import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/inventory/domain/policies/inventory_export_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InventoryExportPolicy', () {
    CurrentUser createStandardUser({
      Set<CrmModule>? modules,
      Set<String>? permissions,
    }) {
      return CurrentUser(
        id: 'user_1',
        displayName: 'Standard User',
        accountType: AccountType.user,
        modules: modules ?? {CrmModule.inventory},
        permissions: permissions ?? {},
      );
    }

    final adminUser = const CurrentUser(
      id: 'admin_1',
      displayName: 'Admin User',
      accountType: AccountType.admin,
      modules: {CrmModule.inventory},
      permissions: {CrmPermissions.inventoryView},
    );

    group('Administrator Authorization', () {
      test('1. Authorized Administrator can export CSV', () {
        expect(InventoryExportPolicy.canExportCsv(adminUser), isTrue);
      });

      test('2. Authorized Administrator can export XLSX', () {
        expect(InventoryExportPolicy.canExportXlsx(adminUser), isTrue);
      });

      test('3. Authorized Administrator can export PDF', () {
        expect(InventoryExportPolicy.canExportPdf(adminUser), isTrue);
      });

      test('4. canExport returns true for Administrator', () {
        expect(InventoryExportPolicy.canExport(adminUser), isTrue);
      });
    });

    group('Standard User Authorization Matrix', () {
      test('4. Inventory + View + CSV permits CSV and strictly denies PDF and XLSX', () {
        final user = createStandardUser(
          permissions: {
            CrmPermissions.inventoryView,
            CrmPermissions.inventoryExportCsv,
          },
        );
        expect(InventoryExportPolicy.canExportCsv(user), isTrue);
        expect(InventoryExportPolicy.canExportXlsx(user), isFalse);
        expect(InventoryExportPolicy.canExportPdf(user), isFalse);
        expect(InventoryExportPolicy.canExport(user), isTrue);
      });

      test('5. Inventory + View + XLSX permits XLSX and strictly denies PDF and CSV', () {
        final user = createStandardUser(
          permissions: {
            CrmPermissions.inventoryView,
            CrmPermissions.inventoryExportXlsx,
          },
        );
        expect(InventoryExportPolicy.canExportCsv(user), isFalse);
        expect(InventoryExportPolicy.canExportXlsx(user), isTrue);
        expect(InventoryExportPolicy.canExportPdf(user), isFalse);
        expect(InventoryExportPolicy.canExport(user), isTrue);
      });

      test('6. Inventory + View + PDF permits PDF and strictly denies CSV and XLSX', () {
        final user = createStandardUser(
          permissions: {
            CrmPermissions.inventoryView,
            InventoryExportPolicy.exportPdfPermission,
          },
        );
        expect(InventoryExportPolicy.canExportCsv(user), isFalse);
        expect(InventoryExportPolicy.canExportXlsx(user), isFalse);
        expect(InventoryExportPolicy.canExportPdf(user), isTrue);
        expect(InventoryExportPolicy.canExport(user), isTrue);
      });

      test('7. Inventory + View + all export permissions permits all formats', () {
        final user = createStandardUser(
          permissions: {
            CrmPermissions.inventoryView,
            CrmPermissions.inventoryExportCsv,
            CrmPermissions.inventoryExportXlsx,
            InventoryExportPolicy.exportPdfPermission,
          },
        );
        expect(InventoryExportPolicy.canExportCsv(user), isTrue);
        expect(InventoryExportPolicy.canExportXlsx(user), isTrue);
        expect(InventoryExportPolicy.canExportPdf(user), isTrue);
        expect(InventoryExportPolicy.canExport(user), isTrue);
      });

      test('8. CSV-only permission denies XLSX and PDF', () {
        final user = createStandardUser(
          permissions: {
            CrmPermissions.inventoryView,
            CrmPermissions.inventoryExportCsv,
          },
        );
        expect(InventoryExportPolicy.canExportXlsx(user), isFalse);
        expect(InventoryExportPolicy.canExportPdf(user), isFalse);
      });

      test('9. XLSX-only permission denies CSV and PDF', () {
        final user = createStandardUser(
          permissions: {
            CrmPermissions.inventoryView,
            CrmPermissions.inventoryExportXlsx,
          },
        );
        expect(InventoryExportPolicy.canExportCsv(user), isFalse);
        expect(InventoryExportPolicy.canExportPdf(user), isFalse);
      });

      test('10. PDF-only permission denies CSV and XLSX', () {
        final user = createStandardUser(
          permissions: {
            CrmPermissions.inventoryView,
            InventoryExportPolicy.exportPdfPermission,
          },
        );
        expect(InventoryExportPolicy.canExportCsv(user), isFalse);
        expect(InventoryExportPolicy.canExportXlsx(user), isFalse);
      });

      test('11. Inventory View without export permission denies all formats', () {
        final user = createStandardUser(
          permissions: {CrmPermissions.inventoryView},
        );
        expect(InventoryExportPolicy.canExportCsv(user), isFalse);
        expect(InventoryExportPolicy.canExportXlsx(user), isFalse);
        expect(InventoryExportPolicy.canExportPdf(user), isFalse);
        expect(InventoryExportPolicy.canExport(user), isFalse);
      });

      test('12. Export permissions without Inventory module deny all formats', () {
        final user = createStandardUser(
          modules: {CrmModule.leadManagement},
          permissions: {
            CrmPermissions.inventoryView,
            CrmPermissions.inventoryExportCsv,
            CrmPermissions.inventoryExportXlsx,
            InventoryExportPolicy.exportPdfPermission,
          },
        );
        expect(InventoryExportPolicy.canExportCsv(user), isFalse);
        expect(InventoryExportPolicy.canExportXlsx(user), isFalse);
        expect(InventoryExportPolicy.canExportPdf(user), isFalse);
        expect(InventoryExportPolicy.canExport(user), isFalse);
      });

      test('13. Export permissions without Inventory View deny all formats', () {
        final user = createStandardUser(
          permissions: {
            CrmPermissions.inventoryExportCsv,
            CrmPermissions.inventoryExportXlsx,
            InventoryExportPolicy.exportPdfPermission,
          },
        );
        expect(InventoryExportPolicy.canExportCsv(user), isFalse);
        expect(InventoryExportPolicy.canExportXlsx(user), isFalse);
        expect(InventoryExportPolicy.canExportPdf(user), isFalse);
        expect(InventoryExportPolicy.canExport(user), isFalse);
      });

      test('14. Import CSV alone does not permit CSV or PDF export', () {
        final user = createStandardUser(
          permissions: {
            CrmPermissions.inventoryView,
            CrmPermissions.inventoryImportCsv,
          },
        );
        expect(InventoryExportPolicy.canExportCsv(user), isFalse);
        expect(InventoryExportPolicy.canExportPdf(user), isFalse);
      });

      test('15. Import XLSX alone does not permit XLSX or PDF export', () {
        final user = createStandardUser(
          permissions: {
            CrmPermissions.inventoryView,
            CrmPermissions.inventoryImportXlsx,
          },
        );
        expect(InventoryExportPolicy.canExportXlsx(user), isFalse);
        expect(InventoryExportPolicy.canExportPdf(user), isFalse);
      });

      test('16. Stock Manage alone does not grant export', () {
        final user = createStandardUser(
          permissions: {
            CrmPermissions.inventoryView,
            CrmPermissions.inventoryStockManage,
          },
        );
        expect(InventoryExportPolicy.canExportCsv(user), isFalse);
        expect(InventoryExportPolicy.canExportXlsx(user), isFalse);
        expect(InventoryExportPolicy.canExportPdf(user), isFalse);
      });

      test('17. Create/Edit/Delete permissions alone do not grant export', () {
        final user = createStandardUser(
          permissions: {
            CrmPermissions.inventoryView,
            CrmPermissions.inventoryCreate,
            CrmPermissions.inventoryEdit,
            CrmPermissions.inventoryDelete,
          },
        );
        expect(InventoryExportPolicy.canExportCsv(user), isFalse);
        expect(InventoryExportPolicy.canExportXlsx(user), isFalse);
        expect(InventoryExportPolicy.canExportPdf(user), isFalse);
      });

      test('18. No authenticated user (null) denies all formats', () {
        expect(InventoryExportPolicy.canExportCsv(null), isFalse);
        expect(InventoryExportPolicy.canExportXlsx(null), isFalse);
        expect(InventoryExportPolicy.canExportPdf(null), isFalse);
        expect(InventoryExportPolicy.canExport(null), isFalse);
      });

      test('19. Revoked CSV permission causes denial', () {
        var user = createStandardUser(
          permissions: {
            CrmPermissions.inventoryView,
            CrmPermissions.inventoryExportCsv,
          },
        );
        expect(InventoryExportPolicy.canExportCsv(user), isTrue);

        user = createStandardUser(
          permissions: {
            CrmPermissions.inventoryView,
          },
        );
        expect(InventoryExportPolicy.canExportCsv(user), isFalse);
      });

      test('20. Revoked XLSX permission causes denial', () {
        var user = createStandardUser(
          permissions: {
            CrmPermissions.inventoryView,
            CrmPermissions.inventoryExportXlsx,
          },
        );
        expect(InventoryExportPolicy.canExportXlsx(user), isTrue);

        user = createStandardUser(
          permissions: {
            CrmPermissions.inventoryView,
          },
        );
        expect(InventoryExportPolicy.canExportXlsx(user), isFalse);
      });

      test('21. Revoked PDF permission causes denial', () {
        var user = createStandardUser(
          permissions: {
            CrmPermissions.inventoryView,
            InventoryExportPolicy.exportPdfPermission,
          },
        );
        expect(InventoryExportPolicy.canExportPdf(user), isTrue);

        user = createStandardUser(
          permissions: {
            CrmPermissions.inventoryView,
          },
        );
        expect(InventoryExportPolicy.canExportPdf(user), isFalse);
      });

      test('22. Removing Inventory module assignment causes denial for all formats', () {
        var user = createStandardUser(
          modules: {CrmModule.inventory},
          permissions: {
            CrmPermissions.inventoryView,
            CrmPermissions.inventoryExportCsv,
            CrmPermissions.inventoryExportXlsx,
            InventoryExportPolicy.exportPdfPermission,
          },
        );
        expect(InventoryExportPolicy.canExportCsv(user), isTrue);
        expect(InventoryExportPolicy.canExportXlsx(user), isTrue);
        expect(InventoryExportPolicy.canExportPdf(user), isTrue);

        user = createStandardUser(
          modules: {CrmModule.hrPayroll},
          permissions: {
            CrmPermissions.inventoryView,
            CrmPermissions.inventoryExportCsv,
            CrmPermissions.inventoryExportXlsx,
            InventoryExportPolicy.exportPdfPermission,
          },
        );
        expect(InventoryExportPolicy.canExportCsv(user), isFalse);
        expect(InventoryExportPolicy.canExportXlsx(user), isFalse);
        expect(InventoryExportPolicy.canExportPdf(user), isFalse);
      });

      test('23. Removing Inventory View causes denial for all formats', () {
        var user = createStandardUser(
          permissions: {
            CrmPermissions.inventoryView,
            CrmPermissions.inventoryExportCsv,
            CrmPermissions.inventoryExportXlsx,
            InventoryExportPolicy.exportPdfPermission,
          },
        );
        expect(InventoryExportPolicy.canExportCsv(user), isTrue);
        expect(InventoryExportPolicy.canExportXlsx(user), isTrue);
        expect(InventoryExportPolicy.canExportPdf(user), isTrue);

        user = createStandardUser(
          permissions: {
            CrmPermissions.inventoryExportCsv,
            CrmPermissions.inventoryExportXlsx,
            InventoryExportPolicy.exportPdfPermission,
          },
        );
        expect(InventoryExportPolicy.canExportCsv(user), isFalse);
        expect(InventoryExportPolicy.canExportXlsx(user), isFalse);
        expect(InventoryExportPolicy.canExportPdf(user), isFalse);
      });
    });
  });
}
