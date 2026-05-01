package com.billing.factory;

import com.billing.db.DB;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.sql.*;
import java.util.*;

/**
 * MASTER TEST DATA FACTORY (ELITE PRECISION)
 * 
 * Generates high-fidelity telecom data for demo environments.
 * Implements weighted status distributions and dynamic service discovery.
 */
public class TestDataFactory {
    private static final Logger logger = LoggerFactory.getLogger(TestDataFactory.class);
    
    private static final String[] FIRST_NAMES = {
        "Alice", "Bob", "Carol", "David", "Eva", "Frank", "Grace", "Henry", 
        "Ivy", "Jack", "Kate", "Leo", "Mia", "Noah", "Olivia", "Paul",
        "Quinn", "Rachel", "Sam", "Tina", "Uma", "Victor", "Wendy", "Xavier",
        "Yara", "Zoe", "Ahmed", "Mohamed", "Ziad", "Sara", "Fatma", "Mona",
        "Hassan", "Youssef", "Mariam", "Salma", "Hala", "Ibrahim", "Amr", "Nour"
    };
    
    private static final String[] LAST_NAMES = {
        "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis",
        "Khattab", "Mansour", "Zaki", "Salem", "Ezzat", "Fouad", "Wahba", "Badawi"
    };
    
    private static final String[] ADDRESSES = {
        "123 Nile St, Cairo", "456 Pyramid Rd, Giza", "789 Corniche, Alexandria", 
        "101 Luxor Ave, Luxor", "202 Aswan Rd, Aswan", "303 Red Sea Dr, Hurghada"
    };
    
    private static final String[] DOMAINS = {"gmail.com", "telecom.eg", "fmrz.io"};
    private static final Random rand = new Random();

    public static int generateFullInvoiceScenario(int customerCount) {
        String periodStart = "2026-04-01";
        logger.info("🚀 Initiating ELITE SEEDING for {} customers for period {}...", customerCount, periodStart);
        
        try {
            // 1. Guard Check: Avoid duplicate seeding
            boolean alreadyExists = DB.runInTransaction(conn -> {
                String sql = "SELECT 1 FROM cdr WHERE start_time >= ? LIMIT 1";
                try (PreparedStatement pstmt = conn.prepareStatement(sql)) {
                    pstmt.setDate(1, java.sql.Date.valueOf(periodStart));
                    try (ResultSet rs = pstmt.executeQuery()) {
                        return rs.next();
                    }
                }
            });

            if (alreadyExists) {
                logger.info("✔ High-fidelity data already exists for {}, skipping generation.", periodStart);
                return 0;
            }

            // 2. Discover Dynamic IDs
            Map<String, Integer> rateplans = new HashMap<>();
            Map<String, Integer> services = new HashMap<>();
            
            DB.runInTransaction(conn -> {
                try (Statement stmt = conn.createStatement()) {
                    try (ResultSet rs = stmt.executeQuery("SELECT id, name FROM rateplan")) {
                        while (rs.next()) rateplans.put(rs.getString("name"), rs.getInt("id"));
                    }
                    try (ResultSet rs = stmt.executeQuery("SELECT id, name FROM service_package")) {
                        while (rs.next()) services.put(rs.getString("name"), rs.getInt("id"));
                    }
                }
                return null;
            });

            if (rateplans.isEmpty() || services.isEmpty()) {
                logger.error("❌ Ref data missing. Please run 01-tables.sql and 02-data.sql first.");
                return 0;
            }

            // 3. Generate Customers & Contracts
            logger.info("Step 1/3: Populating Weighted Subscriber Base...");
            List<Integer> contractIds = new ArrayList<>();
            List<String> msisdns = new ArrayList<>();
            
            DB.runInTransaction(conn -> {
                for (int i = 1; i <= customerCount; i++) {
                    int cId = createEliteUserAndContract(conn, i, rateplans);
                    contractIds.add(cId);
                    msisdns.add(String.format("2010%08d", i));
                }
                return null;
            });

            // 4. Initialize Consumption
            logger.info("Step 2/3: Warming up Consumption Buckets...");
            DB.runInTransaction(conn -> {
                try (PreparedStatement pstmt = conn.prepareStatement("SELECT initialize_consumption_period(?)")) {
                    pstmt.setDate(1, java.sql.Date.valueOf(periodStart));
                    pstmt.execute();
                }
                return null;
            });

            // 5. Generate CDRs (Bulk JDBC Batching)
            logger.info("Step 3/3: Simulating Network Traffic (Heavy Load)...");
            DB.runInTransaction(conn -> {
                int fileId = insertFileRecord(conn, periodStart);
                generateMassiveCDRBatch(conn, msisdns, fileId, services);
                return null;
            });

            // 6. Bulk Process Rating & Billing
            logger.info("✨ Processing Financial Calculations...");
            DB.executeUpdate("SELECT rate_all_unrated_cdrs()");
            DB.runInTransaction(conn -> {
                try (PreparedStatement pstmt = conn.prepareStatement("SELECT generate_all_bills(?)")) {
                    pstmt.setDate(1, java.sql.Date.valueOf(periodStart));
                    pstmt.execute();
                }
                return null;
            });

            logger.info("✅ ELITE SEEDING COMPLETE. FMRZ BSS is ready for demonstration.");
            return customerCount;

        } catch (Exception e) {
            logger.error("❌ Seeding failed at critical junction", e);
            return 0;
        }
    }

    private static int createEliteUserAndContract(Connection conn, int index, Map<String, Integer> rateplans) throws SQLException {
        String fName = FIRST_NAMES[rand.nextInt(FIRST_NAMES.length)];
        String lName = LAST_NAMES[rand.nextInt(LAST_NAMES.length)];
        String name = fName + " " + lName;
        String msisdn = String.format("2010%08d", index);
        String email = fName.toLowerCase() + "." + lName.toLowerCase() + index + "@" + DOMAINS[rand.nextInt(DOMAINS.length)];
        String address = ADDRESSES[rand.nextInt(ADDRESSES.length)];
        String dob = (1975 + rand.nextInt(30)) + "-" + String.format("%02d-%02d", 1 + rand.nextInt(12), 1 + rand.nextInt(28));

        // 1. Create User
        int userId;
        String userSql = "INSERT INTO user_account (username, password, role, name, email, address, birthdate) VALUES (?, ?, 'customer', ?, ?, ?, ?::DATE) RETURNING id";
        try (PreparedStatement pstmt = conn.prepareStatement(userSql)) {
            pstmt.setString(1, "user" + index);
            pstmt.setString(2, "pass" + index);
            pstmt.setString(3, name);
            pstmt.setString(4, email);
            pstmt.setString(5, address);
            pstmt.setString(6, dob);
            try (ResultSet rs = pstmt.executeQuery()) {
                rs.next(); userId = rs.getInt(1);
            }
        }

        // 2. Select Rateplan (Weighted)
        int rpId;
        double rpRand = rand.nextDouble();
        if (rpRand < 0.5) rpId = rateplans.getOrDefault("Basic Plan", 1);
        else if (rpRand < 0.8) rpId = rateplans.getOrDefault("Premium Gold", 2);
        else rpId = rateplans.getOrDefault("Elite Enterprise", 3);

        // 3. Status Weighting (80% Active, 10% Suspended, 5% Debt, 5% Terminated)
        String status = "active";
        double sRand = rand.nextDouble();
        if (sRand < 0.10) status = "suspended";
        else if (sRand < 0.15) status = "suspended_debt";
        else if (sRand < 0.20) status = "terminated";

        // 4. Create Contract
        String contractSql = "INSERT INTO contract (user_account_id, rateplan_id, msisdn, credit_limit, available_credit, status) VALUES (?, ?, ?, ?, ?, ?)";
        double limit = 1000 + rand.nextInt(5000);
        try (PreparedStatement pstmt = conn.prepareStatement(contractSql)) {
            pstmt.setInt(1, userId);
            pstmt.setInt(2, rpId);
            pstmt.setString(3, msisdn);
            pstmt.setDouble(4, limit);
            pstmt.setDouble(5, limit);
            pstmt.setString(6, status);
            pstmt.executeUpdate();
        }

        return userId;
    }

    private static void generateMassiveCDRBatch(Connection conn, List<String> msisdns, int fileId, Map<String, Integer> services) throws SQLException {
        String sql = "INSERT INTO cdr (file_id, dial_a, dial_b, start_time, duration, service_id, hplmn, vplmn, rated_flag) VALUES (?, ?, ?, ?, ?, ?, '60201', ?, FALSE)";
        
        int voiceId = services.getOrDefault("Voice Pack", 1);
        int dataId = services.getOrDefault("Data Pack", 2);
        int smsId = services.getOrDefault("SMS Pack", 3);

        try (PreparedStatement pstmt = conn.prepareStatement(sql)) {
            for (String msisdn : msisdns) {
                // Each user gets 30-60 CDRs for a busy month simulation
                int volume = 30 + rand.nextInt(30);
                for (int i = 0; i < volume; i++) {
                    double typeRand = rand.nextDouble();
                    String dest = "2010" + String.format("%08d", rand.nextInt(1000000));
                    long usage = 1;
                    int sId = voiceId;

                    if (typeRand < 0.4) { // Voice
                        usage = 30 + rand.nextInt(1200);
                        sId = voiceId;
                    } else if (typeRand < 0.8) { // Data
                        dest = "internet";
                        usage = 512 * 1024 + (long)(rand.nextDouble() * 50 * 1024 * 1024); // 0.5MB to 50MB per session
                        sId = dataId;
                    } else { // SMS
                        sId = smsId;
                    }

                    String vplmn = null;
                    if (rand.nextDouble() < 0.05) vplmn = "20801"; // Roaming (Orange France)

                    String time = "2026-04-" + (1 + rand.nextInt(28)) + " " + String.format("%02d:%02d:%02d", rand.nextInt(24), rand.nextInt(60), rand.nextInt(60));

                    pstmt.setInt(1, fileId);
                    pstmt.setString(2, msisdn);
                    pstmt.setString(3, dest);
                    pstmt.setTimestamp(4, Timestamp.valueOf(time));
                    pstmt.setLong(5, usage);
                    pstmt.setInt(6, sId);
                    if (vplmn != null) pstmt.setString(7, vplmn); else pstmt.setNull(7, Types.VARCHAR);
                    pstmt.addBatch();
                }
            }
            pstmt.executeBatch();
        }
    }

    private static int insertFileRecord(Connection conn, String period) throws SQLException {
        String sql = "INSERT INTO file (file_path, parsed_flag) VALUES (?, TRUE) RETURNING id";
        try (PreparedStatement pstmt = conn.prepareStatement(sql)) {
            pstmt.setString(1, "elite_seed_" + period + ".csv");
            try (ResultSet rs = pstmt.executeQuery()) {
                rs.next(); return rs.getInt(1);
            }
        }
    }

    public static void main(String[] args) {
        generateFullInvoiceScenario(300);
    }
}