/// Input data for updating an existing inventory item's identity.
///
/// Only identity fields [name] and [sku] can be updated.
/// Direct stock editing or quantity changes are prohibited.
class UpdateInventoryItemInput {
  final String id;
  final String name;
  final String sku;

  const UpdateInventoryItemInput({
    required this.id,
    required this.name,
    required this.sku,
  });
}
