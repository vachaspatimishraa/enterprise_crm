import 'package:enterprise_crm/features/auth/data/repositories/mock_user_lead_link_repository.dart';
import 'package:enterprise_crm/features/auth/domain/entities/user_lead_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MockUserLeadLinkRepository', () {
    test('seeded: usr_standard resolves to agent-1', () async {
      final repo = MockUserLeadLinkRepository();
      final link = await repo.getLinkForUser('usr_standard');
      expect(link, isNotNull);
      expect(link!.crmUserId, 'usr_standard');
      expect(link.leadAssigneeId, 'agent-1');
    });

    test('seeded: unknown user returns null', () async {
      final repo = MockUserLeadLinkRepository();
      expect(await repo.getLinkForUser('usr_admin'), isNull);
      expect(await repo.getLinkForUser('nonexistent'), isNull);
    });

    test('custom links override seeded data', () async {
      final repo = MockUserLeadLinkRepository(
        links: {'custom_user': 'agent-99'},
      );
      expect(await repo.getLinkForUser('custom_user'),
          const UserLeadLink(crmUserId: 'custom_user', leadAssigneeId: 'agent-99'));
      expect(await repo.getLinkForUser('usr_standard'), isNull);
    });

    test('returns Future<UserLeadLink?> — correctly typed', () {
      final repo = MockUserLeadLinkRepository();
      final result = repo.getLinkForUser('usr_standard');
      expect(result, isA<Future<UserLeadLink?>>());
    });
  });
}
