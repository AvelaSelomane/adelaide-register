
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:5000/api';

  // Register visitor attendance in PostgreSQL.
  static Future<Map<String, dynamic>> registerAttendance({
    required String initialsSurname,
    required int visitorCount,
    required Map<int, int> activities,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/registrations'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'initialsSurname': initialsSurname,
            'visitorCount': visitorCount,
            'activities': activities.entries
                .map(
                  (entry) => {
                    'activityId': entry.key,
                    'visitorCount': entry.value,
                  },
                )
                .toList(),
          }),
        )
        .timeout(const Duration(seconds: 15));

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected server response');
    }

    if (response.statusCode != 201 || decoded['success'] != true) {
      throw Exception(
        decoded['message'] ?? 'Unable to save attendance',
      );
    }

    return decoded;
  }

  // Retrieve available library activities.
  static Future<List<dynamic>> getActivities() async {
    final response = await http
        .get(Uri.parse('$baseUrl/activities'))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Unable to load activities');
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic> ||
        decoded['success'] != true ||
        decoded['activities'] is! List) {
      throw Exception('Unexpected activities response');
    }

    return decoded['activities'] as List<dynamic>;
  }

  // Authenticate the library supervisor.
  static Future<Map<String, dynamic>> adminLogin({
    required String username,
    required String password,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/admin/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': username,
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 15));

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected server response');
    }

    if (response.statusCode != 200 || decoded['success'] != true) {
      throw Exception(
        decoded['message'] ?? 'Administrator login failed',
      );
    }

    return decoded;
  }

  // Retrieve authenticated daily, monthly, or yearly statistics.

static Future<Map<String, dynamic>> getAdminStatistics({
  required String token,
  required String period,
  required DateTime date,
}) async {
  final String formattedDate =
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  final Map<String, String> queryParameters;

  switch (period) {
    case 'daily':
      queryParameters = {
        'period': 'daily',
        'date': formattedDate,
      };
      break;

    case 'monthly':
      queryParameters = {
        'period': 'monthly',
        'year': date.year.toString(),
        'month': date.month.toString(),
      };
      break;

    case 'yearly':
      queryParameters = {
        'period': 'yearly',
        'year': date.year.toString(),
      };
      break;

    default:
      throw ArgumentError(
        'Period must be daily, monthly, or yearly',
      );
  }

  final uri = Uri.parse('$baseUrl/admin/statistics').replace(
    queryParameters: queryParameters,
  );

  final response = await http
      .get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      )
      .timeout(const Duration(seconds: 15));

  final decoded = jsonDecode(response.body);

  if (decoded is! Map<String, dynamic>) {
    throw Exception('Unexpected statistics response');
  }

  if (response.statusCode != 200 || decoded['success'] != true) {
    throw Exception(
      decoded['message'] ?? 'Unable to load attendance statistics',
    );
  }

  return decoded;
}


static Future<void> downloadAdminPdfReport({
  required String token,
  required String period,
  required DateTime date,
}) async {
  if (period != 'monthly' && period != 'yearly') {
    throw ArgumentError('PDF reports must be monthly or yearly');
  }

  final queryParameters = <String, String>{
    'year': date.year.toString(),
    if (period == 'monthly')
      'month': date.month.toString(),
  };

  final uri = Uri.parse(
    '$baseUrl/admin/reports/$period',
  ).replace(queryParameters: queryParameters);

  final response = await http.get(
    uri,
    headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/pdf',
    },
  ).timeout(const Duration(seconds: 60));

  if (response.statusCode != 200) {
    String message = 'Unable to download PDF report';

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        message = decoded['message']?.toString() ?? message;
      }
    } catch (_) {
      // Keep the default error message.
    }

    throw Exception(message);
  }

  final contentType =
      response.headers['content-type']?.toLowerCase() ?? '';

  if (!contentType.contains('application/pdf')) {
    throw Exception('Server did not return a PDF file');
  }

  final filename = period == 'monthly'
      ? 'ClearPass_Monthly_${date.year}_${date.month.toString().padLeft(2, '0')}'
      : 'ClearPass_Yearly_${date.year}';

  await FileSaver.instance.saveFile(
    name: filename,
    bytes: Uint8List.fromList(response.bodyBytes),
    fileExtension: 'pdf',
    mimeType: MimeType.pdf,
  );
}

}
