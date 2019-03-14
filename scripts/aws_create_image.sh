#!/usr/bin/env bash

AWS_BIN="/bin/aws"
OWNER_ID="747476456671"

INSTANCE_ID=$(${AWS_BIN} ec2 describe-instances | jq -r '.Reservations[].Instances[] | select ((.Tags[]|select(.Key=="Name")|.Value) | match("vr") ) | .InstanceId')
echo "Create image from Instance ${INSTANCE_ID}"
IMAGE_ID=$(${AWS_BIN} ec2 create-image --instance-id ${INSTANCE_ID} --name "vr-magento" --description "An AMI for my server" --no-reboot | jq -r .ImageId)

check_image_status=$(${AWS_BIN} ec2 describe-images --image-ids ${IMAGE_ID} --owners ${OWNER_ID}  | jq -r .Images[].State)

COUNTER=0
until [[ $check_image_status == "available"  ]]; do
    if [[ $COUNTER -gt 10 ]]; then
      echo "Image not ready"
      exit 1
    fi
    check_image_status=$(${AWS_BIN} ec2 describe-images --image-ids ${IMAGE_ID} --owners ${OWNER_ID}  | jq -r .Images[].State)
    if [[ $check_image_status == "available"  ]]; then
        echo "Image ${IMAGE_ID} is available"
        break
    else
    	echo " [$COUNTER] Waiting for image ${IMAGE_ID} to be available"
    fi
		sleep 30
    let COUNTER=COUNTER+1
done

echo "IMAGE ID: ${IMAGE_ID}"
