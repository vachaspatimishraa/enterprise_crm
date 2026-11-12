import 'package:enterprise_crm/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/repositories/auth_repository.dart';
import 'package:enterprise_crm/features/dashboard/presentation/widgets/crm_app_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/mock_auth_test_fixtures.dart';

import 'package:enterprise_crm/features/user_management/data/mock/mock_account_store.dart';
import 'package:enterprise_crm/features/user_management/data/repositories/mock_user_management_repository.dart';
import 'package:enterprise_crm/features/user_management/domain/repositories/user_management_repository.dart';

Widget _buildHeaderTestApp({
  required CurrentUser user,
  VoidCallback? onLogout,
  UserManagementRepository? userManagementRepository,
  AuthRepository? authRepository,
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
        child: CrmAppHeader(
          user: user,
          onLogout: onLogout ?? () {},
          userManagementRepository: userManagementRepository,
          authRepository: authRepository,
        ),
      ),
    ),
  );
}

void main() {
  group('CrmAppHeader Tests (Account Avatar in Top Right Corner)', () {
    testWidgets(
      'absent application branding (no Enterprise CRM and no briefcase icon)',
      (tester) async {
        await tester.pumpWidget(
          _buildHeaderTestApp(user: MockAuthTestFixtures.admin),
        );
        await tester.pumpAndSettle();

        expect(find.text('Vinay Enterprise CRM'), findsNothing);
        expect(find.text('Enterprise CRM'), findsNothing);
        expect(find.byIcon(Icons.business_center), findsNothing);
      },
    );

    testWidgets(
      'Admin layout: avatar [A] and logout are on the top right side',
      (tester) async {
        await tester.pumpWidget(
          _buildHeaderTestApp(user: MockAuthTestFixtures.admin),
        );
        await tester.pumpAndSettle();

        final headerBox = find.byType(CrmAppHeader);
        final headerLeft = tester.getTopLeft(headerBox).dx;
        final headerRight = tester.getTopRight(headerBox).dx;
        final headerCenter = (headerLeft + headerRight) / 2;

        // Display name appears
        expect(find.text('Administrator'), findsOneWidget);

        // Avatar with initial 'A'
        final avatarFinder = find.byKey(const Key('home_account_avatar'));
        expect(avatarFinder, findsOneWidget);
        expect(find.text('A'), findsOneWidget);

        // Avatar is on the right half of the header
        final avatarLeft = tester.getTopLeft(avatarFinder).dx;
        expect(avatarLeft, greaterThan(headerCenter));

        // Logout is also on the far right
        final logoutButton = find.byKey(const Key('crm_header_logout_button'));
        expect(logoutButton, findsOneWidget);
        expect(find.byTooltip('Logout'), findsOneWidget);

        final logoutRight = tester.getTopRight(logoutButton).dx;
        expect(logoutRight, greaterThan(headerRight - 60.0));
      },
    );

    testWidgets(
      'tapping account avatar opens AccountProfileDialog with uneditable User ID, name edit, password reset, and logout',
      (tester) async {
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

        // Tap the account avatar
        await tester.tap(find.byKey(const Key('home_account_avatar')));
        await tester.pumpAndSettle();

        // Account Profile dialog is open
        expect(find.byKey(const Key('home_account_dialog')), findsOneWidget);

        // User ID is displayed and uneditable
        final userIdFieldFinder = find.byKey(const Key('account_user_id_field'));
        expect(userIdFieldFinder, findsOneWidget);
        final textField = tester.widget<TextField>(userIdFieldFinder);
        expect(textField.enabled, isFalse);
        expect(textField.readOnly, isTrue);
        expect(find.text('User ID cannot be changed'), findsOneWidget);

        // Display Name is editable
        expect(find.byKey(const Key('account_display_name_field')), findsOneWidget);

        // Password reset button is available
        expect(find.byKey(const Key('account_reset_password_button')), findsOneWidget);

        // Tap dialog logout button
        await tester.ensureVisible(find.byKey(const Key('account_logout_button')));
        await tester.tap(find.byKey(const Key('account_logout_button')));
        await tester.pumpAndSettle();

        expect(loggedOut, isTrue);
        expect(find.byKey(const Key('home_account_dialog')), findsNothing);
      },
    );

    testWidgets('tapping logout triggers onLogout callback', (
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

    testWidgets(
      'mobile narrow viewport (< 420px) shows avatar on top right without overflow',
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
        final headerRight = tester.getTopRight(headerBox).dx;

        expect(find.text('Administrator'), findsNothing);
        expect(find.byKey(const Key('home_account_avatar')), findsOneWidget);

        final avatarRight = tester
            .getTopRight(find.byKey(const Key('home_account_avatar')))
            .dx;
        expect(avatarRight, greaterThan(headerRight - 60.0));

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
      expect(find.byKey(const Key('home_account_avatar')), findsOneWidget);
      expect(find.byKey(const Key('crm_header_logout_button')), findsOneWidget);
    });

    testWidgets(
      'tapping Reset Password opens OTP verification instead of direct password fields',
      (tester) async {
        final store = MockAccountStore.seeded();
        final authRepo = MockAuthRepository(accountStore: store);

        await tester.pumpWidget(
          _buildHeaderTestApp(
            user: MockAuthTestFixtures.admin,
            authRepository: authRepo,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('home_account_avatar')));
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.byKey(const Key('account_reset_password_button')),
        );
        await tester.tap(find.byKey(const Key('account_reset_password_button')));
        await tester.pumpAndSettle();

        // OTP Step 1 is displayed; password fields are locked behind OTP verification
        expect(
          find.byKey(const Key('account_otp_flow_container')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('account_otp_step_1')), findsOneWidget);
        expect(find.byKey(const Key('account_send_otp_button')), findsOneWidget);
        expect(find.byKey(const Key('account_new_password_field')), findsNothing);
        expect(find.byKey(const Key('account_save_password_button')), findsNothing);
      },
    );

    testWidgets(
      'invalid OTP displays error banner and keeps password change fields hidden',
      (tester) async {
        final store = MockAccountStore.seeded();
        final authRepo = MockAuthRepository(accountStore: store);

        await tester.pumpWidget(
          _buildHeaderTestApp(
            user: MockAuthTestFixtures.admin,
            authRepository: authRepo,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('home_account_avatar')));
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.byKey(const Key('account_reset_password_button')),
        );
        await tester.tap(find.byKey(const Key('account_reset_password_button')));
        await tester.pumpAndSettle();

        // Step 1 -> Send OTP
        await tester.ensureVisible(
          find.byKey(const Key('account_send_otp_button')),
        );
        await tester.tap(find.byKey(const Key('account_send_otp_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byKey(const Key('account_otp_step_2')), findsOneWidget);
        expect(find.byKey(const Key('account_otp_demo_badge')), findsOneWidget);
        expect(find.textContaining('123456'), findsOneWidget);

        // Enter wrong OTP
        await tester.enterText(
          find.byKey(const Key('account_otp_field')),
          '000000',
        );
        await tester.ensureVisible(
          find.byKey(const Key('account_verify_otp_button')),
        );
        await tester.tap(find.byKey(const Key('account_verify_otp_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byKey(const Key('account_otp_error_banner')), findsOneWidget);
        expect(find.textContaining('2 attempts remaining'), findsOneWidget);
        expect(find.byKey(const Key('account_new_password_field')), findsNothing);

        // Hide flow cleanly cancels cooldown timer
        await tester.ensureVisible(
          find.byKey(const Key('account_reset_password_button')),
        );
        await tester.tap(find.byKey(const Key('account_reset_password_button')));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'user receives OTP, verifies OTP, and updates password successfully from AccountProfileDialog',
      (tester) async {
        final store = MockAccountStore.seeded();
        final userRepo = MockUserManagementRepository(accountStore: store);
        final authRepo = MockAuthRepository(
          accountStore: store,
          otpCodeGenerator: () => '654321',
        );

        await tester.pumpWidget(
          _buildHeaderTestApp(
            user: MockAuthTestFixtures.admin,
            userManagementRepository: userRepo,
            authRepository: authRepo,
          ),
        );
        await tester.pumpAndSettle();

        // Tap avatar to open dialog
        await tester.tap(find.byKey(const Key('home_account_avatar')));
        await tester.pumpAndSettle();

        // Tap Reset Password to start OTP flow
        await tester.ensureVisible(
          find.byKey(const Key('account_reset_password_button')),
        );
        await tester.tap(find.byKey(const Key('account_reset_password_button')));
        await tester.pumpAndSettle();

        // Step 1: Send OTP
        await tester.ensureVisible(
          find.byKey(const Key('account_send_otp_button')),
        );
        await tester.tap(find.byKey(const Key('account_send_otp_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Step 2: User sees masked email & received OTP
        expect(
          find.textContaining('ad***@enterprise-crm.internal'),
          findsOneWidget,
        );
        expect(find.text('Received OTP: 654321'), findsOneWidget);

        // Enter received OTP and verify
        await tester.enterText(
          find.byKey(const Key('account_otp_field')),
          '654321',
        );
        await tester.ensureVisible(
          find.byKey(const Key('account_verify_otp_button')),
        );
        await tester.tap(find.byKey(const Key('account_verify_otp_button')));
        await tester.pumpAndSettle();

        // Step 3: OTP verified badge and new password fields unlocked
        expect(find.byKey(const Key('account_otp_step_3')), findsOneWidget);
        expect(
          find.byKey(const Key('account_otp_verified_badge')),
          findsOneWidget,
        );

        // Enter new password and confirmation
        await tester.enterText(
          find.byKey(const Key('account_new_password_field')),
          'newSecret123',
        );
        await tester.enterText(
          find.byKey(const Key('account_confirm_password_field')),
          'newSecret123',
        );
        await tester.pumpAndSettle();

        // Tap Update Password
        await tester.ensureVisible(
          find.byKey(const Key('account_save_password_button')),
        );
        await tester.tap(find.byKey(const Key('account_save_password_button')));
        await tester.pumpAndSettle();

        // Verify success notification and collapsed security section
        expect(find.text('Password changed successfully.'), findsOneWidget);
        expect(
          find.byKey(const Key('account_otp_flow_container')),
          findsNothing,
        );

        // Verify old credential fails and new credential works in store
        expect(
          store.authenticate(userId: 'admin', password: 'admin123'),
          isNull,
        );
        expect(
          store.authenticate(userId: 'admin', password: 'newSecret123'),
          isNotNull,
        );
      },
    );

    testWidgets(
      'missing AuthRepository shows OTP service error and blocks password reset',
      (tester) async {
        await tester.pumpWidget(
          _buildHeaderTestApp(user: MockAuthTestFixtures.admin),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('home_account_avatar')));
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.byKey(const Key('account_reset_password_button')),
        );
        await tester.tap(find.byKey(const Key('account_reset_password_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('account_otp_error_banner')), findsOneWidget);
        expect(
          find.textContaining('OTP verification service is unavailable'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('account_new_password_field')), findsNothing);
      },
    );

    testWidgets(
      'OTP password reset flow renders without overflow on narrow 320px viewport',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final store = MockAccountStore.seeded();
        final authRepo = MockAuthRepository(accountStore: store);

        await tester.pumpWidget(
          _buildHeaderTestApp(
            user: MockAuthTestFixtures.admin,
            authRepository: authRepo,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('home_account_avatar')));
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.byKey(const Key('account_reset_password_button')),
        );
        await tester.tap(find.byKey(const Key('account_reset_password_button')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(
          find.byKey(const Key('account_send_otp_button')),
        );
        await tester.tap(find.byKey(const Key('account_send_otp_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);

        await tester.enterText(
          find.byKey(const Key('account_otp_field')),
          '123456',
        );
        await tester.ensureVisible(
          find.byKey(const Key('account_verify_otp_button')),
        );
        await tester.tap(find.byKey(const Key('account_verify_otp_button')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  });
}
