import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/di/providers.dart';

/// Remote data source for authentication using Supabase Auth.
///
/// Handles login, logout, and user profile fetching.
class AuthRemoteSource {
  AuthRemoteSource({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  /// Sign in with email and password.
  ///
  /// The username is auto-appended with @bnp.local domain suffix.
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Get the currently authenticated user.
  User? get currentUser => _client.auth.currentUser;

  /// Check if a user is currently authenticated.
  bool get isAuthenticated => _client.auth.currentUser != null;

  /// Fetch the user profile from the user_profiles table.
  Future<UserProfile?> fetchUserProfile(String userId) async {
    try {
      final response = await _client
          .from(ApiConstants.userProfilesTable)
          .select()
          .eq('id', userId)
          .single();
      return UserProfile.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  /// Listen to auth state changes.
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}

/// Provider for the auth remote source.
final authRemoteSourceProvider = Provider<AuthRemoteSource>((ref) {
  return AuthRemoteSource(client: ref.watch(supabaseClientProvider));
});
