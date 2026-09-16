import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/lead.dart';

class LeadRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Lead>> fetchLeads() async {
    final data = await _client
        .from('leads')
        .select()
        .order('updated_at', ascending: false);
    return (data as List).map((e) => Lead.fromMap(e)).toList();
  }

  Future<Lead> addLead(Lead lead) async {
    final data = await _client
        .from('leads')
        .insert(lead.toInsertMap())
        .select()
        .single();
    return Lead.fromMap(data);
  }

  Future<Lead> updateLead(String id, Map<String, dynamic> changes) async {
    final data = await _client
        .from('leads')
        .update(changes)
        .eq('id', id)
        .select()
        .single();
    return Lead.fromMap(data);
  }

  Future<void> deleteLead(String id) async {
    await _client.from('leads').delete().eq('id', id);
  }

  // Real-time stream of all leads
  Stream<List<Lead>> watchLeads() {
    return _client
        .from('leads')
        .stream(primaryKey: ['id'])
        .order('updated_at', ascending: false)
        .map((rows) => rows.map((e) => Lead.fromMap(e)).toList());
  }
}