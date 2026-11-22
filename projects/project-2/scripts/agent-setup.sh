#!/usr/bin/env bash
# Install Java 21, Git, and Docker Engine for a dedicated Jenkins build agent.
# Run with: sudo -E AGENT_SSH_PUBLIC_KEY='ssh-ed25519 AAAA...' bash agent-setup.sh
set -Eeuo pipefail

if [[ "${EUID}" -ne 0 ]]; then
    echo "Run with sudo: sudo -E AGENT_SSH_PUBLIC_KEY='...' bash $0" >&2
    exit 1
fi
if [[ -z "${AGENT_SSH_PUBLIC_KEY:-}" ]]; then
    echo "AGENT_SSH_PUBLIC_KEY is required (copy it from the controller setup output)." >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y openjdk-21-jdk git curl unzip ca-certificates openssh-server docker.io
systemctl enable --now ssh docker

if ! id jenkins-agent >/dev/null 2>&1; then
    useradd --create-home --shell /bin/bash jenkins-agent
fi
usermod -aG docker jenkins-agent
install -d -m 0700 -o jenkins-agent -g jenkins-agent /home/jenkins-agent/.ssh
touch /home/jenkins-agent/.ssh/authorized_keys
chown jenkins-agent:jenkins-agent /home/jenkins-agent/.ssh/authorized_keys
chmod 0600 /home/jenkins-agent/.ssh/authorized_keys
grep -qxF "$AGENT_SSH_PUBLIC_KEY" /home/jenkins-agent/.ssh/authorized_keys || \
    printf '%s\n' "$AGENT_SSH_PUBLIC_KEY" >> /home/jenkins-agent/.ssh/authorized_keys
install -d -m 0755 -o jenkins-agent -g jenkins-agent /home/jenkins-agent/agent /home/jenkins-agent/.gradle

echo "Node name:             project-2-agent-1"
echo "Private IP:            $(hostname -I | awk '{print $1}')"
echo "SSH username:          jenkins-agent"
echo "Credential ID:         project-2-agent-ssh"
echo "Remote root:           /home/jenkins-agent/agent"
echo "Node label:            jenkins-agent-node-label"
echo "Java path:             $(readlink -f "$(command -v java)")"
echo "Docker version:        $(docker --version)"
echo "Agent SSH host key fingerprint (verify in Jenkins):"
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
echo "Docker group access allows root-equivalent control of this agent. Keep it dedicated to trusted jobs."
