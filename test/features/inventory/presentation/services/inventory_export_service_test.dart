import 'dart:convert';
import 'package:enterprise_crm/features/inventory/domain/entities/custom_field_definition.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_export_fields.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_query.dart';
import 'package:enterprise_crm/features/inventory/domain/policies/inventory_field_access_policy.dart';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_export_artifact.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_page.dart';
import 'package:enterprise_crm/features/inventory/domain/policies/inventory_export_policy.dart';
import 'package:enterprise_crm/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_export_data_loader.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_export_service.dart';

class _CustomRepo implements InventoryRepository {
  _CustomRepo(this._handler);
  final Future<InventoryPage> Function(InventoryQuery) _handler;
  int readCallCount = 0;
  @override
  Future<InventoryPage> getItems(InventoryQuery query) {
    readCallCount++;
    return _handler(query);
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  CurrentUser makeUser({
    String id = 'user_1',
    AccountType type = AccountType.user,
    Set<CrmModule>? modules,
    Set<String>? permissions,
  }) {
    return CurrentUser(
      id: id,
      displayName: 'Test User',
      accountType: type,
      modules: modules ?? {CrmModule.inventory},
      permissions: permissions ?? {
        CrmPermissions.inventoryView,
        CrmPermissions.inventoryExportCsv,
        CrmPermissions.inventoryExportXlsx,
        InventoryExportPolicy.exportPdfPermission,
      },
    );
  }

  group('InventoryExportService Unit Tests', () {
    late MockInventoryRepository mockRepo;
    late InventoryExportDataLoader dataLoader;
    late InventoryExportService exportService;

    setUp(() {
      mockRepo = MockInventoryRepository();
      dataLoader = InventoryExportDataLoader(mockRepo);
      exportService = InventoryExportService(dataLoader: dataLoader);
    });

    test('prepares valid CSV export artifact for authorized user', () async {
      final user = makeUser();
      final artifact = await exportService.prepareExport(
        format: InventoryExportFormat.csv,
        initialUser: user,
        currentUserProvider: () => user,
      );

      expect(artifact.format, equals(InventoryExportFormat.csv));
      expect(artifact.bytes, isA<Uint8List>());
      expect(artifact.bytes.isNotEmpty, isTrue);
      expect(artifact.itemCount, equals(25));
      expect(artifact.fileExtension, equals('.csv'));
      expect(artifact.mimeType, equals('text/csv'));
    });

    test('prepares valid XLSX export artifact for authorized user', () async {
      final user = makeUser();
      final artifact = await exportService.prepareExport(
        format: InventoryExportFormat.xlsx,
        initialUser: user,
        currentUserProvider: () => user,
      );

      expect(artifact.format, equals(InventoryExportFormat.xlsx));
      expect(artifact.bytes, isA<Uint8List>());
      expect(artifact.bytes.isNotEmpty, isTrue);
      expect(artifact.itemCount, equals(25));
      expect(artifact.fileExtension, equals('.xlsx'));
      expect(artifact.mimeType, contains('spreadsheetml.sheet'));
    });

    test('prepares valid PDF export artifact using the same dataset', () async {
      final user = makeUser();
      final artifact = await exportService.prepareExport(
        format: InventoryExportFormat.pdf,
        initialUser: user,
        currentUserProvider: () => user,
      );

      expect(artifact.format, equals(InventoryExportFormat.pdf));
      expect(artifact.bytes, isA<Uint8List>());
      expect(artifact.bytes.sublist(0, 4), equals([37, 80, 68, 70]));
      expect(artifact.itemCount, equals(25));
      expect(artifact.fileExtension, equals('.pdf'));
      expect(artifact.mimeType, equals('application/pdf'));
    });

    test('rejects initial request before loading if user lacks format permission', () async {
      final userWithoutCsv = makeUser(
        permissions: {
          CrmPermissions.inventoryView,
          CrmPermissions.inventoryExportXlsx,
          InventoryExportPolicy.exportPdfPermission,
        },
      );

      expect(
        () => exportService.prepareExport(
          format: InventoryExportFormat.csv,
          initialUser: userWithoutCsv,
          currentUserProvider: () => userWithoutCsv,
        ),
        throwsA(isA<InventoryExportException>().having(
          (e) => e.message,
          'message',
          contains('not authorized'),
        )),
      );
    });

    test('PDF security: CSV-only user cannot export PDF (zero repository reads)', () async {
      final customRepo = _CustomRepo((q) async => const InventoryPage(
        items: [],
        currentPage: 1,
        pageSize: 10,
        totalItems: 0,
        hasNext: false,
      ));
      final service = InventoryExportService(dataLoader: InventoryExportDataLoader(customRepo));
      final userWithCsvOnly = makeUser(
        permissions: {
          CrmPermissions.inventoryView,
          CrmPermissions.inventoryExportCsv,
        },
      );

      await expectLater(
        () => service.prepareExport(
          format: InventoryExportFormat.pdf,
          initialUser: userWithCsvOnly,
          currentUserProvider: () => userWithCsvOnly,
        ),
        throwsA(isA<InventoryExportException>().having(
          (e) => e.message,
          'message',
          contains('not authorized'),
        )),
      );
      expect(customRepo.readCallCount, equals(0));
    });

    test('PDF security: XLSX-only user cannot export PDF (zero repository reads)', () async {
      final customRepo = _CustomRepo((q) async => const InventoryPage(
        items: [],
        currentPage: 1,
        pageSize: 10,
        totalItems: 0,
        hasNext: false,
      ));
      final service = InventoryExportService(dataLoader: InventoryExportDataLoader(customRepo));
      final userWithXlsxOnly = makeUser(
        permissions: {
          CrmPermissions.inventoryView,
          CrmPermissions.inventoryExportXlsx,
        },
      );

      await expectLater(
        () => service.prepareExport(
          format: InventoryExportFormat.pdf,
          initialUser: userWithXlsxOnly,
          currentUserProvider: () => userWithXlsxOnly,
        ),
        throwsA(isA<InventoryExportException>().having(
          (e) => e.message,
          'message',
          contains('not authorized'),
        )),
      );
      expect(customRepo.readCallCount, equals(0));
    });

    test('PDF security: user without Inventory module cannot export PDF', () async {
      final userWithoutModule = makeUser(
        modules: {CrmModule.leadManagement},
        permissions: {
          CrmPermissions.inventoryView,
          InventoryExportPolicy.exportPdfPermission,
        },
      );

      expect(
        () => exportService.prepareExport(
          format: InventoryExportFormat.pdf,
          initialUser: userWithoutModule,
          currentUserProvider: () => userWithoutModule,
        ),
        throwsA(isA<InventoryExportException>().having(
          (e) => e.message,
          'message',
          contains('not authorized'),
        )),
      );
    });

    test('PDF security: user without inventory.view cannot export PDF', () async {
      final userWithoutView = makeUser(
        permissions: {
          InventoryExportPolicy.exportPdfPermission,
        },
      );

      expect(
        () => exportService.prepareExport(
          format: InventoryExportFormat.pdf,
          initialUser: userWithoutView,
          currentUserProvider: () => userWithoutView,
        ),
        throwsA(isA<InventoryExportException>().having(
          (e) => e.message,
          'message',
          contains('not authorized'),
        )),
      );
    });

    test('throws if user session expires (null) during asynchronous loading', () async {
      final user = makeUser();
      var isFirstCall = true;

      final dynamicLoader = InventoryExportDataLoader(_CustomRepo((q) async {
        return const InventoryPage(
          items: [],
          currentPage: 1,
          pageSize: 10,
          totalItems: 0,
          hasNext: false,
        );
      }));
      final service = InventoryExportService(dataLoader: dynamicLoader);

      expect(
        () => service.prepareExport(
          format: InventoryExportFormat.csv,
          initialUser: user,
          currentUserProvider: () {
            if (isFirstCall) {
              isFirstCall = false;
              return null; // Expired / logged out
            }
            return null;
          },
        ),
        throwsA(isA<InventoryExportException>().having(
          (e) => e.message,
          'message',
          contains('session expired'),
        )),
      );
    });

    test('throws if user identity changes during asynchronous loading', () async {
      final initialUser = makeUser(id: 'user_A');
      final switchedUser = makeUser(id: 'user_B');

      final dynamicLoader = InventoryExportDataLoader(_CustomRepo((q) async {
        return const InventoryPage(
          items: [],
          currentPage: 1,
          pageSize: 10,
          totalItems: 0,
          hasNext: false,
        );
      }));
      final service = InventoryExportService(dataLoader: dynamicLoader);

      expect(
        () => service.prepareExport(
          format: InventoryExportFormat.csv,
          initialUser: initialUser,
          currentUserProvider: () => switchedUser,
        ),
        throwsA(isA<InventoryExportException>().having(
          (e) => e.message,
          'message',
          contains('identity changed'),
        )),
      );
    });

    test('throws if permission revoked during asynchronous loading', () async {
      final initialUser = makeUser(
        permissions: {
          CrmPermissions.inventoryView,
          CrmPermissions.inventoryExportCsv,
        },
      );
      final revokedUser = makeUser(
        permissions: {
          CrmPermissions.inventoryView, // CSV export permission stripped
        },
      );

      final dynamicLoader = InventoryExportDataLoader(_CustomRepo((q) async {
        return const InventoryPage(
          items: [],
          currentPage: 1,
          pageSize: 10,
          totalItems: 0,
          hasNext: false,
        );
      }));
      final service = InventoryExportService(dataLoader: dynamicLoader);

      expect(
        () => service.prepareExport(
          format: InventoryExportFormat.csv,
          initialUser: initialUser,
          currentUserProvider: () => revokedUser,
        ),
        throwsA(isA<InventoryExportException>().having(
          (e) => e.message,
          'message',
          contains('revoked'),
        )),
      );
    });

    test('PDF security: throws if PDF permission revoked during asynchronous loading', () async {
      final initialUser = makeUser(
        permissions: {
          CrmPermissions.inventoryView,
          InventoryExportPolicy.exportPdfPermission,
        },
      );
      final revokedUser = makeUser(
        permissions: {
          CrmPermissions.inventoryView, // PDF permission stripped
        },
      );

      final dynamicLoader = InventoryExportDataLoader(_CustomRepo((q) async {
        return const InventoryPage(
          items: [],
          currentPage: 1,
          pageSize: 10,
          totalItems: 0,
          hasNext: false,
        );
      }));
      final service = InventoryExportService(dataLoader: dynamicLoader);

      expect(
        () => service.prepareExport(
          format: InventoryExportFormat.pdf,
          initialUser: initialUser,
          currentUserProvider: () => revokedUser,
        ),
        throwsA(isA<InventoryExportException>().having(
          (e) => e.message,
          'message',
          contains('revoked'),
        )),
      );
    });
     group('Customizable Export Service Tests (INVENTORY-7.5)', () {
    late CurrentUser adminUser;

    setUp(() {
      adminUser = makeUser(type: AccountType.admin);
    });
      test('exports all 21 standard fields in requested order for admin', () async {
        final artifact = await exportService.prepareExport(
          format: InventoryExportFormat.csv,
          initialUser: adminUser,
          currentUserProvider: () => adminUser,
          preset: InventoryExportPreset.custom,
          columns: InventoryExportFields.standardFieldKeys,
        );

        expect(artifact.format, equals(InventoryExportFormat.csv));
        expect(artifact.preset, equals(InventoryExportPreset.custom));
        expect(artifact.columns.length, equals(21));
        final csvString = String.fromCharCodes(artifact.bytes);
        final headerLine = csvString.trim().split('\r\n')[0];
        expect(headerLine.split(',').length, equals(21));
      });

      test('exports registered custom fields in CSV and XLSX', () async {
        final customDef = CustomFieldDefinition(
          id: 'cf-batch',
          key: 'cf_grade',
          label: 'Material Grade',
          dataType: CustomFieldDataType.text,
        );

        final artifact = await exportService.prepareExport(
          format: InventoryExportFormat.csv,
          initialUser: adminUser,
          currentUserProvider: () => adminUser,
          preset: InventoryExportPreset.custom,
          columns: ['sku', 'product_name', 'cf_grade'],
          customFieldDefinitions: [customDef],
        );

        expect(artifact.columns, equals(['sku', 'product_name', 'cf_grade']));
        final csvString = String.fromCharCodes(artifact.bytes);
        expect(csvString, contains('Material Grade'));
      });

      test('preserves user-selected column reordering', () async {
        final artifact = await exportService.prepareExport(
          format: InventoryExportFormat.csv,
          initialUser: adminUser,
          currentUserProvider: () => adminUser,
          preset: InventoryExportPreset.custom,
          columns: ['selling_price_inr', 'sku', 'warehouse', 'product_name'],
        );

        final csvString = String.fromCharCodes(artifact.bytes);
        final headerLine = csvString.trim().split('\r\n')[0];
        expect(
          headerLine,
          equals('Selling Price (INR),SKU,Warehouse,Product Name'),
        );
      });

      test('rejects empty column selection in custom preset', () async {
        expect(
          () => exportService.prepareExport(
            format: InventoryExportFormat.csv,
            initialUser: adminUser,
            currentUserProvider: () => adminUser,
            preset: InventoryExportPreset.custom,
            columns: [],
          ),
          throwsA(isA<InventoryExportException>().having(
            (e) => e.message,
            'message',
            contains('No export columns selected.'),
          )),
        );
      });

      test('rejects duplicate column selection in custom preset', () async {
        expect(
          () => exportService.prepareExport(
            format: InventoryExportFormat.csv,
            initialUser: adminUser,
            currentUserProvider: () => adminUser,
            preset: InventoryExportPreset.custom,
            columns: ['sku', 'product_name', 'sku'],
          ),
          throwsA(isA<InventoryExportException>().having(
            (e) => e.message,
            'message',
            contains('Duplicate export columns are not permitted.'),
          )),
        );
      });

      test('rejects unknown column keys', () async {
        expect(
          () => exportService.prepareExport(
            format: InventoryExportFormat.csv,
            initialUser: adminUser,
            currentUserProvider: () => adminUser,
            preset: InventoryExportPreset.custom,
            columns: ['sku', 'unregistered_mystery_col'],
          ),
          throwsA(isA<InventoryExportException>().having(
            (e) => e.message,
            'message',
            contains('Unknown export column: unregistered_mystery_col'),
          )),
        );
      });

      test('rejects restricted field request when standard user lacks permission', () async {
        final standardUser = CurrentUser(
          id: 'std_user_1',
          displayName: 'Standard User',
          accountType: AccountType.user,
          modules: {CrmModule.inventory},
          permissions: {
            CrmPermissions.inventoryView,
            CrmPermissions.inventoryExportCsv,
            // Does not have costViewPermission or supplierViewPermission
          },
        );

        expect(
          () => exportService.prepareExport(
            format: InventoryExportFormat.csv,
            initialUser: standardUser,
            currentUserProvider: () => standardUser,
            preset: InventoryExportPreset.custom,
            columns: ['sku', 'unit_cost_inr'],
          ),
          throwsA(isA<InventoryExportException>().having(
            (e) => e.message,
            'message',
            contains('Unauthorized field requested: unit_cost_inr'),
          )),
        );

        expect(
          () => exportService.prepareExport(
            format: InventoryExportFormat.csv,
            initialUser: standardUser,
            currentUserProvider: () => standardUser,
            preset: InventoryExportPreset.custom,
            columns: ['sku', 'supplier'],
          ),
          throwsA(isA<InventoryExportException>().having(
            (e) => e.message,
            'message',
            contains('Unauthorized field requested: supplier'),
          )),
        );
      });

      test('allows authorized standard user with costViewPermission to export cost', () async {
        final costAuthorizedUser = CurrentUser(
          id: 'cost_user_1',
          displayName: 'Cost User',
          accountType: AccountType.user,
          modules: {CrmModule.inventory},
          permissions: {
            CrmPermissions.inventoryView,
            CrmPermissions.inventoryExportCsv,
            InventoryFieldAccessPolicy.costViewPermission,
          },
        );

        final artifact = await exportService.prepareExport(
          format: InventoryExportFormat.csv,
          initialUser: costAuthorizedUser,
          currentUserProvider: () => costAuthorizedUser,
          preset: InventoryExportPreset.custom,
          columns: ['sku', 'product_name', 'unit_cost_inr'],
        );

        expect(artifact.columns, contains('unit_cost_inr'));
        final csvString = String.fromCharCodes(artifact.bytes);
        expect(csvString, contains('Unit Cost (INR)'));
      });

      test('field authorization revocation during preparation fails closed', () async {
        final initialUser = CurrentUser(
          id: 'user_cost_dyn',
          displayName: 'Dyn User',
          accountType: AccountType.user,
          modules: {CrmModule.inventory},
          permissions: {
            CrmPermissions.inventoryView,
            CrmPermissions.inventoryExportCsv,
            InventoryFieldAccessPolicy.costViewPermission,
          },
        );

        final revokedUser = CurrentUser(
          id: 'user_cost_dyn',
          displayName: 'Dyn User',
          accountType: AccountType.user,
          modules: {CrmModule.inventory},
          permissions: {
            CrmPermissions.inventoryView,
            CrmPermissions.inventoryExportCsv,
            // costViewPermission revoked
          },
        );

        expect(
          () => exportService.prepareExport(
            format: InventoryExportFormat.csv,
            initialUser: initialUser,
            currentUserProvider: () => revokedUser,
            preset: InventoryExportPreset.custom,
            columns: ['sku', 'unit_cost_inr'],
          ),
          throwsA(isA<InventoryExportException>().having(
            (e) => e.message,
            'message',
            contains('Field authorization revoked during export preparation: unit_cost_inr'),
          )),
        );
      });

      test('proves serializer output does not contain unauthorized fields', () async {
        final standardUser = CurrentUser(
          id: 'std_user_safe',
          displayName: 'Safe User',
          accountType: AccountType.user,
          modules: {CrmModule.inventory},
          permissions: {
            CrmPermissions.inventoryView,
            CrmPermissions.inventoryExportCsv,
          },
        );

        final artifact = await exportService.prepareExport(
          format: InventoryExportFormat.csv,
          initialUser: standardUser,
          currentUserProvider: () => standardUser,
          preset: InventoryExportPreset.custom,
          columns: ['sku', 'product_name', 'selling_price_inr'],
        );

        final csvString = String.fromCharCodes(artifact.bytes);
        expect(csvString, isNot(contains('Unit Cost')));
        expect(csvString, isNot(contains('Supplier')));
      });

      test('filtered scope exports only matching records', () async {
        final artifact = await exportService.prepareExport(
          format: InventoryExportFormat.csv,
          initialUser: adminUser,
          currentUserProvider: () => adminUser,
          scope: InventoryExportScope.filtered,
          query: const InventoryQuery(searchText: 'Laptop'),
        );

        expect(artifact.scope, equals(InventoryExportScope.filtered));
        final csvString = String.fromCharCodes(artifact.bytes);
        final lines = csvString.trim().split('\r\n');
        expect(lines.length, greaterThan(1));
        // Verify all rows match widget
        for (var i = 1; i < lines.length; i++) {
          expect(lines[i].toLowerCase(), contains('laptop'));
        }
      });

      test('selected scope exports exactly selected items', () async {
        final allItems = await mockRepo.getItems(const InventoryQuery(pageSize: 5));
        final selectedIds = {allItems.items[0].item.id, allItems.items[1].item.id};

        final artifact = await exportService.prepareExport(
          format: InventoryExportFormat.csv,
          initialUser: adminUser,
          currentUserProvider: () => adminUser,
          scope: InventoryExportScope.selected,
          selectedItemIds: selectedIds,
        );

        expect(artifact.scope, equals(InventoryExportScope.selected));
        expect(artifact.itemCount, equals(2));
      });

      test('selected scope rejects empty selected set', () async {
        expect(
          () => exportService.prepareExport(
            format: InventoryExportFormat.csv,
            initialUser: adminUser,
            currentUserProvider: () => adminUser,
            scope: InventoryExportScope.selected,
            selectedItemIds: {},
          ),
          throwsA(isA<InventoryExportException>().having(
            (e) => e.message,
            'message',
            contains('No items selected for export.'),
          )),
        );
      });

      test('custom PDF export prepares valid PDF artifact with selected columns', () async {
        final artifact = await exportService.prepareExport(
          format: InventoryExportFormat.pdf,
          initialUser: adminUser,
          currentUserProvider: () => adminUser,
          preset: InventoryExportPreset.custom,
          columns: ['sku', 'product_name', 'category', 'unit_cost_inr'],
          scope: InventoryExportScope.all,
        );

        expect(artifact.format, equals(InventoryExportFormat.pdf));
        expect(artifact.mimeType, equals('application/pdf'));
        expect(artifact.fileExtension, equals('.pdf'));
        expect(artifact.columns, equals(['sku', 'product_name', 'category', 'unit_cost_inr']));
        expect(artifact.bytes.length, greaterThan(100));

        final text = ascii.decode(artifact.bytes);
        expect(text, startsWith('%PDF-1.4'));
        expect(text, contains('SKU'));
        expect(text, contains('Product Name'));
        expect(text, contains(r'Unit Cost \(INR\)'));
      });

      test('custom PDF export rejects unauthorized fields for standard user', () async {
        final standardUserWithoutCost = makeUser(
          permissions: {
            CrmPermissions.inventoryView,
            InventoryExportPolicy.exportPdfPermission,
          },
        );

        expect(
          () => exportService.prepareExport(
            format: InventoryExportFormat.pdf,
            initialUser: standardUserWithoutCost,
            currentUserProvider: () => standardUserWithoutCost,
            preset: InventoryExportPreset.custom,
            columns: ['sku', 'unit_cost_inr'],
          ),
          throwsA(isA<InventoryExportException>().having(
            (e) => e.message,
            'message',
            contains('Unauthorized field requested: unit_cost_inr'),
          )),
        );
      });

      test('custom PDF export with filtered scope only exports matching items', () async {
        final artifact = await exportService.prepareExport(
          format: InventoryExportFormat.pdf,
          initialUser: adminUser,
          currentUserProvider: () => adminUser,
          preset: InventoryExportPreset.custom,
          columns: ['sku', 'product_name'],
          scope: InventoryExportScope.filtered,
          query: const InventoryQuery(searchText: 'Laptop'),
        );

        expect(artifact.scope, equals(InventoryExportScope.filtered));
        expect(artifact.itemCount, greaterThan(0));
        final text = ascii.decode(artifact.bytes);
        expect(text, contains(r'Scope: Filtered Results'));
        expect(text, contains('Laptop'));
      });
    });
  });
}