import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/dashboard/presentation/widgets/crm_app_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/mock_auth_test_fixtures.dart';

Widget _buildHeaderTestApp({
  required CurrentUser user,
  VoidCallback? onLogout,
  ThemeMode themeMode = ThemeMode.light,
  double? width,
}) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
    darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
    themeMode: themeMode,
    home: Scaffold(
      body: SizedBox(
        width: width,
        child: CrmAppHeader(user: user, onLogout: onLogout ?? () {}),
      ),
    ),
  );
}

void main() {
  group('CrmAppHeader Tests (UI-P1.1 Final Alignment)', () {
    testWidgets(
      'absent application branding (no Enterprise CRM and no briefcase icon)',
      (tester) async {
        await tester.pumpWidget(
          _buildHeaderTestApp(user: MockAuthTestFixtures.admin),
        );
        await tester.pumpAndSettle();

        // Brand text and icon MUST NOT be present in authenticated header
        expect(find.text('Enterprise CRM'), findsNothing);
        expect(find.byIcon(Icons.business_center), findsNothing);
      },
    );

    testWidgets(
      'Admin layout: avatar [A] is on the far left, followed by Administrator, with only Logout on far right',
      (tester) async {
        await tester.pumpWidget(
          _buildHeaderTestApp(user: MockAuthTestFixtures.admin),
        );
        await tester.pumpAndSettle();

        final headerBox = find.byType(CrmAppHeader);
        final headerLeft = tester.getTopLeft(headerBox).dx;
        final headerRight = tester.getTopRight(headerBox).dx;
        final headerCenter = (headerLeft + headerRight) / 2;

        // 1. Administrator appears exactly once
        expect(find.text('Administrator'), findsOneWidget);
        // No duplicate Admin or role subtitle
        expect(find.text('Admin'), findsNothing);

        // 2. Avatar with initial 'A'
        final avatarFinder = find.byType(CircleAvatar);
        expect(avatarFinder, findsOneWidget);
        expect(find.text('A'), findsOneWidget);

        // 3. Avatar is on the far left, BEFORE the display name
        final avatarLeft = tester.getTopLeft(avatarFinder).dx;
        final avatarRight = tester.getTopRight(avatarFinder).dx;
        final nameLeft = tester.getTopLeft(find.text('Administrator')).dx;
        final nameRight = tester.getTopRight(find.text('Administrator')).dx;

        expect(avatarLeft, lessThan(headerLeft + 30.0)); // Far left
        expect(
          nameLeft,
          greaterThan(avatarRight),
        ); // Display name is AFTER avatar
        expect(nameRight, lessThan(headerCenter)); // Both on left side

        // 4. Logout is the only trailing/right-side action
        final logoutButton = find.byKey(const Key('crm_header_logout_button'));
        expect(logoutButton, findsOneWidget);
        expect(find.byTooltip('Logout'), findsOneWidget);

        final logoutRight = tester.getTopRight(logoutButton).dx;
        expect(logoutRight, greaterThan(headerRight - 60.0)); // Far right edge
      },
    );

    testWidgets(
      'normal User layout: avatar [S] is on the left, followed by Standard User, with only Logout on right',
      (tester) async {
        await tester.pumpWidget(
          _buildHeaderTestApp(user: MockAuthTestFixtures.standardUser),
        );
        await tester.pumpAndSettle();

        final headerBox = find.byType(CrmAppHeader);
        final headerLeft = tester.getTopLeft(headerBox).dx;
        final headerRight = tester.getTopRight(headerBox).dx;
        final headerCenter = (headerLeft + headerRight) / 2;

        // Display name appears exactly once
        expect(find.text('Standard User'), findsOneWidget);
        expect(find.text('S'), findsOneWidget);

        // No duplicate role labels or branding
        expect(find.text('User'), findsNothing);
        expect(find.text('Enterprise CRM'), findsNothing);

        // Avatar before display name on left
        final avatarFinder = find.byType(CircleAvatar);
        final avatarRight = tester.getTopRight(avatarFinder).dx;
        final nameLeft = tester.getTopLeft(find.text('Standard User')).dx;
        expect(nameLeft, greaterThan(avatarRight));
        expect(nameLeft, lessThan(headerCenter));

        // Right alignment check
        final logoutButton = find.byKey(const Key('crm_header_logout_button'));
        final logoutRight = tester.getTopRight(logoutButton).dx;
        expect(logoutRight, greaterThan(headerRight - 60.0));
      },
    );

    testWidgets('tapping admin logout triggers onLogout callback', (
      tester,
    ) async {
      bool loggedOut = false;
      await tester.pumpWidget(
        _buildHeaderTestApp(
          user: MockAuthTestFixtures.admin,
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

    testWidgets('tapping normal user logout triggers onLogout callback', (
      tester,
    ) async {
      bool loggedOut = false;
      await tester.pumpWidget(
        _buildHeaderTestApp(
          user: MockAuthTestFixtures.standardUser,
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

    testWidgets(
      'mobile narrow viewport (< 420px) shows avatar [A] on left and logout on far right without overflow',
      (tester) async {
        const mobileWidth = 360.0;
        await tester.pumpWidget(
          _buildHeaderTestApp(
            user: MockAuthTestFixtures.admin,
            width: mobileWidth,
          ),
        );
        await tester.pumpAndSettle();

        final headerBox = find.byType(CrmAppHeader);
        final headerLeft = tester.getTopLeft(headerBox).dx;
        final headerRight = tester.getTopRight(headerBox).dx;

        // On narrow screen, full display name is omitted to prevent crowding
        expect(find.text('Administrator'), findsNothing);

        // Avatar remains on the far left
        final avatarLeft = tester.getTopLeft(find.byType(CircleAvatar)).dx;
        expect(avatarLeft, lessThan(headerLeft + 30.0));

        // Logout remains on the far right
        final logoutRight = tester
            .getTopRight(find.byKey(const Key('crm_header_logout_button')))
            .dx;
        expect(logoutRight, greaterThan(headerRight - 60.0));

        // Verify zero overflow
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('renders cleanly in dark mode', (tester) async {
      await tester.pumpWidget(
        _buildHeaderTestApp(
          user: MockAuthTestFixtures.admin,
          themeMode: ThemeMode.dark,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Administrator'), findsOneWidget);
      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.byKey(const Key('crm_header_logout_button')), findsOneWidget);
    });
  });
}
