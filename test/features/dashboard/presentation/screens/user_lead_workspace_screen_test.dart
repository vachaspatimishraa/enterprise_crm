import 'package:enterprise_crm/features/auth/data/repositories/mock_user_lead_link_repository.dart';
import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/auth/domain/repositories/user_lead_link_repository.dart';
import 'package:enterprise_crm/features/auth/presentation/screens/access_restricted_screen.dart';
import 'package:enterprise_crm/features/dashboard/presentation/screens/user_lead_workspace_screen.dart';
import 'package:enterprise_crm/features/leads/data/repositories/mock_lead_repository.dart';
import 'package:enterprise_crm/features/leads/domain/repositories/lead_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Helpers ────────────────────────────────────────────────────────────────

/// Link repo that returns a link mapping usr_standard → agent-1.
final _linkedRepo = MockUserLeadLinkRepository();

/// Link repo with no configured links.
final _noLinkRepo = MockUserLeadLinkRepository(links: {});

/// Link repo with stale mapping pointing to non-existent assignee.
final _staleLinkRepo = MockUserLeadLinkRepository(
  links: {'usr_standard': 'nonexistent-assignee'},
);

/// Default seeded lead repo containing agent-1 assignee + their leads.
final _leadRepo = MockLeadRepository();

Widget _buildTestApp(
  CurrentUser user, {
  UserLeadLinkRepository? linkRepo,
  LeadRepository? leadRepo,
  ThemeMode themeMode = ThemeMode.light,
}) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
    darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
    themeMode: themeMode,
    home: UserLeadWorkspaceScreen(
      user: user,
      linkRepository: linkRepo ?? _linkedRepo,
      leadRepository: leadRepo ?? _leadRepo,
    ),
  );
}

// ── User fixtures ──────────────────────────────────────────────────────────

const _userWithBothPerms = CurrentUser(
  id: 'usr_standard',
  displayName: 'Sales Rep',
  accountType: AccountType.user,
  modules: {CrmModule.leadManagement},
  permissions: {CrmPermissions.leadViewAssigned, CrmPermissions.leadUpdate},
);

const _userWithViewOnly = CurrentUser(
  id: 'usr_standard',
  displayName: 'Lead Viewer',
  accountType: AccountType.user,
  modules: {CrmModule.leadManagement},
  permissions: {CrmPermissions.leadViewAssigned},
);

const _userWithNoPerms = CurrentUser(
  id: 'usr_noop',
  displayName: 'No Op User',
  accountType: AccountType.user,
  modules: {CrmModule.leadManagement},
  permissions: {},
);

const _userWithUpdateOnly = CurrentUser(
  id: 'usr_update',
  displayName: 'Updater',
  accountType: AccountType.user,
  modules: {CrmModule.leadManagement},
  permissions: {CrmPermissions.leadUpdate},
);

const _userWithoutLeadModule = CurrentUser(
  id: 'usr_hr_only',
  displayName: 'HR Person',
  accountType: AccountType.user,
  modules: {CrmModule.hrPayroll},
  permissions: {CrmPermissions.hrView},
);

void main() {
  // ── AUTH-3A capability section ──────────────────────────────────────────

  group('UserLeadWorkspaceScreen - Permission Invariants (AUTH-3A section)', () {
    testWidgets(
      'Case A: User with View Assigned and Update permissions sees both capabilities',
      (tester) async {
        await tester.pumpWidget(_buildTestApp(_userWithBothPerms));
        await tester.pumpAndSettle();

        expect(find.byType(UserLeadWorkspaceScreen), findsOneWidget);
        expect(find.text('Lead Management'), findsOneWidget); // AppBar title
        expect(find.text('YOUR ACCESS'), findsOneWidget);
        expect(find.byKey(const Key('lead_perm_view_assigned')), findsOneWidget);
        expect(find.text('View assigned leads'), findsOneWidget);
        expect(find.byKey(const Key('lead_perm_update')), findsOneWidget);
        expect(find.text('Update leads'), findsOneWidget);
        expect(
          find.byKey(const Key('user_lead_update_without_view_warning')),
          findsNothing,
        );
        expect(find.byKey(const Key('user_lead_no_actions_message')), findsNothing);
      },
    );

    testWidgets(
      'Case B: User with View Assigned only sees view capability and no update',
      (tester) async {
        await tester.pumpWidget(_buildTestApp(_userWithViewOnly));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('lead_perm_view_assigned')), findsOneWidget);
        expect(find.text('View assigned leads'), findsOneWidget);
        expect(find.byKey(const Key('lead_perm_update')), findsNothing);
        expect(find.text('Update leads'), findsNothing);
      },
    );

    testWidgets(
      'Case C: User with Lead module but zero lead permissions sees no actions message',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(_userWithNoPerms, linkRepo: _noLinkRepo),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('user_lead_no_actions_message')),
          findsOneWidget,
        );
        expect(
          find.text(
            'You have access to this module, but no Lead actions have been assigned to your account.',
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('lead_perm_view_assigned')), findsNothing);
        expect(find.byKey(const Key('lead_perm_update')), findsNothing);
        // No lead list section shown when view perm absent
        expect(find.byKey(const Key('user_assigned_leads_list')), findsNothing);
      },
    );

    testWidgets(
      'Case D: User with Update but missing View Assigned sees defensive warning and no leads',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(_userWithUpdateOnly, linkRepo: _noLinkRepo),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('lead_perm_update')), findsOneWidget);
        expect(find.byKey(const Key('lead_perm_view_assigned')), findsNothing);
        expect(
          find.byKey(const Key('user_lead_update_without_view_warning')),
          findsOneWidget,
        );
        expect(
          find.text(
            'Viewing leads requires the view permission. Operational lead screens are unavailable without view permission.',
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('user_assigned_leads_list')), findsNothing);
      },
    );

    testWidgets(
      'Case E: Direct navigation without Lead Management module renders AccessRestrictedScreen',
      (tester) async {
        await tester.pumpWidget(_buildTestApp(_userWithoutLeadModule));
        await tester.pumpAndSettle();

        expect(find.byType(AccessRestrictedScreen), findsOneWidget);
        expect(find.text('Access Restricted'), findsOneWidget);
        expect(
          find.text('You do not have permission to access this area.'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('lead_perm_view_assigned')), findsNothing);
      },
    );

    testWidgets('Back button pops navigation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => UserLeadWorkspaceScreen(
                        user: _userWithViewOnly,
                        linkRepository: _linkedRepo,
                        leadRepository: _leadRepo,
                      ),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(UserLeadWorkspaceScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('user_lead_back_button')));
      await tester.pumpAndSettle();
      expect(find.byType(UserLeadWorkspaceScreen), findsNothing);
      expect(find.text('Open'), findsOneWidget);
    });
  });

  // ── AUTH-3B.1 lead list states ──────────────────────────────────────────

  group('UserLeadWorkspaceScreen - Assigned Lead States (AUTH-3B.1)', () {
    testWidgets(
      'No link configured → shows no-link info panel',
      (tester) async {
        await tester.pumpWidget(_buildTestApp(_userWithViewOnly, linkRepo: _noLinkRepo));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('user_assigned_leads_no_link')), findsOneWidget);
        expect(
          find.text(
            'Your account has not been linked to a lead assignee identity.',
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('user_assigned_leads_list')), findsNothing);
      },
    );

    testWidgets(
      'Stale link → shows invalid-link warning panel, getLeads not called',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(_userWithViewOnly, linkRepo: _staleLinkRepo),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('user_assigned_leads_invalid_link')), findsOneWidget);
        expect(
          find.text(
            'Lead assignment identity is not configured correctly for this account.',
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('user_assigned_leads_list')), findsNothing);
      },
    );

    testWidgets(
      'Valid link renders without error (loaded or empty based on seed)',
      (tester) async {
        // usr_standard → agent-1; default seed has agent-1 leads
        await tester.pumpWidget(
          _buildTestApp(
            const CurrentUser(
              id: 'usr_standard',
              displayName: 'User',
              accountType: AccountType.user,
              modules: {CrmModule.leadManagement},
              permissions: {CrmPermissions.leadViewAssigned},
            ),
            linkRepo: _linkedRepo,
            leadRepo: MockLeadRepository(),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Valid link with leads → shows read-only lead list',
      (tester) async {
        await tester.pumpWidget(_buildTestApp(_userWithViewOnly));
        await tester.pumpAndSettle();

        // Default seed: usr_standard → agent-1 (Aarav Sharma, Vikram Joshi)
        expect(find.byKey(const Key('user_assigned_leads_list')), findsOneWidget);
        expect(find.text('Aarav Sharma'), findsOneWidget);
        expect(find.text('Vikram Joshi'), findsOneWidget);
        // Verify the capability section is still shown above the list
        expect(find.text('YOUR ACCESS'), findsOneWidget);
        expect(find.text('MY ASSIGNED LEADS'), findsOneWidget);
      },
    );

    testWidgets(
      'Lead list shows no edit or create buttons — strictly read-only',
      (tester) async {
        await tester.pumpWidget(_buildTestApp(_userWithBothPerms));
        await tester.pumpAndSettle();

        // No action buttons that would allow mutation
        expect(find.byIcon(Icons.edit), findsNothing);
        expect(find.byIcon(Icons.add), findsNothing);
        expect(find.byIcon(Icons.person_add), findsNothing);
        expect(find.text('Edit'), findsNothing);
        expect(find.text('Assign'), findsNothing);
        expect(find.text('Create'), findsNothing);
      },
    );

    testWidgets(
      'Loading indicator visible before resolution completes',
      (tester) async {
        // Use a link repo that delays to catch loading state
        await tester.pumpWidget(_buildTestApp(_userWithViewOnly));
        // pump once without settling to catch the loading frame
        await tester.pump();
        expect(find.byKey(const Key('user_assigned_leads_loading')), findsOneWidget);
        await tester.pumpAndSettle();
      },
    );
  });

  // ── Responsiveness ─────────────────────────────────────────────────────

  group('UserLeadWorkspaceScreen - Responsiveness & Theme', () {
    for (final size in const [
      Size(320, 568),
      Size(360, 640),
      Size(768, 1024),
      Size(1200, 800),
    ]) {
      testWidgets('Renders cleanly on ${size.width}x${size.height}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_buildTestApp(_userWithBothPerms));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(UserLeadWorkspaceScreen), findsOneWidget);
      });
    }

    testWidgets('Renders cleanly in dark theme', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(_userWithBothPerms, themeMode: ThemeMode.dark),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(UserLeadWorkspaceScreen), findsOneWidget);
    });
  });
}
