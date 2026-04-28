#!/bin/bash
echo "Stopping existing billing system processes..."
pkill -f "com.billing.Main" || true
pkill -f "Telecom-Billing-Engine" || true

# Aggressively kill anything on port 8080
echo "Clearing port 8080..."
fuser -k 8080/tcp || true

echo "Cleaning environment..."
unset DB_URL DB_USER DB_PASSWORD JAVA_OPTS

echo "Loading environment variables from .env..."
if [ -f .env ]; then
    set -a
    source .env
    set +a
else
    echo "WARNING: .env file not found!"
fi

echo "Starting FMRZ Billing System..."
mvn exec:java -Dexec.mainClass="com.billing.Main"
