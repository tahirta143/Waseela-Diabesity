import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/services/pdf_eye_prescription_service.dart';
import '../../core/services/prescription_api_service.dart';
import '../../core/services/mr_api_service.dart';
import '../../core/services/vitals_api_service.dart';
import '../../core/services/ai_api_service.dart';
import '../../models/vitals_model/vitals_model.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/camp_sync_service.dart';
import '../../core/services/auth_storage_service.dart';
import '../../core/utils/database_helper.dart';
import '../../models/mr_model/mr_patient_model.dart';
import '../../models/prescription_model/prescription_model.dart';

class PrescriptionProvider extends ChangeNotifier {
  final PrescriptionApiService _apiService = PrescriptionApiService();
  final MrApiService _mrApiService = MrApiService();
  final VitalsApiService _vitalsApiService = VitalsApiService();
  final AiApiService _aiApiService = AiApiService();
  final ConnectivityService _connectivity = ConnectivityService();
  final CampSyncService _syncService = CampSyncService();
  final DatabaseHelper _db = DatabaseHelper();
  final AuthStorageService _storage = AuthStorageService();

  // ─── Loading States ───────────────────────────────────────────────
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isLoadingPatients = false;
  bool _isLoadingHistory = false;
  bool _isLoadingTests = false;
  bool _analyzingVisits = false;
  String? _visitAnalysis;
  String? _errorMessage;

  // New Alignment State
  String? _receiptId;
  String? _tokenNumber;
  String? _doctorName;
  int? _doctorSrlNo;
  String _medMode = 'medicine'; // 'medicine' or 'formula'
  String _inputLang = 'en'; // 'en' or 'ur'
  List<dynamic> _medicineSearchResults = [];
  String _medSearchQuery = '';
  
  // Investigation Search
  String _labSearch = '';
  String _xraySearch = '';
  String _ultrasoundSearch = '';
  String _ctSearch = '';
  String? _mrSearchValue;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isLoadingPatients => _isLoadingPatients;
  bool get isLoadingHistory => _isLoadingHistory;
  bool get isLoadingTests => _isLoadingTests;
  bool get analyzingVisits => _analyzingVisits;
  String? get visitAnalysis => _visitAnalysis;
  String? get errorMessage => _errorMessage;

  String? get receiptId => _receiptId;
  String? get tokenNumber => _tokenNumber;
  String? get doctorName => _doctorName;
  int? get doctorSrlNo => _doctorSrlNo;
  String get medMode => _medMode;
  String get inputLang => _inputLang;
  List<dynamic> get medicineSearchResults => _medicineSearchResults;
  String get medSearchQuery => _medSearchQuery;
  String get labSearch => _labSearch;
  String get xraySearch => _xraySearch;
  String get ultrasoundSearch => _ultrasoundSearch;
  String get ctSearch => _ctSearch;
  String? get mrSearchValue => _mrSearchValue;

  bool get isAdmissionReferral => noteControllers['referTo']!.text.trim().toLowerCase().contains('admission');

  // Predefined Instructions State
  List<dynamic> _predefinedInstructions = [];
  List<dynamic> get predefinedInstructions => _predefinedInstructions;

  List<dynamic> _filteredInstructions = [];
  List<dynamic> get filteredInstructions => _filteredInstructions;

  bool _isLoadingInstructions = false;
  bool get isLoadingInstructions => _isLoadingInstructions;

  bool get hasAnyVitals {
    if (_currentPatient == null) return false;
    if (_currentVitals != null) return true;
    final keys = ['weight', 'height', 'bp', 'pulse', 'spo2', 'temp', 'pain_scale'];
    return keys.any((k) => vitalControllers[k]?.text.trim().isNotEmpty == true);
  }

  // ─── Patient State ────────────────────────────────────────────────
  PatientModel? _currentPatient;
  PatientModel? get currentPatient => _currentPatient;

  VitalsModel? _currentVitals;
  VitalsModel? get currentVitals => _currentVitals;

  List<dynamic> _consultationPatients = [];
  List<dynamic> get consultationPatients => _consultationPatients;
  List<dynamic> get eyeConsultationPatients => _consultationPatients.where((p) {
        final dept = (p['doctor_department'] ?? '').toString().toLowerCase();
        final service = (p['service_detail'] ?? '').toString().toLowerCase();
        return dept.contains('eye') || service.contains('eye');
      }).toList();

  List<dynamic> getFilteredConsultationPatients(String? department) {
    if (department == null || department.isEmpty) return _consultationPatients;
    final q = department.toLowerCase();
    return _consultationPatients.where((p) {
      final dept = (p['doctor_department'] ?? '').toString().toLowerCase();
      final service = (p['service_detail'] ?? '').toString().toLowerCase();
      return dept.contains(q) || service.contains(q);
    }).toList();
  }

  List<PrescriptionModel> _prescriptionHistory = [];
  List<PrescriptionModel> get prescriptionHistory => _prescriptionHistory;

  // ─── Tests State ──────────────────────────────────────────────────
  List<dynamic> _labTests = [];
  List<dynamic> _radiologyTests = [];
  List<dynamic> get labTests => _labTests;
  List<dynamic> get radiologyTests => _radiologyTests;


  // ─── Form Data (Common) ───────────────────────────────────────────
  final Map<String, TextEditingController> vitalControllers = {
    'temp': TextEditingController(),
    'bp': TextEditingController(),
    'pulse': TextEditingController(),
    'weight': TextEditingController(),
    'height': TextEditingController(),
    'blood': TextEditingController(),
    'receiptId': TextEditingController(),
    'spo2': TextEditingController(),
    'pain_scale': TextEditingController(),
    'consultant': TextEditingController(), // Editable — mirrors React's doctorName state
  };

  final Map<String, TextEditingController> noteControllers = {
    'history': TextEditingController(),
    'treatment': TextEditingController(),
    'notes': TextEditingController(),
    'remarks': TextEditingController(),
    'referTo': TextEditingController(),
  };

  // ─── GP Specific State ────────────────────────────────────────────
  List<PrescriptionMedicine> _prescribedMedicines = [];
  List<PrescriptionMedicine> get prescribedMedicines => _prescribedMedicines;

  List<PrescriptionInvestigation> _selectedInvestigations = [];
  List<PrescriptionInvestigation> get selectedInvestigations => _selectedInvestigations;

  PrescriptionModel? _lastSavedPrescription;
  PrescriptionModel? get lastSavedPrescription => _lastSavedPrescription;

  List<String> _instructions = [];
  List<String> get instructions => _instructions;

  List<dynamic> _diagnosisQuestions = [];
  List<dynamic> get diagnosisQuestions => _diagnosisQuestions;
  
  Map<int, dynamic> _diagnosisAnswers = {};
  Map<int, dynamic> get diagnosisAnswers => _diagnosisAnswers;

  // ─── Eye Specific State ───────────────────────────────────────────
  // History Checkboxes
  final Map<String, bool> eyeHistory = {
    'Asthma': false, 'Diabetes': false, 'HBV': false, 'HCV': false,
    'Hypertension': false, 'Ischemic Heart Disease': false, 'Pregnancy': false, 'RT Injury': false,
  };
  final TextEditingController eyeOtherHistoryCtrl = TextEditingController();

  // Refraction Matrix
  final Map<String, Map<String, TextEditingController>> refractionCtrls = {
    'right': {
      'sph': TextEditingController(), 'cyl': TextEditingController(), 
      'axis': TextEditingController(), 'va': TextEditingController(), 'addition': TextEditingController()
    },
    'left': {
      'sph': TextEditingController(), 'cyl': TextEditingController(), 
      'axis': TextEditingController(), 'va': TextEditingController(), 'addition': TextEditingController()
    },
    'add01': {
      'sph': TextEditingController(), 'cyl': TextEditingController(), 
      'axis': TextEditingController(), 'va': TextEditingController(), 'addition': TextEditingController()
    },
    'add02': {
      'sph': TextEditingController(), 'cyl': TextEditingController(), 
      'axis': TextEditingController(), 'va': TextEditingController(), 'addition': TextEditingController()
    },
  };

  // Vision Stats
  final Map<String, Map<String, TextEditingController>> visionCtrls = {
    'right': {'var': TextEditingController(), 'ph': TextEditingController(), 'ref': TextEditingController()},
    'left': {'var': TextEditingController(), 'ph': TextEditingController(), 'ref': TextEditingController()},
  };

  // Examination & Management
  final TextEditingController presentingComplaintsCtrl = TextEditingController();
  List<EyeSideItem> _eyeComplaints = [];
  List<EyeSideItem> _eyeExaminations = [];
  List<EyeSideItem> _eyeDiagnosis = [];
  List<EyeSideItem> _eyeAdvised = [];
  String _eyeTreatmentType = '';
  
  // API Setup Lists
  List<String> eyeSetupComplaints = [];
  List<String> eyeSetupExaminations = [];
  List<String> eyeSetupDiagnosis = [];
  List<String> eyeSetupAdvised = [];
  List<String> eyeSetupSurgery = [];
  final TextEditingController eyeRemarksCtrl = TextEditingController();
  final TextEditingController eyeSurgeryNameCtrl = TextEditingController();
  DateTime? _eyeOperationDate;
  List<String> _surgerySearchResults = [];
  List<String> get surgerySearchResults => _surgerySearchResults;

  List<EyeSideItem> get eyeComplaints => _eyeComplaints;
  List<EyeSideItem> get eyeExaminations => _eyeExaminations;
  List<EyeSideItem> get eyeDiagnosis => _eyeDiagnosis;
  List<EyeSideItem> get eyeAdvised => _eyeAdvised;
  String get eyeTreatmentType => _eyeTreatmentType;
  DateTime? get eyeOperationDate => _eyeOperationDate;

  // ─── Actions ─────────────────────────────────────────────────────

  Future<void> loadCampPatients(String campId) async {
    _isLoadingPatients = true;
    notifyListeners();
    try {
      final result =
          await _syncService.fetchWebCampPatients(campId: campId, limit: 200);
      if (result['success'] == true) {
        final data = result['data'];
        final patients = data is Map ? (data['patients'] as List? ?? []) : [];
        _consultationPatients = patients.map((patient) {
          final p = patient as Map<String, dynamic>;
          final name = p['patient_name']?.toString() ??
              '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim();
          return {
            'srl_no': p['id'] ?? p['mr_number'],
            'patient_mr_number': p['mr_number'],
            'receipt_id': '',
            'patient_name': name,
            'service_detail': 'Camp patient',
            'doctor_name': '',
            'token_number': null,
          };
        }).toList();
      }
    } catch (e) {
      debugPrint('Error camp patients: $e');
    }
    _isLoadingPatients = false;
    notifyListeners();
  }

  Future<void> loadConsultationPatients() async {
    _isLoadingPatients = true;
    notifyListeners();
    await loadEyeSetupItems();

    final activeCamp = await _storage.getActiveCamp();
    if (activeCamp != null) {
      final campId = activeCamp['id']?.toString();
      if (campId != null) {
        await loadCampPatients(campId);
        return;
      }
    }

    try {
      // 1. Load local pending visits
      final localVisits = await _db.queryAll('visits_local');
      final List<dynamic> merged = [];
      
      merged.addAll(localVisits
          .where((v) => v['sync_status'] == 'pending')
          .map((v) => {
                'patient_mr_number': (v['mr_number'] ?? v['patient_uuid'])?.toString(),
                'patient_name': v['patient_name'],
                'receipt_id': v['receipt_id'],
                'service_detail': v['opd_service'],
                'date': v['date'],
                'sync_status': 'pending',
                'status': 'Pending Sync',
              }));

      // 2. Load Online
      if (_connectivity.isOnline.value) {
        try {
          final res = await _apiService.fetchConsultationPatients().timeout(const Duration(seconds: 10));
          if (res['success'] == true) {
            final onlineData = res['data'] as List? ?? [];
            merged.addAll(onlineData);
          }
        } catch (e) {
          debugPrint('⚠️ Online consultation patients load failed: $e');
        }
      }

      _consultationPatients = merged;
    } catch (e) {
      debugPrint('Error merging consultation patients: $e');
    }

    _isLoadingPatients = false;
    notifyListeners();
  }

  Future<void> loadEyeSetupItems() async {
    bool found = false;
    if (_connectivity.isOnline.value) {
      try {
        final res = await _apiService.fetchEyeSetupItems('')
            .timeout(const Duration(seconds: 8));
        if (res['success'] == true) {
          final items = res['data'] as List? ?? [];
          _processEyeSetup(items);
          found = true;
        }
      } catch (e) {
        debugPrint('⚠️ Online eye setup failed: $e');
      }
    }

    if (!found) {
      debugPrint('📴 Loading eye setup from local DB');
      final localItems = await _db.queryAll('master_eye_setup');
      _processEyeSetup(localItems);
    }
  }

  void _processEyeSetup(List<dynamic> items) {
    eyeSetupComplaints.clear();
    eyeSetupExaminations.clear();
    eyeSetupDiagnosis.clear();
    eyeSetupAdvised.clear();
    eyeSetupSurgery.clear();
    for (var item in items) {
      final type = (item['item_type'] ?? '').toString().trim();
      final name = item['item_name'] ?? '';
      if (type == 'Complaint') eyeSetupComplaints.add(name);
      else if (type == 'Examination') eyeSetupExaminations.add(name);
      else if (type == 'Diagnosis') eyeSetupDiagnosis.add(name);
      else if (type == 'Advised') eyeSetupAdvised.add(name);
      else if (type == 'Surgery') eyeSetupSurgery.add(name);
    }
    notifyListeners();
  }

  Future<void> selectConsultationPatient(dynamic patient, {String? department}) async {
    final mr = patient['patient_mr_number']?.toString().trim() ?? '';
    _receiptId = patient['receipt_id']?.toString();
    _tokenNumber = patient['token_number']?.toString();
    _doctorSrlNo = int.tryParse(patient['doctor_srl_no']?.toString() ?? '');

    // Mirror React's selectConsultPatient logic:
    // 1. Use doctor_name directly if available
    // 2. Fallback: parse "Dr. <name>" from service_detail
    final rawDoctorName = patient['doctor_name']?.toString();
    if (rawDoctorName != null && rawDoctorName.isNotEmpty) {
      _doctorName = rawDoctorName;
    } else {
      final detail = patient['service_detail']?.toString() ?? '';
      final drMatch = RegExp(r'Dr\.\s*(.+)', caseSensitive: false).firstMatch(detail);
      if (drMatch != null) {
        _doctorName = drMatch.group(1)?.trim();
      } else {
        _doctorName = null;
      }
    }

    // Set controllers AFTER searchPatient, because searchPatient clears
    // all vitalControllers at the start. Setting them before would get wiped.
    // (React avoids this because setState() values are independent of search.)
    await searchPatient(mr, department: department);
    vitalControllers['receiptId']?.text = _receiptId ?? '';
    // Populate consultant controller from resolved _doctorName
    vitalControllers['consultant']?.text = _doctorName ?? '';
    notifyListeners();
  }

  void setMedMode(String mode) {
    _medMode = mode;
    _medicineSearchResults = [];
    _medSearchQuery = '';
    notifyListeners();
  }

  void setInputLang(String lang) {
    _inputLang = lang;
    notifyListeners();
  }

  void updateLabSearch(String q) { _labSearch = q; notifyListeners(); }
  void updateXraySearch(String q) { _xraySearch = q; notifyListeners(); }
  void updateUltrasoundSearch(String q) { _ultrasoundSearch = q; notifyListeners(); }
  void updateCtSearch(String q) { _ctSearch = q; notifyListeners(); }

  void updateMedSearch(String query) async {
    _medSearchQuery = query;
    if (query.isEmpty) {
      _medicineSearchResults = [];
      notifyListeners();
      return;
    }
    
    if (!_connectivity.isOnline.value) {
      debugPrint('📴 App is OFFLINE. Searching medicines in local DB.');
      final localMeds = await _db.queryAll('master_medicines');
      _medicineSearchResults = localMeds.where((m) => 
        (m['name'] ?? '').toString().toLowerCase().contains(query.toLowerCase())
      ).map((m) => {
        'id': m['id'],
        'medicine_name': m['name'],
        'formula': m['is_formula'],
      }).toList();
      notifyListeners();
      return;
    }

    final res = await _apiService.searchMedicines(query);
    if (res['success'] == true) {
      _medicineSearchResults = res['data'] ?? [];
    }
    notifyListeners();
  }

  void setDoctorName(String? name) {
    _doctorName = name;
    vitalControllers['consultant']?.text = name ?? '';
    notifyListeners();
  }

  Future<void> searchPatient(String mrNumber, {String? department}) async {
    _isLoading = true;
    _errorMessage = null;
    _currentPatient = null;
    _currentVitals = null;
    _prescriptionHistory = [];
    _visitAnalysis = null;
    _mrSearchValue = mrNumber; // Keep the search value for UI
    for (var c in vitalControllers.values) c.clear();
    for (var c in noteControllers.values) c.clear();
    
    final activeCamp = await _storage.getActiveCamp();
    if (activeCamp != null) {
      final activeTeam = await _storage.getActiveTeam();
      String rawDocName = '';
      if (department == 'Nutritionist') {
        rawDocName = activeTeam?['nutritionist']?.toString() ?? '';
      } else if (department == 'Eye' || department == 'Lab' || department == 'Vitals' || department == 'Foot Notes' || department == 'FootNotes') {
        rawDocName = activeTeam?['medical_assistant']?.toString() ?? '';
      } else {
        rawDocName = activeTeam?['medical_officer']?.toString() ?? '';
      }
      _doctorName = rawDocName.replaceFirst(RegExp(r'^Dr\.\s*', caseSensitive: false), '');
    }
    
    notifyListeners();

    try {
      final mr = mrNumber.trim();
      bool foundOnline = false;

      if (_connectivity.isOnline.value) {
        final result = await _mrApiService.fetchPatientByMR(mr);
        if (result.success && result.patient != null) {
          _currentPatient = result.patient!.toPatientModel();
          _mrSearchValue = null; // Clear search value if patient found
          foundOnline = true;
          // Notify early so patient info shows up while other details fetch
          notifyListeners();
          
          await fetchDiagnosis(department ?? 'General'); 
          await fetchVitals(mr, receiptId: _receiptId);
          await fetchHistory(mr);
        }
      }

      if (!foundOnline) {
        // 📴 Search locally
        debugPrint('📴 Prescription search: searching local DB for $mr');
        final db = await _db.database;
        
        // Try exact, padded, and device_uuid
        final searchInput = _normalizeMrNumber(mr);
        final localRows = await db.query(
          'patients_local',
          where: 'mr_number = ? OR mr_number = ? OR device_uuid = ?',
          whereArgs: [mr, searchInput, mr]
        );

        if (localRows.isNotEmpty) {
          _currentPatient = PatientModel.fromLocalMap(localRows.first);
          _mrSearchValue = null;
          debugPrint('✅ Found patient locally: ${_currentPatient?.fullName}');
          
          // Also load other data offline
          await fetchDiagnosis(department ?? 'General');
          await loadTests();
          await fetchVitals(mr, receiptId: _receiptId);
        } else {
          // Try numeric match as last resort
          final numericInput = mr.replaceAll(RegExp(r'[^0-9]'), '');
          if (numericInput.isNotEmpty) {
             final allLocal = await db.query('patients_local');
             final match = allLocal.firstWhere((p) {
                final dbMr = (p['mr_number'] ?? '').toString();
                final dbNumeric = dbMr.replaceAll(RegExp(r'[^0-9]'), '');
                return dbNumeric.isNotEmpty && (dbNumeric == numericInput || int.tryParse(dbNumeric) == int.tryParse(numericInput));
             }, orElse: () => {});
             if (match.isNotEmpty) {
               _currentPatient = PatientModel.fromLocalMap(match);
               _mrSearchValue = null;
               debugPrint('✅ Found patient locally via numeric match: ${_currentPatient?.fullName}');
               await fetchDiagnosis(department ?? 'General');
               await loadTests();
               await fetchVitals(_currentPatient?.mrNumber ?? mr, receiptId: _receiptId);
             }
          }
        }
      }

      if (_currentPatient == null) {
        _errorMessage = 'Patient not found locally or online';
      }
    } catch (e) {
      debugPrint('Error in searchPatient: $e');
      _errorMessage = 'An error occurred while searching: $e';
    } finally {
      _isLoading = false;
      vitalControllers['consultant']?.text = _doctorName ?? '';
      notifyListeners();
    }
  }

  Future<void> fetchVitals(String mrNumber, {String? receiptId}) async {
    _currentVitals = null;
    notifyListeners();
    try {
      if (_connectivity.isOnline.value) {
        Map<String, dynamic> res = {'success': false};

        // 1. Try fetching by Receipt ID first if available
        if (receiptId != null && receiptId.isNotEmpty) {
          res = await _vitalsApiService.getVitalsByReceipt(receiptId);
        }

        // 2. Fallback to MR Number if Receipt fetch failed or returned no data
        if (res['success'] != true || res['data'] == null) {
          res = await _vitalsApiService.getVitalsByMR(mrNumber);
        }

        if (res['success'] == true && res['data'] != null) {
          _currentVitals = VitalsModel.fromJson(res['data']);
        }
      } else {
        final db = await _db.database;
        Map<String, dynamic>? vitalsRow;

        if (receiptId != null && receiptId.isNotEmpty) {
          final visits = await db.query(
            'visits_local',
            where: 'receipt_id = ?',
            whereArgs: [receiptId],
            orderBy: 'created_at DESC',
            limit: 1,
          );
          if (visits.isNotEmpty) {
            final visitUuid = visits.first['device_uuid']?.toString();
            if (visitUuid != null && visitUuid.isNotEmpty) {
              final rows = await db.query(
                'vitals_local',
                where: 'visit_uuid = ?',
                whereArgs: [visitUuid],
                orderBy: 'created_at DESC',
                limit: 1,
              );
              if (rows.isNotEmpty) {
                vitalsRow = rows.first;
              }
            }
          }
        }

        if (vitalsRow == null) {
          final rows = await db.query(
            'vitals_local',
            where: 'mr_number = ?',
            whereArgs: [mrNumber],
            orderBy: 'created_at DESC',
            limit: 1,
          );
          if (rows.isNotEmpty) {
            vitalsRow = rows.first;
          }
        }

        if (vitalsRow != null) {
          final normalized = Map<String, dynamic>.from(vitalsRow);
          normalized['temperature'] = normalized['temperature'] ?? normalized['temp'];
          normalized['receipt_id'] = receiptId;
          _currentVitals = VitalsModel.fromJson(normalized);
        }
      }
      if (_currentVitals != null) {
        _populateVitalControllers(_currentVitals!);
      }
    } catch (e) {
      debugPrint('Error fetching vitals: $e');
    }
    notifyListeners();
  }

  void _populateVitalControllers(VitalsModel vitals) {
    vitalControllers['temp']?.text = vitals.temperature?.toString() ?? '';
    vitalControllers['bp']?.text = (vitals.systolic != null && vitals.diastolic != null) ? '${vitals.systolic}/${vitals.diastolic}' : '';
    vitalControllers['pulse']?.text = vitals.pulse?.toString() ?? '';
    vitalControllers['weight']?.text = vitals.weight?.toString() ?? '';
    vitalControllers['height']?.text = vitals.height?.toString() ?? '';
    vitalControllers['spo2']?.text = vitals.spo2?.toString() ?? '';
    vitalControllers['pain_scale']?.text = vitals.painScale?.toString() ?? '';
  }

  Future<void> fetchHistory(String mrNumber) async {
    _isLoadingHistory = true;
    notifyListeners();
    try {
      final res = await _apiService.fetchPrescriptionHistory(mrNumber);
      if (res['success'] == true) {
        // API sometimes returns data as a JSON-encoded string instead of a List.
        // Decode it first if needed.
        dynamic rawData = res['data'];
        if (rawData is String && rawData.isNotEmpty) {
          try {
            final decoded = jsonDecode(rawData);
            if (decoded is List) rawData = decoded;
          } catch (_) {
            rawData = [];
          }
        }
        final List raw = rawData is List ? rawData : [];
        _prescriptionHistory = raw
            .whereType<Map<String, dynamic>>()
            .map((e) => PrescriptionModel.fromJson(e))
            .toList();
      }
    } catch (e) {
      debugPrint('Error fetching history: $e');
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  Future<void> loadTests() async {
    if (_labTests.isNotEmpty && _radiologyTests.isNotEmpty) return;
    _isLoadingTests = true;
    notifyListeners();
    
    try {
      bool foundLab = false;
      bool foundRad = false;

      if (_connectivity.isOnline.value) {
        try {
          final labRes = await _apiService.fetchLabTests()
              .timeout(const Duration(seconds: 8));
          if (labRes['success'] == true) {
            _labTests = labRes['data'] ?? [];
            foundLab = true;
          }

          final radRes = await _apiService.fetchRadiologyTests()
              .timeout(const Duration(seconds: 8));
          if (radRes['success'] == true) {
            _radiologyTests = radRes['data'] ?? [];
            foundRad = true;
          }
        } catch (e) {
          debugPrint('⚠️ Online tests load failed: $e');
        }
      }

      if (!foundLab || !foundRad) {
        debugPrint('📴 Loading tests from local DB');
        final localTests = await _db.queryAll('master_investigations');
        if (!foundLab) {
          _labTests = localTests.where((t) {
            final type = (t['test_type'] ?? t['test_category'] ?? '').toString().toLowerCase();
            return type == 'lab';
          }).toList();
        }
        if (!foundRad) {
          _radiologyTests = localTests.where((t) {
            final type = (t['test_type'] ?? t['test_category'] ?? '').toString().toLowerCase();
            return type != 'lab' && type.isNotEmpty;
          }).toList();
        }
        // If still empty, split by type
        if (_labTests.isEmpty && _radiologyTests.isEmpty && localTests.isNotEmpty) {
          debugPrint('📴 Splitting all ${localTests.length} tests as lab');
          _labTests = localTests;
        }
      }
    } catch (e) {
      debugPrint('Error loading tests: $e');
    } finally {
      _isLoadingTests = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> searchMedicines(String query) async {
    return await _apiService.searchMedicines(query);
  }

  // Cache online diagnosis questions to local DB for offline use
  void _cacheDiagnosisToDb(List<dynamic> questions, String department) async {
    try {
      final db = await _db.database;
      // Delete existing entries for this department only
      await db.delete('master_diagnosis', where: 'LOWER(category) = ?', whereArgs: [department.toLowerCase()]);
      for (var q in questions) {
        String optionsJson;
        try {
          optionsJson = jsonEncode(q['options'] ?? q['choices'] ?? []);
        } catch (_) {
          optionsJson = '[]';
        }
        await db.insert('master_diagnosis', {
          'id': q['id'],
          'question': q['question_text'] ?? q['question'] ?? '',
          'options_json': optionsJson,
          'category': department, // Always use the queried department, not q['category']
          'question_type': q['question_mode'] ?? q['question_type'] ?? 'choice',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      debugPrint('💾 Cached ${questions.length} diagnosis questions for $department');
      if (questions.isNotEmpty) {
        debugPrint('💾 First cached item: id=${questions.first['id']}, category=$department, mode=${questions.first['question_mode'] ?? questions.first['question_type']}');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to cache diagnosis: $e');
    }
  }

  Future<void> fetchDiagnosis(String department) async {
    bool found = false;
    if (_connectivity.isOnline.value) {
      try {
        final res = await _apiService.fetchDiagnosisQuestions(department)
            .timeout(const Duration(seconds: 8));
        if (res['success'] == true) {
          _diagnosisQuestions = res['data'] ?? [];
          _diagnosisAnswers = {};
          found = true;
          // Log first item structure for debugging
          if (_diagnosisQuestions.isNotEmpty) {
            debugPrint('🌐 Online diagnosis first item: ${_diagnosisQuestions.first}');
          }
          // Cache to local DB for offline use
          _cacheDiagnosisToDb(_diagnosisQuestions, department);
        }
      } catch (e) {
        debugPrint('⚠️ Online diagnosis failed: $e');
      }
    }

    if (!found) {
      debugPrint('📴 Loading diagnosis from local DB for $department');
      final db = await _db.database;

      // First try: exact department match (cached from online API)
      List<Map<String, dynamic>> localDiagnosis = await db.query(
        'master_diagnosis',
        where: 'LOWER(category) = ?',
        whereArgs: [department.toLowerCase()],
      );

      // Second try: for Eye, also try 'eye' variants
      if (localDiagnosis.isEmpty && department.toLowerCase().contains('eye')) {
        localDiagnosis = await db.query(
          'master_diagnosis',
          where: "LOWER(category) LIKE '%eye%'",
        );
      }

      // Only fall back to all questions if we have options data
      // (bootstrap data has no options so it's useless for rendering)
      if (localDiagnosis.isEmpty) {
        debugPrint('📴 No cached diagnosis for $department — need to go online first');
        _diagnosisQuestions = [];
        _diagnosisAnswers = {};
        notifyListeners();
        return;
      }

      debugPrint('📴 Diagnosis rows found in DB: ${localDiagnosis.length}');
      if (localDiagnosis.isNotEmpty) {
        debugPrint('📴 Offline diagnosis first item raw: ${localDiagnosis.first}');
      }

      _diagnosisQuestions = localDiagnosis.map((d) {
        List<dynamic> options = [];
        try {
          final decoded = jsonDecode(d['options_json']?.toString() ?? '[]');
          options = decoded is List ? decoded : [];
        } catch (_) {
          options = [];
        }
        return {
          'id': d['id'],
          'question_text': d['question'],
          'options': options,
          'question_type': d['question_type'] ?? d['question_mode'] ?? 'choice',
          'question_mode': d['question_type'] ?? d['question_mode'] ?? 'choice',
        };
      }).toList();
      _diagnosisAnswers = {};
    }
    notifyListeners();
  }

  // ─── GP Form Helpers ──────────────────────────────────────────────
  
  void addMedicine(PrescriptionMedicine med) {
    _prescribedMedicines.add(med);
    notifyListeners();
  }

  void removeMedicine(int index) {
    _prescribedMedicines.removeAt(index);
    notifyListeners();
  }

  void toggleInvestigation(String type, String name) {
    final exists = _selectedInvestigations.any((i) => i.investigationType == type && i.testName == name);
    if (exists) {
      _selectedInvestigations.removeWhere((i) => i.investigationType == type && i.testName == name);
    } else {
      _selectedInvestigations.add(PrescriptionInvestigation(investigationType: type, testName: name));
    }
    notifyListeners();
  }

  Future<int?> createMedicineIfNeeded(String name, String? category, String? dosage) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return null;

    try {
      final existing = _medicineSearchResults.cast<Map?>().firstWhere(
        (m) => (m?['medicine_name'] ?? m?['name'] ?? '').toString().toLowerCase() == trimmedName.toLowerCase(),
        orElse: () => null,
      );

      if (existing != null) {
        return existing['id'] is num ? (existing['id'] as num).toInt() : int.tryParse(existing['id'].toString());
      }

      if (!_connectivity.isOnline.value) {
        return null;
      }

      final res = await _apiService.createMedicine({
        'medicine_name': trimmedName,
        'category_name': category ?? 'tablet/capsule',
        'default_dosage': dosage ?? '',
      });

      if (res['success'] == true) {
        final newId = res['id'] ?? res['data']?['id'];
        return newId is num ? newId.toInt() : int.tryParse(newId.toString());
      }
    } catch (e) {
      debugPrint('Failed to create medicine: $e');
    }
    return null;
  }

  Future<bool> addCustomInvestigation(String type, String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty) return false;

    // Check if it already exists (case-insensitive)
    final existingList = type == 'lab'
        ? _labTests
        : _radiologyTests.where((t) {
            final cat = (t['test_category'] ?? t['test_type'] ?? '').toString().toLowerCase();
            if (type == 'xray') return cat.contains('x-ray') || cat.contains('xray');
            if (type == 'ultrasound') return cat.contains('ultrasound') || cat.contains('ultra sound');
            return cat.contains('ct-scan') || cat.contains('ct scan') || cat.contains('ctscan') || cat.contains('ct_scan');
          }).toList();

    final alreadyExists = existingList.any((t) => t['test_name'].toString().toLowerCase() == name.toLowerCase());

    if (alreadyExists) {
      // Just toggle selection, don't create it
      toggleInvestigation(type, name);
      return true;
    }

    try {
      if (!_connectivity.isOnline.value) {
        // Offline fallback: toggle directly as custom test
        toggleInvestigation(type, name);
        return true;
      }

      if (type == 'lab') {
        final res = await _apiService.createLabTest({'test_name': name, 'test_rate': 0});
        if (res['success'] != true) {
          _errorMessage = res['message'] ?? 'Could not save new lab test';
          notifyListeners();
          return false;
        }
        final newId = res['id'] ?? res['data']?['id'];
        final newTest = {'id': newId, 'test_name': name, 'test_rate': 0};
        _labTests.add(newTest);
      } else {
        const categoryMap = {
          'xray': 'X-Ray',
          'ultrasound': 'Ultrasound',
          'ct_scan': 'CT-Scan',
        };
        final testCategory = categoryMap[type] ?? 'Radiology';
        final res = await _apiService.createRadiologyTest({
          'test_name': name,
          'test_category': testCategory,
          'test_rate': 0,
        });
        if (res['success'] != true) {
          _errorMessage = res['message'] ?? 'Could not save new test';
          notifyListeners();
          return false;
        }
        final newId = res['id'] ?? res['data']?['id'];
        final newTest = {'id': newId, 'test_name': name, 'test_category': testCategory, 'test_rate': 0};
        _radiologyTests.add(newTest);
      }

      // Add to selected investigations
      final exists = _selectedInvestigations.any((i) => i.investigationType == type && i.testName.toLowerCase() == name.toLowerCase());
      if (!exists) {
        _selectedInvestigations.add(PrescriptionInvestigation(investigationType: type, testName: name));
      }
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to save custom investigation: $e');
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchPredefinedInstructions() async {
    _isLoadingInstructions = true;
    notifyListeners();
    try {
      if (_connectivity.isOnline.value) {
        final res = await _apiService.fetchPredefinedInstructions();
        if (res['success'] == true) {
          final all = res['data'] as List? ?? [];
          _predefinedInstructions = all.where((inst) => inst['is_active'] == 1 || inst['is_active'] == true).toList();
          _filteredInstructions = List.from(_predefinedInstructions);
        }
      }
    } catch (e) {
      debugPrint('Error fetching predefined instructions: $e');
    } finally {
      _isLoadingInstructions = false;
      notifyListeners();
    }
  }

  void filterInstructions(String query) {
    if (query.trim().isEmpty) {
      _filteredInstructions = List.from(_predefinedInstructions);
    } else {
      _filteredInstructions = _predefinedInstructions
          .where((inst) => (inst['instruction_text'] ?? '')
              .toString()
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();
    }
    notifyListeners();
  }

  void addInstruction(String text) {
    if (text.trim().isNotEmpty) {
      _instructions.add(text.trim());
      notifyListeners();
    }
  }

  void removeInstruction(int index) {
    _instructions.removeAt(index);
    notifyListeners();
  }

  void setDiagnosisAnswer(int questionId, dynamic value, {bool isMcq = false}) {
    if (isMcq) {
      final List<int> current = List<int>.from(_diagnosisAnswers[questionId] is List ? _diagnosisAnswers[questionId] : []);
      final int valId = int.tryParse(value.toString()) ?? 0;
      if (valId == 0) return;

      if (current.contains(valId)) {
        current.remove(valId);
      } else {
        current.add(valId);
      }
      _diagnosisAnswers[questionId] = current;
    } else {
      _diagnosisAnswers[questionId] = value;
    }
    notifyListeners();
  }

  void setAdmissionReferral(bool value) {
    final controller = noteControllers['referTo']!;
    if (value) {
      if (controller.text.trim().isEmpty || controller.text.trim().toLowerCase() != 'admission') {
        controller.text = 'Admission';
      }
    } else {
      if (controller.text.trim().toLowerCase() == 'admission') {
        controller.text = '';
      }
    }
    notifyListeners();
  }

  // ─── Eye Form Helpers ───────────────────────────────────────────

  void toggleEyeHistory(String key) {
    eyeHistory[key] = !(eyeHistory[key] ?? false);
    notifyListeners();
  }

  void addEyeItem(String listType, String name, String side) {
    final item = EyeSideItem(name: name, side: side);
    if (listType == 'complaint') _eyeComplaints.add(item);
    else if (listType == 'examination') _eyeExaminations.add(item);
    else if (listType == 'diagnosis') _eyeDiagnosis.add(item);
    else if (listType == 'advised') _eyeAdvised.add(item);
    notifyListeners();
  }

  void removeEyeItem(String listType, int index) {
    if (listType == 'complaint') _eyeComplaints.removeAt(index);
    else if (listType == 'examination') _eyeExaminations.removeAt(index);
    else if (listType == 'diagnosis') _eyeDiagnosis.removeAt(index);
    else if (listType == 'advised') _eyeAdvised.removeAt(index);
    notifyListeners();
  }

  void setEyeTreatmentType(String type) {
    _eyeTreatmentType = type;
    notifyListeners();
  }

  void setOperationDate(DateTime date) {
    _eyeOperationDate = date;
    notifyListeners();
  }

  Future<void> printOldPrescription(BuildContext context, PrescriptionModel rx) async {
    if (_currentPatient != null) {
      await PDFEyePrescriptionService.printPrescription(rx, _currentPatient!);
    }
  }

  // ─── Submission ──────────────────────────────────────────────────

  Future<bool> savePrescription({bool isEye = false, required String doctorName, int? doctorSrlNo}) async {
    if (_currentPatient == null) {
      debugPrint('⚠️ Cannot save prescription: _currentPatient is null');
      return false;
    }
    
    _isSaving = true;
    notifyListeners();

    try {
      // Use the consultant controller text (user may have edited it in the field)
      // matching React where doctorName state is updated via onChange.
      final resolvedDoctorName = vitalControllers['consultant']?.text.trim().isNotEmpty == true
          ? vitalControllers['consultant']!.text.trim()
          : doctorName;

      final prescription = PrescriptionModel(
        mrNumber: _currentPatient?.mrNumber ?? '',
        doctorName: resolvedDoctorName,
        doctorSrlNo: doctorSrlNo,
        receiptId: _receiptId,
        tokenNumber: _tokenNumber,
        vitals: vitalControllers.map((key, controller) => MapEntry(key, controller.text)),
        historyExamination: isEye ? (presentingComplaintsCtrl.text.isEmpty ? null : presentingComplaintsCtrl.text) : (noteControllers['history']?.text.isEmpty ?? true ? null : noteControllers['history']!.text),
        treatment: isEye ? (_eyeTreatmentType.isEmpty ? null : _eyeTreatmentType) : (noteControllers['treatment']?.text.isEmpty ?? true ? null : noteControllers['treatment']!.text),
        remarks: isEye ? (eyeRemarksCtrl.text.isEmpty ? null : eyeRemarksCtrl.text) : (noteControllers['remarks']?.text.isEmpty ?? true ? null : noteControllers['remarks']!.text),
        consultantNotes: noteControllers['notes']?.text.isEmpty ?? true ? null : noteControllers['notes']!.text,
        referTo: noteControllers['referTo']?.text.isEmpty ?? true ? null : noteControllers['referTo']!.text,
        medicines: _prescribedMedicines,
        investigations: _selectedInvestigations,
        instructions: _instructions,
        diagnosis: _diagnosisAnswers.entries.map((e) {
          final question = _diagnosisQuestions.cast<Map?>().firstWhere(
            (q) => q?['id'] == e.key,
            orElse: () => const {},
          );
          
          final val = e.value;
          final isArray = val is List;

          return PrescriptionDiagnosis(
            questionId: e.key,
            questionText: (question?['question_text'] ?? question?['question'] ?? '').toString(),
            answerText: isArray ? null : val?.toString(),
            answerOptions: isArray ? List<int>.from(val) : null,
          );
        }).where((d) => (d.answerText != null && d.answerText!.isNotEmpty) || (d.answerOptions != null && d.answerOptions!.isNotEmpty)).toList(),
        eyeDetails: isEye ? _buildEyeDetails() : null,
      );

      bool isSuccess = false;
      if (_connectivity.isOnline.value) {
        final payload = prescription.toJson();
        debugPrint('📤 Sending prescription payload: ${jsonEncode(payload)}');
        
        final res = await _apiService.savePrescription(payload);
        debugPrint('📥 Received prescription response: $res');
        
        isSuccess = res['success'] == true ||
            res['status'] == true ||
            res['ok'] == true ||
            (res['message']?.toString().toLowerCase().contains('saved') ?? false);
            
        if (!isSuccess) {
          debugPrint('❌ Prescription save failed on server. Response: $res');
        }
      } else {
        debugPrint('📴 App is OFFLINE. Saving prescription locally.');
        final visitUuid = _syncService.generateUuid();
        final bpParts = (vitalControllers['bp']?.text ?? '').split('/');

        await _db.insert('vitals_local', {
          'device_uuid': _syncService.generateUuid(),
          'patient_uuid': _currentPatient!.deviceUuid ?? _currentPatient!.mrNumber,
          'mr_number': _currentPatient!.mrNumber == 'PENDING' ? null : _currentPatient!.mrNumber,
          'visit_uuid': visitUuid,
          'bsr': double.tryParse(vitalControllers['blood']?.text ?? '0') ?? 0.0,
          'systolic': double.tryParse(bpParts.isNotEmpty ? bpParts.first : '0') ?? 0.0,
          'diastolic': double.tryParse(bpParts.length > 1 ? bpParts.last : '0') ?? 0.0,
          'pulse': double.tryParse(vitalControllers['pulse']?.text ?? '0') ?? 0.0,
          'weight': double.tryParse(vitalControllers['weight']?.text ?? '0') ?? 0.0,
          'temp': double.tryParse(vitalControllers['temp']?.text ?? '0') ?? 0.0,
          'sync_status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
        });

        await _db.insert('prescriptions_local', {
          'device_uuid': _syncService.generateUuid(),
          'patient_uuid': _currentPatient!.deviceUuid ?? _currentPatient!.mrNumber,
          'mr_number': _currentPatient!.mrNumber == 'PENDING' ? null : _currentPatient!.mrNumber,
          'visit_uuid': visitUuid,
          'doctor_srl_no': doctorSrlNo,
          'treatment': prescription.treatment,
          'medicines_json': jsonEncode(prescription.medicines.map((m) => m.toJson()).toList()),
          'investigations_json': jsonEncode(prescription.investigations.map((i) => i.toJson()).toList()),
          'sync_status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
        });

        isSuccess = true;
      }

      if (isSuccess) {
        _lastSavedPrescription = prescription;
        clearForm();
      }
      return isSuccess;
    } catch (e) {
      debugPrint('❌ savePrescription failed: $e');
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<VitalsModel?> saveInlineVitals() async {
    if (_currentPatient == null) {
      debugPrint('⚠️ Cannot save inline vitals: _currentPatient is null');
      return null;
    }

    final hasVitalsInput = ['weight', 'height', 'bp', 'pulse', 'spo2', 'temp', 'blood', 'pain_scale']
        .any((key) => vitalControllers[key]?.text.trim().isNotEmpty == true);

    if (!hasVitalsInput && _currentVitals == null) return null;

    final bpText = vitalControllers['bp']?.text ?? '';
    int? systolic;
    int? diastolic;
    if (bpText.isNotEmpty) {
      final parts = bpText.split('/');
      if (parts.isNotEmpty) systolic = int.tryParse(parts.first.trim());
      if (parts.length > 1) diastolic = int.tryParse(parts[1].trim());
    }

    final weight = double.tryParse(vitalControllers['weight']?.text ?? '');
    final height = double.tryParse(vitalControllers['height']?.text ?? '');
    final heightUnit = _currentVitals?.heightUnit ?? 'in';

    double? bmi;
    if (weight != null && height != null && height > 0) {
      final meters = heightUnit == 'cm' ? height / 100 : height * 0.0254;
      if (meters > 0) {
        bmi = double.parse((weight / (meters * meters)).toStringAsFixed(1));
      }
    }

    final payload = {
      'mr_number': _currentPatient!.mrNumber,
      'receipt_id': _receiptId,
      'weight': weight,
      'height': height,
      'height_unit': heightUnit,
      'bsr': double.tryParse(vitalControllers['blood']?.text ?? '') ?? _currentVitals?.bsr,
      'bmi': bmi ?? _currentVitals?.bmi,
      'bmr': _currentVitals?.bmr,
      'systolic': systolic,
      'diastolic': diastolic,
      'bp_reading_type': (systolic != null && diastolic != null) ? (_currentVitals?.bpReadingType ?? 'regular') : null,
      'pulse': int.tryParse(vitalControllers['pulse']?.text ?? ''),
      'spo2': double.tryParse(vitalControllers['spo2']?.text ?? ''),
      'temperature': double.tryParse(vitalControllers['temp']?.text ?? ''),
      'waist': _currentVitals?.waist,
      'hip': _currentVitals?.hip,
      'whr': _currentVitals?.whr,
      'pain_scale': int.tryParse(vitalControllers['pain_scale']?.text ?? '') ?? _currentVitals?.painScale,
      'remarks': _currentVitals?.remarks,
    };

    try {
      if (_connectivity.isOnline.value) {
        debugPrint('📤 Saving vitals online: $payload');
        final res = await _vitalsApiService.saveVitals(payload);
        if (res['success'] == true && res['data'] != null) {
          _currentVitals = VitalsModel.fromJson(res['data']);
          notifyListeners();
          return _currentVitals;
        } else {
          debugPrint('❌ Online vitals save failed: ${res['message']}');
        }
      } else {
        debugPrint('📴 Saving vitals locally (offline)');
        final visitUuid = _syncService.generateUuid();
        final localData = {
          'device_uuid': _syncService.generateUuid(),
          'patient_uuid': _currentPatient!.deviceUuid ?? _currentPatient!.mrNumber,
          'mr_number': _currentPatient!.mrNumber == 'PENDING' ? null : _currentPatient!.mrNumber,
          'visit_uuid': visitUuid,
          'bsr': double.tryParse(vitalControllers['blood']?.text ?? '') ?? 0.0,
          'systolic': systolic ?? 0.0,
          'diastolic': diastolic ?? 0.0,
          'pulse': int.tryParse(vitalControllers['pulse']?.text ?? '') ?? 0.0,
          'weight': weight ?? 0.0,
          'temp': double.tryParse(vitalControllers['temp']?.text ?? '') ?? 0.0,
          'sync_status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
        };
        await _db.insert('vitals_local', localData);

        final normalized = Map<String, dynamic>.from(localData);
        normalized['temperature'] = normalized['temp'];
        normalized['receipt_id'] = _receiptId;
        _currentVitals = VitalsModel.fromJson(normalized);
        notifyListeners();
        return _currentVitals;
      }
    } catch (e) {
      debugPrint('❌ Error in saveInlineVitals: $e');
    }
    return null;
  }


  void updateSurgerySearch(String query) {
    if (query.isEmpty) {
      _surgerySearchResults = [];
    } else {
      _surgerySearchResults = eyeSetupSurgery
          .where((s) => s.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
    notifyListeners();
  }

  EyePrescriptionDetails _buildEyeDetails() {
    return EyePrescriptionDetails(
      history: Map<String, bool>.from(eyeHistory),
      otherHistory: eyeOtherHistoryCtrl.text,
      rightRefraction: _getRefraction('right'),
      leftRefraction: _getRefraction('left'),
      add01Refraction: _getRefraction('add01'),
      add02Refraction: _getRefraction('add02'),
      rightVision: _getVision('right'),
      leftVision: _getVision('left'),
      presentingComplaints: presentingComplaintsCtrl.text,
      complaints: _eyeComplaints,
      examinations: _eyeExaminations,
      diagnosis: _eyeDiagnosis,
      advised: _eyeAdvised,
      treatmentType: _eyeTreatmentType,
      remarks: eyeRemarksCtrl.text,
      operationDate: _eyeOperationDate?.toString().split(' ')[0],
      surgeryName: eyeSurgeryNameCtrl.text.isEmpty ? null : eyeSurgeryNameCtrl.text,
    );
  }

  RefractionMatrix _getRefraction(String side) {
    final ctrls = refractionCtrls[side]!;
    return RefractionMatrix(
      sph: ctrls['sph']!.text,
      cyl: ctrls['cyl']!.text,
      axis: ctrls['axis']!.text,
      va: ctrls['va']!.text,
      addition: ctrls['addition']!.text,
    );
  }

  VisionStats _getVision(String side) {
    final ctrls = visionCtrls[side]!;
    return VisionStats(
      varValue: ctrls['var']!.text,
      ph: ctrls['ph']!.text,
      ref: ctrls['ref']!.text,
    );
  }

  Future<bool> summarizeVisitsWithAI(String patientName) async {
    if (_prescriptionHistory.isEmpty) return false;
    _analyzingVisits = true;
    notifyListeners();
    try {
      final records = _prescriptionHistory.map((visit) => {
        'date': visit.createdAt,
        'doctor': visit.doctorName,
        'vitals': visit.vitals,
        'history_examination': visit.historyExamination,
        'treatment': visit.treatment,
        'consultant_notes': visit.consultantNotes,
        'remarks': visit.remarks,
        'diagnosis': visit.diagnosis.map((ans) => {
          'question': ans.questionText,
          'answer': ans.answerDisplay ?? ans.answerText ?? (ans.answerOptions?.join(', ') ?? '—'),
        }).toList(),
        'investigations': visit.investigations.map((i) => '${i.investigationType}: ${i.testName}').toList(),
        'medicines': visit.medicines.map((m) => m.medicineName).toList(),
      }).toList();

      final res = await _aiApiService.summarizePatientHistory(records, patientName);
      if (res['success'] == true) {
        _visitAnalysis = res['summary'] ?? '';
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error summarizing visits: $e');
      return false;
    } finally {
      _analyzingVisits = false;
      notifyListeners();
    }
  }

  void clearForm() {
    for (var c in vitalControllers.values) c.clear();
    for (var c in noteControllers.values) c.clear();
    _prescribedMedicines = [];
    _selectedInvestigations = [];
    _instructions = [];
    _diagnosisAnswers = {};
    _currentPatient = null;
    _currentVitals = null;
    _receiptId = null;
    _tokenNumber = null;
    _doctorName = null;
    _doctorSrlNo = null;
    _medMode = 'medicine';
    _medicineSearchResults = [];
    _medSearchQuery = '';
    _mrSearchValue = null;
    _eyeComplaints = [];
    _eyeExaminations = [];
    _eyeDiagnosis = [];
    _eyeAdvised = [];
    _eyeTreatmentType = '';
    _eyeOperationDate = null;
    eyeOtherHistoryCtrl.clear();
    presentingComplaintsCtrl.clear();
    eyeRemarksCtrl.clear();
    for (var side in refractionCtrls.values) {
      for (var ctrl in side.values) ctrl.clear();
    }
    for (var side in visionCtrls.values) {
      for (var ctrl in side.values) ctrl.clear();
    }
    notifyListeners();
  }

  String _normalizeMrNumber(String input) {
    String trimmed = input.trim();
    if (trimmed.isEmpty) return "";
    if (RegExp(r'^\d+$').hasMatch(trimmed)) {
      return trimmed.padLeft(5, '0');
    }
    return trimmed;
  }

  Future<String?> getMrPrefix() async {
    try {
      final db = await _db.database;
      final config = await db.query('camp_config', limit: 1);
      if (config.isNotEmpty) {
        return config.first['mr_prefix']?.toString();
      }
    } catch (e) {
      debugPrint('Error getting MR prefix: $e');
    }
    return null;
  }

  Future<void> prefillMrPrefix() async {
    if (_currentPatient != null) return;
    final prefix = await getMrPrefix();
    if (prefix != null && prefix.isNotEmpty) {
      _mrSearchValue = '$prefix-';
      notifyListeners();
    }
  }
}
