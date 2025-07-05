ARG debian_version=bookworm
# https://www.postgresql.org/docs/release/
ARG postgresql_major=17
ARG postgresql_release=${postgresql_major}.5

# https://github.com/jedisct1/libsodium/releases
ARG libsodium_release=1.0.20

# https://github.com/eradman/pg-safeupdate/tags
ARG pg_safeupdate_release=1.5

# https://github.com/citusdata/pg_cron/releases
ARG pg_cron_release=1.6.4

# https://github.com/supabase/pg_net/releases
ARG pg_net_release=0.14.0

# https://github.com/pgexperts/pg_plan_filter/commits/master/
ARG pg_plan_filter_release=5081a7b5cb890876e67d8e7486b6a64c38c9a492

# https://github.com/michelp/pgjwt/commits/master/
ARG pgjwt_release=f3d82fd30151e754e19ce5d6a06c71c20689ce3d

# https://github.com/supabase/vault/releases
ARG vault_release=0.3.1

# https://github.com/pramsey/pgsql-http/tags
ARG pgsql_http_release=1.6.3

# https://github.com/okbob/plpgsql_check/releases
ARG plpgsql_check_release=2.8.1

# https://github.com/eulerto/wal2json/releases
ARG wal2json_release=2_6

# https://github.com/plv8/pljs/tags
ARG pljs_release=1.0.1

# https://github.com/plv8/plv8/tags
ARG plv8_release=3.2.3

# https://github.com/postgrespro/rum/tags
ARG rum_release=1.3.14

# https://github.com/iCyberon/pg_hashids/tags
ARG pg_hashids_release=1.2.1

# https://github.com/percona/pg_stat_monitor/releases
ARG pg_stat_monitor_release=2.1.1

# https://github.com/supabase/pg_jsonschema/releases
ARG pg_jsonschema_release=0.3.3

# https://github.com/reorg/pg_repack/releases
ARG pg_repack_release=1.5.2

# https://github.com/supabase/wrappers/releases
ARG wrappers_release=0.5.2

# https://github.com/HypoPG/hypopg/releases
ARG hypopg_release=1.4.1

# https://github.com/pgvector/pgvector/tags
ARG pgvector_release=0.8.0

# https://github.com/aws/pg_tle/releases
ARG pg_tle_release=1.5.1

# https://github.com/olirice/index_advisor/releases
ARG index_advisor_release=0.2.0

# https://github.com/supabase/supautils/releases
ARG supautils_release=2.9.4

FROM postgres:${postgresql_release}-${debian_version} AS builder
ARG postgresql_major
ARG TARGETARCH

RUN apt update && apt install -y --no-install-recommends \
  build-essential \
  checkinstall \
  cmake \
  postgresql-server-dev-${postgresql_major}

FROM builder AS ccache
# Cache large build artifacts
RUN apt-get update && apt-get install -y --no-install-recommends \
  clang \
  ccache \
  && rm -rf /var/lib/apt/lists/*
ENV CCACHE_DIR=/ccache
ENV PATH=/usr/lib/ccache:$PATH
# Used to update ccache
ARG CACHE_EPOCH


FROM ccache AS libsodium-source
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


FROM ccache AS pg-safeupdate-source
ARG pg_safeupdate_release
# Download and extract
ADD "https://github.com/eradman/pg-safeupdate/archive/refs/tags/${pg_safeupdate_release}.tar.gz" \
  /tmp/pg-safeupdate.tar.gz
RUN tar -xvf /tmp/pg-safeupdate.tar.gz -C /tmp && \
  rm -rf /tmp/pg-safeupdate.tar.gz
# Build from source
WORKDIR /tmp/pg-safeupdate-${pg_safeupdate_release}
RUN --mount=type=cache,target=/ccache \
  make -j$(nproc)
# Create debian package
RUN checkinstall -D --install=no --fstrans=no --backup=no --pakdir=/tmp --nodoc


FROM ccache AS pg_cron-source
# Download and extract
ARG pg_cron_release
ARG pg_cron_release_checksum
ADD --checksum=${pg_cron_release_checksum} \
  "https://github.com/citusdata/pg_cron/archive/refs/tags/v${pg_cron_release}.tar.gz" \
  /tmp/pg_cron.tar.gz
RUN tar -xvf /tmp/pg_cron.tar.gz -C /tmp && \
  rm -rf /tmp/pg_cron.tar.gz
# Build from source
WORKDIR /tmp/pg_cron-${pg_cron_release}
RUN --mount=type=cache,target=/ccache \
  make -j$(nproc)
# Create debian package
RUN checkinstall -D --install=no --fstrans=no --backup=no --pakdir=/tmp --nodoc


FROM ccache AS pg_net-source
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
RUN --mount=type=cache,target=/ccache \
  make -j$(nproc)
# Create debian package
RUN checkinstall -D --install=no --fstrans=no --backup=no --pakdir=/tmp --requires=libcurl3-gnutls --nodoc


FROM ccache AS pg_plan_filter-source
# Download and extract
ARG pg_plan_filter_release
ADD "https://github.com/pgexperts/pg_plan_filter.git#${pg_plan_filter_release}" \
  /tmp/pg_plan_filter-${pg_plan_filter_release}
# Build from source
WORKDIR /tmp/pg_plan_filter-${pg_plan_filter_release}
RUN --mount=type=cache,target=/ccache \
  make -j$(nproc)
# Create debian package
RUN checkinstall -D --install=no --fstrans=no --backup=no --pakdir=/tmp --pkgversion=1 --nodoc


FROM ccache AS pgjwt-source
# Download and extract
ARG pgjwt_release
ADD "https://github.com/michelp/pgjwt.git#${pgjwt_release}" \
  /tmp/pgjwt-${pgjwt_release}
# Build from source
WORKDIR /tmp/pgjwt-${pgjwt_release}
RUN make -j$(nproc)
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

FROM ccache AS pgsql-http-source
ARG pgsql_http_release
# Download and extract
ADD "https://github.com/pramsey/pgsql-http/archive/refs/tags/v${pgsql_http_release}.tar.gz" \
  /tmp/pgsql-http.tar.gz
RUN tar -xvf /tmp/pgsql-http.tar.gz -C /tmp && \
  rm -rf /tmp/pgsql-http.tar.gz
# Install build dependencies
RUN apt update && apt install -y --no-install-recommends \
  libcurl4-gnutls-dev \
  && rm -rf /var/lib/apt/lists/*
# Build from source
WORKDIR /tmp/pgsql-http-${pgsql_http_release}
RUN make -j$(nproc)
# Create debian package
RUN checkinstall -D --install=no --fstrans=no --backup=no --pakdir=/tmp --requires=libcurl4 --nodoc

FROM ccache AS plpgsql_check-source
ARG plpgsql_check_release
# Download and extract
ADD "https://github.com/okbob/plpgsql_check/archive/refs/tags/v${plpgsql_check_release}.tar.gz" \
  /tmp/plpgsql_check.tar.gz
RUN tar -xvf /tmp/plpgsql_check.tar.gz -C /tmp && \
  rm -rf /tmp/plpgsql_check.tar.gz
# Install build dependencies
RUN apt update && apt install -y --no-install-recommends \
  libicu-dev \
  && rm -rf /var/lib/apt/lists/*
# Build from source
WORKDIR /tmp/plpgsql_check-${plpgsql_check_release}
RUN make -j$(nproc)
# Create debian package
RUN checkinstall -D --install=no --fstrans=no --backup=no --pakdir=/tmp --nodoc

FROM ccache AS wal2json-source
ARG wal2json_release
# Download and extract
ADD "https://github.com/eulerto/wal2json/archive/refs/tags/wal2json_${wal2json_release}.tar.gz" \
  /tmp/wal2json.tar.gz
RUN tar -xvf /tmp/wal2json.tar.gz -C /tmp --one-top-level --strip-components 1 && \
  rm -rf /tmp/wal2json.tar.gz
# Build from source
WORKDIR /tmp/wal2json
RUN make -j$(nproc)
# Create debian package
ENV version=${wal2json_release}
RUN checkinstall -D --install=no --fstrans=no --backup=no --pakdir=/tmp --pkgversion="\${version/_/.}" --nodoc

FROM ccache AS pljs-source
ARG pljs_release
# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  gcc \
  git \
  && rm -rf /var/lib/apt/lists/*
# Clone source and submodules
RUN git clone --branch v${pljs_release} --recurse-submodules --depth 1 https://github.com/plv8/pljs.git /tmp/pljs-${pljs_release}
# Build from source
WORKDIR /tmp/pljs-${pljs_release}
# Patch quickjs Makefile to add -fPIC and a valid version
RUN sed -i "s/CFLAGS+=-g -Wall/CFLAGS+=-fPIC -g -Wall/" deps/quickjs/Makefile
RUN --mount=type=cache,target=/ccache make -j$(nproc)
# Create debian package
RUN checkinstall -D --install=no --fstrans=no --backup=no --pakdir=/tmp --nodoc

FROM ccache AS plv8-source
ARG plv8_release
# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  pkg-config \
  ninja-build \
  git \
  binutils \
  libtinfo5 \
  libstdc++-12-dev \
  && rm -rf /var/lib/apt/lists/*
# Clone source and submodules
RUN git clone --branch v${plv8_release} --recurse-submodules --depth 1 https://github.com/plv8/plv8.git /tmp/plv8-${plv8_release}
# Build from source
WORKDIR /tmp/plv8-${plv8_release}
RUN --mount=type=cache,id=plv8-${plv8_release}/build,target=/tmp/plv8-${plv8_release}/build \
  --mount=type=cache,id=ccache,target=/ccache \
  # build plv8_config.h first to prevent parallel build overwriting it
  make plv8_config.h plv8.so -j$(nproc)

# Create debian package
RUN checkinstall -D --install=no --fstrans=no --backup=no --pakdir=/tmp --nodoc

FROM ccache AS rum-source
ARG rum_release
# Download and extract
ADD "https://github.com/postgrespro/rum/archive/refs/tags/${rum_release}.tar.gz" \
  /tmp/rum.tar.gz
RUN tar -xvf /tmp/rum.tar.gz -C /tmp && \
  rm -rf /tmp/rum.tar.gz
# Install build dependencies
RUN apt update && apt install -y --no-install-recommends \
  systemtap-sdt-dev \
  && rm -rf /var/lib/apt/lists/*
# Build from source
WORKDIR /tmp/rum-${rum_release}
ENV USE_PGXS=1
RUN make -j$(nproc)
# Create debian package
RUN checkinstall -D --install=no --fstrans=no --backup=no --pakdir=/tmp --nodoc


FROM ccache AS pg_hashids-source
ARG pg_hashids_release
# Download and extract
ADD "https://github.com/iCyberon/pg_hashids/archive/refs/tags/v${pg_hashids_release}.tar.gz" \
  /tmp/pg_hashids.tar.gz
RUN tar -xvf /tmp/pg_hashids.tar.gz -C /tmp && \
  rm -rf /tmp/pg_hashids.tar.gz
# Build from source
WORKDIR /tmp/pg_hashids-${pg_hashids_release}
RUN make -j$(nproc)
# Create debian package
RUN checkinstall -D --install=no --fstrans=no --backup=no --pakdir=/tmp --pkgversion=1 --nodoc

FROM ccache AS pg_stat_monitor-source
ARG pg_stat_monitor_release
# Download and extract
ADD "https://github.com/percona/pg_stat_monitor/archive/refs/tags/${pg_stat_monitor_release}.tar.gz" \
  /tmp/pg_stat_monitor.tar.gz
RUN tar -xvf /tmp/pg_stat_monitor.tar.gz -C /tmp && \
  rm -rf /tmp/pg_stat_monitor.tar.gz
# Build from source
WORKDIR /tmp/pg_stat_monitor-${pg_stat_monitor_release}
ENV USE_PGXS=1
RUN make -j$(nproc)
# Create debian package
RUN checkinstall -D --install=no --fstrans=no --backup=no --pakdir=/tmp --nodoc

FROM builder AS pg_jsonschema
# Download package archive
ARG pg_jsonschema_release
ADD "https://github.com/supabase/pg_jsonschema/releases/download/v${pg_jsonschema_release}/pg_jsonschema-v${pg_jsonschema_release}-pg${postgresql_major}-${TARGETARCH}-linux-gnu.deb" \
  /tmp/pg_jsonschema.deb

FROM ccache AS pg_repack-source
ARG pg_repack_release
# Download and extract
ADD "https://github.com/reorg/pg_repack/archive/refs/tags/ver_${pg_repack_release}.tar.gz" \
  /tmp/pg_repack.tar.gz
RUN tar -xvf /tmp/pg_repack.tar.gz -C /tmp && \
  rm -rf /tmp/pg_repack.tar.gz
# Install build dependencies
RUN apt update && apt install -y --no-install-recommends \
  zlib1g-dev \
  liblz4-dev \
  libzstd-dev \
  libreadline-dev \
  && rm -rf /var/lib/apt/lists/*
# Build from source
WORKDIR /tmp/pg_repack-ver_${pg_repack_release}
ENV USE_PGXS=1
RUN make -j$(nproc)
# Create debian package
RUN checkinstall -D --install=no --fstrans=no --backup=no --pakdir=/tmp --pkgversion=${pg_repack_release} --nodoc

FROM builder AS wrappers
# Download package archive
ARG wrappers_release
ADD "https://github.com/supabase/wrappers/releases/download/v${wrappers_release}/wrappers-v${wrappers_release}-pg${postgresql_major}-${TARGETARCH}-linux-gnu.deb" \
  /tmp/wrappers.deb

FROM ccache AS hypopg-source
ARG hypopg_release
# Download and extract
ADD "https://github.com/HypoPG/hypopg/archive/refs/tags/${hypopg_release}.tar.gz" \
  /tmp/hypopg.tar.gz
RUN tar -xvf /tmp/hypopg.tar.gz -C /tmp && \
  rm -rf /tmp/hypopg.tar.gz
# Build from source
WORKDIR /tmp/hypopg-${hypopg_release}
RUN make -j$(nproc)
# Create debian package
RUN checkinstall -D --install=no --fstrans=no --backup=no --pakdir=/tmp --nodoc

FROM ccache AS pgvector-source
ARG pgvector_release
# Download and extract
ADD "https://github.com/pgvector/pgvector/archive/refs/tags/v${pgvector_release}.tar.gz" \
  /tmp/pgvector.tar.gz
RUN tar -xvf /tmp/pgvector.tar.gz -C /tmp && \
  rm -rf /tmp/pgvector.tar.gz
# Build from source
WORKDIR /tmp/pgvector-${pgvector_release}
RUN make -j$(nproc)
# Create debian package
RUN checkinstall -D --install=no --fstrans=no --backup=no --pakdir=/tmp --nodoc

FROM ccache AS pg_tle-source
ARG pg_tle_release
# Download and extract
ADD "https://github.com/aws/pg_tle/archive/refs/tags/v${pg_tle_release}.tar.gz" \
  /tmp/pg_tle.tar.gz
RUN tar -xvf /tmp/pg_tle.tar.gz -C /tmp && \
  rm -rf /tmp/pg_tle.tar.gz
# Install build dependencies
RUN apt update && apt install -y --no-install-recommends \
  flex \
  libkrb5-dev \
  && rm -rf /var/lib/apt/lists/*
# Build from source
WORKDIR /tmp/pg_tle-${pg_tle_release}
RUN make -j$(nproc)
# Create debian package
RUN checkinstall -D --install=no --fstrans=no --backup=no --pakdir=/tmp --nodoc

FROM ccache AS index_advisor-source
ARG index_advisor_release
# Download and extract
ADD "https://github.com/olirice/index_advisor/archive/refs/tags/v${index_advisor_release}.tar.gz" \
  /tmp/index_advisor.tar.gz
RUN tar -xvf /tmp/index_advisor.tar.gz -C /tmp && \
  rm -rf /tmp/index_advisor.tar.gz
# Build from source
WORKDIR /tmp/index_advisor-${index_advisor_release}
RUN make -j$(nproc)
# Create debian package
RUN checkinstall -D --install=no --fstrans=no --backup=no --pakdir=/tmp --nodoc

FROM ccache AS supautils-source
ARG supautils_release
# Download and extract
ADD "https://github.com/supabase/supautils/archive/refs/tags/v${supautils_release}.tar.gz" \
  /tmp/supautils.tar.gz
RUN tar -xvf /tmp/supautils.tar.gz -C /tmp && \
  rm -rf /tmp/supautils.tar.gz
# Build from source
WORKDIR /tmp/supautils-${supautils_release}
RUN make -j$(nproc)
# Create debian package
RUN checkinstall -D --install=no --fstrans=no --backup=no --pakdir=/tmp --nodoc

# https://github.com/cloudnative-pg/postgres-containers?tab=readme-ov-file#minimal-images
# https://github.com/cloudnative-pg/postgres-containers/pkgs/container/postgresql/versions?filters%5Bversion_type%5D=tagged
# FROM ghcr.io/cloudnative-pg/postgresql:${postgresql_release}-minimal-${debian_version}

FROM postgres:${postgresql_release}-${debian_version}
ARG postgresql_major
USER root

# cache pg_stat_statements and auto_explain and pg_stat_kcache to temp directory
RUN set -eux; \
  mkdir /tmp/pg_pkglibdir; \
  mkdir /tmp/pg_sharedir; \
  cp -r $(pg_config --pkglibdir)/* /tmp/pg_pkglibdir; \
  cp -r $(pg_config --sharedir)/* /tmp/pg_sharedir

COPY --from=libsodium-source /tmp/*.deb /tmp/
COPY --from=pg-safeupdate-source /tmp/*.deb /tmp/
COPY --from=pg_cron-source /tmp/*.deb /tmp/
COPY --from=pg_net-source /tmp/*.deb /tmp/
COPY --from=pg_plan_filter-source /tmp/*.deb /tmp/
COPY --from=pgjwt-source /tmp/*.deb /tmp/
COPY --from=vault-source /tmp/*.deb /tmp/
COPY --from=pgsql-http-source /tmp/*.deb /tmp/
COPY --from=plpgsql_check-source /tmp/*.deb /tmp/
COPY --from=wal2json-source /tmp/*.deb /tmp/
COPY --from=pljs-source /tmp/*.deb /tmp/
COPY --from=plv8-source /tmp/*.deb /tmp/
COPY --from=rum-source /tmp/*.deb /tmp/
COPY --from=pg_hashids-source /tmp/*.deb /tmp/
COPY --from=pg_stat_monitor-source /tmp/*.deb /tmp/
COPY --from=pg_jsonschema /tmp/*.deb /tmp/
COPY --from=pg_repack-source /tmp/*.deb /tmp/
COPY --from=wrappers /tmp/*.deb /tmp/
COPY --from=hypopg-source /tmp/*.deb /tmp/
COPY --from=pgvector-source /tmp/*.deb /tmp/
COPY --from=pg_tle-source /tmp/*.deb /tmp/
COPY --from=index_advisor-source /tmp/*.deb /tmp/
COPY --from=supautils-source /tmp/*.deb /tmp/

RUN apt update && apt install -y --no-install-recommends \
  /tmp/*.deb \
  && rm -rf /var/lib/apt/lists/* /tmp/*

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
RUN usermod -u 26 postgres && chown -R 26:26 /var/run/postgresql
USER 26

# Copy the getkey script for pgsodium
COPY --chown=26:26 --chmod=755 ./extension/pgsodium_getkey /usr/share/postgresql/${postgresql_major}/extension/pgsodium_getkey
