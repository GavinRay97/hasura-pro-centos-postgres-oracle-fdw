FROM hasuraci/graphql-engine-pro:v2.2.0-pro.1.centos

ARG oracle_fdw_version=2_4_0
ARG instantclient_version=19_3

USER root

# Centos 8 is EOL, so we need to fix the repos
# See: https://forums.centos.org/viewtopic.php?f=54&t=78708
RUN dnf -y --disablerepo '*' --enablerepo=extras swap centos-linux-repos centos-stream-repos && dnf -y distro-sync

# Taken from: https://github.com/mfvitale/postgres-oracle-fdw/blob/master/Dockerfile
RUN dnf remove -y postgresql13-devel-13.5-1PGDG.rhel8.x86_64 \
    && dnf install -y \
    libpq-devel-13.5-1.el8.x86_64 \
    http://mirror.centos.org/centos/8-stream/AppStream/x86_64/os/Packages/postgresql-server-devel-13.5-2.module_el8.6.0+1044+ed943ce5.x86_64.rpm \
    postgresql13-server \
    # contrib package contains extensions like "pg_fdw" and "dblink"
    postgresql13-contrib

RUN dnf install -y \
    http://mirror.centos.org/centos/8-stream/BaseOS/x86_64/os/Packages/libaio-0.3.112-1.el8.x86_64.rpm libaio-devel \
    gcc gcc-c++ make unzip redhat-rpm-config libnsl

COPY sdk\ /tmp

RUN unzip "/tmp/*.zip" -d /tmp

ENV ORACLE_HOME=/tmp/instantclient_${instantclient_version}
ENV LD_LIBRARY_PATH=/tmp/instantclient_${instantclient_version}
ENV PATH=$ORACLE_HOME/bin:$PATH
RUN cd /tmp/oracle_fdw-ORACLE_FDW_${oracle_fdw_version} && make && make install

RUN cp /tmp/oracle_fdw-ORACLE_FDW_${oracle_fdw_version}/oracle_fdw.so /usr/pgsql-13/lib \
    && cp /tmp/oracle_fdw-ORACLE_FDW_${oracle_fdw_version}/oracle_fdw.control /usr/pgsql-13/share/extension \
    && cp /tmp/oracle_fdw-ORACLE_FDW_${oracle_fdw_version}/oracle_fdw--1.0--1.1.sql /usr/pgsql-13/share/extension \
    && cp /tmp/oracle_fdw-ORACLE_FDW_${oracle_fdw_version}/oracle_fdw--1.1--1.2.sql /usr/pgsql-13/share/extension \
    && cp /tmp/oracle_fdw-ORACLE_FDW_${oracle_fdw_version}/oracle_fdw--1.2.sql /usr/pgsql-13/share/extension \
    && ldconfig /tmp/instantclient_19_3/ 

# Initialize DB data files
RUN su - postgres -c '/usr/pgsql-13/bin/initdb -D /var/lib/pgsql/13/data -U postgres --locale=en_US.UTF-8'

# ### 3. Expose database and it's port to host machine
# # set permissions to allow logins, trust the bridge, this is the default for docker YMMV
RUN echo "host    all             all             0.0.0.0/0            trust" >> /var/lib/pgsql/13/data/pg_hba.conf

# #listen on all interfaces
RUN echo "listen_addresses='*'" >> /var/lib/pgsql/13/data/postgresql.conf

# #expose 5432 (postgres) and 8080 (graphql)
EXPOSE 5432
EXPOSE 8080 

# ### 5. Add VOLUMEs to allow persistence of database
VOLUME  ["/usr/pgsql-13", "/var/lib/pgsql/13/data"]

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]