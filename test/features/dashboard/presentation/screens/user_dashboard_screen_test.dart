import 'package:enterprise_crm/features/dashboard/presentation/screens/module_placeholder_screen.dart';
import 'package:enterprise_crm/features/dashboard/presentation/screens/user_dashboard_screen.dart';
import 'package:enterprise_crm/features/dashboard/presentation/screens/user_lead_placeholder_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/mock_auth_test_fixtures.dart';

Widget _buildUserDashboardTestApp({
  VoidCallback? onLogout,
  ThemeMode themeMode = ThemeMode.light,
}) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
    darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
    themeMode: themeMode,
    home: UserDashboardScreen(
      user: MockAuthTestFixtures.standardUser,
      onLogout: onLogout ?? () {},
    ),
  );
}

void main() {
  group('UserDashboardScreen Tests', () {
    testWidgets('renders only assigned modules for standard user', (
      tester,
    ) async {
      await tester.pumpWidget(_buildUserDashboardTestApp());
      await tester.pumpAndSettle();

      // Header: CRM branding removed, Standard User appears only once
      expect(find.text('Enterprise CRM'), findsNothing);
      expect(find.text('Standard User'), findsOneWidget);
      expect(find.byKey(const Key('crm_header_logout_button')), findsOneWidget);

      // Section title
      expect(find.text('USER DASHBOARD'), findsOneWidget);
      expect(find.text('ASSIGNED MODULES'), findsOneWidget);

      // Assigned modules present
      expect(find.text('Lead Management'), findsOneWidget);
      expect(find.text('Calling'), findsOneWidget);

      // Unassigned modules MUST NOT be present
      expect(find.text('Inventory'), findsNothing);
      expect(find.text('Dispatch'), findsNothing);
      expect(find.text('Purchase'), findsNothing);
      expect(find.text('HR / Payroll'), findsNothing);
      expect(find.text('Approvals & Notifications'), findsNothing);
      expect(find.text('Vendor Management'), findsNothing);

      // Administration MUST NOT be present
      expect(find.text('ADMINISTRATION'), findsNothing);
      expect(find.text('Users & Access'), findsNothing);
    });

    testWidgets(
      'tapping Lead Management opens UserLeadPlaceholderScreen without unrestricted access',
      (tester) async {
        await tester.pumpWidget(_buildUserDashboardTestApp());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('module_card_leadManagement')));
        await tester.pumpAndSettle();

        expect(find.byType(UserLeadPlaceholderScreen), findsOneWidget);
        // New screen shows YOUR ACCESS capability section; old placeholder text removed
        expect(find.text('YOUR ACCESS'), findsOneWidget);
        expect(find.byKey(const Key('user_lead_workspace_screen')), findsOneWidget);

        // Tap Back to return to User Dashboard
        await tester.tap(find.text('Back to Dashboard'));
        await tester.pumpAndSettle();

        expect(find.byType(UserDashboardScreen), findsOneWidget);
      },
    );

    testWidgets('tapping Calling opens ModulePlaceholderScreen', (
      tester,
    ) async {
      await tester.pumpWidget(_buildUserDashboardTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('module_card_calling')));
      await tester.pumpAndSettle();

      expect(find.byType(ModulePlaceholderScreen), findsOneWidget);
      expect(find.text('Coming in a later module phase.'), findsOneWidget);

      await tester.tap(find.text('Back to Dashboard'));
      await tester.pumpAndSettle();

      expect(find.byType(UserDashboardScreen), findsOneWidget);
    });

    testWidgets('tapping Logout invokes onLogout callback', (tester) async {
      bool loggedOut = false;
      await tester.pumpWidget(
        _buildUserDashboardTestApp(
          onLogout: () {
            loggedOut = true;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('crm_header_logout_button')));
      await tester.pumpAndSettle();

      expect(loggedOut, isTrue);
    });

    testWidgets('renders cleanly across viewports without overflow', (
      tester,
    ) async {
      const viewports = [
        Size(320, 568),
        Size(360, 640),
        Size(768, 1024),
        Size(1200, 800),
      ];

      for (final size in viewports) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_buildUserDashboardTestApp());
        await tester.pumpAndSettle();

        expect(find.text('USER DASHBOARD'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('renders cleanly in dark theme', (tester) async {
      await tester.pumpWidget(
        _buildUserDashboardTestApp(themeMode: ThemeMode.dark),
      );
      await tester.pumpAndSettle();

      expect(find.text('USER DASHBOARD'), findsOneWidget);
      expect(
        find.byKey(const Key('module_card_leadManagement')),
        findsOneWidget,
      );
    });
  });
}
