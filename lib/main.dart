import 'package:flutter/material.dart';

import 'app/crm_app.dart';
import 'features/auth/data/repositories/mock_auth_repository.dart';
import 'features/leads/data/repositories/mock_lead_repository.dart';

void main() {
  final leadRepository = MockLeadRepository();
  final authRepository = MockAuthRepository();

  runApp(
    CrmApp(leadRepository: leadRepository, authRepository: authRepository),
  );
}
