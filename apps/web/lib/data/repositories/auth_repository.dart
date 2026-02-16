import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Exception thrown when a non-admin user attempts to log in.
class NotAdminException implements Exception {
  final String message;
  const NotAdminException(
      [this.message = 'Only administrators can access this dashboard.',]);

  @override
  String toString() => message;
}

/// Exception thrown when authentication fails.
class AuthException implements Exception {
  final String message;
  const AuthException([this.message = 'Authentication failed.']);

  @override
  String toString() => message;
}

/// Repository for authentication operations.
///
/// Handles Supabase Auth sign-in, sign-out, session persistence,
/// and admin role verification (rejects non-admin users).
class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  /// Sign in with email and password, verifying the user is an admin.
  ///
  /// Throws [NotAdminException] if the user has a non-admin role.
  /// Throws [AuthException] for invalid credentials or other errors.
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw const AuthException('Invalid credentials.');
      }

      final profile = await _fetchUserProfile(response.user!.id);

      if (profile.role != UserRole.admin) {
        // Sign out the non-admin user immediately.
        await _client.auth.signOut();
        throw const NotAdminException(
          'Access denied. Only park administrators can log in to this dashboard. '
          'If you are a ranger, please use the mobile app instead.',
        );
      }

      return profile;
    } on NotAdminException {
      rethrow;
    } on AuthException {
      rethrow;
    } on AuthApiException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      if (e is NotAdminException || e is AuthException) rethrow;
      throw const AuthException('Login failed. Please check your credentials and try again.');
    }
  }

  /// Get the current user's profile if they have an active session.
  ///
  /// Returns `null` if no session exists or the user is not an admin.
  Future<UserProfile?> getCurrentUserProfile() async {
    final session = _client.auth.currentSession;
    if (session == null) return null;

    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final profile = await _fetchUserProfile(userId);
      if (profile.role != UserRole.admin) {
        await _client.auth.signOut();
        return null;
      }
      return profile;
    } catch (_) {
      return null;
    }
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Fetch user profile from the database by user ID.
  Future<UserProfile> _fetchUserProfile(String userId) async {
    final data = await _client
        .from(ApiConstants.userProfilesTable)
        .select()
        .eq('id', userId)
        .single();

    return UserProfile.fromJson(data);
  }

  /// Listen to auth state changes.
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Get the current session's access token for API calls.
  String? get accessToken => _client.auth.currentSession?.accessToken;

  /// The current authenticated user's ID, or null.
  String? get currentUserId => _client.auth.currentUser?.id;
}
