#!/bin/bash

DATA_FOLDER=/data/
BACKUP_FOLDER=bkups/

DATE_TIME=$(date '+%Y-%m-%d_%H%M')
TEMP_DIR=/var/tmp/${DATE_TIME}/

# Make environment variables available
source /etc/environment

echo "Backing up on ${DATE_TIME}" > /backup.log

# Check if the backup folder is already present
if [ ! -d "${DATA_FOLDER}${BACKUP_FOLDER}" ]; then
	mkdir ${DATA_FOLDER}${BACKUP_FOLDER}
fi

# create a temporary directory

if [ -d "$TEMP_DIR" ]; then
	rm -rdf "$TEMP_DIR"
fi

mkdir "$TEMP_DIR"

# Backup the Sqlite db
sqlite3 ${DATA_FOLDER}/db.sqlite3 ".backup '${TEMP_DIR}db-${DATE_TIME}.sqlite3'"
echo "Backup db done" >> /backup.log

# Backup the attachments dir
if [ -d "${DATA_FOLDER}attachments/" ]; then
	mkdir "$TEMP_DIR"attachments/
	cp -r "${DATA_FOLDER}attachments/" "$TEMP_DIR"attachments/
	echo "Backup attachments done" >> /backup.log
else
	echo "Backup attachments skipped" >> /backup.log
fi

# Backup the config.json file
cp "${DATA_FOLDER}"*.json "$TEMP_DIR"
echo "Backup json files done" >> /backup.log

# Backup the rsa_key* files
cp "${DATA_FOLDER}"rsa_key.* "$TEMP_DIR"
echo "Backup rsa keys done" >> /backup.log

# Compress the temp folder (z: gzip, c: create, f: filename, C: move to temp_dir before compressing) and delete it
tar -zcf "${DATA_FOLDER}${BACKUP_FOLDER}${DATE_TIME}.tar" -C "${TEMP_DIR}" .
echo "Backup folder compressed" >> /backup.log

# Remove old backups

#  If trying ls on a nonexisting path, gives a null string
shopt -s nullglob

# get file list into an array sorted by newest separated by a newline
unset FILE_LIST
FILE_LIST+=("$(ls -tp1 ${DATA_FOLDER}${BACKUP_FOLDER})")

# Separate the string into array elements (-d '' suppresses \n as the default string delimiter)
IFS=$'\n' read -rd '' -a FILE_ARRAY <<<"${FILE_LIST[@]}"; unset IFS

for i in "${!FILE_ARRAY[@]}"; do
	echo "checking file ${FILE_ARRAY[$i]}, ($i against ${LAST_N_BCKUPS}) " >> /backup.log
	if [[ "$i" -ge "${LAST_N_BCKUPS}" ]]; then
		echo "trying to delete ${DATA_FOLDER}${BACKUP_FOLDER}${FILE_ARRAY[$i]}"  >> /backup.log
		rm -- "${DATA_FOLDER}${BACKUP_FOLDER}${FILE_ARRAY[$i]}"
		echo "removed ${FILE_ARRAY[$i]} (item $i)" >> /backup.log
	fi
done

# Unset nullglob option
#shopt -u nullglob
