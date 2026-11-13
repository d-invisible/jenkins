# Set Up Jenkins Agent 1 for a Java Maven Project

This guide prepares an Ubuntu 24.04 server to run Jenkins jobs for Java and
Maven projects. Jenkins now calls worker machines **agents**; older material
may call them "slave nodes."

## 1. Prepare the Ubuntu agent instance

Launch an Ubuntu Server 24.04 LTS EC2 instance. The Jenkins controller must be
able to reach this server over SSH.

| Setting | Suggested value |
| --- | --- |
| AMI | Ubuntu Server 24.04 LTS |
| SSH access | TCP port `22`, allowed only from the Jenkins controller security group or a trusted IP |
| Jenkins web access | Not required on the agent |

> Do not expose the agent's SSH port to `0.0.0.0/0` in a production setup.

## 2. Set up the agent

Run the script in this directory on the Ubuntu agent:

```bash
chmod +x setup-slave-1.sh
./setup-slave-1.sh
```

It installs Java 21, Git, Maven, and the SSH server. It also creates the
`devopsadmin` user and an SSH key pair for Jenkins to use.

### Manual setup

Complete these steps in order if you prefer to run the commands manually.

#### Step 1: Update package information

```bash
sudo apt update
```

#### Step 2: Install Java, Git, Maven, and the SSH server

```bash
sudo apt install -y openjdk-21-jre git maven openssh-server
```

#### Step 3: Verify installed tools

```bash
java -version
git --version
mvn --version
sudo systemctl status ssh --no-pager
```

#### Step 4: Create the Jenkins agent user

```bash
sudo useradd --create-home --shell /bin/bash devopsadmin
```

#### Step 5: Create an SSH key pair

```bash
sudo -u devopsadmin mkdir -p /home/devopsadmin/.ssh
sudo chmod 700 /home/devopsadmin/.ssh
sudo -u devopsadmin ssh-keygen -t ecdsa -b 521 \
  -f /home/devopsadmin/.ssh/id_ecdsa -N ""
```

The generated files are:

| File | Purpose |
| --- | --- |
| `/home/devopsadmin/.ssh/id_ecdsa` | Private key; add this to Jenkins credentials |
| `/home/devopsadmin/.ssh/id_ecdsa.pub` | Public key |

#### Step 6: Authorize the key for the agent user

```bash
sudo cp /home/devopsadmin/.ssh/id_ecdsa.pub \
  /home/devopsadmin/.ssh/authorized_keys
sudo chown devopsadmin:devopsadmin /home/devopsadmin/.ssh/authorized_keys
sudo chmod 600 /home/devopsadmin/.ssh/authorized_keys
```

#### Step 7: Retrieve the private key for Jenkins

On the agent, display the key and copy it securely into Jenkins. Do not commit
this key to source control or share it in chat/email.

```bash
sudo cat /home/devopsadmin/.ssh/id_ecdsa
```

## 3. Connect the agent in Jenkins

1. In Jenkins, select **Manage Jenkins** → **Credentials**.
2. Add a credential of type **SSH Username with private key**.
3. Set the username to `devopsadmin` and paste the private key from Step 7.
   An example credential ID is `jenkins_agent1_cred`.
4. Go to **Manage Jenkins** → **Nodes** → **New Node**.
5. Enter a node name, select **Permanent Agent**, and save.
6. Configure the launch method as **Launch agents via SSH** using:

   | Field | Value |
   | --- | --- |
   | Host | Private IP address or DNS name of the agent |
   | Credentials | `jenkins_agent1_cred` |
   | Host Key Verification Strategy | Use your organisation's approved verification method |

7. Save the node configuration and confirm that the agent becomes online.

## Troubleshooting

From the Jenkins controller, confirm the agent is reachable:

```bash
ssh -i /path/to/private-key devopsadmin@<agent-private-ip>
```

On the agent, inspect SSH service logs if the connection fails:

```bash
sudo journalctl -u ssh -n 100 --no-pager
```
