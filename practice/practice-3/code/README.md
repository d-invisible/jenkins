# Practice 3 Tomcat App

A small Jakarta Servlet application packaged as `practice-3.war` for Tomcat 10.1.

Endpoints after deployment:

- `/practice-3/` — greeting
- `/practice-3/?name=Asha` — personalized greeting
- `/practice-3/health` — health check returning `UP`

Build and test:

```bash
mvn clean verify
```

