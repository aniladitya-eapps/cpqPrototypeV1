public with sharing class SpreadsheetRulesFromFiles {
    // Put your ContentVersion Ids here
    public static final Id RULES_VERSION_ID    = '068am00000HCPKDAA5';
    public static final Id OUTCOMES_VERSION_ID = '068am00000HCPLpAAP';

    public static String readRulesCsv()    { return readCsv(RULES_VERSION_ID); }
    public static String readOutcomesCsv() { return readCsv(OUTCOMES_VERSION_ID); }

    private static String readCsv(Id contentVersionId) {
        ContentVersion cv = [
            SELECT VersionData, FileType
            FROM ContentVersion WHERE Id = :contentVersionId
        ];
        // If you uploaded xlsx, export CSV once and upload CSV files; or parse xlsx via 3rd-party lib (not typical in Apex).
        // Easiest: keep the file as CSV.
        Blob b = cv.VersionData;
        return b.toString(); // CSV text
    }
}
