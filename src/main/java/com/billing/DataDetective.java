package com.billing;

import com.billing.db.DB;
import java.util.List;
import java.util.Map;

public class DataDetective {
    public static void main(String[] args) {
        try {
            List<Map<String, Object>> stats = DB.executeSelect("SELECT * FROM get_dashboard_stats()");
            if (stats.isEmpty()) {
                System.out.println("DEBUG: No stats returned!");
                return;
            }
            Map<String, Object> row = stats.get(0);
            System.out.println("DEBUG: Raw Keys from DB: " + row.keySet());
            System.out.println("DEBUG: Raw Data: " + row);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
