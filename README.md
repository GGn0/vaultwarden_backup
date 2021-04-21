# bitwarden_backup
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
for other environmental variables to set, refer to the original [bitwardenrs/server](https://hub.docker.com/r/bitwardenrs/server) documentation.
(for example, SIGNUPS_ALLOWED=false to disable logins or ADMIN_TOKEN=token to give access to the admin page)

From the project directory it's possible to build the image with the following command:
```sh
docker build --rm -t bitwarden_backup .
```
--rm specifies to remove intermediate images used in the building process
-t assign a tag to the image
. Sets the context of the build to the current directory

### Step 2:
Create a volume, either from portainer or from the command line.
This is necessary to expose the backups to the local machine.

Next run a container using the image and volume that we just prepared

```sh
docker run -d -v volume_name:/data -p XXX:80 --name container_name image_name
```
-d runs the container in detached mode
-v specifies the volume (__volume_name__) to mount in the container internal directory /data
-p publishes the container port 80 on the host port __XXX__
--name specifies the container name (__container_name__)
__image_name__ is the name of the image previously built

### Step 3:
TODO
backup encrypt and upload on dropbox

## Notes
The repository is based on [bitwardenrs/server](https://hub.docker.com/r/bitwardenrs/server) on docker hub
The backup upload script uses [this script](https://github.com/andreafabrizi/Dropbox-Uploader) to communicate with dropbox
