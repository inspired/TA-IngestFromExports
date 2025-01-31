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
ALLOWED_FILENAMES=(ndjson zstd gzip lz4)


for file in "${INPUT_DIR}"/**
do
        dirname=$(dirname ${file})
        filename=$(basename -- "$file")
        extension="${filename##*.}"
        if [[ "$extension" == @(${ALLOWED_FILENAMES}) ]]; then
                filename="${filename%.*}"
                date=$(date +"%s")
                filename_with_date=${filename}_${date}
                dir_to_move_to=${STAGING_DIR}/${dirname#$INPUT_DIR}
                #file_to_staging=${STAGING_DIR}/${filename_with_date}.${extension}
                file_to_staging=${dir_to_move_to}/${filename_with_date}.${extension}
                filemtime=$(stat -c %Y ${file})
                filesize=$(stat --printf="%s" ${file})
                mtimesince=$((${date} - ${filemtime}))
                echo MTIME: ${filemtime} and ${filesize}
                # If the file is empty and old, we remove it.
                if [ $filesize -eq 0 ]; then
                        if [ $mtimesince -gt 300 ]; then
                                echo Deleting ${file} because of age
                                rm -f ${file}
                        fi
                else
                        echo Creating ${dir_to_move_to} if required
                        mkdir -p ${dir_to_move_to}
                        echo Copying ${file} to ${file_to_staging}
                        # At this point there is a theoretical chance of data loss. We need to monitor this.
                        cp ${file} ${file_to_staging} && truncate -s 0 ${file}
                fi
        fi
done

# Copy files and delete local staging
rsync -z -r -t --perms --chown=${REMOTE_DEST_USER}:${REMOTE_DEST_GROUP} --chmod=775 -e "ssh -o ConnectTimeout=10 -o ConnectionAttempts=1 -i ${SSH_KEY}" ${STAGING_DIR}/* ${REMOTE_DEST_USER}@${REMOTE_DEST}:${REMOTE_DEST_DIR} && rm -rf ${STAGING_DIR}/*
