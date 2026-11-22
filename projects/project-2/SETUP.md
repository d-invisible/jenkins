# Project 2 setup

Follow these steps in order. The AWS script creates Ubuntu 24.04 instances in the default VPC in `ap-southeast-2` by default. EC2 resources incur charges until removed.

[Back to overview](README.md)

## 1. Create AWS infrastructure

Use a machine with Bash, AWS CLI, and EC2 permissions for VPC and AMI lookup, key pairs, security groups, and instances. Configure AWS credentials first. Supply your public IP as a `/32` CIDR. From the repository root:

```bash
aws sts get-caller-identity
ADMIN_CIDR='YOUR_PUBLIC_IP/32' bash projects/project-2/aws-script/setup-aws.sh
```

The script creates two Ubuntu 24.04 EC2 instances, an SSH key in your home directory, and separate security groups. It prints both public IPs and the agent private IP. Defaults: `ap-southeast-2`, `t3.small`, `project-2-keypair`. Override `REGION`, `INSTANCE_TYPE`, `KEY_NAME`, or `KEY_FILE` as environment variables if needed. Use fresh names when repeating the script in the same VPC.

The controller permits SSH and Jenkins port 8080 from `ADMIN_CIDR`. The agent permits SSH from the controller security group and `ADMIN_CIDR`. Both use outbound network access for package repositories, GitHub, Gradle, and Docker Hub. This design launches the Jenkins agent over SSH, so it does not need inbound port 50000.

## 2. Install Jenkins on the controller

Copy the script and connect with the key from step 1:

```bash
scp -i "$HOME/project-2-keypair.pem" projects/project-2/scripts/controller-setup.sh ubuntu@CONTROLLER_PUBLIC_IP:~/
ssh -i "$HOME/project-2-keypair.pem" ubuntu@CONTROLLER_PUBLIC_IP
sudo bash ~/controller-setup.sh
```

Open `http://CONTROLLER_PUBLIC_IP:8080` from the allowed IP. Get the initial admin password on the controller:

```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Finish the Jenkins wizard. Install **Pipeline**, **Git**, and **SSH Build Agents** plugins if needed. The script prints the SSH public key for the agent and stores the matching private key at `/root/project-2-bootstrap-keys/controller-to-agent`.

## 3. Prepare the agent

Copy the script to the agent. Use the complete controller public key printed in step 2:

```bash
scp -i "$HOME/project-2-keypair.pem" projects/project-2/scripts/agent-setup.sh ubuntu@AGENT_PUBLIC_IP:~/
ssh -i "$HOME/project-2-keypair.pem" ubuntu@AGENT_PUBLIC_IP
sudo -E AGENT_SSH_PUBLIC_KEY='ssh-ed25519 AAAA... controller-key-comment' bash ~/agent-setup.sh
```

The script creates `jenkins-agent`, installs Java 21, Git, SSH, and Docker, and adds the user to the `docker` group. Keep this agent dedicated to trusted jobs because Docker group access is root equivalent on that host. Check access from a new login session:

```bash
sudo -iu jenkins-agent java -version
sudo -iu jenkins-agent git --version
sudo -iu jenkins-agent docker info
```

## 4. Register the agent in Jenkins

On the controller, display the SSH private key:

```bash
sudo cat /root/project-2-bootstrap-keys/controller-to-agent
```

In **Manage Jenkins → Credentials**, add an **SSH Username with private key** credential with ID `project-2-agent-ssh`, username `jenkins-agent`, and that key. In **Manage Jenkins → Nodes → New Node**, create a **Permanent Agent**:

| Setting | Value |
|---|---|
| Name | `project-2-agent-1` |
| Remote root | `/home/jenkins-agent/agent` |
| Label | `jenkins-agent-node-label` |
| Usage | Only build jobs with matching label expressions |
| Launch method | Launch agents via SSH |
| Host | Agent private IP from step 1 |
| Credentials | `project-2-agent-ssh` |

Verify the SSH host key fingerprint printed by the agent script. If Jenkins cannot find Java, enter the Java path printed by that script. Wait for the node to show **Online**.

## 5. Prepare Docker Hub

Create a Docker Hub repository named `my-app` under your account, or edit `DOCKERHUB_REPOSITORY` in `code/Jenkinsfile`. Create a Docker Hub access token with push permission. In **Manage Jenkins → Credentials**, add a **Username with password** credential:

| Field | Value |
|---|---|
| ID | `dockerhub-creds` |
| Username | Docker Hub username |
| Password | Docker Hub access token |

## 6. Create the pipeline job

Push this Project 2 directory to the Git repository Jenkins uses for the pipeline definition. Create a **Pipeline** job with **Pipeline script from SCM**:

| Setting | Value |
|---|---|
| SCM | Git |
| Repository URL | This Jenkins learning repository |
| Branch | `*/main` |
| Script Path | `projects/project-2/code/Jenkinsfile` |

The Jenkinsfile checks out `https://github.com/d-invisible/java-springboot-gradle-app` from `main` on the agent. That application repository must contain the Gradle wrapper, app, and Dockerfile copying `build/libs/project-1.jar`. The copy in `code/` shows the expected structure. Change the URL in the Jenkinsfile if your application repository differs.

## 7. Run and inspect

Select **Build Now**. Expected stages: **SCM checkout**, **Build**, **Docker image**, **Docker push to DockerHub**. Inspect the archived `build/libs/project-1.jar`, console output, and Docker Hub tag `DOCKER_USER/my-app:BUILD_NUMBER`.

To try the image on a Docker host:

```bash
docker pull DOCKER_USER/my-app:BUILD_NUMBER
docker run --rm -p 8080:8080 DOCKER_USER/my-app:BUILD_NUMBER
curl http://localhost:8080/actuator/health
```

If the job stays queued, check the agent's online state and exact label. If Docker fails, run `sudo -iu jenkins-agent docker info` on the agent. If the JAR is missing, align the app repository's Gradle output, Dockerfile, and Jenkinsfile artifact path. If push is denied, check the Docker Hub repository, token permission, and `dockerhub-creds` ID.
