import 'package:flutter/material.dart';

import '../../../auth/domain/entities/crm_module.dart';

/// Presentation mapper providing UI metadata for [CrmModule] entities.
extension CrmModulePresentation on CrmModule {
  /// Human-readable title for the module.
  String get displayName {
    switch (this) {
      case CrmModule.leadManagement:
        return 'Lead Management';
      case CrmModule.calling:
        return 'Calling';
      case CrmModule.inventory:
        return 'Inventory';
      case CrmModule.dispatch:
        return 'Dispatch';
      case CrmModule.purchase:
        return 'Purchase';
      case CrmModule.hrPayroll:
        return 'HR / Payroll';
      case CrmModule.approvalsNotifications:
        return 'Approvals & Notifications';
      case CrmModule.vendorManagement:
        return 'Vendor Management';
    }
  }

  /// Concise subtitle explaining the module's business purpose.
  String get subtitle {
    switch (this) {
      case CrmModule.leadManagement:
        return 'Track, assign, and manage customer leads';
      case CrmModule.calling:
        return 'Telephony, call logs, and outreach';
      case CrmModule.inventory:
        return 'Stock levels, warehouses, and items';
      case CrmModule.dispatch:
        return 'Order dispatch and delivery tracking';
      case CrmModule.purchase:
        return 'Purchase orders and procurement';
      case CrmModule.hrPayroll:
        return 'Staff directory, attendance, and payroll';
      case CrmModule.approvalsNotifications:
        return 'Workflow approvals and system alerts';
      case CrmModule.vendorManagement:
        return 'Vendor onboarding, catalog, and relations';
    }
  }

  /// Material icon representing the module.
  IconData get icon {
    switch (this) {
      case CrmModule.leadManagement:
        return Icons.leaderboard_outlined;
      case CrmModule.calling:
        return Icons.phone_in_talk_outlined;
      case CrmModule.inventory:
        return Icons.inventory_2_outlined;
      case CrmModule.dispatch:
        return Icons.local_shipping_outlined;
      case CrmModule.purchase:
        return Icons.shopping_cart_outlined;
      case CrmModule.hrPayroll:
        return Icons.badge_outlined;
      case CrmModule.approvalsNotifications:
        return Icons.notifications_active_outlined;
      case CrmModule.vendorManagement:
        return Icons.storefront_outlined;
    }
  }
}
