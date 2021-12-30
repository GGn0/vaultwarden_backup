#!/bin/bash

# cd to script directory
cd ${BASH_SOURCE%/*}

#-------------------CONFIGS---------------------

source ./CONFIG

#-----------------------------------------------

unset LOCAL_LIST
unset LOCAL_ARRAY
sudo -u ${USR} REMOTE_LIST=$(./"${UPLOADER}" list ${REMOTEDIR})
LOCAL_LIST+=$(ls -1r "${SOURCEDIR}")
IFS=$'\n' read -rd '' -a LOCAL_ARRAY <<<"${LOCAL_LIST[@]}"; unset IFS

TMPDIR=$(mktemp -d)
chown ${USR}:${USR} "${TMPDIR}"
for i in ${!LOCAL_ARRAY[@]}; do
        printf -v FILENAME "%03d.tar.gz" $i
        openssl enc -aes256 -in "${SOURCEDIR}/${LOCAL_ARRAY[$i]}" -pbkdf2 -iter 100000 -pass file:"${PWD}" -out "${TMPDIR}/${FILENAME}"
        chown ${USR} "${TMPDIR}/${FILENAME}"
        sudo -u ${USR} ./"${UPLOADER}" upload "${TMPDIR}/${FILENAME}" "${REMOTE_DIR}/"
done

rm -rf "${TMPDIR}"
