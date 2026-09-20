import 'package:enterprise_crm/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/user_management/data/repositories/mock_user_management_repository.dart';
import 'package:enterprise_crm/features/user_management/domain/entities/managed_user.dart';
import 'package:enterprise_crm/features/user_management/domain/repositories/user_management_repository.dart';
import 'package:enterprise_crm/features/user_management/presentation/screens/user_details_screen.dart';
import 'package:enterprise_crm/features/user_management/presentation/screens/users_and_access_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockThrowingRepo implements UserManagementRepository {
  bool shouldThrow = true;

  @override
  Future<List<ManagedUser>> getUsers() async {
    if (shouldThrow) {
      throw const UserManagementException('Failed to fetch user directory');
    }
    return MockUserManagementRepository.defaultSeeds;
  }

  @override
  Future<ManagedUser?> getUserById(String id) async => null;
}

Widget _buildUsersAndAccessTestApp({
  required CurrentUser user,
  UserManagementRepository? repository,
  ThemeMode themeMode = ThemeMode.light,
  Size size = const Size(1024, 768),
}) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
    darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
    themeMode: themeMode,
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: UsersAndAccessScreen(
        user: user,
        repository: repository ?? MockUserManagementRepository(),
      ),
    ),
  );
}

void main() {
  group('UsersAndAccessScreen Widget Tests', () {
    testWidgets(
      'renders directory header, search, filter chips, and desktop rows',
      (tester) async {
        await tester.pumpWidget(
          _buildUsersAndAccessTestApp(user: MockAuthRepository.mockAdmin),
        );
        await tester.pumpAndSettle();

        expect(find.text('Users & Access'), findsOneWidget);
        expect(find.text('USER DIRECTORY'), findsOneWidget);
        expect(find.byKey(const Key('user_search_field')), findsOneWidget);
        expect(find.byKey(const Key('status_filter_all')), findsOneWidget);
        expect(find.byKey(const Key('status_filter_active')), findsOneWidget);
        expect(find.byKey(const Key('status_filter_disabled')), findsOneWidget);

        // Verify default seeded users are visible in desktop rows
        expect(find.text('Administrator'), findsWidgets);
        expect(find.text('Standard User'), findsWidgets);
        expect(find.text('HR User'), findsWidgets);
        expect(find.text('Inventory User'), findsWidgets);
        expect(find.text('Disabled User'), findsWidgets);
      },
    );

    testWidgets(
      'search filters users case-insensitively and clear button resets',
      (tester) async {
        await tester.pumpWidget(
          _buildUsersAndAccessTestApp(user: MockAuthRepository.mockAdmin),
        );
        await tester.pumpAndSettle();

        // Enter search text 'standard'
        await tester.enterText(
          find.byKey(const Key('user_search_field')),
          'standard',
        );
        await tester.pumpAndSettle();

        expect(find.text('Standard User'), findsWidgets);
        expect(find.text('Administrator'), findsNothing);
        expect(find.text('HR User'), findsNothing);

        // Verify clear button appears and resets
        expect(
          find.byKey(const Key('user_search_clear_button')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('user_search_clear_button')));
        await tester.pumpAndSettle();

        expect(find.text('Administrator'), findsWidgets);
        expect(find.text('Standard User'), findsWidgets);
        expect(find.text('HR User'), findsWidgets);
      },
    );

    testWidgets('status filter chips filter active and disabled users', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildUsersAndAccessTestApp(user: MockAuthRepository.mockAdmin),
      );
      await tester.pumpAndSettle();

      // Tap Disabled filter chip
      await tester.tap(find.byKey(const Key('status_filter_disabled')));
      await tester.pumpAndSettle();

      expect(find.text('Disabled User'), findsWidgets);
      expect(find.text('Administrator'), findsNothing);
      expect(find.text('Standard User'), findsNothing);

      // Tap Active filter chip
      await tester.tap(find.byKey(const Key('status_filter_active')));
      await tester.pumpAndSettle();

      expect(find.text('Administrator'), findsWidgets);
      expect(find.text('Standard User'), findsWidgets);
      expect(find.text('Disabled User'), findsNothing);

      // Tap All filter chip
      await tester.tap(find.byKey(const Key('status_filter_all')));
      await tester.pumpAndSettle();

      expect(find.text('Administrator'), findsWidgets);
      expect(find.text('Disabled User'), findsWidgets);
    });

    testWidgets('empty directory displays empty notice', (tester) async {
      final emptyRepo = MockUserManagementRepository(initialUsers: const []);

      await tester.pumpWidget(
        _buildUsersAndAccessTestApp(
          user: MockAuthRepository.mockAdmin,
          repository: emptyRepo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('user_directory_empty')), findsOneWidget);
      expect(find.text('No users found.'), findsOneWidget);
    });

    testWidgets(
      'search with no matches shows reset filters button and resets',
      (tester) async {
        await tester.pumpWidget(
          _buildUsersAndAccessTestApp(user: MockAuthRepository.mockAdmin),
        );
        await tester.pumpAndSettle();

        // Enter unmatched query
        await tester.enterText(
          find.byKey(const Key('user_search_field')),
          'zzzzzz_nonexistent',
        );
        await tester.pumpAndSettle();

        expect(find.text('No users match your search.'), findsOneWidget);
        expect(
          find.byKey(const Key('user_directory_reset_filters_button')),
          findsOneWidget,
        );

        // Tap Reset filters
        await tester.tap(
          find.byKey(const Key('user_directory_reset_filters_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Administrator'), findsWidgets);
        expect(find.text('Standard User'), findsWidgets);
      },
    );

    testWidgets(
      'error state displays failure message and Retry button recovers',
      (tester) async {
        final throwingRepo = _MockThrowingRepo();

        await tester.pumpWidget(
          _buildUsersAndAccessTestApp(
            user: MockAuthRepository.mockAdmin,
            repository: throwingRepo,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('user_directory_error_view')),
          findsOneWidget,
        );
        expect(find.text('Unable to load users.'), findsOneWidget);
        expect(
          find.byKey(const Key('user_directory_retry_button')),
          findsOneWidget,
        );

        // Fix repo and tap retry
        throwingRepo.shouldThrow = false;
        await tester.tap(find.byKey(const Key('user_directory_retry_button')));
        await tester.pumpAndSettle();

        expect(find.text('Administrator'), findsWidgets);
        expect(
          find.byKey(const Key('user_directory_error_view')),
          findsNothing,
        );
      },
    );

    testWidgets('mobile layout renders user cards under 600px width', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildUsersAndAccessTestApp(
          user: MockAuthRepository.mockAdmin,
          size: const Size(375, 812), // Mobile viewport
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('user_item_usr_admin')), findsOneWidget);
      expect(find.byKey(const Key('user_item_usr_standard')), findsOneWidget);
    });

    testWidgets('tapping a user opens UserDetailsScreen', (tester) async {
      await tester.pumpWidget(
        _buildUsersAndAccessTestApp(user: MockAuthRepository.mockAdmin),
      );
      await tester.pumpAndSettle();

      // Tap View button for Standard User
      await tester.ensureVisible(
        find.byKey(const Key('user_view_button_usr_standard')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('user_view_button_usr_standard')));
      await tester.pumpAndSettle();

      expect(find.byType(UserDetailsScreen), findsOneWidget);
      expect(find.text('Standard User'), findsWidgets);
      expect(find.text('@user'), findsOneWidget);
    });

    testWidgets('renders cleanly in dark mode without errors', (tester) async {
      await tester.pumpWidget(
        _buildUsersAndAccessTestApp(
          user: MockAuthRepository.mockAdmin,
          themeMode: ThemeMode.dark,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('USER DIRECTORY'), findsOneWidget);
      expect(find.text('Administrator'), findsWidgets);
    });
  });
}
