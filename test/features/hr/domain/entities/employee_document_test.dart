import 'package:enterprise_crm/features/hr/domain/entities/employee_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EmployeeDocument Entity Tests', () {
    final sampleDoc = EmployeeDocument(
      id: 'doc_test_1',
      employeeId: 'emp_1',
      title: 'Offer Letter',
      fileName: 'offer_letter.pdf',
      fileExtension: 'pdf',
      fileSizeBytes: 1024 * 500, // 500 KB
      documentType: 'Contract',
      expiryDate: DateTime.utc(2025, 12, 31),
      uploadedAt: DateTime.utc(2023, 1, 1),
      uploadedBy: 'usr_admin',
    );

    test('correctly formats file sizes', () {
      expect(sampleDoc.formattedFileSize, '500.0 KB');

      final smallDoc = sampleDoc.copyWith(fileSizeBytes: 512);
      expect(smallDoc.formattedFileSize, '512 B');

      final largeDoc = sampleDoc.copyWith(fileSizeBytes: 1024 * 1024 * 2);
      expect(largeDoc.formattedFileSize, '2.0 MB');
    });

    test('isExpired calculates expiration correctly', () {
      final docWithExpiry = sampleDoc.copyWith(
        expiryDate: DateTime.utc(2024, 1, 1),
      );
      final checkBefore = DateTime.utc(2023, 6, 1);
      final checkAfter = DateTime.utc(2025, 1, 1);

      expect(docWithExpiry.isExpired(now: checkBefore), isFalse);
      expect(docWithExpiry.isExpired(now: checkAfter), isTrue);

      final docNoExpiry = sampleDoc.copyWith(clearExpiryDate: true);
      expect(docNoExpiry.isExpired(now: checkAfter), isFalse);
    });

    test('copyWith creates exact replica with specified updates', () {
      final updated = sampleDoc.copyWith(
        title: 'Updated Agreement',
        fileSizeBytes: 1024 * 600,
      );

      expect(updated.title, 'Updated Agreement');
      expect(updated.fileSizeBytes, 1024 * 600);
      expect(updated.id, sampleDoc.id);
      expect(updated.employeeId, sampleDoc.employeeId);
    });

    test('equality and hashcode are consistent', () {
      final copy = sampleDoc.copyWith();
      expect(sampleDoc, equals(copy));
      expect(sampleDoc.hashCode, equals(copy.hashCode));
    });
  });
}
