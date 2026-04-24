package com.billing.dao;

import com.billing.db.DB;
import com.billing.model.UserAccount;
import java.sql.*;

public class UserAccountDAO {

    public UserAccount login(String username, String password) throws SQLException {
        String sql = "SELECT * FROM user_account WHERE username = ?";
        try (Connection conn = DB.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            
            stmt.setString(1, username);
            ResultSet rs = stmt.executeQuery();
            
            if (rs.next()) {
                String storedPassword = rs.getString("password");
                if (password.equals(storedPassword)) {
                    return mapRow(rs);
                }
            }
        }
        return null;
    }

    /**
     * PROFESSIONALLY INTEGRATED: Calls Mohamed's 'create_customer' SQL function.
     * This ensures all database-level triggers and setup logic are executed.
     */
    public void register(UserAccount user) throws SQLException {
        String sql = "{ ? = call create_customer(?, ?, ?, ?, ?, ?) }";
        try (Connection conn = DB.getConnection();
             CallableStatement cs = conn.prepareCall(sql)) {
            
            cs.registerOutParameter(1, Types.INTEGER);
            cs.setString(2, user.getUsername());
            cs.setString(3, user.getPassword()); // Plain text per request
            cs.setString(4, user.getName());
            cs.setString(5, user.getEmail());
            cs.setString(6, user.getAddress());
            cs.setObject(7, user.getBirthdate());
            
            cs.execute();
            user.setId(cs.getInt(1));
        }
    }

    public UserAccount getById(int id) throws SQLException {
        String sql = "SELECT * FROM user_account WHERE id = ?";
        try (Connection conn = DB.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, id);
            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) return mapRow(rs);
            }
        }
        return null;
    }

    private UserAccount mapRow(ResultSet rs) throws SQLException {
        return new UserAccount(
            rs.getInt("id"),
            rs.getString("username"),
            rs.getString("password"),
            rs.getString("role"),
            rs.getString("name"),
            rs.getString("email"),
            rs.getString("address"),
            rs.getObject("birthdate", java.time.LocalDate.class)
        );
    }
}
