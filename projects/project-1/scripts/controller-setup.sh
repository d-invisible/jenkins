#!/usr/bin/env bash
# Configure the Jenkins controller (formerly called master) on Ubuntu 24.04.
# Run: sudo bash controller-setup.sh

set -Eeuo pipefail

if [[ "${EUID}" -ne 0 ]]; then
    echo "Run this script as root: sudo bash $0" >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "[1/5] Installing Java 21 and base utilities..."
apt-get update
apt-get install -y fontconfig openjdk-21-jre-headless ca-certificates curl wget gnupg jq openssh-client

echo "[2/5] Adding the Jenkins LTS package repository..."
install -d -m 0755 /etc/apt/keyrings
wget -qO /etc/apt/keyrings/jenkins-keyring.asc \
    https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
    > /etc/apt/sources.list.d/jenkins.list

echo "[3/5] Installing and starting Jenkins..."
apt-get update
apt-get install -y jenkins
systemctl enable --now jenkins

echo "[4/5] Creating dedicated SSH key pairs for the agent and target..."
key_dir=/root/project-1-bootstrap-keys
install -d -m 0700 "$key_dir"

if [[ ! -f "$key_dir/controller-to-agent" ]]; then
    ssh-keygen -q -t ed25519 -N '' \
        -C project-1-controller-to-agent \
        -f "$key_dir/controller-to-agent"
fi

if [[ ! -f "$key_dir/jenkins-to-target" ]]; then
    ssh-keygen -q -t ed25519 -N '' \
        -C project-1-jenkins-to-target \
        -f "$key_dir/jenkins-to-target"
fi

echo "[5/5] Collecting values for Jenkins configuration..."
private_ip=$(hostname -I | awk '{print $1}')
public_ip='not detected'
metadata_token=$(curl -fsS --max-time 2 -X PUT \
    -H 'X-aws-ec2-metadata-token-ttl-seconds: 60' \
    http://169.254.169.254/latest/api/token 2>/dev/null || true)
if [[ -n "$metadata_token" ]]; then
    public_ip=$(curl -fsS --max-time 2 \
        -H "X-aws-ec2-metadata-token: $metadata_token" \
        http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo 'not assigned')
fi

echo
echo "================ JENKINS CONTROLLER DATA ================"
echo "Jenkins service:       $(systemctl is-active jenkins)"
echo "Java:                  $(java -version 2>&1 | head -n 1)"
echo "Private IP:             $private_ip"
echo "Public IP:              $public_ip"
echo "Jenkins URL:            http://${public_ip}:8080"
echo "Initial password file:  /var/lib/jenkins/secrets/initialAdminPassword"
echo "Show initial password:  sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
echo
echo "Agent credential ID:    project-1-agent-ssh"
echo "Agent SSH username:     jenkins-agent"
echo "Agent private key file: $key_dir/controller-to-agent"
echo "Agent public key (use when running agent-setup.sh):"
cat "$key_dir/controller-to-agent.pub"
echo
echo "Target Publish Over SSH key file: $key_dir/jenkins-to-target"
echo "Target public key (use when running target-setup.sh):"
cat "$key_dir/jenkins-to-target.pub"
echo
echo "Install Jenkins plugins from Manage Jenkins > Plugins:"
echo "  Pipeline, Git, GitHub, JUnit, SSH Build Agents,"
echo "  Publish Over SSH, Email Extension, Credentials Binding"
echo "==========================================================="

