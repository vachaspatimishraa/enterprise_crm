import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/auth/presentation/screens/access_restricted_screen.dart';
import 'package:enterprise_crm/features/dashboard/presentation/screens/module_placeholder_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildModuleApp(CurrentUser user, CrmModule module) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
    home: ModulePlaceholderScreen(module: module, user: user),
  );
}

void main() {
  group('ModulePlaceholderScreen - Authorization & Capabilities', () {
    const admin = CurrentUser(
      id: 'usr_admin',
      displayName: 'Administrator',
      accountType: AccountType.admin,
      modules: {},
      permissions: {},
    );

    testWidgets('Admin can access any placeholder module unconditionally', (
      tester,
    ) async {
      await tester.pumpWidget(_buildModuleApp(admin, CrmModule.inventory));
      await tester.pumpAndSettle();

      expect(find.byType(ModulePlaceholderScreen), findsOneWidget);
      expect(find.text('Access granted.'), findsOneWidget);
      expect(find.byType(AccessRestrictedScreen), findsNothing);
    });

    testWidgets(
      'Direct navigation to unassigned module renders AccessRestrictedScreen',
      (tester) async {
        const user = CurrentUser(
          id: 'usr_user',
          displayName: 'Standard User',
          accountType: AccountType.user,
          modules: {CrmModule.calling},
          permissions: {CrmPermissions.callingUse},
        );

        // Attempting direct navigation to Inventory (not assigned)
        await tester.pumpWidget(_buildModuleApp(user, CrmModule.inventory));
        await tester.pumpAndSettle();

        expect(find.byType(AccessRestrictedScreen), findsOneWidget);
        expect(find.text('Access Restricted'), findsOneWidget);
        expect(find.text('Access granted.'), findsNothing);
      },
    );

    testWidgets(
      'Calling module: user with calling.use sees Access granted and capability',
      (tester) async {
        const user = CurrentUser(
          id: 'usr_caller',
          displayName: 'Caller',
          accountType: AccountType.user,
          modules: {CrmModule.calling},
          permissions: {CrmPermissions.callingUse},
        );

        await tester.pumpWidget(_buildModuleApp(user, CrmModule.calling));
        await tester.pumpAndSettle();

        expect(find.text('Access granted.'), findsOneWidget);
        expect(find.text('Use calling'), findsOneWidget);
        expect(
          find.byKey(const Key('module_no_operational_permission')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Calling module: user without calling.use sees no operational permission message',
      (tester) async {
        const user = CurrentUser(
          id: 'usr_no_caller',
          displayName: 'Silent User',
          accountType: AccountType.user,
          modules: {CrmModule.calling},
          permissions: {},
        );

        await tester.pumpWidget(_buildModuleApp(user, CrmModule.calling));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('module_no_operational_permission')),
          findsOneWidget,
        );
        expect(
          find.text(
            'You do not currently have an operational permission for this module.',
          ),
          findsOneWidget,
        );
        expect(find.text('Access granted.'), findsNothing);
      },
    );

    testWidgets(
      'Modules without fine-grained permissions (Dispatch, Approvals) grant access on module assignment',
      (tester) async {
        const user = CurrentUser(
          id: 'usr_dispatcher',
          displayName: 'Dispatcher',
          accountType: AccountType.user,
          modules: {CrmModule.dispatch},
          permissions: {},
        );

        await tester.pumpWidget(_buildModuleApp(user, CrmModule.dispatch));
        await tester.pumpAndSettle();

        expect(find.text('Access granted.'), findsOneWidget);
        expect(
          find.byKey(const Key('module_no_operational_permission')),
          findsNothing,
        );
      },
    );

    testWidgets('Back button pops navigation', (tester) async {
      const user = CurrentUser(
        id: 'usr_user',
        displayName: 'Standard User',
        accountType: AccountType.user,
        modules: {CrmModule.inventory},
        permissions: {CrmPermissions.inventoryView},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ModulePlaceholderScreen(
                        module: CrmModule.inventory,
                        user: user,
                      ),
                    ),
                  ),
                  child: const Text('Open Module'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Module'));
      await tester.pumpAndSettle();
      expect(find.byType(ModulePlaceholderScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('module_placeholder_back_button')));
      await tester.pumpAndSettle();
      expect(find.byType(ModulePlaceholderScreen), findsNothing);
      expect(find.text('Open Module'), findsOneWidget);
    });
  });
}
