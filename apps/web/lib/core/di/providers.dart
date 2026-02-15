import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/alert_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../data/repositories/passage_repository.dart';
import '../../data/repositories/ranger_repository.dart';
import '../../data/repositories/segment_repository.dart';
import '../../data/repositories/violation_repository.dart';

part 'providers.g.dart';

// ---------------------------------------------------------------------------
// Supabase client
// ---------------------------------------------------------------------------

@Riverpod(keepAlive: true)
SupabaseClient supabaseClient(Ref ref) {
  return Supabase.instance.client;
}

// ---------------------------------------------------------------------------
// Repositories
// ---------------------------------------------------------------------------

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
}

@Riverpod(keepAlive: true)
RangerRepository rangerRepository(Ref ref) {
  return RangerRepository(ref.watch(supabaseClientProvider));
}

@Riverpod(keepAlive: true)
SegmentRepository segmentRepository(Ref ref) {
  return SegmentRepository(ref.watch(supabaseClientProvider));
}

@Riverpod(keepAlive: true)
PassageRepository passageRepository(Ref ref) {
  return PassageRepository(ref.watch(supabaseClientProvider));
}

@Riverpod(keepAlive: true)
ViolationRepository violationRepository(Ref ref) {
  return ViolationRepository(ref.watch(supabaseClientProvider));
}

@Riverpod(keepAlive: true)
DashboardRepository dashboardRepository(Ref ref) {
  return DashboardRepository(ref.watch(supabaseClientProvider));
}

@Riverpod(keepAlive: true)
AlertRepository alertRepository(Ref ref) {
  return AlertRepository(ref.watch(supabaseClientProvider));
}

// ---------------------------------------------------------------------------
// Auth state
// ---------------------------------------------------------------------------

@Riverpod(keepAlive: true)
class AuthState extends _$AuthState {
  @override
  AsyncValue<UserProfile?> build() {
    _init();
    return const AsyncValue.loading();
  }

  Future<void> _init() async {
    final repo = ref.read(authRepositoryProvider);
    try {
      final profile = await repo.getCurrentUserProfile();
      state = AsyncValue.data(profile);
    } catch (_) {
      state = const AsyncValue.data(null);
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final profile = await ref.read(authRepositoryProvider).signIn(
            email: email,
            password: password,
          );
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncValue.data(null);
  }
}

/// Whether the current user is authenticated as admin.
@riverpod
bool isAuthenticated(Ref ref) {
  final authState = ref.watch(authStateProvider);
  return authState.valueOrNull != null;
}
