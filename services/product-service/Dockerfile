FROM maven:3.9-eclipse-temurin-17-alpine
WORKDIR /app
COPY target/product-service-*.jar app.jar
EXPOSE 8083
ENTRYPOINT ["java", "-jar", "app.jar"]
