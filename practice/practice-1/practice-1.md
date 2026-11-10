# Practice 1 Guide: Java with Maven

A small Java HTTP service for practicing a Maven build, JUnit tests, and a basic Jenkins pipeline without Docker or an application framework.

## Requirements

- JDK 17 or newer
- Maven 3.9 or newer

## Build and run

Run these commands from the `code` directory:

```powershell
cd code
mvn clean verify
java -jar target/practice-1.jar
```

The service uses port `8080` by default. Try these endpoints:

```powershell
Invoke-RestMethod http://localhost:8080/
Invoke-RestMethod 'http://localhost:8080/?name=Asha'
Invoke-RestMethod http://localhost:8080/health
```

Use a different port when needed:

```powershell
$env:PORT = '9090'
java -jar target/practice-1.jar
```

See the reusable [practice project guide](../PROJECT.md) for GitHub, Jenkins, webhook, CI/CD, and deployment instructions. See [code/README.md](code/README.md) for the application description.

