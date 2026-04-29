# --- STAGE 1: Build the Application (Maven Builder) ---
FROM maven:3.9.6-eclipse-temurin-21 AS build
WORKDIR /build

# 1. Copy pom.xml and download dependencies (for caching)
COPY pom.xml .
RUN mvn dependency:go-offline -B

# 2. Copy source code and build the Fat JAR
COPY . .
RUN mvn clean package -DskipTests

# --- STAGE 2: Run the Application (JRE Runtime) ---
FROM eclipse-temurin:21-jre-jammy
WORKDIR /app

# 1. Create a non-root user for security
RUN addgroup --system javauser && adduser --system --ingroup javauser javauser

# 2. Install curl for healthchecks
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# 3. Create required directories for CDR processing
RUN mkdir -p /app/input /app/processed && chown -R javauser:javauser /app/input /app/processed

# 4. Copy only the Fat JAR from the build stage
COPY --from=build /build/target/Telecom-Billing-Engine.jar app.jar

# 4. Copy the COMPILED webapp from the build stage (Important for 404 fix)
# We take it from the source folder because SvelteKit builds directly into it in our pom.xml
COPY --from=build /build/src/main/webapp ./webapp_static

# 5. Copy other runtime resources
COPY --from=build /build/src/main/resources/invoice.jrxml .
COPY --from=build /build/src/main/resources/logo.svg .
COPY --from=build /build/src/main/resources/Pictures ./Pictures

# 6. Set ownership to the non-root user
RUN chown -R javauser:javauser /app

# 7. Switch to the non-root user
USER javauser

# 8. Expose the application port
EXPOSE 8080

# 9. Run the application
ENTRYPOINT ["java", "-Xmx512m", "-Djava.awt.headless=true", "-jar", "app.jar"]
