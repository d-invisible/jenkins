# Practice 1: Deploy a Java Maven App with Jenkins

This exercise builds, tests, packages, and publishes a small Java HTTP application through Jenkins. It uses Maven and JUnit, with no Docker or application framework.

## What you will practice

```text
GitHub push
    -> Jenkins checkout
    -> Maven build
    -> JUnit tests
    -> executable JAR
    -> Jenkins build artifact
    -> run the tested JAR
```

For this beginner exercise, deployment means that Jenkins publishes the exact JAR that passed the tests. You then download and run that artifact on the target machine. Automatic server deployment and service management will be introduced in a later practice.

## Project locations

```text
practice/practice-1/
|-- practice-1.md
`-- code/
    |-- Jenkinsfile
    |-- pom.xml
    |-- README.md
    `-- src/
```

When the complete `jenkins` directory is stored in one GitHub repository, the Jenkinsfile path is:

```text
practice/practice-1/code/Jenkinsfile
```

## Step 1: Install the prerequisites

For local development:

- Git
- JDK 17 or newer
- Maven 3.9 or newer

For CI/CD:

- a Jenkins server
- a GitHub account and repository
- network access from Jenkins to GitHub
- JDK and Maven configured in Jenkins

Confirm the local tools:

```powershell
git --version
java -version
mvn -version
```

## Step 2: Build and test locally

From the repository root:

```powershell
cd practice\practice-1\code
mvn clean verify
```

A successful build ends with `BUILD SUCCESS`. Maven runs the JUnit tests and creates:

```text
target/practice-1.jar
```

Run it:

```powershell
java -jar target\practice-1.jar
```

In a second PowerShell terminal, verify the application:

```powershell
Invoke-RestMethod http://localhost:8080/
Invoke-RestMethod 'http://localhost:8080/?name=Asha'
Invoke-RestMethod http://localhost:8080/health
```

Expected health response:

```text
UP
```

Press `Ctrl+C` in the application terminal to stop it.

## Step 3: Create the GitHub repository

Create an empty GitHub repository. Do not ask GitHub to create a README, `.gitignore`, or license because the local project already contains its files.

From the `jenkins` repository root:

```powershell
git init
git branch -M main
git add .
git commit -m "Add practice-1 Maven Jenkins pipeline"
git remote add origin https://github.com/YOUR_NAME/YOUR_REPOSITORY.git
git push -u origin main
```

Replace `YOUR_NAME` and `YOUR_REPOSITORY`. If Git is already initialized, do not run `git init` or add the remote again; commit and push the new files normally.

For a private repository, create a GitHub personal access token or SSH key for Jenkins. Do not put credentials in this repository or the Jenkinsfile.

## Step 4: Install the Jenkins plugins

Open **Manage Jenkins > Plugins** and ensure these plugins are installed:

- Pipeline
- Git
- GitHub
- JUnit

Restart Jenkins only if the plugin screen requests it.

## Step 5: Configure the Jenkins tools

Open **Manage Jenkins > Tools**.

Under **JDK installations**:

1. Add a JDK.
2. Set its name to `jdk17`.
3. Configure JDK 17 or newer using an installer or an existing JDK home.

Under **Maven installations**:

1. Add Maven.
2. Set its name to `maven3`.
3. Select Maven 3.9.x or configure an existing Maven home.

These names must be exactly `jdk17` and `maven3` because they are referenced in `code/Jenkinsfile`.

Also confirm Git is available on the Jenkins agent. On **Manage Jenkins > Nodes**, the selected agent should be online.

## Step 6: Add GitHub credentials to Jenkins

Skip this step for a public repository that allows anonymous cloning.

For a private repository:

1. Open **Manage Jenkins > Credentials**.
2. Select the appropriate global domain.
3. Choose **Add Credentials**.
4. Add either a GitHub username/token credential or an SSH private key.
5. Give it a recognizable ID, such as `github-practice`.

The credential is selected in the Jenkins job configuration; it is never written into the Jenkinsfile.

## Step 7: Create the Jenkins pipeline job

1. On the Jenkins dashboard, select **New Item**.
2. Enter `practice-1` as the item name.
3. Select **Pipeline**, then select **OK**.
4. Under **Build Triggers**, enable **GitHub hook trigger for GITScm polling**.
5. In the **Pipeline** section, set Definition to **Pipeline script from SCM**.
6. Set SCM to **Git**.
7. Enter the GitHub repository URL.
8. Select the GitHub credential if the repository is private.
9. Set Branch Specifier to `*/main`.
10. Set Script Path to `practice/practice-1/code/Jenkinsfile`.
11. Select **Save**.

If `practice-1` is stored as a standalone repository whose root contains the `code` directory, use `code/Jenkinsfile` as the Script Path.

## Step 8: Run the first pipeline manually

Open the `practice-1` Jenkins job and select **Build Now**.

The pipeline should execute these stages:

1. **Checkout** — clones the GitHub repository.
2. **Locate project** — finds `practice/practice-1/code`.
3. **Build and test** — runs `mvn --batch-mode clean verify`.
4. **Publish artifact** — stores `target/practice-1.jar` in Jenkins.
5. **Deploy** — confirms that the tested artifact is ready to deploy when building `main`.

Open **Console Output** and confirm the build ends successfully. Then check:

- **Test Result** shows the JUnit tests.
- **Artifacts** contains `practice-1.jar`.
- The pipeline visualization shows every required stage in green.

If the Deploy stage is skipped, confirm the job is building `main` and the Git branch is reported as `origin/main` or `main`.

## Step 9: Configure the GitHub webhook

GitHub must be able to reach Jenkins. A URL such as `http://localhost:8080` is not reachable from GitHub.

In the GitHub repository:

1. Open **Settings > Webhooks**.
2. Select **Add webhook**.
3. Set Payload URL to `https://YOUR_JENKINS_URL/github-webhook/`.
4. Set Content type to `application/json`.
5. Select **Just the push event**.
6. Keep **Active** enabled.
7. Select **Add webhook**.

The trailing slash in `/github-webhook/` is required. GitHub should show a successful delivery after the next push.

If Jenkins is only available on your local computer, use **Poll SCM** temporarily instead of a webhook. In the Jenkins job configuration, enable **Poll SCM** and use this schedule to check every five minutes:

```text
H/5 * * * *
```

## Step 10: Trigger CI/CD from GitHub

Make a small change, then commit and push it:

```powershell
git add .
git commit -m "Test the practice-1 pipeline"
git push
```

The GitHub webhook should start Jenkins automatically. In GitHub, open the webhook's **Recent Deliveries** if the build does not start. A successful webhook response is normally HTTP `200`.

## Step 11: Deploy and run the Jenkins artifact

Use the JAR from Jenkins, not a new local Maven build:

1. Open the successful Jenkins build.
2. Open **Build Artifacts**.
3. Download `practice-1.jar`.
4. Copy it to a deployment directory on the target machine.

Example Windows deployment directory:

```powershell
New-Item -ItemType Directory -Force C:\apps\practice-1
Copy-Item .\practice-1.jar C:\apps\practice-1\practice-1.jar
cd C:\apps\practice-1
java -jar practice-1.jar
```

Example Linux deployment directory:

```bash
sudo mkdir -p /opt/practice-1
sudo cp practice-1.jar /opt/practice-1/practice-1.jar
cd /opt/practice-1
java -jar practice-1.jar
```

Verify the deployed application:

```powershell
Invoke-RestMethod http://TARGET_HOST:8080/health
```

Replace `TARGET_HOST` with `localhost`, the server name, or its IP address. The expected response is `UP`.

This is the Practice 1 deployment boundary: Jenkins builds, tests, and publishes the deployable JAR; starting it is manual. A later practice will have Jenkins transfer the JAR over SSH, restart a managed service, run a health check, and support rollback.

## Step 12: Practice a failed build

Temporarily change an expected value in `GreetingServiceTest.java`, commit it, and push it. Jenkins should fail in **Build and test**, publish the failed test result, and skip artifact publication.

Restore the correct value, commit, and push again. The next pipeline should become green and publish a new JAR.

## Troubleshooting

### Jenkins reports that `jdk17` or `maven3` does not exist

The names under **Manage Jenkins > Tools** do not match the Jenkinsfile. Create tools with those exact names or update the Jenkinsfile.

### Jenkins cannot find the Jenkinsfile

For the shared repository, confirm Script Path is exactly:

```text
practice/practice-1/code/Jenkinsfile
```

Paths are case-sensitive on Linux Jenkins agents.

### Jenkins cannot clone GitHub

Check the repository URL and credential. Confirm the Jenkins machine can connect to `github.com`.

### GitHub push does not start Jenkins

Check GitHub **Settings > Webhooks > Recent Deliveries**. Confirm Jenkins has a publicly reachable HTTPS URL and that the payload path ends in `/github-webhook/`.

### Port 8080 is already in use

Jenkins commonly uses port 8080. Run this application on another port when deploying it on the same machine:

```powershell
$env:PORT = '9090'
java -jar practice-1.jar
```

Then verify `http://localhost:9090/health`.

### Tests pass but no artifact appears

Open Console Output and confirm the **Publish artifact** stage ran. The expected Maven output file is `target/practice-1.jar`.

## Completion checklist

- The application builds locally with `mvn clean verify`.
- Both JUnit tests pass.
- The source is pushed to GitHub.
- Jenkins can clone the repository.
- Jenkins records the test results.
- Jenkins publishes `practice-1.jar`.
- A GitHub push automatically starts the pipeline.
- The Jenkins artifact runs on the target machine.
- `/health` returns `UP`.

The short application description is available in [code/README.md](code/README.md). The conventions shared by every exercise are in [../PROJECT.md](../PROJECT.md).
