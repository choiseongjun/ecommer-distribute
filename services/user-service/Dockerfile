FROM maven:3.9-eclipse-temurin-17-alpine
WORKDIR /app
COPY target/user-service-*.jar app.jar
EXPOSE 8081
ENTRYPOINT ["java", "-jar", "app.jar"]
