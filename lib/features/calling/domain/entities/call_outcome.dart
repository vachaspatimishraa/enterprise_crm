/// The 8 business-defined call outcomes for Enterprise CRM.
///
/// CRITICAL: These outcomes remain completely separate from [LeadStatus].
/// Recording a call outcome must never mutate or infer [LeadStatus].
enum CallOutcome {
  followUp,
  notConnected,
  visitScheduled,
  irrelevant,
  notInterested,
  leadClosed,
  salesDone,
  dispatched,
}
