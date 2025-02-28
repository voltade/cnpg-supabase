ARG debian_version=bookworm
ARG postgresql_major=17
ARG postgresql_release=${postgresql_major}.4

# https://github.com/jedisct1/libsodium/releases
# The current pgsodium (3.1.9) requires libsodium.so.23
ARG libsodium_release=1.0.18
# https://github.com/eradman/pg-safeupdate/tags
ARG pg_safeupdate_release=1.5
# https://github.com/supabase/vault/releases
ARG vault_release=0.2.9

FROM postgres:${postgresql_release}-${debian_version} AS builder
ARG postgresql_major
RUN apt update && apt install -y --no-install-recommends \
  build-essential \
  checkinstall \
  cmake \
  postgresql-server-dev-${postgresql_major}

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

FROM builder AS vault-source
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

# https://github.com/cloudnative-pg/postgres-containers
FROM ghcr.io/cloudnative-pg/postgresql:${postgresql_release}-${debian_version}

ARG postgresql_major

USER root

# PGDATA is set in tembo-pg-slim and used by dependents on this image.
RUN if [ -z "${PGDATA}" ]; then echo "PGDATA is not set"; exit 1; fi

# Install trunk
COPY --from=quay.io/tembo/tembo-pg-cnpg:17-3f42399 /usr/bin/trunk /usr/bin/trunk

RUN trunk install pg_stat_statements
RUN trunk install auto_explain
RUN trunk install pg_cron
RUN trunk install pgaudit
RUN trunk install pgjwt
RUN trunk install pgsql_http
RUN trunk install plpgsql_check
RUN trunk install timescaledb
RUN trunk install wal2json
RUN trunk install plv8
RUN trunk install pg_net
RUN trunk install rum
RUN trunk install pg_hashids
RUN trunk install pgsodium
RUN trunk install pg_stat_monitor
RUN trunk install pg_jsonschema
RUN trunk install pg_repack
RUN trunk install wrappers
RUN trunk install hypopg
RUN trunk install pgvector
RUN trunk install pg_tle
RUN trunk install index_advisor
RUN trunk install supautils

# cache pg_stat_statements and auto_explain and pg_stat_kcache to temp directory
RUN set -eux; \
  mkdir /tmp/pg_pkglibdir; \
  mkdir /tmp/pg_sharedir; \
  cp -r $(pg_config --pkglibdir)/* /tmp/pg_pkglibdir; \
  cp -r $(pg_config --sharedir)/* /tmp/pg_sharedir

COPY --from=libsodium-source /tmp/*.deb /tmp/
COPY --from=pg-safeupdate-source /tmp/*.deb /tmp/
COPY --from=vault-source /tmp/*.deb /tmp/

RUN apt update && apt install -y --no-install-recommends \
  /tmp/*.deb \
  && rm -rf /var/lib/apt/lists/* /tmp/*

# libs installed with checkinstall are not in the default library path
ENV LD_LIBRARY_PATH=/usr/local/lib

# Revert the postgres user to id 26
RUN usermod -u 26 postgres
USER 26
