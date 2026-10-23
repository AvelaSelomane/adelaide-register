import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/visitor.dart';
import '../models/visit_event.dart';
import '../utils/app_constants.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  bool _contactConsentGiven = false;
  final List<Visitor> _visitors = [];
  final List<VisitEvent> _events = [];
  final TextEditingController _adminPasswordController =
      TextEditingController();

  DateTime _now = DateTime.now();
  Timer? _clock;
  String _selectedReason = 'Public Facilities - Study';
  bool _showAdmin = false;
  bool _isAdminAuthenticated = false;
  String _adminRange = 'Last 7 days';

  void _checkAdminPassword() {
    if (_adminPasswordController.text == 'Admin@123') {
      setState(() {
        _isAdminAuthenticated = true;
        _showAdmin = true;
      });

      _adminPasswordController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incorrect admin password. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAdminPasswordDialog() {
    _adminPasswordController.clear();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Admin access'),
        content: TextField(
          controller: _adminPasswordController,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Admin password',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) {
            Navigator.of(dialogContext).pop();
            _checkAdminPassword();
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _adminPasswordController.clear();
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _checkAdminPassword();
            },
            child: const Text('Unlock dashboard'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _nameController.dispose();
    _contactController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String _time(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    return '$hour:${_two(date.minute)} ${date.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _date(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  bool _samePerson(String a, String b) =>
      a.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ') ==
      b.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  Visitor? _findVisitor(String name) {
    for (final visitor in _visitors) {
      if (_samePerson(visitor.name, name)) return visitor;
    }
    return null;
  }

  List<VisitEvent> _activeEventsFor(String name) => _events
      .where(
        (event) =>
            _samePerson(event.visitorName, name) && event.signOut == null,
      )
      .toList();

  int get _activeCount =>
      _events.where((event) => event.signOut == null).length;
  int get _totalVisits => _events.length;

  void _signIn() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final contact = _contactController.text.trim();
    final now = DateTime.now();
    final existing = _findVisitor(name);

    setState(() {
      if (existing != null) {
        existing.contact = contact;
        existing.totalVisits++;
        existing.lastSignIn = now;
        _visitors.remove(existing);
        _visitors.insert(0, existing);
      } else {
        _visitors.insert(
          0,
          Visitor(name: name, contact: contact, lastSignIn: now),
        );
      }

      _events.insert(
        0,
        VisitEvent(visitorName: name, reason: _selectedReason, signIn: now),
      );

      _nameController.clear();
      _contactController.clear();
      _selectedReason = visitReasons.first;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          existing == null
              ? 'Welcome, $name! Your visit has been registered.'
              : 'Welcome back, ${existing.name}! Visit #${existing.totalVisits}.',
        ),
        backgroundColor: const Color(0xFF16866A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _signOut(Visitor visitor) {
    final activeEvents = _activeEventsFor(visitor.name);
    if (activeEvents.isEmpty) return;
    final event = activeEvents.first;

    setState(() => event.signOut = DateTime.now());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${visitor.name} has signed out.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<VisitEvent> get _filteredEvents {
    final now = DateTime.now();
    if (_adminRange == 'Today') {
      return _events
          .where(
            (e) =>
                e.signIn.year == now.year &&
                e.signIn.month == now.month &&
                e.signIn.day == now.day,
          )
          .toList();
    }
    if (_adminRange == 'Last 30 days') {
      final start = now.subtract(const Duration(days: 29));
      return _events
          .where(
            (e) => !e.signIn.isBefore(
              DateTime(start.year, start.month, start.day),
            ),
          )
          .toList();
    }
    final start = now.subtract(const Duration(days: 6));
    return _events
        .where(
          (e) =>
              !e.signIn.isBefore(DateTime(start.year, start.month, start.day)),
        )
        .toList();
  }

  Map<String, int> _reasonCounts(List<VisitEvent> events) => {
    for (final reason in visitReasons)
      reason: events.where((e) => e.reason == reason).length,
  };

  List<MapEntry<String, int>> _dailyCounts(List<VisitEvent> events) {
    final days = <DateTime, int>{};
    final now = DateTime.now();
    final count = _adminRange == 'Today'
        ? 1
        : (_adminRange == 'Last 30 days' ? 30 : 7);
    for (var i = count - 1; i >= 0; i--) {
      final d = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: i));
      days[d] = 0;
    }
    for (final event in events) {
      final d = DateTime(
        event.signIn.year,
        event.signIn.month,
        event.signIn.day,
      );
      if (days.containsKey(d)) days[d] = days[d]! + 1;
    }
    return days.entries
        .map((e) => MapEntry('${e.key.day}/${e.key.month}', e.value))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF6F7FF),
                    Color(0xFFE7EEFC),
                    Color(0xFFF0E9FF),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -100,
            right: -80,
            child: _glow(300, const Color(0x665C78FF)),
          ),
          Positioned(
            bottom: 80,
            left: -130,
            child: _glow(300, const Color(0x554ED9C2)),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1350),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(),
                      const SizedBox(height: 28),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        reverseDuration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          final slide = Tween<Offset>(
                            begin: const Offset(0, 0.025),
                            end: Offset.zero,
                          ).animate(animation);

                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: slide,
                              child: child,
                            ),
                          );
                        },
                        child: KeyedSubtree(
                          key: ValueKey<bool>(_showAdmin),
                          child: _showAdmin
                              ? _adminDashboard()
                              : _visitorPage(),
                        ),
                      ),
                      const SizedBox(height: 25),
                      const Center(
                        child: Text(
                          'CLEARPASS  •  Adelaide Tambo Library',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: muted,
                            fontSize: 11,
                            letterSpacing: 0.7,
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
    );
  }

  Widget _glow(double size, Color color) => ImageFiltered(
    imageFilter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    ),
  );

  Widget _header() {
    return GlassPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final brand = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7187FF), Color(0xFF4355DC)],
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.local_library_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 13),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ClearPass',
                      style: TextStyle(
                        color: ink,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      libraryName.toUpperCase(),
                      style: const TextStyle(
                        color: muted,
                        fontSize: 9,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final toggle = FilledButton.tonalIcon(
            onPressed: () {
              if (_showAdmin && _isAdminAuthenticated) {
                setState(() {
                  _showAdmin = false;
                  _isAdminAuthenticated = false;
                });
                _adminPasswordController.clear();
              } else {
                _showAdminPasswordDialog();
              }
            },
            icon: Icon(
              _showAdmin ? Icons.how_to_reg_rounded : Icons.dashboard_rounded,
            ),
            label: Text(_showAdmin ? 'Visitor register' : 'Admin dashboard'),
          );
          return compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [brand, const SizedBox(height: 14), toggle],
                )
              : Row(
                  children: [
                    brand,
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDDF7EB),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: Color(0xFF16866A), size: 8),
                          SizedBox(width: 6),
                          Text(
                            'Ready',
                            style: TextStyle(
                              color: Color(0xFF16866A),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    toggle,
                  ],
                );
        },
      ),
    );
  }

  Widget _visitorPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _welcome(),
        const SizedBox(height: 22),
        _statistics(_activeCount, _totalVisits),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 850) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _registrationForm()),
                  const SizedBox(width: 22),
                  Expanded(child: _visitorLog()),
                ],
              );
            }
            return Column(
              children: [
                _registrationForm(),
                const SizedBox(height: 22),
                _visitorLog(),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _welcome() => Wrap(
    alignment: WrapAlignment.spaceBetween,
    runSpacing: 15,
    spacing: 15,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome to Adelaide Tambo Library',
            style: TextStyle(
              color: ink,
              fontSize: 27,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Sign in for study, borrowing books or printing.',
            style: TextStyle(color: muted, fontSize: 13),
          ),
        ],
      ),
      GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DATE & LOCAL TIME',
              style: TextStyle(
                color: muted,
                fontSize: 9,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _date(_now),
              style: const TextStyle(
                color: ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              _time(_now),
              style: const TextStyle(
                color: accent,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _statistics(int active, int totalVisits) {
    final items = [
      _StatCard(
        icon: Icons.people_alt_rounded,
        label: 'UNIQUE VISITORS',
        value: '${_visitors.length}',
        color: accent,
      ),
      _StatCard(
        icon: Icons.login_rounded,
        label: 'CURRENTLY INSIDE',
        value: '$active',
        color: const Color(0xFF15966B),
      ),
      _StatCard(
        icon: Icons.repeat_rounded,
        label: 'TOTAL VISITS',
        value: '$totalVisits',
        color: const Color(0xFFB47B27),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 550) {
          return Column(
            children: items
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: item,
                  ),
                )
                .toList(),
          );
        }
        return Row(
          children: items
              .map(
                (item) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: item,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _registrationForm() {
    return GlassPanel(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.how_to_reg_rounded, color: accent, size: 30),
            const SizedBox(height: 12),
            const Text(
              'Visitor sign-in',
              style: TextStyle(
                color: ink,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Enter your details and select your reason for visiting.',
              style: TextStyle(color: muted, fontSize: 12, height: 1.6),
            ),
            const SizedBox(height: 25),
            const _Label('FULL NAME *'),
            const SizedBox(height: 9),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'Enter your full name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Please enter your name'
                  : null,
            ),

            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 14),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: Material(
  color: accent.withValues(alpha: 0.08),
  borderRadius: BorderRadius.circular(16),
  clipBehavior: Clip.antiAlias,
  child: Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: accent.withValues(alpha: 0.22)),
    ),
                    child: CheckboxListTile(
                      value: _contactConsentGiven,
                      onChanged: (value) {
                        setState(() {
                          _contactConsentGiven = value ?? false;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: accent,
                      title: const Text(
                        'Your number, your privacy',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: const Text(
                        'I agree to provide my contact number so the '
                        'library can identify my visitor record and '
                        'update me with new information if needed.',
                        style: TextStyle(fontSize: 12, height: 1.4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ),

            const SizedBox(height: 19),
            const _Label('CONTACT NUMBER *'),
            const SizedBox(height: 9),
            TextFormField(
              controller: _contactController,
              enabled: _contactConsentGiven,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: 'Enter your contact number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (value) {
                final phone = value?.trim() ?? '';
                if (phone.isEmpty) return 'Please enter your number';
                if (phone.replaceAll(RegExp(r'\D'), '').length < 7) {
                  return 'Please enter a valid contact number';
                }
                return null;
              },
              onFieldSubmitted: (_) => _signIn(),
            ),
            const SizedBox(height: 19),
            const _Label('USE OF FACILITIES *'),
            const SizedBox(height: 9),
            DropdownButtonFormField<String>(
              initialValue: _selectedReason,
              isExpanded: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.menu_book_rounded),
              ),
              items: visitReasons
                  .map(
                    (reason) => DropdownMenuItem<String>(
                      value: reason,
                      child: Text(reason),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedReason = value);
                }
              },
            ),

            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF0FF).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD9E2FF)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.history_rounded, color: accent, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Returning visitor? Use the same name as before. Each sign-in is recorded as a separate visit.',
                      style: TextStyle(
                        color: Color(0xFF53617B),
                        fontSize: 11,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: _SmoothButton(
                onPressed: _signIn,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.login_rounded),
                    SizedBox(width: 9),
                    Flexible(
                      child: Text(
                        'Sign in / Return visit',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            const Center(
              child: Text(
                'Simple. Secure. Paperless.',
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _visitorLog() {
    return GlassPanel(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Visitor register',
                      style: TextStyle(
                        color: ink,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'One summary record per person',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.manage_search_rounded, color: accent, size: 26),
            ],
          ),
          const SizedBox(height: 22),
          if (_visitors.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.assignment_ind_outlined,
                      size: 52,
                      color: Color(0xFFA4B0C7),
                    ),
                    SizedBox(height: 14),
                    Text(
                      'No visitors registered yet',
                      style: TextStyle(color: ink, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 7),
                    Text(
                      'Registered visitors will appear here.',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._visitors.map(_visitorCard),
        ],
      ),
    );
  }

  Widget _visitorCard(Visitor visitor) {
    final activeEvents = _activeEventsFor(visitor.name);
    final isInside = activeEvents.isNotEmpty;
    final latestEvent = _events.firstWhere(
      (e) => _samePerson(e.visitorName, visitor.name),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE1E7FF), Color(0xFFF0E9FF)],
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  visitor.name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: accent,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visitor.name,
                      style: const TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      visitor.contact,
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Pill(
                          text:
                              '${visitor.totalVisits} ${visitor.totalVisits == 1 ? 'visit' : 'visits'}',
                          color: const Color(0xFFE9EDFF),
                          textColor: accent,
                        ),
                        _Pill(
                          text: latestEvent.reason,
                          color: const Color(0xFFF0E9FF),
                          textColor: const Color(0xFF7252B8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _Pill(
                text: isInside ? 'Inside' : 'Signed out',
                color: isInside
                    ? const Color(0xFFDDF7EB)
                    : const Color(0xFFFFEED8),
                textColor: isInside
                    ? const Color(0xFF16866A)
                    : const Color(0xFF9B691C),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 13),
            child: Divider(height: 1, color: Color(0xFFE3E8F1)),
          ),
          _detail(
            Icons.login_rounded,
            'Last sign-in',
            '${_date(visitor.lastSignIn)} • ${_time(visitor.lastSignIn)}',
          ),
          const SizedBox(height: 9),
          if (isInside)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _signOut(visitor),
                icon: const Icon(Icons.logout_rounded, size: 17),
                label: const Text('Sign out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF596782),
                  side: const BorderSide(color: Color(0xFFD8E0EE)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            )
          else if (latestEvent.signOut != null)
            _detail(
              Icons.logout_rounded,
              'Last sign-out',
              '${_date(latestEvent.signOut!)} • ${_time(latestEvent.signOut!)}',
            ),
        ],
      ),
    );
  }

  Widget _adminDashboard() {
    final events = _filteredEvents;
    final reasons = _reasonCounts(events);
    final daily = _dailyCounts(events);
    final maxDaily = daily.fold<int>(
      1,
      (max, e) => e.value > max ? e.value : max,
    );
    final study = reasons['Study'] ?? 0;
    final books = reasons['Borrow a book'] ?? 0;
    final printing = reasons['Printing'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Admin dashboard',
          style: TextStyle(
            color: ink,
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Attendance and library usage overview',
          style: TextStyle(color: muted, fontSize: 13),
        ),
        const SizedBox(height: 18),
        GlassPanel(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              const Text(
                'REPORTING PERIOD',
                style: TextStyle(
                  color: muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              DropdownButton<String>(
                value: _adminRange,
                items: const [
                  DropdownMenuItem(value: 'Today', child: Text('Today')),
                  DropdownMenuItem(
                    value: 'Last 7 days',
                    child: Text('Last 7 days'),
                  ),
                  DropdownMenuItem(
                    value: 'Last 30 days',
                    child: Text('Last 30 days'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _adminRange = value);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              _StatCard(
                icon: Icons.groups_rounded,
                label: 'VISITS IN PERIOD',
                value: '${events.length}',
                color: accent,
              ),
              _StatCard(
                icon: Icons.people_alt_rounded,
                label: 'UNIQUE VISITORS',
                value: '${_visitors.length}',
                color: const Color(0xFF15966B),
              ),
              _StatCard(
                icon: Icons.login_rounded,
                label: 'CURRENTLY INSIDE',
                value: '$_activeCount',
                color: const Color(0xFFB47B27),
              ),
              _StatCard(
                icon: Icons.menu_book_rounded,
                label: 'STUDY VISITS',
                value: '$study',
                color: const Color(0xFF3985D6),
              ),
            ];
            final columns = constraints.maxWidth > 900
                ? 4
                : (constraints.maxWidth > 560 ? 2 : 1);
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: cards
                  .map(
                    (card) => SizedBox(
                      width:
                          (constraints.maxWidth - (columns - 1) * 12) / columns,
                      child: card,
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final reasonChart = _chartPanel(
              title: 'Visits by reason',
              subtitle: 'What people came to the library to do',
              child: Column(
                children: [
                  _BarRow(
                    label: 'Study',
                    count: study,
                    total: events.length,
                    color: const Color(0xFF3985D6),
                  ),
                  const SizedBox(height: 20),
                  _BarRow(
                    label: 'Borrow a book',
                    count: books,
                    total: events.length,
                    color: const Color(0xFF259B7A),
                  ),
                  const SizedBox(height: 20),
                  _BarRow(
                    label: 'Printing',
                    count: printing,
                    total: events.length,
                    color: const Color(0xFF9169CE),
                  ),
                ],
              ),
            );
            final attendanceChart = _chartPanel(
              title: 'Attendance trend',
              subtitle: 'Recorded visits per day',
              child: SizedBox(
                height: 230,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: daily.map((entry) {
                    final barHeight = entry.value == 0
                        ? 4.0
                        : 145.0 * entry.value / maxDaily;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '${entry.value}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: muted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              height: barHeight,
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.8),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(7),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              entry.key,
                              style: const TextStyle(fontSize: 9, color: muted),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            );
            if (constraints.maxWidth >= 800) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: reasonChart),
                  const SizedBox(width: 18),
                  Expanded(child: attendanceChart),
                ],
              );
            }
            return Column(
              children: [
                reasonChart,
                const SizedBox(height: 18),
                attendanceChart,
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        _recentVisitsPanel(events),
        const SizedBox(height: 12),
        const Text(
          'Demo note: data is held in memory and will be cleared when the app restarts. Add persistent storage and admin authentication before using this with real library visitors.',
          style: TextStyle(color: muted, fontSize: 11, height: 1.5),
        ),
      ],
    );
  }

  Widget _chartPanel({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return GlassPanel(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(subtitle, style: const TextStyle(color: muted, fontSize: 11)),
          const SizedBox(height: 25),
          child,
        ],
      ),
    );
  }

  Widget _recentVisitsPanel(List<VisitEvent> events) {
    final recent = events.take(12).toList();
    return GlassPanel(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent visits',
            style: TextStyle(
              color: ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Latest entries within the selected period',
            style: TextStyle(color: muted, fontSize: 11),
          ),
          const SizedBox(height: 15),
          if (recent.isEmpty)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Center(
                child: Text(
                  'No visits recorded for this period yet.',
                  style: TextStyle(color: muted),
                ),
              ),
            )
          else
            ...recent.map(
              (event) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9EDFF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _reasonIcon(event.reason),
                        color: accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.visitorName,
                            style: const TextStyle(
                              color: ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${event.reason} • ${_date(event.signIn)}',
                            style: const TextStyle(color: muted, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _time(event.signIn),
                      style: const TextStyle(
                        color: muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _reasonIcon(String reason) {
    switch (reason) {
      case 'Study':
        return Icons.menu_book_rounded;
      case 'Borrow a book':
        return Icons.bookmark_added_rounded;
      default:
        return Icons.print_rounded;
    }
  }

  Widget _detail(IconData icon, String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 16, color: muted),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          '$label: $value',
          style: const TextStyle(color: muted, fontSize: 11, height: 1.5),
        ),
      ),
    ],
  );
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });
  final String label;
  final int count;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : count / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '$count',
              style: const TextStyle(
                color: ink,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(ratio * 100).round()}%',
              style: const TextStyle(color: muted, fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 11,
            color: const Color(0xFFE5EAF5),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: ratio,
              child: Container(color: color),
            ),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.color,
    required this.textColor,
  });
  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: textColor,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Color(0xFF475773),
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 1,
    ),
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.all(18),
    child: Row(
      children: [
        Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 23),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  color: ink,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.95),
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.06),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: child,
      ),
    ),
  );
}

class _SmoothButton extends StatefulWidget {
  const _SmoothButton({
    required this.child,
    required this.onPressed,

    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
  });

  final Widget child;
  final VoidCallback? onPressed;
  final EdgeInsetsGeometry padding;

  @override
  State<_SmoothButton> createState() => _SmoothButtonState();
}

class _SmoothButtonState extends State<_SmoothButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: Listener(
        onPointerDown: (_) {
          if (enabled) setState(() => _pressed = true);
        },
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : (_hovered ? 1.015 : 1.0),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.16),
                        blurRadius: 16,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : const [],
            ),
            child: FilledButton(
              onPressed: widget.onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: widget.padding,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
