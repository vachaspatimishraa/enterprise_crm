import 'dart:convert';
import 'dart:typed_data';

import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/hr/data/repositories/mock_employee_document_repository.dart';
import 'package:enterprise_crm/features/hr/domain/entities/employee.dart';
import 'package:enterprise_crm/features/hr/domain/entities/employment_status.dart';
import 'package:enterprise_crm/features/hr/presentation/screens/upload_document_screen.dart';
import 'package:enterprise_crm/features/hr/presentation/services/employee_document_file_picker.dart';
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

  final sampleEmployee = Employee(
    id: 'emp_1',
    employeeCode: 'EMP-001',
    fullName: 'Alice Johnson',
    department: 'Human Resources',
    designation: 'HR Manager',
    employmentStatus: EmploymentStatus.active,
  );

  final samplePickedFile = EmployeeDocumentPickedFile(
    name: 'test_contract.pdf',
    extension: 'pdf',
    sizeBytes: 1024 * 200,
    bytes: Uint8List.fromList(utf8.encode('Sample document bytes')),
  );

  setUp(() {
    repository = MockEmployeeDocumentRepository();
  });

  Widget buildTestWidget({
    required CurrentUser user,
    EmployeeDocumentFilePicker? filePicker,
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(800, 1200)),
        child: UploadDocumentScreen(
          user: user,
          employee: sampleEmployee,
          repository: repository,
          filePicker: filePicker,
        ),
      ),
    );
  }

  group('UploadDocumentScreen Tests', () {
    testWidgets('non-admin user is blocked with AccessRestrictedScreen', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(user: hrStandardUser));
      await tester.pumpAndSettle();

      expect(find.text('Access Restricted'), findsOneWidget);
      expect(find.byKey(const Key('upload_document_scaffold')), findsNothing);
    });

    testWidgets('admin user sees upload form', (tester) async {
      await tester.pumpWidget(buildTestWidget(user: adminUser));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('upload_document_scaffold')), findsOneWidget);
      expect(find.text('Upload Document — Alice Johnson'), findsOneWidget);
      expect(
        find.byKey(const Key('upload_doc_select_file_button')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('upload_doc_title_field')), findsOneWidget);
      expect(find.byKey(const Key('upload_doc_type_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('upload_doc_submit_button')), findsOneWidget);
    });

    testWidgets('validation rejects submission without selecting a file', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(user: adminUser));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('upload_doc_title_field')),
        'Valid Document Title',
      );

      final submitBtn = find.byKey(const Key('upload_doc_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Please select a file to upload.'), findsOneWidget);
    });

    testWidgets('validation rejects submission with empty title', (
      tester,
    ) async {
      final mockPicker = MockEmployeeDocumentFilePicker(
        cannedFile: samplePickedFile,
      );
      await tester.pumpWidget(
        buildTestWidget(user: adminUser, filePicker: mockPicker),
      );
      await tester.pumpAndSettle();

      // Pick file
      await tester.tap(find.byKey(const Key('upload_doc_select_file_button')));
      await tester.pumpAndSettle();

      // Clear title
      await tester.enterText(
        find.byKey(const Key('upload_doc_title_field')),
        '',
      );

      final submitBtn = find.byKey(const Key('upload_doc_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Please enter a document title.'), findsOneWidget);
    });

    testWidgets('successful upload persists document to repository', (
      tester,
    ) async {
      final mockPicker = MockEmployeeDocumentFilePicker(
        cannedFile: samplePickedFile,
      );
      await tester.pumpWidget(
        buildTestWidget(user: adminUser, filePicker: mockPicker),
      );
      await tester.pumpAndSettle();

      // Pick file
      await tester.tap(find.byKey(const Key('upload_doc_select_file_button')));
      await tester.pumpAndSettle();

      expect(find.text('test_contract.pdf'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('upload_doc_title_field')),
        'Master Consulting Agreement',
      );

      final submitBtn = find.byKey(const Key('upload_doc_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      final docs = await repository.getDocumentsForEmployee('emp_1');
      expect(docs.any((d) => d.title == 'Master Consulting Agreement'), isTrue);
    });

    testWidgets('rejects oversized file selection (> 10MB)', (tester) async {
      final oversizedFile = EmployeeDocumentPickedFile(
        name: 'huge_file.pdf',
        extension: 'pdf',
        sizeBytes: 15 * 1024 * 1024, // 15 MB
        bytes: Uint8List(100),
      );
      final mockPicker = MockEmployeeDocumentFilePicker(
        cannedFile: oversizedFile,
      );

      await tester.pumpWidget(
        buildTestWidget(user: adminUser, filePicker: mockPicker),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('upload_doc_select_file_button')));
      await tester.pumpAndSettle();

      expect(
        find.text('Selected file exceeds the maximum 10 MB limit.'),
        findsOneWidget,
      );
    });
  });
}
