import 'package:enterprise_crm/features/leads/presentation/utils/lead_field_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isValidOptionalLeadEmail', () {
    test('returns true for null', () {
      expect(isValidOptionalLeadEmail(null), isTrue);
    });

    test('returns true for empty string', () {
      expect(isValidOptionalLeadEmail(''), isTrue);
    });

    test('returns true for whitespace-only string', () {
      expect(isValidOptionalLeadEmail('   '), isTrue);
      expect(isValidOptionalLeadEmail('\t\n'), isTrue);
    });

    test('returns true for valid email containing @ and .', () {
      expect(isValidOptionalLeadEmail('alice@example.com'), isTrue);
      expect(isValidOptionalLeadEmail('a@b.co'), isTrue);
      expect(isValidOptionalLeadEmail('user.name@domain.co.in'), isTrue);
    });

    test('returns true when whitespace-padded email contains @ and .', () {
      expect(isValidOptionalLeadEmail('  alice@example.com  '), isTrue);
    });

    test('returns false when missing @', () {
      expect(isValidOptionalLeadEmail('alice.example.com'), isFalse);
    });

    test('returns false when missing dot', () {
      expect(isValidOptionalLeadEmail('alice@examplecom'), isFalse);
    });

    test('returns false when missing both @ and dot', () {
      expect(isValidOptionalLeadEmail('plainaddress'), isFalse);
    });
  });
}
