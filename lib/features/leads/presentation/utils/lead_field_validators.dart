/// Utility functions for validating Lead input fields across manual entry and import.
library;

/// Validates whether an optional email is well-formed.
///
/// Returns `true` if [email] is `null` or blank after trimming.
/// If non-empty, requires both '@' and '.' characters, consistent with manual Lead entry.
bool isValidOptionalLeadEmail(String? email) {
  if (email == null) return true;
  final trimmed = email.trim();
  if (trimmed.isEmpty) return true;
  return trimmed.contains('@') && trimmed.contains('.');
}
