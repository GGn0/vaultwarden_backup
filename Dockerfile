FROM vaultwarden/server:1.27.0

WORKDIR /

# Install cron
RUN apt-get update
RUN apt-get install -y -qq --allow-downgrades \
		--allow-remove-essential \
		--allow-change-held-packages \
		cron sqlite3

#Set the environment variables
ENV BKUP_AT_MIN=0
ENV BKUP_AT_HOUR=7,12,17,22
ENV LAST_N_BCKUPS=28

# Copy the entry script and make it executable
ADD entry.sh /entry.sh
RUN chmod 755 /entry.sh

# Copy the backup script and make it executable
# (the backup script name is referenced in entry.sh)
ADD backup.sh /backup.sh
RUN chmod 755 /backup.sh

#COPY --from=init /dumb-init /usr/bin/

# Run the helper script as the final command
CMD ["/entry.sh"]
