import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/inventory_workspace_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('selected workspace rows are available to the export scope', (
    tester,
  ) async {
    const admin = CurrentUser(
      id: 'admin_export_scope',
      displayName: 'Admin',
      accountType: AccountType.admin,
      modules: {CrmModule.inventory},
      permissions: {},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: InventoryWorkspaceScreen(
          user: admin,
          repository: MockInventoryRepository(),
          currentUserProvider: () => admin,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final selection = find.byKey(const Key('inventory_item_select_item_001'));
    expect(selection, findsOneWidget);
    await tester.ensureVisible(selection);
    await tester.tap(selection);
    await tester.tap(
      find.byKey(const Key('inventory_workspace_export_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Selected Records (1 items)'), findsOneWidget);
    expect(
      find.byKey(const Key('inventory_export_scope_selected')),
      findsOneWidget,
    );
  });
}
