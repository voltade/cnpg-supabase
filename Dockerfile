ARG debian_version=bookworm
ARG postgresql_major=17
ARG postgresql_release=${postgresql_major}.4

# https://github.com/jedisct1/libsodium/releases
ARG libsodium_release=1.0.20
# https://github.com/eradman/pg-safeupdate/tags
ARG pg_safeupdate_release=1.5
# https://github.com/supabase/pg_net/releases
ARG pg_net_release=0.14.0
# https://github.com/pgexperts/pg_plan_filter/commits/master/
ARG pg_plan_filter_release=5081a7b5cb890876e67d8e7486b6a64c38c9a492
# https://github.com/supabase/vault/releases
ARG vault_release=0.3.1

FROM postgres:${postgresql_release}-${debian_version} AS builder
ARG postgresql_major

RUN apt update && apt install -y --no-install-recommends \
  build-essential \
  checkinstall \
  cmake \
  postgresql-server-dev-${postgresql_major}

# For extensions not supported by trunk (https://pgt.dev/), build from source
# Reference: https://github.com/supabase/postgres/blob/release/15.6/Dockerfile

FROM builder AS libsodium-source
ARG libsodium_release
ADD "https://github.com/jedisct1/libsodium/releases/download/${libsodium_release}-RELEASE/libsodium-${libsodium_release}.tar.gz" \
  /tmp/libsodium.tar.gz
RUN tar -xvf /tmp/libsodium.tar.gz -C /tmp && \
  rm -rf /tmp/libsodium.tar.gz
# Build from source
WORKDIR /tmp/libsodium-${libsodium_release}
RUN ./configure
RUN make -j$(nproc)
RUN make install
RUN checkinstall -D --install=no --fstrans=no --backup=no --pakdir=/tmp --nodoc

FROM builder AS pg-safeupdate-source
ARG pg_safeupdate_release
# Download and extract
ADD "https://github.com/eradman/pg-safeupdate/archive/refs/tags/${pg_safeupdate_release}.tar.gz" \
  /tmp/pg-safeupdate.tar.gz
RUN tar -xvf /tmp/pg-safeupdate.tar.gz -C /tmp && \
  rm -rf /tmp/pg-safeupdate.tar.gz
# Build from source
WORKDIR /tmp/pg-safeupdate-${pg_safeupdate_release}
RUN --mount=type=cache,target=/ccache,from=public.ecr.aws/supabase/postgres:ccache \
  make -j$(nproc)
# Create debian package
RUN checkinstall -D --install=no --fstrans=no --backup=no --pakdir=/tmp --nodoc

FROM builder AS pg_net-source
# Download and extract
ARG pg_net_release
ARG pg_net_release_checksum
ADD --checksum=${pg_net_release_checksum} \
  "https://github.com/supabase/pg_net/archive/refs/tags/v${pg_net_release}.tar.gz" \
  /tmp/pg_net.tar.gz
RUN tar -xvf /tmp/pg_net.tar.gz -C /tmp && \
  rm -rf /tmp/pg_net.tar.gz
# Install build dependencies
RUN apt update && apt install -y --no-install-recommends \
  libcurl4-gnutls-dev \
  && rm -rf /var/lib/apt/lists/*
# Build from source
WORKDIR /tmp/pg_net-${pg_net_release}
RUN --mount=type=cache,target=/ccache,from=public.ecr.aws/supabase/postgres:ccache \
  make -j$(nproc)
# Create debian package
RUN checkinstall -D --install=no --fstrans=no --backup=no --pakdir=/tmp --requires=libcurl3-gnutls --nodoc

FROM builder AS pg_plan_filter-source
# Download and extract
ARG pg_plan_filter_release
ADD "https://github.com/pgexperts/pg_plan_filter.git#${pg_plan_filter_release}" \
  /tmp/pg_plan_filter-${pg_plan_filter_release}
# Build from source
WORKDIR /tmp/pg_plan_filter-${pg_plan_filter_release}
RUN --mount=type=cache,target=/ccache,from=public.ecr.aws/supabase/postgres:ccache \
  make -j$(nproc)
# Create debian package
RUN checkinstall -D --install=no --fstrans=no --backup=no --pakdir=/tmp --pkgversion=1 --nodoc

FROM libsodium-source AS vault-source
ARG vault_release
# Download and extract
ADD "https://github.com/supabase/vault/archive/refs/tags/v${vault_release}.tar.gz" \
  /tmp/vault.tar.gz
RUN tar -xvf /tmp/vault.tar.gz -C /tmp && \
  rm -rf /tmp/vault.tar.gz
# Build from source
WORKDIR /tmp/vault-${vault_release}
RUN make -j$(nproc)
# Create debian package
RUN checkinstall -D --install=no --fstrans=no --backup=no --pakdir=/tmp --nodoc

# https://github.com/cloudnative-pg/postgres-containers?tab=readme-ov-file#minimal-images
# https://github.com/cloudnative-pg/postgres-containers/pkgs/container/postgresql/versions?filters%5Bversion_type%5D=tagged
FROM ghcr.io/cloudnative-pg/postgresql:${postgresql_release}-minimal-${debian_version}
ARG postgresql_major
USER root

# cache pg_stat_statements and auto_explain and pg_stat_kcache to temp directory
RUN set -eux; \
  mkdir /tmp/pg_pkglibdir; \
  mkdir /tmp/pg_sharedir; \
  cp -r $(pg_config --pkglibdir)/* /tmp/pg_pkglibdir; \
  cp -r $(pg_config --sharedir)/* /tmp/pg_sharedir

COPY --from=pg-safeupdate-source /tmp/*.deb /tmp/
COPY --from=pg_net-source /tmp/*.deb /tmp/
COPY --from=pg_plan_filter-source /tmp/*.deb /tmp/
COPY --from=vault-source /tmp/*.deb /tmp/

RUN apt update && apt install -y --no-install-recommends \
  /tmp/*.deb \
  && rm -rf /var/lib/apt/lists/* /tmp/*

# Install trunk
# https://quay.io/repository/tembo/tembo-pg-cnpg?tab=tags
COPY --from=quay.io/tembo/tembo-pg-cnpg:17-bffd097 /usr/bin/trunk /usr/bin/trunk

RUN trunk install pg_stat_statements
RUN trunk install auto_explain
RUN trunk install pg_cron
RUN trunk install pgjwt
RUN trunk install pgsql_http
RUN trunk install plpgsql_check
RUN trunk install timescaledb
RUN trunk install wal2json
RUN trunk install plv8
RUN trunk install rum
RUN trunk install pg_hashids
RUN trunk install pg_graphql
RUN trunk install pg_stat_monitor
RUN trunk install pg_jsonschema
RUN trunk install pg_repack
RUN trunk install wrappers
RUN trunk install hypopg
RUN trunk install pgvector
RUN trunk install pg_tle
RUN trunk install index_advisor
RUN trunk install supautils

RUN rm -rf /tmp/* /usr/bin/trunk

# Install pg-failover-slots
RUN set -xe; \
  apt update; \
  apt install -y --no-install-recommends \
  "postgresql-${postgresql_major}-pgaudit" \
  "postgresql-${postgresql_major}-pg-failover-slots"; \
  apt purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
  rm -rf /var/lib/apt/lists/* /var/cache/* /var/log/*;

# libs installed with checkinstall are not in the default library path
ENV LD_LIBRARY_PATH=/usr/local/lib

# Revert the postgres user to id 26
RUN usermod -u 26 postgres
USER 26

# Copy the getkey script for pgsodium
COPY --chown=26:26 --chmod=755 ./extension/pgsodium_getkey /usr/share/postgresql/${postgresql_major}/extension/pgsodium_getkey
