#!/usr/bin/env bash
# Configure an Ubuntu 24.04 Jenkins agent for Java and Maven builds.

# Exit on errors, unset variables, and failed pipeline commands.
set -Eeuo pipefail

# Re-run with administrator privileges if the script was started by a normal user.
if [[ "${EUID}" -ne 0 ]]; then
  exec sudo "$0" "$@"
fi

# Prevent apt from asking interactive questions during installation.
export DEBIAN_FRONTEND=noninteractive

# Jenkins connects to this user via SSH using the generated key pair.
agent_user="devopsadmin"
agent_home="/home/${agent_user}"
ssh_directory="${agent_home}/.ssh"
private_key="${ssh_directory}/id_ecdsa"

# Step 1: Refresh Ubuntu package information.
apt-get update

# Step 2: Install the Java runtime, build tools, Git, and SSH server.
apt-get install -y openjdk-21-jre git maven openssh-server

# Ensure that the SSH service starts now and after future reboots.
systemctl enable --now ssh

# Step 3: Create the Jenkins agent account only when it does not already exist.
if ! id -u "${agent_user}" > /dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "${agent_user}"
fi

# Step 4: Create and secure the directory that stores SSH keys for the agent.
install -d -m 700 -o "${agent_user}" -g "${agent_user}" "${ssh_directory}"

# Step 5: Generate an ECDSA key pair once; preserve it on later script runs.
if [[ ! -f "${private_key}" ]]; then
  runuser -u "${agent_user}" -- ssh-keygen -t ecdsa -b 521 \
    -f "${private_key}" -N ""
fi

# Step 6: Authorize the generated public key for SSH login as the agent user.
install -m 600 -o "${agent_user}" -g "${agent_user}" \
  "${private_key}.pub" "${ssh_directory}/authorized_keys"

echo
echo "Jenkins agent prerequisites are installed."
echo "Add this private key to Jenkins as an 'SSH Username with private key' credential:"
echo "  ${private_key}"
echo "Use username '${agent_user}' and this agent's private IP or DNS name in the Jenkins node configuration."
