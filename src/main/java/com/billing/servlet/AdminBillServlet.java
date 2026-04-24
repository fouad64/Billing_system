package com.billing.servlet;

import com.billing.db.DB;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.List;
import java.util.Map;

// Maps this servlet to /api/admin/bills and any sub-paths (like /api/admin/bills/5)
@WebServlet("/api/admin/bills/*")
public class AdminBillServlet extends BaseServlet {

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws IOException {
        try {
            String pathParam = getPathParam(req);
            if (pathParam != null) {
                // Path: /api/admin/bills/{id}
                int id = Integer.parseInt(pathParam);
                List<Map<String, Object>> list = DB.executeSelect("SELECT * FROM bill WHERE id = ?", id);
                if (list.isEmpty()) sendError(res, 404, "Bill not found");
                else sendJson(res, list.get(0));
            } else {
                String contractId = req.getParameter("contract_id");
                if (contractId != null) {
                    sendJson(res, DB.executeSelect("SELECT * FROM bill WHERE contract_id = ? ORDER BY billing_period_start DESC", Integer.parseInt(contractId)));
                } else {
                    sendJson(res, DB.executeSelect("SELECT * FROM bill ORDER BY billing_date DESC"));
                }
            }
        } catch (NumberFormatException e) {
            sendError(res, 400, "Invalid ID format");
        } catch (Exception e) {
            sendError(res, 500, e.getMessage());
        }
    }
}
