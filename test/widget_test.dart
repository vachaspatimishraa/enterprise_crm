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
  });
}
