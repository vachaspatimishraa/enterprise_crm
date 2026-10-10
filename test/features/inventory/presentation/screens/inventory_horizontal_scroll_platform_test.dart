import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/inventory_workspace_screen.dart';

void main() {
  group('InventoryWorkspaceScreen - Platform Scroll & Removal of Bulk Entry Tests', () {
    final adminUser = CurrentUser(
      id: 'usr_admin',
      displayName: 'Admin User',
      accountType: AccountType.admin,
      modules: {CrmModule.inventory},
      permissions: {
        CrmPermissions.inventoryView,
        CrmPermissions.inventoryCreate,
      },
    );

    testWidgets('shows horizontal scroll bar and Add Item on desktop/web, with no bulk entry', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = MockInventoryRepository();

        await tester.pumpWidget(
          MaterialApp(
            home: InventoryWorkspaceScreen(user: adminUser, repository: repo),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('inventory_items_table')), findsOneWidget);
        expect(find.byKey(const Key('inventory_horizontal_scroll_bar')), findsOneWidget);
        expect(find.byKey(const Key('inventory_scroll_start_button')), findsOneWidget);
        expect(find.byKey(const Key('inventory_scroll_left_button')), findsOneWidget);
        expect(find.byKey(const Key('inventory_horizontal_scroll_slider')), findsOneWidget);
        expect(find.byKey(const Key('inventory_scroll_right_button')), findsOneWidget);
        expect(find.byKey(const Key('inventory_scroll_end_button')), findsOneWidget);
        expect(find.byKey(const Key('inventory_workspace_add_item_button')), findsOneWidget);
        expect(find.byKey(const Key('inventory_workspace_bulk_entry_button')), findsNothing);
        expect(find.byKey(const Key('inventory_workspace_bulk_entry_appbar_button')), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('omits horizontal scroll bar and bulk entry on Android APK', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = MockInventoryRepository();

        await tester.pumpWidget(
          MaterialApp(
            home: InventoryWorkspaceScreen(user: adminUser, repository: repo),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('inventory_items_table')), findsOneWidget);
        expect(find.byKey(const Key('inventory_horizontal_scroll_bar')), findsNothing);
        expect(find.byKey(const Key('inventory_scroll_start_button')), findsNothing);
        expect(find.byKey(const Key('inventory_scroll_left_button')), findsNothing);
        expect(find.byKey(const Key('inventory_horizontal_scroll_slider')), findsNothing);
        expect(find.byKey(const Key('inventory_scroll_right_button')), findsNothing);
        expect(find.byKey(const Key('inventory_scroll_end_button')), findsNothing);
        expect(find.byKey(const Key('inventory_workspace_bulk_entry_button')), findsNothing);
        expect(find.byKey(const Key('inventory_workspace_bulk_entry_appbar_button')), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('bulk entry is not present on mobile/compact view', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = MockInventoryRepository();

        await tester.pumpWidget(
          MaterialApp(
            home: InventoryWorkspaceScreen(user: adminUser, repository: repo),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('inventory_workspace_add_item_button')), findsOneWidget);
        expect(find.byKey(const Key('inventory_workspace_bulk_entry_button')), findsNothing);
        expect(find.byKey(const Key('inventory_workspace_bulk_entry_appbar_button')), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
