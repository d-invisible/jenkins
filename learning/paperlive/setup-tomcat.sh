#!/usr/bin/env bash
# Configure an Ubuntu 24.04 Tomcat QA server for Jenkins WAR deployments.

# Exit on errors, unset variables, and failed pipeline commands.
set -Eeuo pipefail

# Re-run with administrator privileges if the script was started by a normal user.
if [[ "${EUID}" -ne 0 ]]; then
  exec sudo "$0" "$@"
fi

# Prevent apt from asking interactive questions during installation.
export DEBIAN_FRONTEND=noninteractive

# This account receives WAR files transferred by Jenkins over SSH.
deploy_user="tomcatdeploy"
tomcat_home="/var/lib/tomcat10"
webapps_directory="${tomcat_home}/webapps"
tomcat_link="/opt/tomcat"

# Step 1: Refresh Ubuntu package information.
apt-get update

# Step 2: Install Java 21, the Tomcat 10 service, and OpenSSH.
apt-get install -y openjdk-21-jre tomcat10 openssh-server

# Step 3: Start Tomcat and SSH now, and automatically after future reboots.
systemctl enable --now tomcat10 ssh

# Step 4: Create the Jenkins deployment account only when it does not exist.
if ! id -u "${deploy_user}" > /dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "${deploy_user}"
fi

# Let the deployment user share Tomcat's service group permissions.
usermod -aG tomcat "${deploy_user}"

# Step 5: Prepare the deployment user's SSH directory for the Jenkins public key.
install -d -m 700 -o "${deploy_user}" -g "${deploy_user}" \
  "/home/${deploy_user}/.ssh"
touch "/home/${deploy_user}/.ssh/authorized_keys"
chown "${deploy_user}:${deploy_user}" "/home/${deploy_user}/.ssh/authorized_keys"
chmod 600 "/home/${deploy_user}/.ssh/authorized_keys"

# Step 6: Provide the familiar /opt/tomcat path without duplicating Tomcat files.
if [[ ! -e "${tomcat_link}" ]]; then
  ln -s "${tomcat_home}" "${tomcat_link}"
fi

# Step 7: Make the deployment user own webapps, while Tomcat keeps group write access.
chown -R "${deploy_user}:tomcat" "${webapps_directory}"
chmod -R g+rwX "${webapps_directory}"
find "${webapps_directory}" -type d -exec chmod 2775 {} \;

echo
echo "Tomcat is installed and running."
echo "Deploy WAR files as '${deploy_user}' to: ${tomcat_link}/webapps"
echo "Tomcat URL: http://<server-public-ip>:8080/"
echo "Add the Jenkins public key to /home/${deploy_user}/.ssh/authorized_keys."
