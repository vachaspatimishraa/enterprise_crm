/// Input data for creating a new inventory item.
///
/// Only identity fields [name] and [sku] are specified.
/// Stock movements and quantities are managed separately.
class CreateInventoryItemInput {
  final String name;
  final String sku;

  const CreateInventoryItemInput({required this.name, required this.sku});
}
