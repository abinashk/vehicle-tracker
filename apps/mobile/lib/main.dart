import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'app.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/notification_service.dart';
import 'domain/usecases/sync_passages.dart';

/// Application entry point.
///
/// Initializes:
/// 1. Flutter bindings
/// 2. Supabase client
/// 3. Connectivity monitoring
/// 4. Push notifications
/// 5. Wakelock (keeps screen on during active use)
/// 6. System UI preferences (dark status bar)
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait mode for consistent camera usage.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Dark system overlays to match the app theme.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF121212),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize Supabase.
  await Supabase.initialize(
    url: const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://your-project.supabase.co',
    ),
    anonKey: const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'your-anon-key',
    ),
  );

  // Keep screen on during active use (outdoor ranger usage).
  await WakelockPlus.enable();

  // Create the ProviderScope container.
  final container = ProviderContainer();

  // Initialize services.
  await container.read(connectivityServiceProvider).initialize();

  // Initialize notifications (non-blocking if Firebase not configured).
  try {
    await container.read(notificationServiceProvider).initialize();
  } catch (_) {
    // Firebase may not be configured in all environments.
  }

  // Start the sync engine (non-blocking — configures and starts if user
  // is already authenticated and has an assigned checkpost).
  try {
    await container.read(syncPassagesUseCaseProvider).startSync();
  } catch (_) {
    // Sync startup may fail if user isn't logged in yet; the home screen
    // will retry once the user authenticates.
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const VehicleTrackerApp(),
    ),
  );
}
