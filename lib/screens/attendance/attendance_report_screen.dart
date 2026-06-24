import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../custum widgets/drawer/base_scaffold.dart';
import '../../providers/attendance_provider/attendance_provider.dart';
import '../../custum widgets/custom_loader.dart';

class AttendanceReportScreen extends StatefulWidget {
  const AttendanceReportScreen({super.key});

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  static const Color _teal = Color(0xFF00B5AD);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AttendanceProvider>();
      provider.fetchAttendanceReport(provider.selectedReportDate);
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final provider = context.read<AttendanceProvider>();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: provider.selectedReportDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _teal,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      provider.setReportDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    final double hp = (sw * 0.04).clamp(12.0, 24.0);
    final double vp = (sh * 0.02).clamp(8.0, 16.0);

    final report = provider.report;
    final overview = report.overview;
    final userList = report.data;

    return BaseScaffold(
      title: 'Attendance Report',
      drawerIndex: 25,
      showNotificationIcon: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: () => provider.fetchAttendanceReport(provider.selectedReportDate),
        ),
      ],
      body: Container(
        color: const Color(0xFFF4F6F9),
        child: provider.isLoading && userList.isEmpty
            ? const Center(child: CustomLoader(size: 50, color: _teal))
            : RefreshIndicator(
                color: _teal,
                onRefresh: () => provider.fetchAttendanceReport(provider.selectedReportDate),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: hp, vertical: vp),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── Date Picker Filter Section ───────────────────────
                      GestureDetector(
                        onTap: () => _selectDate(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.calendar_month_rounded, color: _teal, size: 20),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'REPORT DATE',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.8,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        DateFormat('EEEE, d MMMM yyyy').format(provider.selectedReportDate),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2C3E50),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _teal.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.edit_calendar_rounded, color: _teal, size: 18),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ─── Overview Stats Cards ────────────────────────────
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 350;
                          final cards = [
                            _buildStatCard(
                              title: 'TOTAL USERS',
                              value: overview.totalUsers.toString(),
                              icon: Icons.people_outline_rounded,
                              color: Colors.indigo,
                            ),
                            _buildStatCard(
                              title: 'PRESENT',
                              value: overview.present.toString(),
                              icon: Icons.check_circle_outline,
                              color: Colors.green,
                            ),
                            _buildStatCard(
                              title: 'ABSENT',
                              value: overview.absent.toString(),
                              icon: Icons.cancel_outlined,
                              color: Colors.red,
                            ),
                          ];

                          if (isNarrow) {
                            return Column(
                              children: [
                                cards[0],
                                const SizedBox(height: 12),
                                cards[1],
                                const SizedBox(height: 12),
                                cards[2],
                              ],
                            );
                          }

                          return Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: cards[0]),
                                  const SizedBox(width: 12),
                                  Expanded(child: cards[1]),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(child: cards[2]),
                                  const SizedBox(width: 12),
                                  const Expanded(child: SizedBox()),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // ─── Error message ───────────────────────────────────
                      if (provider.errorMessage != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF5F5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Text(
                            provider.errorMessage!,
                            style: const TextStyle(color: Colors.red, fontSize: 13),
                          ),
                        ),

                      // ─── Detailed User Report Table / List ───────────────
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
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Staff Records',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                            ),
                            const Divider(height: 1),
                            if (provider.isLoading && userList.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(32.0),
                                child: Center(child: CustomLoader(size: 30, color: _teal)),
                              )
                            else if (userList.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(32.0),
                                child: Center(
                                  child: Text(
                                    'No records found for this date.',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: userList.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final user = userList[index];
                                  final isEven = index % 2 == 0;
                                  return Container(
                                    color: isEven ? Colors.white : const Color(0xFFFAFAFA),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Row(
                                      children: [
                                        // User Info
                                        Expanded(
                                          flex: 4,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                user.fullName,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '@${user.username}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Timings (Check-in/Check-out)
                                        Expanded(
                                          flex: 4,
                                          child: Row(
                                            children: [
                                              _buildTimeLabel(report.date, user.timeIn, true),
                                              const SizedBox(width: 8),
                                              _buildTimeLabel(report.date, user.timeOut, false),
                                            ],
                                          ),
                                        ),
                                        // Status Chip
                                        Expanded(
                                          flex: 2,
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: _buildStatusChip(user.status ?? 'Absent'),
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

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeLabel(String? date, String? time, bool isTimeIn) {
    final bool hasTime = time != null && time.isNotEmpty;
    final Color color = isTimeIn ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: hasTime ? color.withOpacity(0.08) : Colors.grey.withOpacity(0.06),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        hasTime ? _formatTimeInLocal(date, time) : '--:--',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: hasTime ? color : Colors.grey,
        ),
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
    // DB now stores local time directly — no UTC conversion needed.
    return _formatTime(timeStr);
  }
}
