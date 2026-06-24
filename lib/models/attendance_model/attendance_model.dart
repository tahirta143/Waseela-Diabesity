class AttendanceRecord {
  final int id;
  final int userId;
  final String attendanceDate;
  final String? timeIn;
  final String? timeOut;
  final String status;

  AttendanceRecord({
    required this.id,
    required this.userId,
    required this.attendanceDate,
    this.timeIn,
    this.timeOut,
    required this.status,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    String rawDate = json['attendance_date'] ?? '';
    if (rawDate.contains('T')) {
      rawDate = rawDate.split('T')[0];
    }
    return AttendanceRecord(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      attendanceDate: rawDate,
      timeIn: json['time_in'],
      timeOut: json['time_out'],
      status: json['status'] ?? 'Absent',
    );
  }
}

class AttendanceReportOverview {
  final int totalUsers;
  final int present;
  final int absent;

  AttendanceReportOverview({
    required this.totalUsers,
    required this.present,
    required this.absent,
  });

  factory AttendanceReportOverview.fromJson(Map<String, dynamic> json) {
    return AttendanceReportOverview(
      totalUsers: json['totalUsers'] ?? 0,
      present: json['present'] ?? 0,
      absent: json['absent'] ?? 0,
    );
  }

  factory AttendanceReportOverview.empty() {
    return AttendanceReportOverview(totalUsers: 0, present: 0, absent: 0);
  }
}

class AttendanceReportUser {
  final int id;
  final String fullName;
  final String username;
  final String? timeIn;
  final String? timeOut;
  final String? status;

  AttendanceReportUser({
    required this.id,
    required this.fullName,
    required this.username,
    this.timeIn,
    this.timeOut,
    this.status,
  });

  factory AttendanceReportUser.fromJson(Map<String, dynamic> json) {
    return AttendanceReportUser(
      id: json['id'] ?? 0,
      fullName: json['full_name'] ?? '',
      username: json['username'] ?? '',
      timeIn: json['time_in'],
      timeOut: json['time_out'],
      status: json['status'],
    );
  }
}

class AttendanceReport {
  final String date;
  final AttendanceReportOverview overview;
  final List<AttendanceReportUser> data;

  AttendanceReport({
    required this.date,
    required this.overview,
    required this.data,
  });

  factory AttendanceReport.fromJson(Map<String, dynamic> json) {
    final overviewJson = json['overview'] as Map<String, dynamic>? ?? {};
    final dataList = json['data'] as List? ?? [];
    String rawDate = json['date'] ?? '';
    if (rawDate.contains('T')) {
      rawDate = rawDate.split('T')[0];
    }
    return AttendanceReport(
      date: rawDate,
      overview: AttendanceReportOverview.fromJson(overviewJson),
      data: dataList.map((e) => AttendanceReportUser.fromJson(e)).toList(),
    );
  }

  factory AttendanceReport.empty() {
    return AttendanceReport(
      date: '',
      overview: AttendanceReportOverview.empty(),
      data: [],
    );
  }
}
