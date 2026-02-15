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
  // These values MUST be provided via --dart-define at build time.
  // No defaults — the app will throw at startup if they're missing.
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  assert(supabaseUrl.isNotEmpty, 'SUPABASE_URL must be set via --dart-define');
  assert(supabaseAnonKey.isNotEmpty, 'SUPABASE_ANON_KEY must be set via --dart-define');

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(
    const ProviderScope(
      child: VehicleTrackerWebApp(),
    ),
  );
}
