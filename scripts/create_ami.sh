#!/usr/bin/env bash
cd $(dirname "$0")

OWNER_ID="747476456671"
JOB_NAME=${1}
BUILD_NUMBER=${2}
APP_NAME=${3}
ASG_NAME=${4}

source ./functions.sh

create_image
log "IMAGE ID: ${IMAGE_ID}"
return ${IMAGE_ID}
