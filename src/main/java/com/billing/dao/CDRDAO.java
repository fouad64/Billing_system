package com.billing.dao;

import com.billing.db.DB;
import java.sql.*;

/**
 * CDR (Call Detail Record) DAO
 * Professionally integrates Mohamed's Rating Engine.
 */
public class CDRDAO {

    /**
     * Inserts a raw CDR and returns its generated ID.
     */
    public int insert(int fileId, String dialA, String dialB, Timestamp startTime, 
                      int duration, Integer serviceId, String hplmn, String vplmn, 
                      Double externalCharges) throws SQLException {
        
        String sql = "{ ? = call insert_cdr(?, ?, ?, ?, ?, ?, ?, ?, ?) }";
        try (Connection conn = DB.getConnection();
             CallableStatement cs = conn.prepareCall(sql)) {
            
            cs.registerOutParameter(1, Types.INTEGER);
            cs.setInt(2, fileId);
            cs.setString(3, dialA);
            cs.setString(4, dialB);
            cs.setTimestamp(5, startTime);
            cs.setInt(6, duration);
            if (serviceId != null) cs.setInt(7, serviceId); else cs.setNull(7, Types.INTEGER);
            cs.setString(8, hplmn);
            cs.setString(9, vplmn);
            if (externalCharges != null) cs.setDouble(10, externalCharges); else cs.setDouble(10, 0.0);
            
            cs.execute();
            return cs.getInt(1);
        }
    }

    /**
     * PROFESSIONALLY INTEGRATED: Triggers Mohamed's 'rate_cdr' SQL function.
     * This is the "Brain" of the billing system—it calculates costs and updates balances.
     */
    public void rate(int cdrId) throws SQLException {
        String sql = "{ call rate_cdr(?) }";
        try (Connection conn = DB.getConnection();
             CallableStatement cs = conn.prepareCall(sql)) {
            cs.setInt(1, cdrId);
            cs.execute();
        }
    }
}
