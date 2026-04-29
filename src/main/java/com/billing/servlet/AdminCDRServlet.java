package com.billing.servlet;

import com.billing.db.DB;
import com.billing.cdr.CDRParser;

import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.annotation.MultipartConfig;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.Part;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.Map;

@WebServlet("/api/admin/cdr/*")
@MultipartConfig(
        maxFileSize = 10 * 1024 * 1024,
        maxRequestSize = 10 * 1024 * 1024
)
public class AdminCDRServlet extends BaseServlet {

    // -----------------------------
    // FIXED PROJECT ROOT
    // -----------------------------
    private static final String PROJECT_ROOT =
            System.getenv("APP_ROOT") != null
                ? System.getenv("APP_ROOT")
                : System.getProperty("catalina.base") != null
                    ? System.getProperty("catalina.base") + "/webapps/ROOT"
                    : ".";

    private File ensureDir(String subfolder) {
        File dir = new File(PROJECT_ROOT, subfolder);

        if (!dir.exists() && !dir.mkdirs()) {
            throw new RuntimeException("Failed to create directory: " + dir.getAbsolutePath());
        }

        System.out.println("[CDR] Using directory: " + dir.getAbsolutePath());
        return dir;
    }

    // ==========================================================
    // GET → FETCH CDRs
    // ==========================================================
    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws IOException {
        handle(res, () -> {
            int limit = req.getParameter("limit") != null
                    ? Integer.parseInt(req.getParameter("limit"))
                    : 50;

            int offset = req.getParameter("offset") != null
                    ? Integer.parseInt(req.getParameter("offset"))
                    : 0;

            String sql = "SELECT * FROM get_cdrs(?, ?)";

            return DB.executeSelect(sql, limit, offset);
        });
    }

    // ==========================================================
    // POST → UPLOAD OR IMPORT
    // ==========================================================
    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws IOException {
        String path = req.getPathInfo();

        try {

            // --------------------------------------------------
            // 1) UPLOAD CSV FILE → /api/admin/cdr/upload
            // --------------------------------------------------
            if ("/upload".equals(path)) {

                File inputDir = ensureDir("input");

                Part filePart = req.getPart("file");

                if (filePart == null) {
                    sendError(res, 400, "No file uploaded");
                    return;
                }

                String fileName = new File(filePart.getSubmittedFileName()).getName();

                if (!fileName.toLowerCase().endsWith(".csv")) {
                    sendError(res, 400, "Only CSV files allowed");
                    return;
                }

                File dest = new File(inputDir, fileName);

                System.out.println("[CDR-UPLOAD] Saving to: " + dest.getAbsolutePath());

                try (InputStream in = filePart.getInputStream();
                     FileOutputStream out = new FileOutputStream(dest)) {
                    in.transferTo(out);
                }

                System.out.println("[CDR-UPLOAD] File saved successfully");

                sendJson(res, Map.of(
                        "success", true,
                        "message", "File uploaded successfully",
                        "file", fileName
                ));
                return;
            }

            // --------------------------------------------------
            // 2) IMPORT ALL FILES → /api/admin/cdr/import
            // --------------------------------------------------
            if ("/import".equals(path)) {

                System.out.println("[CDR-IMPORT] Triggered via Admin Panel");

                File inputDir = ensureDir("input");
                File processedDir = ensureDir("processed");

                File[] files = inputDir.listFiles((dir, name) -> name.toLowerCase().endsWith(".csv"));
                int fileCount = (files != null) ? files.length : 0;

                if (fileCount == 0) {
                    sendError(res, 400, "No CSV files found in input directory");
                    return;
                }

                CDRParser.processAll(
                        inputDir.getAbsolutePath(),
                        processedDir.getAbsolutePath()
                );

                System.out.println("[CDR-IMPORT] Success. Processed " + fileCount + " files.");

                sendJson(res, Map.of(
                        "success", true,
                        "message", "Import complete! Processed " + fileCount + " file(s).",
                        "count", fileCount
                ));
                return;
            }

            sendError(res, 404, "Unknown CDR endpoint: " + path);

        } catch (Exception e) {
            e.printStackTrace();
            sendError(res, 500, "CDR operation failed: " + e.getMessage());
        }
    }
}