# https://github.com/supabase/postgres/blob/15.8.1.047/Dockerfile-15
FROM supabase/postgres:15.8.1.047

# Setup Postgresql PPA: https://www.ubuntuupdates.org/ppa/postgresql?dist=focal-pgdg
RUN set -xe; \
  sudo apt install curl ca-certificates gnupg; \
  curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/apt.postgresql.org.gpg >/dev/null; \
  sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ focal-pgdg main" >> /etc/apt/sources.list.d/postgresql.list';

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

COPY requirements.txt /

# Install Python 3.9 and barman-cloud
RUN set -xe; \
  apt-get update; \
  apt-get remove -y python3.8 python3.8-minimal python3-minimal python3; \
  apt-get autoremove -y; \
  apt-get install -y --no-install-recommends \
  python3.9 \
  python3.9-distutils \
  python3.9-dev \
  python3.9-venv \
  ; \
  curl -sS https://bootstrap.pypa.io/get-pip.py | python3.9; \
  update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 1; \
  update-alternatives --install /usr/bin/python python /usr/bin/python3.9 1; \
  pip install --no-cache-dir --upgrade pip; \
  pip install --no-cache-dir --no-deps -r requirements.txt; \
  pip install psycopg2-binary; \
  rm -rf /var/lib/apt/lists/*;

# Revert the postgres user to id 26
RUN usermod -u 26 postgres
USER 26

COPY --chown=26:26 --chmod=755 ./extension/pgsodium_getkey /usr/share/postgresql/extension/pgsodium_getkey
