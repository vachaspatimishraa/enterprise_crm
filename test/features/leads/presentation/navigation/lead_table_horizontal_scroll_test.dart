import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enterprise_crm/features/leads/data/repositories/mock_lead_repository.dart';
import 'package:enterprise_crm/features/leads/presentation/bloc/lead_list_cubit.dart';
import 'package:enterprise_crm/features/leads/presentation/screens/lead_list_screen.dart';
import 'package:enterprise_crm/features/leads/presentation/widgets/lead_data_table.dart';

void main() {
  group('LeadListScreen - Horizontal Scroll Bar Platform Behavior', () {
    late MockLeadRepository repository;
    late LeadListCubit cubit;

    setUp(() {
      repository = MockLeadRepository();
      cubit = LeadListCubit(repository);
    });

    testWidgets('shows horizontal scroll bar and navigation controls on desktop/web', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await cubit.loadLeads();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LeadListScreen(
                cubit: cubit,
                repository: repository,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(LeadDataTable), findsOneWidget);
        expect(find.byKey(const Key('lead_horizontal_scroll_bar')), findsOneWidget);
        expect(find.byKey(const Key('lead_scroll_start_button')), findsOneWidget);
        expect(find.byKey(const Key('lead_scroll_left_button')), findsOneWidget);
        expect(find.byKey(const Key('lead_horizontal_scroll_slider')), findsOneWidget);
        expect(find.byKey(const Key('lead_scroll_right_button')), findsOneWidget);
        expect(find.byKey(const Key('lead_scroll_end_button')), findsOneWidget);
        expect(
          find.text('◀ Scroll Horizontally (Left ↔ Right) to View All Columns ▶'),
          findsOneWidget,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('omits horizontal scroll bar on Android APK', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await cubit.loadLeads();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LeadListScreen(
                cubit: cubit,
                repository: repository,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(LeadDataTable), findsOneWidget);
        expect(find.byKey(const Key('lead_horizontal_scroll_bar')), findsNothing);
        expect(find.byKey(const Key('lead_scroll_start_button')), findsNothing);
        expect(find.byKey(const Key('lead_scroll_left_button')), findsNothing);
        expect(find.byKey(const Key('lead_horizontal_scroll_slider')), findsNothing);
        expect(find.byKey(const Key('lead_scroll_right_button')), findsNothing);
        expect(find.byKey(const Key('lead_scroll_end_button')), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
