import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../remote/auth_remote_source.dart';

/// Authentication state holding the current user profile.
class AuthState {
  final UserProfile? userProfile;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.userProfile,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => userProfile != null;

  AuthState copyWith({
    UserProfile? userProfile,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      userProfile: userProfile ?? this.userProfile,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Repository for authentication operations.
///
/// Mediates between the Supabase auth remote source and the app state.
/// Stores the user profile locally for offline access.
class AuthRepository {
  AuthRepository({required AuthRemoteSource remoteSource})
      : _remoteSource = remoteSource;

  final AuthRemoteSource _remoteSource;
  UserProfile? _cachedProfile;

  /// The currently cached user profile.
  UserProfile? get currentProfile => _cachedProfile;

  /// Whether the user is currently authenticated.
  bool get isAuthenticated => _remoteSource.isAuthenticated;

  /// The current user's ID from Supabase auth.
  String? get currentUserId => _remoteSource.currentUser?.id;

  /// Sign in with username and password.
  ///
  /// Auto-appends the @bnp.local domain suffix to the username.
  Future<AuthState> signIn({
    required String username,
    required String password,
  }) async {
    try {
      final email = username.contains('@')
          ? username
          : '$username${AppConstants.authDomainSuffix}';

      await _remoteSource.signIn(email: email, password: password);

      final userId = _remoteSource.currentUser?.id;
      if (userId == null) {
        return const AuthState(error: 'Authentication failed');
      }

      final profile = await _remoteSource.fetchUserProfile(userId);
      if (profile == null) {
        return const AuthState(error: 'User profile not found');
      }

      _cachedProfile = profile;
      return AuthState(userProfile: profile);
    } on AuthException catch (e) {
      return AuthState(error: e.message);
    } catch (e) {
      return AuthState(error: 'Login failed: $e');
    }
  }

  /// Sign out and clear cached data.
  Future<void> signOut() async {
    await _remoteSource.signOut();
    _cachedProfile = null;
  }

  /// Restore the user session and profile.
  ///
  /// Called on app startup to check if the user is still authenticated.
  Future<AuthState> restoreSession() async {
    if (!_remoteSource.isAuthenticated) {
      return const AuthState();
    }

    final userId = _remoteSource.currentUser!.id;
    try {
      final profile = await _remoteSource.fetchUserProfile(userId);
      _cachedProfile = profile;
      return AuthState(userProfile: profile);
    } catch (_) {
      // Offline - use cached profile if available.
      if (_cachedProfile != null) {
        return AuthState(userProfile: _cachedProfile);
      }
      return const AuthState();
    }
  }
}

/// Provider for the auth repository.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(remoteSource: ref.watch(authRemoteSourceProvider));
});

/// StateNotifier for managing auth state in the UI.
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier({required AuthRepository repository})
      : _repository = repository,
        super(const AuthState());

  final AuthRepository _repository;

  /// Attempt to sign in.
  Future<void> signIn({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    final result =
        await _repository.signIn(username: username, password: password);
    state = result;
  }

  /// Sign out.
  Future<void> signOut() async {
    await _repository.signOut();
    state = const AuthState();
  }

  /// Restore session on app launch.
  Future<void> restoreSession() async {
    state = state.copyWith(isLoading: true);
    final result = await _repository.restoreSession();
    state = result;
  }
}

/// Provider for the auth notifier.
final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(repository: ref.watch(authRepositoryProvider));
});
