import 'package:enterprise_crm/features/auth/data/repositories/mock_user_lead_link_repository.dart';
import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/auth/presentation/screens/access_restricted_screen.dart';
import 'package:enterprise_crm/features/dashboard/presentation/screens/user_edit_lead_screen.dart';
import 'package:enterprise_crm/features/dashboard/presentation/screens/user_lead_details_screen.dart';
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
    id: 'lead-user-1',
    name: 'Alice Johnson',
    phone: '+1 555-0100',
    email: 'alice@example.com',
    status: const LeadStatus('Contacted'),
    source: LeadSource.manual,
    assignedUserId: 'agent-1',
    assignedUserName: 'Sarah Jenkins',
    createdAt: DateTime(2025, 1, 15, 10, 30),
    updatedAt: DateTime(2025, 1, 16, 14, 00),
  );

  final crossAssigneeLead = Lead(
    id: 'lead-other-1',
    name: 'Bob Smith',
    phone: '+1 555-0200',
    email: 'bob@example.com',
    status: const LeadStatus('New'),
    source: LeadSource.excel,
    assignedUserId: 'agent-2',
    assignedUserName: 'Mike Ross',
    createdAt: DateTime(2025, 1, 10),
  );

  final unassignedLead = Lead(
    id: 'lead-unassigned-1',
    name: 'Charlie Brown',
    phone: '+1 555-0300',
    status: const LeadStatus('New'),
    source: LeadSource.csv,
    createdAt: DateTime(2025, 1, 12),
  );

  late MockLeadRepository leadRepo;
  late MockUserLeadLinkRepository linkRepo;

  setUp(() {
    leadRepo = MockLeadRepository(
      dataSource: MockLeadDataSource(
        initialLeads: [testLead, crossAssigneeLead, unassignedLead],
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

  const userWithoutViewPerm = CurrentUser(
    id: 'usr_standard',
    displayName: 'Update Only',
    accountType: AccountType.user,
    modules: {CrmModule.leadManagement},
    permissions: {CrmPermissions.leadUpdate},
  );

  Widget buildTestApp({
    required CurrentUser user,
    required String leadId,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      themeMode: themeMode,
      home: UserLeadDetailsScreen(
        user: user,
        leadId: leadId,
        linkRepository: linkRepo,
        leadRepository: leadRepo,
      ),
    );
  }

  group('UserLeadDetailsScreen - Authorization and Ownership Guards', () {
    testWidgets(
      'User with view + update on own lead sees details and Edit button',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(user: userWithBothPerms, leadId: 'lead-user-1'),
        );
        await tester.pumpAndSettle();

        expect(find.byType(UserLeadDetailsScreen), findsOneWidget);
        expect(find.text('Lead Details'), findsOneWidget);
        expect(find.byKey(const Key('user_lead_details_name')), findsOneWidget);
        expect(find.text('Alice Johnson'), findsOneWidget);
        expect(find.text('+1 555-0100'), findsOneWidget);
        expect(find.text('alice@example.com'), findsOneWidget);
        expect(find.text('Contacted'), findsOneWidget);
        expect(find.text('Sarah Jenkins'), findsOneWidget);
        expect(find.text('Manual'), findsOneWidget);

        // Edit button must be present
        expect(find.byKey(const Key('user_lead_edit_button')), findsOneWidget);
        expect(find.text('Edit Lead'), findsOneWidget);
      },
    );

    testWidgets(
      'User with view-only on own lead sees details but NO Edit button',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(user: userWithViewOnly, leadId: 'lead-user-1'),
        );
        await tester.pumpAndSettle();

        expect(find.byType(UserLeadDetailsScreen), findsOneWidget);
        expect(find.text('Alice Johnson'), findsOneWidget);

        // Edit button must NOT be present
        expect(find.byKey(const Key('user_lead_edit_button')), findsNothing);
        expect(find.text('Edit Lead'), findsNothing);
      },
    );

    testWidgets('User lacking lead module renders AccessRestrictedScreen', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(user: userWithoutLeadModule, leadId: 'lead-user-1'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AccessRestrictedScreen), findsOneWidget);
      expect(find.byKey(const Key('user_lead_edit_button')), findsNothing);
    });

    testWidgets(
      'User lacking view_assigned permission renders AccessRestrictedScreen',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(user: userWithoutViewPerm, leadId: 'lead-user-1'),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AccessRestrictedScreen), findsOneWidget);
        expect(find.byKey(const Key('user_lead_edit_button')), findsNothing);
      },
    );

    testWidgets(
      'Direct route attack to cross-assignee lead renders AccessRestrictedScreen',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(user: userWithBothPerms, leadId: 'lead-other-1'),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AccessRestrictedScreen), findsOneWidget);
        expect(find.text('Bob Smith'), findsNothing);
        expect(find.byKey(const Key('user_lead_edit_button')), findsNothing);
      },
    );

    testWidgets(
      'Direct route attack to unassigned lead renders AccessRestrictedScreen',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(user: userWithBothPerms, leadId: 'lead-unassigned-1'),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AccessRestrictedScreen), findsOneWidget);
        expect(find.text('Charlie Brown'), findsNothing);
        expect(find.byKey(const Key('user_lead_edit_button')), findsNothing);
      },
    );

    testWidgets('Non-existent lead renders AccessRestrictedScreen', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(user: userWithBothPerms, leadId: 'lead-missing'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AccessRestrictedScreen), findsOneWidget);
    });

    testWidgets('Repository error renders failure message with Retry', (
      tester,
    ) async {
      final failingRepo = _FailingLeadRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: UserLeadDetailsScreen(
            user: userWithBothPerms,
            leadId: 'lead-user-1',
            linkRepository: linkRepo,
            leadRepository: failingRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Network timeout'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('UserLeadDetailsScreen - Navigation and Interactivity', () {
    testWidgets('Back button pops navigation', (tester) async {
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
                        builder: (_) => UserLeadDetailsScreen(
                          user: userWithBothPerms,
                          leadId: 'lead-user-1',
                          linkRepository: linkRepo,
                          leadRepository: leadRepo,
                        ),
                      ),
                    );
                    popped = true;
                  },
                  child: const Text('Open Details'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Details'));
      await tester.pumpAndSettle();

      expect(find.byType(UserLeadDetailsScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('user_lead_details_back_button')));
      await tester.pumpAndSettle();

      expect(find.byType(UserLeadDetailsScreen), findsNothing);
      expect(popped, isTrue);
    });

    testWidgets('Tapping Edit button opens UserEditLeadScreen', (tester) async {
      await tester.pumpWidget(
        buildTestApp(user: userWithBothPerms, leadId: 'lead-user-1'),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('user_lead_edit_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('user_lead_edit_button')));
      await tester.pumpAndSettle();

      expect(find.byType(UserEditLeadScreen), findsOneWidget);
      expect(find.text('Edit Lead'), findsOneWidget);
    });
  });

  group('UserLeadDetailsScreen - Responsive Layouts & Dark Mode', () {
    const screenSizes = [
      Size(360, 640), // Mobile
      Size(768, 1024), // Tablet
      Size(1280, 800), // Desktop
      Size(1920, 1080), // Widescreen
    ];

    for (final size in screenSizes) {
      testWidgets(
        'Renders cleanly without overflow on ${size.width}x${size.height}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            buildTestApp(user: userWithBothPerms, leadId: 'lead-user-1'),
          );
          await tester.pumpAndSettle();

          expect(find.byType(UserLeadDetailsScreen), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('Renders cleanly in dark theme', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          user: userWithBothPerms,
          leadId: 'lead-user-1',
          themeMode: ThemeMode.dark,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(UserLeadDetailsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

class _FailingLeadRepository implements LeadRepository {
  @override
  Future<Lead?> getLeadById(String leadId) =>
      throw Exception('Network timeout');

  @override
  Future<List<LeadAssignee>> getAssignableUsers() async => const [
    LeadAssignee(id: 'agent-1', displayName: 'Agent 1'),
  ];

  @override
  Future<Lead> updateLead(UpdateLeadInput input) => throw UnimplementedError();

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
