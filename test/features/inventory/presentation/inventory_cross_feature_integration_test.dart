import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_export_artifact.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_import_models.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_query.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/stock_movement_type.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/adjust_inventory_stock_input.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/create_inventory_item_input.dart';
import 'package:enterprise_crm/features/inventory/domain/inputs/record_opening_stock_input.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_export_data_loader.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('INVENTORY-FINAL-QA-1: Cross-Feature Integration Workflows', () {
    late MockInventoryRepository repository;
    final adminUser = const CurrentUser(
      id: 'admin',
      displayName: 'Administrator',
      accountType: AccountType.admin,
      modules: {CrmModule.inventory},
      permissions: {},
    );

    setUp(() {
      repository = MockInventoryRepository(
        nowProvider: () => DateTime.utc(2026, 10, 3, 12, 0, 0),
      );
    });

    test('Flow 1: Item Creation to Listing reflects in repository query', () async {
      final created = await repository.createItem(
        const CreateInventoryItemInput(
          name: 'Quantum Keyboard',
          sku: 'KB-QNT-01',
          openingStock: null,
        ),
      );
      expect(created.item.name, 'Quantum Keyboard');

      final page = await repository.getItems(
        const InventoryQuery(page: 1, pageSize: 50),
      );
      final match = page.items.where((s) => s.item.id == created.item.id);
      expect(match, isNotEmpty);
      expect(match.first.item.sku, 'KB-QNT-01');
      expect(match.first.quantityOnHand, 0.0);
    });

    test('Flow 2: Opening Stock updates Current Quantity and Movement History', () async {
      final created = await repository.createItem(
        const CreateInventoryItemInput(
          name: 'Ergonomic Desk',
          sku: 'DSK-ERG-01',
        ),
      );

      await repository.recordOpeningStock(
        RecordOpeningStockInput(
          itemId: created.item.id,
          quantity: 15.0,
          performedByUserId: adminUser.id,
        ),
      );

      final summary = await repository.getItemById(created.item.id);
      expect(summary?.quantityOnHand, 15.0);

      final history = await repository.getStockMovements(created.item.id);
      expect(history, hasLength(1));
      expect(history.first.movement.type, StockMovementType.openingStock);
      expect(history.first.movement.quantityDelta, 15.0);
      expect(history.first.runningBalance, 15.0);
      expect(history.first.movement.performedByUserId, 'admin');
    });

    test('Flow 3 & Flow 7: Stock Adjustment to Export and History Consistency', () async {
      final created = await repository.createItem(
        const CreateInventoryItemInput(
          name: 'Trackball Mouse',
          sku: 'MOU-TRK-01',
          openingStock: 20.0,
          performedByUserId: 'admin',
        ),
      );

      // Adjust quantity: increase by 5
      await repository.adjustStock(
        AdjustInventoryStockInput(
          itemId: created.item.id,
          quantityDelta: 5.0,
          reason: 'Received return shipment',
          performedByUserId: adminUser.id,
        ),
      );

      // Verify listing quantity
      final summary = await repository.getItemById(created.item.id);
      expect(summary?.quantityOnHand, 25.0);

      // Verify history
      final history = await repository.getStockMovements(created.item.id);
      expect(history, hasLength(2));
      expect(history.first.movement.type, StockMovementType.adjustment);
      expect(history.first.movement.quantityDelta, 5.0);
      expect(history.first.runningBalance, 25.0);
      expect(history.first.movement.reason, 'Received return shipment');

      // Verify Export captures 25.0
      final loader = InventoryExportDataLoader(repository);
      final exportService = InventoryExportService(dataLoader: loader);
      final artifact = await exportService.prepareExport(
        format: InventoryExportFormat.csv,
        initialUser: adminUser,
        currentUserProvider: () => adminUser,
      );

      final csvText = String.fromCharCodes(artifact.bytes);
      expect(csvText, contains('MOU-TRK-01'));
      expect(csvText, contains('Trackball Mouse'));
      expect(csvText, contains('25'));
    });

    test('Flow 4: Import to Listing adds new items and reflects in query', () async {
      final importReq = const InventoryImportRequest(
        performedByUserId: 'admin',
        rows: [
          InventoryImportRowInput(
            sourceRowNumber: 2,
            name: 'Imported Monitor Stand',
            sku: 'IMP-MNT-99',
            openingStock: 12.0,
          ),
        ],
      );

      final result = await repository.importItems(importReq);
      expect(result.successCount, 1);

      final page = await repository.getItems(
        const InventoryQuery(page: 1, pageSize: 50),
      );
      final imported = page.items.where((s) => s.item.sku == 'IMP-MNT-99');
      expect(imported, isNotEmpty);
      expect(imported.first.quantityOnHand, 12.0);
    });

    test('Flow 5 & Flow 6: Delete to Export exclusion and Undo to Export inclusion', () async {
      final created = await repository.createItem(
        const CreateInventoryItemInput(
          name: 'Temporary Item',
          sku: 'TMP-DEL-01',
          openingStock: 10.0,
          performedByUserId: 'admin',
        ),
      );

      final loader = InventoryExportDataLoader(repository);

      // Verify initially present in export dataset
      var items = await loader.loadAllItems();
      expect(items.any((s) => s.item.id == created.item.id), isTrue);

      // Mark for deletion
      await repository.requestItemDeletion(
        itemId: created.item.id,
        performedByUserId: adminUser.id,
      );

      // Flow 5: Item must be excluded from Export
      items = await loader.loadAllItems();
      expect(items.any((s) => s.item.id == created.item.id), isFalse);

      // Flow 6: Undo deletion within 60-second window
      await repository.undoItemDeletion(
        itemId: created.item.id,
        performedByUserId: adminUser.id,
      );

      // Restored item must be included in Export again
      items = await loader.loadAllItems();
      expect(items.any((s) => s.item.id == created.item.id), isTrue);
      expect(items.firstWhere((s) => s.item.id == created.item.id).quantityOnHand, 10.0);
    });
  });
}
