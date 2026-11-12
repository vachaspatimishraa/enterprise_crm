import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'bootstrap/hr_payroll_dependencies.dart';
import '../core/config/app_config.dart';
import '../core/localization/crm_localizations.dart';
import '../core/localization/locale_controller.dart';
import '../core/logging/crm_logger.dart';
import '../core/security/auth_token_vault.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_mode_controller.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/domain/repositories/user_lead_link_repository.dart';
import '../features/auth/presentation/bloc/auth_cubit.dart';
import '../features/auth/presentation/bloc/auth_state.dart';
import '../features/auth/presentation/screens/access_restricted_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/dashboard/presentation/screens/admin_dashboard_screen.dart';
import '../features/dashboard/presentation/screens/user_dashboard_screen.dart';
import '../features/user_management/domain/repositories/user_management_repository.dart';
import '../features/leads/domain/entities/lead.dart';
import '../features/leads/domain/entities/lead_query.dart';
import '../features/leads/domain/repositories/lead_repository.dart';
import '../features/leads/presentation/bloc/lead_dashboard_cubit.dart';
import '../features/leads/presentation/bloc/lead_details_cubit.dart';
import '../features/leads/presentation/bloc/lead_list_cubit.dart';
import '../features/leads/presentation/screens/add_lead_screen.dart';
import '../features/leads/presentation/screens/edit_lead_screen.dart';
import '../features/leads/presentation/screens/lead_dashboard_screen.dart';
import '../features/leads/presentation/screens/lead_details_screen.dart';
import '../features/leads/presentation/screens/lead_import_workflow_screen.dart';
import '../features/leads/data/services/lead_export_file_saver.dart';
import '../features/leads/presentation/screens/lead_list_screen.dart';
import '../features/calling/domain/repositories/lead_call_activity_repository.dart';
import '../features/calling/domain/repositories/lead_follow_up_repository.dart';
import '../features/dispatch/data/repositories/mock_dispatch_repository.dart';
import '../features/dispatch/domain/repositories/dispatch_repository.dart';
import '../features/purchase/data/repositories/mock_purchase_repository.dart';
import '../features/purchase/domain/repositories/purchase_repository.dart';
import '../features/vendors/data/repositories/mock_vendor_repository.dart';
import '../features/vendors/domain/repositories/vendor_repository.dart';
import '../features/hr/domain/repositories/attendance_repository.dart';
import '../features/hr/domain/repositories/employee_document_repository.dart';
import '../features/hr/domain/repositories/employee_kpi_repository.dart';
import '../features/hr/domain/repositories/employee_repository.dart';
import '../features/inventory/domain/repositories/inventory_repository.dart';
import '../features/leads/presentation/services/lead_import_file_picker.dart';
import '../features/leads/presentation/widgets/lead_export_dialog.dart';
import 'dart:async';
import '../features/payroll/presentation/navigation/payroll_routes.dart';
import '../features/payroll/configuration/domain/payroll_configuration_repository.dart';
import '../features/payroll/operations/domain/payroll_operations_repository.dart';
import '../features/approvals/domain/repositories/approval_repository.dart';
import '../features/approvals/data/repositories/mock_approval_repository.dart';
import '../features/approvals/domain/services/approval_bridge.dart';
import '../features/approvals/data/services/default_approval_bridge.dart';
import '../features/notifications/data/repositories/mock_notification_repository.dart';
import '../features/notifications/domain/repositories/notification_repository.dart';
import '../features/notifications/domain/services/notification_dispatcher.dart';
import '../features/notifications/domain/entities/crm_notification.dart';
import '../features/notifications/domain/entities/notification_priority.dart';
import '../features/notifications/presentation/cubit/notification_cubit.dart';
import '../features/notifications/presentation/cubit/notification_toast_cubit.dart';
import '../features/notifications/presentation/cubit/notification_toast_state.dart';
import '../features/notifications/presentation/navigation/deep_link_navigation_resolver.dart';

/// Top-level application widget for the Enterprise CRM.
class CrmApp extends StatefulWidget {
  final AppConfig appConfig;
  final LeadRepository leadRepository;
  final LeadImportFilePicker? filePicker;
  final LeadExportFileSaver? exportFileSaver;
  final AuthRepository? authRepository;
  final UserManagementRepository? userManagementRepository;
  final UserLeadLinkRepository? userLeadLinkRepository;
  final LeadCallActivityRepository? leadCallActivityRepository;
  final LeadFollowUpRepository? leadFollowUpRepository;
  final EmployeeRepository? employeeRepository;
  final EmployeeDocumentRepository? employeeDocumentRepository;
  final AttendanceRepository? attendanceRepository;
  final EmployeeKpiRepository? employeeKpiRepository;
  final InventoryRepository? inventoryRepository;
  final DispatchRepository? dispatchRepository;
  final PurchaseRepository? purchaseRepository;
  final VendorRepository? vendorRepository;
  final PayrollOperationsRepository? payrollOperationsRepository;
  final PayrollConfigurationRepository? payrollConfigurationRepository;
  final HrPayrollDependencies? hrPayrollDependencies;
  final ApprovalRepository? approvalRepository;
  final NotificationRepository? notificationRepository;
  final ApprovalBridge? approvalBridge;
  final NotificationDispatcher? notificationDispatcher;
  final AuthTokenVault? authTokenVault;

  const CrmApp({
    super.key,
    this.appConfig = AppConfig.development,
    required this.leadRepository,
    this.filePicker,
    this.exportFileSaver,
    this.authRepository,
    this.userManagementRepository,
    this.userLeadLinkRepository,
    this.leadCallActivityRepository,
    this.leadFollowUpRepository,
    this.employeeRepository,
    this.employeeDocumentRepository,
    this.attendanceRepository,
    this.employeeKpiRepository,
    this.inventoryRepository,
    this.dispatchRepository,
    this.purchaseRepository,
    this.vendorRepository,
    this.payrollOperationsRepository,
    this.payrollConfigurationRepository,
    this.hrPayrollDependencies,
    this.approvalRepository,
    this.notificationRepository,
    this.approvalBridge,
    this.notificationDispatcher,
    this.authTokenVault,
  }) : assert(
         authRepository == null || userManagementRepository != null,
         'userManagementRepository must be provided when authRepository is enabled',
       ),
       assert(
         authRepository == null || userLeadLinkRepository != null,
         'userLeadLinkRepository must be provided when authRepository is enabled',
       ),
       assert(
         authRepository == null || leadCallActivityRepository != null,
         'leadCallActivityRepository must be provided when authRepository is enabled',
       ),
       assert(
         authRepository == null ||
             leadCallActivityRepository == null ||
             leadFollowUpRepository != null,
         'leadFollowUpRepository must be provided when Calling is enabled with auth',
       ),
       assert(
         authRepository == null || inventoryRepository != null,
         'inventoryRepository must be provided when authRepository is enabled',
       );

  @override
  State<CrmApp> createState() => _CrmAppState();
}

class _CrmAppState extends State<CrmApp> {
  AuthCubit? _authCubit;
  late final DispatchRepository _dispatchRepository;
  late final PurchaseRepository _purchaseRepository;
  late final VendorRepository _vendorRepository;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  EmployeeRepository? get _employeeRepository =>
      widget.employeeRepository ?? widget.hrPayrollDependencies?.employees;
  EmployeeDocumentRepository? get _employeeDocumentRepository =>
      widget.employeeDocumentRepository ??
      widget.hrPayrollDependencies?.employeeDocuments;
  AttendanceRepository? get _attendanceRepository =>
      widget.attendanceRepository ?? widget.hrPayrollDependencies?.attendance;
  EmployeeKpiRepository? get _employeeKpiRepository =>
      widget.employeeKpiRepository ??
      widget.hrPayrollDependencies?.employeeKpis;
  PayrollConfigurationRepository? get _payrollConfigurationRepository =>
      widget.payrollConfigurationRepository ??
      widget.hrPayrollDependencies?.payrollConfiguration;
  PayrollOperationsRepository? get _payrollOperationsRepository =>
      widget.payrollOperationsRepository ??
      widget.hrPayrollDependencies?.payrollOperations;
  late final ApprovalRepository _defaultApprovalRepository =
      MockApprovalRepository();
  ApprovalRepository get _approvalRepository =>
      widget.approvalRepository ?? _defaultApprovalRepository;

  late final NotificationRepository _defaultNotificationRepository =
      MockNotificationRepository();
  NotificationRepository get _notificationRepository =>
      widget.notificationRepository ?? _defaultNotificationRepository;
  late final NotificationCubit _notificationCubit =
      NotificationCubit(_notificationRepository);

  late final NotificationDispatcher _defaultNotificationDispatcher =
      DefaultNotificationDispatcher(_notificationRepository);
  NotificationDispatcher get _notificationDispatcher =>
      widget.notificationDispatcher ?? _defaultNotificationDispatcher;

  late final ApprovalBridge _defaultApprovalBridge =
      DefaultApprovalBridge(
        repository: _approvalRepository,
        notificationDispatcher: _notificationDispatcher,
      );
  ApprovalBridge get _approvalBridge =>
      widget.approvalBridge ?? _defaultApprovalBridge;

  late final NotificationToastCubit _notificationToastCubit =
      NotificationToastCubit();
  StreamSubscription<List<CrmNotification>>? _toastNotificationSubscription;
  final Set<String> _seenToastNotificationIds = <String>{};

  @override
  void initState() {
    super.initState();
    _dispatchRepository = widget.dispatchRepository ?? MockDispatchRepository();
    _purchaseRepository = widget.purchaseRepository ?? MockPurchaseRepository();
    _vendorRepository = widget.vendorRepository ?? MockVendorRepository();
    if (widget.authRepository != null) {
      _authCubit = AuthCubit(widget.authRepository!);
      final authState = _authCubit!.state;
      if (authState is AuthAuthenticated) {
        _notificationCubit.watchNotifications(authState.user.id);
      }
    }
  }

  @override
  void didUpdateWidget(covariant CrmApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.authRepository != oldWidget.authRepository) {
      _authCubit?.close();
      _authCubit = widget.authRepository != null
          ? AuthCubit(widget.authRepository!)
          : null;
    }
  }

  @override
  void dispose() {
    _toastNotificationSubscription?.cancel();
    _authCubit?.close();
    _notificationCubit.close();
    _notificationToastCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_authCubit != null) {
      content = BlocProvider<AuthCubit>.value(
        value: _authCubit!,
        child: BlocConsumer<AuthCubit, AuthState>(
          listener: (context, state) {
            if (state is AuthAuthenticated) {
              _notificationCubit.watchNotifications(state.user.id);
              _toastNotificationSubscription?.cancel();
              var isFirstEmission = true;
              _seenToastNotificationIds.clear();
              _toastNotificationSubscription = _notificationRepository
                  .watchNotifications(state.user.id)
                  .listen((notifications) {
                if (isFirstEmission) {
                  _seenToastNotificationIds
                      .addAll(notifications.map((n) => n.id));
                  isFirstEmission = false;
                  return;
                }
                for (final n in notifications) {
                  if (!_seenToastNotificationIds.contains(n.id)) {
                    _seenToastNotificationIds.add(n.id);
                    if (!n.isRead) {
                      _notificationToastCubit.handleIncomingNotification(n);
                    }
                  }
                }
              });
            } else if (state is AuthUnauthenticated) {
              _toastNotificationSubscription?.cancel();
              _toastNotificationSubscription = null;
              _seenToastNotificationIds.clear();
              _navigatorKey.currentState?.popUntil((route) => route.isFirst);
            }
          },
          builder: (context, state) {
            switch (state) {
              case AuthAuthenticated(:final user):
                if (user.isAdmin) {
                  return AdminDashboardScreen(
                    user: user,
                    appConfig: widget.appConfig,
                    onLogout: () => _authCubit!.logout(),
                    inventoryRepository: widget.inventoryRepository!,
                    dispatchRepository: _dispatchRepository,
                    purchaseRepository: _purchaseRepository,
                    vendorRepository: _vendorRepository,
                    authRepository: widget.authRepository,
                    userManagementRepository: widget.userManagementRepository,
                    employeeRepository: _employeeRepository,
                    employeeDocumentRepository: _employeeDocumentRepository,
                    attendanceRepository: _attendanceRepository,
                    employeeKpiRepository: _employeeKpiRepository,
                    leadRepository: widget.leadRepository,
                    userLeadLinkRepository: widget.userLeadLinkRepository,
                    callActivityRepository: widget.leadCallActivityRepository,
                    leadFollowUpRepository: widget.leadFollowUpRepository,
                    approvalRepository: _approvalRepository,
                    notificationCubit: _notificationCubit,
                    onOpenLeadManagement: () {
                      _navigatorKey.currentState?.push(
                        MaterialPageRoute(
                          builder: (_) => CrmHomeScreen(
                            repository: widget.leadRepository,
                            filePicker: widget.filePicker,
                            exportFileSaver: widget.exportFileSaver,
                            onLogout: () => _authCubit!.logout(),
                          ),
                        ),
                      );
                    },
                  );
                } else {
                  return UserDashboardScreen(
                    user: user,
                    appConfig: widget.appConfig,
                    onLogout: () => _authCubit!.logout(),
                    userLeadLinkRepository: widget.userLeadLinkRepository!,
                    leadRepository: widget.leadRepository,
                    callActivityRepository: widget.leadCallActivityRepository!,
                    leadFollowUpRepository: widget.leadFollowUpRepository!,
                    employeeRepository: _employeeRepository,
                    employeeDocumentRepository: _employeeDocumentRepository,
                    attendanceRepository: _attendanceRepository,
                    employeeKpiRepository: _employeeKpiRepository,
                    inventoryRepository: widget.inventoryRepository!,
                    dispatchRepository: _dispatchRepository,
                    purchaseRepository: _purchaseRepository,
                    vendorRepository: _vendorRepository,
                    approvalRepository: _approvalRepository,
                    notificationCubit: _notificationCubit,
                    authRepository: widget.authRepository,
                    userManagementRepository: widget.userManagementRepository,
                  );
                }
              case AuthUnauthenticated():
              case AuthAuthenticating():
              case AuthFailure():
                return LoginScreen(authRepository: widget.authRepository);
            }
          },
        ),
      );
    } else {
      // Legacy fallback for baseline tests without authentication configured
      content = CrmHomeScreen(
        repository: widget.leadRepository,
        filePicker: widget.filePicker,
        exportFileSaver: widget.exportFileSaver,
      );
    }

    Widget app = ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeModeController.instance,
      builder: (context, themeMode, _) {
        return ValueListenableBuilder<Locale>(
          valueListenable: LocaleController.instance,
          builder: (context, currentLocale, _) {
            return MaterialApp(
              navigatorKey: _navigatorKey,
              title: 'Vinay Enterprise CRM',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: themeMode,
              locale: currentLocale,
              localizationsDelegates: const [
                CrmLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: CrmLocalizations.supportedLocales,
              builder: (context, child) {
                return BlocListener<NotificationToastCubit, NotificationToastState>(
                  listener: (context, toastState) {
                    if (toastState is NotificationToastShow) {
                  final notification = toastState.notification;
                  final isCritical =
                      notification.priority == NotificationPriority.critical;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: isCritical
                          ? const Color(0xFFB00020)
                          : const Color(0xFFE65100),
                      content: Row(
                        children: [
                          Icon(
                            isCritical
                                ? Icons.warning_rounded
                                : Icons.info_outline_rounded,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notification.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  notification.body,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      action: SnackBarAction(
                        label: 'View',
                        textColor: Colors.white,
                        onPressed: () {
                          final authState = _authCubit?.state;
                          final currentUser = authState is AuthAuthenticated
                              ? authState.user
                              : null;
                          if (currentUser != null &&
                              _navigatorKey.currentContext != null) {
                            DeepLinkNavigationResolver.resolve(
                              _navigatorKey.currentContext!,
                              notification: notification,
                              user: currentUser,
                              approvalRepository: _approvalRepository,
                            );
                          }
                        },
                      ),
                    ),
                  );
                }
              },
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: content,
          onGenerateRoute: (settings) {
        if (settings.name?.startsWith('/payroll') != true) return null;
        final authState = _authCubit?.state;
        final currentUser = authState is AuthAuthenticated
            ? authState.user
            : null;
        final configurationRepository = _payrollConfigurationRepository;
        final operationsRepository = _payrollOperationsRepository;
        if (configurationRepository == null || operationsRepository == null) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const AccessRestrictedScreen(),
          );
        }
        return PayrollRoutes.onGenerateRoute(
          settings,
          user: currentUser,
          config: widget.appConfig,
          configurationRepository: configurationRepository,
          operationsRepository: operationsRepository,
        );
      },
    );
        },
      );
    },
  );

    if (widget.authRepository != null) {
      app = RepositoryProvider<AuthRepository>.value(
        value: widget.authRepository!,
        child: app,
      );
    }

    if (widget.userManagementRepository != null) {
      app = RepositoryProvider<UserManagementRepository>.value(
        value: widget.userManagementRepository!,
        child: app,
      );
    }

    if (widget.userLeadLinkRepository != null) {
      app = RepositoryProvider<UserLeadLinkRepository>.value(
        value: widget.userLeadLinkRepository!,
        child: app,
      );
    }

    if (widget.leadFollowUpRepository != null) {
      app = RepositoryProvider<LeadFollowUpRepository>.value(
        value: widget.leadFollowUpRepository!,
        child: app,
      );
    }

    if (_employeeRepository != null) {
      app = RepositoryProvider<EmployeeRepository>.value(
        value: _employeeRepository!,
        child: app,
      );
    }
    if (_employeeDocumentRepository != null) {
      app = RepositoryProvider<EmployeeDocumentRepository>.value(
        value: _employeeDocumentRepository!,
        child: app,
      );
    }
    if (_attendanceRepository != null) {
      app = RepositoryProvider<AttendanceRepository>.value(
        value: _attendanceRepository!,
        child: app,
      );
    }
    if (_employeeKpiRepository != null) {
      app = RepositoryProvider<EmployeeKpiRepository>.value(
        value: _employeeKpiRepository!,
        child: app,
      );
    }

    app = RepositoryProvider<ApprovalRepository>.value(
      value: _approvalRepository,
      child: RepositoryProvider<ApprovalBridge>.value(
        value: _approvalBridge,
        child: app,
      ),
    );

    app = RepositoryProvider<NotificationRepository>.value(
      value: _notificationRepository,
      child: RepositoryProvider<NotificationDispatcher>.value(
        value: _notificationDispatcher,
        child: BlocProvider<NotificationCubit>.value(
          value: _notificationCubit,
          child: BlocProvider<NotificationToastCubit>.value(
            value: _notificationToastCubit,
            child: app,
          ),
        ),
      ),
    );

    return RepositoryProvider<LeadRepository>.value(
      value: widget.leadRepository,
      child: RepositoryProvider<LeadExportFileSaver>.value(
        value: widget.exportFileSaver ?? const DefaultLeadExportFileSaver(),
        child: app,
      ),
    );
  }
}

/// Root CRM Home screen hosting the Lead Dashboard and coordinating navigation.
class CrmHomeScreen extends StatefulWidget {
  final LeadRepository repository;
  final LeadImportFilePicker? filePicker;
  final LeadExportFileSaver? exportFileSaver;
  final VoidCallback? onLogout;

  const CrmHomeScreen({
    super.key,
    required this.repository,
    this.filePicker,
    this.exportFileSaver,
    this.onLogout,
  });

  @override
  State<CrmHomeScreen> createState() => _CrmHomeScreenState();
}

class _CrmHomeScreenState extends State<CrmHomeScreen> {
  late final LeadDashboardCubit _dashboardCubit;
  late final LeadExportFileSaver _exportFileSaver;

  @override
  void initState() {
    super.initState();
    _dashboardCubit = LeadDashboardCubit(widget.repository)..loadDashboard();
    _exportFileSaver =
        widget.exportFileSaver ?? const DefaultLeadExportFileSaver();
  }

  @override
  void dispose() {
    _dashboardCubit.close();
    super.dispose();
  }

  void _openLeadList(
    BuildContext context, {
    LeadQuery initialQuery = const LeadQuery(),
  }) async {
    final listCubit = LeadListCubit(
      widget.repository,
      initialQuery: initialQuery,
    );
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (listContext) => LeadListScreen(
          cubit: listCubit,
          repository: widget.repository,
          filePicker: widget.filePicker,
          exportFileSaver: _exportFileSaver,
          initialQuery: initialQuery,
          onViewLead: (lead) => _openLeadDetails(
            listContext,
            lead.id,
            onAssigned: () => listCubit.refreshLeads(),
          ),
          onAddLead: () => _openAddLead(
            listContext,
            onCreated: () => listCubit.refreshLeads(),
          ),
        ),
      ),
    );
    listCubit.close();
    if (mounted) {
      _dashboardCubit.loadDashboard();
    }
  }

  void _openAddLead(BuildContext context, {VoidCallback? onCreated}) async {
    bool leadCreated = false;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (addContext) => AddLeadScreen(
          repository: widget.repository,
          onLeadCreated: (_) {
            leadCreated = true;
          },
          onCancel: () {
            Navigator.of(addContext).pop(false);
          },
        ),
      ),
    );

    if (leadCreated) {
      onCreated?.call();
      if (mounted) {
        _dashboardCubit.loadDashboard();
      }
    }
  }

  void _openLeadDetails(
    BuildContext context,
    String leadId, {
    VoidCallback? onAssigned,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (detailsContext) => LeadDetailsScreen(
          leadId: leadId,
          repository: widget.repository,
          onEditLead: (lead) => _openEditLead(detailsContext, lead),
          onLeadAssigned: onAssigned,
        ),
      ),
    );

    onAssigned?.call();
    if (mounted) {
      _dashboardCubit.loadDashboard();
    }
  }

  void _openEditLead(BuildContext context, Lead lead) async {
    bool leadUpdated = false;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (editContext) => EditLeadScreen(
          lead: lead,
          repository: widget.repository,
          onLeadUpdated: (_) {
            leadUpdated = true;
          },
          onCancel: () {
            Navigator.of(editContext).pop(false);
          },
        ),
      ),
    );

    if (leadUpdated) {
      if (context.mounted) {
        try {
          context.read<LeadDetailsCubit>().loadLead(lead.id);
        } catch (e, st) {
          CrmLogger.warning('CrmApp', 'LeadDetailsCubit not in scope for lead refresh', e, st);
        }
      }
      if (mounted) {
        _dashboardCubit.loadDashboard();
      }
    }
  }

  void _openImportWorkflow(BuildContext context) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LeadImportWorkflowScreen(
          repository: widget.repository,
          filePicker: widget.filePicker,
        ),
      ),
    );
    if (result == true && mounted) {
      _dashboardCubit.loadDashboard();
    }
  }

  void _openDistributeLeads(BuildContext context) async {
    final listCubit = LeadListCubit(
      widget.repository,
      initialQuery: const LeadQuery(isAssigned: false),
    );
    final didAssign = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (listContext) => LeadListScreen(
          cubit: listCubit,
          repository: widget.repository,
          filePicker: widget.filePicker,
          isDistributionMode: true,
          onViewLead: (lead) => _openLeadDetails(
            listContext,
            lead.id,
            onAssigned: () => listCubit.refreshLeads(),
          ),
        ),
      ),
    );
    listCubit.close();
    if (didAssign == true && mounted) {
      _dashboardCubit.loadDashboard();
    }
  }

  void _openExportLeads() async {
    final result = await showLeadExportDialog(
      context: context,
      repository: widget.repository,
      fileSaver: _exportFileSaver,
      query: const LeadQuery(),
      contextExplanation: 'All Leads will be exported.',
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lead export saved.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LeadDashboardScreen(
      cubit: _dashboardCubit,
      repository: widget.repository,
      filePicker: widget.filePicker,
      fileSaver: _exportFileSaver,
      onNavigateToLeads: (query) => _openLeadList(context, initialQuery: query),
      onAddLead: () => _openAddLead(context),
      onImportLeads: () => _openImportWorkflow(context),
      onDistributeLeads: () => _openDistributeLeads(context),
      onExportLeads: _openExportLeads,
      onLogout: widget.onLogout,
    );
  }
}
