import 'package:flutter/foundation.dart';
import '../core/services/auth_storage_service.dart';
import '../core/services/camp_sync_service.dart';
import '../models/mr_model/mr_patient_model.dart';

/// Web-style camp mode (matches React CampContext + team selection).
class CampProvider extends ChangeNotifier {
  final CampSyncService _sync = CampSyncService();
  final AuthStorageService _storage = AuthStorageService();

  Map<String, dynamic>? _activeCamp;
  Map<String, dynamic>? _selectedTeam; // null = no team chosen
  bool _loading = true;

  Map<String, dynamic>? get activeCamp => _activeCamp;
  Map<String, dynamic>? get selectedTeam => _selectedTeam;
  bool get isCampMode => _activeCamp != null;
  bool get loading => _loading;
  String? get campId => _activeCamp?['id']?.toString();

  // ── Team-member name helpers (used in prescription / nutrition / vitals) ──
  String get medicalOfficer => _selectedTeam?['medical_officer']?.toString() ?? '';
  String get nutritionist   => _selectedTeam?['nutritionist']?.toString()   ?? '';
  String get medicalAssistant => _selectedTeam?['medical_assistant']?.toString() ?? '';
  String get teamName       => _selectedTeam?['team_name']?.toString()       ?? '';

  String get campDisplayName {
    if (_activeCamp == null) return '';
    return (_activeCamp!['camp_name'] ?? _activeCamp!['name'] ?? '').toString();
  }

  String get campLocation =>
      (_activeCamp?['address'] ?? _activeCamp?['location'] ?? _activeCamp?['venue'] ?? '').toString();

  Future<void> initialize() async {
    _loading = true;
    notifyListeners();
    final stored = await _storage.getActiveCamp();
    if (stored != null) {
      _activeCamp = _normalizeCamp(stored);
    }
    final storedTeam = await _storage.getActiveTeam();
    if (storedTeam != null) {
      _selectedTeam = storedTeam;
    }
    _loading = false;
    notifyListeners();
  }

  Map<String, dynamic> _normalizeCamp(Map<String, dynamic> camp) {
    return {
      ...camp,
      'camp_name': camp['camp_name'] ?? camp['name'],
    };
  }

  bool canAccessCampMode(bool isAdmin, bool Function(String) can) {
    return isAdmin || can('CAMPS.WEB_LOGIN.ACCESS');
  }

  Future<List<Map<String, dynamic>>> fetchAvailableCamps() async {
    final result = await _sync.fetchWebAvailableCamps();
    if (result['success'] == true) {
      final list = result['data'] as List? ?? [];
      return list
          .map((c) => _normalizeCamp(Map<String, dynamic>.from(c as Map)))
          .toList();
    }
    return [];
  }

  /// Fetch teams assigned to a specific camp (matches React getTeamsByCamp).
  Future<List<Map<String, dynamic>>> fetchTeamsByCamp(String campId) async {
    final result = await _sync.getTeamsByCamp(campId);
    if (result['success'] == true) {
      final list = result['data'] as List? ?? [];
      return list.map((t) => Map<String, dynamic>.from(t as Map)).toList();
    }
    return [];
  }

  /// Join a camp, optionally with a selected team.
  /// Matches React: loginToCamp(campId, teamId, teamObject).
  Future<({bool success, String? message})> loginToCamp(
    String campId, {
    Map<String, dynamic>? team,
  }) async {
    final result = await _sync.webSelectCamp(campId);
    if (result['success'] == true) {
      final data = result['data'] as Map<String, dynamic>? ?? {};
      final camp = data['camp'] as Map<String, dynamic>? ?? data;
      _activeCamp = _normalizeCamp(Map<String, dynamic>.from(camp));
      _selectedTeam = team;
      await _storage.saveActiveCamp(_activeCamp!);
      await _storage.saveActiveTeam(_selectedTeam);
      notifyListeners();
      return (success: true, message: null);
    }
    return (
      success: false,
      message: result['message']?.toString() ?? 'Failed to join camp',
    );
  }

  Future<void> exitCamp() async {
    _activeCamp = null;
    _selectedTeam = null;
    await _storage.clearActiveCamp();
    await _storage.clearActiveTeam();
    notifyListeners();
  }

  Future<List<dynamic>> fetchCampPatients({int limit = 200}) async {
    if (_activeCamp == null) return [];
    final result = await _sync.fetchWebCampPatients(
      campId: campId!,
      limit: limit,
    );
    if (result['success'] == true) {
      final data = result['data'];
      if (data is Map && data['patients'] is List) {
        return data['patients'] as List;
      }
      if (data is List) return data;
    }
    return [];
  }

  List<dynamic> mapCampPatientsForSidebar(List<dynamic> patients) {
    return patients.map((patient) {
      final p = patient as Map<String, dynamic>;
      final name = p['patient_name']?.toString() ??
          '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim();
      return {
        'srl_no': p['id'] ?? p['mr_number'],
        'patient_mr_number': p['mr_number'],
        'receipt_id': '',
        'patient_name': name,
        'service_detail': p['last_vitals_at'] != null
            ? 'Vitals recorded'
            : 'Camp patient',
        'doctor_name': medicalOfficer,
        'token_number': null,
      };
    }).toList();
  }

  Future<({bool success, String? mrNumber, String? message})> registerCampPatient(
    Map<String, dynamic> payload,
  ) async {
    if (campId == null) {
      return (success: false, mrNumber: null, message: 'No active camp');
    }
    final body = {...payload, 'camp_id': campId};
    final result = await _sync.createWebCampPatient(payload: body);
    if (result['success'] == true) {
      final data = result['data'];
      final mr = data is Map ? data['mr_number']?.toString() : null;
      return (success: true, mrNumber: mr, message: null);
    }
    return (
      success: false,
      mrNumber: null,
      message: result['message']?.toString() ?? 'Registration failed',
    );
  }

  Future<List<PatientModel>> searchCampPatients(String query) async {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return [];
    final patients = await fetchCampPatients(limit: 200);
    return patients
        .where((patient) {
          final p = patient as Map<String, dynamic>;
          final name = (p['patient_name'] ??
                  '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}')
              .toString()
              .toLowerCase();
          final mr = (p['mr_number'] ?? '').toString().toLowerCase();
          final phone = (p['phone'] ?? '').toString();
          return mr.contains(q) || name.contains(q) || phone.contains(q);
        })
        .map((p) => PatientModel.fromCampMap(p as Map<String, dynamic>))
        .toList();
  }
}
