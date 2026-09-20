import 'package:enterprise_crm/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:enterprise_crm/features/dashboard/presentation/screens/admin_dashboard_screen.dart';
import 'package:enterprise_crm/features/dashboard/presentation/screens/module_placeholder_screen.dart';
import 'package:enterprise_crm/features/user_management/data/repositories/mock_user_management_repository.dart';
import 'package:enterprise_crm/features/user_management/presentation/screens/users_and_access_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildAdminDashboardTestApp({
  VoidCallback? onLogout,
  VoidCallback? onOpenLeadManagement,
  ThemeMode themeMode = ThemeMode.light,
}) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
    darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
    themeMode: themeMode,
    home: AdminDashboardScreen(
      user: MockAuthRepository.mockAdmin,
      onLogout: onLogout ?? () {},
      onOpenLeadManagement: onOpenLeadManagement ?? () {},
      userManagementRepository: MockUserManagementRepository(),
    ),
  );
}

void main() {
  group('AdminDashboardScreen Tests', () {
    testWidgets('renders header, title, and all 8 business modules', (
      tester,
    ) async {
      await tester.pumpWidget(_buildAdminDashboardTestApp());
      await tester.pumpAndSettle();

      // Header
      expect(find.text('Enterprise CRM'), findsOneWidget);
      expect(find.text('Administrator'), findsWidgets);
      expect(find.byKey(const Key('crm_header_logout_button')), findsOneWidget);

      // Section title
      expect(find.text('ADMIN DASHBOARD'), findsOneWidget);
      expect(find.text('BUSINESS MODULES'), findsOneWidget);

      // All 8 modules present
      expect(find.text('Lead Management'), findsOneWidget);
      expect(find.text('Calling'), findsOneWidget);
      expect(find.text('Inventory'), findsOneWidget);
      expect(find.text('Dispatch'), findsOneWidget);
      expect(find.text('Purchase'), findsOneWidget);
      expect(find.text('HR / Payroll'), findsOneWidget);
      expect(find.text('Approvals & Notifications'), findsOneWidget);
      expect(find.text('Vendor Management'), findsOneWidget);

      // Administration section
      expect(find.text('ADMINISTRATION'), findsOneWidget);
      expect(find.text('Users & Access'), findsOneWidget);
      expect(
        find.byKey(const Key('admin_card_users_and_access')),
        findsOneWidget,
      );
    });

    testWidgets('tapping Lead Management invokes onOpenLeadManagement', (
      tester,
    ) async {
      bool opened = false;
      await tester.pumpWidget(
        _buildAdminDashboardTestApp(
          onOpenLeadManagement: () {
            opened = true;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('module_card_leadManagement')));
      await tester.pumpAndSettle();

      expect(opened, isTrue);
    });

    testWidgets('tapping Calling opens ModulePlaceholderScreen', (
      tester,
    ) async {
      await tester.pumpWidget(_buildAdminDashboardTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('module_card_calling')));
      await tester.pumpAndSettle();

      expect(find.byType(ModulePlaceholderScreen), findsOneWidget);
      expect(find.text('Coming in a later module phase.'), findsOneWidget);

      // Tap Back
      await tester.tap(find.text('Back to Dashboard'));
      await tester.pumpAndSettle();

      expect(find.byType(AdminDashboardScreen), findsOneWidget);
    });

    testWidgets('tapping Users & Access opens UsersAndAccessScreen', (
      tester,
    ) async {
      await tester.pumpWidget(_buildAdminDashboardTestApp());
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('admin_card_users_and_access')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('admin_card_users_and_access')));
      await tester.pumpAndSettle();

      expect(find.byType(UsersAndAccessScreen), findsOneWidget);
      expect(find.text('USER DIRECTORY'), findsOneWidget);

      // Tap Back via AppBar back button
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(AdminDashboardScreen), findsOneWidget);
    });

    testWidgets('tapping Logout invokes onLogout callback', (tester) async {
      bool loggedOut = false;
      await tester.pumpWidget(
        _buildAdminDashboardTestApp(
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

        await tester.pumpWidget(_buildAdminDashboardTestApp());
        await tester.pumpAndSettle();

        expect(find.text('ADMIN DASHBOARD'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('renders cleanly in dark theme', (tester) async {
      await tester.pumpWidget(
        _buildAdminDashboardTestApp(themeMode: ThemeMode.dark),
      );
      await tester.pumpAndSettle();

      expect(find.text('ADMIN DASHBOARD'), findsOneWidget);
      expect(
        find.byKey(const Key('module_card_leadManagement')),
        findsOneWidget,
      );
    });
  });
}
