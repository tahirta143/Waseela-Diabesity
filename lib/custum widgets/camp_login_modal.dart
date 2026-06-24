import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/camp_provider.dart';
import '../screens/mr_details/mr_details.dart';

const _kTeal   = Color(0xFF00B5AD);

/// ─── CampLoginModal ──────────────────────────────────────────────────────────
/// Mirrors React CampLoginModal.jsx:
///   1. Fetch available camps
///   2. User selects a camp  →  fetch teams for that camp
///   3. User optionally selects a team
///   4. Submit → loginToCamp(campId, team: selectedTeam)
class CampLoginModal extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final bool embeddedInDialog;

  const CampLoginModal({
    super.key,
    required this.isOpen,
    required this.onClose,
    this.embeddedInDialog = false,
  });

  static void showJoinDialog(BuildContext context) {
    showCampJoinDialog(context);
  }

  @override
  State<CampLoginModal> createState() => _CampLoginModalState();
}

class _CampLoginModalState extends State<CampLoginModal> {
  // ── Camps ────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _camps = [];
  bool _loadingCamps = false;
  String? _selectedCampId;

  // ── Teams ────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _campTeams = [];
  bool _loadingTeams = false;
  Map<String, dynamic>? _selectedTeam;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadCamps());
    }
  }

  @override
  void didUpdateWidget(CampLoginModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen && !oldWidget.isOpen) {
      _loadCamps();
      setState(() {
        _selectedCampId = null;
        _campTeams = [];
        _selectedTeam = null;
      });
    }
  }

  // ── fetch camps ──────────────────────────────────────────────────────────
  Future<void> _loadCamps() async {
    setState(() { _loadingCamps = true; _camps = []; });
    final camps = await context.read<CampProvider>().fetchAvailableCamps();
    if (!mounted) return;
    final todayName = _todayDayName();
    final filtered = camps.where((camp) {
      final days = (camp['days'] ?? '').toString();
      if (days.isEmpty) return true;
      return days.split(',').map((d) => d.trim()).contains(todayName);
    }).toList();
    setState(() { _camps = filtered; _loadingCamps = false; });
  }

  // ── fetch teams when camp selected ───────────────────────────────────────
  Future<void> _onCampChanged(String? campId) async {
    setState(() {
      _selectedCampId = campId;
      _campTeams = [];
      _selectedTeam = null;
    });
    if (campId == null || campId.isEmpty) return;

    setState(() => _loadingTeams = true);
    try {
      final teams = await context.read<CampProvider>().fetchTeamsByCamp(campId);
      if (!mounted) return;
      setState(() {
        _campTeams = teams;
        _loadingTeams = false;
        // Auto-select if only one team
        if (teams.length == 1) _selectedTeam = teams[0];
      });
    } catch (_) {
      if (mounted) setState(() => _loadingTeams = false);
    }
  }

  // ── submit ───────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_selectedCampId == null) return;
    setState(() => _isSubmitting = true);
    final result = await context.read<CampProvider>().loginToCamp(
      _selectedCampId!,
      team: _selectedTeam,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.success) {
      widget.onClose();
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MrDetailsScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Failed to join camp'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  String _todayDayName() {
    const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return names[DateTime.now().weekday - 1];
  }

  // ─── Team colour helpers (consistent Teal theme) ──────────────────────
  Color _teamActiveColor(Map<String, dynamic> team) {
    return _kTeal;
  }

  Color _teamIdleColor(Map<String, dynamic> team) {
    return const Color(0xFFF2FBFB);
  }

  Color _teamBadgeBg(Map<String, dynamic> team) {
    return const Color(0xFFE0F7FA);
  }

  Color _teamBadgeFg(Map<String, dynamic> team) {
    return const Color(0xFF007A73);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen) return const SizedBox.shrink();
    final card = _buildCard(context);
    if (widget.embeddedInDialog) return card;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: Container(color: Colors.black54),
          ),
        ),
        Center(
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: card,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(BuildContext context) {
    return Container(
      width: widget.embeddedInDialog ? null : MediaQuery.of(context).size.width * 0.9,
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: widget.embeddedInDialog
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          _buildBody(),
          _buildFooter(),
        ],
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _kTeal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.festival, color: _kTeal),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Join Camp', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                Text('Select an active online camp', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Body ──────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_loadingCamps) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            CircularProgressIndicator(color: _kTeal),
            SizedBox(height: 12),
            Text('Loading active camps...'),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Camp selector ────────────────────────────────────────────────
          _sectionLabel('Select Camp'),
          const SizedBox(height: 8),
          if (_camps.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade100),
              ),
              child: Text(
                'No active camps available for ${_todayDayName()}.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFB45309), fontSize: 13),
              ),
            )
          else
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _selectedCampId,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kTeal, width: 1.5)),
              ),
              hint: const Text('-- Select an active camp --', style: TextStyle(fontSize: 13)),
              items: _camps.map((camp) {
                final id   = camp['id']?.toString() ?? '';
                final name = (camp['camp_name'] ?? camp['name'] ?? 'Camp').toString();
                final loc  = camp['location']?.toString() ?? '';
                String label = loc.isNotEmpty ? '$name - $loc' : name;
                return DropdownMenuItem(value: id, child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)));
              }).toList(),
              onChanged: (v) => _onCampChanged(v),
            ),

          // ── Teams section (shown once camp selected) ─────────────────────
          if (_selectedCampId != null) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.groups_2_outlined, size: 16, color: _kTeal),
                const SizedBox(width: 6),
                _sectionLabel('Select Team'),
                const Spacer(),
                const Text('Optional', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              ],
            ),
            const SizedBox(height: 8),
            if (_loadingTeams)
              const Row(
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _kTeal)),
                  SizedBox(width: 8),
                  Text('Loading teams...', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                ],
              )
            else if (_campTeams.isEmpty)
              const Text(
                'No teams assigned to this camp — you can still proceed.',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              )
            else ...[
              Row(
                children: _campTeams.map((team) {
                  final isSelected = _selectedTeam?['id'] == team['id'];
                  final activeColor = _teamActiveColor(team);
                  final idleColor   = _teamIdleColor(team);
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: _campTeams.last == team ? 0 : 8),
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedTeam = isSelected ? null : team;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? activeColor : idleColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? activeColor : const Color(0xFFE2E8F0),
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isSelected) ...[
                                Icon(Icons.check, size: 14, color: isSelected ? Colors.white : activeColor),
                                const SizedBox(width: 4),
                              ],
                              Icon(Icons.groups_2_outlined, size: 14, color: isSelected ? Colors.white : activeColor),
                              const SizedBox(width: 4),
                              Text(
                                team['team_name']?.toString() ?? 'Team',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.white : activeColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              // ── Selected team member badges ────────────────────────────
              if (_selectedTeam != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _teamBadgeBg(_selectedTeam!),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _teamBadgeFg(_selectedTeam!).withValues(alpha: 0.3)),
                  ),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      if ((_selectedTeam!['medical_officer'] ?? '').toString().isNotEmpty)
                        _memberBadge('MO', _selectedTeam!['medical_officer'].toString(), _teamBadgeFg(_selectedTeam!)),
                      if ((_selectedTeam!['nutritionist'] ?? '').toString().isNotEmpty)
                        _memberBadge('Nutritionist', _selectedTeam!['nutritionist'].toString(), _teamBadgeFg(_selectedTeam!)),
                      if ((_selectedTeam!['medical_assistant'] ?? '').toString().isNotEmpty)
                        _memberBadge('MA', _selectedTeam!['medical_assistant'].toString(), _teamBadgeFg(_selectedTeam!)),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 6),
              const Text(
                'Tap a selected team again to deselect',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155)));
  }

  Widget _memberBadge(String label, String value, Color color) {
    return Text(
      '$label: $value',
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color),
    );
  }

  // ─── Footer ────────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: widget.onClose,
            child: const Text('Clinical Mode'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _selectedCampId == null || _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: _isSubmitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Camp Mode'),
          ),
        ],
      ),
    );
  }
}

// ─── Session flag ─────────────────────────────────────────────────────────────
bool _campJoinShownThisSession = false;
void resetCampJoinSession() => _campJoinShownThisSession = false;

Future<void> maybeShowCampJoinPrompt(BuildContext context) async {
  if (_campJoinShownThisSession) return;
  final camp = context.read<CampProvider>();
  if (camp.isCampMode || camp.loading) return;
  _campJoinShownThisSession = true;
  if (!context.mounted) return;
  showCampJoinDialog(context);
}

void showCampJoinDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: CampLoginModal(
        isOpen: true,
        embeddedInDialog: true,
        onClose: () => Navigator.of(ctx).pop(),
      ),
    ),
  );
}
