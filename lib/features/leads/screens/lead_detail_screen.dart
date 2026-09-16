import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/models/lead.dart';
import '../bloc/lead_bloc.dart';
import '../bloc/lead_event.dart';

class LeadDetailScreen extends StatelessWidget {
  final Lead lead;
  const LeadDetailScreen({super.key, required this.lead});

  Future<void> _launch(String scheme, String value) async {
    final uri = Uri.parse('$scheme:$value');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(lead.name)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            if (lead.company != null) _infoRow(Icons.business, lead.company!),
            if (lead.phone != null)
              _infoRow(Icons.phone, lead.phone!, onTap: () => _launch('tel', lead.phone!)),
            if (lead.email != null)
              _infoRow(Icons.email, lead.email!, onTap: () => _launch('mailto', lead.email!)),
            if (lead.notes != null) _infoRow(Icons.notes, lead.notes!),
            const SizedBox(height: 20),
            const Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: Lead.statuses.map((s) {
                return ChoiceChip(
                  label: Text(s),
                  selected: lead.status == s,
                  onSelected: (_) {
                    context.read<LeadBloc>().add(LeadStatusChanged(lead.id, s));
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon),
      title: Text(text),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}