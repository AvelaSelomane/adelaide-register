import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'admin_login_screen.dart';

// Adelaide Tambo visitor registration and authenticated supervisor reporting.

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _AttendanceRecord {
  _AttendanceRecord({
    required this.name,
    required this.visitorCount,
    required this.activities,
    required this.recordedAt,
  });

  final String name;
  final int visitorCount;
  final Map<String, int> activities;
  final DateTime recordedAt;
}

class _RegisterPageState extends State<RegisterPage> {
  static const Color ink = Color(0xFF1B2B47);
  static const Color muted = Color(0xFF7786A2);
  static const Color accent = Color(0xFF526DFF);

  static const Map<String, List<String>> activityGroups = {
    'Public Facilities': ['Study', 'Reading', 'Research'],
    'ICT Facilities': ['Internet', 'Typing'],
    'Library Services': [
      'Book Borrowing',
      'Booking',
      'Other Approved Services',
      'Enquiries',
      'Programmes',
    ],
  };

  static const Map<String, int> activityIds = {
    'Study': 1,
    'Reading': 2,
    'Research': 3,
    'Internet': 4,
    'Typing': 6,
    'Book Borrowing': 7,
    'Booking': 8,
    'Other Approved Services': 9,
    'Enquiries': 10,
    'Programmes': 11,
  };

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _visitorCountController = TextEditingController(text: '1');

  final List<_AttendanceRecord> _records = [];

  final Map<String, int> _activityCounts = {
    for (final group in activityGroups.values)
      for (final activity in group) activity: 0,
  };

  bool _showAdmin = false;
  String? _adminToken;
  String _statisticsPeriod = 'daily';
  Map<String, dynamic>? _adminStatistics;
  bool _statisticsLoading = false;
  bool _pdfDownloading = false;
  String? _statisticsError;

  // Daily visitor register
  List<dynamic> _dailyRegistrations = [];
  bool _dailyRegistrationsLoading = false;
  String? _dailyRegistrationsError;
  bool _isSaving = false;
  DateTime _now = DateTime.now();
  Timer? _clock;

  @override
  void initState() {
    super.initState();

    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _nameController.dispose();
    _visitorCountController.dispose();
    super.dispose();
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  int get _todayCount {
    return _records
        .where((record) => _sameDay(record.recordedAt, _now))
        .fold<int>(0, (sum, record) => sum + record.visitorCount);
  }

  int get _allCount {
    return _records.fold<int>(0, (sum, record) => sum + record.visitorCount);
  }

  String _dateTime(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/${date.year} $hour:$minute';
  }

  Future<void> _register() async {
    if (_isSaving || !_formKey.currentState!.validate()) {
      return;
    }

    final count = int.parse(_visitorCountController.text.trim());

    final selected = Map<String, int>.fromEntries(
      _activityCounts.entries.where((entry) => entry.value > 0),
    );

    final allocated = selected.values.fold<int>(0, (sum, value) => sum + value);

    if (allocated != count) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Activity counts must total $count visitors. '
            'Currently allocated: $allocated.',
          ),
          backgroundColor: Colors.deepOrange,
        ),
      );
      return;
    }

    final activitiesForApi = <int, int>{
      for (final entry in selected.entries)
        activityIds[entry.key]!: entry.value,
    };

    setState(() => _isSaving = true);

    try {
      final response = await ApiService.registerAttendance(
        initialsSurname: _nameController.text.trim(),
        visitorCount: count,
        activities: activitiesForApi,
      );

      if (!mounted) return;

      final registration = response['registration'] as Map<String, dynamic>;
      final recordedAt = DateTime.parse(registration['registeredAt'] as String)
          .toLocal();

      setState(() {
        _records.insert(
          0,
          _AttendanceRecord(
            name: _nameController.text.trim(),
            visitorCount: count,
            activities: selected,
            recordedAt: recordedAt,
          ),
        );

        _nameController.clear();
        _visitorCountController.text = '1';

        for (final key in _activityCounts.keys) {
          _activityCounts[key] = 0;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance saved to PostgreSQL successfully.'),
          backgroundColor: Color(0xFF16866A),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save attendance: $error'),
          backgroundColor: Colors.deepOrange,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _loadAdminStatistics() async {
    final token = _adminToken;
    if (token == null) return;
    final period = _statisticsPeriod;

    setState(() {
      _statisticsLoading = true;
      _statisticsError = null;
    });

    try {
      final result = await ApiService.getAdminStatistics(
        token: token,
        period: period,
        date: DateTime.now(),
      );
      if (!mounted || _adminToken != token || _statisticsPeriod != period) {
        return;
      }
      setState(() => _adminStatistics = result);
      if (period == 'daily') {
        await _loadDailyRegistrations();
      }
    } catch (error) {
      if (!mounted || _adminToken != token || _statisticsPeriod != period) {
        return;
      }
      setState(() {
        _adminStatistics = null;
        _statisticsError =
            'Could not load statistics. Check the backend connection and sign in again if your session expired.';
      });
    } finally {
      if (mounted && _adminToken == token && _statisticsPeriod == period) {
        setState(() => _statisticsLoading = false);
      }
    }
  }

  Future<void> _loadDailyRegistrations() async {
  final token = _adminToken;

  if (token == null || _statisticsPeriod != 'daily') {
    return;
  }

  setState(() {
    _dailyRegistrationsLoading = true;
    _dailyRegistrationsError = null;
  });

  try {
    final response = await ApiService.getDailyRegistrations(
      token: token,
      date: DateTime.now(),
    );

    if (!mounted ||
        _adminToken != token ||
        _statisticsPeriod != 'daily') {
      return;
    }

    final registrations = response['registrations'];

    if (registrations is! List) {
      throw Exception('Invalid daily registrations response');
    }

    setState(() {
      _dailyRegistrations = registrations;
    });
  } catch (error) {
    if (!mounted ||
        _adminToken != token ||
        _statisticsPeriod != 'daily') {
      return;
    }

    setState(() {
      _dailyRegistrations = [];
      _dailyRegistrationsError =
          'Unable to load daily registrations: $error';
    });
  } finally {
    if (mounted && _adminToken == token) {
      setState(() {
        _dailyRegistrationsLoading = false;
      });
    }
  }
}

Future<void> _downloadPdfReport() async {
  final token = _adminToken;
  final period = _statisticsPeriod;

  if (token == null || (period != 'monthly' && period != 'yearly')) {
    return;
  }

  setState(() => _pdfDownloading = true);

  try {
    await ApiService.downloadAdminPdfReport(
      token: token,
      period: period,
      date: DateTime.now(),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PDF report downloaded successfully.'),
      ),
    );
  } catch (error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('PDF download failed: $error'),
        backgroundColor: Colors.deepOrange,
      ),
    );
  } finally {
    if (mounted) {
      setState(() => _pdfDownloading = false);
    }
  }
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
                      const SizedBox(height: 26),
                      if (_showAdmin)
                        _adminToken == null
                            ? AdminLoginScreen(
                                onLoginSuccess: (token) {
                                  setState(() {
                                    _adminToken = token;
                                    _statisticsPeriod = 'daily';
                                    _adminStatistics = null;
                                    _dailyRegistrations = [];
                                    _dailyRegistrationsError = null;
                                  });
                                  _loadAdminStatistics();
                                },
                              )
                            : _adminView()
                      else
                        _visitorView(),
                      
                      const Center(
                        child: Text(
                          'Adelaide Tambo Public Library  •  Demonstration',
                          style: TextStyle(
                            fontSize: 11,
                            color: muted,
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

  
Widget _header() {
  return _panel(
    Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Image.asset(
              'assets/images/adelaide_tambo_logo.png',
              height: 48,
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
            ),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.tonalIcon(
          onPressed: () {
            setState(() {
              _showAdmin = !_showAdmin;

              if (!_showAdmin) {
                _adminToken = null;
                _adminStatistics = null;
                _statisticsError = null;
                _statisticsLoading = false;
                _dailyRegistrations = [];
                _dailyRegistrationsError = null;
                _dailyRegistrationsLoading = false;
              }
            });
          },
          icon: Icon(
            _showAdmin
                ? Icons.assignment_rounded
                : Icons.dashboard_rounded,
          ),
          label: Text(
            _showAdmin
                ? 'Visitor registration'
                : 'Supervisor login',
          ),
        ),
      ],
    ),
  );
}


  Widget _visitorView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 18,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome to Adelaide Tambo Library',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Record your attendance and use '
                  'of library facilities.',
                  style: TextStyle(fontSize: 13, color: muted),
                ),
              ],
            ),
            _panel(
              Text(
                'DATE & LOCAL TIME\n${_dateTime(_now)}',
                style: const TextStyle(fontWeight: FontWeight.w700, color: ink),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            _stat(
              "TODAY'S ATTENDANCE",
              '$_todayCount',
              Icons.people_alt_rounded,
            ),
            _stat(
              'REGISTRATIONS',
              '${_records.length}',
              Icons.assignment_turned_in_rounded,
            ),
            _stat('TOTAL ATTENDANCE', '$_allCount', Icons.bar_chart_rounded),
          ],
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 850) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _registrationForm()),
                  const SizedBox(width: 22),
                  Expanded(child: _visitorPrivacyPanel()),
                ],
              );
            }

            return Column(
              children: [
                _registrationForm(),
                const SizedBox(height: 22),
                _visitorPrivacyPanel(),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _registrationForm() {
    return _panel(
      Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.how_to_reg_rounded, color: accent, size: 30),
            const SizedBox(height: 12),
            const Text(
              'Visitor attendance',
              style: TextStyle(
                color: ink,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Complete the register for yourself '
              'or your group.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            const SizedBox(height: 22),
            _label('INITIALS AND SURNAME *'),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'e.g. T. Lebia',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter initials and surname';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            _label('NUMBER OF VISITORS *'),
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Remove one visitor',
                  onPressed: () {
                    final current =
                        int.tryParse(_visitorCountController.text) ?? 1;
                    if (current > 1) {
                      setState(() {
                        _visitorCountController.text = (current - 1).toString();
                      });
                    }
                  },
                  icon: const Icon(Icons.remove),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _visitorCountController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(hintText: 'e.g. 5'),
                    validator: (value) {
                      final number = int.tryParse(value?.trim() ?? '');
                      if (number == null || number < 1) {
                        return 'Enter a whole number of at least 1';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filled(
                  tooltip: 'Add one visitor',
                  onPressed: () {
                    final current =
                        int.tryParse(_visitorCountController.text) ?? 0;
                    setState(() {
                      _visitorCountController.text = (current + 1).toString();
                    });
                  },
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const SizedBox(height: 20),
            const Text(
              'ACTIVITY COUNTS',
              style: TextStyle(fontWeight: FontWeight.w800, color: ink),
            ),
            const SizedBox(height: 6),
            const Text(
              'Allocate the number of visitors '
              'to each activity. The total must '
              'match your group size.',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            const SizedBox(height: 12),
            for (final group in activityGroups.entries) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  group.key,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
              ),
              for (final activity in group.value)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          activity,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Remove one $activity visitor',
                        onPressed: _activityCounts[activity]! > 0
                            ? () {
                                setState(() {
                                  _activityCounts[activity] =
                                      _activityCounts[activity]! - 1;
                                });
                              }
                            : null,
                        icon: const Icon(Icons.remove),
                      ),
                      SizedBox(
                        width: 36,
                        child: Text(
                          '${_activityCounts[activity]}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: ink,
                          ),
                        ),
                      ),
                      IconButton.filled(
                        tooltip: 'Add one $activity visitor',
                        onPressed: () {
                          setState(() {
                            _activityCounts[activity] =
                                _activityCounts[activity]! + 1;
                          });
                        },
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _register,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.assignment_turned_in_rounded),
                label: Text(
                  _isSaving ? 'Saving attendance...' : 'Register Attendance',
                ),
                style: FilledButton.styleFrom(backgroundColor: accent),
              ),
            ),
            const SizedBox(height: 10),
            const Center(
              child: Text(
                'Simple. Secure. Paperless.',
                style: TextStyle(fontSize: 11, color: muted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _visitorPrivacyPanel() {
    return _panel(
      const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, color: accent, size: 32),
          SizedBox(height: 12),
          Text(
            'Your privacy matters',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: ink),
          ),
          SizedBox(height: 10),
          Text(
            'Your attendance is saved securely to the library database. '
            'Visitor names and individual attendance records are not shown '
            'on this shared registration screen.',
            style: TextStyle(fontSize: 13, color: muted, height: 1.5),
          ),
          SizedBox(height: 12),
          Text(
            'Supervisors can view authorized reports after signing in.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ],
      ),
    );
  }

  Widget _adminView() {
    final statistics = _adminStatistics;
    final activities = statistics?['activities'];
    final activityList = activities is List ? activities : <dynamic>[];
    final counts = <String, int>{
      for (final group in activityGroups.values)
        for (final activity in group) activity: 0,
    };

    for (final item in activityList) {
      if (item is Map) {
        final name = item['activityName'];
        final value = item['visitorCount'];
        if (name is String && counts.containsKey(name) && value is num) {
          counts[name] = value.toInt();
        }
      }
    }

    final periodLabel = switch (_statisticsPeriod) {
      'monthly' => 'This month',
      'yearly' => 'This year',
      _ => 'Today',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Supervisor dashboard',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: ink),
        ),
        const SizedBox(height: 8),
        const Text(
          'Live attendance statistics from the library database.',
          style: TextStyle(fontSize: 12, color: muted),
        ),
        const SizedBox(height: 20),
        _panel(
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Reporting period:',
                  style: TextStyle(fontWeight: FontWeight.w700, color: ink)),
              DropdownButton<String>(
                value: _statisticsPeriod,
                items: const [
                  DropdownMenuItem(value: 'daily', child: Text('Daily')),
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                ],
                onChanged: _statisticsLoading
                    ? null
                    : (period) {
                        if (period == null) return;
                        setState(() {
                          _statisticsPeriod = period;
                          _adminStatistics = null;
                          _statisticsError = null;
                          _dailyRegistrations = [];
                          _dailyRegistrationsError = null;
                        });
                        _loadAdminStatistics();
                      },
              ),
              FilledButton.tonalIcon(
                onPressed: _statisticsLoading ? null : _loadAdminStatistics,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh'),
              ),

if (_statisticsPeriod == 'monthly' || _statisticsPeriod == 'yearly')
  FilledButton.icon(
    onPressed: (_pdfDownloading || _statisticsLoading)
        ? null
        : _downloadPdfReport,
    icon: _pdfDownloading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : const Icon(Icons.picture_as_pdf_rounded),
    label: Text(
      _pdfDownloading
          ? 'Downloading...'
          : _statisticsPeriod == 'monthly'
              ? 'Download Monthly PDF'
              : 'Download Yearly PDF',
    ),
  ),

            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_statisticsLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_statisticsError != null)
          _panel(Text(_statisticsError!,
              style: const TextStyle(color: Colors.deepOrange))),
        if (statistics != null) ...[
          Text(
            '$periodLabel • ${statistics['startDate'] ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.w700, color: muted),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _stat('TOTAL VISITORS', '${statistics['totalVisitors'] ?? 0}',
                  Icons.people_alt_rounded),
              _stat('REGISTRATIONS', '${statistics['totalRegistrations'] ?? 0}',
                  Icons.assignment_rounded),
            ],
          ),
          const SizedBox(height: 20),
          _panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Activity totals',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ink)),
                const SizedBox(height: 14),
                for (final group in activityGroups.entries) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(group.key,
                        style: const TextStyle(fontWeight: FontWeight.w800, color: ink)),
                  ),
                  for (final activity in group.value)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Expanded(child: Text(activity)),
                          Text('${counts[activity] ?? 0}'),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
        if (_statisticsPeriod == 'daily' && _adminToken != null) ...[
          const SizedBox(height: 20),
          _dailyVisitorRegister(),
        ],
      ],
    );
  }

  Widget _dailyVisitorRegister() {
  return _panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Daily Visitor Register',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: ink,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Individual visitor registrations recorded today.',
          style: TextStyle(fontSize: 12, color: muted),
        ),
        const SizedBox(height: 16),

        if (_dailyRegistrationsLoading)
          const Center(child: CircularProgressIndicator())
        else if (_dailyRegistrationsError != null)
          Text(
            _dailyRegistrationsError!,
            style: const TextStyle(color: Colors.deepOrange),
          )
        else if (_dailyRegistrations.isEmpty)
          const Text(
            'No visitor registrations found for today.',
            style: TextStyle(color: muted),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Time')),
                DataColumn(label: Text('Initials & Surname')),
                DataColumn(label: Text('Visitors')),
                DataColumn(label: Text('Activities')),
              ],
              rows: _dailyRegistrations.map((item) {
                final registration = item is Map
                    ? Map<String, dynamic>.from(item)
                    : <String, dynamic>{};

                final rawDate = registration['registeredAt'];
                final registeredAt = DateTime.tryParse(
                  rawDate?.toString() ?? '',
                )?.toLocal();

                final time = registeredAt == null
                    ? '-'
                    : '${registeredAt.hour.toString().padLeft(2, '0')}:'
                      '${registeredAt.minute.toString().padLeft(2, '0')}';

                final rawActivities = registration['activities'];
                final activities = rawActivities is List
                    ? rawActivities
                    : <dynamic>[];

                final activitySummary = activities.map((activity) {
                  final data = activity is Map
                      ? Map<String, dynamic>.from(activity)
                      : <String, dynamic>{};

                  return '${data['activityName']}: '
                      '${data['visitorCount']}';
                }).join(', ');

                return DataRow(
                  cells: [
                    DataCell(Text(time)),
                    DataCell(Text(
                      registration['initialsSurname']?.toString() ?? '-',
                    )),
                    DataCell(Text(
                      registration['visitorCount']?.toString() ?? '0',
                    )),
                    DataCell(
                      SizedBox(
                        width: 320,
                        child: Text(
                          activitySummary,
                          softWrap: true,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    ),
  );
}


  Widget _stat(String label, String value, IconData icon) {
    return SizedBox(
      width: 260,
      child: _panel(
        Row(
          children: [
            Icon(icon, color: accent, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF475773),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _panel(Widget child) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white),
          ),
          child: child,
        ),
      ),
    );
  }
}