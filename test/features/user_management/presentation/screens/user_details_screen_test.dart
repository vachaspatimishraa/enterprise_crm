import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/user_management/data/repositories/mock_user_management_repository.dart';
import 'package:enterprise_crm/features/user_management/domain/entities/managed_user.dart';
import 'package:enterprise_crm/features/user_management/domain/entities/user_account_status.dart';
import 'package:enterprise_crm/features/user_management/presentation/screens/user_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/mock_auth_test_fixtures.dart';

Widget _buildUserDetailsTestApp({
  required ManagedUser user,
  ThemeMode themeMode = ThemeMode.light,
}) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
    darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
    themeMode: themeMode,
    home: UserDetailsScreen(
      currentUser: MockAuthTestFixtures.admin,
      user: user,
    ),
  );
}

void main() {
  group('UserDetailsScreen Tests', () {
    testWidgets('renders standard user details, module chips, and permissions', (
      tester,
    ) async {
      final standardUser = MockUserManagementRepository.defaultSeeds.firstWhere(
        (u) => u.userId == 'user',
      );

      await tester.pumpWidget(_buildUserDetailsTestApp(user: standardUser));
      await tester.pumpAndSettle();

      // Profile Header
      expect(find.text('Standard User'), findsWidgets);
      expect(find.text('@user'), findsOneWidget);
      expect(find.text('Standard User'), findsWidgets); // badge and title
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

      // Deferral Callout Notice
      expect(
        find.text(
          'User editing and access changes will be added in the next administration phase.',
        ),
        findsOneWidget,
      );

      // Back button
      expect(find.byKey(const Key('user_details_back_button')), findsOneWidget);
    });

    testWidgets(
      'CORRECTION 1: Admin details display truthful text and never wildcard *',
      (tester) async {
        final adminUser = MockUserManagementRepository.defaultSeeds.firstWhere(
          (u) => u.userId == 'admin',
        );

        await tester.pumpWidget(_buildUserDetailsTestApp(user: adminUser));
        await tester.pumpAndSettle();

        // Admin badge
        expect(find.text('Admin'), findsOneWidget);

        // Required Truthful Admin text
        expect(find.text('Administrative access'), findsOneWidget);
        expect(
          find.text('Full frontend access in the current mock environment'),
          findsOneWidget,
        );

        // Verify no fake wildcard permission is displayed
        expect(find.text('*'), findsNothing);
        expect(find.textContaining('{"*"}'), findsNothing);

        // All 8 modules present
        for (final module in CrmModule.values) {
          expect(find.text(module.name), findsNothing); // Uses displayName
        }
        expect(find.text('Lead Management'), findsOneWidget);
        expect(find.text('Calling'), findsOneWidget);
        expect(find.text('Inventory'), findsOneWidget);
        expect(find.text('Dispatch'), findsOneWidget);
        expect(find.text('Purchase'), findsOneWidget);
        expect(find.text('HR / Payroll'), findsOneWidget);
        expect(find.text('Approvals & Notifications'), findsOneWidget);
        expect(find.text('Vendor Management'), findsOneWidget);
      },
    );

    testWidgets('renders disabled account status badge', (tester) async {
      final disabledUser = MockUserManagementRepository.defaultSeeds.firstWhere(
        (u) => u.userId == 'disabled_user',
      );

      await tester.pumpWidget(_buildUserDetailsTestApp(user: disabledUser));
      await tester.pumpAndSettle();

      expect(find.text('Disabled User'), findsWidgets);
      expect(find.text('Disabled'), findsOneWidget);
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
