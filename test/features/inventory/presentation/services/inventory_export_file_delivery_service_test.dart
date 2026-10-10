import 'dart:typed_data';
import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/inventory/domain/entities/inventory_export_artifact.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_export_file_delivery_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeExportFileSaver implements InventoryExportFileSaver {
  String? lastFileName;
  Uint8List? lastBytes;
  String? lastMimeType;
  String? lastExtension;
  String? lastDialogTitle;
  int callCount = 0;

  Uri? returnUri;
  Exception? throwException;

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    required String extension,
    String? dialogTitle,
  }) async {
    callCount++;
    lastFileName = fileName;
    lastBytes = bytes;
    lastMimeType = mimeType;
    lastExtension = extension;
    lastDialogTitle = dialogTitle;

    if (throwException != null) {
      throw throwException!;
    }
    return returnUri;
  }
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

  InventoryExportArtifact makeArtifact({
    InventoryExportFormat format = InventoryExportFormat.csv,
    Uint8List? bytes,
    int itemCount = 10,
  }) {
    return InventoryExportArtifact(
      bytes: bytes ?? Uint8List.fromList([1, 2, 3, 4, 5]),
      format: format,
      itemCount: itemCount,
    );
  }

  group('InventoryExportFileDeliveryService - Delivery & Platform Results', () {
    late _FakeExportFileSaver fakeSaver;

    setUp(() {
      fakeSaver = _FakeExportFileSaver();
    });

    test('delivers CSV exact bytes, mimeType, and extension on Android', () async {
      final service = InventoryExportFileDeliveryService(
        fileSaver: fakeSaver,
        isWeb: false,
      );
      final user = makeUser();
      final sampleBytes = Uint8List.fromList([10, 20, 30, 40]);
      final artifact = makeArtifact(
        format: InventoryExportFormat.csv,
        bytes: sampleBytes,
      );

      final expectedUri = Uri.parse('file:///storage/emulated/0/Download/export.csv');
      fakeSaver.returnUri = expectedUri;

      final result = await service.deliverArtifact(
        artifact: artifact,
        currentUserProvider: () => user,
      );

      expect(fakeSaver.callCount, 1);
      expect(fakeSaver.lastBytes, equals(sampleBytes));
      expect(fakeSaver.lastExtension, 'csv');
      expect(fakeSaver.lastMimeType, 'text/csv');
      expect(fakeSaver.lastFileName, artifact.defaultFileName());
      expect(result.status, InventoryExportDeliveryStatus.saved);
      expect(result.isSaved, isTrue);
      expect(result.uri, expectedUri);
    });

    test('delivers XLSX exact bytes, mimeType, and extension on Android', () async {
      final service = InventoryExportFileDeliveryService(
        fileSaver: fakeSaver,
        isWeb: false,
      );
      final user = makeUser();
      final sampleBytes = Uint8List.fromList([80, 75, 3, 4]);
      final artifact = makeArtifact(
        format: InventoryExportFormat.xlsx,
        bytes: sampleBytes,
      );

      final expectedUri = Uri.parse('file:///storage/emulated/0/Download/export.xlsx');
      fakeSaver.returnUri = expectedUri;

      final result = await service.deliverArtifact(
        artifact: artifact,
        currentUserProvider: () => user,
      );

      expect(fakeSaver.callCount, 1);
      expect(fakeSaver.lastBytes, equals(sampleBytes));
      expect(fakeSaver.lastExtension, 'xlsx');
      expect(
        fakeSaver.lastMimeType,
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      expect(result.status, InventoryExportDeliveryStatus.saved);
      expect(result.isSaved, isTrue);
      expect(result.uri, expectedUri);
    });

    test('returns downloadInitiated status on Flutter Web', () async {
      final service = InventoryExportFileDeliveryService(
        fileSaver: fakeSaver,
        isWeb: true,
      );
      final user = makeUser();
      final artifact = makeArtifact(format: InventoryExportFormat.csv);

      final result = await service.deliverArtifact(
        artifact: artifact,
        currentUserProvider: () => user,
      );

      expect(fakeSaver.callCount, 1);
      expect(result.status, InventoryExportDeliveryStatus.downloadInitiated);
      expect(result.isDownloadInitiated, isTrue);
    });

    test('returns cancelled status when user dismisses save dialog on Android', () async {
      final service = InventoryExportFileDeliveryService(
        fileSaver: fakeSaver,
        isWeb: false,
      );
      final user = makeUser();
      final artifact = makeArtifact(format: InventoryExportFormat.csv);
      fakeSaver.returnUri = null; // User cancelled

      final result = await service.deliverArtifact(
        artifact: artifact,
        currentUserProvider: () => user,
      );

      expect(fakeSaver.callCount, 1);
      expect(result.status, InventoryExportDeliveryStatus.cancelled);
      expect(result.isCancelled, isTrue);
      expect(result.uri, isNull);
    });

    test('returns failure status when platform saver throws an exception', () async {
      final service = InventoryExportFileDeliveryService(
        fileSaver: fakeSaver,
        isWeb: false,
      );
      final user = makeUser();
      final artifact = makeArtifact(format: InventoryExportFormat.csv);
      fakeSaver.throwException = Exception('Filesystem I/O error');

      final result = await service.deliverArtifact(
        artifact: artifact,
        currentUserProvider: () => user,
      );

      expect(result.status, InventoryExportDeliveryStatus.failure);
      expect(result.isFailure, isTrue);
      expect(result.message, contains('Filesystem I/O error'));
    });
  });

  group('InventoryExportFileDeliveryService - Security & Authorization', () {
    late _FakeExportFileSaver fakeSaver;
    late InventoryExportFileDeliveryService service;

    setUp(() {
      fakeSaver = _FakeExportFileSaver();
      service = InventoryExportFileDeliveryService(
        fileSaver: fakeSaver,
        isWeb: false,
      );
    });

    test('denies delivery if user session expired or unauthenticated (null)', () async {
      final artifact = makeArtifact(format: InventoryExportFormat.csv);

      final result = await service.deliverArtifact(
        artifact: artifact,
        currentUserProvider: () => null,
      );

      expect(result.status, InventoryExportDeliveryStatus.restricted);
      expect(result.isRestricted, isTrue);
      expect(result.message, contains('unauthenticated'));
      expect(fakeSaver.callCount, 0); // Platform saver never touched
    });

    test('denies delivery if user identity changes from preparing user', () async {
      final artifact = makeArtifact(format: InventoryExportFormat.csv);
      final userB = makeUser(id: 'user_b');

      final result = await service.deliverArtifact(
        artifact: artifact,
        boundUserId: 'user_a',
        currentUserProvider: () => userB,
      );

      expect(result.status, InventoryExportDeliveryStatus.restricted);
      expect(result.isRestricted, isTrue);
      expect(result.message, contains('identity changed'));
      expect(fakeSaver.callCount, 0);
    });

    test('denies CSV delivery if user lacks CSV export permission', () async {
      final userXlsxOnly = makeUser(
        permissions: {
          CrmPermissions.inventoryView,
          CrmPermissions.inventoryExportXlsx,
        },
      );
      final csvArtifact = makeArtifact(format: InventoryExportFormat.csv);

      final result = await service.deliverArtifact(
        artifact: csvArtifact,
        currentUserProvider: () => userXlsxOnly,
      );

      expect(result.status, InventoryExportDeliveryStatus.restricted);
      expect(fakeSaver.callCount, 0);
    });

    test('denies XLSX delivery if user lacks XLSX export permission', () async {
      final userCsvOnly = makeUser(
        permissions: {
          CrmPermissions.inventoryView,
          CrmPermissions.inventoryExportCsv,
        },
      );
      final xlsxArtifact = makeArtifact(format: InventoryExportFormat.xlsx);

      final result = await service.deliverArtifact(
        artifact: xlsxArtifact,
        currentUserProvider: () => userCsvOnly,
      );

      expect(result.status, InventoryExportDeliveryStatus.restricted);
      expect(fakeSaver.callCount, 0);
    });

    test('denies delivery if permission was revoked after preparation', () async {
      final userRevoked = makeUser(
        permissions: {CrmPermissions.inventoryView}, // No export permissions
      );
      final artifact = makeArtifact(format: InventoryExportFormat.csv);

      final result = await service.deliverArtifact(
        artifact: artifact,
        currentUserProvider: () => userRevoked,
      );

      expect(result.status, InventoryExportDeliveryStatus.restricted);
      expect(result.message, contains('not authorized'));
      expect(fakeSaver.callCount, 0);
    });

    test('denies delivery if inventory module is removed', () async {
      final userWithoutModule = makeUser(modules: {CrmModule.hrPayroll});
      final artifact = makeArtifact(format: InventoryExportFormat.csv);

      final result = await service.deliverArtifact(
        artifact: artifact,
        currentUserProvider: () => userWithoutModule,
      );

      expect(result.status, InventoryExportDeliveryStatus.restricted);
      expect(fakeSaver.callCount, 0);
    });

    test('allows delivery for Administrator', () async {
      final admin = makeUser(type: AccountType.admin, permissions: {});
      final artifact = makeArtifact(format: InventoryExportFormat.csv);
      fakeSaver.returnUri = Uri.parse('file:///tmp/admin.csv');

      final result = await service.deliverArtifact(
        artifact: artifact,
        currentUserProvider: () => admin,
      );

      expect(result.status, InventoryExportDeliveryStatus.saved);
      expect(fakeSaver.callCount, 1);
    });
  });

  group('InventoryExportFileDeliveryService - Concurrency & Filename Validation', () {
    late _FakeExportFileSaver fakeSaver;
    late InventoryExportFileDeliveryService service;

    setUp(() {
      fakeSaver = _FakeExportFileSaver();
      service = InventoryExportFileDeliveryService(
        fileSaver: fakeSaver,
        isWeb: false,
      );
    });

    test('rejects unsafe filename containing path traversal or slashes', () async {
      final user = makeUser();
      final artifact = makeArtifact(format: InventoryExportFormat.csv);

      final result1 = await service.deliverArtifact(
        artifact: artifact,
        currentUserProvider: () => user,
        customFileName: '../secret.csv',
      );
      expect(result1.status, InventoryExportDeliveryStatus.failure);
      expect(result1.message, contains('path traversal'));
      expect(fakeSaver.callCount, 0);

      final result2 = await service.deliverArtifact(
        artifact: artifact,
        currentUserProvider: () => user,
        customFileName: 'folder/name.csv',
      );
      expect(result2.status, InventoryExportDeliveryStatus.failure);
      expect(result2.message, contains('path traversal'));
      expect(fakeSaver.callCount, 0);
    });

    test('rejects filename if extension does not match artifact format', () async {
      final user = makeUser();
      final artifact = makeArtifact(format: InventoryExportFormat.csv);

      final result = await service.deliverArtifact(
        artifact: artifact,
        currentUserProvider: () => user,
        customFileName: 'inventory.xlsx', // Mismatched extension
      );

      expect(result.status, InventoryExportDeliveryStatus.failure);
      expect(result.message, contains('Filename extension must match .csv'));
      expect(fakeSaver.callCount, 0);
    });

    test('prevents duplicate simultaneous deliveries', () async {
      final user = makeUser();
      final artifact = makeArtifact(format: InventoryExportFormat.csv);

      // Simulate slow saver
      final saver = _SlowSaver();
      final slowService = InventoryExportFileDeliveryService(
        fileSaver: saver,
        isWeb: false,
      );

      final future1 = slowService.deliverArtifact(
        artifact: artifact,
        currentUserProvider: () => user,
      );
      expect(slowService.isDelivering, isTrue);

      final future2 = slowService.deliverArtifact(
        artifact: artifact,
        currentUserProvider: () => user,
      );

      final result2 = await future2;
      expect(result2.status, InventoryExportDeliveryStatus.restricted);
      expect(result2.message, contains('already in progress'));

      saver.finish();
      final result1 = await future1;
      expect(result1.status, InventoryExportDeliveryStatus.saved);
      expect(slowService.isDelivering, isFalse);
    });
  });

  group('InventoryExportDeliveryResult - Equality & Properties', () {
    test('supports equality and toString', () {
      final uri = Uri.parse('file:///tmp/export.csv');
      final r1 = InventoryExportDeliveryResult.saved(uri: uri);
      final r2 = InventoryExportDeliveryResult.saved(uri: uri);
      const c1 = InventoryExportDeliveryResult.cancelled();
      const c2 = InventoryExportDeliveryResult.cancelled();
      const d1 = InventoryExportDeliveryResult.downloadInitiated();

      expect(r1, equals(r2));
      expect(r1.hashCode, equals(r2.hashCode));
      expect(c1, equals(c2));
      expect(c1.hashCode, equals(c2.hashCode));
      expect(r1, isNot(equals(c1)));
      expect(d1.isDownloadInitiated, isTrue);
      expect(r1.isSaved, isTrue);
      expect(c1.isCancelled, isTrue);
    });
  });
}

class _SlowSaver implements InventoryExportFileSaver {
  void Function()? _onFinish;

  void finish() {
    _onFinish?.call();
  }

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    required String extension,
    String? dialogTitle,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return Uri.parse('file:///tmp/$fileName');
  }
}
