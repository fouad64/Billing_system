package com.billing.servlet;

import com.billing.db.DB;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.List;
import java.util.Map;

@WebServlet("/api/admin/contracts/*")
public class AdminContractServlet extends BaseServlet {

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws IOException {
        String path = req.getPathInfo();
        try {
            if (path == null || "/".equals(path)) {
                String sql = "SELECT c.id, c.msisdn, c.status, c.available_credit as \"availableCredit\", " +
                             "u.name as \"customerName\", r.name as \"rateplanName\" " +
                             "FROM contract c " +
                             "JOIN user_account u ON c.user_account_id = u.id " +
                             "LEFT JOIN rateplan r ON c.rateplan_id = r.id " +
                             "ORDER BY c.id DESC";
                sendJson(res, DB.executeSelect(sql));
            } else {
                int id = Integer.parseInt(path.substring(1));
                String sql = "SELECT c.*, u.name as \"customerName\", r.name as \"rateplanName\", " +
                             "c.available_credit as \"availableCredit\" " +
                             "FROM contract c " +
                             "JOIN user_account u ON c.user_account_id = u.id " +
                             "LEFT JOIN rateplan r ON c.rateplan_id = r.id " +
                             "WHERE c.id = ?";
                List<Map<String, Object>> list = DB.executeSelect(sql, id);
                if (list.isEmpty()) sendError(res, 404, "Contract not found");
                else sendJson(res, list.get(0));
            }
        } catch (Exception e) {
            sendError(res, 500, e.getMessage());
        }
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws IOException {
        try {
            Map body = readJson(req, Map.class);
            List<Map<String, Object>> result = DB.executeSelect(
                "INSERT INTO contract (customer_id, rateplan_id, status) VALUES (?, ?, ?) RETURNING *",
                body.get("customerId"), body.get("ratePlanId"), body.get("status")
            );
            res.setStatus(201);
            sendJson(res, result.get(0));
        } catch (Exception e) {
            sendError(res, 500, e.getMessage());
        }
    }
}
