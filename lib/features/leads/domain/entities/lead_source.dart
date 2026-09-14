enum LeadSource {
  manual('Manual Entry'),
  excel('Excel Import'),
  csv('CSV Import');

  const LeadSource(this.displayName);

  final String displayName;
}
