import 'package:enterprise_crm/features/leads/presentation/models/lead_import_column_mapping.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LeadImportColumnMapping', () {
    test('initializes with null mappings and hasAnyMapping false', () {
      const mapping = LeadImportColumnMapping(sheetIndex: 0, headerRowIndex: 0);

      expect(mapping.sheetIndex, equals(0));
      expect(mapping.headerRowIndex, equals(0));
      expect(mapping.nameColumnIndex, isNull);
      expect(mapping.phoneColumnIndex, isNull);
      expect(mapping.emailColumnIndex, isNull);
      expect(mapping.hasAnyMapping, isFalse);
      expect(mapping.mappedColumnIndices, isEmpty);
      expect(mapping.getColumnFor(LeadImportTargetField.name), isNull);
      expect(mapping.getColumnFor(LeadImportTargetField.phone), isNull);
      expect(mapping.getColumnFor(LeadImportTargetField.email), isNull);
    });

    test('single mapped field sets hasAnyMapping to true', () {
      const mapping = LeadImportColumnMapping(
        sheetIndex: 1,
        headerRowIndex: 2,
        nameColumnIndex: 0,
      );

      expect(mapping.hasAnyMapping, isTrue);
      expect(mapping.mappedColumnIndices, equals({0}));
      expect(mapping.getColumnFor(LeadImportTargetField.name), equals(0));
      expect(mapping.getColumnFor(LeadImportTargetField.phone), isNull);
    });

    test('multiple mapped fields populate mappedColumnIndices correctly', () {
      const mapping = LeadImportColumnMapping(
        sheetIndex: 0,
        headerRowIndex: 0,
        nameColumnIndex: 0,
        phoneColumnIndex: 1,
        emailColumnIndex: 2,
      );

      expect(mapping.hasAnyMapping, isTrue);
      expect(mapping.mappedColumnIndices, equals({0, 1, 2}));
      expect(mapping.getColumnFor(LeadImportTargetField.name), equals(0));
      expect(mapping.getColumnFor(LeadImportTargetField.phone), equals(1));
      expect(mapping.getColumnFor(LeadImportTargetField.email), equals(2));
    });

    test('copyWith updates fields and clears fields correctly', () {
      const original = LeadImportColumnMapping(
        sheetIndex: 0,
        headerRowIndex: 0,
        nameColumnIndex: 0,
        phoneColumnIndex: 1,
      );

      final updated = original.copyWith(emailColumnIndex: 2, clearPhone: true);

      expect(updated.nameColumnIndex, equals(0));
      expect(updated.phoneColumnIndex, isNull);
      expect(updated.emailColumnIndex, equals(2));
      expect(updated.sheetIndex, equals(0));
    });

    test('value equality, hashCode, and toString operate correctly', () {
      const mapping1 = LeadImportColumnMapping(
        sheetIndex: 0,
        headerRowIndex: 1,
        nameColumnIndex: 0,
        phoneColumnIndex: 1,
      );
      const mapping2 = LeadImportColumnMapping(
        sheetIndex: 0,
        headerRowIndex: 1,
        nameColumnIndex: 0,
        phoneColumnIndex: 1,
      );
      const mapping3 = LeadImportColumnMapping(
        sheetIndex: 0,
        headerRowIndex: 1,
        nameColumnIndex: 0,
        phoneColumnIndex: 2,
      );

      expect(mapping1, equals(mapping2));
      expect(mapping1.hashCode, equals(mapping2.hashCode));
      expect(mapping1, isNot(equals(mapping3)));
      expect(mapping1.toString(), contains('name: 0'));
    });
  });
}
