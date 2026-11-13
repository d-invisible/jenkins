# Set Up Jenkins on Ubuntu 24.04

This guide installs the Jenkins LTS package on an Ubuntu 24.04 EC2 instance
using Java 21.

Official Jenkins documentation: <https://www.jenkins.io/doc/book/installing/linux/>

## 1. Prepare the EC2 instance

Create an EC2 instance with the following baseline configuration:

| Setting | Suggested value |
| --- | --- |
| AMI | Ubuntu Server 24.04 LTS |
| Instance type | `t2.micro` (for a demo) |
| SSH access | TCP port `22`, limited to your IP address |
| Jenkins access | TCP port `8080`, limited to your IP address or trusted network |

> Do not allow all inbound traffic in a real environment. Restrict security-group
> rules to the smallest trusted source range.

## 2. Install Jenkins

You can run the setup script in this directory:

```bash
chmod +x setup-jenkins.sh
./setup-jenkins.sh
```

The script installs Git, Java 21, and Jenkins, then enables and starts the
Jenkins service. Review the script before running it in a production account.

### Manual installation

If you prefer to run the commands yourself, complete these steps in order.

#### Step 1: Update Ubuntu package information

```bash
sudo apt update
```

#### Step 2: Install Jenkins prerequisites

```bash
sudo apt install -y ca-certificates curl fontconfig git openjdk-21-jre
```

`ca-certificates` lets Ubuntu verify HTTPS downloads, while `curl` downloads
the Jenkins repository key. Java 21 is required to run Jenkins.

#### Step 3: Add the Jenkins signing key

```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key \
  | sudo tee /etc/apt/keyrings/jenkins-keyring.asc > /dev/null
sudo chmod a+r /etc/apt/keyrings/jenkins-keyring.asc
```

#### Step 4: Add the Jenkins package repository

```bash
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/" \
  | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
```

#### Step 5: Install Jenkins

```bash
sudo apt update
sudo apt install -y jenkins
```

#### Step 6: Enable and start Jenkins

```bash
sudo systemctl enable --now jenkins
```

#### Step 7: Verify the installation

```bash
git --version
java -version
jenkins --version
sudo systemctl status jenkins --no-pager
```

## 3. Complete the initial Jenkins setup

1. In a browser, open `http://<public-ip-address>:8080/`.
2. Obtain the initial administrator password:

   ```bash
   sudo cat /var/lib/jenkins/secrets/initialAdminPassword
   ```

3. Paste the password into the Jenkins unlock screen and follow the setup
   wizard to install plugins and create an administrator account.

The default Jenkins home directory is `/var/lib/jenkins`.

## Service management

```bash
sudo systemctl status jenkins
sudo systemctl start jenkins
sudo systemctl stop jenkins
sudo systemctl restart jenkins
sudo systemctl enable jenkins
```

## Troubleshooting

If Jenkins does not start, inspect its service logs:

```bash
sudo journalctl -u jenkins -n 100 --no-pager
```

Confirm that the EC2 security group permits trusted traffic to TCP port `8080`.
