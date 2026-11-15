import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/user_management/domain/entities/managed_user.dart';
import 'package:enterprise_crm/features/user_management/domain/entities/user_account_status.dart';
import 'package:enterprise_crm/features/user_management/domain/inputs/create_managed_user_input.dart';
import 'package:enterprise_crm/features/user_management/domain/inputs/update_managed_user_input.dart';
import 'package:enterprise_crm/features/user_management/domain/repositories/user_management_repository.dart';
import 'package:enterprise_crm/features/user_management/presentation/screens/create_user_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/mock_auth_test_fixtures.dart';

class _SpyUserManagementRepository implements UserManagementRepository {
  CreateManagedUserInput? lastCreateInput;
  String? lastTemporaryPassword;
  int createCallCount = 0;
  bool shouldThrowOnCreate = false;
  String exceptionMessage = 'User ID already exists.';

  @override
  Future<ManagedUser> createUser(
    CreateManagedUserInput input, {
    required String temporaryPassword,
  }) async {
    createCallCount++;
    lastCreateInput = input;
    lastTemporaryPassword = temporaryPassword;
    if (shouldThrowOnCreate) {
      throw UserManagementException(exceptionMessage);
    }
    return ManagedUser(
      id: 'usr_new',
      userId: input.userId,
      displayName: input.displayName,
      accountType: MockAuthTestFixtures.standardUser.accountType,
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
  Future<ManagedUser> updateUser(UpdateManagedUserInput input) async =>
      throw UnimplementedError();

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

Widget _buildCreateUserApp({
  required UserManagementRepository repository,
  bool isAdmin = true,
}) {
  return MaterialApp(
    home: CreateUserScreen(
      currentUser: isAdmin
          ? MockAuthTestFixtures.admin
          : MockAuthTestFixtures.standardUser,
      repository: repository,
    ),
  );
}

void main() {
  group('CreateUserScreen Tests', () {
    late _SpyUserManagementRepository repository;

    setUp(() {
      repository = _SpyUserManagementRepository();
    });

    testWidgets('Admin direct access renders all required form controls', (
      tester,
    ) async {
      await tester.pumpWidget(_buildCreateUserApp(repository: repository));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('create_user_screen')), findsOneWidget);
      expect(find.text('Create User'), findsWidgets);
      expect(find.byKey(const Key('create_user_id_field')), findsOneWidget);
      expect(
        find.byKey(const Key('create_user_display_name_field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('create_user_password_field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('create_user_password_visibility_button')),
        findsOneWidget,
      );

      // All 8 CRM modules must be available as filter chips
      for (final module in CrmModule.values) {
        expect(
          find.byKey(Key('create_user_module_${module.name}')),
          findsOneWidget,
        );
      }

      // Initial state: no modules selected
      expect(
        find.text('Select one or more modules above to configure permissions.'),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('create_user_cancel_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('create_user_submit_button')),
        findsOneWidget,
      );
    });

    testWidgets('Non-Admin access is blocked with Access Restricted', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCreateUserApp(repository: repository, isAdmin: false),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('create_user_unauthorized_screen')),
        findsOneWidget,
      );
      expect(find.text('Access Restricted'), findsOneWidget);
      expect(find.byKey(const Key('create_user_id_field')), findsNothing);
    });

    testWidgets('Password visibility toggle toggles obscured text', (
      tester,
    ) async {
      await tester.pumpWidget(_buildCreateUserApp(repository: repository));
      await tester.pumpAndSettle();

      final initialField = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('create_user_password_field')),
          matching: find.byType(TextField),
        ),
      );
      expect(initialField.obscureText, isTrue);

      await tester.tap(
        find.byKey(const Key('create_user_password_visibility_button')),
      );
      await tester.pumpAndSettle();

      final revealedField = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('create_user_password_field')),
          matching: find.byType(TextField),
        ),
      );
      expect(revealedField.obscureText, isFalse);
    });

    testWidgets('Form validation rejects empty required fields', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildCreateUserApp(repository: repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('create_user_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('User ID is required.'), findsOneWidget);
      expect(find.text('Display Name is required.'), findsOneWidget);
      expect(find.text('Temporary Password is required.'), findsOneWidget);
      expect(repository.createCallCount, 0);
    });

    testWidgets(
      'Module multi-select dynamically shows and filters permissions',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_buildCreateUserApp(repository: repository));
        await tester.pumpAndSettle();

        // Tap Lead Management
        await tester.tap(
          find.byKey(
            Key('create_user_module_${CrmModule.leadManagement.name}'),
          ),
        );
        await tester.pumpAndSettle();

        // Lead Management permissions appear
        expect(
          find.byKey(const Key('create_user_permission_lead.view_assigned')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('create_user_permission_lead.update')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('create_user_permission_calling.use')),
          findsNothing,
        );

        // Tap Calling
        await tester.tap(
          find.byKey(Key('create_user_module_${CrmModule.calling.name}')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('create_user_permission_calling.use')),
          findsOneWidget,
        );

        // Select lead.view_assigned and calling.use
        await tester.tap(
          find.byKey(const Key('create_user_permission_lead.view_assigned')),
        );
        await tester.ensureVisible(
          find.byKey(const Key('create_user_permission_calling.use')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('create_user_permission_calling.use')),
        );
        await tester.pumpAndSettle();

        // Deselect Lead Management -> its permissions must disappear from UI
        await tester.ensureVisible(
          find.byKey(
            Key('create_user_module_${CrmModule.leadManagement.name}'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(
            Key('create_user_module_${CrmModule.leadManagement.name}'),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('create_user_permission_lead.view_assigned')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('create_user_permission_calling.use')),
          findsOneWidget,
        );
      },
    );

    testWidgets('Successful creation calls repository and pops screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildCreateUserApp(repository: repository));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('create_user_id_field')),
        '  sales_hero  ',
      );
      await tester.enterText(
        find.byKey(const Key('create_user_display_name_field')),
        '  Sales Hero  ',
      );
      await tester.enterText(
        find.byKey(const Key('create_user_password_field')),
        '  temp_pass_123  ',
      );

      // Select Calling module and permission
      await tester.tap(
        find.byKey(Key('create_user_module_${CrmModule.calling.name}')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('create_user_permission_calling.use')),
      );
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.byKey(const Key('create_user_submit_button')));
      await tester.pumpAndSettle();

      expect(repository.createCallCount, 1);
      expect(repository.lastCreateInput?.userId, 'sales_hero');
      expect(repository.lastCreateInput?.displayName, 'Sales Hero');
      expect(repository.lastTemporaryPassword, 'temp_pass_123');
      expect(repository.lastCreateInput?.modules, {CrmModule.calling});
      expect(repository.lastCreateInput?.permissions, {'calling.use'});
    });

    testWidgets('Duplicate User ID displays safe error banner', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      repository.shouldThrowOnCreate = true;
      repository.exceptionMessage = 'User ID "admin" is already taken.';

      await tester.pumpWidget(_buildCreateUserApp(repository: repository));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('create_user_id_field')),
        'admin',
      );
      await tester.enterText(
        find.byKey(const Key('create_user_display_name_field')),
        'Admin Duplicate',
      );
      await tester.enterText(
        find.byKey(const Key('create_user_password_field')),
        'pass123',
      );

      await tester.tap(find.byKey(const Key('create_user_submit_button')));
      await tester.pumpAndSettle();

      expect(repository.createCallCount, 1);
      expect(find.byKey(const Key('create_user_error_banner')), findsOneWidget);
      expect(find.text('User ID "admin" is already taken.'), findsOneWidget);
    });

    testWidgets(
      'All Permissions checkbox allows all permissions in once and supports deselect',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_buildCreateUserApp(repository: repository));
        await tester.pumpAndSettle();

        // Enter required fields first
        await tester.enterText(
          find.byKey(const Key('create_user_id_field')),
          'super_user',
        );
        await tester.enterText(
          find.byKey(const Key('create_user_display_name_field')),
          'Super User',
        );
        await tester.enterText(
          find.byKey(const Key('create_user_password_field')),
          'secret123',
        );

        final allPermsCheckbox = find.byKey(
          const Key('create_user_all_permissions_checkbox'),
        );
        expect(allPermsCheckbox, findsOneWidget);

        // Tap All Permissions when no modules are selected -> selects all modules and all permissions
        await tester.tap(allPermsCheckbox);
        await tester.pumpAndSettle();

        // Verify all 8 modules are selected
        for (final module in CrmModule.values) {
          final chip = tester.widget<FilterChip>(
            find.byKey(Key('create_user_module_${module.name}')),
          );
          expect(chip.selected, isTrue);
        }

        await tester.ensureVisible(
          find.byKey(const Key('create_user_submit_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('create_user_submit_button')));
        await tester.pumpAndSettle();

        expect(repository.createCallCount, 1);
        expect(
          repository.lastCreateInput?.modules.length,
          CrmModule.values.length,
        );
        expect(
          repository.lastCreateInput?.permissions.contains('lead.view_assigned'),
          isTrue,
        );
        expect(
          repository.lastCreateInput?.permissions.contains('calling.use'),
          isTrue,
        );
        expect(
          repository.lastCreateInput?.permissions.contains('hr.view'),
          isTrue,
        );
        expect(
          repository.lastCreateInput?.permissions.contains('inventory.view'),
          isTrue,
        );
      },
    );

    testWidgets(
      'All Permissions checkbox allows all permissions for selected modules and toggles cleanly',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_buildCreateUserApp(repository: repository));
        await tester.pumpAndSettle();

        // Select only Calling module
        await tester.tap(
          find.byKey(Key('create_user_module_${CrmModule.calling.name}')),
        );
        await tester.pumpAndSettle();

        final allPermsCheckbox = find.byKey(
          const Key('create_user_all_permissions_checkbox'),
        );

        // Tap All Permissions -> checks calling.use
        await tester.tap(allPermsCheckbox);
        await tester.pumpAndSettle();

        final callingTile = tester.widget<CheckboxListTile>(
          find.byKey(const Key('create_user_permission_calling.use')),
        );
        expect(callingTile.value, isTrue);

        // Tap All Permissions again -> deselects
        await tester.tap(allPermsCheckbox);
        await tester.pumpAndSettle();

        final callingTileDeselected = tester.widget<CheckboxListTile>(
          find.byKey(const Key('create_user_permission_calling.use')),
        );
        expect(callingTileDeselected.value, isFalse);
      },
    );

    testWidgets(
      'Module Select All button toggles all permissions for that specific module',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_buildCreateUserApp(repository: repository));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(Key('create_user_module_${CrmModule.leadManagement.name}')),
        );
        await tester.pumpAndSettle();

        final selectAllLead = find.byKey(
          Key('create_user_select_all_${CrmModule.leadManagement.name}'),
        );
        expect(selectAllLead, findsOneWidget);

        // Tap Select All for Lead Management
        await tester.tap(selectAllLead);
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<CheckboxListTile>(
                find.byKey(const Key('create_user_permission_lead.view_assigned')),
              )
              .value,
          isTrue,
        );
        expect(
          tester
              .widget<CheckboxListTile>(
                find.byKey(const Key('create_user_permission_lead.update')),
              )
              .value,
          isTrue,
        );

        // Tap Deselect All for Lead Management
        await tester.tap(selectAllLead);
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<CheckboxListTile>(
                find.byKey(const Key('create_user_permission_lead.view_assigned')),
              )
              .value,
          isFalse,
        );
      },
    );
  });
}
