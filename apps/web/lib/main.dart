import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

/// Entry point for the Vehicle Tracker Admin Web Dashboard.
///
/// Initializes Supabase and wraps the app in a [ProviderScope] for Riverpod.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase.
  // In production, these values come from environment variables or
  // build-time configuration. For local development, update these.
  await Supabase.initialize(
    url: const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'http://localhost:54321',
    ),
    anonKey: const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: '',
    ),
  );

  runApp(
    const ProviderScope(
      child: VehicleTrackerWebApp(),
    ),
  );
}
