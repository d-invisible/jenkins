# Practice 2: Build, Test, and Run on a Jenkins Agent VM

Practice 2 reuses the Java application from `practice/practice-1/code`. It does not copy the application. The new Jenkins pipeline checks out the same repository and performs all work on a separate Linux agent VM.

This exercise is manually triggered. It does not require a GitHub webhook.

## What you will practice

```text
Jenkins controller
    -> connects to a Linux agent over SSH
    -> checks out the repository on the agent
    -> builds and tests Practice 1 on the agent
    -> archives the tested JAR
    -> optionally starts the JAR on the agent
    -> checks /health on the agent
```

Practice 2 contains only:

```text
practice/practice-2/
|-- practice-2.md
`-- Jenkinsfile
```

The application source remains in:

```text
practice/practice-1/code
```

## Phase 1 and Phase 2

- **Phase 1:** select **Build Now**. Jenkins builds, tests, and archives the JAR on the agent.
- **Phase 2:** select **Build with Parameters**, enable `RUN_APP_ON_AGENT`, and build again. Jenkins also starts the app on port `9090` and checks `/health`.

## Step 1: Prepare the agent VM

These instructions assume an Ubuntu or Debian agent VM. The controller and agent must be able to reach each other over the network.

Allow these connections in the VM firewall or cloud security group:

- SSH port `22` from the Jenkins controller only
- application port `9090` from your IP only, if you want to open the app externally

Do not expose SSH or the application port to the entire internet for a practice environment.

Connect to the agent VM and install the required tools:

```bash
sudo apt-get update
sudo apt-get install -y openjdk-21-jdk maven git curl

java -version
mvn -version
git --version
curl --version
```

JDK 21 runs the Jenkins agent and can compile Practice 1. The Practice 1 Maven configuration still creates Java 17-compatible bytecode.

## Step 2: Create a dedicated agent user

On the agent VM:

```bash
sudo useradd --create-home --shell /bin/bash jenkins-agent
sudo mkdir -p /home/jenkins-agent/agent
sudo chown -R jenkins-agent:jenkins-agent /home/jenkins-agent
sudo chmod 700 /home/jenkins-agent
```

The Jenkins builds and application process will run as `jenkins-agent`, not as `root`.

## Step 3: Create an SSH key for Jenkins

On a trusted administrator machine, create a dedicated key pair:

```bash
ssh-keygen -t ed25519 -f jenkins-practice-agent -C jenkins-practice-agent
```

This creates:

- `jenkins-practice-agent` — private key for Jenkins Credentials
- `jenkins-practice-agent.pub` — public key for the agent VM

Add the public key to the agent VM. Run these commands on the agent and paste the single public-key line in place of `PUBLIC_KEY_CONTENT`:

```bash
sudo install -d -m 700 -o jenkins-agent -g jenkins-agent /home/jenkins-agent/.ssh
echo 'PUBLIC_KEY_CONTENT' | sudo tee /home/jenkins-agent/.ssh/authorized_keys > /dev/null
sudo chown jenkins-agent:jenkins-agent /home/jenkins-agent/.ssh/authorized_keys
sudo chmod 600 /home/jenkins-agent/.ssh/authorized_keys
```

Test the connection using the private key:

```bash
ssh -i jenkins-practice-agent jenkins-agent@AGENT_PRIVATE_IP
```

Use a private IP when the controller and agent are in the same private network.

## Step 4: Store the SSH credential in Jenkins

On the Jenkins controller:

First, open **Manage Jenkins > Plugins** and ensure the **SSH Build Agents** plugin is installed. Then:

1. Open **Manage Jenkins > Credentials**.
2. Select the global credentials domain.
3. Select **Add Credentials**.
4. Set Kind to **SSH Username with private key**.
5. Set Username to `jenkins-agent`.
6. Set Private Key to **Enter directly**, then paste the private key.
7. Set ID to `practice-agent-ssh`.
8. Save the credential.

Never commit the private key to GitHub.

## Step 5: Register the agent node

1. Open **Manage Jenkins > Nodes**.
2. Select **New Node**.
3. Enter `practice-agent-1`.
4. Select **Permanent Agent**, then create it.
5. Set Number of executors to `1`.
6. Set Remote root directory to `/home/jenkins-agent/agent`.
7. Set Labels to `practice-agent`.
8. Set Usage to **Only build jobs with label expressions matching this node**.
9. Set Launch method to **Launch agents via SSH**.
10. Enter the agent VM's private IP or DNS name.
11. Select the `practice-agent-ssh` credential.
12. Select a secure host-key verification strategy, preferably **Known hosts file** or **Manually trusted key verification**.
13. Under Advanced, set JavaPath to `/usr/lib/jvm/java-21-openjdk-amd64/bin/java` if Jenkins cannot find Java automatically.
14. Save.

Open the node's log. A successful connection ends with a message similar to:

```text
Agent successfully connected and online
```

The exact wording can vary. The node must show **Online** and have the label `practice-agent`.

## Step 6: Confirm the agent environment

From the agent node page, open **System Information** and verify:

- `java.version` reports Java 21
- the remote root is `/home/jenkins-agent/agent`
- the node has one available executor

Maven, Git, and curl are inherited from the agent VM's `PATH`; they are not declared in the Practice 2 Jenkinsfile's `tools` block.

## Step 7: Push Practice 2 to the same repository

From the local repository root:

```powershell
git add practice/practice-2 practice/PROJECT.md
git commit -m "Add practice-2 Jenkins agent exercise"
git push
```

## Step 8: Create the manual pipeline job

1. On the Jenkins dashboard, select **New Item**.
2. Enter `practice-2-agent-job`.
3. Select **Pipeline**, then select **OK**.
4. Do not enable GitHub webhook or Poll SCM triggers for this exercise.
5. Under Pipeline, select **Pipeline script from SCM**.
6. Set SCM to **Git**.
7. Enter the same GitHub repository URL used in Practice 1.
8. Select the repository credential if it is private.
9. Set Branch Specifier to `*/main`.
10. Set Script Path to `practice/practice-2/Jenkinsfile`.
11. Save.

This is a manually triggered pipeline even though its script is stored in the repository.

## Step 9: Phase 1 — build and test on the agent

Select **Build Now** for the first run. The parameter defaults to false, so the application will not start.

Expected stages:

1. **Checkout on agent**
2. **Verify agent tools**
3. **Build and test**
4. **Publish artifact**
5. **Run app on agent** — skipped

Open **Console Output** and confirm:

- `Agent: practice-agent-1` is printed
- Java, Maven, Git, and curl versions are printed
- Maven reports `BUILD SUCCESS`
- two JUnit tests pass

On the build page:

- **Test Result** displays the two tests
- **Build Artifacts** contains `practice-1.jar`

All checkout, compilation, testing, and packaging happened in the agent's workspace under `/home/jenkins-agent/agent`.

## Step 10: Phase 2 — run the application on the agent

After one parameterized build, Jenkins will display **Build with Parameters** for the job:

1. Select **Build with Parameters**.
2. Enable `RUN_APP_ON_AGENT`.
3. Select **Build**.

Jenkins builds and tests again before starting the app. The Run stage:

- safely stops the previous Practice 1 process started from the same workspace, if present
- starts `target/practice-1.jar` on port `9090`
- stores its PID in `.practice-1.pid`
- writes output to `practice-1.log`
- calls `http://127.0.0.1:9090/health`
- fails the pipeline if the app does not return `UP` within 30 seconds

Expected log output:

```text
Started practice-1 with PID ... on port 9090
Health check passed: http://127.0.0.1:9090/health
```

## Step 11: Verify the running app

From the agent VM:

```bash
curl http://127.0.0.1:9090/
curl 'http://127.0.0.1:9090/?name=Agent'
curl http://127.0.0.1:9090/health
```

Expected health response:

```text
UP
```

If port `9090` is allowed from your IP, open:

```text
http://AGENT_PUBLIC_IP:9090/health
```

Do not expose port `9090` publicly unless you intentionally restrict its source range.

## Step 12: Inspect the process and logs

On the agent VM:

```bash
ps -ef | grep '[p]ractice-1.jar'
cat /home/jenkins-agent/agent/workspace/practice-2-agent-job/practice/practice-1/code/practice-1.log
```

The exact workspace directory can differ if Jenkins changes the job name or places the job inside a folder. The Console Output prints the actual `$WORKSPACE` path.

## Step 13: Stop the application manually

From the Practice 1 code directory inside the Jenkins workspace:

```bash
kill "$(cat .practice-1.pid)"
rm -f .practice-1.pid
```

Verify it stopped:

```bash
curl --fail http://127.0.0.1:9090/health
```

The curl command should fail because nothing is listening on port `9090`.

## Troubleshooting

### The job stays queued with “Waiting for next available executor”

Confirm the agent is online and its label is exactly `practice-agent`. The Jenkinsfile only runs on a node with that label.

### The SSH launcher cannot find Java

Set JavaPath in the node's Advanced settings:

```text
/usr/lib/jvm/java-21-openjdk-amd64/bin/java
```

### `mvn`, `git`, or `curl` is not found

Install the missing package on the agent VM and reconnect the node. The build executes on the agent, so installing a tool only on the controller is insufficient.

### The pipeline cannot find Practice 1

Confirm the job checks out the complete shared repository and that this path exists:

```text
practice/practice-1/code/pom.xml
```

### Port 9090 is already in use

Find the listener on the agent:

```bash
sudo ss -ltnp | grep ':9090'
```

Stop the intended old process or change `APP_PORT` in the Practice 2 Jenkinsfile.

### The app stops when the pipeline ends

The Jenkinsfile sets `JENKINS_NODE_COOKIE=dontKillMe` when launching the app. Confirm that line is still present and inspect `practice-1.log` for application errors.

## Completion checklist

- The agent VM has Java 21, Maven, Git, and curl.
- Jenkins connects to the VM using a dedicated SSH credential.
- The agent is online with label `practice-agent`.
- The manual job uses `practice/practice-2/Jenkinsfile`.
- Phase 1 builds and tests Practice 1 on the agent.
- Jenkins records two passing tests and archives the JAR.
- Phase 2 starts the app on the agent VM.
- The agent health check returns `UP` on port `9090`.

