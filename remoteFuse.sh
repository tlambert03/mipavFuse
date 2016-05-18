#!/bin/bash

# this script is used to copy files to a remote location and trigger the fusion script there
# it can be used as follows:
# remoteFuse /path/to/parent/directory 0.5

# note, to prevent the need for passwords each time, set up SSH keys.
# https://help.github.com/articles/generating-an-ssh-key/

INPUT=$1 # first argument is the input directory (the one with SPIMA and SPIMB in it)
ZSTEP=$2 # second argument is Z step
[[ ${ZSTEP} ]] || ZSTEP=0.5 # second argument is optional, and will default to this value
NAME=$(basename $INPUT)

#cluster credentials
USER=username
HOST=10.10.10.10 # host ip address
DEST=/destination/directory/ # directory on host to copy files to

# if you routinely use certain parameters, you can adjust this script here
SCRIPT="/path/to/makeMIPAVjobs.sh -n 4 -f 1 -z $ZSTEP"

rsync -rzv $INPUT $USER@$HOST:$DEST

ssh $USER@$HOST ". /opt/lsf/conf/profile.lsf; $SCRIPT $DEST/$NAME"
