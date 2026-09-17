import 'package:flutter/material.dart';

import 'app/crm_app.dart';
import 'features/leads/data/repositories/mock_lead_repository.dart';

void main() {
  final leadRepository = MockLeadRepository();

  runApp(CrmApp(leadRepository: leadRepository));
}
