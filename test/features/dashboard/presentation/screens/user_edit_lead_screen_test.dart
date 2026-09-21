import 'package:enterprise_crm/features/auth/data/repositories/mock_user_lead_link_repository.dart';
import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/auth/presentation/screens/access_restricted_screen.dart';
import 'package:enterprise_crm/features/dashboard/presentation/screens/user_edit_lead_screen.dart';
import 'package:enterprise_crm/features/leads/data/datasources/mock_lead_data_source.dart';
import 'package:enterprise_crm/features/leads/data/repositories/mock_lead_repository.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_assignee.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_assignment_request.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_draft.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_export.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_import.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_page.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_query.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_status.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_summary.dart';
import 'package:enterprise_crm/features/leads/domain/repositories/lead_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final testLead = Lead(
    id: 'lead-edit-1',
    name: 'Original Lead Name',
    phone: '+1 555-0100',
    email: 'orig@example.com',
    status: const LeadStatus('In Progress'),
    source: LeadSource.manual,
    assignedUserId: 'agent-1',
    assignedUserName: 'Sarah Jenkins',
    createdAt: DateTime(2025, 1, 15, 10, 0),
    updatedAt: DateTime(2025, 1, 15, 10, 0),
  );

  final crossAssigneeLead = Lead(
    id: 'lead-cross-1',
    name: 'Cross Lead',
    phone: '+1 555-0200',
    email: 'cross@example.com',
    status: const LeadStatus('New'),
    source: LeadSource.excel,
    assignedUserId: 'agent-2',
    assignedUserName: 'Mike Ross',
    createdAt: DateTime(2025, 1, 10),
  );

  late MockLeadRepository leadRepo;
  late MockUserLeadLinkRepository linkRepo;

  setUp(() {
    leadRepo = MockLeadRepository(
      dataSource: MockLeadDataSource(
        initialLeads: [testLead, crossAssigneeLead],
      ),
    );
    linkRepo = MockUserLeadLinkRepository(links: {'usr_standard': 'agent-1'});
  });

  const userWithBothPerms = CurrentUser(
    id: 'usr_standard',
    displayName: 'Sales Rep',
    accountType: AccountType.user,
    modules: {CrmModule.leadManagement},
    permissions: {CrmPermissions.leadViewAssigned, CrmPermissions.leadUpdate},
  );

  const userWithViewOnly = CurrentUser(
    id: 'usr_standard',
    displayName: 'Lead Viewer',
    accountType: AccountType.user,
    modules: {CrmModule.leadManagement},
    permissions: {CrmPermissions.leadViewAssigned},
  );

  const userWithoutLeadModule = CurrentUser(
    id: 'usr_standard',
    displayName: 'HR Person',
    accountType: AccountType.user,
    modules: {CrmModule.hrPayroll},
    permissions: {CrmPermissions.leadViewAssigned, CrmPermissions.leadUpdate},
  );

  Widget buildTestApp({
    required CurrentUser user,
    required String leadId,
    Lead? initialLead,
    LeadRepository? customLeadRepo,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      themeMode: themeMode,
      home: UserEditLeadScreen(
        user: user,
        leadId: leadId,
        initialLead: initialLead,
        linkRepository: linkRepo,
        leadRepository: customLeadRepo ?? leadRepo,
      ),
    );
  }

  group('UserEditLeadScreen - Form Presentation & Field Boundaries', () {
    testWidgets(
      'Prefills permitted fields and displays read-only status/source/assignee chips',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            user: userWithBothPerms,
            leadId: testLead.id,
            initialLead: testLead,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(UserEditLeadScreen), findsOneWidget);
        expect(find.text('Edit Lead'), findsOneWidget);

        // Editable fields prefilled
        expect(find.byKey(const Key('user_edit_lead_name')), findsOneWidget);
        expect(find.text('Original Lead Name'), findsOneWidget);
        expect(find.byKey(const Key('user_edit_lead_phone')), findsOneWidget);
        expect(find.text('+1 555-0100'), findsOneWidget);
        expect(find.byKey(const Key('user_edit_lead_email')), findsOneWidget);
        expect(find.text('orig@example.com'), findsOneWidget);

        // Read-only chips
        expect(find.text('Status: In Progress'), findsOneWidget);
        expect(find.text('Assigned: Sarah Jenkins'), findsOneWidget);
        expect(find.text('Source: Manual'), findsOneWidget);

        // No dropdowns or inputs for status or assignee
        expect(find.byType(DropdownButtonFormField), findsNothing);
        expect(find.byType(DropdownMenu), findsNothing);

        // Save button is initially disabled (pristine)
        final saveButton = tester.widget<FilledButton>(
          find.byKey(const Key('user_edit_lead_save')),
        );
        expect(saveButton.onPressed, isNull);
      },
    );

    testWidgets('Cancel button pops screen without any update', (tester) async {
      bool popped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => UserEditLeadScreen(
                          user: userWithBothPerms,
                          leadId: testLead.id,
                          initialLead: testLead,
                          linkRepository: linkRepo,
                          leadRepository: leadRepo,
                        ),
                      ),
                    );
                    popped = true;
                  },
                  child: const Text('Launch Edit'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Launch Edit'));
      await tester.pumpAndSettle();

      expect(find.byType(UserEditLeadScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('user_edit_lead_cancel_button')));
      await tester.pumpAndSettle();

      expect(find.byType(UserEditLeadScreen), findsNothing);
      expect(popped, isTrue);
    });
  });

  group('UserEditLeadScreen - Authorization & Ownership Guards', () {
    testWidgets(
      'Direct route attack to cross-assignee lead renders AccessRestrictedScreen',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            user: userWithBothPerms,
            leadId: crossAssigneeLead.id,
            initialLead: crossAssigneeLead,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AccessRestrictedScreen), findsOneWidget);
        expect(find.byKey(const Key('user_edit_lead_save')), findsNothing);
      },
    );

    testWidgets(
      'User with view-only permission (missing lead.update) renders AccessRestrictedScreen',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            user: userWithViewOnly,
            leadId: testLead.id,
            initialLead: testLead,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AccessRestrictedScreen), findsOneWidget);
        expect(find.byKey(const Key('user_edit_lead_save')), findsNothing);
      },
    );

    testWidgets('User lacking lead module renders AccessRestrictedScreen', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          user: userWithoutLeadModule,
          leadId: testLead.id,
          initialLead: testLead,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AccessRestrictedScreen), findsOneWidget);
    });
  });

  group('UserEditLeadScreen - Save Mutation & Fresh Re-fetch Ownership', () {
    testWidgets('Valid save: edits name, saves, and returns updated lead', (
      tester,
    ) async {
      Lead? returnedLead;
      await tester.pumpWidget(
        MaterialApp(
          home: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    returnedLead = await Navigator.of(context).push<Lead>(
                      MaterialPageRoute(
                        builder: (_) => UserEditLeadScreen(
                          user: userWithBothPerms,
                          leadId: testLead.id,
                          initialLead: testLead,
                          linkRepository: linkRepo,
                          leadRepository: leadRepo,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Edit'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Edit'));
      await tester.pumpAndSettle();

      // Enter new name
      await tester.enterText(
        find.byKey(const Key('user_edit_lead_name')),
        'Updated Lead Name',
      );
      await tester.pump();

      // Save button should now be enabled
      final saveBtn = tester.widget<FilledButton>(
        find.byKey(const Key('user_edit_lead_save')),
      );
      expect(saveBtn.onPressed, isNotNull);

      // Tap Save
      await tester.tap(find.byKey(const Key('user_edit_lead_save')));
      await tester.pumpAndSettle();

      // Popped back with updated lead
      expect(find.byType(UserEditLeadScreen), findsNothing);
      expect(returnedLead, isNotNull);
      expect(returnedLead!.name, 'Updated Lead Name');
      // Immutable fields intact
      expect(returnedLead!.id, testLead.id);
      expect(returnedLead!.assignedUserId, 'agent-1');
      expect(returnedLead!.status, testLead.status);
      expect(returnedLead!.source, testLead.source);
    });

    testWidgets(
      'Reassignment while form open blocks update with Access Restricted and 0 updateLead calls',
      (tester) async {
        final spyRepo = _ReassignOnSaveLeadRepository(
          initialLead: testLead,
          reassignedLead: testLead.copyWith(
            assignedUserId: 'agent-2',
            assignedUserName: 'Mike Ross',
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: UserEditLeadScreen(
              user: userWithBothPerms,
              leadId: testLead.id,
              initialLead: testLead,
              linkRepository: linkRepo,
              leadRepository: spyRepo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Modify a field to enable save
        await tester.enterText(
          find.byKey(const Key('user_edit_lead_name')),
          'Attempted Hijack Name',
        );
        await tester.pump();

        // Admin reassigns lead while user has form open
        spyRepo.isReassigned = true;

        // Tap Save
        await tester.tap(find.byKey(const Key('user_edit_lead_save')));
        await tester.pumpAndSettle();

        // Ownership changed on fresh re-fetch -> Access Restricted Screen shown!
        expect(find.byType(AccessRestrictedScreen), findsOneWidget);
        // updateLead must NEVER have been called!
        expect(spyRepo.updateCallCount, 0);
      },
    );

    testWidgets('Invalid email prevents submit', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          user: userWithBothPerms,
          leadId: testLead.id,
          initialLead: testLead,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('user_edit_lead_email')),
        'invalid-email-no-at-sign',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('user_edit_lead_save')));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address'), findsOneWidget);
    });
  });

  group('UserEditLeadScreen - Responsive Layouts & Dark Mode', () {
    const screenSizes = [
      Size(360, 640),
      Size(768, 1024),
      Size(1280, 800),
      Size(1920, 1080),
    ];

    for (final size in screenSizes) {
      testWidgets('Renders cleanly on ${size.width}x${size.height}', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          buildTestApp(
            user: userWithBothPerms,
            leadId: testLead.id,
            initialLead: testLead,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(UserEditLeadScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Renders cleanly in dark theme', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          user: userWithBothPerms,
          leadId: testLead.id,
          initialLead: testLead,
          themeMode: ThemeMode.dark,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(UserEditLeadScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

/// Repository that simulates an admin reassigning the lead while the edit form is open.
/// On initial load it returns the user's lead, but on subsequent getLeadById calls
/// (like the fresh re-fetch before save), it returns the reassigned lead.
class _ReassignOnSaveLeadRepository implements LeadRepository {
  final Lead initialLead;
  final Lead reassignedLead;
  bool isReassigned = false;
  int updateCallCount = 0;

  _ReassignOnSaveLeadRepository({
    required this.initialLead,
    required this.reassignedLead,
  });

  @override
  Future<Lead?> getLeadById(String leadId) async {
    return isReassigned ? reassignedLead : initialLead;
  }

  @override
  Future<List<LeadAssignee>> getAssignableUsers() async => const [
    LeadAssignee(id: 'agent-1', displayName: 'Agent 1'),
    LeadAssignee(id: 'agent-2', displayName: 'Agent 2'),
  ];

  @override
  Future<Lead> updateLead(UpdateLeadInput input) async {
    updateCallCount++;
    return initialLead;
  }

  @override
  Future<LeadPage> getLeads([LeadQuery query = const LeadQuery()]) =>
      throw UnimplementedError();

  @override
  Future<LeadSummary> getLeadSummary() => throw UnimplementedError();

  @override
  Future<Lead> createLead(CreateLeadInput input) => throw UnimplementedError();

  @override
  Future<void> assignLead({
    required String leadId,
    required String assigneeId,
  }) => throw UnimplementedError();

  @override
  Future<void> assignLeads(LeadAssignmentRequest request) =>
      throw UnimplementedError();

  @override
  Future<void> reassignLead(LeadReassignmentRequest request) =>
      throw UnimplementedError();

  @override
  Future<LeadImportResult> importLeads(LeadImportRequest request) =>
      throw UnimplementedError();

  @override
  Future<LeadExportResult> exportLeads(LeadExportRequest request) =>
      throw UnimplementedError();
}
