import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/lead.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../bloc/lead_bloc.dart';
import '../bloc/lead_event.dart';
import '../bloc/lead_state.dart';
import 'add_edit_lead_screen.dart';
import 'lead_detail_screen.dart';

class LeadListScreen extends StatefulWidget {
  const LeadListScreen({super.key});

  @override
  State<LeadListScreen> createState() => _LeadListScreenState();
}

class _LeadListScreenState extends State<LeadListScreen> {
  String _searchQuery = '';
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    context.read<LeadBloc>().add(LeadSubscriptionRequested());
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'New':
        return Colors.blue;
      case 'Contacted':
        return Colors.orange;
      case 'Qualified':
        return Colors.purple;
      case 'Won':
        return Colors.green;
      case 'Lost':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leads'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthBloc>().add(AuthSignOutRequested()),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search leads...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _filterChip(null, 'All'),
                ...Lead.statuses.map((s) => _filterChip(s, s)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: BlocConsumer<LeadBloc, LeadState>(
              listener: (context, state) {
                if (state.status == LeadStatus.error && state.errorMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.errorMessage!)),
                  );
                }
              },
              builder: (context, state) {
                if (state.status == LeadStatus.loading && state.leads.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                var leads = state.leads.where((l) {
                  final matchesSearch = _searchQuery.isEmpty ||
                      l.name.toLowerCase().contains(_searchQuery) ||
                      (l.company?.toLowerCase().contains(_searchQuery) ?? false);
                  final matchesStatus = _statusFilter == null || l.status == _statusFilter;
                  return matchesSearch && matchesStatus;
                }).toList();

                if (leads.isEmpty) {
                  return const Center(child: Text('No leads found. Tap + to add one.'));
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    context.read<LeadBloc>().add(LeadSubscriptionRequested());
                  },
                  child: ListView.builder(
                    itemCount: leads.length,
                    itemBuilder: (context, index) {
                      final lead = leads[index];
                      return Dismissible(
                        key: ValueKey(lead.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) {
                          context.read<LeadBloc>().add(LeadDeleted(lead.id));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${lead.name} deleted')),
                          );
                        },
                        child: ListTile(
                          title: Text(lead.name),
                          subtitle: Text(lead.company ?? lead.phone ?? ''),
                          trailing: Chip(
                            label: Text(
                              lead.status,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                            backgroundColor: _statusColor(lead.status),
                            padding: EdgeInsets.zero,
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => LeadDetailScreen(lead: lead),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddEditLeadScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _filterChip(String? status, String label) {
    final selected = _statusFilter == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _statusFilter = status),
      ),
    );
  }
}