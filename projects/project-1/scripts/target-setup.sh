#!/usr/bin/env bash
# Configure the target VM to run Project 1 as a locked-down systemd service.
# The Publish Over SSH public key from the controller is required.
# Run:
#   sudo -E TARGET_SSH_PUBLIC_KEY='ssh-ed25519 AAAA...' bash target-setup.sh

set -Eeuo pipefail

if [[ "${EUID}" -ne 0 ]]; then
    echo "Run this script as root with sudo." >&2
    exit 1
fi

if [[ -z "${TARGET_SSH_PUBLIC_KEY:-}" ]]; then
    echo "TARGET_SSH_PUBLIC_KEY is required." >&2
    echo "Copy jenkins-to-target.pub from the controller setup output." >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "[1/6] Installing Java 21, SSH, and curl..."
apt-get update
apt-get install -y openjdk-21-jre-headless openssh-server curl ca-certificates
systemctl enable --now ssh

echo "[2/6] Creating service and deployment accounts..."
if ! id springapp >/dev/null 2>&1; then
    useradd --system --home-dir /opt/project-1 --shell /usr/sbin/nologin springapp
fi
if ! id deployer >/dev/null 2>&1; then
    useradd --create-home --shell /bin/bash deployer
fi

install -d -m 0700 -o deployer -g deployer /home/deployer/.ssh
authorized_keys=/home/deployer/.ssh/authorized_keys
touch "$authorized_keys"
chown deployer:deployer "$authorized_keys"
chmod 0600 "$authorized_keys"
if ! grep -qxF "$TARGET_SSH_PUBLIC_KEY" "$authorized_keys"; then
    printf '%s\n' "$TARGET_SSH_PUBLIC_KEY" >> "$authorized_keys"
fi

echo "[3/6] Creating deployment directories..."
install -d -m 0755 -o springapp -g springapp /opt/project-1
install -d -m 0755 -o springapp -g springapp /opt/project-1/releases
install -d -m 0755 -o deployer -g deployer /home/deployer/incoming

echo "[4/6] Installing the systemd service..."
cat > /etc/systemd/system/project-1.service <<'UNIT'
[Unit]
Description=Project 1 Spring Boot Application
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=springapp
Group=springapp
WorkingDirectory=/opt/project-1/current
ExecStart=/usr/bin/java -jar /opt/project-1/current/project-1.jar
Environment=SERVER_PORT=8080
Restart=on-failure
RestartSec=5
SuccessExitStatus=143
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/project-1

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable project-1.service

echo "[5/6] Installing the root-owned deployment script with health-check rollback..."
cat > /usr/local/sbin/deploy-project-1.sh <<'DEPLOY'
#!/usr/bin/env bash
# This script is called by Jenkins through the restricted deployer sudo rule.
set -Eeuo pipefail

source_jar="${1:-}"
expected_source=/home/deployer/incoming/project-1.jar
application_root=/opt/project-1
service_name=project-1.service
health_url=http://127.0.0.1:8080/actuator/health

if [[ "$source_jar" != "$expected_source" || ! -f "$source_jar" ]]; then
    echo "Expected deployment artifact: $expected_source" >&2
    exit 1
fi

release_id=$(date -u +%Y%m%d%H%M%S)
release_dir="$application_root/releases/$release_id"
previous_release=$(readlink -f "$application_root/current" 2>/dev/null || true)

install -d -m 0755 -o springapp -g springapp "$release_dir"
install -m 0444 -o springapp -g springapp "$source_jar" "$release_dir/project-1.jar"
rm -f "$source_jar"

# Replace the current release symlink atomically.
ln -sfn "$release_dir" "$application_root/current.next"
mv -Tf "$application_root/current.next" "$application_root/current"

systemctl restart "$service_name"

for attempt in $(seq 1 60); do
    if curl --fail --silent "$health_url" | grep -Fq '"status":"UP"'; then
        echo "Deployment healthy: $health_url"
        echo "Active release: $release_dir"
        exit 0
    fi
    sleep 1
done

echo "New release failed its health check." >&2
journalctl -u "$service_name" -n 50 --no-pager >&2 || true

if [[ -n "$previous_release" && -d "$previous_release" ]]; then
    echo "Rolling back to $previous_release" >&2
    ln -sfn "$previous_release" "$application_root/current.next"
    mv -Tf "$application_root/current.next" "$application_root/current"
    systemctl restart "$service_name"
fi

exit 1
DEPLOY

chown root:root /usr/local/sbin/deploy-project-1.sh
chmod 0755 /usr/local/sbin/deploy-project-1.sh

echo "[6/6] Granting only the exact deployment command..."
cat > /etc/sudoers.d/project-1-deployer <<'SUDOERS'
deployer ALL=(root) NOPASSWD: /usr/local/sbin/deploy-project-1.sh /home/deployer/incoming/project-1.jar
SUDOERS
chmod 0440 /etc/sudoers.d/project-1-deployer
visudo -cf /etc/sudoers.d/project-1-deployer

private_ip=$(hostname -I | awk '{print $1}')

echo
echo "=============== PUBLISH OVER SSH TARGET DATA =============="
echo "Configuration name:     project-1-target"
echo "Hostname/private IP:    $private_ip"
echo "Username:               deployer"
echo "Remote directory:       /home/deployer"
echo "SSH port:               22"
echo "Private key source:     controller file jenkins-to-target"
echo "Transferred file:       /home/deployer/incoming/project-1.jar"
echo "Remote command:         sudo /usr/local/sbin/deploy-project-1.sh /home/deployer/incoming/project-1.jar"
echo "Service:                project-1.service"
echo "Application URL:        http://${private_ip}:8080/"
echo "Health URL:             http://${private_ip}:8080/actuator/health"
echo "SSH host-key fingerprint:"
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
echo
echo "The service is enabled but will start only after the first deployment."
echo "==========================================================="

