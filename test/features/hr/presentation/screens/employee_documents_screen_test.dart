import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/hr/data/repositories/mock_employee_document_repository.dart';
import 'package:enterprise_crm/features/hr/domain/entities/employee.dart';
import 'package:enterprise_crm/features/hr/domain/entities/employment_status.dart';
import 'package:enterprise_crm/features/hr/presentation/screens/employee_documents_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockEmployeeDocumentRepository repository;

  const adminUser = CurrentUser(
    id: 'usr_admin',
    displayName: 'Admin User',
    accountType: AccountType.admin,
    modules: {},
    permissions: {},
  );

  const hrStandardUser = CurrentUser(
    id: 'usr_hr',
    displayName: 'HR Specialist',
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

  final sampleEmployee = Employee(
    id: 'emp_1',
    employeeCode: 'EMP-001',
    fullName: 'Alice Johnson',
    department: 'Human Resources',
    designation: 'HR Manager',
    employmentStatus: EmploymentStatus.active,
  );

  setUp(() {
    repository = MockEmployeeDocumentRepository();
  });

  Widget buildTestWidget({
    required CurrentUser user,
    Size size = const Size(800, 1000),
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: EmployeeDocumentsScreen(
          user: user,
          employee: sampleEmployee,
          repository: repository,
        ),
      ),
    );
  }

  group('EmployeeDocumentsScreen Tests', () {
    testWidgets('unauthorized user sees AccessRestrictedScreen', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(user: unauthorizedUser));
      await tester.pumpAndSettle();

      expect(find.text('Access Restricted'), findsOneWidget);
      expect(
        find.byKey(const Key('employee_documents_scaffold')),
        findsNothing,
      );
    });

    testWidgets('authorized standard user sees documents without Add button', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(user: hrStandardUser));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('employee_documents_scaffold')),
        findsOneWidget,
      );
      expect(find.text('Alice Johnson — Documents'), findsOneWidget);
      expect(find.text('Employment Agreement'), findsOneWidget);
      expect(
        find.byKey(const Key('employee_documents_add_button')),
        findsNothing,
      );
    });

    testWidgets('admin user sees Add Document floating action button', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(user: adminUser));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('employee_documents_add_button')),
        findsOneWidget,
      );
    });

    testWidgets('mobile layout renders cards (< 600px width)', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget(user: adminUser));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('employee_documents_mobile_list')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('employee_document_card_doc_1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('employee_documents_desktop_table_scroll')),
        findsNothing,
      );
    });

    testWidgets('desktop layout renders table (>= 600px width)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget(user: adminUser));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('employee_documents_desktop_table_scroll')),
        findsOneWidget,
      );
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('Employment Agreement'), findsOneWidget);
      expect(
        find.byKey(const Key('employee_documents_mobile_list')),
        findsNothing,
      );
    });

    testWidgets('search filters documents by title', (tester) async {
      await tester.pumpWidget(buildTestWidget(user: adminUser));
      await tester.pumpAndSettle();

      expect(find.text('Employment Agreement'), findsOneWidget);
      expect(find.text('National Identity Proof'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('employee_documents_search_field')),
        'Agreement',
      );
      await tester.pumpAndSettle();

      expect(find.text('Employment Agreement'), findsOneWidget);
      expect(find.text('National Identity Proof'), findsNothing);
    });

    testWidgets('type filter chips filter documents', (tester) async {
      await tester.pumpWidget(buildTestWidget(user: adminUser));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('filter_chip_identity')));
      await tester.pumpAndSettle();

      expect(find.text('National Identity Proof'), findsOneWidget);
      expect(find.text('Employment Agreement'), findsNothing);
    });

    testWidgets('empty search shows empty state illustration', (tester) async {
      await tester.pumpWidget(buildTestWidget(user: adminUser));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('employee_documents_search_field')),
        'NonexistentQuery12345',
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('employee_documents_empty_icon')),
        findsOneWidget,
      );
      expect(find.text('No documents found'), findsOneWidget);
    });
  });
}
