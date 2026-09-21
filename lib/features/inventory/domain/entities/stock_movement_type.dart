/// Supported stock movement types for the inventory ledger.
///
/// INVENTORY-1 strictly scopes movements to [openingStock]. Future phases will
/// introduce purchase receipts, dispatch deductions, and manual adjustments.
enum StockMovementType { openingStock }
