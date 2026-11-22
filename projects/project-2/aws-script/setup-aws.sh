#!/usr/bin/env bash
# Fresh Ubuntu 24.04 controller and agent in the default VPC.
set -Eeuo pipefail
export AWS_PAGER=""
REGION="${REGION:-ap-southeast-2}"
INSTANCE_TYPE="${INSTANCE_TYPE:-t3.small}"
KEY_NAME="${KEY_NAME:-project-2-keypair}"
KEY_FILE="${KEY_FILE:-${HOME}/project-2-keypair.pem}"
ADMIN_CIDR="${ADMIN_CIDR:?Set ADMIN_CIDR to your public IP/32}"
[[ ! -e "$KEY_FILE" ]] || { echo "Key file exists: $KEY_FILE" >&2; exit 1; }

VPC_ID=$(aws ec2 describe-vpcs --region "$REGION" --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text)
[[ "$VPC_ID" != None && -n "$VPC_ID" ]] || { echo 'No default VPC.' >&2; exit 1; }
SUBNET_ID=$(aws ec2 describe-subnets --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" Name=defaultForAz,Values=true --query 'Subnets[0].SubnetId' --output text)
[[ "$SUBNET_ID" != None && -n "$SUBNET_ID" ]] || { echo 'No default public subnet.' >&2; exit 1; }
AMI_ID=$(aws ec2 describe-images --region "$REGION" --owners 099720109477 --filters \
  'Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*' 'Name=state,Values=available' \
  --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text)
[[ "$AMI_ID" != None && -n "$AMI_ID" ]] || { echo 'No Ubuntu 24.04 AMI.' >&2; exit 1; }

aws ec2 create-key-pair --region "$REGION" --key-name "$KEY_NAME" --query KeyMaterial --output text > "$KEY_FILE"
chmod 400 "$KEY_FILE"
SG_CONTROLLER_ID=$(aws ec2 create-security-group --region "$REGION" --group-name project-2-controller-sg \
  --description 'Project 2 Jenkins controller' --vpc-id "$VPC_ID" --query GroupId --output text)
SG_AGENT_ID=$(aws ec2 create-security-group --region "$REGION" --group-name project-2-agent-sg \
  --description 'Project 2 Jenkins agent' --vpc-id "$VPC_ID" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --region "$REGION" --group-id "$SG_CONTROLLER_ID" \
  --ip-permissions "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=$ADMIN_CIDR}]" \
                   "IpProtocol=tcp,FromPort=8080,ToPort=8080,IpRanges=[{CidrIp=$ADMIN_CIDR}]"
aws ec2 authorize-security-group-ingress --region "$REGION" --group-id "$SG_AGENT_ID" \
  --ip-permissions "IpProtocol=tcp,FromPort=22,ToPort=22,UserIdGroupPairs=[{GroupId=$SG_CONTROLLER_ID}]" \
                   "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=$ADMIN_CIDR}]"
INSTANCE_CONTROLLER=$(aws ec2 run-instances --region "$REGION" --image-id "$AMI_ID" --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" --security-group-ids "$SG_CONTROLLER_ID" --subnet-id "$SUBNET_ID" \
  --associate-public-ip-address --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=project-2-jenkins-controller}]' \
  --query 'Instances[0].InstanceId' --output text)
INSTANCE_AGENT=$(aws ec2 run-instances --region "$REGION" --image-id "$AMI_ID" --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" --security-group-ids "$SG_AGENT_ID" --subnet-id "$SUBNET_ID" \
  --associate-public-ip-address --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=project-2-jenkins-agent}]' \
  --query 'Instances[0].InstanceId' --output text)
aws ec2 wait instance-running --region "$REGION" --instance-ids "$INSTANCE_CONTROLLER" "$INSTANCE_AGENT"
CONTROLLER_IP=$(aws ec2 describe-instances --region "$REGION" --instance-ids "$INSTANCE_CONTROLLER" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
AGENT_IP=$(aws ec2 describe-instances --region "$REGION" --instance-ids "$INSTANCE_AGENT" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
AGENT_PRIVATE_IP=$(aws ec2 describe-instances --region "$REGION" --instance-ids "$INSTANCE_AGENT" --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)
printf 'Controller public IP: %s\nAgent public IP: %s\nAgent private IP: %s\nSSH key: %s\n' \
  "$CONTROLLER_IP" "$AGENT_IP" "$AGENT_PRIVATE_IP" "$KEY_FILE"
echo "SSH as ubuntu: ssh -i '$KEY_FILE' ubuntu@HOST_PUBLIC_IP"
