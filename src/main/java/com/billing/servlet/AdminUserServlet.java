package com.billing.servlet;

import com.billing.db.DB;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.List;
import java.util.Map;

@WebServlet("/api/admin/customers/*")
public class AdminUserServlet extends BaseServlet {

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws IOException {
        String pathParam = getPathParam(req);
        
        try {
            if (pathParam == null) {
                // Return all customers
                sendJson(res, DB.executeSelect("SELECT id, username, name, email, role FROM user_account WHERE role = 'customer' ORDER BY name"));
            } else {
                int id = Integer.parseInt(pathParam);
                List<Map<String, Object>> list = DB.executeSelect("SELECT id, username, name, email, role, address, birthdate FROM user_account WHERE id = ?", id);
                if (list.isEmpty()) sendError(res, 404, "User not found");
                else sendJson(res, list.get(0));
            }
        } catch (Exception e) {
            sendError(res, 500, e.getMessage());
        }
    }
}
