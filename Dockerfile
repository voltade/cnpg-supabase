FROM supabase/postgres:15.8.1.021

ENV PG_MAJOR=15

# https://github.com/cloudnative-pg/postgres-containers/blob/main/Debian/15/bookworm/Dockerfile

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

COPY requirements.txt .

# Install additional extensions
# https://www.ubuntuupdates.org/package/postgresql/focal-pgdg/main/base/postgresql-15-pg-failover-slots
# https://wiki.postgresql.org/wiki/Apt
RUN set -xe; \
  apt-get update; \
  apt-get install -y --no-install-recommends postgresql-common; \
  /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y; \
  apt-get install -y --no-install-recommends \
  "postgresql-${PG_MAJOR}-pg-failover-slots" \
  ; \
  rm -fr /tmp/* ; \
  rm -rf /var/lib/apt/lists/*;

# Install python3.9 an pip (python3.8 shipped with ubuntu 20.04 is not compatible with barman-cloud's dependencies)
# https://stackoverflow.com/questions/65644782/how-to-install-pip-for-python-3-9-on-ubuntu-20-04
RUN set -xe; \
  add-apt-repository ppa:deadsnakes/ppa; \
  apt-get purge --auto-remove -y python3; \
  apt-get update; \
  apt-get install --no-install-recommends -y python3.9 python3.9-distutils; \
  curl -q https://bootstrap.pypa.io/get-pip.py -o get-pip.py; \
  python3.9 get-pip.py;

# Install barman-cloud
RUN set -xe; \
  pip install psycopg2-binary; \
  # TODO: Remove --no-deps once https://github.com/pypa/pip/issues/9644 is solved
  pip install --no-deps -r requirements.txt; \
  rm -rf /var/lib/apt/lists/*;
