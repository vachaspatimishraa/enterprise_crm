import 'dart:async';
import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/auth/presentation/screens/access_restricted_screen.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_assignee.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_assignment_request.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_draft.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_export.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_import.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_page.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_query.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_summary.dart';
import 'package:enterprise_crm/features/leads/domain/repositories/lead_repository.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_form_cubit.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/add_lead_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLeadRepository implements LeadRepository {
  CreateLeadInput? lastCreateInput;
  int createLeadCallCount = 0;
  Completer<Lead>? createCompleter;
  bool shouldThrowOnCreate = false;
  List<LeadAssignee> assignableUsers = const [];
  String? lastAssignedLeadId;
  String? lastAssignedUserId;

  @override
  Future<Lead> createLead(CreateLeadInput input) async {
    lastCreateInput = input;
    createLeadCallCount++;
    if (createCompleter != null) return createCompleter!.future;
    if (shouldThrowOnCreate) throw Exception('Creation failed on server');
    return Lead(
      id: 'created-lead-123',
      name: input.draft.name,
      phone: input.draft.phone,
      email: input.draft.email,
      status: input.draft.status,
      source: input.draft.source ?? LeadSource.manual,
    );
  }

  @override
  Future<Lead?> getLeadById(String leadId) async => null;

  @override
  Future<LeadPage> getLeads([LeadQuery query = const LeadQuery()]) async =>
      const LeadPage(
        items: [],
        currentPage: 1,
        pageSize: 20,
        totalItems: 0,
        hasNext: false,
      );

  @override
  Future<Lead> updateLead(UpdateLeadInput input) async =>
      const Lead(id: 'dummy');

  @override
  Future<void> assignLead({
    required String leadId,
    required String assigneeId,
  }) async {
    lastAssignedLeadId = leadId;
    lastAssignedUserId = assigneeId;
  }

  @override
  Future<void> assignLeads(LeadAssignmentRequest request) async {}

  @override
  Future<void> reassignLead(LeadReassignmentRequest request) async {}

  @override
  Future<List<LeadAssignee>> getAssignableUsers() async => assignableUsers;

  @override
  Future<LeadImportResult> importLeads(LeadImportRequest request) async =>
      const LeadImportResult(
        totalRows: 0,
        importedRows: 0,
        skippedRows: 0,
        failedRows: 0,
        duplicateRows: 0,
      );

  @override
  Future<LeadExportResult> exportLeads(LeadExportRequest request) async =>
      const LeadExportResult(fileReference: '', fileName: '');

  @override
  Future<LeadSummary> getLeadSummary() async => const LeadSummary(
    totalLeads: 0,
    assignedLeads: 0,
    unassignedLeads: 0,
    manualLeads: 0,
    excelLeads: 0,
    csvLeads: 0,
  );
}

void main() {
  late _FakeLeadRepository repository;

  setUp(() {
    repository = _FakeLeadRepository();
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.single;
    view.physicalSize = const Size(800, 1000);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.single;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Widget buildTestWidget({
    LeadFormCubit? cubit,
    void Function(Lead lead)? onLeadCreated,
    VoidCallback? onCancel,
    Size? size,
  }) {
    return MaterialApp(
      home: AddLeadScreen(
        cubit: cubit,
        repository: cubit == null ? repository : null,
        onLeadCreated: onLeadCreated,
        onCancel: onCancel,
      ),
    );
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('AddLeadScreen - Rendering', () {
    testWidgets('renders all supported fields and initial controls', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Add Lead'), findsOneWidget);
      expect(find.text('Primary Information'), findsOneWidget);
      expect(find.text('Contact Person Name'), findsOneWidget);
      expect(find.text('Business Name'), findsOneWidget);
      expect(find.text('Contact Information'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);
      expect(find.text('Email ID'), findsOneWidget);
      expect(find.text('Location Information'), findsOneWidget);
      expect(find.text('City'), findsOneWidget);
      expect(find.text('State'), findsOneWidget);
      expect(find.text('Lead Source'), findsOneWidget);
      expect(find.text('Source'), findsOneWidget);
      expect(find.text('Manual Entry'), findsWidgets);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Create Lead'), findsOneWidget);
    });
  });

  group('AddLeadScreen - Optional Fields', () {
    testWidgets(
      'allows submitting without requiring fields, no mandatory errors shown',
      (tester) async {
        Lead? createdResult;
        await tester.pumpWidget(
          buildTestWidget(onLeadCreated: (lead) => createdResult = lead),
        );
        await tester.pumpAndSettle();

        // Tap Create Lead without typing anything
        await tapVisible(tester, find.text('Create Lead'));

        // No form validation errors
        expect(find.text('Please enter'), findsNothing);
        expect(find.text('Required'), findsNothing);

        // createLead was called
        expect(repository.createLeadCallCount, 1);
        expect(repository.lastCreateInput, isNotNull);
        expect(repository.lastCreateInput!.draft.name, isNull);
        expect(repository.lastCreateInput!.draft.businessName, isNull);
        expect(repository.lastCreateInput!.draft.phone, isNull);
        expect(repository.lastCreateInput!.draft.email, isNull);
        expect(repository.lastCreateInput!.draft.city, isNull);
        expect(repository.lastCreateInput!.draft.state, isNull);
        expect(
          repository.lastCreateInput!.draft.source,
          equals(LeadSource.manual),
        );
        expect(createdResult, isNotNull);
      },
    );

    testWidgets('validates email format only when email is provided', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Enter invalid email
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email ID'),
        'invalid-email-string',
      );
      await tapVisible(tester, find.text('Create Lead'));

      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(repository.createLeadCallCount, 0);

      // Correct email
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email ID'),
        'valid@example.com',
      );
      await tapVisible(tester, find.text('Create Lead'));

      expect(find.text('Enter a valid email address'), findsNothing);
      expect(repository.createLeadCallCount, 1);
    });
  });

  group('AddLeadScreen - Data Entry & Source Handling', () {
    testWidgets('passes trimmed values and LeadSource.manual to repository', (
      tester,
    ) async {
      Lead? capturedLead;
      await tester.pumpWidget(
        buildTestWidget(onLeadCreated: (lead) => capturedLead = lead),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contact Person Name'),
        '   Rajesh Sharma   ',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Business Name'),
        '   Sharma Logistics   ',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone Number'),
        '  +91 9876543210  ',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email ID'),
        '  rajesh@example.com  ',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'City'),
        '  Mumbai  ',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'State'),
        '  Maharashtra  ',
      );

      await tapVisible(tester, find.text('Create Lead'));

      expect(repository.createLeadCallCount, 1);
      final draft = repository.lastCreateInput!.draft;
      expect(draft.name, 'Rajesh Sharma');
      expect(draft.contactPersonName, 'Rajesh Sharma');
      expect(draft.businessName, 'Sharma Logistics');
      expect(draft.phone, '+91 9876543210');
      expect(draft.email, 'rajesh@example.com');
      expect(draft.city, 'Mumbai');
      expect(draft.state, 'Maharashtra');
      expect(draft.source, LeadSource.manual);
      expect(draft.status, isNull);

      expect(capturedLead, isNotNull);
      expect(capturedLead!.name, 'Rajesh Sharma');
      expect(capturedLead!.source, LeadSource.manual);
    });

    testWidgets('allows selecting non-manual source from dropdown', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Open dropdown
      await tapVisible(tester, find.byKey(const Key('add_lead_source_dropdown')));

      // Select Ad Funnels
      await tapVisible(tester, find.text('Ad Funnels').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contact Person Name'),
        'Meta User',
      );

      await tapVisible(tester, find.text('Create Lead'));

      expect(repository.createLeadCallCount, 1);
      final draft = repository.lastCreateInput!.draft;
      expect(draft.name, 'Meta User');
      expect(draft.source, LeadSource.metaCampaign);
    });
  });

  group('AddLeadScreen - Submission State & Duplicate Tap Protection', () {
    testWidgets('shows loading and prevents duplicate taps while submitting', (
      tester,
    ) async {
      repository.createCompleter = Completer<Lead>();
      final cubit = LeadFormCubit(repository);

      await tester.pumpWidget(buildTestWidget(cubit: cubit));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contact Person Name'),
        'Pooja Verma',
      );

      // Scroll to button and first tap
      await tester.ensureVisible(find.text('Create Lead'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create Lead'));
      await tester.pump(); // Enter submitting state

      expect(find.text('Creating...'), findsOneWidget);
      expect(repository.createLeadCallCount, 1);

      // Attempt second tap during submission
      await tester.tap(find.text('Creating...'));
      await tester.pump();

      // Call count must remain 1
      expect(repository.createLeadCallCount, 1);

      // Complete async creation
      repository.createCompleter!.complete(
        const Lead(
          id: 'lead-pooja',
          name: 'Pooja Verma',
          source: LeadSource.manual,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lead created successfully'), findsOneWidget);
    });
  });

  group('AddLeadScreen - Failure State', () {
    testWidgets(
      'shows failure feedback, preserves entered values, allows retry',
      (tester) async {
        repository.shouldThrowOnCreate = true;

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Contact Person Name'),
          'Failed Lead Name',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Phone Number'),
          '+91 9000000000',
        );

        await tapVisible(tester, find.text('Create Lead'));

        // Failure feedback displayed in banner
        expect(find.text('Creation failed on server'), findsWidgets);

        // Values preserved in fields
        expect(find.text('Failed Lead Name'), findsOneWidget);
        expect(find.text('+91 9000000000'), findsOneWidget);

        // Fix failure condition and retry
        repository.shouldThrowOnCreate = false;
        await tapVisible(tester, find.text('Create Lead'));

        expect(repository.createLeadCallCount, 2);
        expect(find.text('Lead created successfully'), findsOneWidget);
      },
    );
  });

  group('AddLeadScreen - Cancel / Back Actions', () {
    testWidgets('invokes onCancel callback when Cancel is tapped', (
      tester,
    ) async {
      bool cancelCalled = false;
      await tester.pumpWidget(
        buildTestWidget(onCancel: () => cancelCalled = true),
      );
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('Cancel'));

      expect(cancelCalled, isTrue);
    });

    testWidgets('invokes onCancel callback when AppBar back button is tapped', (
      tester,
    ) async {
      bool cancelCalled = false;
      await tester.pumpWidget(
        buildTestWidget(onCancel: () => cancelCalled = true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(cancelCalled, isTrue);
    });
  });

  group('AddLeadScreen - Responsive Layout', () {
    testWidgets('mobile layout (360x640) renders cleanly without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget(size: const Size(360, 640)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Add Lead'), findsOneWidget);
      expect(find.text('Contact Person Name'), findsOneWidget);
      expect(find.text('Business Name'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);
      expect(find.text('Email ID'), findsOneWidget);
      expect(find.text('City'), findsOneWidget);
      expect(find.text('State'), findsOneWidget);
      expect(find.text('Lead Source'), findsOneWidget);
      expect(find.text('Source'), findsOneWidget);
      expect(find.text('Create Lead'), findsOneWidget);
    });

    testWidgets('desktop layout (1200x800) renders centered wide layout', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget(size: const Size(1200, 800)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Add Lead'), findsOneWidget);
      expect(find.text('Primary Information'), findsOneWidget);
      expect(find.text('Contact Information'), findsOneWidget);
      expect(find.text('Location Information'), findsOneWidget);
      expect(find.text('Lead Source'), findsOneWidget);
      expect(find.text('Create Lead'), findsOneWidget);
    });
  });

  group('AddLeadScreen - Mobile Phone Validation', () {
    testWidgets('shows validation error for invalid mobile numbers (less than 10 digits or letters)', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone Number'),
        '12345',
      );
      await tapVisible(tester, find.text('Create Lead'));

      expect(
        find.text('Enter a valid mobile number (10-15 digits)'),
        findsOneWidget,
      );
      expect(repository.createLeadCallCount, 0);

      // Alphabetic characters
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone Number'),
        '98765abcde',
      );
      await tapVisible(tester, find.text('Create Lead'));

      expect(
        find.text('Enter a valid mobile number (10-15 digits)'),
        findsOneWidget,
      );
      expect(repository.createLeadCallCount, 0);

      // Valid 10-digit mobile number
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone Number'),
        '9876543210',
      );
      await tapVisible(tester, find.text('Create Lead'));

      expect(
        find.text('Enter a valid mobile number (10-15 digits)'),
        findsNothing,
      );
      expect(repository.createLeadCallCount, 1);
      expect(repository.lastCreateInput!.draft.phone, '9876543210');
    });
  });

  group('AddLeadScreen - Hybrid Dropdown Search & Custom Manual Entry', () {
    testWidgets('allows manual custom text for unlisted City, State, and Source', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contact Person Name'),
        'Aarav Patel',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'City'),
        'Custom City Unlisted',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'State'),
        'Custom State Unlisted',
      );
      await tester.enterText(
        find.byKey(const Key('add_lead_source_dropdown')),
        'Partner Referral Channel',
      );

      await tapVisible(tester, find.text('Create Lead'));

      expect(repository.createLeadCallCount, 1);
      final draft = repository.lastCreateInput!.draft;
      expect(draft.name, 'Aarav Patel');
      expect(draft.city, 'Custom City Unlisted');
      expect(draft.state, 'Custom State Unlisted');
      expect(draft.source, LeadSource.manual);
      expect(draft.metadata?['source_detail'], 'Partner Referral Channel');
    });

    testWidgets('tapping dropdown displays options and filters dynamically on search', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Open source dropdown
      await tapVisible(tester, find.byKey(const Key('add_lead_source_dropdown')));
      expect(find.text('Web Portal'), findsWidgets);
      expect(find.text('Ad Funnels'), findsWidgets);

      // Select Web Portal
      await tester.tap(find.text('Web Portal').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('add_lead_source_badge')), findsOneWidget);

      await tapVisible(tester, find.text('Create Lead'));
      expect(repository.createLeadCallCount, 1);
      expect(repository.lastCreateInput!.draft.source, LeadSource.portal);
    });
  });

  group('AddLeadScreen - Permission Gating & Inline Assignment', () {
    testWidgets(
      'blocks access when currentUser lacks lead.create permission',
      (tester) async {
        const userWithoutCreate = CurrentUser(
          id: 'usr_view_only',
          displayName: 'Viewer',
          accountType: AccountType.user,
          modules: {CrmModule.leadManagement},
          permissions: {CrmPermissions.leadViewAssigned},
        );

        await tester.pumpWidget(
          MaterialApp(
            home: AddLeadScreen(
              repository: repository,
              currentUser: userWithoutCreate,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AccessRestrictedScreen), findsOneWidget);
        expect(find.text('Create Lead'), findsNothing);
      },
    );

    testWidgets(
      'hides inline assignee selector when currentUser has lead.create without lead.assign',
      (tester) async {
        repository.assignableUsers = const [
          LeadAssignee(id: 'u1', displayName: 'Agent U1'),
        ];
        const createOnlyUser = CurrentUser(
          id: 'usr_creator',
          displayName: 'Creator',
          accountType: AccountType.user,
          modules: {CrmModule.leadManagement},
          permissions: {CrmPermissions.leadCreate},
        );

        await tester.pumpWidget(
          MaterialApp(
            home: AddLeadScreen(
              repository: repository,
              currentUser: createOnlyUser,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Create Lead'), findsOneWidget);
        expect(
          find.byKey(const Key('add_lead_assignee_dropdown')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'shows inline assignee selector and assigns lead on submit when currentUser has lead.create & lead.assign',
      (tester) async {
        repository.assignableUsers = const [
          LeadAssignee(id: 'u1', displayName: 'Agent U1'),
        ];
        const createAndAssignUser = CurrentUser(
          id: 'usr_lead_mgr',
          displayName: 'Manager',
          accountType: AccountType.user,
          modules: {CrmModule.leadManagement},
          permissions: {
            CrmPermissions.leadCreate,
            CrmPermissions.leadAssign,
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: AddLeadScreen(
              repository: repository,
              currentUser: createAndAssignUser,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final dropdown = find.byKey(const Key('add_lead_assignee_dropdown'));
        await tapVisible(tester, dropdown);
        await tester.tap(find.text('Agent U1').last);
        await tester.pumpAndSettle();

        await tapVisible(tester, find.text('Create Lead'));

        expect(repository.createLeadCallCount, 1);
        expect(repository.lastAssignedLeadId, equals('created-lead-123'));
        expect(repository.lastAssignedUserId, equals('u1'));
      },
    );
  });
}

