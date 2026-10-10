import '../../domain/entities/inventory_item_summary.dart';

/// States for [EditInventoryItemCubit].
sealed class EditInventoryItemState {
  const EditInventoryItemState();
}

/// Initial uninitialized state.
class EditInventoryItemInitial extends EditInventoryItemState {
  const EditInventoryItemInitial();
}

/// In-flight fresh load of the item from repository.
class EditInventoryItemLoading extends EditInventoryItemState {
  const EditInventoryItemLoading();
}

/// Fresh item loaded successfully, populating form fields.
class EditInventoryItemLoaded extends EditInventoryItemState {
  final InventoryItemSummary item;

  const EditInventoryItemLoaded(this.item);
}

/// In-flight update submission state (disables form controls).
class EditInventoryItemSubmitting extends EditInventoryItemState {
  final InventoryItemSummary item;

  const EditInventoryItemSubmitting(this.item);
}

/// Successful update state carrying the updated [item].
class EditInventoryItemSuccess extends EditInventoryItemState {
  final InventoryItemSummary item;

  const EditInventoryItemSuccess(this.item);
}

/// State emitted when the item does not exist in the repository.
class EditInventoryItemNotFound extends EditInventoryItemState {
  const EditInventoryItemNotFound();
}

/// Failure state carrying a user-facing error message.
class EditInventoryItemFailure extends EditInventoryItemState {
  final String message;
  final InventoryItemSummary? item;

  const EditInventoryItemFailure(this.message, {this.item});
}
