package com.billing.servlet;

import com.billing.db.DB;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.List;
import java.util.Map;

@WebServlet("/api/customer/profile")
public class CustomerProfileServlet extends BaseServlet {

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws IOException {
        // Since we archived Auth, we might not have a session user.
        // For testing, we'll try to get it from the session, or allow a param.
        Map<String, Object> sessionUser = (Map<String, Object>) req.getSession().getAttribute("user");
        
        Integer userId = null;
        if (sessionUser != null) {
            userId = ((Number) sessionUser.get("id")).intValue();
        } else if (req.getParameter("id") != null) {
            userId = Integer.parseInt(req.getParameter("id"));
        }

        if (userId == null) {
            sendError(res, 401, "Not logged in (and no ID provided)");
            return;
        }
        
        try {
            List<Map<String, Object>> profile = DB.executeSelect(
                "SELECT id, username, name, email, role, address, birthdate FROM user_account WHERE id = ?", 
                userId
            );
            if (profile.isEmpty()) sendError(res, 404, "Profile not found");
            else sendJson(res, profile.get(0));
        } catch (Exception e) {
            sendError(res, 500, e.getMessage());
        }
    }
}
