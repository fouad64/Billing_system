package com.billing.util;

// Gson tools for serializing (Java->JSON) and deserializing (JSON->Java)
import com.google.gson.*;
import java.lang.reflect.Type;
// Modern Java 8 Date/Time API (SOTA standard)
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

/**
 * THE JAVA 17+ TIME VACCINE
 * 
 * Why this is SOTA:
 * Java 17+ introduced strict module boundaries that block Gson from using "Reflection" 
 * (looking inside classes magically) on internal Java classes like LocalDate.
 * If we don't provide these custom adapters, sending a Customer to the frontend
 * will throw an InaccessibleObjectException and crash the app.
 */
public class GsonTypeAdapters {
    
    // We create ONE pre-configured GSON instance here. 
    // This is memory efficient because we reuse this one instance across all Servlets.
    public static final Gson GSON = new GsonBuilder()
        .registerTypeAdapter(LocalDate.class, new LocalDateAdapter())
        .registerTypeAdapter(LocalDateTime.class, new LocalDateTimeAdapter())
        .setPrettyPrinting()
        .create();

    // --- LOCAL_DATE ADAPTER (e.g., Birthdates: 2000-05-15) ---
    private static class LocalDateAdapter implements JsonSerializer<LocalDate>, JsonDeserializer<LocalDate> {
        // Enforce strict ISO formatting to avoid timezone/locale bugs
        private final DateTimeFormatter formatter = DateTimeFormatter.ISO_LOCAL_DATE;

        // OUTGOING (Java -> JSON): Wrap the formatted date in a JsonPrimitive (JSON string)
        @Override
        public JsonElement serialize(LocalDate date, Type type, JsonSerializationContext context) {
            return new JsonPrimitive(date.format(formatter));
        }

        // INCOMING (JSON -> Java): Read the string from the frontend and parse it into a LocalDate
        @Override
        public LocalDate deserialize(JsonElement json, Type type, JsonDeserializationContext context) throws JsonParseException {
            return LocalDate.parse(json.getAsString(), formatter);
        }
    }

    // --- LOCAL_DATE_TIME ADAPTER (e.g., Invoice timestamps: 2024-04-22T15:30:00) ---
    private static class LocalDateTimeAdapter implements JsonSerializer<LocalDateTime>, JsonDeserializer<LocalDateTime> {
        private final DateTimeFormatter formatter = DateTimeFormatter.ISO_LOCAL_DATE_TIME;

        @Override
        public JsonElement serialize(LocalDateTime dateTime, Type type, JsonSerializationContext context) {
            return new JsonPrimitive(dateTime.format(formatter));
        }

        @Override
        public LocalDateTime deserialize(JsonElement json, Type type, JsonDeserializationContext context) throws JsonParseException {
            return LocalDateTime.parse(json.getAsString(), formatter);
        }
    }
}
