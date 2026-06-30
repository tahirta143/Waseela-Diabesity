import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../global/global_api.dart';
import 'auth_storage_service.dart';

class PrescriptionApiService {
  final AuthStorageService _storage = AuthStorageService();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ─── POST /api/prescriptions ──────────────────────────────────────
  Future<Map<String, dynamic>> savePrescription(Map<String, dynamic> data) async {
    try {
      final headers = await _authHeaders();
      final response = await http.post(
        Uri.parse('${GlobalApi.baseUrl}/prescriptions'),
        headers: headers,
        body: jsonEncode(data),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ─── GET /api/prescriptions/consultation-patients ───────────────
  Future<Map<String, dynamic>> fetchConsultationPatients() async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('${GlobalApi.baseUrl}/prescriptions/consultation-patients'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ─── GET /api/prescriptions/history/:mr ───────────────────────────
  Future<Map<String, dynamic>> fetchPrescriptionHistory(String mrNumber) async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('${GlobalApi.baseUrl}/prescriptions/history/$mrNumber'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ─── GET /api/diagnosis/questions/department/:dept ───────────────
  Future<Map<String, dynamic>> fetchDiagnosisQuestions(String department) async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('${GlobalApi.baseUrl}/diagnosis/questions/department/${Uri.encodeComponent(department)}'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ─── GET /api/medicines/search ────────────────────────────────────
  Future<Map<String, dynamic>> searchMedicines(String query) async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('${GlobalApi.baseUrl}/medicines/search?q=${Uri.encodeComponent(query)}'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ─── GET /api/eye-setup ──────────────────────────────────────────
  Future<Map<String, dynamic>> fetchEyeSetupItems(String type) async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('${GlobalApi.baseUrl}/eye-setup?item_type=${Uri.encodeComponent(type)}'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ─── GET /api/lab/tests ──────────────────────────────────────────
  Future<Map<String, dynamic>> fetchLabTests() async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('${GlobalApi.baseUrl}/lab/tests'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ─── GET /api/radiology-tests ─────────────────────────────────────
  Future<Map<String, dynamic>> fetchRadiologyTests() async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('${GlobalApi.baseUrl}/radiology-tests'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ─── GET /api/instructions-setup ─────────────────────────────────
  Future<Map<String, dynamic>> fetchPredefinedInstructions() async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('${GlobalApi.baseUrl}/instructions-setup'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ─── POST /api/medicines ─────────────────────────────────────────
  Future<Map<String, dynamic>> createMedicine(Map<String, dynamic> data) async {
    try {
      final headers = await _authHeaders();
      final response = await http.post(
        Uri.parse('${GlobalApi.baseUrl}/medicines'),
        headers: headers,
        body: jsonEncode(data),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ─── POST /api/lab/tests ─────────────────────────────────────────
  Future<Map<String, dynamic>> createLabTest(Map<String, dynamic> data) async {
    try {
      final headers = await _authHeaders();
      final response = await http.post(
        Uri.parse('${GlobalApi.baseUrl}/lab/tests'),
        headers: headers,
        body: jsonEncode(data),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ─── POST /api/radiology-tests ───────────────────────────────────
  Future<Map<String, dynamic>> createRadiologyTest(Map<String, dynamic> data) async {
    try {
      final headers = await _authHeaders();
      final response = await http.post(
        Uri.parse('${GlobalApi.baseUrl}/radiology-tests'),
        headers: headers,
        body: jsonEncode(data),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
