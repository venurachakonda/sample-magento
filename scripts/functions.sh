#!/usr/bin/env bash
AWS_BIN="/bin/aws"
OWNER_ID="747476456671"
# APP_NAME
#ASG_NAME
#OWNER_ID
#

function log() {
  echo "$(date -R ) $@"
}

function capture_old_launch_config() {
  LAUNCH_CONFIG_NAME=$(${AWS_BIN} autoscaling describe-auto-scaling-groups --region ${AWS_DEFAULT_REGION} --auto-scaling-group-name ${ASG_NAME} | jq -r '.AutoScalingGroups[].Instances[].LaunchConfigurationName')
  KEY_NAME=$(${AWS_BIN} autoscaling describe-launch-configurations --launch-configuration-names ${LAUNCH_CONFIG_NAME} | jq -r '.LaunchConfigurations[].KeyName' )
  SECURITY_GROUPS=$(${AWS_BIN} autoscaling describe-launch-configurations --launch-configuration-names ${LAUNCH_CONFIG_NAME} | jq -r '.LaunchConfigurations[].SecurityGroups[]')
  INSTANCE_TYPE=$(${AWS_BIN} autoscaling describe-launch-configurations --launch-configuration-names ${LAUNCH_CONFIG_NAME} | jq -r '.LaunchConfigurations[].InstanceType')
  USER_DATA=$(${AWS_BIN} autoscaling describe-launch-configurations --launch-configuration-names ${LAUNCH_CONFIG_NAME} | jq -r '.LaunchConfigurations[].UserData')
}

function capture_asg_nodes() {
  nodes=$(aws autoscaling describe-auto-scaling-groups --region ${AWS_DEFAULT_REGION} --auto-scaling-group-name ${ASG_NAME} | jq -r '.AutoScalingGroups[].Instances[].InstanceId')
}

function create_image() {
  INSTANCE_ID=$(${AWS_BIN} ec2 describe-instances --filter 'Name=instance-state-name,Values=running' | jq -r '.Reservations[].Instances[] | select ((.Tags[]|select(.Key=="Name")|.Value) | match("'"${ASG_NAME}"'") ) | .InstanceId')
  log "Create image from Instance ${INSTANCE_ID}"
  IMAGE_ID=$(${AWS_BIN} ec2 create-image --instance-id ${INSTANCE_ID} \
                                         --name "${JOB_NAME}-${BUILD_NUMBER}" \
                                         --description "An AMI for ${APP_NAME} server" \
                                         --no-reboot --block-device-mappings "[{\"DeviceName\": \"/dev/sdf\",\"Ebs\":{\"VolumeType\":\"gp2\",\"VolumeSize\":50}}]"| jq -r .ImageId)

  check_image_status=$(${AWS_BIN} ec2 describe-images --image-ids ${IMAGE_ID} --owners ${OWNER_ID}  | jq -r .Images[].State)

  COUNTER=0
  until [[ $check_image_status == "available"  ]]; do
      if [[ $COUNTER -gt 10 ]]; then
        log "Image not ready"
        exit 1
      fi
      check_image_status=$(${AWS_BIN} ec2 describe-images --image-ids ${IMAGE_ID} --owners ${OWNER_ID}  | jq -r .Images[].State)
      if [[ $check_image_status == "available"  ]]; then
          log "Image ${IMAGE_ID} is available"
          echo ${IMAGE_ID}
          break
      else
      	log " [$COUNTER] Waiting for image ${IMAGE_ID} to be available"
      fi
  		sleep 30
      let COUNTER=COUNTER+1
  done
}

function create_new_launch_configuration() {
  ${AWS_BIN} autoscaling create-launch-configuration \
    --launch-configuration-name "${APP_NAME}-${BUILD_NUMBER}-lc" \
    --key-name "${KEY_NAME}" \
    --image-id "${IMAGE_ID}" \
    --instance-type "$INSTANCE_TYPE" \
    --security-groups "${SECURITY_GROUPS}" \
    --user-data "${USER_DATA}"
    --block-device-mappings "[{\"DeviceName\": \"/dev/xvda\",\"Ebs\":{\"VolumeSize\":8,\"VolumeType\":\"gp2\",\"DeleteOnTermination\":true}}]"
}

function update_asg_launch_configuration() {
  ${AWS_BIN} autoscaling update-auto-scaling-group --auto-scaling-group-name ${ASG_NAME} --launch-configuration-name "${APP_NAME}-${BUILD_NUMBER}-lc"
}
