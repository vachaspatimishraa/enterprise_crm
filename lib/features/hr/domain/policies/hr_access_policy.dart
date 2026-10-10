import '../../../auth/domain/entities/crm_module.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/domain/policies/access_policy.dart';
import '../../../auth/domain/policies/crm_permissions.dart';

/// Centralized frontend authorization policy for the HR / Payroll module.
///
/// Evaluates module access and operational permissions against [CurrentUser].
///
/// Invariants:
/// 1. Administrators hold unrestricted access across all HR operations via [user.isAdmin].
/// 2. Standard users require [CrmModule.hrPayroll] assigned in [user.modules].
/// 3. Operational permissions require canonical module assignment:
///    - [canViewHrRecords] requires [CrmPermissions.hrView]
///    - [canViewPayroll] requires [CrmPermissions.payrollView]
abstract final class HrAccessPolicy {
  /// Returns whether [user] is authorized to access the HR / Payroll module.
  ///
  /// Evaluates through [AccessPolicy.canAccessModule].
  static bool canAccessModule(CurrentUser user) {
    return AccessPolicy.canAccessModule(user, CrmModule.hrPayroll);
  }

  /// Returns whether [user] is authorized to view HR records.
  ///
  /// Evaluates through [AccessPolicy.hasPermission] for [CrmPermissions.hrView].
  static bool canViewHrRecords(CurrentUser user) {
    return AccessPolicy.hasPermission(user, CrmPermissions.hrView);
  }

  /// Returns whether [user] is authorized to view Payroll data.
  ///
  /// Evaluates through [AccessPolicy.hasPermission] for [CrmPermissions.payrollView].
  static bool canViewPayroll(CurrentUser user) {
    return AccessPolicy.hasPermission(user, CrmPermissions.payrollView);
  }
}
