# Vaultwarden_backup
The repository contains a modified version of the bitwarden_rs image to implement a periodic backup feature

## Objective
- Practice editing docker images
- Practice using an automatic documentation generator

## System
The container has been deployed on a raspberry Pi 3B+
### Requirements
- Docker
- Portainer (optional)
- Openssl

## How to
### Configure and build the Docker image
The Dockerfile has a few configurable environmental variables that can be configured.
```sh
ENV BKUP_AT_MIN=0,30
ENV BKUP_AT_HOUR=12,22
ENV LAST_N_BCKUPS=9
```
**BKUP_AT_HOUR** and **BKUP_AT_HOUR** dictate how often the backups are saved. In the example above, every day 4 backups will be performed:
- @ 12:00
- @ 12:30
- @ 22:00
- @ 22:30

> :warning: Don't use spaces! Just use numbers and commas (if needed) to separate them

**LAST_N_BCKUPS** sets the number of newest backups to keep. In this case, when the 10th backup has to be saved, the oldest one will be erased

for other environmental variables to set, refer to the original [vaultwarden/server](https://hub.docker.com/r/vaultwarden/server) documentation.
(for example, `SIGNUPS_ALLOWED`=false to disable logins or `ADMIN_TOKEN`=token to give access to the admin page)

From the project directory it's possible to build the image with the following command:
```sh
docker build --rm -t vaultwarden_backup .
```
--rm specifies to remove intermediate images used in the building process
-t assign a tag to the image
. Sets the context of the build to the current directory

### Step 2:
Create a volume, either from portainer or from the command line.
This is necessary to expose the backups to the local machine.

Next run a container using the image and volume that we just prepared

```sh
docker run -d --restart always -v volume_name:/data -p XXX:80 --name container_name image_name
```
-d runs the container in detached mode
-v specifies the volume (__volume_name__) to mount in the container internal directory /data
-p publishes the container port 80 on the host port __XXX__
--name specifies the container name (__container_name__)
__image_name__ is the name of the image previously built

### Step 3:

#### Configuration

All you need is under the diretory `dropbox_sync`  
Execute the script `dropbox_uploader.sh` at least once to link it to your [Dropox](https://www.dropbox.com/) account
> You can find more about the script on its [repo](https://github.com/andreafabrizi/Dropbox-Uploader)

    cd dropbox_sync
    
    # Give execution permissions to the script
    chmod +x dropbox_uploader.sh
    
    # Run the script for the first time and follow the wizard instructions
    ./dropbox_uploader.sh

Create a file (e.g. `PWD`) containing the password for encrypting/decrypting the backup archives
> If you name the file PWD, it will be altready excluded from future commits! (see [.gitignore](.gitignore))

Now you need to edit the `dropbox_sync\CONFIG` file:

    export PWD=./<encryption password file>
    export RECOVER=./<recover directory>
    export UPLOADER=./dropbox_uploader.sh
    export SOURCEDIR=<backup folder in docker volume>
    export REMOTE_FOLDER=<remote subdirectory on Dropbox>
    export USR=ubuntu

- **PWD**: Relative path to the file containing the encryption/decryption password.
- **RECOVER**: A relative folder path where to save restored backups. (will be created if not existent)
- **UPLOADER**: A relative path to the uploader script
- **SOURCEDIR**: The __absolute__ path to the backup folder inside the docker volume.
- **REMOTE_FOLDER**: The subfolder on Dropbox where to save the backups. The path is relative to the application folder specified in the Dropbox configuration.
- **USR**: Is the name of the user which has set the dropbox sync credentials.

Example of `SOURCEDIR`:

    /var/lib/docker/volumes/vaultwarden_volume/_data/bkups

### Automatic backups

To ensure that the backups are saved on Dropbox automatically, just add a cron entry calling the [sync_backups](sync_backups.sh) script.  

How to do this depends on your system.  
On Ubuntu Server 21.04 for Raspberry:

    sudo crontab -e

Paste the following code and save the file

    # Call the backup sync script periodically
    0 * * * * /<path_to_repo_clone>/dropbox_sync/sync_backups.sh
    

> ⚠️ Make sure that the file has a trailing newline!!
> ⚠️ Make sure that the user for which you setup the crontab has access to all the necessary folders!
> The [cronjob](https://man7.org/linux/man-pages/man5/crontab.5.html) above uploads the files every hour. You can modify the interval according to your needs

### Restore backups

- Make sure you have a file with the decryption password in your `dropbox_sync` directory
- Make sure that the file is referenced in `dropbox_sync\CONFIG` file

execute the script `recover_last.sh`

This will create a folder in the same directory of the script (the name is specified in `dropbox_sync\CONFIG`) containing the decrypted files.

At this point you can proceed with two methods:

#### Restore offline

Checkout the name of the container running

    docker ps
    
Read the container name under the appropriate column, then stop it

    docker stop container_name

__cd to `dropbox_sync` folder__

Execute the following code

    source ./CONFIG
    ./recover_last.sh
    cd ${RECOVER}
    mv db* db.sqlite3
    sudo mkdir ${SOURCEDIR} 
    sudo cp * ${SOURCEDIR}/..

Restart the container
    
    docker start container_name


## Notes
The repository is based on [vaultwarden/server](https://hub.docker.com/r/vaultwarden/server) on docker hub
The backup upload script uses [this script](https://github.com/andreafabrizi/Dropbox-Uploader) to communicate with dropbox
