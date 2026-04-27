/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */

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


/**
 *
 * @author roqaya
 */

public class BillAutomationWorker implements Runnable {

    private static final String REPORT_PATH =
            "Billing_System_Invoices/Bill_Template.jasper";

    private static final String OUTPUT_FOLDER =
            System.getProperty("user.home")
                    + "/JaspersoftWorkspace/Billing_System_Invoices/Outputs/";

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

                        // ✅ reuse SAME connection
                        generatePdf(billId, conn);

                    } catch (Exception ex) {
                        System.err.println("Invalid notification payload: "
                                + notification.getParameter());
                    }
                }
            }

        } catch (Exception e) {
            System.err.println("❌ Worker crashed: " + e.getMessage());
            e.printStackTrace();
        }
    }

    // ✅ NOW uses existing connection (no new DB connection)
    private void generatePdf(int billId, Connection conn) {

        try {

            // Ensure output directory exists
            File folder = new File(OUTPUT_FOLDER);
            if (!folder.exists()) {
                folder.mkdirs();
            }

            String pdfPath = OUTPUT_FOLDER + "/Bill_" + billId + ".pdf";

            // Jasper parameters
            Map<String, Object> params = new HashMap<>();
            params.put("BILL_ID", billId);

            // Generate report using :contentReference[oaicite:0]{index=0}
            JasperPrint print = JasperFillManager.fillReport(
                    REPORT_PATH,
                    params,
                    conn
            );

            // Export PDF
            JasperExportManager.exportReportToPdfFile(print, pdfPath);

            System.out.println("✅ PDF generated: " + pdfPath);

            // Save invoice in database using :contentReference[oaicite:1]{index=1}
            try (var pstmt = conn.prepareStatement(
                    "SELECT generate_invoice(?, ?)")) {

                pstmt.setInt(1, billId);
                pstmt.setString(2, pdfPath);

                pstmt.execute();

                System.out.println("💾 Invoice saved in DB for Bill ID: " + billId);
            }

        } catch (Exception e) {
            System.err.println("❌ Jasper generation failed for Bill " + billId);
            e.printStackTrace();
        }
    }
}