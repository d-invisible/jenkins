# Project 2 Spring Boot App (Practice 4)

A small Spring Boot REST service based on the Practice 4 code, built with Java 21 and Gradle.

Endpoints:

- `GET /`
- `GET /api/hello?name=Asha`
- `GET /actuator/health`

Build and test from this directory:

```bash
./gradlew clean build --max-workers=1
```

Run:

```bash
java -jar build/libs/project-1.jar
```

The Docker image uses the included Dockerfile and exposes port 8080. The Jenkins pipeline in `Jenkinsfile` checks out the configured GitHub application repository, archives the JAR, builds an image tagged with the Jenkins build number, then pushes `DOCKER_USER/my-app:BUILD_NUMBER` to Docker Hub. Create Jenkins username/password credential `dockerhub-creds` and use a Docker Hub access token as its password.

