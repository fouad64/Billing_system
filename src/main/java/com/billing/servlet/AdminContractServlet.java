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
                sendJson(res, DB.executeSelect("SELECT * FROM contract ORDER BY id DESC"));
            } else {
                int id = Integer.parseInt(path.substring(1));
                List<Map<String, Object>> list = DB.executeSelect("SELECT * FROM contract WHERE id = ?", id);
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
