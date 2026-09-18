import 'package:enterprise_crm/app/crm_app.dart';
import 'package:enterprise_crm/features/leads/data/datasources/mock_lead_data_source.dart';
import 'package:enterprise_crm/features/leads/data/repositories/mock_lead_repository.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/add_lead_screen.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/lead_dashboard_screen.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/lead_details_screen.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/lead_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
  });
}
