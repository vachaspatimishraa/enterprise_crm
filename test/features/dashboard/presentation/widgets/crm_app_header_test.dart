import 'package:enterprise_crm/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/dashboard/presentation/widgets/crm_app_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildHeaderTestApp({
  required CurrentUser user,
  VoidCallback? onLogout,
  ThemeMode themeMode = ThemeMode.light,
  Size size = const Size(1024, 768),
}) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
    darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
    themeMode: themeMode,
    home: Scaffold(
      body: SizedBox(
        width: size.width,
        child: CrmAppHeader(user: user, onLogout: onLogout ?? () {}),
      ),
    ),
  );
}

void main() {
  group('CrmAppHeader Tests (UI-P1)', () {
    testWidgets(
      'absent application branding (no Enterprise CRM and no briefcase icon)',
      (tester) async {
        await tester.pumpWidget(
          _buildHeaderTestApp(user: MockAuthRepository.mockAdmin),
        );
        await tester.pumpAndSettle();

        // Brand text and icon MUST NOT be present
        expect(find.text('Enterprise CRM'), findsNothing);
        expect(find.byIcon(Icons.business_center), findsNothing);
      },
    );

    testWidgets('shows Administrator only once with avatar and logout on right', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHeaderTestApp(user: MockAuthRepository.mockAdmin),
      );
      await tester.pumpAndSettle();

      // Administrator appears exactly once
      expect(find.text('Administrator'), findsOneWidget);
      // No duplicate Admin or role subtitle
      expect(find.text('Admin'), findsNothing);

      // Avatar with initial 'A'
      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.text('A'), findsOneWidget);

      // Logout button present with tooltip
      final logoutButton = find.byKey(const Key('crm_header_logout_button'));
      expect(logoutButton, findsOneWidget);
      expect(find.byTooltip('Logout'), findsOneWidget);

      // Verify trailing alignment (logout is to the right of avatar, avatar is to the right of display name)
      final nameTopRight = tester.getTopRight(find.text('Administrator'));
      final avatarTopLeft = tester.getTopLeft(find.byType(CircleAvatar));
      final logoutTopLeft = tester.getTopLeft(logoutButton);

      expect(avatarTopLeft.dx, greaterThan(nameTopRight.dx));
      expect(logoutTopLeft.dx, greaterThan(avatarTopLeft.dx));
    });

    testWidgets(
      'normal User shows display name only once without duplicate role label',
      (tester) async {
        await tester.pumpWidget(
          _buildHeaderTestApp(user: MockAuthRepository.mockUser),
        );
        await tester.pumpAndSettle();

        // Display name appears exactly once
        expect(find.text('Standard User'), findsOneWidget);
        // Avatar with initial 'S'
        expect(find.text('S'), findsOneWidget);

        // No duplicate role labels
        expect(find.text('User'), findsNothing);
        expect(find.text('Enterprise CRM'), findsNothing);
        expect(
          find.byKey(const Key('crm_header_logout_button')),
          findsOneWidget,
        );
      },
    );

    testWidgets('tapping logout triggers onLogout callback', (tester) async {
      bool loggedOut = false;
      await tester.pumpWidget(
        _buildHeaderTestApp(
          user: MockAuthRepository.mockAdmin,
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
      'mobile narrow viewport (< 420px) shows avatar + logout with zero overflow',
      (tester) async {
        await tester.pumpWidget(
          _buildHeaderTestApp(
            user: MockAuthRepository.mockAdmin,
            size: const Size(360, 640),
          ),
        );
        await tester.pumpAndSettle();

        // On narrow screen, full display name is omitted to prevent crowding
        expect(find.text('Administrator'), findsNothing);

        // Avatar and Logout remain visible and accessible
        expect(find.byType(CircleAvatar), findsOneWidget);
        expect(find.text('A'), findsOneWidget);
        expect(
          find.byKey(const Key('crm_header_logout_button')),
          findsOneWidget,
        );

        // Verify no overflow error occurred
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('renders cleanly in dark mode', (tester) async {
      await tester.pumpWidget(
        _buildHeaderTestApp(
          user: MockAuthRepository.mockAdmin,
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
