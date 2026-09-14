import 'package:enterprise_crm/features/leads/domain/entities/lead.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_source.dart';
import 'package:enterprise_crm/features/leads/domain/entities/lead_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Lead Entity', () {
    test('creates lead with minimal id and optional fields as null', () {
      const lead = Lead(id: 'lead-101');

      expect(lead.id, 'lead-101');
      expect(lead.name, isNull);
      expect(lead.phone, isNull);
      expect(lead.email, isNull);
      expect(lead.status, isNull);
      expect(lead.source, LeadSource.manual);
      expect(lead.assignedUserId, isNull);
      expect(lead.assignedUserName, isNull);
      expect(lead.isAssigned, isFalse);
    });

    test('supports optional name and phone without requiring them', () {
      const lead = Lead(
        id: 'lead-102',
        name: 'John Doe',
        phone: '+91 9876543210',
      );

      expect(lead.name, 'John Doe');
      expect(lead.phone, '+91 9876543210');
    });

    test('supports assigned state', () {
      const lead = Lead(
        id: 'lead-103',
        name: 'Jane Smith',
        phone: '011-23456789',
        assignedUserId: 'user-01',
        assignedUserName: 'Agent Rahul',
      );

      expect(lead.isAssigned, isTrue);
      expect(lead.assignedUserId, 'user-01');
      expect(lead.assignedUserName, 'Agent Rahul');
    });

    test(
      'copyWith modifies fields and supports unassigning via clearAssignedUser',
      () {
        final now = DateTime.now();
        final lead = Lead(
          id: 'lead-104',
          name: 'Alice Ray',
          phone: '9998887770',
          assignedUserId: 'user-02',
          assignedUserName: 'Agent Priya',
          createdAt: now,
        );

        final updated = lead.copyWith(
          name: 'Alice Brown',
          status: const LeadStatus('qualified'),
        );

        expect(updated.name, 'Alice Brown');
        expect(updated.status, const LeadStatus('qualified'));
        expect(updated.assignedUserId, 'user-02');
        expect(updated.isAssigned, isTrue);

        final unassigned = updated.copyWith(clearAssignedUser: true);
        expect(unassigned.assignedUserId, isNull);
        expect(unassigned.assignedUserName, isNull);
        expect(unassigned.isAssigned, isFalse);
      },
    );

    test('value equality works as expected', () {
      const leadA = Lead(
        id: '1',
        name: 'Sameer',
        phone: '9876500000',
        email: 'sameer@example.com',
      );

      const leadB = Lead(
        id: '1',
        name: 'Sameer',
        phone: '9876500000',
        email: 'sameer@example.com',
      );

      expect(leadA, equals(leadB));
      expect(leadA.hashCode, equals(leadB.hashCode));
    });
  });

  group('LeadSource & LeadStatus', () {
    test('LeadSource contains only allowed channels', () {
      expect(LeadSource.values, [
        LeadSource.manual,
        LeadSource.excel,
        LeadSource.csv,
      ]);
    });

    test(
      'LeadStatus holds backend string value without hardcoded lifecycle presets',
      () {
        final statusA = LeadStatus.fromString('Open');
        final statusB = const LeadStatus('Open');

        expect(statusA.value, 'Open');
        expect(statusA, equals(statusB));
        expect(statusA.toString(), 'Open');
      },
    );
  });
}
