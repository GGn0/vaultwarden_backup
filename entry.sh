#!/bin/bash

CRONJOB_DIR=/etc/cron.d/
CRONJOB_FILE=backup_job

# Reference bash and not sh! because sh doesn't have redirects (<<<)

set -m

echo Entrypoint file has been executed > /entry.log

# Started cron process in bg
cron &

echo Cron launched >> /entry.log

# Generate cron file based on ENV vars

#  Function to remove big numbers or double commas
format_cron_string() {
        # input string (ENV var), maximum value of the item
        IN_STR=$1
        MAX_NUM=$2

        # Check for *
        if [[ "$IN_STR" == "*" ]]; then
                OUTPUT="*"
        elif [[ "$IN_STR" =~ [\-0-9,]* ]]; then
                # Internal file separator = ,| read into array | from env variables
                IFS=',' read -ra ARRAY <<< "$IN_STR"

                OUTPUT=""

                # Check every element of the array
                for i in "${!ARRAY[@]}"; do
                        if [[ "${ARRAY[$i]}" == "" ]] || [[ "${ARRAY[$i]}" -gt "$MAX_NUM" ]] || [[ "${ARRAY[$i]}" -lt "0" ]]; then
                                unset ARRAY[$i]
                        else
                                OUTPUT=${OUTPUT}${ARRAY[$i]},
                        fi
                done

                # Remove last comma
                OUTPUT=${OUTPUT%,}
        else
                OUTPUT="*"
        fi

        if [[ "$OUTPUT" == "" ]]; then
                OUTPUT="*"
        fi

        # READ $OUTPUT
}

#  Format minute string
format_cron_string "$BKUP_AT_MIN" 60
MIN_STR="$OUTPUT"
format_cron_string "$BKUP_AT_HOUR" 24
HOUR_STR="$OUTPUT"

# Write the cron file
echo "${MIN_STR}" "${HOUR_STR}" "* * * /./backup.sh" > "${CRONJOB_DIR}${CRONJOB_FILE}"
echo "# this line is needed for a valid cron file" >> "${CRONJOB_DIR}${CRONJOB_FILE}"

# Give the execution permission to the cron file
chmod 755 "${CRONJOB_DIR}${CRONJOB_FILE}"
# Add the cron job to root's crontab
crontab "${CRONJOB_DIR}${CRONJOB_FILE}"

# Launch start script, it keepsthe container from exiting
./start.sh
