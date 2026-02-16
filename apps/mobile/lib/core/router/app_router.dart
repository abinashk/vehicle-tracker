import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/auth_repository.dart';
import '../../presentation/screens/alert/alert_screen.dart';
import '../../presentation/screens/capture/capture_screen.dart';
import '../../presentation/screens/history/history_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/login/login_screen.dart';
import '../../presentation/screens/outcome/outcome_screen.dart';
import '../../presentation/screens/review/review_screen.dart';

/// Route path constants.
abstract class AppRoutes {
  static const String login = '/login';
  static const String home = '/';
  static const String capture = '/capture';
  static const String review = '/review';
  static const String alert = '/alert';
  static const String outcome = '/outcome';
  static const String history = '/history';
}

/// Application router using go_router with auth redirect guards.
///
/// Unauthenticated users are redirected to the login screen.
/// Authenticated users trying to access login are redirected to home.
GoRouter createAppRouter(Ref ref) {
  final authRepo = ref.read(authRepositoryProvider);

  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: false,
    redirect: (BuildContext context, GoRouterState state) {
      final isAuthenticated = authRepo.isAuthenticated;
      final isLoginRoute = state.matchedLocation == AppRoutes.login;

      if (!isAuthenticated && !isLoginRoute) {
        return AppRoutes.login;
      }

      if (isAuthenticated && isLoginRoute) {
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.capture,
        name: 'capture',
        builder: (context, state) => const CaptureScreen(),
      ),
      GoRoute(
        path: AppRoutes.review,
        name: 'review',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return ReviewScreen(
            imagePath: extra?['imagePath'] as String? ?? '',
            capturedAt: extra?['capturedAt'] as DateTime? ?? DateTime.now(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.alert,
        name: 'alert',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return AlertScreen(
            violationId: extra['violationId'] as String,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.outcome,
        name: 'outcome',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return OutcomeScreen(
            violationId: extra['violationId'] as String,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.history,
        name: 'history',
        builder: (context, state) => const HistoryScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text(
          'Page not found: ${state.error}',
          style: const TextStyle(fontSize: 18),
        ),
      ),
    ),
  );
}
