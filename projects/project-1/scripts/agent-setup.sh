#!/usr/bin/env bash
# Configure Agent 1 for Java 21, Gradle Wrapper builds, tests, and scans.
# The controller's public key is required.
# Run:
#   sudo -E AGENT_SSH_PUBLIC_KEY='ssh-ed25519 AAAA...' bash agent-setup.sh

set -Eeuo pipefail

if [[ "${EUID}" -ne 0 ]]; then
    echo "Run this script as root with sudo." >&2
    exit 1
fi

if [[ -z "${AGENT_SSH_PUBLIC_KEY:-}" ]]; then
    echo "AGENT_SSH_PUBLIC_KEY is required." >&2
    echo "Copy controller-to-agent.pub from the controller setup output." >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "[1/4] Installing Java 21 and build utilities..."
apt-get update
apt-get install -y openjdk-21-jdk git curl unzip ca-certificates openssh-server
systemctl enable --now ssh

echo "[2/4] Creating the dedicated Jenkins agent account..."
if ! id jenkins-agent >/dev/null 2>&1; then
    useradd --create-home --shell /bin/bash jenkins-agent
fi

install -d -m 0700 -o jenkins-agent -g jenkins-agent /home/jenkins-agent/.ssh
authorized_keys=/home/jenkins-agent/.ssh/authorized_keys
touch "$authorized_keys"
chown jenkins-agent:jenkins-agent "$authorized_keys"
chmod 0600 "$authorized_keys"

if ! grep -qxF "$AGENT_SSH_PUBLIC_KEY" "$authorized_keys"; then
    printf '%s\n' "$AGENT_SSH_PUBLIC_KEY" >> "$authorized_keys"
fi

echo "[3/4] Creating the agent workspace and persistent Gradle cache..."
install -d -m 0755 -o jenkins-agent -g jenkins-agent /home/jenkins-agent/agent
install -d -m 0755 -o jenkins-agent -g jenkins-agent /home/jenkins-agent/.gradle

echo "[4/4] Verifying tools..."
sudo -u jenkins-agent java -version
sudo -u jenkins-agent git --version
sudo -u jenkins-agent curl --version | head -n 1

private_ip=$(hostname -I | awk '{print $1}')
java_path=$(readlink -f "$(command -v java)")

echo
echo "=================== JENKINS AGENT DATA ==================="
echo "Node name:              project-1-agent-1"
echo "Host/private IP:        $private_ip"
echo "SSH port:               22"
echo "SSH username:           jenkins-agent"
echo "Credential ID:          project-1-agent-ssh"
echo "Remote root directory:  /home/jenkins-agent/agent"
echo "Node label:             spring-gradle-agent"
echo "Usage:                  Only build matching label expressions"
echo "Launch method:          Launch agents via SSH"
echo "JavaPath (if required): $java_path"
echo "Gradle user home:       /home/jenkins-agent/.gradle"
echo "SSH host-key fingerprint (verify before trusting in Jenkins):"
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
echo "==========================================================="

