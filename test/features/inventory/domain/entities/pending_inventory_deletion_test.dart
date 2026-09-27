import 'package:enterprise_crm/features/inventory/domain/entities/pending_inventory_deletion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PendingInventoryDeletion Entity Tests', () {
    final baseTime = DateTime.utc(2026, 9, 27, 12, 0, 0);
    final deadline = baseTime.add(const Duration(seconds: 60));

    final pending = PendingInventoryDeletion(
      itemId: 'inv_100',
      itemName: 'Test Item',
      itemSku: 'SKU-100',
      initiatedByUserId: 'usr_initiator',
      requestedAt: baseTime,
      undoDeadline: deadline,
      status: PendingDeletionStatus.pending,
    );

    test(
      'isPendingAt returns true before deadline and false at or after deadline',
      () {
        expect(
          pending.isPendingAt(baseTime.add(const Duration(seconds: 30))),
          isTrue,
        );
        expect(
          pending.isPendingAt(baseTime.add(const Duration(seconds: 59))),
          isTrue,
        );
        expect(pending.isPendingAt(deadline), isFalse);
        expect(
          pending.isPendingAt(baseTime.add(const Duration(seconds: 61))),
          isFalse,
        );
      },
    );

    test(
      'isExpiredAt returns false before deadline and true at or after deadline',
      () {
        expect(
          pending.isExpiredAt(baseTime.add(const Duration(seconds: 30))),
          isFalse,
        );
        expect(
          pending.isExpiredAt(baseTime.add(const Duration(seconds: 59))),
          isFalse,
        );
        expect(pending.isExpiredAt(deadline), isTrue);
        expect(
          pending.isExpiredAt(baseTime.add(const Duration(seconds: 61))),
          isTrue,
        );
      },
    );

    test('cancelled status makes isPendingAt and isExpiredAt both false', () {
      final cancelled = pending.copyWith(
        status: PendingDeletionStatus.cancelled,
      );
      expect(
        cancelled.isPendingAt(baseTime.add(const Duration(seconds: 30))),
        isFalse,
      );
      expect(
        cancelled.isExpiredAt(baseTime.add(const Duration(seconds: 90))),
        isFalse,
      );
    });

    test('equality and copyWith work as expected', () {
      final copy = pending.copyWith(status: PendingDeletionStatus.finalized);
      expect(copy.status, PendingDeletionStatus.finalized);
      expect(copy.itemId, pending.itemId);
      expect(pending == pending.copyWith(), isTrue);
    });
  });
}
