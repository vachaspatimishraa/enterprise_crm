import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/auth/presentation/screens/access_restricted_screen.dart';
import 'package:enterprise_crm/features/hr/data/repositories/mock_attendance_repository.dart';
import 'package:enterprise_crm/features/hr/presentation/screens/attendance_details_dialog.dart';
import 'package:enterprise_crm/features/hr/presentation/screens/attendance_list_screen.dart';
import 'package:enterprise_crm/features/hr/presentation/widgets/attendance_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockAttendanceRepository repository;

  const adminUser = CurrentUser(
    id: 'usr_admin',
    displayName: 'Admin User',
    accountType: AccountType.admin,
    modules: {},
    permissions: {},
  );

  const hrViewerUser = CurrentUser(
    id: 'usr_hr_viewer',
    displayName: 'HR Viewer',
    accountType: AccountType.user,
    modules: {CrmModule.hrPayroll},
    permissions: {CrmPermissions.hrView},
  );

  const unauthorizedUser = CurrentUser(
    id: 'usr_sales',
    displayName: 'Sales User',
    accountType: AccountType.user,
    modules: {CrmModule.leadManagement},
    permissions: {CrmPermissions.leadViewAssigned},
  );

  setUp(() {
    repository = MockAttendanceRepository();
  });

  Widget buildTestWidget({
    required CurrentUser user,
    Size size = const Size(800, 1200),
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: AttendanceListScreen(user: user, repository: repository),
      ),
    );
  }

  group('AttendanceListScreen Widget Tests', () {
    testWidgets('unauthorized user sees AccessRestrictedScreen', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(user: unauthorizedUser));
      await tester.pumpAndSettle();

      expect(find.byType(AccessRestrictedScreen), findsOneWidget);
      expect(find.byKey(const Key('attendance_list_scaffold')), findsNothing);
    });

    testWidgets('authorized user sees attendance list and seeded records', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(user: hrViewerUser));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('attendance_list_scaffold')), findsOneWidget);
      expect(find.text('Attendance Management'), findsOneWidget);
      expect(find.byKey(const Key('attendance_search_field')), findsOneWidget);
      expect(
        find.byKey(const Key('attendance_view_mode_toggle')),
        findsOneWidget,
      );
    });

    testWidgets('search filters attendance records', (tester) async {
      await tester.pumpWidget(buildTestWidget(user: adminUser));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('attendance_search_field')),
        'casual leave',
      );
      await tester.pumpAndSettle();

      expect(find.byType(AttendanceStatusBadge), findsOneWidget);
      expect(find.text('emp_1'), findsOneWidget);
      expect(find.text('emp_2'), findsNothing);
    });

    testWidgets('status filter chips filter records', (tester) async {
      await tester.pumpWidget(buildTestWidget(user: adminUser));
      await tester.pumpAndSettle();

      final absentChip = find.byKey(const Key('attendance_filter_chip_Absent'));
      expect(absentChip, findsOneWidget);
      await tester.tap(absentChip);
      await tester.pumpAndSettle();

      expect(find.byType(AttendanceStatusBadge), findsOneWidget);
      expect(find.text('emp_2'), findsOneWidget);
      expect(find.text('emp_1'), findsNothing);
    });

    testWidgets(
      'switching to calendar view displays calendar grid and month header',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(user: adminUser));
        await tester.pumpAndSettle();

        // Tap Calendar segment in toggle
        final calendarSegment = find.text('Calendar');
        expect(calendarSegment, findsOneWidget);
        await tester.tap(calendarSegment);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('calendar_month_title')), findsOneWidget);
        expect(find.text('September 2026'), findsOneWidget);
        expect(
          find.byKey(const Key('calendar_prev_month_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('calendar_next_month_button')),
          findsOneWidget,
        );
      },
    );

    testWidgets('desktop view renders DataTable (width >= 600px)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestWidget(user: adminUser, size: const Size(1200, 800)),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('attendance_desktop_table_scroll')),
        findsOneWidget,
      );
      expect(find.byType(DataTable), findsOneWidget);
    });

    testWidgets('mobile view renders ListView cards (width < 600px)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestWidget(user: adminUser, size: const Size(400, 800)),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('attendance_mobile_list')), findsOneWidget);
    });

    testWidgets('tapping Details button opens AttendanceDetailsDialog', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestWidget(user: adminUser, size: const Size(1200, 800)),
      );
      await tester.pumpAndSettle();

      final detailsBtn = find.text('Details').first;
      await tester.ensureVisible(detailsBtn);
      await tester.tap(detailsBtn);
      await tester.pumpAndSettle();

      expect(find.byType(AttendanceDetailsDialog), findsOneWidget);
      expect(
        find.byKey(const Key('attendance_details_dialog')),
        findsOneWidget,
      );
      expect(find.text('Attendance Details'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('attendance_details_close_button')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AttendanceDetailsDialog), findsNothing);
    });
  });
}
