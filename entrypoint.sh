#!/bin/sh

su - postgres -c "/usr/pgsql-13/bin/pg_ctl -D /var/lib/pgsql/13/data -l logfile start"
graphql-engine-pro serve