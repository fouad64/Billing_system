# Stage 1: Build the application
# We use a Maven image that includes JDK 21. 
# The pom.xml is configured to build the Svelte frontend automatically.
FROM maven:3.9.6-eclipse-temurin-21 AS build
WORKDIR /app
COPY . .
RUN mvn clean package -DskipTests

# Stage 2: Runtime environment
FROM eclipse-temurin:21-jre
WORKDIR /app

# Set headless mode for JasperReports rendering
ENV JAVA_OPTS="-Djava.awt.headless=true"

# Copy the Fat JAR from the build stage
COPY --from=build /app/target/Telecom-Billing-Engine.jar app.jar

# Copy the static webapp files so Tomcat has a physical directory to serve
# This matches the 'webapp' lookup logic in Main.java
COPY --from=build /app/src/main/webapp webapp

# Railway provides the PORT environment variable
# Our Main.java is already configured to listen on it.
EXPOSE 8080

# Run the application
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
