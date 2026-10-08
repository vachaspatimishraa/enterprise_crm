import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/presentation/screens/access_restricted_screen.dart';
import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_query.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/inventory_bulk_entry_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const admin = CurrentUser(
    id: 'admin_bulk',
    displayName: 'Inventory Admin',
    accountType: AccountType.admin,
    modules: {CrmModule.inventory},
    permissions: {},
  );

  const viewOnly = CurrentUser(
    id: 'view_only',
    displayName: 'View Only',
    accountType: AccountType.user,
    modules: {CrmModule.inventory},
    permissions: {},
  );

  testWidgets('renders a multi-row, multi-column manual entry grid', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: InventoryBulkEntryScreen(
          user: admin,
          repository: MockInventoryRepository(items: [], movements: []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('inventory_bulk_entry_grid')), findsOneWidget);
    expect(
      find.byKey(const Key('inventory_bulk_entry_0_name')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('inventory_bulk_entry_0_sku')), findsOneWidget);
    expect(
      find.byKey(const Key('inventory_bulk_entry_1_name')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('inventory_bulk_entry_add_row_button')),
      findsOneWidget,
    );
  });

  testWidgets('commits multiple rows through the ledger-safe import boundary', (
    tester,
  ) async {
    final repository = MockInventoryRepository(items: [], movements: []);
    await tester.pumpWidget(
      MaterialApp(
        home: InventoryBulkEntryScreen(user: admin, repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('inventory_bulk_entry_0_name')),
      'Bulk Bolt',
    );
    await tester.enterText(
      find.byKey(const Key('inventory_bulk_entry_0_sku')),
      'BULK-BOLT-001',
    );
    await tester.enterText(
      find.byKey(const Key('inventory_bulk_entry_1_name')),
      'Bulk Nut',
    );
    await tester.enterText(
      find.byKey(const Key('inventory_bulk_entry_1_sku')),
      'BULK-NUT-001',
    );
    await tester.tap(find.byKey(const Key('inventory_bulk_entry_save_button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('inventory_bulk_entry_result')),
      findsOneWidget,
    );
    expect(find.textContaining('Saved 2 row(s)'), findsOneWidget);
    final page = await repository.getItems(const InventoryQuery());
    expect(page.totalItems, 2);
  });

  testWidgets('blocks users without inventory create permission', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: InventoryBulkEntryScreen(
          user: viewOnly,
          repository: MockInventoryRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AccessRestrictedScreen), findsOneWidget);
    expect(find.byKey(const Key('inventory_bulk_entry_grid')), findsNothing);
  });
}
