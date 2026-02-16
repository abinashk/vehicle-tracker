import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import 'package:vehicle_tracker_web/data/repositories/auth_repository.dart';

@GenerateNiceMocks([
  MockSpec<SupabaseClient>(),
  MockSpec<GoTrueClient>(),
])
import 'auth_repository_test.mocks.dart';

void main() {
  late MockSupabaseClient mockClient;
  late MockGoTrueClient mockAuth;
  late AuthRepository authRepository;

  setUp(() {
    mockClient = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    when(mockClient.auth).thenReturn(mockAuth);
    authRepository = AuthRepository(mockClient);
  });

  group('AuthRepository', () {
    group('signIn', () {
      test('should throw AuthException for invalid credentials', () async {
        when(mockAuth.signInWithPassword(
          email: anyNamed('email'),
          password: anyNamed('password'),
        ),).thenThrow(AuthApiException('Invalid login credentials'));

        expect(
          () => authRepository.signIn(
            email: 'bad@email.com',
            password: 'wrong',
          ),
          throwsA(isA<AuthException>()),
        );
      });

      test('should throw AuthException when user is null', () async {
        when(mockAuth.signInWithPassword(
          email: anyNamed('email'),
          password: anyNamed('password'),
        ),).thenAnswer((_) async => AuthResponse(
              session: null,
              user: null,
            ),);

        expect(
          () => authRepository.signIn(
            email: 'test@bnp.local',
            password: 'password',
          ),
          throwsA(isA<AuthException>()),
        );
      });
    });

    group('getCurrentUserProfile', () {
      test('should return null when no session exists', () async {
        when(mockAuth.currentSession).thenReturn(null);

        final result = await authRepository.getCurrentUserProfile();

        expect(result, isNull);
      });

      test('should return null when no user exists', () async {
        when(mockAuth.currentSession).thenReturn(Session(
          accessToken: 'token',
          tokenType: 'bearer',
          user: User(
            id: 'user-123',
            appMetadata: {},
            userMetadata: {},
            aud: 'authenticated',
            createdAt: DateTime.now().toIso8601String(),
          ),
        ),);
        when(mockAuth.currentUser).thenReturn(null);

        final result = await authRepository.getCurrentUserProfile();

        expect(result, isNull);
      });
    });

    group('signOut', () {
      test('should call signOut on the auth client', () async {
        when(mockAuth.signOut()).thenAnswer((_) async {});

        await authRepository.signOut();

        verify(mockAuth.signOut()).called(1);
      });
    });

    group('accessors', () {
      test('accessToken returns session token', () {
        when(mockAuth.currentSession).thenReturn(Session(
          accessToken: 'test-token',
          tokenType: 'bearer',
          user: User(
            id: 'user-123',
            appMetadata: {},
            userMetadata: {},
            aud: 'authenticated',
            createdAt: DateTime.now().toIso8601String(),
          ),
        ),);

        expect(authRepository.accessToken, 'test-token');
      });

      test('accessToken returns null when no session', () {
        when(mockAuth.currentSession).thenReturn(null);

        expect(authRepository.accessToken, isNull);
      });

      test('currentUserId returns user id', () {
        when(mockAuth.currentUser).thenReturn(User(
          id: 'user-456',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        ),);

        expect(authRepository.currentUserId, 'user-456');
      });

      test('currentUserId returns null when no user', () {
        when(mockAuth.currentUser).thenReturn(null);

        expect(authRepository.currentUserId, isNull);
      });
    });
  });

  group('NotAdminException', () {
    test('should have a default message', () {
      const exception = NotAdminException();
      expect(
        exception.message,
        'Only administrators can access this dashboard.',
      );
    });

    test('should accept a custom message', () {
      const exception = NotAdminException('Custom message');
      expect(exception.message, 'Custom message');
    });

    test('toString returns the message', () {
      const exception = NotAdminException('Test message');
      expect(exception.toString(), 'Test message');
    });
  });

  group('AuthException', () {
    test('should have a default message', () {
      const exception = AuthException();
      expect(exception.message, 'Authentication failed.');
    });

    test('toString returns the message', () {
      const exception = AuthException('Login failed');
      expect(exception.toString(), 'Login failed');
    });
  });
}
