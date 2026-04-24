package com.billing.servlet;

import com.billing.db.DB;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.List;
import java.util.Map;

@WebServlet("/api/admin/cdr/*")
public class AdminCDRServlet extends BaseServlet {

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws IOException {
        try {
            // Fetch all CDRs with their related contract info
            List<Map<String, Object>> cdrs = DB.executeSelect(
                "SELECT c.*, co.msisdn as contract_msisdn " +
                "FROM cdr c " +
                "LEFT JOIN contract co ON c.contract_id = co.id " +
                "ORDER BY c.start_time DESC LIMIT 1000"
            );
            sendJson(res, cdrs);
        } catch (Exception e) {
            sendError(res, 500, e.getMessage());
        }
    }
}
