import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../custum widgets/drawer/base_scaffold.dart';
import '../../models/attendance_model/attendance_model.dart';
import '../../providers/attendance_provider/attendance_provider.dart';
import '../../custum widgets/custom_loader.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late Timer _timer;
  String _currentTime = '';
  String _currentDate = '';
  static const Color _teal = Color(0xFF00B5AD);

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) => _updateTime());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AttendanceProvider>().fetchMyRecords();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    final timeStr = DateFormat('hh:mm:ss a').format(now);
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(now);
    if (mounted) {
      setState(() {
        _currentTime = timeStr;
        _currentDate = dateStr;
      });
    }
  }

  Future<void> _handleCheckIn(BuildContext context) async {
    final provider = context.read<AttendanceProvider>();
    final result = await provider.checkIn();

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(result.success ? Icons.check_circle : Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(result.message)),
          ],
        ),
        backgroundColor: result.success ? _teal : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _handleCheckOut(BuildContext context) async {
    final provider = context.read<AttendanceProvider>();
    final result = await provider.checkOut();

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(result.success ? Icons.check_circle : Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(result.message)),
          ],
        ),
        backgroundColor: result.success ? _teal : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    final today = provider.todayRecord;
    final bool hasCheckedIn = today?.timeIn != null;
    final bool hasCheckedOut = today?.timeOut != null;

    final double hp = (sw * 0.04).clamp(12.0, 24.0);
    final double vp = (sh * 0.02).clamp(8.0, 16.0);

    return BaseScaffold(
      title: 'Mark Attendance',
      drawerIndex: 24,
      showNotificationIcon: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: () => provider.fetchMyRecords(),
        ),
      ],
      body: Container(
        color: const Color(0xFFF4F6F9),
        child: provider.isLoading && provider.myRecords.isEmpty
            ? const Center(child: CustomLoader(size: 50, color: _teal))
            : RefreshIndicator(
          color: _teal,
          onRefresh: () => provider.fetchMyRecords(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: hp, vertical: vp),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Clock Card (compact horizontal) ─────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_teal, Color(0xFF009C96)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _teal.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.access_time_filled_rounded,
                        color: Colors.white70,
                        size: 26,
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentTime,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _currentDate,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ─── Action Cards (always row) ────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        context: context,
                        title: 'Time In',
                        subtitle: hasCheckedIn
                            ? 'Checked in at ${(today != null ? provider.getRecordLocalTimeIn(today) : null) ?? _formatTimeInLocal(today?.attendanceDate, today?.timeIn)}'
                            : 'Start your shift',
                        icon: Icons.login_rounded,
                        color: Colors.green,
                        isDisabled: hasCheckedIn || provider.isLoading,
                        onTap: () => _handleCheckIn(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        context: context,
                        title: 'Time Out',
                        subtitle: hasCheckedOut
                            ? 'Checked out at ${(today != null ? provider.getRecordLocalTimeOut(today) : null) ?? _formatTimeInLocal(today?.attendanceDate, today?.timeOut)}'
                            : (!hasCheckedIn ? 'Time in first' : 'End your shift'),
                        icon: Icons.logout_rounded,
                        color: Colors.orange,
                        isDisabled: !hasCheckedIn || provider.isLoading,
                        onTap: () => _handleCheckOut(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ─── Attendance Status Banner ────────────────────────
                if (today != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _teal.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.info_outline, color: _teal, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Today\'s Status',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Status: ${today.status} · Time-in: ${provider.getRecordLocalTimeIn(today) ?? _formatTimeInLocal(today.attendanceDate, today.timeIn)} · Time-out: ${provider.getRecordLocalTimeOut(today) ?? _formatTimeInLocal(today.attendanceDate, today.timeOut)}',
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // ─── Attendance History Card ─────────────────────────
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Attendance History',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                            if (provider.myRecords.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _teal.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${provider.myRecords.length} Records',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _teal,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      if (provider.isLoading && provider.myRecords.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(child: CustomLoader(size: 30, color: _teal)),
                        )
                      else if (provider.myRecords.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(
                            child: Text(
                              'No records found.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: provider.myRecords.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final record = provider.myRecords[index];
                            final isEven = index % 2 == 0;
                            return Container(
                              color: isEven ? Colors.white : const Color(0xFFFAFAFA),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  // Date Column
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _formatRecordDateInLocal(record.attendanceDate, record.timeIn),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formatRecordFullDateInLocal(record.attendanceDate, record.timeIn),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Timings Column
                                  Expanded(
                                    flex: 4,
                                    child: Row(
                                      children: [
                                        _buildTimeBadge(record, true),
                                        const SizedBox(width: 8),
                                        _buildTimeBadge(record, false),
                                      ],
                                    ),
                                  ),
                                  // Status Column
                                  Expanded(
                                    flex: 2,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: _buildStatusChip(record.status),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDisabled,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Opacity(
            opacity: isDisabled ? 0.5 : 1.0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeBadge(AttendanceRecord record, bool isTimeIn) {
    final String? time = isTimeIn ? record.timeIn : record.timeOut;
    final bool hasTime = time != null && time.isNotEmpty;
    final Color badgeColor = isTimeIn ? Colors.green : Colors.orange;

    final provider = context.read<AttendanceProvider>();
    final String? cachedTime = isTimeIn
        ? provider.getRecordLocalTimeIn(record)
        : provider.getRecordLocalTimeOut(record);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: hasTime ? badgeColor.withOpacity(0.08) : Colors.grey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: hasTime ? badgeColor.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isTimeIn ? Icons.login_rounded : Icons.logout_rounded,
            size: 11,
            color: hasTime ? badgeColor : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            hasTime ? (cachedTime ?? _formatTimeInLocal(record.attendanceDate, time)) : '--:--',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: hasTime ? badgeColor : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final isPresent = status.toLowerCase() == 'present';
    final chipColor = isPresent ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: chipColor,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _formatTime(String timeStr) {
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

  String _formatTimeInLocal(String? dateStr, String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '--:--';
    // DB stores local time directly — no UTC conversion needed.
    return _formatTime(timeStr);
  }

  String _formatRecordDateInLocal(String dateStr, String? timeStr) {
    try {
      final cleanDate = dateStr.contains('T') ? dateStr.split('T')[0] : dateStr;
      final parsed = DateTime.parse(cleanDate);
      return DateFormat('EEE, MMM dd').format(parsed);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatRecordFullDateInLocal(String dateStr, String? timeStr) {
    try {
      final cleanDate = dateStr.contains('T') ? dateStr.split('T')[0] : dateStr;
      final parsed = DateTime.parse(cleanDate);
      return DateFormat('yyyy-MM-dd').format(parsed);
    } catch (_) {
      return dateStr;
    }
  }
}