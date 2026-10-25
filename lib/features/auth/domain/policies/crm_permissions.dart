import '../entities/crm_module.dart';

/// Centralized frontend permission constants and canonical module-ownership mapping.
///
/// NOTE: These permission identifiers represent frontend mock fixtures
/// and will align with the backend contract in future phases.
abstract final class CrmPermissions {
  // Lead Management
  static const String leadView = 'lead.view';
  static const String leadViewAssigned = 'lead.view_assigned';
  static const String leadCreate = 'lead.create';
  static const String leadEdit = 'lead.edit';
  static const String leadUpdate = 'lead.update';
  static const String leadDelete = 'lead.delete';
  static const String leadAssign = 'lead.assign';
  static const String leadImportCsv = 'lead.import.csv';
  static const String leadImportXlsx = 'lead.import.xlsx';
  static const String leadExportCsv = 'lead.export.csv';
  static const String leadExportXlsx = 'lead.export.xlsx';

  // Calling
  static const String callingUse = 'calling.use';

  // HR / Payroll
  static const String hrView = 'hr.view';
  static const String hrEmployeeManage = 'hr.employee.manage';
  static const String hrDocumentsView = 'hr.documents.view';
  static const String hrDocumentsManage = 'hr.documents.manage';
  static const String hrPerformanceManage = 'hr.performance.manage';
  static const String attendanceManage = 'attendance.manage';
  static const String shiftManage = 'shift.manage';
  static const String attendancePolicyManage = 'attendance_policy.manage';
  static const String timesheetApprove = 'timesheet.approve';
  static const String leaveManage = 'leave.manage';
  static const String payrollView = 'payroll.view';
  static const String payrollConfigManage = 'payroll.config.manage';
  static const String payrollSalaryView = 'payroll.salary.view';
  static const String payrollSalaryEdit = 'payroll.salary.edit';
  static const String payrollRunView = 'payroll.run.view';
  static const String payrollRunCreate = 'payroll.run.create';
  static const String payrollRunApprove = 'payroll.run.approve';
  static const String payrollRunLock = 'payroll.run.lock';
  static const String payrollPaymentRelease = 'payroll.payment.release';
  static const String payrollPayslipViewAll = 'payroll.payslip.view_all';
  static const String payrollTaxVerify = 'payroll.tax.verify';
  static const String payrollComplianceView = 'payroll.compliance.view';
  static const String payrollReportsView = 'payroll.reports.view';

  // Inventory
  static const String inventoryView = 'inventory.view';
  static const String inventoryCreate = 'inventory.create';
  static const String inventoryEdit = 'inventory.edit';
  static const String inventoryDelete = 'inventory.delete';
  static const String inventoryStockManage = 'inventory.stock.manage';
  static const String inventoryImportCsv = 'inventory.import.csv';
  static const String inventoryImportXlsx = 'inventory.import.xlsx';
  static const String inventoryExportCsv = 'inventory.export.csv';
  static const String inventoryExportXlsx = 'inventory.export.xlsx';

  // Purchase
  static const String purchaseView = 'purchase.view';
  static const String purchaseCreate = 'purchase.create';
  static const String purchaseApprove = 'purchase.approve';
  static const String purchaseReceiveStock = 'purchase.receive_stock';
  static const String purchaseExportCsv = 'purchase.export.csv';
  static const String purchaseExportPdf = 'purchase.export.pdf';
  static const String purchaseDownloadBill = 'purchase.bill.download';

  // Vendor Management
  static const String vendorView = 'vendor.view';
  static const String vendorCreate = 'vendor.create';
  static const String vendorEdit = 'vendor.edit';
  static const String vendorDelete = 'vendor.delete';
  static const String vendorExportCsv = 'vendor.export.csv';

  // Dispatch
  static const String dispatchView = 'dispatch.view';
  static const String dispatchCreate = 'dispatch.create';
  static const String dispatchUpdateStatus = 'dispatch.update_status';
  static const String dispatchExportCsv = 'dispatch.export.csv';
  static const String dispatchExportXlsx = 'dispatch.export.xlsx';
  static const String dispatchExportPdf = 'dispatch.export.pdf';
  static const String dispatchDownloadBill = 'dispatch.bill.download';

  // Approvals & Notifications
  static const String approvalsView = 'approvals.view';
  static const String approvalsAction = 'approvals.action';
  static const String approvalsSubmit = 'approvals.submit';
  static const String approvalsExport = 'approvals.export';
  static const String notificationsView = 'notifications.view';
  static const String notificationsManage = 'notifications.manage';

  /// Canonical mapping of permission identifiers to their owning CRM modules.
  static const Map<String, CrmModule> _moduleByPermission = {
    leadView: CrmModule.leadManagement,
    leadViewAssigned: CrmModule.leadManagement,
    leadCreate: CrmModule.leadManagement,
    leadEdit: CrmModule.leadManagement,
    leadUpdate: CrmModule.leadManagement,
    leadDelete: CrmModule.leadManagement,
    leadAssign: CrmModule.leadManagement,
    leadImportCsv: CrmModule.leadManagement,
    leadImportXlsx: CrmModule.leadManagement,
    leadExportCsv: CrmModule.leadManagement,
    leadExportXlsx: CrmModule.leadManagement,
    callingUse: CrmModule.calling,
    hrView: CrmModule.hrPayroll,
    hrEmployeeManage: CrmModule.hrPayroll,
    hrDocumentsView: CrmModule.hrPayroll,
    hrDocumentsManage: CrmModule.hrPayroll,
    hrPerformanceManage: CrmModule.hrPayroll,
    attendanceManage: CrmModule.hrPayroll,
    shiftManage: CrmModule.hrPayroll,
    attendancePolicyManage: CrmModule.hrPayroll,
    timesheetApprove: CrmModule.hrPayroll,
    leaveManage: CrmModule.hrPayroll,
    payrollView: CrmModule.hrPayroll,
    payrollConfigManage: CrmModule.hrPayroll,
    payrollSalaryView: CrmModule.hrPayroll,
    payrollSalaryEdit: CrmModule.hrPayroll,
    payrollRunView: CrmModule.hrPayroll,
    payrollRunCreate: CrmModule.hrPayroll,
    payrollRunApprove: CrmModule.hrPayroll,
    payrollRunLock: CrmModule.hrPayroll,
    payrollPaymentRelease: CrmModule.hrPayroll,
    payrollPayslipViewAll: CrmModule.hrPayroll,
    payrollTaxVerify: CrmModule.hrPayroll,
    payrollComplianceView: CrmModule.hrPayroll,
    payrollReportsView: CrmModule.hrPayroll,
    inventoryView: CrmModule.inventory,
    inventoryCreate: CrmModule.inventory,
    inventoryEdit: CrmModule.inventory,
    inventoryDelete: CrmModule.inventory,
    inventoryStockManage: CrmModule.inventory,
    inventoryImportCsv: CrmModule.inventory,
    inventoryImportXlsx: CrmModule.inventory,
    inventoryExportCsv: CrmModule.inventory,
    inventoryExportXlsx: CrmModule.inventory,
    purchaseView: CrmModule.purchase,
    purchaseCreate: CrmModule.purchase,
    purchaseApprove: CrmModule.purchase,
    purchaseReceiveStock: CrmModule.purchase,
    purchaseExportCsv: CrmModule.purchase,
    purchaseExportPdf: CrmModule.purchase,
    purchaseDownloadBill: CrmModule.purchase,
    vendorView: CrmModule.vendorManagement,
    vendorCreate: CrmModule.vendorManagement,
    vendorEdit: CrmModule.vendorManagement,
    vendorDelete: CrmModule.vendorManagement,
    vendorExportCsv: CrmModule.vendorManagement,
    dispatchView: CrmModule.dispatch,
    dispatchCreate: CrmModule.dispatch,
    dispatchUpdateStatus: CrmModule.dispatch,
    dispatchExportCsv: CrmModule.dispatch,
    dispatchExportXlsx: CrmModule.dispatch,
    dispatchExportPdf: CrmModule.dispatch,
    dispatchDownloadBill: CrmModule.dispatch,
    approvalsView: CrmModule.approvalsNotifications,
    approvalsAction: CrmModule.approvalsNotifications,
    approvalsSubmit: CrmModule.approvalsNotifications,
    approvalsExport: CrmModule.approvalsNotifications,
    notificationsView: CrmModule.approvalsNotifications,
    notificationsManage: CrmModule.approvalsNotifications,
  };

  /// Returns whether [permission] is a recognized permission identifier.
  static bool isKnown(String permission) =>
      _moduleByPermission.containsKey(permission);

  /// Returns the canonical [CrmModule] that owns [permission], or `null` if unrecognized.
  static CrmModule? moduleFor(String permission) =>
      _moduleByPermission[permission];

  /// Returns all available permissions belonging to the specified [module].
  static Set<String> permissionsFor(CrmModule module) {
    return _moduleByPermission.entries
        .where((entry) => entry.value == module)
        .map((entry) => entry.key)
        .toSet();
  }

  /// Returns all known permission identifiers.
  static Set<String> get allKnown => Set.unmodifiable(_moduleByPermission.keys);
}
