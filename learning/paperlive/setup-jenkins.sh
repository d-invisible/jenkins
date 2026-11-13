#!/usr/bin/env bash
# Install Jenkins LTS and its dependencies on Ubuntu 24.04.

# Exit on errors, unset variables, and failed commands in pipelines.
set -Eeuo pipefail

# Re-run the script with administrator privileges when required.
if [[ "${EUID}" -ne 0 ]]; then
  exec sudo "$0" "$@"
fi

# Prevent apt from asking interactive questions during installation.
export DEBIAN_FRONTEND=noninteractive

# Step 1: Refresh Ubuntu package information.
apt-get update

# Step 2: Install Java 21 and the packages needed to download Jenkins.
# ca-certificates verifies HTTPS downloads; curl retrieves the Jenkins signing key.
apt-get install -y ca-certificates curl fontconfig git openjdk-21-jre

# Step 3: Create the keyring directory and download the Jenkins signing key.
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key \
  -o /etc/apt/keyrings/jenkins-keyring.asc
chmod a+r /etc/apt/keyrings/jenkins-keyring.asc

# Step 4: Configure the official Jenkins LTS package repository.
cat > /etc/apt/sources.list.d/jenkins.list <<'EOF'
deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/
EOF

# Step 5: Refresh package information, now including the Jenkins repository.
apt-get update

# Step 6: Install Jenkins.
apt-get install -y jenkins

# Step 7: Configure Jenkins to start now and automatically after reboots.
systemctl enable --now jenkins

# Display the Jenkins URL and the command for retrieving the unlock password.
echo
echo "Jenkins is installed and running."
echo "Open: http://<server-public-ip>:8080/"
echo "Initial password: sudo cat /var/lib/jenkins/secrets/initialAdminPassword"

# Print the one-time initial administrator password for the Jenkins setup wizard.
cat /var/lib/jenkins/secrets/initialAdminPassword
