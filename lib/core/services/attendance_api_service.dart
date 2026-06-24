import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../global/global_api.dart';
import 'auth_storage_service.dart';

class AttendanceApiService {
  final AuthStorageService _storage = AuthStorageService();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // POST /api/attendance/time-in
  Future<Map<String, dynamic>> timeIn({String? date, String? time}) async {
    try {
      final headers = await _authHeaders();
      final body = {
        'date': date,
        'time': time,
      }..removeWhere((k, v) => v == null);
      final response = await http.post(
        Uri.parse('${GlobalApi.baseUrl}/attendance/time-in'),
        headers: headers,
        body: jsonEncode(body),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // POST /api/attendance/time-out
  Future<Map<String, dynamic>> timeOut({String? date, String? time}) async {
    try {
      final headers = await _authHeaders();
      final body = {
        'date': date,
        'time': time,
      }..removeWhere((k, v) => v == null);
      final response = await http.post(
        Uri.parse('${GlobalApi.baseUrl}/attendance/time-out'),
        headers: headers,
        body: jsonEncode(body),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // GET /api/attendance/my-records
  Future<Map<String, dynamic>> getMyRecords() async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('${GlobalApi.baseUrl}/attendance/my-records'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // GET /api/attendance/report?date=YYYY-MM-DD
  Future<Map<String, dynamic>> getAttendanceReport(String date) async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('${GlobalApi.baseUrl}/attendance/report?date=$date'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}
