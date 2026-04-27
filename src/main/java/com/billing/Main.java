package com.billing;

import org.apache.catalina.LifecycleException;
import org.apache.catalina.WebResourceRoot;
import org.apache.catalina.core.StandardContext;
import org.apache.catalina.startup.Tomcat;
import org.apache.catalina.valves.RemoteIpValve;
import org.apache.catalina.webresources.DirResourceSet;
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

        // Define the webapp location
        String webappDirLocation = "src/main/webapp/";
        StandardContext ctx = (StandardContext) tomcat.addWebapp("/", new File(webappDirLocation).getAbsolutePath());
        
        // Best Practice: RemoteIpValve for Nginx Reverse Proxy
        RemoteIpValve valve = new RemoteIpValve();
        valve.setRemoteIpHeader("X-Forwarded-For");
        valve.setProtocolHeader("X-Forwarded-Proto");
        ctx.getPipeline().addValve(valve);

        // Map classes/resources for embedded execution
        File additionWebInfClasses = new File("target/classes");
        WebResourceRoot resources = new StandardRoot(ctx);
        resources.addPreResources(new DirResourceSet(resources, "/WEB-INF/classes",
                additionWebInfClasses.getAbsolutePath(), "/"));
        ctx.setResources(resources);

        System.out.println("Configuring app with basedir: " + new File("./" + webappDirLocation).getAbsolutePath());

        tomcat.getConnector(); // Initialize the connector
        tomcat.start();
        System.out.println("FMRZ Billing System started on port " + webPort);
        tomcat.getServer().await();
    }
}
