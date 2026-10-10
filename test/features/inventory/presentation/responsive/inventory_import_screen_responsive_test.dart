import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/inventory_import_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InventoryImportScreen Responsive & Theme Layout Tests', () {
    final user = CurrentUser(
      id: 'admin_1',
      displayName: 'Admin User',
      accountType: AccountType.admin,
      modules: {CrmModule.inventory},
      permissions: {CrmPermissions.inventoryView},
    );

    final viewports = <String, Size>{
      'mobile small (320x568)': const Size(320, 568),
      'mobile standard (360x640)': const Size(360, 640),
      'tablet (768x1024)': const Size(768, 1024),
      'desktop (1200x800)': const Size(1200, 800),
    };

    for (final entry in viewports.entries) {
      testWidgets(
        'InventoryImportScreen renders cleanly at \${entry.key} without overflow',
        (tester) async {
          tester.view.physicalSize = entry.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final repo = MockInventoryRepository();

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.dark(),
              home: InventoryImportScreen(user: user, repository: repo),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Import Inventory'), findsOneWidget);
          expect(
            find.byKey(const Key('inventory_import_select_file_button')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
