package com.billing.util;

import net.sf.jasperreports.engine.JasperCompileManager;
import java.io.File;
import java.io.FileInputStream;

public class DebugJasper {
    public static void main(String[] args) {
        String fileName = (args.length > 0) ? args[0] : "invoice.jrxml";
        String filePath = "/app/" + fileName;
        java.io.File logFile = new java.io.File("/app/debug_results.txt");
        try (java.io.PrintWriter pw = new java.io.PrintWriter(new java.io.FileWriter(logFile, true))) {
            pw.println("🚀 DEBUG (v6): Attempting to compile " + filePath);
            
            File f = new File(filePath);
            if (!f.exists()) {
                pw.println("❌ ERROR: File not found at " + filePath);
                pw.flush();
                return;
            }
            
            try (FileInputStream is = new FileInputStream(f)) {
                pw.println("🔍 TESTING: Standard JDK DocumentBuilder parsing...");
                javax.xml.parsers.DocumentBuilderFactory factory = javax.xml.parsers.DocumentBuilderFactory.newInstance();
                factory.setNamespaceAware(true);
                javax.xml.parsers.DocumentBuilder builder = factory.newDocumentBuilder();
                builder.parse(is);
                pw.println("✅ SUCCESS: Standard JDK parsing works!");
            } catch (Exception e) {
                pw.println("❌ FAILED: Standard JDK parsing failed!");
                e.printStackTrace(pw);
            }

            try (FileInputStream is = new FileInputStream(f)) {
                byte[] bytes = is.readAllBytes();
                pw.println("📜 FILE CONTENT LENGTH: " + bytes.length);
                
                try (java.io.ByteArrayInputStream bais = new java.io.ByteArrayInputStream(bytes)) {
                    JasperCompileManager.compileReport(bais);
                    pw.println("✅ SUCCESS: Jasper compilation works!");
                }
            } catch (Exception e) {
                pw.println("❌ FAILED: Jasper compilation failed!");
                Throwable t = e;
                while (t != null) {
                    pw.println("CAUSE: " + t.getClass().getName() + ": " + t.getMessage());
                    t = t.getCause();
                }
                e.printStackTrace(pw);
            }
            pw.flush();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
