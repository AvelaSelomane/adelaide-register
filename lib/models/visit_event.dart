
class VisitEvent {
  VisitEvent({
    required this.visitorName,
    required this.reason,
    required this.signIn,
  });

  final String visitorName;
  final String reason;
  final DateTime signIn;
  DateTime? signOut;
}
