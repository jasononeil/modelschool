#!/bin/bash

# Get the container id of the database container
dirName=${PWD##*/}
mysqlContainerId=`docker inspect --format="{{.Id}}" ${dirName}_db_1`
phpContainerId=`docker inspect --format="{{.Id}}" ${dirName}_php_1`

databaseName=$1
backupFile=$2

# Copy SQL file to container, wipe database, and then run the SQL file.
docker exec -i -t $mysqlContainerId sh -c "mysqldump -u root -proot --routines --triggers $databaseName > backup.sql"
docker cp $mysqlContainerId:/backup.sql $backupFile

echo "Successfully backed up the database $databaseName to $backupFile."
