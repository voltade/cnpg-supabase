# https://github.com/supabase/postgres/blob/15.1.1.78/Dockerfile
FROM supabase/postgres:15.1.1.78

# Setup Postgresql PPA: https://www.ubuntuupdates.org/ppa/postgresql?dist=focal-pgdg
RUN set -xe; \
  apt-get update; \
  apt-get install -y curl ca-certificates gnupg; \
  curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/apt.postgresql.org.gpg >/dev/null; \
  sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ focal-pgdg main" >> /etc/apt/sources.list.d/postgresql.list';

# Add deadsnakes PPA for Python 3.9
RUN set -xe; \
  apt-get update; \
  apt-get install -y software-properties-common; \
  add-apt-repository ppa:deadsnakes/ppa;

# Install additional extensions
RUN set -xe; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
  "postgresql-15-pg-failover-slots" \
  ; \
  rm -fr /tmp/* ; \
  rm -rf /var/lib/apt/lists/*;

# Revert the postgres user to id 26
RUN usermod -u 26 postgres
USER 26

COPY --chown=26:26 --chmod=755 ./extension/pgsodium_getkey /usr/share/postgresql/extension/pgsodium_getkey
