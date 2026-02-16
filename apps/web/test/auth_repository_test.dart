import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import 'package:vehicle_tracker_web/data/repositories/auth_repository.dart';

@GenerateNiceMocks([
  MockSpec<SupabaseClient>(),
  MockSpec<GoTrueClient>(),
  MockSpec<SupabaseQueryBuilder>(),
  MockSpec<PostgrestFilterBuilder<dynamic>>(),
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
      test('should reject non-admin users with NotAdminException', () async {
        // Arrange: Set up mock auth to return a user.
        final mockUser = User(
          id: 'user-123',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        );

        when(mockAuth.signInWithPassword(
          email: anyNamed('email'),
          password: anyNamed('password'),
        ),).thenAnswer((_) async => AuthResponse(
              session: Session(
                accessToken: 'token',
                tokenType: 'bearer',
                user: mockUser,
              ),
              user: mockUser,
            ),);

        // Mock the user profile query to return a ranger.
        final mockQueryBuilder = MockSupabaseQueryBuilder();
        final mockFilterBuilder = MockPostgrestFilterBuilder();

        when(mockClient.from(ApiConstants.userProfilesTable))
            .thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.select(any)).thenReturn(mockFilterBuilder as dynamic);
        when(mockFilterBuilder.eq(any, any)).thenReturn(mockFilterBuilder);
        when((mockFilterBuilder as dynamic).single()).thenAnswer((_) async => {
              'id': 'user-123',
              'full_name': 'Test Ranger',
              'role': 'ranger',
              'is_active': true,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            });

        when(mockAuth.signOut()).thenAnswer((_) async {});

        // Act & Assert: Should throw NotAdminException.
        expect(
          () => authRepository.signIn(
            email: 'ranger@bnp.local',
            password: 'password123',
          ),
          throwsA(isA<NotAdminException>()),
        );
      });

      test('should allow admin users to sign in', () async {
        // Arrange: Set up mock auth to return a user.
        final mockUser = User(
          id: 'admin-123',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        );

        when(mockAuth.signInWithPassword(
          email: anyNamed('email'),
          password: anyNamed('password'),
        ),).thenAnswer((_) async => AuthResponse(
              session: Session(
                accessToken: 'token',
                tokenType: 'bearer',
                user: mockUser,
              ),
              user: mockUser,
            ),);

        // Mock the user profile query to return an admin.
        final mockQueryBuilder = MockSupabaseQueryBuilder();
        final mockFilterBuilder = MockPostgrestFilterBuilder();

        when(mockClient.from(ApiConstants.userProfilesTable))
            .thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.select(any)).thenReturn(mockFilterBuilder as dynamic);
        when(mockFilterBuilder.eq(any, any)).thenReturn(mockFilterBuilder);
        when((mockFilterBuilder as dynamic).single()).thenAnswer((_) async => {
              'id': 'admin-123',
              'full_name': 'Admin User',
              'role': 'admin',
              'is_active': true,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            });

        // Act
        final profile = await authRepository.signIn(
          email: 'admin@bnp.local',
          password: 'password123',
        );

        // Assert
        expect(profile.role, UserRole.admin);
        expect(profile.fullName, 'Admin User');
      });

      test('should throw AuthException for invalid credentials', () async {
        // Arrange
        when(mockAuth.signInWithPassword(
          email: anyNamed('email'),
          password: anyNamed('password'),
        ),).thenThrow(AuthApiException('Invalid login credentials'));

        // Act & Assert
        expect(
          () => authRepository.signIn(
            email: 'bad@email.com',
            password: 'wrong',
          ),
          throwsA(isA<AuthException>()),
        );
      });
    });

    group('getCurrentUserProfile', () {
      test('should return null when no session exists', () async {
        // Arrange
        when(mockAuth.currentSession).thenReturn(null);

        // Act
        final result = await authRepository.getCurrentUserProfile();

        // Assert
        expect(result, isNull);
      });
    });

    group('signOut', () {
      test('should call signOut on the auth client', () async {
        // Arrange
        when(mockAuth.signOut()).thenAnswer((_) async {});

        // Act
        await authRepository.signOut();

        // Assert
        verify(mockAuth.signOut()).called(1);
      });
    });
  });

  group('NotAdminException', () {
    test('should have a default message', () {
      const exception = NotAdminException();
      expect(
          exception.message, 'Only administrators can access this dashboard.',);
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
