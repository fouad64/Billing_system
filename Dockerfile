FROM maven:3.9.6-eclipse-temurin-21 AS build
WORKDIR /app

# Install Node.js
RUN apt-get update && apt-get install -y curl && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    node --version && npm --version

# Copy pom.xml for dependency caching
COPY pom.xml .
RUN mvn dependency:go-offline -B -q

# Build frontend
COPY frontend/ ./frontend/
WORKDIR /app/frontend
RUN npm install && npm run build

# Build backend
WORKDIR /app
COPY src ./src
RUN mvn -DskipTests clean package -B

# ── Runtime ──
#just some text for the branch merge test
FROM tomcat:10.1-jdk21
RUN rm -rf /usr/local/tomcat/webapps/*
COPY --from=build /app/target/*.war /usr/local/tomcat/webapps/ROOT.war
EXPOSE 8080
CMD ["catalina.sh", "run"]