# Exhaustive Integration & Hardening Audit (Post-Mortem)

This document explains the **Why, Where, and How** for every technical hurdle faced during the integration of Java 21, Tomcat 11, Nginx, and Podman.

---

## 🏗️ 1. Startup Crash: The Permission Paradox
- **Where**: `Dockerfile` and `com.billing.Main.java`
- **Why**: Modern security requires running containers as a non-root user (`billinguser`). However, Tomcat defaults to writing its work files in the execution directory. Since `/app` was owned by root, the app crashed with `AccessDeniedException` before the first log line appeared.
- **The Fix**: 
    1.  **Dockerfile**: Added `chown` to give the app ownership of its own folder.
    2.  **Main.java**: Programmatically moved the Tomcat `baseDir` to `/tmp` to follow the "Read-Only Filesystem" best practice.

## 🛠️ 2. The 404 Ghost: Shaded JAR Annotation Blindness
- **Where**: `com.billing.Main.java`
- **Why**: In a "Shaded JAR," your classes aren't in a folder; they are inside a ZIP. Tomcat's default scanner looks for a `WEB-INF/classes` folder which doesn't exist in a JAR. This caused all `@WebServlet` and `@WebFilter` annotations to be ignored.
- **The Fix**: Implemented **Dynamic JAR Detection**. The code now detects its own JAR filename at runtime and maps it as a `JarResourceSet`. This "tells" Tomcat: *"Everything inside this JAR should be treated as a web class."*

## 📦 3. The Empty Page: Frontend/Backend Desynchronization
- **Where**: `deploy/nginx.conf` and `Dockerfile`
- **Why**: SvelteKit/Vite uses unique hashes for filenames (e.g., `app.A1B2.js`). Nginx was trying to serve these from your **Host's disk**, but the HTML was being served by the **Container**. Because the Host and Container builds happened at different times, the hashes didn't match. Nginx gave a 404 for the JS, and the page stayed empty.
- **The Fix**: Disabled Nginx's filesystem `alias`. Now, Nginx proxies everything to Tomcat. Since Tomcat and the JS files are in the same container, they are always perfectly in sync.

## 🛣️ 4. The SPA Router: Path Normalization
- **Where**: `com.billing.filter.AppFilter.java`
- **Why**: SvelteKit handles navigation in the browser. If a user refreshes `http://billing.local/dashboard`, Tomcat thinks `/dashboard` is a real folder on the server and returns a 404.
- **The Fix**: Updated the filter to recognize "Deep Links" and forward them to `index.html`. Also fixed a JAR-specific bug where `getRealPath()` returned `null`, breaking the dynamic CSS injection.

## 🔒 5. Security Hardening: The Secrets Leak
- **Where**: `com.billing.db.DB.java` and `src/main/resources/db.properties`
- **Why**: Storing passwords in `db.properties` is dangerous because that file is bundled into the JAR. If the JAR is shared, the database is exposed.
- **The Fix**: Scrubbed the properties file and refactored `DB.java` to use **Environment Variable Priority**. The app now looks for `DB_URL` and `DB_PASSWORD` in the secure container environment first.

## 🎨 6. Branding: Centralized Configuration
- **Where**: `src/main/resources/config.properties` and `CustomerProfileServlet.java`
- **Why**: Branding (Phone, Web, Email) was hardcoded in multiple places. Changing the company website required a full rebuild of the code.
- **The Fix**: Created a central `config.properties`. The Servlet now loads this at startup and injects the values into the JasperReport as parameters.

## ⚡ 7. Performance: JasperReport Compilation Lag
- **Where**: `com.billing.servlet.CustomerProfileServlet.java`
- **Why**: Every PDF download request was re-compiling the `.jrxml` file from scratch, adding a 2-second delay and heavy CPU load.
- **The Fix**: Implemented **In-Memory Report Caching**. The report is compiled once and the binary object is reused for all subsequent downloads, making them nearly instant.

---

### 🚦 Final Operational Note
The system is now "Hardened." This means it is no longer dependent on your local filesystem paths or hardcoded passwords. It is a self-contained "Engine" ready for any Linux server.
