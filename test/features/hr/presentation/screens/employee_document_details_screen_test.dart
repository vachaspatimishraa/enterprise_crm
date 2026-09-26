import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/hr/data/repositories/mock_employee_document_repository.dart';
import 'package:enterprise_crm/features/hr/domain/entities/employee.dart';
import 'package:enterprise_crm/features/hr/domain/entities/employee_document.dart';
import 'package:enterprise_crm/features/hr/domain/entities/employment_status.dart';
import 'package:enterprise_crm/features/hr/presentation/screens/employee_document_details_screen.dart';
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

  final sampleDocument = EmployeeDocument(
    id: 'doc_1',
    employeeId: 'emp_1',
    title: 'Employment Agreement',
    fileName: 'employment_agreement.pdf',
    fileExtension: 'pdf',
    fileSizeBytes: 1024 * 1024,
    documentType: 'Contract',
    uploadedAt: DateTime.utc(2023, 1, 15),
    uploadedBy: 'usr_admin',
    fileReference: 'file_ref_mock_001',
  );

  setUp(() {
    repository = MockEmployeeDocumentRepository();
  });

  Widget buildTestWidget({required CurrentUser user, EmployeeDocument? doc}) {
    return MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(800, 1200)),
        child: EmployeeDocumentDetailsScreen(
          user: user,
          employee: sampleEmployee,
          document: doc ?? sampleDocument,
          repository: repository,
        ),
      ),
    );
  }

  group('EmployeeDocumentDetailsScreen Tests', () {
    testWidgets('unauthorized user sees AccessRestrictedScreen', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(user: unauthorizedUser));
      await tester.pumpAndSettle();

      expect(find.text('Access Restricted'), findsOneWidget);
      expect(
        find.byKey(const Key('employee_document_details_scaffold')),
        findsNothing,
      );
    });

    testWidgets('authorized user sees document details and metadata', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(user: adminUser));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('employee_document_details_scaffold')),
        findsOneWidget,
      );
      expect(find.text('Employment Agreement'), findsOneWidget);
      expect(find.text('employment_agreement.pdf'), findsOneWidget);
      expect(find.text('Contract'), findsOneWidget);
      expect(find.text('1.0 MB'), findsOneWidget);
      expect(find.byKey(const Key('document_download_button')), findsOneWidget);
    });

    testWidgets(
      'tapping download button downloads bytes and shows success snackbar',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(user: adminUser));
        await tester.pumpAndSettle();

        final downloadBtn = find.byKey(const Key('document_download_button'));
        await tester.ensureVisible(downloadBtn);
        await tester.tap(downloadBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('document_download_success_snackbar')),
          findsOneWidget,
        );
        expect(
          find.text('Downloaded employment_agreement.pdf'),
          findsOneWidget,
        );
      },
    );
  });
}
