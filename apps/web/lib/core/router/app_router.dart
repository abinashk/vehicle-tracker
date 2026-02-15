import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../di/providers.dart';
import '../../presentation/layout/admin_shell.dart';
import '../../presentation/screens/login/login_screen.dart';
import '../../presentation/screens/dashboard/dashboard_screen.dart';
import '../../presentation/screens/rangers/ranger_list_screen.dart';
import '../../presentation/screens/rangers/ranger_form_screen.dart';
import '../../presentation/screens/segments/segment_list_screen.dart';
import '../../presentation/screens/segments/segment_edit_screen.dart';
import '../../presentation/screens/passages/passage_list_screen.dart';
import '../../presentation/screens/passages/passage_detail_screen.dart';
import '../../presentation/screens/violations/violation_list_screen.dart';
import '../../presentation/screens/violations/violation_detail_screen.dart';
import '../../presentation/screens/unmatched/unmatched_list_screen.dart';

part 'app_router.g.dart';

/// Route paths used across the app.
class RoutePaths {
  RoutePaths._();

  static const String login = '/login';
  static const String dashboard = '/';
  static const String rangers = '/rangers';
  static const String rangerCreate = '/rangers/create';
  static const String rangerEdit = '/rangers/:id/edit';
  static const String segments = '/segments';
  static const String segmentEdit = '/segments/:id/edit';
  static const String passages = '/passages';
  static const String passageDetail = '/passages/:id';
  static const String violations = '/violations';
  static const String violationDetail = '/violations/:id';
  static const String unmatched = '/unmatched';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

@riverpod
GoRouter appRouter(Ref ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: RoutePaths.dashboard,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoading = authState.isLoading;
      if (isLoading) return null;

      final isLoggedIn = authState.valueOrNull != null;
      final isLoginRoute = state.matchedLocation == RoutePaths.login;

      if (!isLoggedIn && !isLoginRoute) {
        return RoutePaths.login;
      }

      if (isLoggedIn && isLoginRoute) {
        return RoutePaths.dashboard;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: RoutePaths.login,
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: RoutePaths.dashboard,
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: RoutePaths.rangers,
            builder: (context, state) => const RangerListScreen(),
          ),
          GoRoute(
            path: RoutePaths.rangerCreate,
            builder: (context, state) => const RangerFormScreen(),
          ),
          GoRoute(
            path: RoutePaths.rangerEdit,
            builder: (context, state) => RangerFormScreen(
              rangerId: state.pathParameters['id'],
            ),
          ),
          GoRoute(
            path: RoutePaths.segments,
            builder: (context, state) => const SegmentListScreen(),
          ),
          GoRoute(
            path: RoutePaths.segmentEdit,
            builder: (context, state) => SegmentEditScreen(
              segmentId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: RoutePaths.passages,
            builder: (context, state) => const PassageListScreen(),
          ),
          GoRoute(
            path: RoutePaths.passageDetail,
            builder: (context, state) => PassageDetailScreen(
              passageId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: RoutePaths.violations,
            builder: (context, state) => const ViolationListScreen(),
          ),
          GoRoute(
            path: RoutePaths.violationDetail,
            builder: (context, state) => ViolationDetailScreen(
              violationId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: RoutePaths.unmatched,
            builder: (context, state) => const UnmatchedListScreen(),
          ),
        ],
      ),
    ],
  );
}
