class Lead {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? company;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Lead({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.company,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Lead.fromMap(Map<String, dynamic> map) {
    return Lead(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      company: map['company'] as String?,
      status: map['status'] as String,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'company': company,
      'status': status,
      'notes': notes,
    };
  }

  static const List<String> statuses = [
    'New',
    'Contacted',
    'Qualified',
    'Won',
    'Lost',
  ];
}