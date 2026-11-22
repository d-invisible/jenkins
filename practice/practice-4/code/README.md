# Project 1 Spring Boot App

A small Spring Boot REST service built with Java 21 and Gradle.

Endpoints:

- `GET /`
- `GET /api/hello?name=Asha`
- `GET /actuator/health`

Build and test:

```bash
./gradlew clean test bootJar --build-cache
```

Run:

```bash
java -jar build/libs/project-1.jar
```

