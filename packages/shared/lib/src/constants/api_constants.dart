/// Supabase API table names, function names, and bucket names.
class ApiConstants {
  ApiConstants._();

  // Table names
  static const String parksTable = 'parks';
  static const String highwaySegmentsTable = 'highway_segments';
  static const String checkpostsTable = 'checkposts';
  static const String userProfilesTable = 'user_profiles';
  static const String vehiclePassagesTable = 'vehicle_passages';
  static const String violationsTable = 'violations';
  static const String violationOutcomesTable = 'violation_outcomes';
  static const String proactiveOverstayAlertsTable =
      'proactive_overstay_alerts';
  static const String syncMetadataTable = 'sync_metadata';

  // Edge Function names
  static const String smsWebhookFunction = 'sms-webhook';
  static const String checkOverstayFunction = 'check-overstay';
  static const String matchPassageFunction = 'match-passage';
  static const String createRangerFunction = 'create-ranger';

  // Storage bucket
  static const String photoBucket = 'passage-photos';
}
