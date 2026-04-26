package com.billing.servlet;

import com.billing.db.DB;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.List;
import java.util.Map;

@WebServlet("/api/admin/addons/*")
public class AdminAddonServlet extends BaseServlet {

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws IOException {
        handle(res, () -> {
            String path = req.getPathInfo();

            // Get available addons: GET /api/admin/addons
            if (path == null || "/".equals(path)) {
                return DB.executeSelect("SELECT * FROM addon ORDER BY name ASC");
            }

            // Get addons for a specific contract: GET /api/admin/addons/{contractId}
            int contractId = Integer.parseInt(path.substring(1));
            return DB.executeSelect("SELECT * FROM get_contract_addons(?)", contractId);
        });
    }
}

