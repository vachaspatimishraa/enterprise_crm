import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/auth/domain/entities/crm_module.dart';
import 'package:enterprise_crm/features/auth/domain/entities/current_user.dart';
import 'package:enterprise_crm/features/auth/domain/policies/crm_permissions.dart';
import 'package:enterprise_crm/features/hr/domain/policies/hr_access_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HrAccessPolicy', () {
    const adminUser = CurrentUser(
      id: 'usr_admin',
      displayName: 'System Admin',
      accountType: AccountType.admin,
      modules: {},
      permissions: {},
    );

    const hrAndPayrollUser = CurrentUser(
      id: 'usr_hr_payroll',
      displayName: 'HR & Payroll Specialist',
      accountType: AccountType.user,
      modules: {CrmModule.hrPayroll},
      permissions: {CrmPermissions.hrView, CrmPermissions.payrollView},
    );

    const hrOnlyUser = CurrentUser(
      id: 'usr_hr_only',
      displayName: 'HR Specialist',
      accountType: AccountType.user,
      modules: {CrmModule.hrPayroll},
      permissions: {CrmPermissions.hrView},
    );

    const payrollOnlyUser = CurrentUser(
      id: 'usr_payroll_only',
      displayName: 'Payroll Specialist',
      accountType: AccountType.user,
      modules: {CrmModule.hrPayroll},
      permissions: {CrmPermissions.payrollView},
    );

    const unassignedModuleUser = CurrentUser(
      id: 'usr_sales',
      displayName: 'Sales Representative',
      accountType: AccountType.user,
      modules: {CrmModule.leadManagement},
      permissions: {CrmPermissions.leadViewAssigned},
    );

    const moduleAssignedNoPermissionsUser = CurrentUser(
      id: 'usr_hr_blank',
      displayName: 'HR Trainee',
      accountType: AccountType.user,
      modules: {CrmModule.hrPayroll},
      permissions: {},
    );

    const permissionWithoutModuleUser = CurrentUser(
      id: 'usr_orphan_perm',
      displayName: 'User with Orphan HR Permission',
      accountType: AccountType.user,
      modules: {CrmModule.leadManagement},
      permissions: {CrmPermissions.hrView, CrmPermissions.payrollView},
    );

    group('canAccessModule', () {
      test('grants access unconditionally to Administrator', () {
        expect(HrAccessPolicy.canAccessModule(adminUser), isTrue);
      });

      test('grants access to standard user when hrPayroll is assigned', () {
        expect(HrAccessPolicy.canAccessModule(hrAndPayrollUser), isTrue);
        expect(HrAccessPolicy.canAccessModule(hrOnlyUser), isTrue);
        expect(HrAccessPolicy.canAccessModule(payrollOnlyUser), isTrue);
        expect(
          HrAccessPolicy.canAccessModule(moduleAssignedNoPermissionsUser),
          isTrue,
        );
      });

      test('denies access to standard user when hrPayroll is not assigned', () {
        expect(HrAccessPolicy.canAccessModule(unassignedModuleUser), isFalse);
        expect(
          HrAccessPolicy.canAccessModule(permissionWithoutModuleUser),
          isFalse,
        );
      });
    });

    group('canViewHrRecords', () {
      test('grants view access unconditionally to Administrator', () {
        expect(HrAccessPolicy.canViewHrRecords(adminUser), isTrue);
      });

      test(
        'grants view access to user with hrPayroll module and hr.view permission',
        () {
          expect(HrAccessPolicy.canViewHrRecords(hrAndPayrollUser), isTrue);
          expect(HrAccessPolicy.canViewHrRecords(hrOnlyUser), isTrue);
        },
      );

      test('denies view access when hr.view permission is absent', () {
        expect(HrAccessPolicy.canViewHrRecords(payrollOnlyUser), isFalse);
        expect(
          HrAccessPolicy.canViewHrRecords(moduleAssignedNoPermissionsUser),
          isFalse,
        );
      });

      test(
        'denies view access when hrPayroll module is unassigned, even if permission exists',
        () {
          expect(
            HrAccessPolicy.canViewHrRecords(permissionWithoutModuleUser),
            isFalse,
          );
        },
      );
    });

    group('canViewPayroll', () {
      test('grants payroll view access unconditionally to Administrator', () {
        expect(HrAccessPolicy.canViewPayroll(adminUser), isTrue);
      });

      test(
        'grants payroll view access to user with hrPayroll module and payroll.view permission',
        () {
          expect(HrAccessPolicy.canViewPayroll(hrAndPayrollUser), isTrue);
          expect(HrAccessPolicy.canViewPayroll(payrollOnlyUser), isTrue);
        },
      );

      test(
        'denies payroll view access when payroll.view permission is absent',
        () {
          expect(HrAccessPolicy.canViewPayroll(hrOnlyUser), isFalse);
          expect(
            HrAccessPolicy.canViewPayroll(moduleAssignedNoPermissionsUser),
            isFalse,
          );
        },
      );

      test(
        'denies payroll view access when hrPayroll module is unassigned, even if permission exists',
        () {
          expect(
            HrAccessPolicy.canViewPayroll(permissionWithoutModuleUser),
            isFalse,
          );
        },
      );
    });
  });
}
