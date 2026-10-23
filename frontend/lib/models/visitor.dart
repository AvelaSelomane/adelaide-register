
class Visitor {
  Visitor({
    required this.name,
    required this.contact,
    required this.lastSignIn,
  }) : totalVisits = 1;

  final String name;
  String contact;
  int totalVisits;
  DateTime lastSignIn;
}
