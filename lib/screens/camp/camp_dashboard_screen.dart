import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../custum widgets/drawer/base_scaffold.dart';
import '../../custum widgets/custom_loader.dart';
import '../../core/providers/permission_provider.dart';
import '../../core/permissions/permission_keys.dart';
import '../../core/services/camp_sync_service.dart';



// ─── Constants ────────────────────────────────────────────────────────────────
const _teal = Color(0xFF00B5AD);
const _tealLight = Color(0xFFE6F7F6);
const _bg = Color(0xFFF4F7FA);
const _border = Color(0xFFE2E8F0);
const _textDark = Color(0xFF1A202C);
const _textLight = Color(0xFF718096);

const _daysOfWeek = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
];
const _dayAbbr = {
  'Monday': 'Mon', 'Tuesday': 'Tue', 'Wednesday': 'Wed',
  'Thursday': 'Thu', 'Friday': 'Fri', 'Saturday': 'Sat', 'Sunday': 'Sun',
};
const _dayColors = {
  'Monday':    [Color(0xFFDBEAFE), Color(0xFF1D4ED8)],
  'Tuesday':   [Color(0xFFD1FAE5), Color(0xFF065F46)],
  'Wednesday': [Color(0xFFEDE9FE), Color(0xFF5B21B6)],
  'Thursday':  [Color(0xFFFEF3C7), Color(0xFF92400E)],
  'Friday':    [Color(0xFFFFE4E6), Color(0xFF9F1239)],
  'Saturday':  [Color(0xFFCFFAFE), Color(0xFF155E75)],
  'Sunday':    [Color(0xFFFFEDD5), Color(0xFF9A3412)],
};

// ─── Screen wrapper ───────────────────────────────────────────────────────────
class CampDashboardScreen extends StatelessWidget {
  const CampDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'Camp Sessions',
      drawerIndex: 102,
      body: Consumer<PermissionProvider>(
        builder: (context, perm, _) {
          if (!perm.can(Perm.campDashboardRead)) {
            return const Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.lock_outline, size: 64, color: Color(0xFFCBD5E0)),
                SizedBox(height: 16),
                Text('Access Denied', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('You do not have permission to view Camp Sessions.', style: TextStyle(color: Color(0xFF718096))),
              ]),
            );
          }
          return const _CampDashboardBody();
        },
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────
class _CampDashboardBody extends StatefulWidget {
  const _CampDashboardBody();
  @override
  State<_CampDashboardBody> createState() => _CampDashboardBodyState();
}

class _CampDashboardBodyState extends State<_CampDashboardBody> {
  final _sync = CampSyncService();
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _overview = {'totalCamps': 0, 'totalPatients': 0, 'totalPrescriptions': 0};
  List<Map<String, dynamic>> _camps = [];
  String _search = '';

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() { _loading = true; _error = null; });
    final result = await _sync.getCampStats();
    if (!mounted) return;
    if (result['success'] == true) {
      final data = result['data'] as Map<String, dynamic>? ?? {};
      setState(() {
        _overview = (data['overview'] as Map<String, dynamic>?) ?? _overview;
        _camps = List<Map<String, dynamic>>.from(
          (data['camps'] as List?)?.map((c) => Map<String, dynamic>.from(c as Map)) ?? [],
        );
        _loading = false;
      });
    } else {
      setState(() { _error = result['message']?.toString() ?? 'Failed to load'; _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _camps;
    final q = _search.toLowerCase();
    return _camps.where((c) =>
      (c['name'] ?? '').toString().toLowerCase().contains(q) ||
      (c['location'] ?? '').toString().toLowerCase().contains(q)
    ).toList();
  }

  Future<void> _delete(Map<String, dynamic> camp) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Camp'),
        content: Text('Delete "${camp['name']}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await _sync.deleteCamp(camp['id'].toString());
    if (!mounted) return;
    if (result['success'] == true) {
      _fetchStats();
    } else {
      setState(() => _error = result['message']?.toString() ?? 'Delete failed');
    }
  }

  void _openForm({Map<String, dynamic>? camp}) {
    showDialog(
      context: context,
      builder: (_) => _CampFormDialog(
        existing: camp,
        onSaved: _fetchStats,
      ),
    );
  }

  void _openTeamsConfig() {
    showDialog(
      context: context,
      builder: (_) => _TeamsConfigDialog(
        camps: _camps,
        onSaved: _fetchStats,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final perm = context.watch<PermissionProvider>();
    final canCreate = perm.can(Perm.campSessionCreate);
    final canUpdate = perm.can(Perm.campSessionUpdate);
    final canDelete = perm.can(Perm.campDashboardDelete);
    final isWide = MediaQuery.of(context).size.width > 820;
    final isMedium = MediaQuery.of(context).size.width > 600;
    final hPad = isWide ? 24.0 : 16.0;

    return Scaffold(
      backgroundColor: _bg,
      body: RefreshIndicator(
        color: _teal,
        onRefresh: _fetchStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 100),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Header ──────────────────────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Camp Sessions',
                              style: TextStyle(fontSize: isWide ? 26 : 22, fontWeight: FontWeight.bold, color: _textDark)),
                          const Text('Medical Camp Statistics & Patient Overview',
                              style: TextStyle(fontSize: 12, color: _textLight)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _loading ? null : _fetchStats,
                      icon: _loading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _teal))
                          : const Icon(Icons.refresh_rounded, color: _teal),
                    ),
                  ],
                ),
                if (canCreate) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _openTeamsConfig,
                        icon: const Icon(Icons.groups_2_outlined, size: 16, color: _teal),
                        label: const Text('Configure Teams', style: TextStyle(fontSize: 12, color: _teal)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _teal),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _openForm(),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Camp', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _teal, foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // ── Error ────────────────────────────────────────────────────────
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFFFF5F5), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFEB2B2))),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: Color(0xFFE53E3E), size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFE53E3E), fontSize: 12))),
                ]),
              ),

            // ── Stat Cards ───────────────────────────────────────────────────
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: _StatCard(title: 'Total Camps', value: '${_overview['totalCamps'] ?? 0}', icon: Icons.festival_outlined, color: _teal)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(title: 'Patients', value: '${_overview['totalPatients'] ?? 0}', icon: Icons.people_outline, color: const Color(0xFF38A169))),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(title: 'Prescriptions', value: '${_overview['totalPrescriptions'] ?? 0}', icon: Icons.description_outlined, color: const Color(0xFF00B5AD))),
              ]),
            ),
            const SizedBox(height: 20),

            // ── Search ───────────────────────────────────────────────────────
            TextField(
              onChanged: (v) => setState(() => _search = v),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search camps...',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFBDBDBD)),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFFBDBDBD)),
                filled: true, fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _teal, width: 1.5)),
              ),
            ),
            const SizedBox(height: 12),

            // ── Camp List ────────────────────────────────────────────────────
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CustomLoader(size: 40, color: _teal)))
            else if (_filtered.isEmpty)
              Center(child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(children: [
                  const Icon(Icons.festival_outlined, size: 48, color: _border),
                  const SizedBox(height: 12),
                  Text(_search.isEmpty ? 'No camps found.' : 'No camps match "$_search".',
                      style: const TextStyle(color: _textLight, fontSize: 13)),
                ]),
              ))
            else if (isMedium)
              // ── Wide/Medium: 2-column grid ──────────────────────────────
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isWide ? 3 : 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: isWide ? 1.15 : 0.95,
                ),
                itemCount: _filtered.length,
                itemBuilder: (_, i) => _CampCard(
                  camp: _filtered[i],
                  canUpdate: canUpdate,
                  canDelete: canDelete,
                  onEdit: () => _openForm(camp: _filtered[i]),
                  onDelete: () => _delete(_filtered[i]),
                ),
              )
            else
              // ── Mobile: single column list ──────────────────────────────
              ...(_filtered.map((camp) => _CampCard(
                camp: camp,
                canUpdate: canUpdate,
                canDelete: canDelete,
                onEdit: () => _openForm(camp: camp),
                onDelete: () => _delete(camp),
              ))),
          ]),
        ),
      ),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDF2F7)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: const Color(0xFFE6F7F6), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 18, color: const Color(0xFF00B5AD)),
        ),
        const SizedBox(height: 10),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF718096), fontWeight: FontWeight.w400)),
      ]),
    );
  }
}

// ─── Camp Card ────────────────────────────────────────────────────────────────
class _CampCard extends StatelessWidget {
  final Map<String, dynamic> camp;
  final bool canUpdate, canDelete;
  final VoidCallback onEdit, onDelete;
  const _CampCard({required this.camp, required this.canUpdate, required this.canDelete, required this.onEdit, required this.onDelete});

  List<String> get _days {
    final raw = camp['days']?.toString() ?? '';
    if (raw.isEmpty) return [];
    return raw.split(',').map((d) => d.trim()).where((d) => d.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final status = (camp['status'] ?? 'active').toString();
    final isActive = status == 'active';
    final days = _days;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDF2F7)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Stack(children: [
        // Top-right: status badge + actions
        Positioned(
          top: 0, right: 0,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFE6F7F6) : const Color(0xFFF7FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isActive ? const Color(0xFF00B5AD) : const Color(0xFFE2E8F0)),
              ),
              child: Text(status.toUpperCase(),
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold,
                      color: isActive ? const Color(0xFF00B5AD) : const Color(0xFF718096))),
            ),
            if (canUpdate) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: const Color(0xFFE6F7F6), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF00B5AD)),
                ),
              ),
            ],
            if (canDelete) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: const Color(0xFFFFF5F5), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFE53E3E)),
                ),
              ),
            ],
          ]),
        ),

        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Icon + name
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: const Color(0xFFE6F7F6), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.festival_outlined, size: 18, color: Color(0xFF00B5AD)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                camp['name']?.toString() ?? '',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF2D3748), height: 1.2),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if ((camp['location'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.location_on_outlined, size: 11, color: Color(0xFF718096)),
                  const SizedBox(width: 2),
                  Expanded(child: Text(camp['location'].toString(),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF718096)),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              ],
            ])),
            // space for the action buttons above
            const SizedBox(width: 80),
          ]),

          const SizedBox(height: 12),

          // Days chips
          if (days.isEmpty)
            const Text('Every day', style: TextStyle(fontSize: 11, color: Color(0xFF718096), fontStyle: FontStyle.italic))
          else
            Wrap(spacing: 4, runSpacing: 4, children: days.map((day) {
              final colors = _dayColors[day] ?? [const Color(0xFFF7FAFC), const Color(0xFF718096)];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: colors[0], borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors[1].withValues(alpha: 0.4)),
                ),
                child: Text(_dayAbbr[day] ?? day,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: colors[1])),
              );
            }).toList()),

          const SizedBox(height: 10),

          // Stats row
          Row(children: [
            _statBadge('${camp['total_patients'] ?? 0}', 'Patients', const Color(0xFF38A169), const Color(0xFFF0FFF4)),
            const SizedBox(width: 8),
            _statBadge('${camp['total_prescriptions'] ?? 0}', 'Rx', const Color(0xFF805AD5), const Color(0xFFFAF5FF)),
            const Spacer(),
            const Icon(Icons.north_east_rounded, size: 12, color: Color(0xFFE2E8F0)),
          ]),
        ]),
      ]),
    );
  }

  Widget _statBadge(String value, String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: fg.withValues(alpha: 0.3))),
      child: Text('$value $label', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

// ─── Day Selector ─────────────────────────────────────────────────────────────
class _DaySelector extends StatelessWidget {
  final List<String> selected;
  final ValueChanged<List<String>> onChange;
  const _DaySelector({required this.selected, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 6, runSpacing: 6, children: _daysOfWeek.map((day) {
      final isSelected = selected.contains(day);
      return GestureDetector(
        onTap: () {
          final updated = List<String>.from(selected);
          if (isSelected) { updated.remove(day); } else { updated.add(day); }
          onChange(updated);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? _teal : const Color(0xFFF7FAFC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? _teal : _border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (isSelected) ...[
              const Icon(Icons.check, size: 11, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(_dayAbbr[day] ?? day, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : _textLight)),
          ]),
        ),
      );
    }).toList());
  }
}

// ─── Create / Edit Dialog ─────────────────────────────────────────────────────
class _CampFormDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;
  const _CampFormDialog({this.existing, required this.onSaved});

  @override
  State<_CampFormDialog> createState() => _CampFormDialogState();
}

class _CampFormDialogState extends State<_CampFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _locCtrl = TextEditingController();
  List<String> _selectedDays = [];
  bool _submitting = false;
  String? _error;

  List<Map<String, dynamic>> _allTeams = [];
  List<String> _assignedTeamNames = [];
  bool _loadingTeams = true;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _nameCtrl.text = widget.existing!['name']?.toString() ?? '';
      _locCtrl.text = widget.existing!['location']?.toString() ?? '';
      final raw = widget.existing!['days']?.toString() ?? '';
      _selectedDays = raw.isEmpty ? [] : raw.split(',').map((d) => d.trim()).where((d) => d.isNotEmpty).toList();
    }
    _loadTeamsAndAssignments();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTeamsAndAssignments() async {
    setState(() => _loadingTeams = true);
    try {
      final sync = CampSyncService();
      final teamsRes = await sync.getAllTeams();
      final List<Map<String, dynamic>> allTeams = [];
      if (teamsRes['success'] == true || teamsRes['data'] != null) {
        final List raw = teamsRes['data'] as List? ?? [];
        allTeams.addAll(raw.map((t) => Map<String, dynamic>.from(t as Map)));
      }

      final List<String> assigned = [];
      if (_isEdit) {
        final campId = widget.existing!['id'].toString();
        final campTeamsRes = await sync.getTeamsByCamp(campId);
        if (campTeamsRes['success'] == true || campTeamsRes['data'] != null) {
          final List rawCampTeams = campTeamsRes['data'] as List? ?? [];
          for (var t in rawCampTeams) {
            final tName = t['team_name']?.toString();
            if (tName != null) assigned.add(tName);
          }
        }
      }

      setState(() {
        _allTeams = allTeams;
        _assignedTeamNames = assigned;
        _loadingTeams = false;
      });
    } catch (e) {
      debugPrint('Error loading teams/assignments in dialog: $e');
      setState(() => _loadingTeams = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _submitting = true; _error = null; });

    final sync = CampSyncService();
    final daysStr = _selectedDays.isEmpty ? null : _selectedDays.join(',');
    Map<String, dynamic> result;

    if (_isEdit) {
      result = await sync.updateCamp(
        widget.existing!['id'].toString(),
        {'name': _nameCtrl.text.trim(), 'location': _locCtrl.text.trim(), 'days': daysStr},
      );
    } else {
      result = await sync.createCamp(
        {'name': _nameCtrl.text.trim(), 'location': _locCtrl.text.trim(), 'days': daysStr},
      );
    }

    if (!mounted) return;

    if (result['success'] == true) {
      final campId = _isEdit ? widget.existing!['id'].toString() : (result['data']?['id']?.toString() ?? result['id']?.toString() ?? '');
      
      if (campId.isNotEmpty) {
        List<String> currentlyAssigned = [];
        if (_isEdit) {
          final campTeamsRes = await sync.getTeamsByCamp(campId);
          if (campTeamsRes['success'] == true || campTeamsRes['data'] != null) {
            final List rawCampTeams = campTeamsRes['data'] as List? ?? [];
            currentlyAssigned = rawCampTeams
                .map((t) => t['team_name']?.toString() ?? '')
                .where((name) => name.isNotEmpty)
                .toList();
          }
        }

        final List<Future> assignments = [];
        for (var tName in _assignedTeamNames) {
          if (!currentlyAssigned.contains(tName)) {
            final team = _allTeams.firstWhere((t) => t['team_name'] == tName, orElse: () => {});
            if (team.isNotEmpty) {
              assignments.add(sync.assignTeamToCamp(campId, {
                'team_name': team['team_name'],
                'medical_officer': team['medical_officer'] ?? '',
                'nutritionist': team['nutritionist'] ?? '',
                'medical_assistant': team['medical_assistant'] ?? '',
              }));
            }
          }
        }
        try {
          if (assignments.isNotEmpty) {
            await Future.wait(assignments);
          }
        } catch (e) {
          debugPrint('Error assigning teams to camp: $e');
        }
      }

      if (!mounted) return;
      setState(() => _submitting = false);
      Navigator.pop(context);
      widget.onSaved();
    } else {
      setState(() {
        _submitting = false;
        _error = result['message']?.toString() ?? 'Failed to save';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF7FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: _border)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: _tealLight, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.festival_outlined, color: _teal, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(_isEdit ? 'Edit Camp' : 'Create New Camp',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textDark))),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: _textLight, size: 20)),
              ]),
            ),

            // Form
            Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFFFF5F5), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFEB2B2))),
                      child: Text(_error!, style: const TextStyle(color: Color(0xFFE53E3E), fontSize: 12)),
                    ),

                  // Camp Name
                  const Text('Camp Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textLight)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameCtrl,
                    validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'e.g. Health Camp - City Center',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFBDBDBD)),
                      filled: true, fillColor: const Color(0xFFF8FAFB),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _teal, width: 1.5)),
                      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE53E3E))),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Location
                  const Text('Location', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textLight)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _locCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'e.g. Community Hall',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFBDBDBD)),
                      filled: true, fillColor: const Color(0xFFF8FAFB),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _teal, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Days
                  Row(children: [
                    const Icon(Icons.calendar_today_outlined, size: 14, color: _teal),
                    const SizedBox(width: 6),
                    const Text('Camp Days', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textLight)),
                  ]),
                  const SizedBox(height: 8),
                  _DaySelector(
                    selected: _selectedDays,
                    onChange: (days) => setState(() => _selectedDays = days),
                  ),
                  const SizedBox(height: 4),
                  const Text('Leave empty to make this camp available every day', style: TextStyle(fontSize: 10, color: _textLight)),
                  
                  // Assign Teams to this Camp
                  const Divider(height: 28, color: _border),
                  Row(children: [
                    const Icon(Icons.groups_2_outlined, size: 14, color: _teal),
                    const SizedBox(width: 6),
                    const Text('Assign Teams to this Camp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textLight)),
                  ]),
                  const SizedBox(height: 8),
                  if (_loadingTeams)
                    const Center(child: Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _teal))))
                  else if (_allTeams.isEmpty)
                    const Text(
                      'No teams available yet. Add a team in the Configure Teams section first.',
                      style: TextStyle(fontSize: 11, color: _textLight, fontStyle: FontStyle.italic),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _allTeams.map((team) {
                        final tName = team['team_name']?.toString() ?? '';
                        final isAssigned = _assignedTeamNames.contains(tName);
                        return ChoiceChip(
                          avatar: Icon(
                            isAssigned ? Icons.check : Icons.groups_outlined,
                            size: 14,
                            color: isAssigned ? Colors.white : _teal,
                          ),
                          label: Text(
                            tName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isAssigned ? Colors.white : _textDark,
                            ),
                          ),
                          selected: isAssigned,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _assignedTeamNames.add(tName);
                              } else {
                                _assignedTeamNames.remove(tName);
                              }
                            });
                          },
                          selectedColor: _teal,
                          backgroundColor: const Color(0xFFF7FAFC),
                          checkmarkColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isAssigned ? _teal : _border,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 4),
                  const Text('Select any teams that should work this camp', style: TextStyle(fontSize: 10, color: _textLight)),
                  const SizedBox(height: 20),

                  // Actions
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: _textLight)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Icon(_isEdit ? Icons.save_outlined : Icons.add, size: 16),
                      label: Text(_isEdit ? 'Update Camp' : 'Create Camp', style: const TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _teal, foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Team Palette ─────────────────────────────────────────────────────────────
class _TeamPalette {
  final Color primary;
  final Color bg;
  final Color text;
  final Color badgeBg;
  final Color iconBg;

  const _TeamPalette({
    required this.primary,
    required this.bg,
    required this.text,
    required this.badgeBg,
    required this.iconBg,
  });
}

const _teamPalettes = [
  _TeamPalette(
    primary: Color(0xFF00B5AD),
    bg: Color(0xFFE6F7F6),
    text: Color(0xFF007A73),
    badgeBg: Color(0xFFE6F7F6),
    iconBg: Color(0xFFE6F7F6),
  ),
];


// ─── Teams Config Dialog ──────────────────────────────────────────────────────
class _TeamsConfigDialog extends StatefulWidget {
  final List<Map<String, dynamic>> camps;
  final VoidCallback onSaved;
  const _TeamsConfigDialog({required this.camps, required this.onSaved});

  @override
  State<_TeamsConfigDialog> createState() => _TeamsConfigDialogState();
}

class _TeamsConfigDialogState extends State<_TeamsConfigDialog> {
  final _sync = CampSyncService();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  List<Map<String, dynamic>> _teams = [];
  
  // State for view mode: 'list' | 'add' | 'edit'
  String _mode = 'list';
  Map<String, dynamic>? _editingTeam;
  String? _editingTeamOriginalName;

  // Controllers for the form
  final _teamNameCtrl = TextEditingController();
  final _moCtrl = TextEditingController();
  final _nutCtrl = TextEditingController();
  final _maCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  @override
  void dispose() {
    _teamNameCtrl.dispose();
    _moCtrl.dispose();
    _nutCtrl.dispose();
    _maCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTeams() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _sync.getAllTeams();
      if (!mounted) return;
      if (res['success'] == true || res['data'] != null) {
        final rawList = res['data'] as List? ?? [];
        setState(() {
          _teams = rawList.map((t) => Map<String, dynamic>.from(t as Map)).toList();
          _loading = false;
        });
      } else {
        setState(() {
          _error = res['message']?.toString() ?? 'Failed to load teams';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = 'Failed to load teams: $e'; _loading = false; });
      }
    }
  }

  void _switchToList() {
    setState(() {
      _mode = 'list';
      _editingTeam = null;
      _editingTeamOriginalName = null;
      _teamNameCtrl.clear();
      _moCtrl.clear();
      _nutCtrl.clear();
      _maCtrl.clear();
      _error = null;
    });
    _loadTeams();
  }

  void _switchToForm({Map<String, dynamic>? team}) {
    setState(() {
      if (team != null) {
        _mode = 'edit';
        _editingTeam = team;
        _editingTeamOriginalName = team['team_name']?.toString();
        _teamNameCtrl.text = team['team_name']?.toString() ?? '';
        _moCtrl.text = team['medical_officer']?.toString() ?? '';
        _nutCtrl.text = team['nutritionist']?.toString() ?? '';
        _maCtrl.text = team['medical_assistant']?.toString() ?? '';
      } else {
        _mode = 'add';
        _editingTeam = null;
        _editingTeamOriginalName = null;
        _teamNameCtrl.clear();
        _moCtrl.clear();
        _nutCtrl.clear();
        _maCtrl.clear();
      }
      _error = null;
    });
  }

  Future<void> _saveTeam() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });

    final payload = {
      'team_name': _teamNameCtrl.text.trim(),
      'medical_officer': _moCtrl.text.trim(),
      'nutritionist': _nutCtrl.text.trim(),
      'medical_assistant': _maCtrl.text.trim(),
    };

    try {
      Map<String, dynamic> response;
      if (_mode == 'edit') {
        response = await _sync.updateTeam(_editingTeamOriginalName!, payload);
      } else {
        response = await _sync.createTeam(payload);
      }

      if (!mounted) return;
      
      final isOk = response['success'] == true || response['ok'] == true;
      if (isOk) {
        _switchToList();
        widget.onSaved();
      } else {
        setState(() {
          _error = response['message']?.toString() ?? 'Failed to save team';
          _saving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to save team: $e';
          _saving = false;
        });
      }
    }
  }

  Widget _buildTeamCard(Map<String, dynamic> team, int index) {
    final teamName = team['team_name']?.toString() ?? '';
    final assignedCamps = widget.camps.where((c) {
      final teamsList = c['teams'] as List?;
      return teamsList?.any((t) => t['team_name'] == teamName) ?? false;
    }).toList();

    final palette = _teamPalettes[index % _teamPalettes.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDF2F7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: palette.primary, width: 4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: palette.bg,
                  border: Border(bottom: BorderSide(color: palette.primary.withValues(alpha: 0.1))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: palette.iconBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.groups_outlined, size: 16, color: palette.text),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            teamName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _textDark,
                            ),
                          ),
                          Text(
                            '${assignedCamps.length} camp${assignedCamps.length != 1 ? "s" : ""} assigned',
                            style: const TextStyle(fontSize: 11, color: _textLight),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _switchToForm(team: team),
                      icon: Icon(Icons.edit_outlined, size: 16, color: palette.text),
                      tooltip: 'Edit team',
                    ),
                  ],
                ),
              ),
              
              // Roles list
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _buildRoleRow('Medical Officer', team['medical_officer']?.toString()),
                    const Divider(height: 12, color: _border),
                    _buildRoleRow('Nutritionist', team['nutritionist']?.toString()),
                    const Divider(height: 12, color: _border),
                    _buildRoleRow('Med. Assistant', team['medical_assistant']?.toString()),
                  ],
                ),
              ),

              // Assigned camps badges
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFB),
                  border: Border(top: BorderSide(color: _border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ASSIGNED CAMPS',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: _textLight,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (assignedCamps.isEmpty)
                      const Text(
                        'No camps assigned yet',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFFCBD5E0),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: assignedCamps.map((camp) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: palette.badgeBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: palette.primary.withValues(alpha: 0.2)),
                            ),
                            child: Text(
                              (camp['name'] ?? 'Camp').toString(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: palette.text,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleRow(String role, String? name) {
    final hasName = name != null && name.trim().isNotEmpty;
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            role,
            style: const TextStyle(fontSize: 11, color: _textLight, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            hasName ? name : '—',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: hasName ? _textDark : const Color(0xFFCBD5E0),
              fontStyle: hasName ? FontStyle.normal : FontStyle.italic,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildFormView() {
    final isEdit = _mode == 'edit';
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Team Name
          const Text(
            'Team Name *',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textLight),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _teamNameCtrl,
            validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
            style: const TextStyle(fontSize: 13),
            enabled: !isEdit,
            decoration: InputDecoration(
              hintText: 'e.g. Team Alpha',
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFBDBDBD)),
              filled: true,
              fillColor: isEdit ? const Color(0xFFEDF2F7) : const Color(0xFFF8FAFB),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _teal, width: 1.5)),
              errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE53E3E))),
            ),
          ),
          const SizedBox(height: 14),

          // Medical Officer
          const Text(
            'Medical Officer',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textLight),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _moCtrl,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'e.g. Dr. Ayesha Khan',
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFBDBDBD)),
              filled: true,
              fillColor: const Color(0xFFF8FAFB),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _teal, width: 1.5)),
            ),
          ),
          const SizedBox(height: 14),

          // Nutritionist
          const Text(
            'Nutritionist',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textLight),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _nutCtrl,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'e.g. Sara Ahmed',
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFBDBDBD)),
              filled: true,
              fillColor: const Color(0xFFF8FAFB),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _teal, width: 1.5)),
            ),
          ),
          const SizedBox(height: 14),

          // Medical Assistant
          const Text(
            'Medical Assistant',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textLight),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _maCtrl,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'e.g. Bilal Hussain',
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFBDBDBD)),
              filled: true,
              fillColor: const Color(0xFFF8FAFB),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _teal, width: 1.5)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isList = _mode == 'list';
    final titleText = isList 
        ? 'Configure Teams' 
        : (_mode == 'edit' ? 'Edit Team' : 'Create New Team');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF7FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: _border)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.groups_2_outlined, color: _teal, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      titleText,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textDark),
                    ),
                  ),
                  if (isList)
                    IconButton(
                      onPressed: () => _switchToForm(),
                      icon: const Icon(Icons.add, color: _teal, size: 20),
                      tooltip: 'Add Team',
                    ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: _textLight, size: 20),
                  ),
                ],
              ),
            ),

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _loading
                    ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: _teal)))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_error != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: const Color(0xFFFFF5F5), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFEB2B2))),
                              child: Text(_error!, style: const TextStyle(color: Color(0xFFE53E3E), fontSize: 12)),
                            ),
                          if (isList)
                            if (_teams.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(40),
                                  child: Text(
                                    'No teams created yet. Click + to add one.',
                                    style: TextStyle(color: _textLight, fontSize: 13, fontStyle: FontStyle.italic),
                                  ),
                                ),
                              )
                            else
                              ...List.generate(
                                _teams.length,
                                (index) => _buildTeamCard(_teams[index], index),
                              )
                          else
                            _buildFormView(),
                        ],
                      ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: _border))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: isList ? () => Navigator.pop(context) : _switchToList,
                    child: Text(isList ? 'Close' : 'Cancel', style: const TextStyle(color: _textLight)),
                  ),
                  if (!isList) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _saveTeam,
                      icon: _saving
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check, size: 16),
                      label: Text(_mode == 'edit' ? 'Save Changes' : 'Create Team', style: const TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
