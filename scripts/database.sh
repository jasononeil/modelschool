#!/bin/bash

# Get the container id of the database container
dirName=${PWD##*/}
mysqlContainerId=`docker inspect --format="{{.Id}}" ${dirName}_db_1`
phpContainerId=`docker inspect --format="{{.Id}}" ${dirName}_php_1`

# Decide which schema we're loading
databaseName=$1
schemaFile=$2

# Copy SQL file to container, wipe database, and then run the SQL file.
docker cp $schemaFile $mysqlContainerId:/schema.sql
docker exec -i -t $mysqlContainerId mysql -u root -proot -e "DROP DATABASE IF EXISTS $databaseName; CREATE DATABASE $databaseName;"
docker exec -i -t $mysqlContainerId sh -c "mysql -u root -proot -D $databaseName < schema.sql"

# TODO: add ability to run database migrations
# docker exec -i $phpContainerId php artisan migrate:run --env=local <<< "y"

echo "Successfully restored the database $databaseName from file $schemaFile."
