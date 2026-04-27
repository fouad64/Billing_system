package com.billing.db;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import java.io.InputStream;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.Properties;

/**
 * Database Connection Manager
 * 
 * This class uses HikariCP (Connection Pool) to manage database connections.
 * Instead of opening a new connection every time, it keeps a pool of connections 
 * ready to use, significantly reducing latency.
 */
public class DB {
    private static final Properties props = new Properties();
    private static final HikariDataSource dataSource;
    private static final String URL  = System.getenv("DB_URL");
    private static final String USER = System.getenv("DB_USER");
    private static final String PASS = System.getenv("DB_PASS");
    static {
        try {
            // Load db.properties only if it exists (local dev)
            InputStream input = DB.class.getClassLoader().getResourceAsStream("db.properties");
            if (input != null) {
                props.load(input);
            }

            // Prefer environment variables, fall back to db.properties
            String url  = System.getenv("DB_URL")  != null ? System.getenv("DB_URL")  : props.getProperty("db.url");
            String user = System.getenv("DB_USER") != null ? System.getenv("DB_USER") : props.getProperty("db.user");
            String pass = System.getenv("DB_PASS") != null ? System.getenv("DB_PASS") : props.getProperty("db.password");

            HikariConfig config = new HikariConfig();
            config.setDriverClassName("org.postgresql.Driver");
            config.setJdbcUrl(url);
            config.setUsername(user);
            config.setPassword(pass);

            config.setMaximumPoolSize(10);
            config.setMinimumIdle(2);
            config.setIdleTimeout(300000);
            config.setConnectionTimeout(20000);
            config.setMaxLifetime(1800000);

            config.addDataSourceProperty("cachePrepStmts", "true");
            config.addDataSourceProperty("prepStmtCacheSize", "250");
            config.addDataSourceProperty("prepStmtCacheSqlLimit", "2048");

            dataSource = new HikariDataSource(config);

        } catch (Exception e) {
            System.err.println("CRITICAL: Failed to initialize HikariCP Connection Pool");
            e.printStackTrace();
            throw new RuntimeException(e);
        }
    }

    /**
     * Returns a connection from the pool.
     * The caller MUST still close it (try-with-resources) to return it to the pool.
     */
    public static Connection getConnection() throws SQLException {
        return dataSource.getConnection();
    }

    public static String getProperty(String key) {
        return props.getProperty(key);
    }

    /**
     * Executes a stored procedure or function call.
     * Example: DB.executeCall("generate_bill", 101, "2023-10-01");
     */
    public static void executeCall(String functionName, Object... params) throws SQLException {
        StringBuilder sql = new StringBuilder("{ call ").append(functionName).append("(");
        for (int i = 0; i < params.length; i++) {
            sql.append(i == 0 ? "?" : ", ?");
        }
        sql.append(") }");

        try (Connection conn = getConnection();
             java.sql.CallableStatement cs = conn.prepareCall(sql.toString())) {
            for (int i = 0; i < params.length; i++) {
                cs.setObject(i + 1, params[i]);
            }
            cs.execute();
        }
    }

    /**
     * Executes a SELECT statement and returns a List of Maps.
     * This format is optimized for JSON serialization via GSON.
     */
    public static java.util.List<java.util.Map<String, Object>> executeSelect(String sql, Object... params) throws SQLException {
        java.util.List<java.util.Map<String, Object>> rows = new java.util.ArrayList<>();
        try (Connection conn = getConnection();
             java.sql.PreparedStatement ps = conn.prepareStatement(sql)) {
            for (int i = 0; i < params.length; i++) {
                ps.setObject(i + 1, params[i]);
            }
            try (java.sql.ResultSet rs = ps.executeQuery()) {
                java.sql.ResultSetMetaData md = rs.getMetaData();
                int columns = md.getColumnCount();
                while (rs.next()) {
                    java.util.Map<String, Object> row = new java.util.HashMap<>();
                    for (int i = 1; i <= columns; i++) {
                        Object val = rs.getObject(i);
                        if (val != null && val.getClass().getName().contains("PGobject")) {
                            val = val.toString();
                        }
                        row.put(md.getColumnLabel(i), val);
                    }
                    rows.add(row);
                }
            }
        }
        return rows;
    }

    /**
     * Executes an INSERT, UPDATE, or DELETE statement.
     * @return The number of rows affected.
     */
    public static int executeUpdate(String sql, Object... params) throws SQLException {
        try (Connection conn = getConnection();
             java.sql.PreparedStatement ps = conn.prepareStatement(sql)) {
            for (int i = 0; i < params.length; i++) {
                ps.setObject(i + 1, params[i]);
            }
            return ps.executeUpdate();
        }
    }

    /**
     * Shut down the pool (useful for clean app shutdown).
     */
    public static void closePool() {
        if (dataSource != null) {
            dataSource.close();
        }
    }
}
