import 'dart:async';
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
import 'package:enterprise_crm/features/inventory/presentation/bloc/inventory_export_cubit.dart';
import 'package:enterprise_crm/features/inventory/presentation/bloc/inventory_export_state.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_export_data_loader.dart';
import 'package:enterprise_crm/features/inventory/presentation/services/inventory_export_service.dart';


class _CustomRepo implements InventoryRepository {
  _CustomRepo(this._fetcher);
  final Future<InventoryPage> Function(InventoryQuery) _fetcher;

  @override
  Future<InventoryPage> getItems(InventoryQuery query) => _fetcher(query);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DelayRepo implements InventoryRepository {
  _DelayRepo(this._completer);
  final Completer<void> _completer;

  @override
  Future<InventoryPage> getItems(InventoryQuery query) async {
    await _completer.future;
    return const InventoryPage(
      items: [],
      currentPage: 1,
      pageSize: 10,
      totalItems: 0,
      hasNext: false,
    );
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
      },
    );
  }

  group('InventoryExportCubit Unit & State Machine Tests', () {
    late MockInventoryRepository mockRepo;
    late InventoryExportDataLoader dataLoader;
    late InventoryExportService exportService;

    setUp(() {
      mockRepo = MockInventoryRepository();
      dataLoader = InventoryExportDataLoader(mockRepo);
      exportService = InventoryExportService(dataLoader: dataLoader);
    });

    test('initial state is InventoryExportInitial', () {
      final user = makeUser();
      final cubit = InventoryExportCubit(
        exportService: exportService,
        currentUser: user,
      );
      expect(cubit.state, isA<InventoryExportInitial>());
    });

    test('successful CSV export emits [Preparing, Prepared]', () async {
      final user = makeUser();
      final cubit = InventoryExportCubit(
        exportService: exportService,
        currentUser: user,
      );

      final states = <InventoryExportState>[];
      cubit.stream.listen(states.add);

      await cubit.export(InventoryExportFormat.csv);
      await Future<void>.delayed(Duration.zero);

      expect(states.length, equals(2));
      expect(states[0], isA<InventoryExportPreparing>());
      expect((states[0] as InventoryExportPreparing).format, equals(InventoryExportFormat.csv));
      expect(states[1], isA<InventoryExportPrepared>());
      final prepared = states[1] as InventoryExportPrepared;
      expect(prepared.artifact.format, equals(InventoryExportFormat.csv));
      expect(prepared.artifact.itemCount, equals(25));
    });

    test('successful XLSX export emits [Preparing, Prepared]', () async {
      final user = makeUser();
      final cubit = InventoryExportCubit(
        exportService: exportService,
        currentUser: user,
      );

      final states = <InventoryExportState>[];
      cubit.stream.listen(states.add);

      await cubit.export(InventoryExportFormat.xlsx);
      await Future<void>.delayed(Duration.zero);

      expect(states.length, equals(2));
      expect(states[0], isA<InventoryExportPreparing>());
      expect((states[0] as InventoryExportPreparing).format, equals(InventoryExportFormat.xlsx));
      expect(states[1], isA<InventoryExportPrepared>());
      final prepared = states[1] as InventoryExportPrepared;
      expect(prepared.artifact.format, equals(InventoryExportFormat.xlsx));
      expect(prepared.artifact.itemCount, equals(25));
    });

    test('unauthorized user immediately emits InventoryExportRestricted without Preparing', () async {
      final userWithoutXlsx = makeUser(
        permissions: {
          CrmPermissions.inventoryView,
          CrmPermissions.inventoryExportCsv,
        },
      );
      final cubit = InventoryExportCubit(
        exportService: exportService,
        currentUser: userWithoutXlsx,
      );

      final states = <InventoryExportState>[];
      cubit.stream.listen(states.add);

      await cubit.export(InventoryExportFormat.xlsx);
      await Future<void>.delayed(Duration.zero);

      expect(states.length, equals(1));
      expect(states[0], isA<InventoryExportRestricted>());
      expect((states[0] as InventoryExportRestricted).format, equals(InventoryExportFormat.xlsx));
    });

    test('user without inventory module is immediately restricted', () async {
      final userWithoutModule = makeUser(
        modules: {CrmModule.hrPayroll},
      );
      final cubit = InventoryExportCubit(
        exportService: exportService,
        currentUser: userWithoutModule,
      );

      final states = <InventoryExportState>[];
      cubit.stream.listen(states.add);

      await cubit.export(InventoryExportFormat.csv);
      await Future<void>.delayed(Duration.zero);

      expect(states.length, equals(1));
      expect(states[0], isA<InventoryExportRestricted>());
    });

    test('duplicate export request while preparing is safely ignored', () async {
      final completer = Completer<void>();
      final delayRepo = _DelayRepo(completer);
      final slowDataLoader = InventoryExportDataLoader(delayRepo);
      final slowService = InventoryExportService(dataLoader: slowDataLoader);

      final user = makeUser();
      final cubit = InventoryExportCubit(
        exportService: slowService,
        currentUser: user,
      );

      final states = <InventoryExportState>[];
      cubit.stream.listen(states.add);

      // Start first export (will pause in delayRepo)
      final future1 = cubit.export(InventoryExportFormat.csv);
      expect(cubit.isPreparing, isTrue);

      // Second export request while isPreparing
      final future2 = cubit.export(InventoryExportFormat.xlsx);

      // Allow slow export to complete
      completer.complete();
      await Future.wait([future1, future2]);
      await Future<void>.delayed(Duration.zero);

      // Verify second request was ignored and only states from first request emitted
      expect(states.length, equals(2));
      expect(states[0], isA<InventoryExportPreparing>());
      expect((states[0] as InventoryExportPreparing).format, equals(InventoryExportFormat.csv));
      expect(states[1], isA<InventoryExportPrepared>());
      expect((states[1] as InventoryExportPrepared).artifact.format, equals(InventoryExportFormat.csv));
    });

    test('revalidation failure during loading emits InventoryExportRestricted with safe message', () async {
      final initialUser = makeUser();
      CurrentUser? currentUser = initialUser;

      final dynamicLoader = InventoryExportDataLoader(_CustomRepo((q) async {
        // While loading, permissions get revoked
        currentUser = makeUser(permissions: {CrmPermissions.inventoryView});
        return const InventoryPage(
          items: [],
          currentPage: 1,
          pageSize: 10,
          totalItems: 0,
          hasNext: false,
        );
      }));
      final service = InventoryExportService(dataLoader: dynamicLoader);

      final cubit = InventoryExportCubit(
        exportService: service,
        currentUser: initialUser,
        currentUserProvider: () => currentUser,
      );

      final states = <InventoryExportState>[];
      cubit.stream.listen(states.add);

      await cubit.export(InventoryExportFormat.csv);
      await Future<void>.delayed(Duration.zero);

      expect(states.length, equals(2));
      expect(states[0], isA<InventoryExportPreparing>());
      expect(states[1], isA<InventoryExportRestricted>());
      expect((states[1] as InventoryExportRestricted).message, contains('revoked'));
    });

    test('reset resets state to initial when not preparing', () async {
      final user = makeUser();
      final cubit = InventoryExportCubit(
        exportService: exportService,
        currentUser: user,
      );

      await cubit.export(InventoryExportFormat.csv);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state, isA<InventoryExportPrepared>());

      cubit.reset();
      expect(cubit.state, isA<InventoryExportInitial>());
    });
  });
}
