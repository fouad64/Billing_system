package com.billing.cdr;

import com.billing.db.DB;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.*;
import java.nio.file.*;
import java.util.*;

/**
 * CDR Importer
 * Generic carrier CSV importer
 * Does NOT trust external_charges - uses internal rate_cdr() for billing
 */
public class CDRImporter {
    private static final Logger logger = LoggerFactory.getLogger(CDRImporter.class);
    
    // CSV format: call_id,calling_number,called_number,start_time,duration_seconds,service_type,roaming_flag,hplmn,vplmn,external_charges
    private static final String[] HEADERS = {
        "call_id", "calling_number", "called_number", "start_time", 
        "duration_seconds", "service_type", "roaming_flag", "hplmn", "vplmn", "external_charges"
    };
    
    public static int importFromCarrier(String filePath) throws Exception {
        logger.info("Starting carrier CDR import from: {}", filePath);
        
        Path path = Paths.get(filePath);
        if (!Files.exists(path)) {
            throw new FileNotFoundException("File not found: " + filePath);
        }
        
        // Read file into lines
        List<String> lines = Files.readAllLines(path);
        
        if (lines.isEmpty()) {
            throw new IllegalArgumentException("Empty file");
        }
        
        // Parse header
        String headerLine = lines.get(0).toLowerCase().trim();
        String[] header = headerLine.split(",");
        
        // Validate required columns
        int[] colIndex = validateHeaders(header);
        
        // Find or create file record
        String fileName = path.getFileName().toString();
        String fileId = createFileRecord(fileName);
        
        int imported = 0;
        int skipped = 0;
        
        // Process data rows (skip header)
        for (int i = 1; i < lines.size(); i++) {
            String line = lines.get(i).trim();
            if (line.isEmpty()) continue;
            
            try {
                String[] values = parseCSVLine(line);
                
                if (values.length < header.length) {
                    logger.warn("Line {} has fewer columns than header, skipping", i + 1);
                    skipped++;
                    continue;
                }
                
                // Extract fields
                String callId = values[colIndex[0]];
                String callingNumber = values[colIndex[1]];
                String calledNumber = values[colIndex[2]];
                String startTime = values[colIndex[3]];
                int duration = Integer.parseInt(values[colIndex[4]].trim());
                String serviceType = values[colIndex[5]].trim().toUpperCase();
                String roamingFlag = values[colIndex[6]].trim().toUpperCase();
                String hplmn = colIndex[7] >= 0 ? values[colIndex[7]].trim() : "EGYVO";
                String vplmn = colIndex[8] >= 0 ? values[colIndex[8]].trim() : "";
                // external_charges NOT trusted - for audit/comparison only
                
                // Map service type to service_package ID
                int serviceId = mapServiceType(serviceType, "Y".equals(roamingFlag));
                
                DB.executeSelect("SELECT insert_cdr(" + fileId + ", '" + callingNumber + "', '" + calledNumber + "', " +
                        "'" + startTime + "', " + duration + ", " + serviceId + ", " +
                        "'" + hplmn + "', '" + vplmn + "', 0)");
                
                imported++;
                
            } catch (Exception e) {
                logger.warn("Failed to process line {}: {}", i + 1, e.getMessage());
                skipped++;
            }
        }
        
        // Rate all imported CDRs (NOT trusting external_charges)
        logger.info("Rating {} CDRs...", imported);
        int rated = rateAllCDRs();
        
        // Mark file as parsed
        DB.executeSelect("SELECT set_file_parsed(" + fileId + ")");
        
        // Log to audit
        DB.executeUpdate("INSERT INTO system_audit_log (action, table_affected, records_affected, performed_by, details) " +
                "VALUES ('CARRIER_CDR_IMPORT', 'cdr', " + imported + ", 'system', " +
                "'{\"file\": \"" + fileName + "\", \"rated\": " + rated + ", \"skipped\": " + skipped + "}')");
        
        logger.info("Import complete: {} imported, {} rated, {} skipped", imported, rated, skipped);
        
        return imported;
    }
    
    private static int[] validateHeaders(String[] header) {
        int[] colIndex = new int[HEADERS.length];
        Arrays.fill(colIndex, -1);
        
        for (int i = 0; i < header.length; i++) {
            String h = header[i].trim().toLowerCase();
            for (int j = 0; j < HEADERS.length; j++) {
                if (h.equals(HEADERS[j])) {
                    colIndex[j] = i;
                    break;
                }
            }
        }
        
        // Validate required columns
        if (colIndex[1] < 0 || colIndex[2] < 0 || colIndex[3] < 0 || 
            colIndex[4] < 0 || colIndex[5] < 0) {
            throw new IllegalArgumentException("Missing required columns. Required: " + 
                String.join(", ", Arrays.copyOfRange(HEADERS, 0, 6)));
        }
        
        return colIndex;
    }
    
    private static String[] parseCSVLine(String line) {
        List<String> values = new ArrayList<>();
        StringBuilder sb = new StringBuilder();
        boolean inQuotes = false;
        
        for (char c : line.toCharArray()) {
            if (c == '"') {
                inQuotes = !inQuotes;
            } else if (c == ',' && !inQuotes) {
                values.add(sb.toString().trim());
                sb = new StringBuilder();
            } else {
                sb.append(c);
            }
        }
        values.add(sb.toString().trim());
        
        return values.toArray(new String[0]);
    }
    
    private static String createFileRecord(String fileName) throws Exception {
        String fileId = DB.executeInsert(
            "INSERT INTO file (file_path) VALUES (?)",
            fileName
        );
        return fileId;
    }
    
    private static int mapServiceType(String serviceType, boolean isRoaming) {
        // Map carrier service type to our service_package IDs
        switch (serviceType) {
            case "VOICE":
                return isRoaming ? 5 : 1; // Roaming Voice Pack or Voice Pack
            case "DATA":
                return isRoaming ? 6 : 2; // Roaming Data Pack or Data Pack
            case "SMS":
                return isRoaming ? 7 : 3; // Roaming SMS Pack or SMS Pack
            default:
                return 1; // Default to voice
        }
    }
    
    private static int rateAllCDRs() throws Exception {
        var result = DB.executeSelect("SELECT rate_all_unrated_cdrs() as rated");
        return ((Number) result.get(0).get("rated")).intValue();
    }
    
    public static void main(String[] args) throws Exception {
        if (args.length < 1) {
            System.out.println("Usage: CDRImporter <csv_file_path>");
            System.exit(1);
        }
        
        importFromCarrier(args[0]);
    }
}