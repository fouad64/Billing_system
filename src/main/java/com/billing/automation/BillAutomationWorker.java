package com.billing.automation;

import com.billing.db.DB;
import net.sf.jasperreports.engine.*;
import org.postgresql.PGConnection;
import org.postgresql.PGNotification;

import java.io.File;
import java.io.InputStream;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.Statement;
import java.util.HashMap;
import java.util.Map;

/**
 * BillAutomationWorker listens for PostgreSQL notifications and automatically
 * generates JasperReport PDFs for new bills.
 * 
 * Integrated from R0qiia's logic with production path fixes.
 */
public class BillAutomationWorker implements Runnable {

    // Use environment variable for output path, default to /app/processed/invoices
    private static final String OUTPUT_FOLDER = System.getenv("CDR_PROCESSED_PATH") != null 
            ? System.getenv("CDR_PROCESSED_PATH") + "/invoices" 
            : "processed/invoices";

    private static final String REPORT_TEMPLATE = "invoice.jrxml";

    @Override
    public void run() {
        System.out.println("🚀 [Automation] Starting BillAutomationWorker...");
        
        // Ensure output directory exists
        new File(OUTPUT_FOLDER).mkdirs();

        // For LISTEN/NOTIFY, we should ideally use a dedicated non-pooled connection.
        // We'll fetch the credentials from the environment.
        // Use the same logic as DB.java for robustness
        String url = getEnvOrProp("DB_URL", "db.url");
        String user = getEnvOrProp("DB_USER", "db.user");
        String pass = getEnvOrProp("DB_PASSWORD", "db.password");

        try (Connection conn = java.sql.DriverManager.getConnection(url, user, pass)) {
            // Unwrap PostgreSQL connection to access LISTEN/NOTIFY features
            PGConnection pgConn = conn.unwrap(PGConnection.class);

            try (Statement stmt = conn.createStatement()) {
                // FIX: Set search_path for the direct connection
                stmt.execute("SET search_path TO public, \"$user\";");
                
                stmt.execute("LISTEN generate_bill_event");
                System.out.println("✔ [Automation] Listening for 'generate_bill_event' (Direct Connection)...");
            }

            int heartbeatCount = 0;
            while (!Thread.currentThread().isInterrupted()) {
                // Poll for notifications every 5 seconds
                PGNotification[] notifications = pgConn.getNotifications(5000);

                if (heartbeatCount++ % 12 == 0) { // Every minute
                    System.out.println("💓 [Automation] Heartbeat: Worker is still listening...");
                }

                if (notifications != null) {
                    for (PGNotification notification : notifications) {
                        handleNotification(notification, conn);
                    }
                }
            }
        } catch (Exception e) {
            System.err.println("❌ [Automation] Worker crashed: " + e.getMessage());
            e.printStackTrace();
        }
    }

    private void handleNotification(PGNotification notification, Connection conn) {
        try {
            int billId = Integer.parseInt(notification.getParameter());
            System.out.println("📩 [Automation] New Bill Event: ID " + billId);
            
            generatePdf(billId, conn);
            
        } catch (NumberFormatException e) {
            System.err.println("⚠️ [Automation] Invalid notification parameter: " + notification.getParameter());
        } catch (Exception e) {
            System.err.println("❌ [Automation] Error handling notification: " + e.getMessage());
        }
    }

    private void generatePdf(int billId, Connection conn) {
        try {
            String pdfPath = OUTPUT_FOLDER + "/Bill_" + billId + ".pdf";
            
            // Load template (Try classpath first, then filesystem)
            InputStream reportStream = BillAutomationWorker.class.getResourceAsStream("/" + REPORT_TEMPLATE);
            if (reportStream == null) {
                // Fallback to filesystem for standalone execution
                File f = new File(REPORT_TEMPLATE);
                if (f.exists()) {
                    reportStream = new java.io.FileInputStream(f);
                } else {
                    f = new File("target/classes/" + REPORT_TEMPLATE);
                    if (f.exists()) {
                        reportStream = new java.io.FileInputStream(f);
                    }
                }
            }
            
            if (reportStream == null) {
                throw new RuntimeException("Report template " + REPORT_TEMPLATE + " not found in classpath or filesystem!");
            }
            
            // JasperReports 7: Use JacksonUtil for strict schema validation
            JasperReportsContext context = DefaultJasperReportsContext.getInstance();
            net.sf.jasperreports.jackson.util.JacksonUtil jacksonUtil = net.sf.jasperreports.jackson.util.JacksonUtil.getInstance(context);
            
            // Load and compile
            net.sf.jasperreports.engine.design.JasperDesign design = jacksonUtil.loadXml(reportStream, net.sf.jasperreports.engine.design.JasperDesign.class);
            JasperReport jasperReport = JasperCompileManager.compileReport(design);

            // Set parameters
            Map<String, Object> params = new HashMap<>();
            params.put("BILL_ID", billId);
            
            // Pass Logo as a Stream (Works in JAR/Railway/Podman)
            InputStream logoStream = BillAutomationWorker.class.getResourceAsStream("/logo.svg");
            params.put("LOGO_PATH", logoStream);
            
            params.put("GROUP_NAME", "FMRZ Telecom Group");
            params.put("COMPANY_CARE", "111 (Free from FMRZ)");
            params.put("COMPANY_WEB", "www.fmrz-telecom.com");
            params.put("COMPANY_EMAIL", "support@fmrz-telecom.com");

            // Fill report
            JasperPrint print = JasperFillManager.fillReport(jasperReport, params, conn);

            // Export to PDF
            JasperExportManager.exportReportToPdfFile(print, pdfPath);
            System.out.println("✅ [Automation] PDF generated: " + pdfPath);

            // Register the generated file path in the 'invoice' table
            try (PreparedStatement pstmt = conn.prepareStatement(
                    "INSERT INTO invoice (bill_id, pdf_path) VALUES (?, ?) " +
                    "ON CONFLICT (bill_id) DO UPDATE SET pdf_path = EXCLUDED.pdf_path")) {
                pstmt.setInt(1, billId);
                pstmt.setString(2, pdfPath);
                pstmt.executeUpdate();
                System.out.println("💾 [Automation] Invoice table updated for Bill " + billId);
            }

        } catch (Exception e) {
            System.err.println("❌ [Automation] Jasper generation failed for Bill " + billId + ": " + e.getMessage());
            e.printStackTrace();
        }
    }

    private static String getEnvOrProp(String envKey, String propKey) {
        // 1. Check Environment Variables
        String val = System.getenv(envKey);
        
        // 2. Check System Properties (-DDB_URL=...)
        if (val == null || val.trim().isEmpty()) {
            val = System.getProperty(envKey);
        }

        // 3. Check db.properties fallback
        if (val == null || val.trim().isEmpty() || val.contains("REPLACE_WITH_ENV_VAR")) {
            // We'll try to load db.properties manually here for the worker
            try (InputStream input = DB.class.getClassLoader().getResourceAsStream("db.properties")) {
                if (input != null) {
                    java.util.Properties props = new java.util.Properties();
                    props.load(input);
                    val = props.getProperty(propKey);
                }
            } catch (Exception ignored) {}
        }
        
        // LISTEN/NOTIFY doesn't work through a pooler
        if (val != null && val.contains("-pooler")) {
            val = val.replace("-pooler", "");
            System.out.println("ℹ [Automation] Stripping '-pooler' from URL for direct LISTEN/NOTIFY connection.");
        }
        
        return val;
    }
}
