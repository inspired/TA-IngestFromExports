#!/bin/sh

# YOUR VARIABLES
# WE READ FROM HERE:
INPUT_DIR=/data/splunk
# WE MOVE TO THIS DIRECTORY
STAGING_DIR=/data/staging

REMOTE_DEST_USER=ec2-user
REMOTE_DEST_GROUP=splunk
REMOTE_DEST=172.31.28.197
REMOTE_DEST_DIR=/data/imports
SSH_KEY=/home/splunk/.sshkey

# CODE STARTS HERE. DO NOT MODIFY
#
shopt -s globstar

INPUT_DIR="${INPUT_DIR%/}/"
ALLOWED_EXTENSIONS=(ndjson zstd gzip lz4)


for file in "${INPUT_DIR}"/**
do
        dirname=$(dirname ${file})
        filename=$(basename -- "$file")
        extension="${filename##*.}"
        if [[ "$extension" == @(${ALLOWED_EXTENSIONS}) ]]; then
                filename="${filename%.*}"
                date=$(date +"%s")
                filename_with_date=${filename}_${date}
                dir_to_move_to=${STAGING_DIR}/${dirname#$INPUT_DIR}
                file_to_staging=${dir_to_move_to}/${filename_with_date}.${extension}
                filemtime=$(stat -c %Y ${file})
                filesize=$(stat --printf="%s" ${file})
                mtimesince=$((${date} - ${filemtime}))
                echo ${date} action=\"info\" file=\""${file}"\" modtime=${filemtime} size=${filesize}
                # If the file is empty and old, we remove it.
                if [ $filesize -eq 0 ]; then
                        if [ $mtimesince -gt 300 ]; then
                                echo ${date} action=\"delete\" file=\""${file}"\" reason=\"age\"
                                rm -f ${file}
                        fi
                else
                        mkdir -p ${dir_to_move_to} && echo ${date} action=create dir="${dir_to_move_to}"
                        # At this point there is a theoretical chance of data loss. We need to monitor this.
                        cp ${file} ${file_to_staging} && truncate -s 0 ${file} && echo ${date} action=\"copytruncate\" file=\""${file}"\" file_to=\""${file_to_staging}"\"
                fi
        fi
done

# Copy files and delete local staging, ignore 0-byte files. They will be deleted within 300 seconds
rsync --min-size=1 -z -r -t --perms --chown=${REMOTE_DEST_USER}:${REMOTE_DEST_GROUP} --chmod=775 -e "ssh -o ConnectTimeout=10 -o ConnectionAttempts=1 -i ${SSH_KEY}" ${STAGING_DIR}/* ${REMOTE_DEST_USER}@${REMOTE_DEST}:${REMOTE_DEST_DIR} && rm -rf ${STAGING_DIR}/* && echo $(date +"%s") action=\"move\" dir=\""${STAGING_DIR}"\" to=\""${REMOTE_DEST_USER}@${REMOTE_DEST}:${REMOTE_DEST_DIR}"\"
