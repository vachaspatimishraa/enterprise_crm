import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_config.dart';
import '../../../auth/domain/entities/crm_module.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../../../dispatch/data/repositories/mock_dispatch_repository.dart';
import '../../../dispatch/domain/repositories/dispatch_repository.dart';
import '../../../dispatch/presentation/screens/dispatch_workspace_screen.dart';
import '../../../hr/data/repositories/mock_attendance_repository.dart';
import '../../../hr/data/repositories/mock_employee_document_repository.dart';
import '../../../hr/data/repositories/mock_employee_kpi_repository.dart';
import '../../../hr/data/repositories/mock_employee_repository.dart';
import '../../../hr/domain/repositories/attendance_repository.dart';
import '../../../hr/domain/repositories/employee_document_repository.dart';
import '../../../hr/domain/repositories/employee_kpi_repository.dart';
import '../../../hr/domain/repositories/employee_repository.dart';
import '../../../hr/presentation/screens/hr_home_screen.dart';
import '../../../inventory/domain/repositories/inventory_repository.dart';
import '../../../inventory/data/repositories/mock_inventory_repository.dart';
import '../../../inventory/presentation/screens/inventory_workspace_screen.dart';
import '../../../auth/domain/repositories/user_lead_link_repository.dart';
import '../../../auth/data/repositories/mock_user_lead_link_repository.dart';
import '../../../calling/data/repositories/mock_lead_call_activity_repository.dart';
import '../../../calling/data/repositories/mock_lead_follow_up_repository.dart';
import '../../../calling/domain/repositories/lead_call_activity_repository.dart';
import '../../../calling/domain/repositories/lead_follow_up_repository.dart';
import '../../../calling/presentation/screens/user_calling_workspace_screen.dart';
import '../../../leads/data/repositories/mock_lead_repository.dart';
import '../../../leads/domain/repositories/lead_repository.dart';
import '../../../purchase/data/repositories/mock_purchase_repository.dart';
import '../../../purchase/domain/repositories/purchase_repository.dart';
import '../../../purchase/presentation/screens/purchase_workspace_screen.dart';
import '../../../user_management/domain/repositories/user_management_repository.dart';
import '../../../user_management/presentation/screens/users_and_access_screen.dart';
import '../../../vendors/data/repositories/mock_vendor_repository.dart';
import '../../../vendors/domain/repositories/vendor_repository.dart';
import '../../../vendors/presentation/screens/vendor_workspace_screen.dart';
import '../../../approvals/data/repositories/mock_approval_repository.dart';
import '../../../approvals/domain/repositories/approval_repository.dart';
import '../../../approvals/presentation/screens/approvals_workspace_screen.dart';
import '../../../notifications/presentation/cubit/notification_cubit.dart';
import '../widgets/crm_app_header.dart';
import '../widgets/crm_module_card.dart';
import 'module_placeholder_screen.dart';

/// Global Admin Dashboard providing access to all 8 CRM business modules
/// and the Administration section.
class AdminDashboardScreen extends StatelessWidget {
  final AppConfig appConfig;
  final CurrentUser user;
  final VoidCallback onLogout;
  final VoidCallback onOpenLeadManagement;
  final InventoryRepository? inventoryRepository;
  final DispatchRepository? dispatchRepository;
  final AuthRepository? authRepository;
  final UserManagementRepository? userManagementRepository;
  final EmployeeRepository? employeeRepository;
  final EmployeeDocumentRepository? employeeDocumentRepository;
  final AttendanceRepository? attendanceRepository;
  final EmployeeKpiRepository? employeeKpiRepository;
  final PurchaseRepository? purchaseRepository;
  final VendorRepository? vendorRepository;
  final LeadRepository? leadRepository;
  final UserLeadLinkRepository? userLeadLinkRepository;
  final LeadCallActivityRepository? callActivityRepository;
  final LeadFollowUpRepository? leadFollowUpRepository;
  final ApprovalRepository? approvalRepository;
  final NotificationCubit? notificationCubit;

  const AdminDashboardScreen({
    super.key,
    this.appConfig = AppConfig.development,
    required this.user,
    required this.onLogout,
    required this.onOpenLeadManagement,
    this.inventoryRepository,
    this.dispatchRepository,
    this.authRepository,
    this.userManagementRepository,
    this.employeeRepository,
    this.employeeDocumentRepository,
    this.attendanceRepository,
    this.employeeKpiRepository,
    this.purchaseRepository,
    this.vendorRepository,
    this.leadRepository,
    this.userLeadLinkRepository,
    this.callActivityRepository,
    this.leadFollowUpRepository,
    this.approvalRepository,
    this.notificationCubit,
  });

  void _openModule(BuildContext context, CrmModule module) {
    if (module == CrmModule.leadManagement) {
      onOpenLeadManagement();
    } else if (module == CrmModule.hrPayroll) {
      final employees = employeeRepository ?? MockEmployeeRepository();
      final documents =
          employeeDocumentRepository ?? MockEmployeeDocumentRepository();
      final attendance = attendanceRepository ?? MockAttendanceRepository();
      final kpis = employeeKpiRepository ?? MockEmployeeKpiRepository();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => HrHomeScreen(
            user: user,
            appConfig: appConfig,
            repository: employees,
            documentRepository: documents,
            attendanceRepository: attendance,
            kpiRepository: kpis,
          ),
        ),
      );
    } else if (module == CrmModule.inventory) {
      AuthCubit? authCubit;
      try {
        authCubit = context.read<AuthCubit?>();
      } catch (_) {}

      CurrentUser? currentInventoryUser() {
        if (authCubit == null || authCubit.isClosed) {
          return null;
        }
        final state = authCubit.state;
        return state is AuthAuthenticated ? state.user : null;
      }

      Widget screen = InventoryWorkspaceScreen(
        user: user,
        repository: inventoryRepository ?? MockInventoryRepository(),
        currentUserProvider: currentInventoryUser,
      );

      if (authCubit != null) {
        screen = BlocProvider<AuthCubit>.value(value: authCubit, child: screen);
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => screen,
        ),
      );
    } else if (module == CrmModule.dispatch) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DispatchWorkspaceScreen(
            user: user,
            repository: dispatchRepository ?? MockDispatchRepository(),
          ),
        ),
      );
    } else if (module == CrmModule.purchase) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PurchaseWorkspaceScreen(
            user: user,
            repository: purchaseRepository ?? MockPurchaseRepository(),
          ),
        ),
      );
    } else if (module == CrmModule.calling) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UserCallingWorkspaceScreen(
            user: user,
            leadRepository: leadRepository ?? MockLeadRepository(),
            linkRepository:
                userLeadLinkRepository ?? MockUserLeadLinkRepository(),
            callActivityRepository:
                callActivityRepository ?? MockLeadCallActivityRepository.seeded(),
            leadFollowUpRepository:
                leadFollowUpRepository ?? MockLeadFollowUpRepository.seeded(),
          ),
        ),
      );
    } else if (module == CrmModule.vendorManagement) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VendorWorkspaceScreen(
            user: user,
            repository: vendorRepository ?? MockVendorRepository(),
            purchaseRepository: purchaseRepository,
          ),
        ),
      );
    } else if (module == CrmModule.approvalsNotifications) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ApprovalsWorkspaceScreen(
            user: user,
            repository: approvalRepository ?? MockApprovalRepository(),
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ModulePlaceholderScreen(module: module, user: user),
        ),
      );
    }
  }

  void _openUsersAndAccess(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UsersAndAccessScreen(
          user: user,
          repository: userManagementRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final width = MediaQuery.of(context).size.width;

    final crossAxisCount = width < 600
        ? 1
        : width < 1000
        ? 2
        : 4;

    const allModules = CrmModule.values;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            CrmAppHeader(
              user: user,
              onLogout: onLogout,
              userManagementRepository: userManagementRepository,
              authRepository: authRepository,
              notificationCubit: notificationCubit,
              approvalRepository: approvalRepository,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: width < 400 ? 14.0 : 24.0,
                  vertical: 20.0,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Page Title & Subtitle
                        Text(
                          'ADMIN DASHBOARD',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Full system access across all enterprise modules.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Business Modules Section Header
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'BUSINESS MODULES',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                  letterSpacing: 0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${allModules.length}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Business Modules Grid
                        GridView.builder(
                          key: const Key('admin_business_modules_grid'),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                mainAxisExtent: 160,
                              ),
                          itemCount: allModules.length,
                          itemBuilder: (context, index) {
                            final module = allModules[index];
                            return CrmModuleCard(
                              module: module,
                              onTap: () => _openModule(context, module),
                            );
                          },
                        ),
                        const SizedBox(height: 36),

                        // Administration Section Header
                        Text(
                          'ADMINISTRATION',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.secondary,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Users & Access Card
                        SizedBox(
                          width: crossAxisCount == 1 ? double.infinity : 320,
                          child: Card(
                            key: const Key('admin_card_users_and_access'),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            color: colorScheme.surfaceContainerLowest,
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => _openUsersAndAccess(context),
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color:
                                                colorScheme.secondaryContainer,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.admin_panel_settings_outlined,
                                            size: 26,
                                            color: colorScheme
                                                .onSecondaryContainer,
                                          ),
                                        ),
                                        const Spacer(),
                                        Icon(
                                          Icons.arrow_forward_ios,
                                          size: 14,
                                          color: colorScheme.onSurfaceVariant
                                              .withValues(alpha: 0.6),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Users & Access',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'User creation, permissions, and credential control',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
