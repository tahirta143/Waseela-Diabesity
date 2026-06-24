import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/attendance_api_service.dart';
import '../../core/services/auth_storage_service.dart';
import '../../models/attendance_model/attendance_model.dart';

class AttendanceProvider extends ChangeNotifier {
  final AttendanceApiService _apiService = AttendanceApiService();
  final AuthStorageService _authStorage = AuthStorageService();

  // Cache for local device clocking times
  final Map<String, String> _localTimeInMap = {};
  final Map<String, String> _localTimeOutMap = {};

  String? getLocalTimeIn(String date) => _localTimeInMap[date];
  String? getLocalTimeOut(String date) => _localTimeOutMap[date];

  String _getLocalDateKey(AttendanceRecord r) {
    // DB stores local date directly — use attendanceDate as the key.
    final cleanDate = r.attendanceDate.contains('T') ? r.attendanceDate.split('T')[0] : r.attendanceDate;
    return cleanDate;
  }

  String _toLocalTime(String? dateStr, String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '--:--';
    // DB stores local time directly — just format for display.
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        final period = hours >= 12 ? 'PM' : 'AM';
        final displayHours = hours % 12 == 0 ? 12 : hours % 12;
        return '$displayHours:${minutes.toString().padLeft(2, '0')} $period';
      }
      return timeStr;
    } catch (_) {
      return timeStr;
    }
  }

  String? getRecordLocalTimeIn(AttendanceRecord r) => _localTimeInMap[_getLocalDateKey(r)];
  String? getRecordLocalTimeOut(AttendanceRecord r) => _localTimeOutMap[_getLocalDateKey(r)];

  bool _isLoading = false;
  String? _errorMessage;

  // Local user's records
  List<AttendanceRecord> _myRecords = [];

  // Report records
  AttendanceReport _report = AttendanceReport.empty();
  DateTime _selectedReportDate = DateTime.now();

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<AttendanceRecord> get myRecords => _myRecords;
  AttendanceReport get report => _report;
  DateTime get selectedReportDate => _selectedReportDate;

  AttendanceRecord? get todayRecord {
    if (_myRecords.isEmpty) return null;
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    for (final r in _myRecords) {
      // DB stores local date directly — compare attendanceDate with today directly.
      final cleanDate = r.attendanceDate.contains('T') ? r.attendanceDate.split('T')[0] : r.attendanceDate;
      if (cleanDate == todayStr) return r;
    }
    return null;
  }

  // Fetch my records
  Future<void> fetchMyRecords() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _apiService.getMyRecords();
      if (res['success'] == true) {
        final list = res['data'] as List? ?? [];
        _myRecords = list.map((e) => AttendanceRecord.fromJson(e)).toList();

        debugPrint('--- RETRIEVED ATTENDANCE RECORDS FROM DATABASE ---');
        for (final r in _myRecords) {
          final localIn = _toLocalTime(r.attendanceDate, r.timeIn);
          final localOut = _toLocalTime(r.attendanceDate, r.timeOut);
          debugPrint('Date: ${r.attendanceDate} | Time In (DB Raw): ${r.timeIn} (Local: $localIn) | Time Out (DB Raw): ${r.timeOut} (Local: $localOut) | Status: ${r.status}');
        }
        
        // Cache local check-in/out times from persistent storage
        for (final r in _myRecords) {
          final localKey = _getLocalDateKey(r);
          final savedIn = await _authStorage.getLocalTimeIn(localKey);
          if (savedIn != null) {
            _localTimeInMap[localKey] = savedIn;
          }
          final savedOut = await _authStorage.getLocalTimeOut(localKey);
          if (savedOut != null) {
            _localTimeOutMap[localKey] = savedOut;
          }
        }
      } else {
        _errorMessage = res['message'] ?? 'Failed to load attendance records';
      }
    } catch (e) {
      _errorMessage = 'An error occurred: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Check-In
  Future<({bool success, String message})> checkIn() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      final timeStr = DateFormat('HH:mm:ss').format(DateTime.now());
      
      final res = await _apiService.timeIn(date: todayStr, time: timeStr);
      if (res['success'] == true) {
        // Save the exact device time when checked in
        final nowStr = DateFormat('hh:mm a').format(DateTime.now());
        _localTimeInMap[todayStr] = nowStr;
        await _authStorage.saveLocalTimeIn(todayStr, nowStr);

        debugPrint('--- CLOCKED IN DEVICE LOCAL ---');
        debugPrint('Date: $todayStr | Local Time: $nowStr');

        await fetchMyRecords(); // refresh records
        return (success: true, message: (res['message'] ?? 'Time-in recorded').toString());
      } else {
        return (success: false, message: (res['message'] ?? 'Failed to check in').toString());
      }
    } catch (e) {
      return (success: false, message: 'An error occurred: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Check-Out
  Future<({bool success, String message})> checkOut() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      final timeStr = DateFormat('HH:mm:ss').format(DateTime.now());

      final res = await _apiService.timeOut(date: todayStr, time: timeStr);
      if (res['success'] == true) {
        // Save the exact device time when checked out
        final nowStr = DateFormat('hh:mm a').format(DateTime.now());
        _localTimeOutMap[todayStr] = nowStr;
        await _authStorage.saveLocalTimeOut(todayStr, nowStr);

        debugPrint('--- CLOCKED OUT DEVICE LOCAL ---');
        debugPrint('Date: $todayStr | Local Time: $nowStr');

        await fetchMyRecords(); // refresh records
        return (success: true, message: (res['message'] ?? 'Time-out recorded').toString());
      } else {
        return (success: false, message: (res['message'] ?? 'Failed to check out').toString());
      }
    } catch (e) {
      return (success: false, message: 'An error occurred: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch report
  Future<void> fetchAttendanceReport(DateTime date) async {
    _selectedReportDate = date;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    try {
      final res = await _apiService.getAttendanceReport(dateStr);
      if (res['success'] == true) {
        _report = AttendanceReport.fromJson(res);
      } else {
        _errorMessage = res['message'] ?? 'Failed to load attendance report';
      }
    } catch (e) {
      _errorMessage = 'An error occurred: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setReportDate(DateTime date) {
    _selectedReportDate = date;
    fetchAttendanceReport(date);
  }
}
