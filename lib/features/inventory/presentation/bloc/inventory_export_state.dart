import 'package:flutter/foundation.dart';
import '../../domain/entities/inventory_export_artifact.dart';

/// Immutable states representing the lifecycle of inventory export preparation.
@immutable
sealed class InventoryExportState {
  const InventoryExportState();
}

/// Initial idle state before any export has been requested.
final class InventoryExportInitial extends InventoryExportState {
  const InventoryExportInitial();
}

/// State emitted while export data is being loaded and serialized.
final class InventoryExportPreparing extends InventoryExportState {
  final InventoryExportFormat format;

  const InventoryExportPreparing(this.format);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryExportPreparing &&
          runtimeType == other.runtimeType &&
          format == other.format;

  @override
  int get hashCode => format.hashCode;

  @override
  String toString() => 'InventoryExportPreparing(format: $format)';
}

/// State emitted when export artifact is ready for delivery.
final class InventoryExportPrepared extends InventoryExportState {
  final InventoryExportArtifact artifact;

  const InventoryExportPrepared(this.artifact);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryExportPrepared &&
          runtimeType == other.runtimeType &&
          artifact == other.artifact;

  @override
  int get hashCode => artifact.hashCode;

  @override
  String toString() => 'InventoryExportPrepared(format: ${artifact.format}, items: ${artifact.itemCount})';
}

/// State emitted when a user is restricted from exporting the requested format.
final class InventoryExportRestricted extends InventoryExportState {
  final InventoryExportFormat format;
  final String message;

  const InventoryExportRestricted(
    this.format, {
    this.message = 'You do not have permission to export inventory in this format.',
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryExportRestricted &&
          runtimeType == other.runtimeType &&
          format == other.format &&
          message == other.message;

  @override
  int get hashCode => Object.hash(format, message);

  @override
  String toString() => 'InventoryExportRestricted(format: $format, message: $message)';
}

/// State emitted when an export operation fails due to data or system error.
final class InventoryExportFailure extends InventoryExportState {
  final InventoryExportFormat format;
  final String message;

  const InventoryExportFailure(this.format, this.message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryExportFailure &&
          runtimeType == other.runtimeType &&
          format == other.format &&
          message == other.message;

  @override
  int get hashCode => Object.hash(format, message);

  @override
  String toString() => 'InventoryExportFailure(format: $format, message: $message)';
}
