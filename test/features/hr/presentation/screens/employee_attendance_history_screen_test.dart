import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/auth/presentation/screens/access_restricted_screen.dart';
import 'package:enterprise_crm/features/hr/data/repositories/mock_attendance_repository.dart';
import 'package:enterprise_crm/features/hr/domain/entities/employee.dart';
import 'package:enterprise_crm/features/hr/presentation/screens/attendance_details_dialog.dart';
import 'package:enterprise_crm/features/hr/presentation/screens/employee_attendance_history_screen.dart';
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
    id: 'usr_unauth',
    displayName: 'Unauthorized User',
    accountType: AccountType.user,
    modules: {},
    permissions: {},
  );

  setUp(() {
    repository = MockAttendanceRepository();
  });

  Widget buildWidget({required CurrentUser user, required Employee employee}) {
    return MaterialApp(
      home: EmployeeAttendanceHistoryScreen(
        employee: employee,
        repository: repository,
        user: user,
      ),
    );
  }

  group('EmployeeAttendanceHistoryScreen Widget Tests', () {
    testWidgets('unauthorized user sees AccessRestrictedScreen', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(
          user: unauthorizedUser,
          employee: const Employee(id: 'emp_1', fullName: 'Aarav Sharma'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AccessRestrictedScreen), findsOneWidget);
      expect(find.text('Access Restricted'), findsOneWidget);
    });

    testWidgets(
      'authorized user sees summary metric cards and record history',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          buildWidget(
            user: hrViewerUser,
            employee: const Employee(id: 'emp_1', fullName: 'Aarav Sharma'),
          ),
        );
        await tester.pumpAndSettle();

        // Verify app bar title
        expect(find.text('Aarav Sharma — Attendance'), findsOneWidget);

        // Verify summary metrics cards
        expect(find.text('Total Days: '), findsOneWidget);
        expect(find.text('Present: '), findsOneWidget);
        expect(find.text('Half-day: '), findsOneWidget);

        // In seeded data, emp_1 has 5 records (att_101 through att_105)
        expect(find.byType(AttendanceStatusBadge), findsNWidgets(5));
        expect(find.text('2026-09-21'), findsOneWidget);
        expect(find.text('2026-09-22'), findsOneWidget);
        expect(find.text('2026-09-23'), findsOneWidget);
        expect(find.text('2026-09-24'), findsOneWidget);
        expect(find.text('2026-09-25'), findsOneWidget);
      },
    );

    testWidgets('empty state displays when employee has no records', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(
          user: adminUser,
          employee: const Employee(
            id: 'emp_nonexistent',
            fullName: 'Unknown Employee',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('No attendance records found for this employee.'),
        findsOneWidget,
      );
      expect(find.byType(AttendanceStatusBadge), findsNothing);
    });

    testWidgets('tapping card opens AttendanceDetailsDialog', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          user: adminUser,
          employee: const Employee(id: 'emp_1', fullName: 'Aarav Sharma'),
        ),
      );
      await tester.pumpAndSettle();

      final firstCard = find.byKey(const Key('employee_history_card_att_104'));
      expect(firstCard, findsOneWidget);

      await tester.tap(firstCard);
      await tester.pumpAndSettle();

      expect(find.byType(AttendanceDetailsDialog), findsOneWidget);
      expect(find.text('Attendance Details'), findsOneWidget);
    });
  });
}
