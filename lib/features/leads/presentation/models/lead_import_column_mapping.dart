/// The supported Lead fields that can be mapped from spreadsheet columns.
enum LeadImportTargetField { name, phone, email }

/// Explicit mapping from discovered spreadsheet column indices to Lead fields.
class LeadImportColumnMapping {
  const LeadImportColumnMapping({
    required this.sheetIndex,
    required this.headerRowIndex,
    this.nameColumnIndex,
    this.phoneColumnIndex,
    this.emailColumnIndex,
  });

  final int sheetIndex;
  final int headerRowIndex;
  final int? nameColumnIndex;
  final int? phoneColumnIndex;
  final int? emailColumnIndex;

  /// True if at least one Lead field is mapped.
  bool get hasAnyMapping =>
      nameColumnIndex != null ||
      phoneColumnIndex != null ||
      emailColumnIndex != null;

  /// Returns the set of all non-null column indices mapped to any Lead field.
  Set<int> get mappedColumnIndices => {
    ?nameColumnIndex,
    ?phoneColumnIndex,
    ?emailColumnIndex,
  };

  /// Retrieves the mapped column index for the specified [field].
  int? getColumnFor(LeadImportTargetField field) {
    return switch (field) {
      LeadImportTargetField.name => nameColumnIndex,
      LeadImportTargetField.phone => phoneColumnIndex,
      LeadImportTargetField.email => emailColumnIndex,
    };
  }

  LeadImportColumnMapping copyWith({
    int? sheetIndex,
    int? headerRowIndex,
    int? nameColumnIndex,
    bool clearName = false,
    int? phoneColumnIndex,
    bool clearPhone = false,
    int? emailColumnIndex,
    bool clearEmail = false,
  }) {
    return LeadImportColumnMapping(
      sheetIndex: sheetIndex ?? this.sheetIndex,
      headerRowIndex: headerRowIndex ?? this.headerRowIndex,
      nameColumnIndex: clearName
          ? null
          : (nameColumnIndex ?? this.nameColumnIndex),
      phoneColumnIndex: clearPhone
          ? null
          : (phoneColumnIndex ?? this.phoneColumnIndex),
      emailColumnIndex: clearEmail
          ? null
          : (emailColumnIndex ?? this.emailColumnIndex),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadImportColumnMapping &&
          runtimeType == other.runtimeType &&
          sheetIndex == other.sheetIndex &&
          headerRowIndex == other.headerRowIndex &&
          nameColumnIndex == other.nameColumnIndex &&
          phoneColumnIndex == other.phoneColumnIndex &&
          emailColumnIndex == other.emailColumnIndex;

  @override
  int get hashCode => Object.hash(
    sheetIndex,
    headerRowIndex,
    nameColumnIndex,
    phoneColumnIndex,
    emailColumnIndex,
  );

  @override
  String toString() =>
      'LeadImportColumnMapping(sheet: $sheetIndex, headerRow: $headerRowIndex, name: $nameColumnIndex, phone: $phoneColumnIndex, email: $emailColumnIndex)';
}
