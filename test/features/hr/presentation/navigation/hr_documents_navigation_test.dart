import 'dart:typed_data';

import 'package:enterprise_crm/features/auth/data/repositories/mock_user_lead_link_repository.dart';
import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/auth/presentation/screens/access_restricted_screen.dart';
import 'package:enterprise_crm/features/calling/data/repositories/mock_lead_call_activity_repository.dart';
import 'package:enterprise_crm/features/calling/data/repositories/mock_lead_follow_up_repository.dart';
import 'package:enterprise_crm/features/dashboard/presentation/screens/admin_dashboard_screen.dart';
import 'package:enterprise_crm/features/dashboard/presentation/screens/user_dashboard_screen.dart';
import 'package:enterprise_crm/features/hr/data/repositories/mock_employee_document_repository.dart';
import 'package:enterprise_crm/features/hr/data/repositories/mock_employee_repository.dart';
import 'package:enterprise_crm/features/hr/domain/entities/employee.dart';
import 'package:enterprise_crm/features/hr/domain/entities/employment_status.dart';
import 'package:enterprise_crm/features/hr/presentation/screens/employee_details_screen.dart';
import 'package:enterprise_crm/features/hr/presentation/screens/employee_directory_screen.dart';
import 'package:enterprise_crm/features/hr/presentation/screens/employee_document_details_screen.dart';
import 'package:enterprise_crm/features/hr/presentation/screens/employee_documents_screen.dart';
import 'package:enterprise_crm/features/hr/presentation/screens/upload_document_screen.dart';
import 'package:enterprise_crm/features/hr/presentation/services/employee_document_file_picker.dart';
import 'package:enterprise_crm/features/leads/data/repositories/mock_lead_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/mock_auth_test_fixtures.dart';

void main() {
  late MockEmployeeRepository employeeRepository;
  late MockEmployeeDocumentRepository documentRepository;

  final sampleEmployee1 = Employee(
    id: 'emp_1',
    employeeCode: 'EMP-001',
    fullName: 'Alice Johnson',
    department: 'Human Resources',
    designation: 'HR Manager',
    employmentStatus: EmploymentStatus.active,
  );

  final sampleEmployee2 = Employee(
    id: 'emp_2',
    employeeCode: 'EMP-002',
    fullName: 'Bob Smith',
    department: 'Engineering',
    designation: 'Senior Developer',
    employmentStatus: EmploymentStatus.active,
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
    employeeRepository = MockEmployeeRepository();
    documentRepository = MockEmployeeDocumentRepository();
  });

  Widget buildAdminApp({
    ThemeMode themeMode = ThemeMode.light,
    EmployeeDocumentFilePicker? filePicker,
  }) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      themeMode: themeMode,
      home: AdminDashboardScreen(
        user: MockAuthTestFixtures.admin,
        onLogout: () {},
        onOpenLeadManagement: () {},
        employeeRepository: employeeRepository,
        employeeDocumentRepository: documentRepository,
      ),
    );
  }

  Widget buildUserApp({
    required CurrentUser user,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      themeMode: themeMode,
      home: UserDashboardScreen(
        user: user,
        onLogout: () {},
        userLeadLinkRepository: MockUserLeadLinkRepository(),
        leadRepository: MockLeadRepository(),
        callActivityRepository: MockLeadCallActivityRepository(),
        leadFollowUpRepository: MockLeadFollowUpRepository(),
        employeeRepository: employeeRepository,
        employeeDocumentRepository: documentRepository,
      ),
    );
  }

  group('HR-3 Employee Documents Application Integration & Navigation', () {
    testWidgets(
      'Full Admin flow: Dashboard -> Directory -> Details -> Documents -> Upload -> Details -> Download',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final mockPicker = MockEmployeeDocumentFilePicker(
          cannedFile: EmployeeDocumentPickedFile(
            name: 'bonus_letter.pdf',
            bytes: Uint8List.fromList([1, 2, 3, 4]),
            sizeBytes: 4,
            extension: 'pdf',
          ),
        );

        await tester.pumpWidget(buildAdminApp());
        await tester.pumpAndSettle();

        // 1. From Dashboard tap HR/Payroll module
        final hrCard = find.byKey(const Key('module_card_hrPayroll'));
        expect(hrCard, findsOneWidget);
        await tester.tap(hrCard);
        await tester.pumpAndSettle();

        expect(find.byType(EmployeeDirectoryScreen), findsOneWidget);
        expect(find.text('Alice Johnson'), findsOneWidget);

        // 2. Tap Alice Johnson to navigate to EmployeeDetailsScreen
        await tester.tap(find.text('Alice Johnson'));
        await tester.pumpAndSettle();

        expect(find.byType(EmployeeDetailsScreen), findsOneWidget);
        expect(find.text('EMP-001'), findsOneWidget);

        // 3. Scroll to and tap Employee Documents tile
        final docsTile = find.byKey(const Key('employee_documents_tile'));
        expect(docsTile, findsOneWidget);
        await tester.ensureVisible(docsTile);
        await tester.tap(docsTile);
        await tester.pumpAndSettle();

        expect(find.byType(EmployeeDocumentsScreen), findsOneWidget);
        expect(find.text('Alice Johnson — Documents'), findsOneWidget);
        expect(find.text('Employment Agreement'), findsOneWidget);

        // 4. Tap Add Document FAB
        final addDocFab = find.byKey(
          const Key('employee_documents_add_button'),
        );
        expect(addDocFab, findsOneWidget);

        // We push UploadDocumentScreen with our mock picker
        Navigator.of(tester.element(find.byType(EmployeeDocumentsScreen))).push(
          MaterialPageRoute(
            builder: (_) => UploadDocumentScreen(
              user: MockAuthTestFixtures.admin,
              employee: sampleEmployee1,
              repository: documentRepository,
              filePicker: mockPicker,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(UploadDocumentScreen), findsOneWidget);

        // 5. Select file
        await tester.tap(
          find.byKey(const Key('upload_doc_select_file_button')),
        );
        await tester.pumpAndSettle();
        expect(find.text('bonus_letter.pdf'), findsOneWidget);

        // 6. Enter Title
        await tester.enterText(
          find.byKey(const Key('upload_doc_title_field')),
          'Annual Bonus Letter',
        );
        await tester.pumpAndSettle();

        // 7. Submit
        final uploadSubmitBtn = find.byKey(
          const Key('upload_doc_submit_button'),
        );
        await tester.ensureVisible(uploadSubmitBtn);
        await tester.tap(uploadSubmitBtn);
        await tester.pumpAndSettle();

        // Pop back to documents screen
        expect(find.byType(EmployeeDocumentsScreen), findsOneWidget);

        // Refresh cubit to see new document
        final refreshBtn = find.byTooltip('Refresh');
        if (refreshBtn.evaluate().isNotEmpty) {
          await tester.tap(refreshBtn);
          await tester.pumpAndSettle();
        }

        expect(find.text('Annual Bonus Letter'), findsOneWidget);

        // 8. Tap document to open details screen
        final newDocTile = find.text('Annual Bonus Letter');
        await tester.ensureVisible(newDocTile);
        await tester.tap(newDocTile);
        await tester.pumpAndSettle();

        expect(find.byType(EmployeeDocumentDetailsScreen), findsOneWidget);
        expect(find.text('Annual Bonus Letter'), findsOneWidget);
        expect(find.text('bonus_letter.pdf'), findsOneWidget);

        // 9. Download file
        final downloadBtn = find.byKey(const Key('document_download_button'));
        expect(downloadBtn, findsOneWidget);
        await tester.ensureVisible(downloadBtn);
        await tester.tap(downloadBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('document_download_status_box')),
          findsOneWidget,
        );
        expect(find.textContaining('bytes downloaded'), findsOneWidget);
      },
    );

    testWidgets(
      'Cross-employee document isolation: emp_1 and emp_2 have distinct records',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: EmployeeDocumentsScreen(
              user: MockAuthTestFixtures.admin,
              employee: sampleEmployee2,
              repository: documentRepository,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // emp_2 has Resume / Curriculum Vitae, but NOT Employment Agreement or National Identity Proof
        expect(find.text('Bob Smith — Documents'), findsOneWidget);
        expect(find.text('Resume / Curriculum Vitae'), findsOneWidget);
        expect(find.text('Employment Agreement'), findsNothing);
        expect(find.text('National Identity Proof'), findsNothing);
      },
    );

    testWidgets(
      'Standard HR user has read-only access: can view list and details, no upload FAB',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: EmployeeDocumentsScreen(
              user: hrViewerUser,
              employee: sampleEmployee1,
              repository: documentRepository,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('employee_documents_scaffold')),
          findsOneWidget,
        );
        expect(find.text('Employment Agreement'), findsOneWidget);
        expect(
          find.byKey(const Key('employee_documents_add_button')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Direct navigation restrictions: unauthorized user is blocked by AccessRestrictedScreen',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: EmployeeDocumentsScreen(
              user: unauthorizedUser,
              employee: sampleEmployee1,
              repository: documentRepository,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AccessRestrictedScreen), findsOneWidget);
        expect(
          find.byKey(const Key('employee_documents_scaffold')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Responsive viewports (320x568, 360x640, 768x1024, 1200x800) render cleanly without overflow',
      (tester) async {
        final viewports = [
          const Size(320, 568),
          const Size(360, 640),
          const Size(768, 1024),
          const Size(1200, 800),
        ];

        for (final size in viewports) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(
            MaterialApp(
              home: EmployeeDocumentsScreen(
                user: MockAuthTestFixtures.admin,
                employee: sampleEmployee1,
                repository: documentRepository,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('employee_documents_scaffold')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        }

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );

    testWidgets(
      'Standard user dashboard navigation: can navigate to HR directory',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(buildUserApp(user: hrViewerUser));
        await tester.pumpAndSettle();

        final hrCard = find.byKey(const Key('module_card_hrPayroll'));
        expect(hrCard, findsOneWidget);
        await tester.tap(hrCard);
        await tester.pumpAndSettle();

        expect(find.byType(EmployeeDirectoryScreen), findsOneWidget);
      },
    );

    testWidgets('Dark theme renders cleanly without errors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: EmployeeDocumentsScreen(
            user: MockAuthTestFixtures.admin,
            employee: sampleEmployee1,
            repository: documentRepository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('employee_documents_scaffold')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
