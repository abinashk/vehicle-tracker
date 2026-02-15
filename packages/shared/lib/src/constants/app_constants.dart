/// Application-wide constants.
class AppConstants {
  AppConstants._();

  /// Auth domain suffix appended to ranger usernames.
  static const String authDomainSuffix = '@bnp.local';

  /// Sync engine interval.
  static const Duration syncInterval = Duration(seconds: 30);

  /// How far back to search for unmatched entries (generous window).
  static const Duration matchLookbackWindow = Duration(hours: 24);

  /// Max photo file size in bytes (2MB).
  static const int maxPhotoSizeBytes = 2 * 1024 * 1024;

  /// Allowed photo MIME types.
  static const List<String> allowedPhotoMimeTypes = [
    'image/jpeg',
    'image/png',
  ];

  /// Supabase storage bucket name for passage photos.
  static const String photoBucketName = 'passage-photos';

  /// Data retention period.
  static const Duration retentionPeriod = Duration(days: 365);

  /// Nepal timezone offset (UTC+5:45).
  static const Duration nepalTimezoneOffset = Duration(hours: 5, minutes: 45);
}
