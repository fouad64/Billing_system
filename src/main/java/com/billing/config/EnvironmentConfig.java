package com.billing.config;

public class EnvironmentConfig {

    public static Environment getEnvironment() {
        // Check Railway indicators
        if (System.getenv("RAILWAY_STATIC_URL") != null || 
            System.getenv("RAILWAY_ENVIRONMENT") != null) {
            return Environment.RAILWAY;
        }
        
        // Check local indicators
        if (System.getenv("CDR_INPUT_PATH") != null || 
            System.getProperty("cdr.input.path") != null) {
            return Environment.LOCAL;
        }
        
        return Environment.UNKNOWN;
    }

    public static boolean isLocal() {
        return getEnvironment() == Environment.LOCAL;
    }

    public static boolean isProduction() {
        return getEnvironment() == Environment.RAILWAY;
    }

    public static String getEnvironmentName() {
        return getEnvironment().name().toLowerCase();
    }

    public static String getEnvironmentDisplayName() {
        Environment env = getEnvironment();
        switch (env) {
            case RAILWAY:
                return "PRODUCTION";
            case LOCAL:
                return "DEVELOPMENT";
            default:
                return "UNKNOWN";
        }
    }
}