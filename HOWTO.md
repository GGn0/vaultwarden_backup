# How to get here
## Prequisites
- Install docker

# Get the setup commands
The objective of this section is to attain the commands to execute in the dockerfile

Pull the original image
```sh
docker pull bitwardenrs/server:latest
```
Spin up a container of the image and run a shell inside it
> Adding the --rm flag deletes the container once the shell session is closed.
```sh
docker run --rm -it -p 777:80 bitwardenrs/server:latest /bin/sh
```
Here we try all the commands and verify that:
- The desired results are attained
- The user input is not required


Update package index and install cron silently and run it
```sh
apt-get update
apt-get -y --allow-downgrades --allow-remove-essential --allow-change-held-packages install -qq cron
cron
```

Check if cron is running
```sh
ps -aux | grep cron
```
> :heavy_check_mark:   root         ...         cron
 

Check that a simple cron script works:
```sh
touch /etc/cron.d/test-cron
echo "* * * * *  echo test >> /test.log" > /etc/cron.d/test-cron
echo "#" >> /etc/cron.d/test-cron
chmod 755 /etc/cron.d/test-cron
crontab /etc/cron.d/test-cron
```

Now wait a couple of minutes and run
```sh
cat test.log
```
>:heavy_check_mark:
>
> test
>
> ...
>
> ...
>
> test

The content of the test.log file should be multiple lines of the string "test" (one each minute")

Now we can delete the test script and output file

```sh
rm /etc/cron.d/test-cron
rm test.log
```

# Dockerfile and startup scripts
Exit from the container
```sh
exit
```
The docker file has to replicate the previous commands. the entrypoint and command have been taken by the [original Dockerfile](https://github.com/dani-garcia/bitwarden_rs/blob/master/docker/amd64/Dockerfile)
```sh
FROM bitwardenrs/server:latest

WORKDIR /

RUN apt-get update
RUN apt-get install -y -qq --allow-downgrades \
		--allow-remove-essential \
		--allow-change-held-packages \
		cron

RUN cron

EXPOSE 80

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/start.sh"]
```

Build the image
```sh
docker build --rm -t bitwarden_backup .
```

Spin the container and check if everything is running as expected
>:warning: to test the entrypoint and cmd, you can't start an autoremovable container! run it as detached (-d)
```sh
docker run -d -p 777:80 --name BW_test bitwarden_backup
docker exec -it BW_test /bin/bash 
```

> :x: cron won't be running!

That's because cron has to be launched when the container is launched (not when creating the image)

Since there is already a script called in the CMD field, we'll replace it with another one

## Adjusting the start operations
### Entry script

The basic script has to spawn the cron process and then call the start script (previous CMD command)
```sh
#!/bin/bash

# Spawn cron process in bg
cron &

# Launch start script, it keeps the container from exiting
./start.sh
```
> :warinng: Don't use #!/bin/sh which doesn't have here-strings (will be used later)

The dockerfile has been modified to
```sh
FROM bitwardenrs/server:latest

WORKDIR /

RUN apt-get update
RUN apt-get install -y -qq --allow-downgrades \
		--allow-remove-essential \
		--allow-change-held-packages \
		cron

# Copy the entry script and make it executable
ADD entry.sh /entry.sh
RUN chmod 755 /entry.sh

EXPOSE 80

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/entry.sh"]
```

The start script is added to the image and the execution permission is set.
The CMD has also been changed to call entry.sh instead of start.sh

```sh
docker build --rm -t bitwarden_backup .
docker run -d -p 777:80 --name BW_test bitwarden_backup
docker exec -it BW_test /bin/bash
```
In the docker shell
```sh
ps -aux | grep cron
```
> :heavy_check_mark: cron should be running!

---

### Generating the cronjob file
Once it has been verified that the cron task is spawned, it's necessary to generate a cron job to execute a periodic backup.

The idea is to have environment variables to specify the hour and minute at which the backup has to be done and how many backups to keep. At startup the script reads these variables and generates the cronjob file

Environment variables in the **Dockerfile**
```sh
#Set the environment variables
ENV BKUP_AT_MIN=0
ENV BKUP_AT_HOUR=12,22
ENV LAST_N_BCKUPS=10
```

The desired generated cronjob file should look something like that
```sh
0 12,22 * * * /./backup.sh

```
This should call the script /backup.sh at 12:00 and at 22:00

The following lines have been added to **/entry.sh**
```sh
CRONJOB_DIR=/etc/cron.d/
CRONJOB_FILE=backup_job

# Reference bash and not sh! because sh doesn't have redirects (<<<)
set -m

#  Function to remove big numbers or double commas
format_cron_string() {
        ...
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

```

The script now validates the environmental variables and prints the cronjob file.
The file is then given the execution permissions and set as the crontab for the container user

The **Dockerfile** has to be modified to add the scripts and set the permissions
```sh
# Copy the entry script and make it executable
ADD entry.sh /entry.sh
RUN chmod 755 /entry.sh

# Copy the backup script and make it executable
# (the backup script name is referenced in entry.sh)
ADD backup.sh /backup.sh
RUN chmod 755 /backup.sh
```
# Backup script
The script backup.sh saves the following files according to the [project documentation](https://github.com/dani-garcia/bitwarden_rs/wiki/Backing-up-your-vault):

- SQLite database (using the .backup command)
- Attachments folder (if present)
- *.json files
- rsa_key.* files

most of the items to backup are just files/folder to copy. The database is handled using the SQLite command '.backup'.

The script copies everything into a temporary folder and then adds it to a tar archive.
The **tar archive** is moved in the **/data/bkups** folder and only the most recent files are kept.

The number of backups stored can be set editing the environment variable **LAST_N_BCKUPS**

> :warning: The tar archives are unencrypted!

It's suggested to use a docker volume to make the backup folder available on the outside, encrypt the files and store them on a separate device.
## Manual backup
Backups can be triggered manually executing the backup script:
```sh
sqlite3 docker exec BW_test /./backup.sh 
```
the backup will be found in the folder **/data/bkups**

## Restoring a backup
To restore a backup, just extract the tar archive in the data folder, then use the sqlite3 shell to restore the database backup:
(From the container shell)
```sh
sqlite3 /data/db.sqlite3 ".restore '/path/to/backup.sqlite3'"
```