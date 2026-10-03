import '../../domain/entities/custom_field_definition.dart';
import '../../domain/entities/inventory_catalogs.dart';
import '../../domain/entities/inventory_item_summary.dart';

/// States for [CreateInventoryItemCubit].
sealed class CreateInventoryItemState {
  const CreateInventoryItemState();
}

/// Initial form state ready for user input.
class CreateInventoryItemInitial extends CreateInventoryItemState {
  final List<CustomFieldDefinition> customFieldDefinitions;
  final InventoryCatalogs? _catalogs;

  InventoryCatalogs get catalogs => _catalogs ?? InventoryCatalogs();

  const CreateInventoryItemInitial({
    this.customFieldDefinitions = const [],
    InventoryCatalogs? catalogs,
  }) : _catalogs = catalogs;
}

/// In-flight submission state (disables form controls).
class CreateInventoryItemSubmitting extends CreateInventoryItemState {
  const CreateInventoryItemSubmitting();
}

/// Successful creation state carrying the created [item].
class CreateInventoryItemSuccess extends CreateInventoryItemState {
  final InventoryItemSummary item;

  const CreateInventoryItemSuccess(this.item);
}

/// Failure state carrying a user-facing error message.
class CreateInventoryItemFailure extends CreateInventoryItemState {
  final String message;

  const CreateInventoryItemFailure(this.message);
}
