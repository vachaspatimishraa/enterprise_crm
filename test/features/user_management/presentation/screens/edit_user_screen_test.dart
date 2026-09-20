import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/user_management/domain/entities/managed_user.dart';
import 'package:enterprise_crm/features/user_management/domain/entities/user_account_status.dart';
import 'package:enterprise_crm/features/user_management/domain/inputs/create_managed_user_input.dart';
import 'package:enterprise_crm/features/user_management/domain/inputs/update_managed_user_input.dart';
import 'package:enterprise_crm/features/user_management/domain/repositories/user_management_repository.dart';
import 'package:enterprise_crm/features/user_management/presentation/screens/edit_user_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/mock_auth_test_fixtures.dart';

class _SpyUserManagementRepository implements UserManagementRepository {
  UpdateManagedUserInput? lastUpdateInput;
  int updateCallCount = 0;
  bool shouldThrowOnUpdate = false;
  String exceptionMessage = 'Update failed.';

  @override
  Future<ManagedUser> updateUser(UpdateManagedUserInput input) async {
    updateCallCount++;
    lastUpdateInput = input;
    if (shouldThrowOnUpdate) {
      throw UserManagementException(exceptionMessage);
    }
    return ManagedUser(
      id: input.id,
      userId: 'test_user',
      displayName: input.displayName,
      accountType: AccountType.user,
      modules: input.modules,
      permissions: input.permissions,
      status: UserAccountStatus.active,
    );
  }

  @override
  Future<List<ManagedUser>> getUsers() async => [];

  @override
  Future<ManagedUser?> getUserById(String id) async => null;

  @override
  Future<ManagedUser?> findUserByUserId(String userId) async => null;

  @override
  Future<ManagedUser> createUser(
    CreateManagedUserInput input, {
    required String temporaryPassword,
  }) async => throw UnimplementedError();

  @override
  Future<ManagedUser> setUserStatus({
    required String id,
    required UserAccountStatus status,
  }) async => throw UnimplementedError();

  @override
  Future<void> resetPassword({
    required String id,
    required String newPassword,
  }) async => throw UnimplementedError();
}

Widget _buildEditUserApp({
  required ManagedUser user,
  required UserManagementRepository repository,
  bool isAdmin = true,
}) {
  return MaterialApp(
    home: EditUserScreen(
      currentUser: isAdmin
          ? MockAuthTestFixtures.admin
          : MockAuthTestFixtures.standardUser,
      user: user,
      repository: repository,
    ),
  );
}

void main() {
  group('EditUserScreen Tests', () {
    late _SpyUserManagementRepository repository;
    late ManagedUser standardUser;
    late ManagedUser adminUser;

    setUp(() {
      repository = _SpyUserManagementRepository();
      standardUser = ManagedUser(
        id: 'usr_std_1',
        userId: 'jsmith',
        displayName: 'Jane Smith',
        accountType: AccountType.user,
        modules: const {CrmModule.leadManagement},
        permissions: const {'lead.view_assigned'},
        status: UserAccountStatus.active,
      );
      adminUser = ManagedUser(
        id: 'usr_admin',
        userId: 'admin',
        displayName: 'Administrator',
        accountType: AccountType.admin,
        modules: Set.of(CrmModule.values),
        permissions: const {},
        status: UserAccountStatus.active,
      );
    });

    testWidgets(
      'Admin direct access renders initial values and read-only User ID',
      (tester) async {
        await tester.pumpWidget(
          _buildEditUserApp(user: standardUser, repository: repository),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('edit_user_screen')), findsOneWidget);
        expect(find.text('Edit User: @jsmith'), findsOneWidget);

        // User ID field must be read-only
        final userIdField = tester.widget<TextField>(
          find.descendant(
            of: find.byKey(const Key('edit_user_id_field')),
            matching: find.byType(TextField),
          ),
        );
        expect(userIdField.readOnly, isTrue);

        // Display Name field populated with current name
        expect(find.text('Jane Smith'), findsOneWidget);

        // Lead Management chip must be selected
        final leadChip = tester.widget<FilterChip>(
          find.byKey(Key('edit_user_module_${CrmModule.leadManagement.name}')),
        );
        expect(leadChip.selected, isTrue);
      },
    );

    testWidgets('Non-Admin access is blocked with Access Restricted', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildEditUserApp(
          user: standardUser,
          repository: repository,
          isAdmin: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('edit_user_unauthorized_screen')),
        findsOneWidget,
      );
      expect(find.text('Access Restricted'), findsOneWidget);
    });

    testWidgets('Master Admin cannot be edited: renders Protected screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildEditUserApp(user: adminUser, repository: repository),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('edit_user_admin_protected_screen')),
        findsOneWidget,
      );
      expect(find.text('Master Administrator Protected'), findsOneWidget);
      expect(find.byKey(const Key('edit_user_submit_button')), findsNothing);
    });

    testWidgets('Validation rejects empty Display Name', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildEditUserApp(user: standardUser, repository: repository),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('edit_user_display_name_field')),
        '   ',
      );
      await tester.tap(find.byKey(const Key('edit_user_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Display Name is required.'), findsOneWidget);
      expect(repository.updateCallCount, 0);
    });

    testWidgets(
      'Saving updated display name, modules, and permissions calls repository',
      (tester) async {
        await tester.pumpWidget(
          _buildEditUserApp(user: standardUser, repository: repository),
        );
        await tester.pumpAndSettle();

        // Change display name
        await tester.enterText(
          find.byKey(const Key('edit_user_display_name_field')),
          'Jane Doe',
        );

        // Add Calling module
        await tester.ensureVisible(
          find.byKey(Key('edit_user_module_${CrmModule.calling.name}')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(Key('edit_user_module_${CrmModule.calling.name}')),
        );
        await tester.pumpAndSettle();

        // Select Calling permission
        await tester.ensureVisible(
          find.byKey(const Key('edit_user_permission_calling.use')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('edit_user_permission_calling.use')),
        );
        await tester.pumpAndSettle();

        // Submit
        await tester.ensureVisible(
          find.byKey(const Key('edit_user_submit_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('edit_user_submit_button')));
        await tester.pumpAndSettle();

        expect(repository.updateCallCount, 1);
        expect(repository.lastUpdateInput?.id, 'usr_std_1');
        expect(repository.lastUpdateInput?.displayName, 'Jane Doe');
        expect(repository.lastUpdateInput?.modules, {
          CrmModule.leadManagement,
          CrmModule.calling,
        });
        expect(repository.lastUpdateInput?.permissions, {
          'lead.view_assigned',
          'calling.use',
        });
      },
    );
  });
}
