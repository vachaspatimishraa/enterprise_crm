import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/inventory/data/repositories/mock_inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_export_artifact.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_page.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_query.dart';
import 'package:enterprise_crm/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_export_data_loader.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_export_service.dart';

class _CustomRepo implements InventoryRepository {
  _CustomRepo(this._handler);
  final Future<InventoryPage> Function(InventoryQuery) _handler;
  @override
  Future<InventoryPage> getItems(InventoryQuery query) => _handler(query);
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

    test('rejects initial request before loading if user lacks format permission', () async {
      final userWithoutCsv = makeUser(
        permissions: {
          CrmPermissions.inventoryView,
          CrmPermissions.inventoryExportXlsx,
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
  });
}
