#!/usr/bin/env bash
AWS_BIN="/usr/bin/aws"
OWNER_ID="747476456671"
NODE_SLEEP_INTERVAL=15
NODE_INITIAL_WAIT_PERIOD=10



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

function create_image() {
  INSTANCE_ID=$(${AWS_BIN} ec2 describe-instances --filter 'Name=instance-state-name,Values=running' | jq -r '.Reservations[].Instances[] | select ((.Tags[]|select(.Key=="Name")|.Value) | match("'"${ASG_NAME}"'") ) | .InstanceId')
  IMAGE_ID=$(${AWS_BIN} ec2 create-image --instance-id ${INSTANCE_ID} \
                                         --name "${JOB_NAME}-${BUILD_NUMBER}" \
                                         --description "An AMI for ${APP_NAME} server" \
                                         --no-reboot \
                                         --block-device-mappings "[{\"DeviceName\": \"/dev/sdf\",\"Ebs\":{\"VolumeType\":\"gp2\",\"VolumeSize\":50}}]"| jq -r .ImageId)
  echo "${IMAGE_ID}"
}

function tag_image() {
  ${AWS_BIN} ec2 create-tags --resources ${IMAGE_ID} --tags Key=Name,Value="${JOB_NAME}-${BUILD_NUMBER}"   Key=asg,Value=${ASG_NAME}
}

function get_device_mappings() {
  case ${Target} in
    dev )
      BLOCK_DEVICE_MAPPINGS="'[{\"DeviceName\": \"/dev/sda1\",\"Ebs\":{\"VolumeSize\":50,\"VolumeType\":\"gp2\",\"DeleteOnTermination\":true}}]'"
      ;;
    qa )
      BLOCK_DEVICE_MAPPINGS=""
      ;;
    uat)
      BLOCK_DEVICE_MAPPINGS=""
      ;;
    production)
      BLOCK_DEVICE_MAPPINGS=""
      ;;
    *)
      echo "invalid environment $Target"
      ;;
  esac
}


function check_image_status() {
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
          break
      else
      	log " [$COUNTER] Waiting for image ${IMAGE_ID} to be available"
      fi
  		sleep 30
      let COUNTER=COUNTER+1
  done
}

function create_new_launch_configuration() {
  get_device_mappings
  ${AWS_BIN} autoscaling create-launch-configuration \
    --launch-configuration-name "${APP_NAME}-${BUILD_NUMBER}-lc" \
    --key-name "${KEY_NAME}" \
    --image-id "${IMAGE_ID}" \
    --instance-type "$INSTANCE_TYPE" \
    --security-groups ${SECURITY_GROUPS} \
    --user-data "${USER_DATA}" \
    --block-device-mappings "${BLOCK_DEVICE_MAPPINGS}"
}

function update_asg_launch_configuration() {
  ${AWS_BIN} autoscaling update-auto-scaling-group --auto-scaling-group-name ${ASG_NAME} --launch-configuration-name "${APP_NAME}-${BUILD_NUMBER}-lc"
}

# AutoScalingGroups scaling

function check_aws_connectivity() {
  success="true"
  while true; do
    log "Checking connectivity to AWS API. "
    RESULT=$(${AWS_BIN} autoscaling describe-auto-scaling-groups --region ${AWS_DEFAULT_REGION}) || success="false"
    [ "$success" = "false" ] && exit 5
    [ "$success" = "true" ] && break
  done
}

function capture_asg_nodes() {
  nodes=$(${AWS_BIN} autoscaling describe-auto-scaling-groups --region ${AWS_DEFAULT_REGION} --auto-scaling-group-name ${ASG_NAME} | jq -r '.AutoScalingGroups[].Instances[].InstanceId')
  echo $nodes | tr " " "\n" > asg_nodes
}


function retry_timeout() {
  max_retries=$1
  current_retry=$2
  task=$3

  if [ ${current_retry} -ge ${max_retries} ]; then
    log "Timeout. Max retries exceeded for " $task
    exit 1
  fi
}


###############

function check_asg_state() {

  node_count=$(cat asg_nodes | wc -l | tr -d ' ')
  log "Total VMs in the ASG ${ASG_NAME} : $node_count"

  desired_capacity=$(${AWS_BIN} autoscaling describe-auto-scaling-groups --auto-scaling-group-name ${ASG_NAME} --region ${AWS_DEFAULT_REGION} | jq '.AutoScalingGroups[].DesiredCapacity')
  min_size=$(${AWS_BIN} autoscaling describe-auto-scaling-groups --auto-scaling-group-name ${ASG_NAME} --region ${AWS_DEFAULT_REGION} | jq '.AutoScalingGroups[].MinSize')
  max_size=$(${AWS_BIN} autoscaling describe-auto-scaling-groups --auto-scaling-group-name ${ASG_NAME} --region ${AWS_DEFAULT_REGION} | jq '.AutoScalingGroups[].MaxSize')
  if [[ $max_size -lt $(( 2*desired_capacity )) ]]; then
    log "${ASG_NAME} Max size ($max_size) should be >= 2x the desired capacity ($desired_capacity)."
    double_max_size=$(( desired_capacity * 2 ))
    log "Setting the Max size to ($double_max_size) for ${ASG_NAME}"
    ${AWS_BIN} autoscaling update-auto-scaling-group --auto-scaling-group-name ${ASG_NAME} --region ${AWS_DEFAULT_REGION} --max-size $double_max_size
  else
    log "${ASG_NAME} Desired capacity $desired_capacity, Max size $max_size, Min size $min_size."
  fi

  current_instances=$(${AWS_BIN} autoscaling describe-auto-scaling-groups --auto-scaling-group-name ${ASG_NAME} --region ${AWS_DEFAULT_REGION} | jq -r '.AutoScalingGroups[0].Instances[].LifecycleState' | wc -l | tr -d ' ')
  if [[ $current_instances -ne $desired_capacity ]]; then
    log "ERROR: ${ASG_NAME} may not be at its desired capacity. Current instances $current_instances. Desired instances: $desired_capacity"
    exit 5
  else
    log "${ASG_NAME} is at its desired capacity. Current instances $current_instances. Desired instances: $desired_capacity"
  fi
}


function double_capacity() {
  group=${ASG_NAME}
  capacity=$(${AWS_BIN} autoscaling describe-auto-scaling-groups --auto-scaling-group-name $group --region ${AWS_DEFAULT_REGION} | jq '.AutoScalingGroups[].DesiredCapacity')
  desired=$(( capacity * 2 ))
  log "Current desired capacity for $group is: $capacity, setting it to $desired"
  ${AWS_BIN} autoscaling set-desired-capacity --auto-scaling-group-name $group --desired-capacity $desired --region ${AWS_DEFAULT_REGION}
}

function wait_for_desired_nodes() {
  group=${ASG_NAME}
  count=$(${AWS_BIN} autoscaling describe-auto-scaling-groups --auto-scaling-group-name $group --region ${AWS_DEFAULT_REGION} | jq -r '.AutoScalingGroups[0].DesiredCapacity')
  sleep $NODE_INITIAL_WAIT_PERIOD
  retries=0
  while true; do
    updated_node_count=$(${AWS_BIN} autoscaling describe-auto-scaling-groups --region ${AWS_DEFAULT_REGION} --auto-scaling-group-name ${ASG_NAME} | jq -r '.AutoScalingGroups[].Instances[].InstanceId' | wc -l | tr -d ' ')
    msg="Waiting for nodes in ASG. Nodes found $updated_node_count. Expected nodes $count."
    log $msg
    [[  $updated_node_count -eq $count ]] && break
    retry_timeout 200 $retries $msg
    ((retries++))
    sleep $NODE_SLEEP_INTERVAL
  done
}

function reset_capacity() {
  group=${ASG_NAME}
  desired_capacity=$(${AWS_BIN} autoscaling describe-auto-scaling-groups --auto-scaling-group-name $group --region ${AWS_DEFAULT_REGION} | jq '.AutoScalingGroups[].DesiredCapacity')
  min_size=$(${AWS_BIN} autoscaling describe-auto-scaling-groups --auto-scaling-group-name $group --region ${AWS_DEFAULT_REGION} | jq '.AutoScalingGroups[].MinSize')
  max_size=$(${AWS_BIN} autoscaling describe-auto-scaling-groups --auto-scaling-group-name $group --region ${AWS_DEFAULT_REGION} | jq '.AutoScalingGroups[].MaxSize')

  if [[ $max_size -eq $(( 2*desired_capacity )) ]]; then
    log "Nothing to do. $group Desired capacity $desired_capacity, Max size $max_size, Min size $min_size."
    exit 0
  elif [[ $max_size -ne $desired_capacity ]]; then
    log "$group Desired capacity $desired_capacity, Max size $max_size, Min size $min_size."
  fi

  log "Gradually resetting the desired capacity to max_size/2."
  log "This is a DESTRUCTIVE process that will delete instances from the current cluster. Please Ctrl C in the next 20 seconds if you want to quit."
  sleep 20
  while true; do
    desired_capacity=$(${AWS_BIN} autoscaling describe-auto-scaling-groups --auto-scaling-group-name $group --region ${AWS_DEFAULT_REGION} | jq '.AutoScalingGroups[].DesiredCapacity')
    tmp_capacity=$(( desired_capacity - 1 ))
    [[ $max_size -gt $(( 2*tmp_capacity )) ]] && break
    log "Current desired capacity for $group is: $desired_capacity, setting it to $tmp_capacity"
    ${AWS_BIN} autoscaling set-desired-capacity --auto-scaling-group-name $group --desired-capacity $tmp_capacity --region ${AWS_DEFAULT_REGION}
    wait_for_desired_nodes
  done
}
