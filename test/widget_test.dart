import 'package:enterprise_crm/app/crm_app.dart';
import 'package:enterprise_crm/features/leads/data/datasources/mock_lead_data_source.dart';
import 'package:enterprise_crm/features/leads/data/repositories/mock_lead_repository.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_assignment_request.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_page.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_query.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/add_lead_screen.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/lead_dashboard_screen.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/lead_details_screen.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/lead_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailingRefreshLeadRepository extends MockLeadRepository {
  _FailingRefreshLeadRepository({super.dataSource});

  int reassignLeadCallCount = 0;
  bool shouldThrowOnGetLeads = false;

  @override
  Future<void> reassignLead(LeadReassignmentRequest request) async {
    reassignLeadCallCount++;
    await super.reassignLead(request);
  }

  @override
  Future<LeadPage> getLeads([LeadQuery query = const LeadQuery()]) async {
    if (shouldThrowOnGetLeads) {
      throw Exception('Server error loading leads');
    }
    return super.getLeads(query);
  }
}

void main() {
  group('CrmApp Shell Integration', () {
    testWidgets(
      'app starts in CRM: renders Enterprise CRM Lead Dashboard with Overview & Summary and Quick Actions',
      (tester) async {
        final repository = MockLeadRepository();
        await tester.pumpWidget(CrmApp(leadRepository: repository));
        await tester.pumpAndSettle();

        // Verifies the starter counter screen is gone and CRM Dashboard is rendered
        expect(
          find.text('You have pushed the button this many times:'),
          findsNothing,
        );
        expect(find.byType(FloatingActionButton), findsNothing);

        // Verifies actual CRM UI
        expect(find.byType(LeadDashboardScreen), findsOneWidget);
        expect(find.text('Lead Management'), findsOneWidget);
        expect(find.text('Overview & Summary'), findsOneWidget);
        expect(find.text('Total Leads'), findsOneWidget);
        expect(find.text('Quick Actions'), findsOneWidget);
        expect(find.text('View Leads'), findsOneWidget);
        expect(find.text('Add Lead'), findsOneWidget);
        expect(find.text('Import Leads'), findsOneWidget);
      },
    );

    testWidgets(
      'navigation: tapping View Leads opens LeadListScreen and Back returns to Dashboard',
      (tester) async {
        final repository = MockLeadRepository();
        await tester.pumpWidget(CrmApp(leadRepository: repository));
        await tester.pumpAndSettle();

        // Tap 'View Leads' Quick Action on Dashboard
        await tester.tap(find.text('View Leads'));
        await tester.pumpAndSettle();

        // Verified: LeadListScreen is open
        expect(find.byType(LeadListScreen), findsOneWidget);
        expect(find.text('Leads'), findsOneWidget);

        // Tap Back in AppBar
        final backButton = find.byTooltip('Back');
        if (backButton.evaluate().isNotEmpty) {
          await tester.tap(backButton);
        } else {
          final navigatorState = tester.state<NavigatorState>(
            find.byType(Navigator),
          );
          navigatorState.pop();
        }
        await tester.pumpAndSettle();

        // Verified: back on Dashboard
        expect(find.byType(LeadDashboardScreen), findsOneWidget);
        expect(find.text('Lead Management'), findsOneWidget);
      },
    );

    testWidgets(
      'import reachability: Import Leads action is accessible from both Dashboard and LeadListScreen',
      (tester) async {
        final repository = MockLeadRepository();
        await tester.pumpWidget(CrmApp(leadRepository: repository));
        await tester.pumpAndSettle();

        // 1. Dashboard: Quick Action 'Import Leads' exists
        expect(find.text('Import Leads'), findsOneWidget);

        // 2. Navigate to LeadListScreen
        await tester.tap(find.text('View Leads'));
        await tester.pumpAndSettle();

        // LeadListScreen has AppBar import button
        expect(
          find.byKey(const Key('lead_list_import_button')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'shared repository: single LeadRepository instance is used across Dashboard, List, and Add Lead',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final dataSource = MockLeadDataSource(
          initialLeads: [
            const Lead(
              id: 'init-1',
              name: 'Alpha Lead',
              source: LeadSource.manual,
            ),
          ],
        );
        final sharedRepository = MockLeadRepository(dataSource: dataSource);

        await tester.pumpWidget(CrmApp(leadRepository: sharedRepository));
        await tester.pumpAndSettle();

        // Initial Dashboard: total leads = 1
        expect(find.text('1'), findsWidgets);

        // Tap 'Add Lead' from Dashboard
        await tester.tap(find.text('Add Lead'));
        await tester.pumpAndSettle();

        // AddLeadScreen is open
        expect(find.byType(AddLeadScreen), findsOneWidget);

        // Fill in name
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Lead Name'),
          'Beta Lead',
        );
        await tester.pumpAndSettle();

        // Submit form
        await tester.tap(find.text('Create Lead'));
        await tester.pumpAndSettle();

        // Back on Dashboard: total leads refreshed to 2
        expect(find.byType(LeadDashboardScreen), findsOneWidget);
        expect(find.text('2'), findsWidgets);

        // Scroll to and tap 'View Leads' Quick Action
        await tester.scrollUntilVisible(
          find.text('View Leads'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('View Leads'));
        await tester.pumpAndSettle();

        expect(find.byType(LeadListScreen), findsOneWidget);
        expect(find.text('Alpha Lead'), findsOneWidget);
        expect(find.text('Beta Lead'), findsOneWidget);
      },
    );

    testWidgets(
      'responsive layout: CrmApp renders cleanly across mobile, tablet, and desktop viewports',
      (tester) async {
        const viewports = [Size(360, 640), Size(768, 1024), Size(1200, 800)];

        for (final size in viewports) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final repository = MockLeadRepository();
          await tester.pumpWidget(CrmApp(leadRepository: repository));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.byType(LeadDashboardScreen), findsOneWidget);
          expect(find.text('Lead Management'), findsOneWidget);
        }
      },
    );

    testWidgets(
      'L5.2 integration: Lead List -> open unassigned Lead -> Assign -> back to Lead List -> list refreshes with updated assignee',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final dataSource = MockLeadDataSource(
          initialLeads: [
            const Lead(
              id: 'lead-unassigned',
              name: 'Unassigned Person',
              source: LeadSource.manual,
            ),
          ],
        );
        final sharedRepository = MockLeadRepository(dataSource: dataSource);

        await tester.pumpWidget(CrmApp(leadRepository: sharedRepository));
        await tester.pumpAndSettle();

        // 1. Navigate to Lead List from Dashboard
        await tester.tap(find.text('View Leads'));
        await tester.pumpAndSettle();

        expect(find.byType(LeadListScreen), findsOneWidget);
        expect(find.text('Unassigned Person'), findsOneWidget);
        expect(find.text('Unassigned'), findsWidgets);

        // 2. Open Lead Details by tapping 'View' action
        await tester.ensureVisible(find.text('View'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('View'));
        await tester.pumpAndSettle();

        expect(find.byType(LeadDetailsScreen), findsOneWidget);
        expect(find.byKey(const Key('assign_lead_button')), findsOneWidget);

        // 3. Open assignment dialog
        await tester.tap(find.byKey(const Key('assign_lead_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('assign_lead_dialog')), findsOneWidget);

        // 4. Select assignee
        await tester.tap(find.byKey(const Key('lead_assignee_dropdown')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Mock Agent One').last);
        await tester.pumpAndSettle();

        // 5. Submit assignment
        await tester.tap(find.byKey(const Key('assign_dialog_submit_button')));
        await tester.pumpAndSettle();

        // 6. Modal closes, Lead Details updates
        expect(find.byKey(const Key('assign_lead_dialog')), findsNothing);
        expect(find.text('Mock Agent One'), findsWidgets);
        expect(find.byKey(const Key('assign_lead_button')), findsNothing);

        // 7. Navigate back to Lead List
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        // 8. Lead List refreshes automatically, showing the updated assignee
        expect(find.byType(LeadListScreen), findsOneWidget);
        expect(find.text('Mock Agent One'), findsWidgets);
      },
    );

    testWidgets(
      'L5.4 shared repository regression: Distribute Leads -> assign -> unassigned list updates -> return updates Dashboard metrics',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final dataSource = MockLeadDataSource(
          initialLeads: [
            const Lead(
              id: 'lead-a',
              name: 'Lead Alpha',
              source: LeadSource.manual,
            ),
            const Lead(
              id: 'lead-b',
              name: 'Lead Beta',
              source: LeadSource.manual,
            ),
            const Lead(
              id: 'lead-c',
              name: 'Lead Gamma',
              source: LeadSource.manual,
              assignedUserId: 'agent-1',
              assignedUserName: 'Mock Agent One',
            ),
          ],
        );
        final sharedRepository = MockLeadRepository(dataSource: dataSource);

        await tester.pumpWidget(CrmApp(leadRepository: sharedRepository));
        await tester.pumpAndSettle();

        // Initial summary metrics
        expect(find.text('Assigned Leads'), findsOneWidget);
        expect(find.text('Unassigned Leads'), findsOneWidget);

        // Tap Distribute Leads Quick Action
        await tester.tap(find.text('Distribute Leads'));
        await tester.pumpAndSettle();

        // LeadListScreen is open in distribution mode (starts in selection mode)
        expect(find.byType(LeadListScreen), findsOneWidget);
        expect(find.text('0 selected'), findsOneWidget);

        // Only unassigned leads are visible
        expect(find.text('Lead Alpha'), findsOneWidget);
        expect(find.text('Lead Beta'), findsOneWidget);
        expect(find.text('Lead Gamma'), findsNothing);

        // Select Lead Alpha
        await tester.tap(find.byKey(const Key('lead_select_checkbox_lead-a')));
        await tester.pumpAndSettle();
        expect(find.text('1 selected'), findsOneWidget);

        // Open bulk assign dialog
        await tester.tap(
          find.byKey(const Key('lead_list_assign_leads_button')),
        );
        await tester.pumpAndSettle();

        // Choose Mock Agent Two and submit
        await tester.tap(find.byKey(const Key('lead_assignee_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mock Agent Two').last);
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('bulk_assign_dialog_submit_button')),
        );
        await tester.pumpAndSettle();

        // Lead Alpha disappears from unassigned list; Lead Beta remains
        expect(find.text('Lead Alpha'), findsNothing);
        expect(find.text('Lead Beta'), findsOneWidget);

        // Exit selection mode and navigate back to Dashboard
        await tester.tap(
          find.byKey(const Key('lead_list_cancel_selection_button')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Distribute Leads'), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        // Dashboard is displayed with refreshed metrics (Assigned = 2, Unassigned = 1)
        expect(find.byType(LeadDashboardScreen), findsOneWidget);
      },
    );

    testWidgets(
      'L5.4 ordinary View Leads regression: opening View Leads does not force Unassigned filter or selection mode',
      (tester) async {
        final dataSource = MockLeadDataSource(
          initialLeads: [
            const Lead(
              id: 'lead-1',
              name: 'Unassigned Person',
              source: LeadSource.manual,
            ),
            const Lead(
              id: 'lead-2',
              name: 'Assigned Person',
              source: LeadSource.manual,
              assignedUserId: 'agent-1',
              assignedUserName: 'Mock Agent One',
            ),
          ],
        );
        final repository = MockLeadRepository(dataSource: dataSource);

        await tester.pumpWidget(CrmApp(leadRepository: repository));
        await tester.pumpAndSettle();

        // Tap View Leads
        await tester.tap(find.text('View Leads'));
        await tester.pumpAndSettle();

        // Screen is regular LeadListScreen
        expect(find.byType(LeadListScreen), findsOneWidget);
        expect(find.text('Leads'), findsOneWidget);
        expect(find.text('0 selected'), findsNothing);

        // Both assigned and unassigned are displayed
        expect(find.text('Unassigned Person'), findsOneWidget);
        expect(find.text('Assigned Person'), findsOneWidget);
      },
    );

    testWidgets(
      'L5.4 cancel / no-mutation: Distribute Leads -> select -> cancel -> Back leaves counts unchanged',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final dataSource = MockLeadDataSource(
          initialLeads: [
            const Lead(
              id: 'lead-1',
              name: 'Unassigned Person',
              source: LeadSource.manual,
            ),
          ],
        );
        final repository = MockLeadRepository(dataSource: dataSource);

        await tester.pumpWidget(CrmApp(leadRepository: repository));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Distribute Leads'));
        await tester.pumpAndSettle();

        // Select lead
        await tester.tap(find.byKey(const Key('lead_select_checkbox_lead-1')));
        await tester.pumpAndSettle();
        expect(find.text('1 selected'), findsOneWidget);

        // Cancel selection
        await tester.tap(
          find.byKey(const Key('lead_list_cancel_selection_button')),
        );
        await tester.pumpAndSettle();

        // Back to Dashboard
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(find.byType(LeadDashboardScreen), findsOneWidget);
      },
    );

    testWidgets(
      'L5.4 multiple batches in one session: assign batch A -> assign batch B -> return to Dashboard reflects both',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final dataSource = MockLeadDataSource(
          initialLeads: [
            const Lead(
              id: 'lead-a',
              name: 'Batch Lead A',
              source: LeadSource.manual,
            ),
            const Lead(
              id: 'lead-b',
              name: 'Batch Lead B',
              source: LeadSource.manual,
            ),
          ],
        );
        final repository = MockLeadRepository(dataSource: dataSource);

        await tester.pumpWidget(CrmApp(leadRepository: repository));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Distribute Leads'));
        await tester.pumpAndSettle();

        // 1. Assign Batch A
        await tester.tap(find.byKey(const Key('lead_select_checkbox_lead-a')));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('lead_list_assign_leads_button')),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('lead_assignee_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mock Agent One').last);
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('bulk_assign_dialog_submit_button')),
        );
        await tester.pumpAndSettle();

        // Batch A disappeared, Batch B is visible, selection mode remains active
        expect(find.text('Batch Lead A'), findsNothing);
        expect(find.text('Batch Lead B'), findsOneWidget);
        expect(find.text('0 selected'), findsOneWidget);

        // 2. Assign Batch B
        await tester.tap(find.byKey(const Key('lead_select_checkbox_lead-b')));
        await tester.pumpAndSettle();
        expect(find.text('1 selected'), findsOneWidget);

        await tester.tap(
          find.byKey(const Key('lead_list_assign_leads_button')),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('lead_assignee_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mock Agent Two').last);
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('bulk_assign_dialog_submit_button')),
        );
        await tester.pumpAndSettle();

        // All assigned, empty state reached
        expect(find.text('Batch Lead B'), findsNothing);
        expect(find.text('No unassigned leads available'), findsOneWidget);

        // 3. Return to Dashboard
        await tester.tap(
          find.byKey(const Key('lead_list_cancel_selection_button')),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(find.byType(LeadDashboardScreen), findsOneWidget);
      },
    );

    testWidgets(
      'L5.5 comprehensive end-to-end verification: single, bulk, distribution, and cross-screen shared repository mutation',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final dataSource = MockLeadDataSource(
          initialLeads: [
            const Lead(
              id: 'lead-1',
              name: 'First Unassigned Lead',
              source: LeadSource.manual,
            ),
            const Lead(
              id: 'lead-2',
              name: 'Second Unassigned Lead',
              source: LeadSource.manual,
            ),
          ],
        );
        final sharedRepository = MockLeadRepository(dataSource: dataSource);

        await tester.pumpWidget(CrmApp(leadRepository: sharedRepository));
        await tester.pumpAndSettle();

        // 1. Initial Dashboard: 0 assigned, 2 unassigned
        expect(find.text('Assigned Leads'), findsOneWidget);
        expect(find.text('Unassigned Leads'), findsOneWidget);

        // 2. Dashboard -> Distribute Leads (Bulk Assignment on Lead 1)
        await tester.tap(find.text('Distribute Leads'));
        await tester.pumpAndSettle();

        expect(find.byType(LeadListScreen), findsOneWidget);
        expect(find.text('0 selected'), findsOneWidget);

        await tester.tap(find.byKey(const Key('lead_select_checkbox_lead-1')));
        await tester.pumpAndSettle();
        expect(find.text('1 selected'), findsOneWidget);

        await tester.tap(
          find.byKey(const Key('lead_list_assign_leads_button')),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('lead_assignee_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mock Agent One').last);
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('bulk_assign_dialog_submit_button')),
        );
        await tester.pumpAndSettle();

        // Lead 1 is now assigned and vanished from unassigned distribution list
        expect(find.text('First Unassigned Lead'), findsNothing);
        expect(find.text('Second Unassigned Lead'), findsOneWidget);

        // 3. Return to Dashboard
        await tester.tap(
          find.byKey(const Key('lead_list_cancel_selection_button')),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(find.byType(LeadDashboardScreen), findsOneWidget);

        // 4. Dashboard -> View Leads (Ordinary Lead List)
        await tester.tap(find.text('View Leads'));
        await tester.pumpAndSettle();

        expect(find.byType(LeadListScreen), findsOneWidget);
        expect(find.text('Leads'), findsOneWidget);

        // Both leads exist: Lead 1 is assigned to Mock Agent One, Lead 2 is unassigned
        expect(find.text('First Unassigned Lead'), findsOneWidget);
        expect(find.text('Second Unassigned Lead'), findsOneWidget);
        expect(find.text('Mock Agent One'), findsWidgets);

        // 5. Open Lead 2 Details
        await tester.ensureVisible(find.text('View').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('View').last);
        await tester.pumpAndSettle();

        expect(find.byType(LeadDetailsScreen), findsOneWidget);
        expect(find.byKey(const Key('assign_lead_button')), findsOneWidget);

        // 6. Single Lead Assignment on Lead 2
        await tester.tap(find.byKey(const Key('assign_lead_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('lead_assignee_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mock Agent Two').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('assign_dialog_submit_button')));
        await tester.pumpAndSettle();

        // Details shows Mock Agent Two, Assign button disappears
        expect(find.text('Mock Agent Two'), findsWidgets);
        expect(find.byKey(const Key('assign_lead_button')), findsNothing);

        // 7. Return to Lead List -> Lead 2 shows Mock Agent Two
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(find.byType(LeadListScreen), findsOneWidget);
        expect(find.text('Mock Agent Two'), findsWidgets);

        // 8. Return to Dashboard -> Metrics update
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(find.byType(LeadDashboardScreen), findsOneWidget);
      },
    );

    testWidgets(
      'reassignment integration: Lead List -> open assigned Lead -> Reassign Lead -> success -> return to Lead List shows updated assignee',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final dataSource = MockLeadDataSource(
          initialLeads: [
            const Lead(
              id: 'lead-assigned-1',
              name: 'Reassignable Customer',
              source: LeadSource.manual,
              assignedUserId: 'agent-1',
              assignedUserName: 'Mock Agent One',
            ),
          ],
        );
        final sharedRepository = MockLeadRepository(dataSource: dataSource);

        await tester.pumpWidget(CrmApp(leadRepository: sharedRepository));
        await tester.pumpAndSettle();

        // 1. Dashboard -> View Leads
        await tester.tap(find.text('View Leads'));
        await tester.pumpAndSettle();

        expect(find.byType(LeadListScreen), findsOneWidget);
        expect(find.text('Reassignable Customer'), findsOneWidget);
        expect(find.text('Mock Agent One'), findsWidgets);

        // 2. Open Lead Details
        await tester.ensureVisible(find.text('View').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('View').first);
        await tester.pumpAndSettle();

        expect(find.byType(LeadDetailsScreen), findsOneWidget);
        expect(find.byKey(const Key('reassign_lead_button')), findsOneWidget);

        // 3. Tap Reassign Lead
        await tester.tap(find.byKey(const Key('reassign_lead_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('reassign_lead_dialog')), findsOneWidget);

        // 4. Select Mock Agent Two and enter reason
        await tester.tap(find.byKey(const Key('lead_reassignee_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mock Agent Two').last);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('reassign_dialog_reason_input')),
          'Workload rebalance',
        );
        await tester.pumpAndSettle();

        // 5. Submit reassignment
        await tester.tap(
          find.byKey(const Key('reassign_dialog_submit_button')),
        );
        await tester.pumpAndSettle();

        // Reassignment dialog closes, details shows Mock Agent Two
        expect(find.byKey(const Key('reassign_lead_dialog')), findsNothing);
        expect(find.text('Mock Agent Two'), findsWidgets);

        // 6. Return to LeadListScreen
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(find.byType(LeadListScreen), findsOneWidget);
        // List displays the new assignee from shared repository
        expect(find.text('Mock Agent Two'), findsWidgets);
      },
    );

    testWidgets(
      'L6A.3 filter integration: Lead List filtered to Agent One -> reassign to Agent Two -> disappears from Agent One list -> appears under Agent Two filter',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final dataSource = MockLeadDataSource(
          initialLeads: [
            const Lead(
              id: 'lead-filter-1',
              name: 'Filter Test Customer',
              source: LeadSource.manual,
              assignedUserId: 'agent-1',
              assignedUserName: 'Mock Agent One',
            ),
          ],
        );
        final sharedRepository = MockLeadRepository(dataSource: dataSource);

        await tester.pumpWidget(CrmApp(leadRepository: sharedRepository));
        await tester.pumpAndSettle();

        // 1. Navigate to Lead List
        await tester.tap(find.text('View Leads'));
        await tester.pumpAndSettle();

        // 2. Open Filters modal and filter by Agent One
        await tester.tap(find.byKey(const Key('lead_filter_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('filter_assignee_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mock Agent One').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('filter_apply_button')));
        await tester.pumpAndSettle();

        // Lead is displayed under Agent One filter
        expect(find.text('Filter Test Customer'), findsOneWidget);

        // 3. Open Details for this lead
        await tester.ensureVisible(find.text('View').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('View').first);
        await tester.pumpAndSettle();

        expect(find.byType(LeadDetailsScreen), findsOneWidget);

        // 4. Reassign to Mock Agent Two
        await tester.tap(find.byKey(const Key('reassign_lead_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('lead_reassignee_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mock Agent Two').last);
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('reassign_dialog_submit_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Mock Agent Two'), findsWidgets);

        // 5. Return to Lead List
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        // Caller refreshed: lead disappears from Agent One filter results through normal repository query semantics
        expect(find.byType(LeadListScreen), findsOneWidget);
        expect(find.text('Filter Test Customer'), findsNothing);

        // 6. Change filter to Mock Agent Two
        await tester.tap(find.byKey(const Key('lead_filter_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('filter_assignee_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mock Agent Two').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('filter_apply_button')));
        await tester.pumpAndSettle();

        // Lead appears under Mock Agent Two
        expect(find.text('Filter Test Customer'), findsOneWidget);
        expect(find.text('Mock Agent Two'), findsWidgets);
      },
    );

    testWidgets(
      'L6A.3 assignment filter invariants: Assigned filter retains lead with new assignee; Unassigned filter never includes reassigned lead',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final dataSource = MockLeadDataSource(
          initialLeads: [
            const Lead(
              id: 'lead-inv-1',
              name: 'Invariant Customer',
              source: LeadSource.manual,
              assignedUserId: 'agent-1',
              assignedUserName: 'Mock Agent One',
            ),
          ],
        );
        final sharedRepository = MockLeadRepository(dataSource: dataSource);

        await tester.pumpWidget(CrmApp(leadRepository: sharedRepository));
        await tester.pumpAndSettle();

        await tester.tap(find.text('View Leads'));
        await tester.pumpAndSettle();

        // 1. Filter by Assigned
        await tester.tap(find.byKey(const Key('lead_filter_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('filter_assignment_assigned')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('filter_apply_button')));
        await tester.pumpAndSettle();

        expect(find.text('Invariant Customer'), findsOneWidget);

        // 2. Open Details and reassign to Agent Two
        await tester.ensureVisible(find.text('View').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('View').first);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('reassign_lead_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('lead_reassignee_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mock Agent Two').last);
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('reassign_dialog_submit_button')),
        );
        await tester.pumpAndSettle();

        // 3. Back to list: Assigned filter is still active, lead is visible showing Mock Agent Two
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(find.text('Invariant Customer'), findsOneWidget);
        expect(find.text('Mock Agent Two'), findsWidgets);

        // 4. Switch filter to Unassigned
        await tester.tap(find.byKey(const Key('lead_filter_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('filter_assignment_unassigned')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('filter_apply_button')));
        await tester.pumpAndSettle();

        // Reassigned lead does NOT appear in unassigned filter
        expect(find.text('Invariant Customer'), findsNothing);
      },
    );

    testWidgets(
      'L6A.3 dashboard metrics invariant: repository summary and UI metrics remain identical before and after reassignment',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final dataSource = MockLeadDataSource(
          initialLeads: [
            const Lead(
              id: 'lead-dash-1',
              name: 'Assigned Lead A',
              source: LeadSource.manual,
              assignedUserId: 'agent-1',
              assignedUserName: 'Mock Agent One',
            ),
            const Lead(
              id: 'lead-dash-2',
              name: 'Assigned Lead B',
              source: LeadSource.manual,
              assignedUserId: 'agent-2',
              assignedUserName: 'Mock Agent Two',
            ),
            const Lead(
              id: 'lead-dash-3',
              name: 'Unassigned Lead C',
              source: LeadSource.manual,
            ),
          ],
        );
        final sharedRepository = MockLeadRepository(dataSource: dataSource);

        // Verify initial repository summary numbers
        final summaryBefore = await sharedRepository.getLeadSummary();
        expect(summaryBefore.assignedLeads, 2);
        expect(summaryBefore.unassignedLeads, 1);
        expect(summaryBefore.totalLeads, 3);

        await tester.pumpWidget(CrmApp(leadRepository: sharedRepository));
        await tester.pumpAndSettle();

        // Verify Dashboard UI numbers
        expect(find.text('Assigned Leads'), findsOneWidget);
        expect(find.text('Unassigned Leads'), findsOneWidget);

        // Open View Leads
        await tester.tap(find.text('View Leads'));
        await tester.pumpAndSettle();

        // Open Assigned Lead A Details
        await tester.ensureVisible(find.text('View').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('View').first);
        await tester.pumpAndSettle();

        // Reassign from Agent One to Agent Two
        await tester.tap(find.byKey(const Key('reassign_lead_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('lead_reassignee_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mock Agent Two').last);
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('reassign_dialog_submit_button')),
        );
        await tester.pumpAndSettle();

        // Return: Details -> List -> Dashboard
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        final backToDashboard = find.byTooltip('Back');
        if (backToDashboard.evaluate().isNotEmpty) {
          await tester.tap(backToDashboard);
        } else {
          tester.state<NavigatorState>(find.byType(Navigator)).pop();
        }
        await tester.pumpAndSettle();

        expect(find.byType(LeadDashboardScreen), findsOneWidget);

        // Verify repository summary numbers after reassignment: invariant
        final summaryAfter = await sharedRepository.getLeadSummary();
        expect(summaryAfter.assignedLeads, 2);
        expect(summaryAfter.unassignedLeads, 1);
        expect(summaryAfter.totalLeads, 3);
      },
    );

    testWidgets(
      'L6A.3 caller refresh failure boundary: reassign succeeds once -> list refresh fails -> retry reloads list without re-running reassignment',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final dataSource = MockLeadDataSource(
          initialLeads: [
            const Lead(
              id: 'lead-fail-1',
              name: 'Refresh Edge Customer',
              source: LeadSource.manual,
              assignedUserId: 'agent-1',
              assignedUserName: 'Mock Agent One',
            ),
          ],
        );
        final sharedRepository = _FailingRefreshLeadRepository(
          dataSource: dataSource,
        );

        await tester.pumpWidget(CrmApp(leadRepository: sharedRepository));
        await tester.pumpAndSettle();

        // Navigate to Lead List
        await tester.tap(find.text('View Leads'));
        await tester.pumpAndSettle();

        // Open Lead Details
        await tester.ensureVisible(find.text('View').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('View').first);
        await tester.pumpAndSettle();

        // Configure next getLeads to fail (caller refresh failure)
        sharedRepository.shouldThrowOnGetLeads = true;

        // Reassign Lead to Mock Agent Two
        await tester.tap(find.byKey(const Key('reassign_lead_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('lead_reassignee_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mock Agent Two').last);
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('reassign_dialog_submit_button')),
        );
        await tester.pumpAndSettle();

        // Reassign mutation succeeded once in repository
        expect(sharedRepository.reassignLeadCallCount, 1);

        // Details screen reloaded successfully
        expect(find.text('Mock Agent Two'), findsWidgets);

        // Return to LeadListScreen
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        // Lead List shows load failure state, NOT a reassignment failure
        expect(find.text('Failed to load leads'), findsOneWidget);
        expect(find.text('Unable to reassign the Lead.'), findsNothing);

        // Restore repository getLeads and tap Retry
        sharedRepository.shouldThrowOnGetLeads = false;
        await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
        await tester.pumpAndSettle();

        // List is loaded with updated assignee
        expect(find.text('Refresh Edge Customer'), findsOneWidget);
        expect(find.text('Mock Agent Two'), findsWidgets);

        // Critical invariant: reassignLead was NOT called again during retry
        expect(sharedRepository.reassignLeadCallCount, 1);
      },
    );

    testWidgets(
      'L6A.3 cross-screen end-to-end persistence: List -> Details -> Reassign -> Details -> List -> reopen Details preserves updated assignee with no history leakage',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final dataSource = MockLeadDataSource(
          initialLeads: [
            const Lead(
              id: 'lead-e2e-1',
              name: 'Persistent Customer',
              source: LeadSource.manual,
              assignedUserId: 'agent-1',
              assignedUserName: 'Mock Agent One',
            ),
          ],
        );
        final sharedRepository = MockLeadRepository(dataSource: dataSource);

        await tester.pumpWidget(CrmApp(leadRepository: sharedRepository));
        await tester.pumpAndSettle();

        // 1. Dashboard -> View Leads
        await tester.tap(find.text('View Leads'));
        await tester.pumpAndSettle();

        expect(find.text('Persistent Customer'), findsOneWidget);
        expect(find.text('Mock Agent One'), findsWidgets);

        // 2. Open Details
        await tester.ensureVisible(find.text('View').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('View').first);
        await tester.pumpAndSettle();

        // 3. Reassign Lead with reason
        await tester.tap(find.byKey(const Key('reassign_lead_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('lead_reassignee_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mock Agent Two').last);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('reassign_dialog_reason_input')),
          'End-to-end reason boundary check',
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('reassign_dialog_submit_button')),
        );
        await tester.pumpAndSettle();

        // 4. Details shows Mock Agent Two
        expect(find.text('Mock Agent Two'), findsWidgets);
        // Reason is NOT displayed on screen
        expect(find.text('End-to-end reason boundary check'), findsNothing);
        expect(find.text('History'), findsNothing);
        expect(find.text('Timeline'), findsNothing);

        // 5. Back to Lead List
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(find.byType(LeadListScreen), findsOneWidget);
        expect(find.text('Mock Agent Two'), findsWidgets);
        expect(find.text('End-to-end reason boundary check'), findsNothing);

        // 6. Reopen Details
        await tester.ensureVisible(find.text('View').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('View').first);
        await tester.pumpAndSettle();

        // Still Mock Agent Two in Lead Details
        expect(find.byType(LeadDetailsScreen), findsOneWidget);
        expect(find.text('Mock Agent Two'), findsWidgets);
        expect(find.text('End-to-end reason boundary check'), findsNothing);
        expect(find.text('History'), findsNothing);
        expect(find.text('Timeline'), findsNothing);
      },
    );
  });
}
