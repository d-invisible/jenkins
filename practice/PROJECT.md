# Practice Projects Guide

This directory contains small projects for learning build, test, and deployment workflows progressively. Each `practice-N` directory has an exercise guide named `practice-N.md` and an independent application under `code`.

## Progression

The exercises should add one major concept at a time:

1. Java, Maven, JUnit, and a basic Jenkins pipeline
2. The same workflow using Gradle
3. Automatic deployment to a server without Docker
4. Branches, pull requests, and multibranch pipelines
5. Docker image builds and container deployment
6. Artifact repositories, environments, approvals, and rollback

Keep an exercise small enough that its CI/CD concept remains easy to see.

## Standard project layout

```text
practice-N/
|-- practice-N.md
`-- code/
    |-- README.md
    |-- src/
    |   |-- main/
    |   `-- test/
    |-- Jenkinsfile
    `-- build file (pom.xml or build.gradle)
```

The `practice-N.md` file stays outside `code` and contains the exercise-specific instructions:

- the learning goal
- prerequisites
- build, test, and run steps
- practice tasks

The `code/README.md` contains only a short description of the application, its endpoints, and the essential build/run commands. All implementation files belong inside `code`. Reusable GitHub, Jenkins, CI/CD, and learning instructions belong in this guide.

## Common local workflow

For a Maven project:

```powershell
mvn clean verify
java -jar target/PROJECT_NAME.jar
```

Useful Maven lifecycle commands:

```text
mvn test          compile and run tests
mvn package       run tests and create the package
mvn clean verify  clean, test, package, and verify (recommended for CI)
```

For a Gradle project:

```powershell
./gradlew clean build
```

On Windows, use `gradlew.bat clean build`.

## Put the practices on GitHub

The recommended approach is one Git repository containing the complete `practice` directory. From the repository root:

```powershell
git init
git branch -M main
git add .
git commit -m "Add CI/CD practice projects"
git remote add origin https://github.com/YOUR_NAME/YOUR_REPOSITORY.git
git push -u origin main
```

Create the GitHub repository without generating another README or `.gitignore`. For a private repository, store a GitHub personal access token or SSH key in Jenkins Credentials. Never commit a token, password, or private key.

## Configure Jenkins once

1. Install the Pipeline, Git, GitHub, and JUnit plugins.
2. Open **Manage Jenkins > Tools**.
3. Add a JDK named `jdk17` (JDK 17 or newer).
4. Add Maven named `maven3` for Maven exercises.
5. Add Gradle when an exercise does not use the Gradle Wrapper.
6. Ensure Git is installed on every Jenkins agent.

Tool names must match the `tools` block in each `Jenkinsfile`. Either use these standard names or update that project's pipeline.

## Create a Jenkins pipeline for a project

1. Select **New Item > Pipeline**.
2. Give the job the same name as the project, such as `practice-1`.
3. Enable **GitHub hook trigger for GITScm polling** under Build Triggers.
4. Under Pipeline, select **Pipeline script from SCM**.
5. Select Git and enter the repository URL and credentials, if required.
6. Set the branch specifier to `*/main`.
7. Set Script Path to `practice/practice-N/code/Jenkinsfile`.
8. Save and run **Build Now** once to verify the initial setup.

For a standalone repository rooted at a practice directory, its Script Path is `code/Jenkinsfile`.

## Connect GitHub to Jenkins

Jenkins must be reachable from GitHub over HTTPS. In the GitHub repository, open **Settings > Webhooks > Add webhook** and use:

```text
Payload URL:  https://YOUR_JENKINS_URL/github-webhook/
Content type: application/json
Events:       Just the push event
Active:       enabled
```

The trailing slash in `/github-webhook/` matters. GitHub cannot call a Jenkins server available only at `localhost`. While learning locally, either expose Jenkins safely or configure Jenkins to poll the repository.

After setup, the basic workflow is:

```text
GitHub push -> checkout -> build -> automated tests -> package -> publish/deploy
```

## Beginner deployment model

At the first level, Jenkins publishes the successfully tested package as a build artifact. Download that exact artifact on the target machine and run it. This demonstrates an important rule: deploy the package that passed the tests; do not rebuild it manually.

Later exercises can extend the deployment stage to:

- copy the artifact to a Linux server over SSH
- run the Java application as a `systemd` service
- perform an HTTP health check
- retain the previous artifact for rollback
- deploy a Docker image instead of a raw JAR

## Checklist for every practice

- The application runs locally.
- At least one automated test passes locally.
- The CI build starts from a clean checkout.
- Jenkins runs tests and records their results.
- Jenkins publishes the exact deployable artifact.
- Secrets are stored in Jenkins Credentials, not source control.
- A deliberately failing test makes the pipeline fail.
- The `practice-N.md` file explains that exercise.
- The `code/README.md` stays short and describes only the application.

