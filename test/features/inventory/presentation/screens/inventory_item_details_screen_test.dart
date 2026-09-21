import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/presentation/screens/inventory_item_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InventoryItemDetailsScreen Widget Tests', () {
    final testUser = CurrentUser(
      id: 'usr_test',
      displayName: 'Test User',
      accountType: AccountType.admin,
      modules: {CrmModule.inventory},
      permissions: {CrmPermissions.inventoryView},
    );

    testWidgets(
      'renders item details card with Name, SKU, and derived Quantity',
      (tester) async {
        final repo = MockInventoryRepository();

        await tester.pumpWidget(
          MaterialApp(
            home: InventoryItemDetailsScreen(
              user: testUser,
              repository: repo,
              itemId: 'item_001',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Inventory Item Details'), findsOneWidget);
        expect(
          find.byKey(const Key('inventory_item_details_card')),
          findsOneWidget,
        );
        expect(find.text('Laptop Stand'), findsOneWidget);
        expect(find.text('SKU: INV-001'), findsOneWidget);
        expect(find.text('25'), findsOneWidget);
      },
    );

    testWidgets('zero-stock item renders quantity 0 cleanly', (tester) async {
      final repo = MockInventoryRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: InventoryItemDetailsScreen(
            user: testUser,
            repository: repo,
            itemId: 'item_003', // seeded with 0 delta
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Wireless Mechanical Keyboard'), findsOneWidget);
      expect(find.text('SKU: INV-003'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets(
      'VERIFIED READ-ONLY: zero write or mutation controls on details screen',
      (tester) async {
        final repo = MockInventoryRepository();

        await tester.pumpWidget(
          MaterialApp(
            home: InventoryItemDetailsScreen(
              user: testUser,
              repository: repo,
              itemId: 'item_001',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Edit'), findsNothing);
        expect(find.text('Delete'), findsNothing);
        expect(find.text('Adjust'), findsNothing);
        expect(find.text('Receive'), findsNothing);
        expect(find.text('Dispatch'), findsNothing);
        expect(find.byIcon(Icons.edit), findsNothing);
        expect(find.byIcon(Icons.delete), findsNothing);
      },
    );

    testWidgets('item not found shows not-found state with back action', (
      tester,
    ) async {
      final repo = MockInventoryRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: InventoryItemDetailsScreen(
            user: testUser,
            repository: repo,
            itemId: 'non_existent_item_id',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inventory_item_not_found')), findsOneWidget);
      expect(find.text('Item not found'), findsOneWidget);
      expect(find.text('Back to Inventory'), findsOneWidget);
    });
  });
}
