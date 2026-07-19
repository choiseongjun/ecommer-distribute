FROM maven:3.9-eclipse-temurin-17-alpine
WORKDIR /app
COPY target/order-service-*.jar app.jar
EXPOSE 8082
ENTRYPOINT ["java", "-jar", "app.jar"]
