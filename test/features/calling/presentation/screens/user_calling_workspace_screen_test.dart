import 'package:enterprise_crm/features/auth/data/repositories/mock_user_lead_link_repository.dart';
import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/auth/presentation/screens/access_restricted_screen.dart';
import 'package:enterprise_crm/features/calling/data/repositories/mock_lead_call_activity_repository.dart';
import 'package:enterprise_crm/features/calling/presentation/screens/user_calling_workspace_screen.dart';
import 'package:enterprise_crm/features/dashboard/presentation/screens/user_lead_workspace_screen.dart';
import 'package:enterprise_crm/features/leads/data/repositories/mock_lead_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const userWithCallingAndLeads = CurrentUser(
    id: 'usr_standard',
    displayName: 'Caller Rep',
    accountType: AccountType.user,
    modules: {CrmModule.calling, CrmModule.leadManagement},
    permissions: {CrmPermissions.callingUse, CrmPermissions.leadViewAssigned},
  );

  const userWithCallingOnly = CurrentUser(
    id: 'usr_calling_only',
    displayName: 'Calling Only Rep',
    accountType: AccountType.user,
    modules: {CrmModule.calling},
    permissions: {CrmPermissions.callingUse},
  );

  const userWithoutCallingPerm = CurrentUser(
    id: 'usr_no_calling_perm',
    displayName: 'No Calling Perm',
    accountType: AccountType.user,
    modules: {CrmModule.calling},
    permissions: {},
  );

  const userWithoutCallingModule = CurrentUser(
    id: 'usr_no_calling_mod',
    displayName: 'No Calling Module',
    accountType: AccountType.user,
    modules: {CrmModule.leadManagement},
    permissions: {CrmPermissions.callingUse},
  );

  late MockLeadRepository leadRepo;
  late MockUserLeadLinkRepository linkRepo;
  late MockLeadCallActivityRepository callActivityRepo;

  setUp(() {
    leadRepo = MockLeadRepository();
    linkRepo = MockUserLeadLinkRepository();
    callActivityRepo = MockLeadCallActivityRepository();
  });

  Widget buildTestApp({
    CurrentUser? user,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      themeMode: themeMode,
      home: UserCallingWorkspaceScreen(
        user: user ?? userWithCallingAndLeads,
        leadRepository: leadRepo,
        linkRepository: linkRepo,
        callActivityRepository: callActivityRepo,
      ),
    );
  }

  group('UserCallingWorkspaceScreen - Access & Presentation', () {
    testWidgets(
      'authorized user with lead view access sees full workspace and Open My Assigned Leads button',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        expect(find.byType(UserCallingWorkspaceScreen), findsOneWidget);
        expect(find.text('Calling'), findsOneWidget);
        expect(find.text('CALLING'), findsOneWidget);
        expect(
          find.byKey(const Key('user_calling_status_enabled')),
          findsOneWidget,
        );
        expect(find.text('Calling access is enabled.'), findsOneWidget);
        expect(
          find.byKey(const Key('user_calling_manage_from_leads_message')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('user_calling_open_leads_button')),
          findsOneWidget,
        );
        expect(find.text('Open My Assigned Leads'), findsOneWidget);
      },
    );

    testWidgets(
      'authorized user without lead view access sees no lead access message and NO button',
      (tester) async {
        await tester.pumpWidget(buildTestApp(user: userWithCallingOnly));
        await tester.pumpAndSettle();

        expect(find.byType(UserCallingWorkspaceScreen), findsOneWidget);
        expect(find.text('CALLING'), findsOneWidget);
        expect(
          find.byKey(const Key('user_calling_status_enabled')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('user_calling_no_lead_access_message')),
          findsOneWidget,
        );
        expect(
          find.text(
            'Calling access is enabled, but no Lead viewing access has been assigned to your account.',
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('user_calling_open_leads_button')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'user lacking calling.use permission renders AccessRestrictedScreen',
      (tester) async {
        await tester.pumpWidget(buildTestApp(user: userWithoutCallingPerm));
        await tester.pumpAndSettle();

        expect(find.byType(AccessRestrictedScreen), findsOneWidget);
        expect(find.text('CALLING'), findsNothing);
      },
    );

    testWidgets('user lacking Calling module renders AccessRestrictedScreen', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp(user: userWithoutCallingModule));
      await tester.pumpAndSettle();

      expect(find.byType(AccessRestrictedScreen), findsOneWidget);
      expect(find.text('CALLING'), findsNothing);
    });
  });

  group('UserCallingWorkspaceScreen - Navigation & Repository Invariance', () {
    testWidgets(
      'tapping Open My Assigned Leads pushes UserLeadWorkspaceScreen retaining shared repositories',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('user_calling_open_leads_button')),
        );
        await tester.pumpAndSettle();

        // Verified: UserLeadWorkspaceScreen is opened
        expect(find.byType(UserLeadWorkspaceScreen), findsOneWidget);
        final leadWorkspace = tester.widget<UserLeadWorkspaceScreen>(
          find.byType(UserLeadWorkspaceScreen),
        );

        // Invariant: Exact same repository instances passed through
        expect(identical(leadWorkspace.leadRepository, leadRepo), isTrue);
        expect(identical(leadWorkspace.linkRepository, linkRepo), isTrue);
        expect(
          identical(leadWorkspace.callActivityRepository, callActivityRepo),
          isTrue,
        );
      },
    );

    testWidgets('tapping back button pops navigation', (tester) async {
      bool popped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => UserCallingWorkspaceScreen(
                        user: userWithCallingAndLeads,
                        leadRepository: leadRepo,
                        linkRepository: linkRepo,
                        callActivityRepository: callActivityRepo,
                      ),
                    ),
                  );
                  popped = true;
                },
                child: const Text('Open Calling'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Calling'));
      await tester.pumpAndSettle();

      expect(find.byType(UserCallingWorkspaceScreen), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('user_calling_workspace_back_button')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(UserCallingWorkspaceScreen), findsNothing);
      expect(popped, isTrue);
    });
  });

  group('UserCallingWorkspaceScreen - Responsive & Theme Tests', () {
    testWidgets('renders cleanly across 4 viewports without overflow', (
      tester,
    ) async {
      const viewports = [
        Size(320, 568),
        Size(360, 640),
        Size(768, 1024),
        Size(1200, 800),
      ];

      for (final size in viewports) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        expect(find.text('CALLING'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('renders cleanly in dark mode', (tester) async {
      await tester.pumpWidget(buildTestApp(themeMode: ThemeMode.dark));
      await tester.pumpAndSettle();

      expect(find.text('CALLING'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
