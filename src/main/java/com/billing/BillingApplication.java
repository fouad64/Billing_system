package com.billing;

import org.apache.catalina.Context;
import org.apache.catalina.startup.Tomcat;
import java.io.File;

/**
 * Embedded Tomcat Launcher for the FMRZ Billing System.
 * This class provides a Spring Boot-like experience, allowing you to run
 * the application directly from IntelliJ's "Run" button or as an executable JAR.
 */
public class BillingApplication {

    public static void main(String[] args) throws Exception {
        System.out.println("🚀 Starting FMRZ Billing System Embedded Server...");
        
        Tomcat tomcat = new Tomcat();
        
        // Use PORT environment variable or default to 8080
        String webPort = System.getenv("PORT");
        if (webPort == null || webPort.isEmpty()) {
            webPort = "8080";
        }
        
        tomcat.setPort(Integer.valueOf(webPort));
        tomcat.getConnector(); // Initialize the default connector

        // Set the web application directory
        String webappDirLocation = "src/main/webapp/";
        File webappDir = new File(webappDirLocation);
        
        if (!webappDir.exists()) {
            System.err.println("❌ ERROR: Could not find " + webappDir.getAbsolutePath());
            System.err.println("Make sure you run this from the project root directory.");
            System.exit(1);
        }

        // Add the web app to Tomcat
        Context context = tomcat.addWebapp("/", webappDir.getAbsolutePath());
        System.out.println("✅ Webapp configured at: " + webappDir.getAbsolutePath());

        // Start the server
        tomcat.start();
        System.out.println("🌐 Server running on http://localhost:" + webPort);
        tomcat.getServer().await();
    }
}
