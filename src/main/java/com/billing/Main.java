package com.billing;

import org.apache.catalina.LifecycleException;
import org.apache.catalina.WebResourceRoot;
import org.apache.catalina.core.StandardContext;
import org.apache.catalina.startup.Tomcat;
import org.apache.catalina.valves.RemoteIpValve;
import org.apache.catalina.webresources.DirResourceSet;
import org.apache.catalina.webresources.JarResourceSet;
import org.apache.catalina.webresources.StandardRoot;

import java.io.File;

public class Main {
    public static void main(String[] args) throws LifecycleException {
        Tomcat tomcat = new Tomcat();
        
        // Use port from environment variable or default to 8080
        String webPort = System.getenv("PORT");
        if (webPort == null || webPort.isEmpty()) {
            webPort = "8080";
        }
        tomcat.setPort(Integer.parseInt(webPort));

        // FIX: In a hardened container, we use /tmp for Tomcat's internal files.
        // This avoids "Permission Denied" errors when running as a non-root user.
        String baseDir = System.getProperty("java.io.tmpdir") + "/tomcat-base." + webPort;
        new File(baseDir).mkdirs();
        tomcat.setBaseDir(baseDir);

        // FIX: The docBase must exist for Tomcat to start. If the source folder is missing (production),
        // we create an empty placeholder directory.
        File webappFile = new File("src/main/webapp");
        if (!webappFile.exists()) {
            webappFile = new File(baseDir, "docbase");
            webappFile.mkdirs();
        }
        
        StandardContext ctx = (StandardContext) tomcat.addWebapp("", webappFile.getAbsolutePath());
        
        // 3. Best Practice: RemoteIpValve for Nginx Reverse Proxy
        RemoteIpValve valve = new RemoteIpValve();
        valve.setRemoteIpHeader("X-Forwarded-For");
        valve.setProtocolHeader("X-Forwarded-Proto");
        ctx.getPipeline().addValve(valve);

        // FIX: Shaded JAR Support
        // Tomcat 11 doesn't scan inside a Fat JAR by default. We must manually map the JAR 
        // as a JarResourceSet so that @WebServlet and @WebFilter annotations are discovered.
        File additionWebInfClasses = new File("target/classes");
        
        // Dynamic JAR Detection: Find the path of the currently executing JAR
        String jarPath = Main.class.getProtectionDomain().getCodeSource().getLocation().getPath();
        File jarFile = new File(jarPath);
        
        WebResourceRoot resources = new StandardRoot(ctx);
        if (additionWebInfClasses.exists()) {
            // IDE Mode: Classes are in a physical folder
            resources.addPreResources(new DirResourceSet(resources, "/WEB-INF/classes",
                    additionWebInfClasses.getAbsolutePath(), "/"));
            System.out.println("Mapping resources from IDE path: " + additionWebInfClasses.getAbsolutePath());
        } else if (jarFile.isFile() && jarFile.getName().endsWith(".jar")) {
            // Production Mode: Classes are inside the JAR. We map the JAR dynamically.
            resources.addJarResources(new JarResourceSet(resources, "/WEB-INF/classes",
                    jarFile.getAbsolutePath(), "/"));
            System.out.println("Mapping resources from Dynamic JAR: " + jarFile.getAbsolutePath());
        }
        ctx.setResources(resources);

        System.out.println("Configuring app with docbase: " + webappFile.getAbsolutePath());

        tomcat.getConnector(); // Initialize the connector
        tomcat.start();
        System.out.println("FMRZ Billing System started on port " + webPort);
        tomcat.getServer().await();
    }
}
