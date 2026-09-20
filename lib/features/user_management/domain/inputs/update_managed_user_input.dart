import '../../../auth/domain/entities/crm_module.dart';

/// Request input model for updating an existing managed user account.
class UpdateManagedUserInput {
  final String id;
  final String displayName;
  final Set<CrmModule> modules;
  final Set<String> permissions;

  UpdateManagedUserInput({
    required this.id,
    required this.displayName,
    Set<CrmModule> modules = const {},
    Set<String> permissions = const {},
  }) : modules = Set.unmodifiable(modules),
       permissions = Set.unmodifiable(permissions);
}
