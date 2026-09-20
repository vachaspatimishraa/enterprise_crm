import '../../../auth/domain/entities/crm_module.dart';

/// Request input model for creating a new managed user account.
class CreateManagedUserInput {
  final String userId;
  final String displayName;
  final Set<CrmModule> modules;
  final Set<String> permissions;

  CreateManagedUserInput({
    required this.userId,
    required this.displayName,
    Set<CrmModule> modules = const {},
    Set<String> permissions = const {},
  }) : modules = Set.unmodifiable(modules),
       permissions = Set.unmodifiable(permissions);
}
