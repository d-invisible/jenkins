#!/usr/bin/env bash
# Install Jenkins LTS and Java 21 on an Ubuntu 24.04 controller.
set -Eeuo pipefail

if [[ "${EUID}" -ne 0 ]]; then
    echo "Run with sudo: sudo bash $0" >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y fontconfig openjdk-21-jre-headless ca-certificates curl wget gnupg openssh-client
install -d -m 0755 /etc/apt/keyrings
wget -qO /etc/apt/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
echo 'deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/' > /etc/apt/sources.list.d/jenkins.list
apt-get update
apt-get install -y jenkins
systemctl enable --now jenkins

key_dir=/root/project-2-bootstrap-keys
install -d -m 0700 "$key_dir"
if [[ ! -f "$key_dir/controller-to-agent" ]]; then
    ssh-keygen -q -t ed25519 -N '' -C project-2-controller-to-agent -f "$key_dir/controller-to-agent"
fi

private_ip=$(hostname -I | awk '{print $1}')
echo "Jenkins URL:             http://<CONTROLLER-IP>:8080"
echo "Private IP:              $private_ip"
echo "Initial admin password:  sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
echo "Agent credential ID:     project-2-agent-ssh"
echo "Agent SSH username:      jenkins-agent"
echo "Agent private key file:  $key_dir/controller-to-agent"
echo "Copy this public key to the agent setup:"
cat "$key_dir/controller-to-agent.pub"
