# Set Up an Apache Tomcat QA Server on Ubuntu 24.04

This guide configures a separate Ubuntu VM as a Tomcat deployment target for
Java web application (`.war`) files built by Jenkins.

## Architecture

| Server | Purpose | Required software |
| --- | --- | --- |
| Jenkins controller | Orchestrates jobs | Git, Java, Jenkins |
| Jenkins build agent | Builds the application | Git, Java, Maven |
| Tomcat QA server | Runs deployed `.war` files | Java, Tomcat, SSH server |

The deployment flow is:

```text
Jenkins build agent: target/*.war  -->  Tomcat QA server: /opt/tomcat/webapps/
```

The Jenkins job transfers the artifact using SSH. Tomcat detects the WAR file
in `webapps` and deploys it.

## 1. Prepare the Ubuntu VM

Launch an Ubuntu Server 24.04 LTS VM for the Tomcat QA server.

| Rule | Port | Allowed source |
| --- | --- | --- |
| SSH | `22` | Jenkins controller/build-agent security group or trusted IP |
| Tomcat HTTP | `8080` | Testers, load balancer, or trusted network |

> Do not open SSH or Tomcat to all internet addresses in a production
> environment.

## 2. Install and configure Tomcat

Run the script in this directory on the Tomcat VM:

```bash
chmod +x setup-tomcat.sh
./setup-tomcat.sh
```

The script installs Java 21, Tomcat 10, and OpenSSH. It creates a deployment
user named `tomcatdeploy`, then makes that user the owner of Tomcat's `webapps`
directory. The Tomcat service group retains write access so it can expand and
deploy WAR files.

### Manual setup

#### Step 1: Update Ubuntu package information

```bash
sudo apt update
```

#### Step 2: Install Java, Tomcat, and the SSH server

```bash
sudo apt install -y openjdk-21-jre tomcat10 openssh-server
```

#### Step 3: Start Tomcat and SSH

```bash
sudo systemctl enable --now tomcat10 ssh
sudo systemctl status tomcat10 --no-pager
```

#### Step 4: Create a deployment user

```bash
sudo useradd --create-home --shell /bin/bash tomcatdeploy
sudo usermod -aG tomcat tomcatdeploy
```

#### Step 5: Set ownership and permissions for `webapps`

Ubuntu's Tomcat package stores application files in `/var/lib/tomcat10/webapps`.
The following commands make `/opt/tomcat` point to that location, so the target
path used by Jenkins is `/opt/tomcat/webapps`.

```bash
sudo ln -s /var/lib/tomcat10 /opt/tomcat
sudo chown -R tomcatdeploy:tomcat /var/lib/tomcat10/webapps
sudo chmod -R g+rwX /var/lib/tomcat10/webapps
sudo find /var/lib/tomcat10/webapps -type d -exec chmod 2775 {} \;
```

`tomcatdeploy` owns the directory, while the `tomcat` group can write deployed
files. The set-group-ID permission (`2775`) ensures new directories retain the
`tomcat` group.

#### Step 6: Verify Tomcat

```bash
java -version
sudo systemctl status tomcat10 --no-pager
```

Open `http://<tomcat-server-ip>:8080/` from an allowed network to confirm that
the server is reachable.

## 3. Configure SSH access for Jenkins

Jenkins needs an SSH key that can log in as `tomcatdeploy`.

1. Create or reuse a key pair on the Jenkins controller/build agent.
2. Add its public key to `/home/tomcatdeploy/.ssh/authorized_keys` on the
   Tomcat server.
3. Store the matching private key in Jenkins Credentials.

Example on the Tomcat server:

```bash
sudo install -d -m 700 -o tomcatdeploy -g tomcatdeploy /home/tomcatdeploy/.ssh
sudo tee /home/tomcatdeploy/.ssh/authorized_keys > /dev/null
sudo chown tomcatdeploy:tomcatdeploy /home/tomcatdeploy/.ssh/authorized_keys
sudo chmod 600 /home/tomcatdeploy/.ssh/authorized_keys
```

Paste the Jenkins public key at the `tee` prompt, then press `Ctrl+D`.

## 4. Publish the WAR file from Jenkins

Install the **Publish Over SSH** plugin (`publish-over-ssh`) in Jenkins. The
plugin can transfer artifacts over SFTP and execute remote commands. Configure
the Tomcat host under **Manage Jenkins** → **Configure System** → **SSH
Servers**, using the `tomcatdeploy` SSH credential. [Jenkins plugin
documentation](https://plugins.jenkins.io/publish-over-ssh) describes this host
configuration and the publisher options.

In the job's post-build action, add **Send build artifacts over SSH** and use a
transfer set similar to this:

| Field | Value |
| --- | --- |
| Source files | `target/*.war` |
| Remove prefix | `target` |
| Remote directory | `/opt/tomcat/webapps` |

After a successful build, verify the deployed application at:

```text
http://<tomcat-server-ip>:8080/<application-context>/
```

## Troubleshooting

```bash
# Tomcat service logs
sudo journalctl -u tomcat10 -n 100 --no-pager

# Confirm the Jenkins deployment user can write to the deployment directory
sudo -u tomcatdeploy touch /opt/tomcat/webapps/.write-test
sudo rm /opt/tomcat/webapps/.write-test

# View Tomcat application files
ls -la /opt/tomcat/webapps
```
