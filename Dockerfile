# --- STAGE 1: Build Stage (The Workshop) ---
FROM maven:3.9.6-eclipse-temurin-21 AS build
WORKDIR /app

# 1. Install Node.js 20 (Required for SvelteKit Frontend Build)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs

# 2. Optimization: Cache Maven dependencies
COPY pom.xml .
RUN mvn dependency:go-offline -B

# 3. Build the Branded Engine
# This triggers frontend-maven-plugin to build the SvelteKit UI
COPY . .
RUN mvn clean package -DskipTests

# --- STAGE 2: Runtime Stage (The Armor) ---
FROM eclipse-temurin:21-jre-jammy
WORKDIR /app

# 4. Create a non-root user for security
RUN addgroup --system javauser && adduser --system --ingroup javauser javauser

# 5. Copy artifacts from the build stage
COPY --from=build /app/target/Telecom-Billing-Engine.jar app.jar
COPY --from=build /app/src/main/webapp src/main/webapp

# Set ownership to the non-root user
RUN chown -R javauser:javauser app.jar src/main/webapp

# Switch to the non-root user
USER javauser

# Expose the application port
EXPOSE 8080

# Run the application
ENTRYPOINT ["java", "-Xmx512m", "-jar", "app.jar"]
