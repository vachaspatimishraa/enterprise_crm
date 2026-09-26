import 'dart:typed_data';

import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/auth/presentation/screens/access_restricted_screen.dart';
import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_import_models.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/inventory_import_screen.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_import_file_picker.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_import_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFilePicker implements InventoryImportFilePicker {
  _FakeFilePicker(this.file);
  final InventoryImportSelectedFile? file;

  @override
  Future<InventoryImportSelectedFile?> pickFile() async => file;
}

class _FakeParser implements InventoryImportParser {
  _FakeParser(this.parsed);
  final InventoryImportParsedFile parsed;

  @override
  Future<InventoryImportParsedFile> parse(
    InventoryImportSelectedFile file,
  ) async => parsed;
}

void main() {
  group('InventoryImportScreen UI', () {
    late CurrentUser adminUser;
    late CurrentUser standardUser;
    late MockInventoryRepository repository;

    setUp(() {
      adminUser = CurrentUser(
        id: 'admin_1',
        displayName: 'Administrator',
        accountType: AccountType.admin,
        modules: {CrmModule.inventory},
        permissions: {CrmPermissions.inventoryView},
      );
      standardUser = CurrentUser(
        id: 'user_1',
        displayName: 'Standard User',
        accountType: AccountType.user,
        modules: {CrmModule.inventory},
        permissions: {CrmPermissions.inventoryView},
      );
      repository = MockInventoryRepository();
    });

    testWidgets(
      'unauthorized user gets AccessRestrictedScreen with zero interaction',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: InventoryImportScreen(
              user: standardUser,
              repository: repository,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AccessRestrictedScreen), findsOneWidget);
        expect(
          find.byKey(const Key('inventory_import_select_file_button')),
          findsNothing,
        );
      },
    );

    testWidgets('authorized admin renders file picker initial view', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: InventoryImportScreen(user: adminUser, repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AccessRestrictedScreen), findsNothing);
      expect(find.text('Import Inventory'), findsOneWidget);
      expect(
        find.byKey(const Key('inventory_import_select_file_button')),
        findsOneWidget,
      );
      expect(find.text('Upload Inventory File'), findsOneWidget);
    });

    testWidgets('full import flow from file selection to success result view', (
      tester,
    ) async {
      final selectedFile = InventoryImportSelectedFile(
        name: 'test_inventory.csv',
        extension: 'csv',
        sizeBytes: 120,
        bytes: Uint8List(12),
      );
      const parsedFile = InventoryImportParsedFile(
        fileName: 'test_inventory.csv',
        fileType: InventoryImportFileType.csv,
        sheets: [
          InventoryImportParsedSheet(
            name: 'CSV',
            rows: [
              ['Item Name', 'Product SKU', 'Qty'],
              ['Bolt M6', 'SKU-BOLT-01', '100'],
              ['Nut M6', 'SKU-NUT-01', ''],
            ],
          ),
        ],
      );

      final fakePicker = _FakeFilePicker(selectedFile);
      final fakeParser = _FakeParser(parsedFile);

      await tester.pumpWidget(
        MaterialApp(
          home: InventoryImportScreen(
            user: adminUser,
            repository: repository,
            filePicker: fakePicker,
            parser: fakeParser,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Click Select File
      await tester.tap(
        find.byKey(const Key('inventory_import_select_file_button')),
      );
      await tester.pumpAndSettle();

      // 2. We are now on Header Selection
      expect(
        find.byKey(const Key('inventory_import_confirm_header_button')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('inventory_import_confirm_header_button')),
      );
      await tester.pumpAndSettle();

      // 3. We are now on Column Mapping
      expect(
        find.byKey(const Key('inventory_import_confirm_mapping_button')),
        findsOneWidget,
      );

      // Try confirming mapping without selecting required fields
      await tester.tap(
        find.byKey(const Key('inventory_import_confirm_mapping_button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('inventory_import_mapping_error')),
        findsOneWidget,
      );

      // Select Name column (Col 1)
      await tester.tap(
        find.byKey(const Key('inventory_import_map_name_dropdown')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Col 1: Item Name').last);
      await tester.pumpAndSettle();

      // Select SKU column (Col 2)
      await tester.tap(
        find.byKey(const Key('inventory_import_map_sku_dropdown')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Col 2: Product SKU').last);
      await tester.pumpAndSettle();

      // Select Opening Stock column (Col 3)
      await tester.tap(
        find.byKey(const Key('inventory_import_map_opening_stock_dropdown')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Col 3: Qty').last);
      await tester.pumpAndSettle();

      // Confirm mapping -> Transitions to Preview
      await tester.tap(
        find.byKey(const Key('inventory_import_confirm_mapping_button')),
      );
      await tester.pumpAndSettle();

      // 4. Preview Screen
      expect(
        find.byKey(const Key('inventory_import_summary_total')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('inventory_import_submit_button')),
        findsOneWidget,
      );

      // Submit import
      await tester.tap(find.byKey(const Key('inventory_import_submit_button')));
      await tester.pumpAndSettle();

      // 5. Result Screen
      expect(
        find.byKey(const Key('inventory_import_result_title')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('inventory_import_done_button')),
        findsOneWidget,
      );
      expect(find.text('Imported: 2 | Failed: 0'), findsOneWidget);
    });
  });
}
