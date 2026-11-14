# Practice 3: Build on an Agent and Deploy to a Tomcat Target VM

Practice 3 introduces a separate deployment target. Jenkins orchestrates the pipeline, Agent 1 builds and tests a Maven WAR, and a target VM runs the application in Tomcat 10.1.

Jenkins now calls the old “master” machine the **controller**. This guide uses “controller (master)” where helpful.

## Architecture

Open the editable [architecture.drawio](architecture.drawio) file in [draw.io](https://app.diagrams.net/) or the diagrams.net desktop application.

```text
Jenkins controller (master)
        |
        | SSH / Jenkins remoting
        v
Agent 1: maven-agent
  checkout -> build -> test -> WAR
        |
        | SSH/SCP practice-3.war
        v
Target VM: Tomcat 10.1
  deploy -> restart -> /practice-3/health
```

All Maven compilation and tests run on Agent 1. The controller stores credentials and orchestrates the job. Only the tested WAR is copied to the target VM.

## Project layout

```text
practice/practice-3/
|-- architecture.drawio
|-- Jenkinsfile
|-- practice-3.md
`-- code/
    |-- pom.xml
    |-- README.md
    `-- src/
```

Practice 3 uses a Jakarta Servlet WAR because Tomcat deploys web applications as WAR files. Tomcat 10.1 implements Servlet 6.0 and supports Java 11 or later; this exercise uses Java 21.

## Pipeline phases

- **Phase 1:** run with `DEPLOY_TO_TARGET=false`. Jenkins builds, tests, and archives `practice-3.war` on Agent 1.
- **Phase 2:** run with `DEPLOY_TO_TARGET=true` and provide `TARGET_HOST`. Jenkins copies the tested WAR to the target, restarts Tomcat, and checks the deployed health endpoint.

## Required network access

Use private IP addresses when all VMs are in the same VPC or private network.

| Source | Destination | Port | Purpose |
|---|---|---:|---|
| Your IP | Jenkins controller | 8080 or 443 | Jenkins UI |
| Jenkins controller | Agent 1 | 22 | SSH agent launcher |
| Agent 1 | GitHub and Maven repositories | 443 | Checkout and dependencies |
| Agent 1 | Target VM | 22 | SCP and SSH deployment |
| Agent 1 | Target VM | 8080 | Tomcat health check |
| Your IP | Target VM | 8080 | Optional browser testing |

Restrict security-group or firewall sources to the controller, Agent 1, and your IP. Do not allow SSH from `0.0.0.0/0`.

## Step 1: Prepare the Jenkins controller

Ensure these plugins are installed under **Manage Jenkins > Plugins**:

- Pipeline
- Git
- JUnit
- SSH Build Agents — controller to Agent 1
- SSH Agent — pipeline SSH credential for Agent 1 to target

The SSH Agent plugin requires the `ssh-agent` executable on Agent 1.

## Step 2: Prepare Agent 1

Practice 2 already created an agent VM. Install the additional SSH client tools if needed:

```bash
sudo apt-get update
sudo apt-get install -y openjdk-21-jdk maven git curl openssh-client

java -version
mvn -version
git --version
ssh -V
curl --version
```

In **Manage Jenkins > Nodes**, edit Agent 1:

1. Keep the node online.
2. Add the label `maven-agent`.
3. Keep its remote root, such as `/home/jenkins-agent/agent`.
4. Keep Usage set to jobs matching the node label.

The Practice 3 Jenkinsfile uses `agent { label 'maven-agent' }`, so the job remains queued if no online node has that label.

## Step 3: Prepare the Tomcat target VM

These package commands are for Ubuntu or Debian distributions that provide the `tomcat10` package:

```bash
sudo apt-get update
sudo apt-get install -y openjdk-21-jdk tomcat10 openssh-server curl
sudo systemctl enable --now ssh
sudo systemctl enable --now tomcat10

java -version
systemctl status tomcat10 --no-pager
curl --fail http://127.0.0.1:8080/
```

Confirm the Tomcat service account and deployment directory:

```bash
id tomcat
sudo test -d /var/lib/tomcat10/webapps
```

If your distribution uses a manually installed Tomcat, replace the service name, service account, and `$CATALINA_BASE/webapps` path consistently in the Jenkinsfile and sudoers rule.

## Step 4: Create a restricted target deployment user

On the target VM:

```bash
sudo useradd --create-home --shell /bin/bash deployer
sudo install -d -m 700 -o deployer -g deployer /home/deployer/.ssh
```

The pipeline logs in as `deployer`; it does not log in as root.

## Step 5: Create the target deployment SSH key

On a trusted administrator machine, create a dedicated key pair:

```bash
ssh-keygen -t ed25519 -f practice-3-target -C practice-3-target
```

Add `practice-3-target.pub` to the target. Replace `PUBLIC_KEY_CONTENT` with the complete public-key line:

```bash
echo 'PUBLIC_KEY_CONTENT' | sudo tee /home/deployer/.ssh/authorized_keys > /dev/null
sudo chown deployer:deployer /home/deployer/.ssh/authorized_keys
sudo chmod 600 /home/deployer/.ssh/authorized_keys
```

Test it from Agent 1 or another trusted machine:

```bash
ssh -i practice-3-target deployer@TARGET_PRIVATE_IP
```

Never commit either key to Git. Store the private key only in Jenkins Credentials and secure administrative storage.

## Step 6: Allow only the required deployment commands

The pipeline needs permission to install the WAR and restart Tomcat. On the target VM, open a dedicated sudoers file:

```bash
sudo visudo -f /etc/sudoers.d/practice-3-deployer
```

Add these two exact rules on one line:

```text
deployer ALL=(root) NOPASSWD: /usr/bin/install -o tomcat -g tomcat -m 0644 /tmp/practice-3.war /var/lib/tomcat10/webapps/practice-3.war, /usr/bin/systemctl restart tomcat10
```

Validate it:

```bash
sudo chmod 440 /etc/sudoers.d/practice-3-deployer
sudo visudo -cf /etc/sudoers.d/practice-3-deployer
sudo -l -U deployer
```

This is intentionally narrower than granting unrestricted `sudo` access.

## Step 7: Add the target credential to Jenkins

On the Jenkins controller:

1. Open **Manage Jenkins > Credentials**.
2. Select the global credentials domain.
3. Select **Add Credentials**.
4. Set Kind to **SSH Username with private key**.
5. Set Username to `deployer`.
6. Paste the `practice-3-target` private key.
7. Set ID to exactly `target-vm-ssh`.
8. Save.

The ID must match `sshagent(credentials: ['target-vm-ssh'])` in the Jenkinsfile.

## Step 8: Trust the target host key on Agent 1

The pipeline uses strict host-key verification. First, on the target VM, display the real SSH host-key fingerprint:

```bash
sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

On Agent 1, as the Jenkins agent user, collect the public host key and inspect its fingerprint:

```bash
sudo -u jenkins-agent install -d -m 700 /home/jenkins-agent/.ssh
sudo -u jenkins-agent ssh-keyscan -t ed25519 TARGET_PRIVATE_IP > /tmp/practice-3-known-host
ssh-keygen -lf /tmp/practice-3-known-host
```

Compare the fingerprint with the value printed directly on the target VM. Only if they match, install it:

```bash
sudo sh -c 'cat /tmp/practice-3-known-host >> /home/jenkins-agent/.ssh/known_hosts'
sudo chown jenkins-agent:jenkins-agent /home/jenkins-agent/.ssh/known_hosts
sudo chmod 600 /home/jenkins-agent/.ssh/known_hosts
rm -f /tmp/practice-3-known-host
```

Use the same hostname or IP in `TARGET_HOST` that was written to `known_hosts`.

## Step 9: Build locally if desired

From the Practice 3 code directory:

```bash
cd practice/practice-3/code
mvn clean verify
```

Expected package:

```text
target/practice-3.war
```

## Step 10: Push Practice 3 to the repository

From the repository root:

```powershell
git add practice/practice-3 practice/PROJECT.md
git commit -m "Add practice-3 Tomcat deployment pipeline"
git push
```

## Step 11: Create the manual Jenkins pipeline

1. Select **New Item** on the Jenkins dashboard.
2. Name it `practice-3-tomcat-job`.
3. Select **Pipeline**.
4. Do not enable webhook or Poll SCM triggers yet.
5. Under Pipeline, select **Pipeline script from SCM**.
6. Select **Git** and enter the same repository URL.
7. Select the GitHub credential if the repository is private.
8. Set Branch Specifier to `*/main`.
9. Set Script Path to `practice/practice-3/Jenkinsfile`.
10. Save.

## Step 12: Phase 1 — build and test on Agent 1

Run **Build with Parameters** using:

```text
DEPLOY_TO_TARGET = false
TARGET_HOST       = empty
TARGET_USER       = deployer
```

Expected stages:

1. Checkout on Maven agent
2. Verify agent
3. Build and test WAR
4. Publish WAR
5. Deployment stages skipped

Confirm on the build page:

- the node is Agent 1 with label `maven-agent`
- Maven reports `BUILD SUCCESS`
- **Test Result** shows two passing tests
- **Build Artifacts** contains `practice-3.war`

## Step 13: Phase 2 — deploy to the Tomcat target

Run **Build with Parameters** again:

```text
DEPLOY_TO_TARGET = true
TARGET_HOST       = TARGET_PRIVATE_IP
TARGET_USER       = deployer
```

The pipeline will:

1. rebuild and test the WAR on Agent 1
2. archive the tested WAR in Jenkins
3. copy that WAR to `/tmp/practice-3.war` on the target
4. install it as `/var/lib/tomcat10/webapps/practice-3.war`
5. restart `tomcat10`
6. poll `/practice-3/health` for up to 60 seconds

Expected log message:

```text
Target health check passed: http://TARGET_PRIVATE_IP:8080/practice-3/health
```

## Step 14: Verify the target application

From Agent 1 or another machine allowed by the target firewall:

```bash
curl http://TARGET_PRIVATE_IP:8080/practice-3/
curl 'http://TARGET_PRIVATE_IP:8080/practice-3/?name=Agent'
curl http://TARGET_PRIVATE_IP:8080/practice-3/health
```

Expected health response:

```text
UP
```

On the target VM, inspect deployment and logs:

```bash
ls -l /var/lib/tomcat10/webapps/practice-3.war
systemctl status tomcat10 --no-pager
sudo journalctl -u tomcat10 -n 100 --no-pager
```

## How the deployment stays secure

- GitHub credentials and the target private key live in Jenkins Credentials.
- Agent 1 verifies the target SSH host key.
- The target accepts SSH only from Agent 1.
- The `deployer` account has only two exact passwordless sudo commands.
- The pipeline validates `TARGET_HOST` and `TARGET_USER` before using them.
- Only a WAR that passed tests is sent to the target.

## Troubleshooting

### Job waits for an executor

Agent 1 must be online and have the exact label `maven-agent`.

### `No such DSL method 'sshagent'`

Install the **SSH Agent** plugin on the controller and restart Jenkins if requested.

### `ssh-agent` is not found

Install `openssh-client` on Agent 1.

### Host key verification failed

Repeat Step 8 and ensure `TARGET_HOST` exactly matches the IP or hostname stored in `/home/jenkins-agent/.ssh/known_hosts`.

### Permission denied while installing the WAR

Run `sudo -l -U deployer` on the target. Confirm the sudoers command exactly matches the command in the Jenkinsfile, including paths and arguments.

### Health check times out

On the target:

```bash
systemctl status tomcat10 --no-pager
sudo journalctl -u tomcat10 -n 100 --no-pager
curl -v http://127.0.0.1:8080/practice-3/health
```

Also verify that the target security group allows TCP `8080` from Agent 1.

### Tomcat package or paths differ

Find the actual service and app base, then update all three places together:

- Practice 3 Jenkinsfile
- `/etc/sudoers.d/practice-3-deployer`
- this guide

## Completion checklist

- Controller can launch Agent 1.
- Agent 1 is online with label `maven-agent`.
- Agent 1 has Java 21, Maven, Git, curl, SSH, and SCP.
- Target VM runs Tomcat 10.1.
- Target credential ID is `target-vm-ssh`.
- Agent 1 has a verified target entry in `known_hosts`.
- Phase 1 builds, tests, and archives `practice-3.war`.
- Phase 2 deploys the WAR and restarts Tomcat.
- `/practice-3/health` returns `UP` from the target VM.

## References

- [Apache Tomcat version compatibility](https://tomcat.apache.org/whichversion.html)
- [Tomcat WAR deployment documentation](https://tomcat.apache.org/tomcat-10.1-doc/deployer-howto.html)
- [Jenkins SSH Agent plugin](https://plugins.jenkins.io/ssh-agent/)

