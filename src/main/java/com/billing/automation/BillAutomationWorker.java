package com.billing.automation;

import com.billing.db.DB;
import net.sf.jasperreports.engine.*;
import org.postgresql.PGConnection;
import org.postgresql.PGNotification;

import java.io.File;
import java.sql.Connection;
import java.sql.Statement;
import java.util.HashMap;
import java.util.Map;

public class BillAutomationWorker implements Runnable {

    private static final String REPORT_PATH = "reports/Bill.jasper";
    private static final String OUTPUT_FOLDER = "generated_reports/invoices/";

    @Override
    public void run() {

        try (Connection conn = DB.getConnection()) {

            PGConnection pgConn = conn.unwrap(PGConnection.class);

            try (Statement stmt = conn.createStatement()) {
                stmt.execute("LISTEN generate_bill_event");
            }

            System.out.println("✔ Worker started: Listening for bill events...");

            while (!Thread.currentThread().isInterrupted()) {

                PGNotification[] notifications = pgConn.getNotifications(5000);

                if (notifications == null) continue;

                for (PGNotification notification : notifications) {

                    try {
                        int billId = Integer.parseInt(notification.getParameter());
                        System.out.println("📩 Event received for Bill ID: " + billId);

                        generatePdf(billId);

                    } catch (Exception ex) {
                        System.err.println("Invalid notification payload: " + notification.getParameter());
                    }
                }
            }

        } catch (Exception e) {
            System.err.println("❌ Worker crashed: " + e.getMessage());
            e.printStackTrace();
        }
    }

    private void generatePdf(int billId) {

        try (Connection conn = DB.getConnection()) {

            // Ensure output directory exists
            File folder = new File(OUTPUT_FOLDER);
            if (!folder.exists()) {
                folder.mkdirs();
            }

            String pdfPath = OUTPUT_FOLDER + "Bill_" + billId + ".pdf";

            // Jasper parameters
            Map<String, Object> params = new HashMap<>();
            params.put("BILL_ID", billId);

            // Fill report (JasperReports 7.0.6 compatible)
            JasperPrint print = JasperFillManager.fillReport(
                    REPORT_PATH,
                    params,
                    conn
            );

            // Export PDF
            JasperExportManager.exportReportToPdfFile(print, pdfPath);

            System.out.println("✅ PDF generated: " + pdfPath);

        } catch (Exception e) {
            System.err.println("❌ Jasper generation failed for Bill " + billId);
            e.printStackTrace();
        }
    }
}