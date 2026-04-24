# FMRZ Telecom Billing System 🚀

A high-performance, enterprise-grade Telecom Billing System built with a modern full-stack architecture.

## 🏗️ Architecture Stack
- **Backend**: Java (Jakarta EE 11) on Apache Tomcat 11.
- **Frontend**: SvelteKit 5 (Static Adapter) with premium glassmorphic UI.
- **Database**: PostgreSQL (Neon DB) with HikariCP connection pooling.
- **Routing**: Unified `AppFilter` for SPA deep-linking, path normalization, and dynamic asset injection.

## ✨ Key Features
- **Premium Admin Dashboard**: Real-time stats for Customers, Contracts, and CDRs with vibrant visual cards.
- **High-Performance CDR Engine**: Optimized for processing large datasets (500+ records) with absolute zero routing latency.
- **Unified Security**: Session-based authentication with secure cookie-only tracking.
- **Fast-Path Hydration**: Custom script to prevent UI flickering during SPA boot.
- **Automated Asset Sync**: Single-pass filter to inject compiled CSS hashes into the static index.

## 🚀 Getting Started

### Prerequisites
- Java 21+
- Maven 3.9+
- Node.js 20+

### One-Command Start
The project is configured with the Maven Cargo plugin for a seamless developer experience:
```bash
./mvnw clean package cargo:run
```
*Access the app at: http://localhost:8080*

### Admin Credentials
- **Username**: `admin`
- **Password**: `admin123`

## 🛠️ Development Workflow
- **Frontend Changes**: Modify files in `frontend/src/`. Run `npm run build` inside the frontend folder to sync assets to the Java `webapp` directory.
- **Backend Changes**: Modify servlets in `src/main/java/com/billing/servlet/`.
- **Database**: The system uses a shared Neon DB cluster. Connection settings are managed in `DB.java`.

## 🛡️ Core Stability Fixes
- **Routing**: Enforced absolute `/` paths globally to prevent recursive `admin/admin` loops.
- **Filters**: Replaced legacy `SpaFilter` and `HtmlInjectionFilter` with a high-performance `AppFilter` featuring a `ThreadLocal` recursion guard.
- **Performance**: Integrated HikariCP for 10x faster database query execution.

---
*Developed by Ziad Khattab & Team — ITI Telecom Billing Project 2026*