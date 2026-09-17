import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/leads/domain/entities/lead.dart';
import '../features/leads/domain/repositories/lead_repository.dart';
import '../features/leads/presentation/bloc/lead_dashboard_cubit.dart';
import '../features/leads/presentation/bloc/lead_details_cubit.dart';
import '../features/leads/presentation/bloc/lead_list_cubit.dart';
import '../features/leads/presentation/screens/add_lead_screen.dart';
import '../features/leads/presentation/screens/edit_lead_screen.dart';
import '../features/leads/presentation/screens/lead_dashboard_screen.dart';
import '../features/leads/presentation/screens/lead_details_screen.dart';
import '../features/leads/presentation/screens/lead_import_workflow_screen.dart';
import '../features/leads/presentation/screens/lead_list_screen.dart';
import '../features/leads/presentation/services/lead_import_file_picker.dart';

/// Top-level application widget for the Enterprise CRM.
class CrmApp extends StatelessWidget {
  final LeadRepository leadRepository;
  final LeadImportFilePicker? filePicker;

  const CrmApp({super.key, required this.leadRepository, this.filePicker});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<LeadRepository>.value(
      value: leadRepository,
      child: MaterialApp(
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
        home: CrmHomeScreen(repository: leadRepository, filePicker: filePicker),
      ),
    );
  }
}

/// Root CRM Home screen hosting the Lead Dashboard and coordinating navigation.
class CrmHomeScreen extends StatefulWidget {
  final LeadRepository repository;
  final LeadImportFilePicker? filePicker;

  const CrmHomeScreen({super.key, required this.repository, this.filePicker});

  @override
  State<CrmHomeScreen> createState() => _CrmHomeScreenState();
}

class _CrmHomeScreenState extends State<CrmHomeScreen> {
  late final LeadDashboardCubit _dashboardCubit;

  @override
  void initState() {
    super.initState();
    _dashboardCubit = LeadDashboardCubit(widget.repository)..loadDashboard();
  }

  @override
  void dispose() {
    _dashboardCubit.close();
    super.dispose();
  }

  void _openLeadList(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (listContext) => LeadListScreen(
          repository: widget.repository,
          filePicker: widget.filePicker,
          onViewLead: (lead) => _openLeadDetails(listContext, lead.id),
          onAddLead: () => _openAddLead(listContext),
        ),
      ),
    );
    if (mounted) {
      _dashboardCubit.loadDashboard();
    }
  }

  void _openAddLead(BuildContext context) async {
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
      if (context.mounted) {
        try {
          context.read<LeadListCubit>().refreshLeads();
        } catch (_) {}
      }
      if (mounted) {
        _dashboardCubit.loadDashboard();
      }
    }
  }

  void _openLeadDetails(BuildContext context, String leadId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (detailsContext) => LeadDetailsScreen(
          leadId: leadId,
          repository: widget.repository,
          onEditLead: (lead) => _openEditLead(detailsContext, lead),
        ),
      ),
    );

    if (context.mounted) {
      try {
        context.read<LeadListCubit>().refreshLeads();
      } catch (_) {}
    }
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

  @override
  Widget build(BuildContext context) {
    return LeadDashboardScreen(
      cubit: _dashboardCubit,
      repository: widget.repository,
      onViewLeads: () => _openLeadList(context),
      onAddLead: () => _openAddLead(context),
      onImportLeads: () => _openImportWorkflow(context),
    );
  }
}
