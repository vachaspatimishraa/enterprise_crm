import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/domain/repositories/user_lead_link_repository.dart';
import '../features/auth/presentation/bloc/auth_cubit.dart';
import '../features/auth/presentation/bloc/auth_state.dart';
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
import '../features/leads/presentation/services/lead_import_file_picker.dart';
import '../features/leads/presentation/widgets/lead_export_dialog.dart';

/// Top-level application widget for the Enterprise CRM.
class CrmApp extends StatefulWidget {
  final LeadRepository leadRepository;
  final LeadImportFilePicker? filePicker;
  final LeadExportFileSaver? exportFileSaver;
  final AuthRepository? authRepository;
  final UserManagementRepository? userManagementRepository;
  final UserLeadLinkRepository? userLeadLinkRepository;

  const CrmApp({
    super.key,
    required this.leadRepository,
    this.filePicker,
    this.exportFileSaver,
    this.authRepository,
    this.userManagementRepository,
    this.userLeadLinkRepository,
  }) : assert(
         authRepository == null || userManagementRepository != null,
         'userManagementRepository must be provided when authRepository is enabled',
       ),
       assert(
         authRepository == null || userLeadLinkRepository != null,
         'userLeadLinkRepository must be provided when authRepository is enabled',
       );

  @override
  State<CrmApp> createState() => _CrmAppState();
}

class _CrmAppState extends State<CrmApp> {
  AuthCubit? _authCubit;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    if (widget.authRepository != null) {
      _authCubit = AuthCubit(widget.authRepository!);
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
    _authCubit?.close();
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
            if (state is AuthUnauthenticated) {
              _navigatorKey.currentState?.popUntil((route) => route.isFirst);
            }
          },
          builder: (context, state) {
            switch (state) {
              case AuthAuthenticated(:final user):
                if (user.isAdmin) {
                  return AdminDashboardScreen(
                    user: user,
                    onLogout: () => _authCubit!.logout(),
                    userManagementRepository: widget.userManagementRepository,
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
                    onLogout: () => _authCubit!.logout(),
                    userLeadLinkRepository: widget.userLeadLinkRepository!,
                    leadRepository: widget.leadRepository,
                  );
                }
              case AuthUnauthenticated():
              case AuthAuthenticating():
              case AuthFailure():
                return const LoginScreen();
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

    Widget app = MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Enterprise CRM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: content,
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
        } catch (_) {}
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
