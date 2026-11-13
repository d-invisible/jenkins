You can install Jenkins on an Ubuntu VM (AWS EC2, Azure VM, VirtualBox, or a local Ubuntu VM).

For your DevOps practice, I recommend installing Jenkins directly on Ubuntu first, without Docker. This will help you understand Java, systemd services, ports, plugins, and CI/CD.

We'll install Jenkins using its official Debian package repository.

## 1. VM requirements

Recommended VM configuration

| Resource     | Recommendation                      |
| ------------ | ----------------------------------- |
| OS           | Ubuntu 24.04 LTS                    |
| CPU          | 2 vCPU                              |
| RAM          | 4 GB                                |
| Storage      | 25 GB                               |
| Network      | Public IP or private network access |
| Jenkins port | 8080                                |
| SSH port     | 22                                  |

## 2. Install Java 21

Jenkins requires Java. Install Java 21:

```
sudo apt update
sudo apt install fontconfig openjdk-21-jre -y
```

Verify:

```
java -version
```

Expected: OpenJDK 21.

## 3. Add Jenkins official repository

We'll install the Jenkins LTS (Long-Term Support) release, which is preferable for learning and stable environments.

```
sudo mkdir -p /etc/apt/keyrings

sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
```

Add the repository:

```
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" \
https://pkg.jenkins.io/debian-stable binary/ | \
sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
```

Install Jenkins:

```
sudo apt update
sudo apt install jenkins -y
```

These commands follow the official Jenkins installation guide.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://www.jenkins.io\&sz=32)

Jenkins+1



## 4. Start Jenkins service

```
sudo systemctl enable jenkins
sudo systemctl start jenkins
```

Check status:

```
sudo systemctl status jenkins
```

Expected:

Active: active (running)

Useful service commands:

```
sudo systemctl stop jenkins
sudo systemctl restart jenkins
sudo systemctl status jenkins
```

## 5. Configure VM firewall / cloud security group

Jenkins uses port `8080` by default.

If you're using an Azure or AWS VM, configure its inbound network rule:

| Setting  | Value          |
| -------- | -------------- |
| Protocol | TCP            |
| Port     | 8080           |
| Source   | Your public IP |
| Action   | Allow          |



Security

&#x20;Don't expose Jenkins port 8080 to the entire internet (`0.0.0.0/0`) for routine practice.



If Ubuntu UFW is enabled:

```
sudo ufw allow from YOUR_PUBLIC_IP to any port 8080 proto tcp
```

## 6. Open Jenkins in browser

Navigate to:

```
http://YOUR_VM_PUBLIC_IP:8080
```

You should see the Jenkins unlock screen.

## 7. Unlock Jenkins

Get the initial admin password:

```
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Copy the password and paste it into the Jenkins browser page.

Then:

1. Select Install suggested plugins.
2. Wait for installation.
3. Create your administrator account.
4. Click Start using Jenkins.

