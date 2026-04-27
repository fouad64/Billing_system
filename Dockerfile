# --- STAGE 1: Build Stage (The Workshop) ---
# We use a full JDK 21 and Maven image to compile the engine
FROM maven:3.9.6-eclipse-temurin-21 AS build
WORKDIR /app

# 1. Install Node.js 20 (Required for SvelteKit Frontend Build)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs

# 2. Optimization: Cache Maven dependencies
# By copying only the pom.xml first, we don't have to re-download 
# the internet every time you change a single line of code.
COPY pom.xml .
RUN mvn dependency:go-offline -B

# 3. Build the Branded Engine
# This will trigger the frontend-maven-plugin to build SvelteKit
COPY . .
RUN mvn clean package -DskipTests

# --- STAGE 2: Runtime Stage (The Armor) ---
# We use a slim JRE (Java Runtime Environment) for production security
FROM eclipse-temurin:21-jre-jammy
WORKDIR /app

# 4. Security: Run as a non-root user
# This prevents an attacker from gaining root access to your host machine
RUN useradd -m billinguser && chown -R billinguser:billinguser /app
USER billinguser

# 5. Deployment: Copy artifact and webapp assets
COPY --chown=billinguser:billinguser --from=build /app/target/Telecom-Billing-Engine.jar .
COPY --chown=billinguser:billinguser --from=build /app/src/main/webapp ./src/main/webapp

# 6. Network: Open the Tomcat port
EXPOSE 8080

# 7. Launch: The startup entrypoint
ENTRYPOINT ["java", "-XX:+UseParallelGC", "-jar", "Telecom-Billing-Engine.jar"]
