import 'package:enterprise_crm/features/leads/presentation/widgets/lead_pagination_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestWidget({
    required int currentPage,
    required int pageSize,
    required int totalItems,
    required bool hasNext,
    VoidCallback? onPrevious,
    VoidCallback? onNext,
    Size size = const Size(800, 600),
  }) {
    return MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(size: size),
          child: SizedBox(
            width: size.width,
            child: LeadPaginationControls(
              currentPage: currentPage,
              pageSize: pageSize,
              totalItems: totalItems,
              hasNext: hasNext,
              onPrevious: onPrevious,
              onNext: onNext,
            ),
          ),
        ),
      ),
    );
  }

  group('LeadPaginationControls - Result Range & Pages', () {
    testWidgets('displays correct range and total pages for page 1', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          currentPage: 1,
          pageSize: 20,
          totalItems: 53,
          hasNext: true,
        ),
      );

      expect(find.text('1–20 of 53 leads'), findsOneWidget);
      expect(find.text('Page 1 of 3'), findsOneWidget);
    });

    testWidgets('displays correct range and total pages for page 2', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          currentPage: 2,
          pageSize: 20,
          totalItems: 53,
          hasNext: true,
        ),
      );

      expect(find.text('21–40 of 53 leads'), findsOneWidget);
      expect(find.text('Page 2 of 3'), findsOneWidget);
    });

    testWidgets(
      'displays correct range and total pages for final partial page',
      (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            currentPage: 3,
            pageSize: 20,
            totalItems: 53,
            hasNext: false,
          ),
        );

        expect(find.text('41–53 of 53 leads'), findsOneWidget);
        expect(find.text('Page 3 of 3'), findsOneWidget);
      },
    );

    testWidgets(
      'calculates total pages correctly when total items is exact multiple of page size',
      (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            currentPage: 1,
            pageSize: 20,
            totalItems: 40,
            hasNext: true,
          ),
        );

        expect(find.text('Page 1 of 2'), findsOneWidget);
      },
    );

    testWidgets('calculates total pages correctly for single item', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          currentPage: 1,
          pageSize: 20,
          totalItems: 1,
          hasNext: false,
        ),
      );

      expect(find.text('1–1 of 1 leads'), findsOneWidget);
      expect(find.text('Page 1 of 1'), findsOneWidget);
    });

    testWidgets('renders nothing when totalItems is 0', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          currentPage: 1,
          pageSize: 20,
          totalItems: 0,
          hasNext: false,
        ),
      );

      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.byKey(const Key('pagination_range_text')), findsNothing);
    });
  });

  group('LeadPaginationControls - Button States & Callbacks', () {
    testWidgets(
      'Previous button is disabled on page 1 even if callback provided',
      (tester) async {
        var previousTapped = false;
        await tester.pumpWidget(
          buildTestWidget(
            currentPage: 1,
            pageSize: 20,
            totalItems: 53,
            hasNext: true,
            onPrevious: () => previousTapped = true,
          ),
        );

        final prevButton = tester.widget<OutlinedButton>(
          find.byKey(const Key('pagination_previous_button')),
        );
        expect(prevButton.onPressed, isNull);

        await tester.tap(find.byKey(const Key('pagination_previous_button')));
        expect(previousTapped, isFalse);
      },
    );

    testWidgets('Previous button is enabled on page 2+ and calls onPrevious', (
      tester,
    ) async {
      var previousTapped = false;
      await tester.pumpWidget(
        buildTestWidget(
          currentPage: 2,
          pageSize: 20,
          totalItems: 53,
          hasNext: true,
          onPrevious: () => previousTapped = true,
        ),
      );

      final prevButton = tester.widget<OutlinedButton>(
        find.byKey(const Key('pagination_previous_button')),
      );
      expect(prevButton.onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('pagination_previous_button')));
      expect(previousTapped, isTrue);
    });

    testWidgets('Next button is disabled when hasNext is false', (
      tester,
    ) async {
      var nextTapped = false;
      await tester.pumpWidget(
        buildTestWidget(
          currentPage: 3,
          pageSize: 20,
          totalItems: 53,
          hasNext: false,
          onNext: () => nextTapped = true,
        ),
      );

      final nextButton = tester.widget<OutlinedButton>(
        find.byKey(const Key('pagination_next_button')),
      );
      expect(nextButton.onPressed, isNull);

      await tester.tap(find.byKey(const Key('pagination_next_button')));
      expect(nextTapped, isFalse);
    });

    testWidgets(
      'Next button is enabled when hasNext is true and calls onNext',
      (tester) async {
        var nextTapped = false;
        await tester.pumpWidget(
          buildTestWidget(
            currentPage: 1,
            pageSize: 20,
            totalItems: 53,
            hasNext: true,
            onNext: () => nextTapped = true,
          ),
        );

        final nextButton = tester.widget<OutlinedButton>(
          find.byKey(const Key('pagination_next_button')),
        );
        expect(nextButton.onPressed, isNotNull);

        await tester.tap(find.byKey(const Key('pagination_next_button')));
        expect(nextTapped, isTrue);
      },
    );
  });

  group('LeadPaginationControls - Responsive Layout', () {
    for (final size in [
      const Size(320, 568),
      const Size(360, 640),
      const Size(600, 800),
      const Size(768, 1024),
      const Size(1200, 800),
    ]) {
      testWidgets(
        'renders cleanly without overflow at ${size.width}x${size.height}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            buildTestWidget(
              currentPage: 2,
              pageSize: 20,
              totalItems: 126,
              hasNext: true,
              size: size,
            ),
          );

          expect(tester.takeException(), isNull);
          expect(
            find.byKey(const Key('pagination_previous_button')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('pagination_next_button')),
            findsOneWidget,
          );
          expect(find.text('21–40 of 126 leads'), findsOneWidget);
          expect(find.text('Page 2 of 7'), findsOneWidget);
        },
      );
    }
  });
}
