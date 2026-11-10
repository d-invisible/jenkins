# Practice 1 Java App

A small Java HTTP service used to practice Maven builds, JUnit tests, and Jenkins CI/CD without Docker.

It provides a greeting at `/`, accepts a name with `/?name=Asha`, and reports its status at `/health`.

Build and run:

```powershell
mvn clean verify
java -jar target/practice-1.jar
```

