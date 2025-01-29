#!/bin/bash

set -e
set -u

function create_user_and_database() {
	local database=$1
	local user=$2
	local password=$3
	echo "  Creating user '$user' with password '$password' and database '$database'"
	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
	    CREATE USER $user WITH PASSWORD '$password';
	    CREATE DATABASE $database OWNER $user ;
	    GRANT ALL PRIVILEGES ON DATABASE $database TO $user;
	    GRANT ALL PRIVILEGES ON DATABASE $database TO $POSTGRES_USER;
EOSQL
}

if [ -n "$POSTGRES_MULTIPLE_DATABASES" ]; then
	echo "Multiple database creation requested: $POSTGRES_MULTIPLE_DATABASES"
	for db in $(echo $POSTGRES_MULTIPLE_DATABASES | tr ',' ' '); do
	    db_user_var="${db}_db_user"
		db_user_pwd="${db}_db_pwd"
		create_user_and_database $db $(eval echo \$$db_user_var) $(eval echo \$$db_user_pwd)
	done
	echo "Multiple databases created"
fi
