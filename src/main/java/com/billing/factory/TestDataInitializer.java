package com.billing.factory;

import com.billing.config.EnvironmentConfig;
import com.billing.db.DB;
import java.io.File;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Test Data Initializer
 * Auto-seeds test data on local startup
 * Cleans up old PDF files to prevent ghost invoices
 */
public class TestDataInitializer {
    private static final Logger logger = LoggerFactory.getLogger(TestDataInitializer.class);
    
    private static final int THRESHOLD = 200;
    private static final int DEFAULT_CUSTOMER_COUNT = 250;
    
    public static void initializeIfLocal() {
        if (!EnvironmentConfig.isLocal()) {
            logger.info("Not local environment, skipping test data initialization");
            return;
        }
        
        logger.info("Checking test data status...");
        
        // Phase 1: Cleanup old PDFs (only *.pdf files, leave assets)
        cleanupOldPDFs();
        
        // Phase 2: Check existing data
        int existingCustomers = countCustomers();
        
        if (existingCustomers >= THRESHOLD) {
            logger.info("Found {} customers, skipping seed (threshold: {})", existingCustomers, THRESHOLD);
            return;
        }
        
        // Phase 3: Generate test data
        logger.info("Found only {} customers, generating test data...", existingCustomers);
        int count = DEFAULT_CUSTOMER_COUNT;
        
        try {
            int result = TestDataFactory.generateFullInvoiceScenario(count);
            
            // Log to audit (batch logging, not per-row trigger)
            if (result > 0) {
                DB.executeUpdate("INSERT INTO system_audit_log (action, table_affected, records_affected, performed_by, details) " +
                        "VALUES ('TEST_DATA_SEED', 'user_account', " + result + ", 'system', " +
                        "'{\"seed_count\": " + result + ", \"environment\": \"local\"}')");
                
                logger.info("Successfully generated {} test customers", result);
            }
        } catch (Exception e) {
            logger.error("Failed to generate test data", e);
        }
    }
    
    private static void cleanupOldPDFs() {
        String path = DB.getProperty("invoice.output.path");
        String baseDir = path != null ? path : System.getProperty("java.io.tmpdir");
        File invoicesDir = new File(baseDir + "/invoices");
        
        if (!invoicesDir.exists()) {
            logger.debug("Invoices directory does not exist, skipping cleanup");
            return;
        }
        
        File[] pdfs = invoicesDir.listFiles((dir, name) -> name.endsWith(".pdf"));
        
        if (pdfs == null || pdfs.length == 0) {
            logger.debug("No old PDFs to clean up");
            return;
        }
        
        int deleted = 0;
        for (File f : pdfs) {
            if (f.delete()) {
                deleted++;
            }
        }
        
        if (deleted > 0) {
            logger.info("Cleaned up {} old PDF files", deleted);
        }
    }
    
    private static int countCustomers() {
        try {
            var result = DB.executeSelect(
                "SELECT COUNT(*) as cnt FROM user_account WHERE role = 'customer'"
            );
            if (result.isEmpty()) return 0;
            return ((Number) result.get(0).get("cnt")).intValue();
        } catch (Exception e) {
            logger.warn("Failed to count customers: {}", e.getMessage());
            return 0;
        }
    }
    
    public static void main(String[] args) {
        logger.info("TestDataInitializer standalone");
        initializeIfLocal();
    }
}