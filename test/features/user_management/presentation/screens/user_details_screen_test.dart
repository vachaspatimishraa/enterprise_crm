import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/user_management/data/mock/mock_account_store.dart';
import 'package:enterprise_crm/features/user_management/data/repositories/mock_user_management_repository.dart';
import 'package:enterprise_crm/features/user_management/domain/entities/managed_user.dart';
import 'package:enterprise_crm/features/user_management/domain/entities/user_account_status.dart';
import 'package:enterprise_crm/features/user_management/domain/repositories/user_management_repository.dart';
import 'package:enterprise_crm/features/user_management/presentation/screens/user_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/mock_auth_test_fixtures.dart';

Widget _buildUserDetailsTestApp({
  required ManagedUser user,
  UserManagementRepository? repository,
  ThemeMode themeMode = ThemeMode.light,
}) {
  final repo =
      repository ??
      MockUserManagementRepository(accountStore: MockAccountStore.seeded());
  return MaterialApp(
    theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
    darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
    themeMode: themeMode,
    home: UserDetailsScreen(
      currentUser: MockAuthTestFixtures.admin,
      user: user,
      repository: repo,
    ),
  );
}

void main() {
  group('UserDetailsScreen Tests', () {
    testWidgets(
      'renders standard user details, module chips, permissions, and admin actions',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final standardUser = MockUserManagementRepository.defaultSeeds
            .firstWhere((u) => u.userId == 'user');

        await tester.pumpWidget(_buildUserDetailsTestApp(user: standardUser));
        await tester.pumpAndSettle();

        // Profile Header
        expect(find.text('Standard User'), findsWidgets);
        expect(find.text('@user'), findsOneWidget);
        expect(find.text('Active'), findsOneWidget);
        expect(find.text('ID: usr_standard'), findsOneWidget);

        // Module Access
        expect(find.text('MODULE ACCESS'), findsOneWidget);
        expect(find.text('Lead Management'), findsOneWidget);
        expect(find.text('Calling'), findsOneWidget);

        // Permissions
        expect(find.text('PERMISSIONS'), findsOneWidget);
        expect(find.text('lead.view_assigned'), findsOneWidget);
        expect(find.text('lead.update'), findsOneWidget);
        expect(find.text('calling.use'), findsOneWidget);

        // Administrative Actions
        expect(find.text('ADMINISTRATIVE ACTIONS'), findsOneWidget);
        expect(
          find.byKey(const Key('user_details_edit_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('user_details_status_toggle_button')),
          findsOneWidget,
        );
        expect(find.text('Disable User'), findsOneWidget);
        expect(
          find.byKey(const Key('user_details_reset_password_button')),
          findsOneWidget,
        );

        // Back button
        expect(
          find.byKey(const Key('user_details_back_button')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Master Admin protection: Reset Password permitted; Edit and Disable hidden',
      (tester) async {
        final adminUser = MockUserManagementRepository.defaultSeeds.firstWhere(
          (u) => u.userId == 'admin',
        );

        await tester.pumpWidget(_buildUserDetailsTestApp(user: adminUser));
        await tester.pumpAndSettle();

        // Admin badge
        expect(find.text('Admin'), findsOneWidget);

        // Truthful Admin text
        expect(find.text('Administrative access'), findsOneWidget);
        expect(
          find.text('Full frontend access in the current mock environment'),
          findsOneWidget,
        );

        // Master Admin protection callout
        expect(
          find.text(
            'Master Administrator accounts cannot be disabled or have modules/permissions modified.',
          ),
          findsOneWidget,
        );

        // Edit and Disable must NOT be rendered
        expect(find.byKey(const Key('user_details_edit_button')), findsNothing);
        expect(
          find.byKey(const Key('user_details_status_toggle_button')),
          findsNothing,
        );

        // Reset Password MUST be rendered
        expect(
          find.byKey(const Key('user_details_reset_password_button')),
          findsOneWidget,
        );
      },
    );

    testWidgets('Disable User requires confirmation dialog before disabling', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final store = MockAccountStore.seeded();
      final repo = MockUserManagementRepository(accountStore: store);
      final standardUser = store.getUserById('usr_standard')!;

      await tester.pumpWidget(
        _buildUserDetailsTestApp(user: standardUser, repository: repo),
      );
      await tester.pumpAndSettle();

      // Tap Disable User
      await tester.tap(
        find.byKey(const Key('user_details_status_toggle_button')),
      );
      await tester.pumpAndSettle();

      // Confirmation dialog appears
      expect(
        find.byKey(const Key('disable_user_confirm_dialog')),
        findsOneWidget,
      );
      expect(find.text('Disable User Account?'), findsOneWidget);

      // Cancel first
      await tester.tap(find.byKey(const Key('disable_user_cancel_button')));
      await tester.pumpAndSettle();

      // Dialog closed, user is still active
      expect(
        find.byKey(const Key('disable_user_confirm_dialog')),
        findsNothing,
      );
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Disable User'), findsOneWidget);

      // Tap Disable User again and confirm
      await tester.tap(
        find.byKey(const Key('user_details_status_toggle_button')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('disable_user_confirm_button')));
      await tester.pumpAndSettle();

      // User state updated to Disabled in place
      expect(find.text('Disabled'), findsOneWidget);
      expect(find.text('Enable User'), findsOneWidget);
      expect(store.getUserById('usr_standard')?.isDisabled, isTrue);
    });

    testWidgets('Enable User re-activates a disabled user account', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final store = MockAccountStore.seeded();
      final repo = MockUserManagementRepository(accountStore: store);
      final disabledUser = store.getUserById('usr_disabled')!;

      await tester.pumpWidget(
        _buildUserDetailsTestApp(user: disabledUser, repository: repo),
      );
      await tester.pumpAndSettle();

      expect(find.text('Disabled'), findsOneWidget);
      expect(find.text('Enable User'), findsOneWidget);

      // Tap Enable User
      await tester.tap(
        find.byKey(const Key('user_details_status_toggle_button')),
      );
      await tester.pumpAndSettle();

      // Status becomes Active
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Disable User'), findsOneWidget);
      expect(store.getUserById('usr_disabled')?.isActive, isTrue);
    });

    testWidgets('Reset Password dialog sets new password for user', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final store = MockAccountStore.seeded();
      final repo = MockUserManagementRepository(accountStore: store);
      final standardUser = store.getUserById('usr_standard')!;

      await tester.pumpWidget(
        _buildUserDetailsTestApp(user: standardUser, repository: repo),
      );
      await tester.pumpAndSettle();

      // Tap Reset Password
      await tester.tap(
        find.byKey(const Key('user_details_reset_password_button')),
      );
      await tester.pumpAndSettle();

      // Dialog appears
      expect(find.byKey(const Key('reset_password_dialog')), findsOneWidget);

      // Enter new password
      await tester.enterText(
        find.byKey(const Key('reset_password_new_password_field')),
        'new_secret_123',
      );

      // Submit reset
      await tester.tap(find.byKey(const Key('reset_password_submit_button')));
      await tester.pumpAndSettle();

      // Dialog dismissed and feedback displayed
      expect(find.byKey(const Key('reset_password_dialog')), findsNothing);
      expect(
        find.text('Password reset successfully for @user.'),
        findsOneWidget,
      );

      // Verify login credential in store
      expect(
        store.authenticate(userId: 'user', password: 'new_secret_123'),
        isNotNull,
      );
    });

    testWidgets(
      'renders fallback notices when user has no modules or permissions',
      (tester) async {
        final bareUser = ManagedUser(
          id: 'bare_user',
          userId: 'bare',
          displayName: 'Bare User',
          accountType: AccountType.user,
          modules: const {},
          permissions: const {},
          status: UserAccountStatus.active,
        );

        await tester.pumpWidget(_buildUserDetailsTestApp(user: bareUser));
        await tester.pumpAndSettle();

        expect(find.text('No business modules assigned.'), findsOneWidget);
        expect(find.text('No explicit permissions assigned.'), findsOneWidget);
      },
    );

    testWidgets('renders cleanly in dark mode', (tester) async {
      final standardUser = MockUserManagementRepository.defaultSeeds.firstWhere(
        (u) => u.userId == 'user',
      );

      await tester.pumpWidget(
        _buildUserDetailsTestApp(user: standardUser, themeMode: ThemeMode.dark),
      );
      await tester.pumpAndSettle();

      expect(find.text('Standard User'), findsWidgets);
      expect(find.text('Active'), findsOneWidget);
    });
  });
}
