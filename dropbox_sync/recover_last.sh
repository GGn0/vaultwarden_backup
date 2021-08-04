#!/bin/bash

#-------------------CONFIGS---------------------

source ./CONFIG

#-----------------------------------------------

# Clear and create the recovery folder
if [[ -d "${RECOVER}" ]]; then
	rm -rf "${RECOVER}"
fi

mkdir "${RECOVER}"


TEMP_DIR=$(mktemp -d)

# Pull the encrypted file
./"${UPLOADER}" download "${REMOTE_FOLDER}/000.tar.gz" "${TEMP_DIR}/000.tar.gz"

# Decrypt and untar the archive
openssl enc -d -aes256 -in "${TEMP_DIR}/000.tar.gz" -pass file:"${PWD}" -pbkdf2 -iter 100000 | tar -xz -C "${RECOVER}"


# Delete the temp dir
rm -rf "${TEMP_DIR}"
