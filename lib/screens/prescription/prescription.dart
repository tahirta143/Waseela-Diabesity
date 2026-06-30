import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../custum widgets/drawer/base_scaffold.dart';
import '../../models/mr_model/mr_patient_model.dart';
import '../../models/prescription_model/prescription_model.dart';
import '../../models/vitals_model/vitals_model.dart';
import '../../providers/prescription_provider/prescription_provider.dart';
import '../../core/providers/permission_provider.dart';
import '../../providers/camp_provider.dart';
import '../../custum widgets/custom_loader.dart';
import '../../custum widgets/animations/animations.dart';
import 'package:animate_do/animate_do.dart';
import 'widgets/lab_values_sheet.dart';
import '../../core/utils/wait_time_helper.dart';
import '../../core/services/pdf_eye_prescription_service.dart';
import 'widgets/shared_consultation_widgets.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const kTeal = Color(0xFF00B5AD);
const kTealLight = Color(0xFFE0F7F5);
const kBorder = Color(0xFFCCECE9);
const kBg = Color(0xFFF8F9FA);
const kTextDark = Color(0xFF2D3748);
const kTextMid = Color(0xFF718096);
const kWhite = Colors.white;

String getMealTimingLabel(String slot, String? value, String lang, {bool compact = false}) {
  if (value == null || value.isEmpty) return '';
  final isUr = lang == 'ur';
  if (slot == 'morning') {
    if (value == 'before_breakfast') return compact ? (isUr ? 'پہلے' : 'Before') : (isUr ? 'ناشتے سے پہلے' : 'Before Breakfast');
    if (value == 'after_breakfast') return compact ? (isUr ? 'بعد' : 'After') : (isUr ? 'ناشتے کے بعد' : 'After Breakfast');
  } else if (slot == 'afternoon') {
    if (value == 'before_lunch') return compact ? (isUr ? 'پہلے' : 'Before') : (isUr ? 'دوپہر کے کھانے سے پہلے' : 'Before Lunch');
    if (value == 'after_lunch') return compact ? (isUr ? 'بعد' : 'After') : (isUr ? 'دوپہر کے کھانے کے بعد' : 'After Lunch');
  } else if (slot == 'night') {
    if (value == 'before_dinner') return compact ? (isUr ? 'پہلے' : 'Before') : (isUr ? 'رات کے کھانے سے پہلے' : 'Before Dinner');
    if (value == 'after_dinner') return compact ? (isUr ? 'بعد' : 'After') : (isUr ? 'رات کے کھانے کے بعد' : 'After Dinner');
  }
  return '';
}

// ─── Main Screen ─────────────────────────────────────────────────────────────
class PrescriptionScreen extends StatefulWidget {
  final String? initialMr;
  const PrescriptionScreen({super.key, this.initialMr});

  @override
  State<PrescriptionScreen> createState() => _PrescriptionScreenState();
}

class _PrescriptionScreenState extends State<PrescriptionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<PrescriptionProvider>();
      final camp = context.read<CampProvider>();
      provider.clearForm();
      if (camp.isCampMode && camp.campId != null) {
        await provider.loadCampPatients(camp.campId!);
        // ── Pre-fill consultant from selected team's medical_officer ──────────
        // Mirrors React: when a team is selected on login, their MO name is the
        // default doctor/consultant name across all clinical screens.
        if (camp.medicalOfficer.isNotEmpty) {
          provider.vitalControllers['consultant']?.text = camp.medicalOfficer;
        }
      } else {
        await provider.loadConsultationPatients();
        provider.prefillMrPrefix();
      }
      await provider.fetchPredefinedInstructions();
      final mr = widget.initialMr?.trim();
      if (mr != null && mr.isNotEmpty) {
        await provider.searchPatient(mr);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrescriptionProvider>();
    final camp = context.watch<CampProvider>();
    final isMobile = MediaQuery.of(context).size.width < 900;
    final sidebarTitle =
        camp.isCampMode ? 'Camp Patients' : 'Consultation Patients';

    return BaseScaffold(
      title: 'Prescription',
      drawerIndex: 9,
      showNotificationIcon: true,
      body: CustomPageTransition(
        child: Stack(
          children: [
            Column(
              children: [
                if (isMobile)
                  SharedConsultationDropdown(
                    patients: provider.consultationPatients,
                    isLoading: provider.isLoadingPatients,
                  ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 9,
                        child: _PrescriptionBody(tabController: _tabController, provider: provider),
                      ),
                      if (!isMobile)
                        Expanded(
                          flex: 3,
                          child: SharedConsultationSidebar(
                            sidebarTitle: sidebarTitle,
                            emptyMessage: camp.isCampMode
                                ? 'No camp patients yet'
                                : null,
                            patients: provider.consultationPatients,
                            isLoading: provider.isLoadingPatients,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (provider.isSaving || provider.isLoading)
              const CustomLoader(color: kTeal,),
          ],
        ),
      ),
    );
  }
}


// ─── Body ─────────────────────────────────────────────────────────────────────
class _PrescriptionBody extends StatelessWidget {
  final TabController tabController;
  final PrescriptionProvider provider;
  const _PrescriptionBody({required this.tabController, required this.provider});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenW = mq.size.width;
    final isTablet = screenW > 600;
    final hPad = screenW * 0.04;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: hPad,
        right: hPad,
        top: mq.size.height * 0.015,
        bottom: mq.size.height * 0.12, // space for bottom nav bar
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Date strip ────────────────────────────────────────────────────
          FadeInUp(delay: const Duration(milliseconds: 100), child: _DateStrip(isTablet: isTablet)),
          SizedBox(height: mq.size.height * 0.014),

          // ── Patient Info ──────────────────────────────────────────────────
          FadeInUp(delay: const Duration(milliseconds: 200), child: _PatientInfoCard(isTablet: isTablet, screenW: screenW, provider: provider)),
          SizedBox(height: mq.size.height * 0.018),

          // ── Tabs ──────────────────────────────────────────────────────────
          FadeInUp(delay: const Duration(milliseconds: 300), child: _TabSection(tabController: tabController, isTablet: isTablet, provider: provider)),
          SizedBox(height: mq.size.height * 0.022),

          // ── Save & Print Button (bottom, full width) ──────────────────────
          FadeInUp(delay: const Duration(milliseconds: 400), child: _SavePrintButton(isTablet: isTablet, provider: provider)),
          SizedBox(height: mq.size.height * 0.01),
        ],
      ),
    );
  }
}

// ─── Date Strip ───────────────────────────────────────────────────────────────
class _DateStrip extends StatelessWidget {
  final bool isTablet;
  const _DateStrip({required this.isTablet});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kTealLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today_outlined, color: kTeal, size: 15),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formattedDate(),
                style: TextStyle(
                  color: kTeal,
                  fontWeight: FontWeight.w600,
                  fontSize: isTablet ? 13 : 11,
                ),
              ),
              Text(
                _formattedTime(),
                style: TextStyle(
                  color: kTeal.withOpacity(0.8),
                  fontSize: isTablet ? 11 : 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formattedDate() {
    final now = DateTime.now();
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  String _formattedTime() {
    final now = DateTime.now();
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

// ─── Save & Print Button ──────────────────────────────────────────────────────
class _SavePrintButton extends StatelessWidget {
  final bool isTablet;
  final PrescriptionProvider provider;
  const _SavePrintButton({required this.isTablet, required this.provider});

  @override
  Widget build(BuildContext context) {
    final perm = context.read<PermissionProvider>();
    final camp = context.watch<CampProvider>();
    return SizedBox(
      width: double.infinity,
      height: isTablet ? 52 : 48,
      child: ElevatedButton.icon(
        onPressed: (provider.currentPatient == null || !provider.hasAnyVitals) ? null : () async {
          debugPrint('🟢 [PrescriptionScreen] Save & Print button pressed');
          final patient = provider.currentPatient;
          debugPrint('🟢 [PrescriptionScreen] Current patient: ${patient?.fullName} (${patient?.mrNumber})');
          
          final success = await provider.savePrescription(
            doctorName: perm.fullName ?? 'Doctor',
            doctorSrlNo: 1, // Defaulting for now
          );
          debugPrint('🟢 [PrescriptionScreen] Save result: $success');
          if (success && patient != null) {
            final rx = provider.lastSavedPrescription;
            if (rx != null) {
              String? campInfo;
              if (camp.isCampMode) {
                final address = camp.activeCamp?['address'] ??
                    camp.activeCamp?['location'] ??
                    camp.activeCamp?['venue'] ??
                    '';
                campInfo = address.toString();
              }
              await PDFEyePrescriptionService.printPrescription(rx, patient, campName: campInfo);
            }
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(success ? 'Prescription saved successfully' : 'Failed to save prescription'),
                backgroundColor: success ? Colors.green : Colors.red,
              ),
            );
          }
        },
        icon: provider.isSaving 
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: kWhite))
          : const Icon(Icons.print_outlined, size: 18),
        label: Text(
          'Save & Print',
          style: TextStyle(
            fontSize: isTablet ? 15 : 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: kTeal,
          foregroundColor: kWhite,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          disabledBackgroundColor: Colors.grey.shade300,
        ),
      ),
    );
  }
}

// ─── Patient Info Card ────────────────────────────────────────────────────────
class _PatientInfoCard extends StatelessWidget {
  final bool isTablet;
  final double screenW;
  final PrescriptionProvider provider;
  const _PatientInfoCard({required this.isTablet, required this.screenW, required this.provider});

  @override
  Widget build(BuildContext context) {
    final patient = provider.currentPatient;

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.person_outline, color: kTeal, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Patient Information',
                  style: TextStyle(
                    color: kTextDark,
                    fontWeight: FontWeight.w600,
                    fontSize: isTablet ? 14 : 13,
                  ),
                ),
                if (provider.tokenNumber != null) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [kTeal, Color(0xFF00968F)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: kTeal.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.stars_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          'TOKEN #${provider.tokenNumber}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                if (provider.isLoading)
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: kTeal)),
              ],
            ),
          ),
          const Divider(color: kBorder, height: 1),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: isTablet ? _tabletGrid(context, patient) : _mobileGrid(context, patient),
          ),
          const SizedBox(height: 14),
          // Vitals
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            // child: _VitalsSection(isTablet: isTablet, provider: provider),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _mobileGrid(BuildContext context, PatientModel? patient) {
    return Column(
      children: [
        _FieldRow(fields: [
          _FieldData('MR No.*', 'Enter MR no.', required: true, initialValue: patient?.mrNumber ?? provider.mrSearchValue, onSearch: (val) => provider.searchPatient(val)),
          _FieldData('Patient Name', '', initialValue: patient?.fullName, readOnly: true),
        ]),
        const SizedBox(height: 10),
        _FieldRow(fields: [
          _FieldData('Age / Gender', '', initialValue: patient != null ? '${patient.age ?? ''} / ${patient.gender}' : '', readOnly: true),
          _FieldData('Phone', '', initialValue: patient?.phoneNumber, readOnly: true),
        ]),
        const SizedBox(height: 10),
        _FieldRow(fields: [
          _FieldData('Father / Husband', '', initialValue: patient?.guardianName, readOnly: true),
          _FieldData('Address', '', initialValue: patient?.address, readOnly: true),
        ]),
        const SizedBox(height: 10),
        _FieldRow(fields: [
          // Editable — mirrors React: onChange={(e) => setDoctorName(val)}
          _FieldData('Consultant', 'Enter doctor name', controller: provider.vitalControllers['consultant']),
          _FieldData('Receipt ID', 'Receipt ID', initialValue: provider.receiptId, controller: provider.vitalControllers['receiptId']),
        ]),
        const SizedBox(height: 12),
        _VitalsSummaryBox(vitals: provider.currentVitals),
      ],
    );
  }

  Widget _tabletGrid(BuildContext context, PatientModel? patient) {
    return Column(
      children: [
        Row(children: [
          Expanded(child: _InputField(label: 'MR No.*', hint: 'Enter MR no.', required: true, initialValue: patient?.mrNumber ?? provider.mrSearchValue, onSubmitted: (val) => provider.searchPatient(val))),
          const SizedBox(width: 12),
          Expanded(child: _InputField(label: 'Patient Name', hint: '', initialValue: patient?.fullName, readOnly: true)),
          const SizedBox(width: 12),
          Expanded(child: _InputField(label: 'Age / Gender', hint: '', initialValue: patient != null ? '${patient.age ?? ''} / ${patient.gender}' : '', readOnly: true)),
          const SizedBox(width: 12),
          Expanded(child: _InputField(label: 'Phone', hint: '', initialValue: patient?.phoneNumber, readOnly: true)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _InputField(label: 'Father / Husband', hint: '', initialValue: patient?.guardianName, readOnly: true)),
          const SizedBox(width: 12),
          Expanded(child: _InputField(label: 'Address', hint: '', initialValue: patient?.address, readOnly: true)),
          const SizedBox(width: 12),
          // Editable — mirrors React: onChange={(e) => setDoctorName(val)}
          Expanded(child: _InputField(label: 'Consultant', hint: 'Enter doctor name', controller: provider.vitalControllers['consultant'])),
          const SizedBox(width: 12),
          Expanded(child: _InputField(label: 'Receipt ID', hint: 'Receipt ID', initialValue: provider.receiptId, controller: provider.vitalControllers['receiptId'])),
        ]),
        const SizedBox(height: 12),
        _VitalsSummaryBox(vitals: provider.currentVitals),
      ],
    );
  }
}

// ─── Vitals Summary Widget ────────────────────────────────────────────────────
class _VitalsSummaryBox extends StatelessWidget {
  final VitalsModel? vitals;
  const _VitalsSummaryBox({this.vitals});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrescriptionProvider>();
    final v = vitals;

    // Matches React's vitals grid exactly:
    // weight, height, bmi, bmr, bsr, bp, pulse, spo2, temp, pain, waist, hip, whr, blood_group, remarks
    final items = [
      _VitalItem(label: 'Weight',  key: 'weight',     unit: 'kg',    editable: true),
      _VitalItem(label: 'Height',  key: 'height',     unit: v?.heightUnit ?? 'in', editable: true),
      _VitalItem(label: 'BMI',     key: 'bmi',        unit: '',      editable: false, value: v?.bmi?.toString()),
      _VitalItem(label: 'BMR',     key: 'bmr',        unit: 'kcal',  editable: false, value: v?.bmr?.toString()),
      _VitalItem(label: 'BSR',     key: 'bsr',        unit: v?.bsrType == 'fasting' ? 'F' : 'R', editable: false, value: v?.bsr?.toString()),
      _VitalItem(label: 'B.P.',    key: 'bp',         unit: '',      editable: true,  placeholder: '120/80'),
      _VitalItem(label: 'Pulse',   key: 'pulse',      unit: 'bpm',   editable: true),
      _VitalItem(label: 'SpO2',    key: 'spo2',       unit: '%',     editable: true),
      _VitalItem(label: 'Temp',    key: 'temp',       unit: '°F',    editable: true),
      _VitalItem(label: 'Pain',    key: 'pain_scale', unit: '/10',   editable: true),
      _VitalItem(label: 'Waist',   key: 'waist',      unit: 'cm',    editable: false, value: v?.waist?.toString()),
      _VitalItem(label: 'Hip',     key: 'hip',        unit: 'cm',    editable: false, value: v?.hip?.toString()),
      _VitalItem(label: 'WHR',     key: 'whr',        unit: '',      editable: false, value: v?.whr?.toString()),
      _VitalItem(label: 'Blood',   key: 'blood',      unit: '',      editable: true),
      _VitalItem(label: 'Remarks', key: 'remarks',    unit: '',      editable: false, value: v?.remarks, wide: true),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.monitor_heart_outlined, size: 14, color: Color(0xFF3B82F6)),
                  SizedBox(width: 6),
                  Text('VITALS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A), letterSpacing: 0.5)),
                ],
              ),
              if (vitals == null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Text('No vitals recorded', style: TextStyle(fontSize: 8, color: Color(0xFFB45309), fontStyle: FontStyle.italic)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, lbc) {
            final sw = MediaQuery.of(context).size.width;
            final isT = sw > 600;
            final crossCount = isT ? 8 : 4;
            final aspectRatio = isT ? 1.6 : (sw < 380 ? 1.2 : 1.5);

            // Build a Wrap instead of GridView so "wide" items can span differently
            // Use a simple grid-like Wrap approach
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.map((item) {
                final cellW = (lbc.maxWidth - (crossCount - 1) * 8) / crossCount;
                final w = item.wide ? (cellW * 2 + 8) : cellW;  // wide = double width

                return SizedBox(
                  width: w,
                  height: isT ? (cellW / 1.6) : (cellW / (sw < 380 ? 1.2 : 1.5)),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(item.label.toUpperCase(),
                            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                        const SizedBox(height: 2),
                        item.editable
                            ? _editableCell(provider, item)
                            : _readOnlyCell(item),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }

  Widget _editableCell(PrescriptionProvider provider, _VitalItem item) {
    final ctrl = provider.vitalControllers[item.key];
    if (ctrl == null) return _readOnlyCell(item);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: TextField(
            controller: ctrl,
            keyboardType: item.key == 'bp' ? TextInputType.text : TextInputType.number,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              hintText: item.placeholder ?? '—',
              hintStyle: const TextStyle(color: Color(0xFFCBD5E1)),
            ),
          ),
        ),
        if (item.unit.isNotEmpty) ...[
          const SizedBox(width: 2),
          Text(item.unit, style: const TextStyle(fontSize: 8, color: Color(0xFF64748B))),
        ],
      ],
    );
  }

  Widget _readOnlyCell(_VitalItem item) {
    final val = item.value;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(
            val?.isNotEmpty == true ? val! : '—',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: val?.isNotEmpty == true ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        if (item.unit.isNotEmpty && val?.isNotEmpty == true) ...[
          const SizedBox(width: 2),
          Text(item.unit, style: const TextStyle(fontSize: 8, color: Color(0xFF64748B))),
        ],
      ],
    );
  }
}

class _VitalItem {
  final String label;
  final String key;
  final String unit;
  final bool editable;
  final String? value;
  final String? placeholder;
  final bool wide;
  const _VitalItem({
    required this.label,
    required this.key,
    required this.unit,
    required this.editable,
    this.value,
    this.placeholder,
    this.wide = false,
  });
}

// ─── Field Row (2 columns) ────────────────────────────────────────────────────
class _FieldData {
  final String label;
  final String hint;
  final bool required;
  final String? initialValue;
  final bool readOnly;
  final Function(String)? onSearch;
  final TextEditingController? controller;
  const _FieldData(this.label, this.hint, {this.required = false, this.initialValue, this.readOnly = false, this.onSearch, this.controller});
}

class _FieldRow extends StatelessWidget {
  final List<_FieldData> fields;
  const _FieldRow({required this.fields});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: fields.asMap().entries.map((e) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: e.key > 0 ? 10 : 0),
            child: _InputField(
              label: e.value.label,
              hint: e.value.hint,
              required: e.value.required,
              initialValue: e.value.initialValue,
              readOnly: e.value.readOnly,
              onSubmitted: e.value.onSearch,
              controller: e.value.controller,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Input Field ──────────────────────────────────────────────────────────────
class _InputField extends StatefulWidget {
  final String label;
  final String hint;
  final bool required;
  final int maxLines;
  final String? initialValue;
  final bool readOnly;
  final Function(String)? onSubmitted;
  final TextEditingController? controller;

  const _InputField({
    required this.label,
    required this.hint,
    this.required = false,
    this.maxLines = 1,
    this.initialValue,
    this.readOnly = false,
    this.onSubmitted,
    this.controller,
  });

  @override
  State<_InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<_InputField> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = widget.controller ?? TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(_InputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Use .value instead of .text to atomically update text + cursor,
    // preventing RangeError when IME tries to restore a stale offset.
    if (widget.controller == null && widget.initialValue != oldWidget.initialValue) {
      final newText = widget.initialValue ?? '';
      _ctrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    final labelSize = isTablet ? 12.0 : 11.0;
    final inputSize = isTablet ? 13.0 : 12.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: widget.label,
            style: TextStyle(
              color: kTextMid,
              fontSize: labelSize,
              fontWeight: FontWeight.w500,
              fontFamily: 'Roboto',
            ),
            children: widget.required
                ? const [TextSpan(text: ' *', style: TextStyle(color: Colors.red))]
                : [],
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _ctrl,
          readOnly: widget.readOnly,
          maxLines: widget.maxLines,
          onSubmitted: widget.onSubmitted,
          style: TextStyle(fontSize: inputSize, color: widget.readOnly ? kTextMid : kTextDark),
          decoration: InputDecoration(
            hintText: widget.hint.isNotEmpty ? widget.hint : null,
            hintStyle: TextStyle(
              color: kTextMid.withOpacity(0.55),
              fontSize: inputSize,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 10,
              vertical: widget.maxLines > 1 ? 10 : 9,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(color: kBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(color: kTeal, width: 1.5),
            ),
            filled: true,
            fillColor: widget.readOnly ? Colors.grey.shade50 : kWhite,
            isDense: true,
          ),
        ),
      ],
    );
  }
}

// ─── Vitals Section ───────────────────────────────────────────────────────────
// class _VitalsSection extends StatelessWidget {
//   final bool isTablet;
//   final PrescriptionProvider provider;
//   const _VitalsSection({required this.isTablet, required this.provider});
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: kBg,
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: kBorder),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             'VITALS',
//             style: TextStyle(
//               color: kTextMid,
//               fontSize: isTablet ? 11 : 10,
//               fontWeight: FontWeight.w700,
//               letterSpacing: 1.1,
//             ),
//           ),
//           const SizedBox(height: 10),
//           // Always 3 columns on mobile, 6 on tablet
//           if (isTablet)
//             Row(
//               children: [
//                 Expanded(child: _VitalField(label: 'Temp', hint: '°F', controller: provider.vitalControllers['temp']!)),
//                 const SizedBox(width: 8),
//                 Expanded(child: _VitalField(label: 'B.P.', hint: '120/80', controller: provider.vitalControllers['bp']!)),
//                 const SizedBox(width: 8),
//                 Expanded(child: _VitalField(label: 'Pulse', hint: 'bpm', controller: provider.vitalControllers['pulse']!)),
//                 const SizedBox(width: 8),
//                 Expanded(child: _VitalField(label: 'Weight', hint: 'kg', controller: provider.vitalControllers['weight']!)),
//                 const SizedBox(width: 8),
//                 Expanded(child: _VitalField(label: 'Height', hint: 'ft', controller: provider.vitalControllers['height']!)),
//                 const SizedBox(width: 8),
//                 Expanded(child: _VitalField(label: 'Blood', hint: 'A+', controller: provider.vitalControllers['blood']!)),
//               ],
//             )
//           else ...[
//             Row(
//               children: [
//                 Expanded(child: _VitalField(label: 'Temp', hint: '°F', controller: provider.vitalControllers['temp']!)),
//                 const SizedBox(width: 8),
//                 Expanded(child: _VitalField(label: 'B.P.', hint: '120/80', controller: provider.vitalControllers['bp']!)),
//                 const SizedBox(width: 8),
//                 Expanded(child: _VitalField(label: 'Pulse', hint: 'bpm', controller: provider.vitalControllers['pulse']!)),
//               ],
//             ),
//             const SizedBox(height: 8),
//             Row(
//               children: [
//                 Expanded(child: _VitalField(label: 'Weight', hint: 'kg', controller: provider.vitalControllers['weight']!)),
//                 const SizedBox(width: 8),
//                 Expanded(child: _VitalField(label: 'Height', hint: 'ft', controller: provider.vitalControllers['height']!)),
//                 const SizedBox(width: 8),
//                 Expanded(child: _VitalField(label: 'Blood', hint: 'A+', controller: provider.vitalControllers['blood']!)),
//               ],
//             ),
//           ],
//         ],
//       ),
//     );
//   }
// }
//
// class _VitalField extends StatelessWidget {
//   final String label;
//   final String hint;
//   final TextEditingController controller;
//   const _VitalField({required this.label, required this.hint, required this.controller});
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           label,
//           style: const TextStyle(
//             color: kTextMid,
//             fontSize: 10,
//             fontWeight: FontWeight.w500,
//           ),
//         ),
//         const SizedBox(height: 3),
//         TextField(
//           controller: controller,
//           style: const TextStyle(fontSize: 12, color: kTextDark),
//           decoration: InputDecoration(
//             hintText: hint,
//             hintStyle: TextStyle(
//               color: kTextMid.withOpacity(0.65),
//               fontSize: 11,
//             ),
//             contentPadding:
//             const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
//             enabledBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(6),
//               borderSide: const BorderSide(color: kBorder),
//             ),
//             focusedBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(6),
//               borderSide: const BorderSide(color: kTeal, width: 1.5),
//             ),
//             filled: true,
//             fillColor: kWhite,
//             isDense: true,
//           ),
//         ),
//       ],
//     );
//   }
// }

// ─── Tab Section ─────────────────────────────────────────────────────────────
class _TabSection extends StatelessWidget {
  final TabController tabController;
  final bool isTablet;
  final PrescriptionProvider provider;
  const _TabSection({required this.tabController, required this.isTablet, required this.provider});

  static const _tabs = [
    [Icons.notes_outlined, 'Notes'],
    [Icons.medical_information_outlined, 'Observations'],
    [Icons.science_outlined, 'Investigations'],
    [Icons.medication_outlined, 'Medicines'],
    [Icons.assignment_outlined, 'Instructions'],
    [Icons.history_outlined, 'Old Visits'],
    [Icons.biotech_outlined, 'Lab Values'],
    // [Icons.people_outline, 'Waiting List'],
  ];

  @override
  Widget build(BuildContext context) {

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            children: [
              // Tab bar
              Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: kBorder)),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: TabBar(
                  controller: tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: kTeal,
                  unselectedLabelColor: kTextMid,
                  indicatorColor: kTeal,
                  indicatorWeight: 2.5,
                  dividerColor: Colors.transparent,
                  labelStyle: TextStyle(
                    fontSize: isTablet ? 13 : 11,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontSize: isTablet ? 13 : 11,
                    fontWeight: FontWeight.w400,
                  ),
                  padding: EdgeInsets.zero,
                  tabs: _tabs
                      .map(
                        (t) => Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(t[0] as IconData,
                              size: isTablet ? 16 : 14),
                          const SizedBox(width: 5),
                          Text(t[1] as String),
                        ],
                      ),
                    ),
                  )
                      .toList(),
                ),
              ),

              // Tab views — intrinsic height via IndexedStack
              _TabViewBody(tabController: tabController, isTablet: isTablet, provider: provider),
            ],
          ),
          if (provider.currentPatient != null && !provider.hasAnyVitals)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFECACA)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.monitor_heart_outlined, color: Colors.red, size: 20),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Please add patient vitals to create prescription',
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: isTablet ? 13 : 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Tab View Body ────────────────────────────────────────────────────────────
class _TabViewBody extends StatefulWidget {
  final TabController tabController;
  final bool isTablet;
  final PrescriptionProvider provider;
  const _TabViewBody(
      {required this.tabController, required this.isTablet, required this.provider});

  @override
  State<_TabViewBody> createState() => _TabViewBodyState();
}

class _TabViewBodyState extends State<_TabViewBody> {
  @override
  void initState() {
    super.initState();
    widget.tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!widget.tabController.indexIsChanging) setState(() {});
  }

  @override
  void dispose() {
    widget.tabController.removeListener(_onTabChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.tabController,
      builder: (context, child) {
        return switch (widget.tabController.index) {
          0 => _NotesTab(isTablet: widget.isTablet, provider: widget.provider),
          1 => _DiagnosisTab(isTablet: widget.isTablet, provider: widget.provider),
          2 => _InvestigationsTab(isTablet: widget.isTablet, provider: widget.provider),
          3 => _MedicinesTab(isTablet: widget.isTablet, provider: widget.provider),
          4 => _InstructionsTab(isTablet: widget.isTablet, provider: widget.provider),
          5 => _OldVisitsTab(isTablet: widget.isTablet, provider: widget.provider),
          6 => Padding(
                padding: const EdgeInsets.all(16.0),
                child: LabValuesSheet(
                  mrNumber: widget.provider.currentPatient?.mrNumber ?? '',
                  receiptId: widget.provider.receiptId,
                  readOnly: true,
                ),
              ),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }
}

// ─── Investigations Tab ─────────────────────────────────────────────────────
class _InvestigationsTab extends StatefulWidget {
  final bool isTablet;
  final PrescriptionProvider provider;
  const _InvestigationsTab({required this.isTablet, required this.provider});

  @override
  State<_InvestigationsTab> createState() => _InvestigationsTabState();
}

class _InvestigationsTabState extends State<_InvestigationsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.provider.loadTests();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.provider.isLoadingTests) {
      return const Center(child: Padding(padding: EdgeInsets.all(20), child: CustomLoader()));
    }

    final labTests = widget.provider.labTests.where((t) => 
      t['test_name'].toString().toLowerCase().contains(widget.provider.labSearch.toLowerCase())).toList();
    
    // test_category holds the investigation_type from API (x-ray, ultrasound, ct-scan, radiology, etc.)
    final xrayTests = widget.provider.radiologyTests.where((t) {
      final cat = (t['test_category'] ?? t['test_type'] ?? '').toString().toLowerCase();
      final matchesCat = cat.contains('x-ray') || cat.contains('xray') || cat.contains('x ray') || cat.contains('x_ray');
      final matchesSearch = t['test_name'].toString().toLowerCase().contains(widget.provider.xraySearch.toLowerCase());
      return matchesCat && matchesSearch;
    }).toList();

    final usTests = widget.provider.radiologyTests.where((t) {
      final cat = (t['test_category'] ?? t['test_type'] ?? '').toString().toLowerCase();
      final matchesCat = cat.contains('ultrasound') || cat.contains('ultra sound') || cat.contains('ultra_sound');
      final matchesSearch = t['test_name'].toString().toLowerCase().contains(widget.provider.ultrasoundSearch.toLowerCase());
      return matchesCat && matchesSearch;
    }).toList();

    final ctTests = widget.provider.radiologyTests.where((t) {
      final cat = (t['test_category'] ?? t['test_type'] ?? '').toString().toLowerCase();
      final matchesCat = cat.contains('ct-scan') || cat.contains('ct scan') || cat.contains('ctscan') || cat.contains('ct_scan');
      final matchesSearch = t['test_name'].toString().toLowerCase().contains(widget.provider.ctSearch.toLowerCase());
      return matchesCat && matchesSearch;
    }).toList();

    // Any radiology tests not matched by specific categories
    final matchedIds = {...xrayTests, ...usTests, ...ctTests}.map((t) => t['srl_no'] ?? t['id']).toSet();
    final otherRadTests = widget.provider.radiologyTests.where((t) {
      return !matchedIds.contains(t['srl_no'] ?? t['id']);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _testSection('LAB TESTS', labTests, 'lab', Icons.science_outlined, Colors.blue, 
            widget.provider.labSearch, widget.provider.updateLabSearch),
          const SizedBox(height: 20),
          _testSection('X-RAYS', xrayTests, 'xray', Icons.settings_overscan, Colors.indigo,
            widget.provider.xraySearch, widget.provider.updateXraySearch),
          const SizedBox(height: 20),
          _testSection('ULTRA SOUND', usTests, 'ultrasound', Icons.waves, Colors.green,
            widget.provider.ultrasoundSearch, widget.provider.updateUltrasoundSearch),
          const SizedBox(height: 20),
          _testSection('CT SCAN', ctTests, 'ct_scan', Icons.biotech, Colors.amber,
            widget.provider.ctSearch, widget.provider.updateCtSearch),
          if (otherRadTests.isNotEmpty) ...[
            const SizedBox(height: 20),
            _testSection('RADIOLOGY', otherRadTests, 'radiology', Icons.radio_outlined, Colors.purple,
              '', (_) {}),
          ],
        ],
      ),
    );
  }

  Widget _testSection(String title, List<dynamic> tests, String type, IconData icon, Color color, 
      String searchQuery, Function(String) onSearch) {
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color.withOpacity(0.8), letterSpacing: 1.1)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (tests.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(searchQuery.isEmpty ? 'No data available in this category' : 'No matches found', 
              style: TextStyle(fontSize: 11, color: kTextMid.withOpacity(0.6), fontStyle: FontStyle.italic)),
          )
        else ...[
          ElevatedButton.icon(
            onPressed: () => _showInvestigationPopup(context, title, tests, type, color, icon),
            icon: const Icon(Icons.add, size: 14),
            label: Text('Select $title', style: const TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: color.withOpacity(0.1),
              foregroundColor: color,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              minimumSize: const Size(double.infinity, 36),
            ),
          ),
          const SizedBox(height: 10),
          // Show selected items as chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.provider.selectedInvestigations
                .where((i) => i.investigationType == type)
                .map((i) {
              return Chip(
                label: Text(i.testName, style: const TextStyle(fontSize: 11)),
                onDeleted: () => widget.provider.toggleInvestigation(type, i.testName),
                deleteIcon: const Icon(Icons.close, size: 14),
                backgroundColor: color.withOpacity(0.1),
                labelStyle: TextStyle(color: color),
                side: BorderSide(color: color.withOpacity(0.2)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              );
            }).toList(),
          ),
        ]
      ],
    );
  }

  void _showInvestigationPopup(BuildContext context, String title, List<dynamic> tests, String type, Color color, IconData icon) {
    String searchQuery = '';
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: anim1.value,
          child: Opacity(
            opacity: anim1.value,
            child: StatefulBuilder(
              builder: (context, setState) {
                final filteredTests = tests.where((t) => 
                  t['test_name'].toString().toLowerCase().contains(searchQuery.toLowerCase())
                ).toList();

                final exactMatchExists = tests.any((t) => 
                  t['test_name'].toString().toLowerCase() == searchQuery.trim().toLowerCase()
                );

                return AlertDialog(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  contentPadding: EdgeInsets.zero,
                  content: Container(
                    width: double.maxFinite,
                    constraints: const BoxConstraints(minHeight: 200, maxHeight: 400),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Custom Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00B5AD),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(icon, color:Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Select $title',
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: () => Navigator.pop(context),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Search Field
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                            onChanged: (val) {
                              setState(() {
                                searchQuery = val;
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'Search tests...',
                              prefixIcon: const Icon(Icons.search, size: 18),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(25),
                                  borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(25),
                                  borderSide: BorderSide(color: color, width: 1)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // List
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: (filteredTests.isEmpty && (exactMatchExists || searchQuery.trim().isEmpty))
                                ? const Center(child: Text('No matches found', style: TextStyle(color: Colors.grey)))
                                : ListView.builder(
                                    itemCount: filteredTests.length + (!exactMatchExists && searchQuery.trim().isNotEmpty ? 1 : 0),
                                    itemBuilder: (context, index) {
                                      if (!exactMatchExists && searchQuery.trim().isNotEmpty && index == filteredTests.length) {
                                        return ListTile(
                                          dense: true,
                                          leading: Icon(Icons.add_circle_outline, color: color, size: 18),
                                          title: Text(
                                            "Add '${searchQuery.trim()}' as a new test",
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                                          ),
                                          onTap: () async {
                                            final success = await widget.provider.addCustomInvestigation(type, searchQuery.trim());
                                            if (success) {
                                              setState(() {
                                                searchQuery = '';
                                              });
                                            }
                                          },
                                        );
                                      }

                                      final test = filteredTests[index];
                                      final name = test['test_name'].toString();
                                      final isSelected = widget.provider.selectedInvestigations.any((i) => i.investigationType == type && i.testName == name);

                                      return ListTile(
                                        dense: true,
                                        title: Text(name, style: const TextStyle(fontSize: 12)),
                                        trailing: isSelected ? Icon(Icons.check_circle, color: color, size: 18) : null,
                                        onTap: () {
                                          widget.provider.toggleInvestigation(type, name);
                                          setState(() {}); // Update local state for checkmark
                                        },
                                      );
                                    },
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}


// ─── Instructions Tab ────────────────────────────────────────────────────────
class _InstructionsTab extends StatefulWidget {
  final bool isTablet;
  final PrescriptionProvider provider;
  const _InstructionsTab({required this.isTablet, required this.provider});

  @override
  State<_InstructionsTab> createState() => _InstructionsTabState();
}

class _InstructionsTabState extends State<_InstructionsTab> {
  final TextEditingController _instCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _instCtrl.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _focusNode.unfocus();
      },
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Focus(
                    onFocusChange: (hasFocus) {
                      setState(() {
                        _isFocused = hasFocus;
                      });
                    },
                    child: TextField(
                      controller: _instCtrl,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: 'Type or search instructions...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: kBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: kTeal, width: 1.5),
                        ),
                      ),
                      onChanged: (val) {
                        provider.filterInstructions(val);
                      },
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) {
                          provider.addInstruction(val);
                          _instCtrl.clear();
                          provider.filterInstructions('');
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () {
                    if (_instCtrl.text.trim().isNotEmpty) {
                      provider.addInstruction(_instCtrl.text);
                      _instCtrl.clear();
                      provider.filterInstructions('');
                    }
                  },
                  icon: const Icon(Icons.add),
                  style: IconButton.styleFrom(backgroundColor: kTeal),
                ),
              ],
            ),
            if (_isFocused && provider.filteredInstructions.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: provider.filteredInstructions.length,
                  itemBuilder: (context, index) {
                    final inst = provider.filteredInstructions[index];
                    final text = (inst['instruction_text'] ?? '').toString();
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.add, size: 14, color: Colors.green),
                      title: Text(text, style: const TextStyle(fontSize: 12)),
                      onTap: () {
                        provider.addInstruction(text);
                        _instCtrl.clear();
                        provider.filterInstructions('');
                      },
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (provider.instructions.isEmpty)
              const Center(child: Text('No instructions added.', style: TextStyle(color: kTextMid, fontSize: 13)))
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: provider.instructions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  return ListTile(
                    dense: true,
                    tileColor: kBg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    title: Text(provider.instructions[index], style: const TextStyle(fontSize: 13)),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                      onPressed: () => provider.removeInstruction(index),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Old Visits Tab — TABLE (matches React) ──────────────────────────────────
class _OldVisitsTab extends StatefulWidget {
  final bool isTablet;
  final PrescriptionProvider provider;
  const _OldVisitsTab({required this.isTablet, required this.provider});

  @override
  State<_OldVisitsTab> createState() => _OldVisitsTabState();
}

class _OldVisitsTabState extends State<_OldVisitsTab> {
  // index of the currently expanded row (-1 = none)
  int? _expandedRow;

  void _toggleRow(int i) =>
      setState(() => _expandedRow = (_expandedRow == i) ? null : i);

  String _fmtDate(String? raw) {
    if (raw == null) return '';
    try {
      final d = DateTime.parse(raw);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${d.day.toString().padLeft(2,'0')} ${months[d.month-1]} ${d.year}';
    } catch (_) { return raw; }
  }

  bool _isUrdu(String text) => RegExp(r'[\u0600-\u06FF]').hasMatch(text);

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;

    if (provider.isLoadingHistory) {
      return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: kTeal)));
    }

    final visits = provider.prescriptionHistory;
    final patientName = provider.currentPatient?.fullName ?? provider.currentPatient?.mrNumber ?? 'Patient';

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header row ───────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  '${visits.length} visit(s) found',
                  style: const TextStyle(fontSize: 10, color: kTextMid, fontWeight: FontWeight.w600, letterSpacing: 0.3),
                ),
              ),
              if (visits.isNotEmpty)
                TextButton.icon(
                  onPressed: provider.analyzingVisits
                      ? null
                      : () async {
                          final ok = await provider.summarizeVisitsWithAI(patientName);
                          if (!ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Could not analyze visits'), backgroundColor: Colors.red),
                            );
                          }
                        },
                  icon: provider.analyzingVisits
                      ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: kTeal))
                      : const Icon(Icons.auto_awesome, size: 13, color: kTeal),
                  label: Text(
                    provider.analyzingVisits ? 'Analyzing...' : 'Analyze with AI',
                    style: const TextStyle(fontSize: 11, color: kTeal, fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    backgroundColor: kTealLight,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: kBorder)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // ─── AI Summary ───────────────────────────────────────────────────
          if (provider.visitAnalysis != null && (provider.visitAnalysis ?? '').isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 13, color: Color(0xFF166534)),
                      SizedBox(width: 6),
                      Text(
                        'AI VISIT SUMMARY',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF166534), letterSpacing: 0.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    provider.visitAnalysis ?? '',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF374151), height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          if (visits.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(Icons.history_outlined, size: 36, color: kTextMid.withOpacity(0.3)),
                    const SizedBox(height: 8),
                    Text('No visit history found', style: TextStyle(fontSize: 12, color: kTextMid.withOpacity(0.6))),
                  ],
                ),
              ),
            )
          else
            _VisitsTable(
              visits: visits,
              expandedRow: _expandedRow,
              onToggleRow: _toggleRow,
              fmtDate: _fmtDate,
              isUrdu: _isUrdu,
            ),
        ],
      ),
    );
  }
}

// ─── Visits Table ─────────────────────────────────────────────────────────────
class _VisitsTable extends StatelessWidget {
  final List<PrescriptionModel> visits;
  final int? expandedRow;
  final void Function(int) onToggleRow;
  final String Function(String?) fmtDate;
  final bool Function(String) isUrdu;
  const _VisitsTable({
    required this.visits, required this.expandedRow,
    required this.onToggleRow, required this.fmtDate, required this.isUrdu,
  });

  // Fixed column widths (px) — determines the total scroll width
  // Row content width = sum of these. Outer border adds 2px, handled by overflow clip.
  static const _colWidths = [28.0, 90.0, 90.0, 90.0, 140.0, 140.0, 110.0, 160.0];
  static const _headers   = ['',   'Date','Doctor','Vitals','Notes / Dx','Investigations','Lab Values','Medicines'];

  @override
  Widget build(BuildContext context) {
    final totalW = _colWidths.fold(0.0, (a, b) => a + b);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: totalW,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row — no border needed, sits inside the outer border
                Container(
                  color: const Color(0xFF374151),
                  child: Row(
                    children: List.generate(_headers.length, (i) => SizedBox(
                      width: _colWidths[i],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                        child: Text(_headers[i],
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                color: Colors.white, letterSpacing: 0.3)),
                      ),
                    )),
                  ),
                ),
                // Data rows — no extra border, outer DecoratedBox handles it
                ...visits.asMap().entries.map((e) => _VisitRow(
                  visit: e.value, index: e.key,
                  colWidths: _colWidths,
                  isEven: e.key % 2 == 0,
                  isOpen: expandedRow == e.key,
                  onTap: () => onToggleRow(e.key),
                  fmtDate: fmtDate, isUrdu: isUrdu,
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Visit Row ────────────────────────────────────────────────────────────────
class _VisitRow extends StatelessWidget {
  final PrescriptionModel visit;
  final int index;
  final List<double> colWidths;
  final bool isEven, isOpen;
  final VoidCallback onTap;
  final String Function(String?) fmtDate;
  final bool Function(String) isUrdu;
  const _VisitRow({
    required this.visit, required this.index, required this.colWidths,
    required this.isEven, required this.isOpen, required this.onTap,
    required this.fmtDate, required this.isUrdu,
  });

  Color get _bg => isOpen ? const Color(0xFFDEEBFF)  // Light blue when expanded
      : (isEven ? Colors.white : const Color(0xFFF9FAFB));
  String _dose(double v) => v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
  Widget _grey(String t) => Text(t, style: TextStyle(fontSize: 10, color: Colors.grey.shade400));
  Widget _col(int idx, Widget child) => SizedBox(
    width: colWidths[idx],
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), child: child),
  );

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          color: _bg,
          child: Row(children: [
            // Col 0: Chevron
            _col(0, Center(child: AnimatedRotation(
              duration: const Duration(milliseconds: 200),
              turns: isOpen ? 0.25 : 0,
              child: const Icon(Icons.chevron_right, size: 16, color: Color(0xFF6B7280)),
            ))),
            _col(1, _dateCell()), 
            _col(2, _doctorCell()), 
            _col(3, _vitalsCell()),
            _col(4, _notesDxCell()), 
            _col(5, _investigationsCell()),
            _col(6, _labCell()), 
            _col(7, _medsCell()),
          ]),
        ),
      ),
      if (isOpen) Container(
        color: const Color(0xFFF0F9FF),
        padding: const EdgeInsets.all(14), 
        child: _detailPanel()
      ),
      if (!isOpen) Divider(height: 1, color: Colors.grey.shade200),
    ]);
  }

  Widget _dateCell() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(fmtDate(visit.createdAt),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
    if ((visit.receiptId ?? '').isNotEmpty)
      Text('#${visit.receiptId}', style: const TextStyle(fontSize: 9, color: kTextMid)),
  ]);

  Widget _doctorCell() {
    final raw = visit.doctorName.trim();
    final name = raw.isEmpty 
        ? '—' 
        : ((raw.toLowerCase().startsWith('dr.') || raw.toLowerCase().startsWith('dr ')) ? raw : 'Dr. $raw');
    return Text(
      name,
      style: const TextStyle(fontSize: 11, color: const Color(0xFF374151)),
      overflow: TextOverflow.ellipsis, maxLines: 2,
    );
  }

  Widget _vitalsCell() {
    final v = visit.vitals;
    final bp = (v['systolic'] != null && v['diastolic'] != null)
        ? '${v['systolic']}/${v['diastolic']}' : (v['bp'] ?? '');
    final pairs = <String, String>{
      'BP': bp, 'Pulse': v['pulse'] ?? '',
      'Temp': v['temp'] ?? v['temperature'] ?? '',
      'Wt': v['weight'] ?? '', 'SpO2': v['spo2'] ?? '',
    }..removeWhere((_, val) => val.isEmpty);
    if (pairs.isEmpty) return _grey('—');
    return Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: pairs.entries.map((e) =>
          Text('${e.key}: ${e.value}',
              style: const TextStyle(fontSize: 10, color: Color(0xFF374151)))).toList());
  }

  Widget _notesDxCell() {
    final parts = <Widget>[];
    void chip(String lbl, String? txt, Color c) {
      if ((txt ?? '').isEmpty) return;
      parts.add(Padding(padding: const EdgeInsets.only(bottom: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(margin: const EdgeInsets.only(top: 1, right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(3)),
            child: Text(lbl, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: c))),
          Expanded(child: Text(txt!, style: const TextStyle(fontSize: 10, color: Color(0xFF374151)),
              maxLines: 2, overflow: TextOverflow.ellipsis)),
        ])));
    }
    chip('Hx', visit.historyExamination, const Color(0xFF2563EB));
    chip('Tx', visit.treatment, const Color(0xFF059669));
    chip('Notes', visit.consultantNotes, const Color(0xFF7C3AED));
    chip('Rmk', visit.remarks, const Color(0xFFD97706));
    for (final dx in visit.diagnosis) {
      final a = (dx.answerDisplay ?? dx.answerText ?? '').toString();
      if (a.isEmpty) continue;
      final q = dx.questionText.isNotEmpty ? dx.questionText : 'Q#${dx.questionId}';
      parts.add(Text.rich(TextSpan(style: const TextStyle(fontSize: 10), children: [
        TextSpan(text: '$q: ', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
        TextSpan(text: a, style: const TextStyle(color: Color(0xFF374151))),
      ]), maxLines: 1, overflow: TextOverflow.ellipsis));
    }
    if (parts.isEmpty) return _grey('—');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: parts);
  }

  Widget _investigationsCell() {
    if (visit.investigations.isEmpty) return _grey('—');
    return Wrap(spacing: 4, runSpacing: 3,
      children: visit.investigations.map((inv) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFA7F3D0))),
        child: Text(inv.testName,
            style: const TextStyle(fontSize: 9, color: Color(0xFF065F46), fontWeight: FontWeight.w500)),
      )).toList());
  }

  Widget _labCell() {
    // Extract lab value rows like React's labValueRows(visit)
    final labValueRows = <Map<String, String>>[];
    final entries = visit.labValues?['entries'] as Map<String, dynamic>?;
    if (entries != null) {
      entries.forEach((parameter, byDate) {
        if (byDate is Map) {
          (byDate as Map<String, dynamic>).forEach((date, value) {
            if (value != null && value.toString().trim().isNotEmpty) {
              labValueRows.add({
                'parameter': parameter,
                'date': date,
                'value': value.toString(),
              });
            }
          });
        }
      });
    }
    
    // Sort by date descending (newest first)
    labValueRows.sort((a, b) {
      try {
        final dateA = DateTime.parse(a['date'] ?? '');
        final dateB = DateTime.parse(b['date'] ?? '');
        return dateB.compareTo(dateA);
      } catch (_) {
        return 0;
      }
    });

    if (labValueRows.isEmpty) return _grey('—');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: labValueRows.take(3).map((row) {
        final param = row['parameter'] ?? '';
        final val = row['value'] ?? '';
        final dateRaw = row['date'] ?? '';
        String formattedDate = '';
        try {
          final d = DateTime.parse(dateRaw);
          formattedDate = '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}';
        } catch (_) {
          formattedDate = dateRaw;
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 1),
          child: Text.rich(
            TextSpan(style: const TextStyle(fontSize: 9), children: [
              TextSpan(text: '$param: ', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
              TextSpan(text: val, style: const TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.w600)),
              if (formattedDate.isNotEmpty) TextSpan(text: ' ($formattedDate)', style: TextStyle(fontSize: 8, color: Colors.grey.shade500)),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
    );
  }

  Widget _medsCell() {
    if (visit.medicines.isEmpty) return _grey('—');
    return Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: visit.medicines.take(3).map((m) {
        final d = [
          if (m.morning > 0) _dose(m.morning), if (m.afternoon > 0) _dose(m.afternoon),
          if (m.evening > 0) _dose(m.evening), if (m.night > 0) _dose(m.night),
        ].join('-');
        final displayName = m.isFree ? '${m.medicineName} (Free Medicine)' : m.medicineName;
        return Padding(padding: const EdgeInsets.only(bottom: 2),
          child: Text.rich(TextSpan(style: const TextStyle(fontSize: 10), children: [
            TextSpan(text: displayName,
                style: TextStyle(fontWeight: FontWeight.w600, color: m.isFree ? const Color(0xFF047857) : const Color(0xFF1F2937))),
            if (m.isFormula) const TextSpan(text: ' (F)',
                style: TextStyle(fontSize: 8, color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
            if (d.isNotEmpty) TextSpan(text: '  $d',
                style: const TextStyle(color: kTeal, fontWeight: FontWeight.w500)),
            if (m.forDays.isNotEmpty) TextSpan(text: ' ×${m.forDays}d',
                style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
          ]), maxLines: 1, overflow: TextOverflow.ellipsis));
      }).toList());
  }

  Widget _detailPanel() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if ([visit.historyExamination, visit.treatment, visit.consultantNotes, visit.remarks]
          .any((s) => (s ?? '').isNotEmpty)) ...[
        _sec('NOTES', Icons.description_outlined, const Color(0xFF2563EB),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if ((visit.historyExamination ?? '').isNotEmpty) _lv('History', visit.historyExamination!),
            if ((visit.treatment ?? '').isNotEmpty) _lv('Treatment', visit.treatment!),
            if ((visit.consultantNotes ?? '').isNotEmpty) _lv('Notes', visit.consultantNotes!),
            if ((visit.remarks ?? '').isNotEmpty) _lv('Remarks', visit.remarks!),
          ])),
        const SizedBox(height: 10),
      ],
      if (visit.diagnosis.isNotEmpty) ...[
        _sec('DIAGNOSIS', Icons.assignment_outlined, const Color(0xFF9333EA),
          Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: visit.diagnosis.map((dx) {
              final q = dx.questionText.isNotEmpty ? dx.questionText : 'Q#${dx.questionId}';
              final a = (dx.answerDisplay ?? dx.answerText ?? '').toString();
              return Padding(padding: const EdgeInsets.only(bottom: 2),
                child: Text.rich(TextSpan(style: const TextStyle(fontSize: 11), children: [
                  TextSpan(text: '$q: ', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                  TextSpan(text: a, style: const TextStyle(color: Color(0xFF374151))),
                ])));
            }).toList())),
        const SizedBox(height: 10),
      ],
      if (visit.investigations.isNotEmpty) ...[
        _sec('INVESTIGATIONS', Icons.science_outlined, const Color(0xFF059669),
          Wrap(spacing: 6, runSpacing: 4,
            children: visit.investigations.map((inv) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFA7F3D0))),
              child: Text.rich(TextSpan(children: [
                TextSpan(text: inv.testName,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF065F46))),
                TextSpan(text: ' (${inv.investigationType})',
                    style: const TextStyle(fontSize: 9, color: Color(0xFF6EE7B7))),
              ])))).toList())),
        const SizedBox(height: 10),
      ],
      if (visit.medicines.isNotEmpty) ...[
        _sec('MEDICINES', Icons.medication_outlined, const Color(0xFFD97706),
          Table(
            columnWidths: const {0: FixedColumnWidth(22), 1: FlexColumnWidth(3),
              2: FixedColumnWidth(26), 3: FixedColumnWidth(26),
              4: FixedColumnWidth(26), 5: FixedColumnWidth(26), 6: FixedColumnWidth(34)},
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                children: const ['#','Medicine','M','A','E','N','Days']
                    .map((h) => Padding(padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(h,
                            textAlign: (h == '#' || h == 'Medicine') ? TextAlign.left : TextAlign.center,
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.grey.shade500))))
                    .toList()),
              ...visit.medicines.asMap().entries.map((e) {
                final m = e.value;
                return TableRow(
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade50))),
                  children: [
                    _tc('${e.key + 1}', left: true),
                    Padding(padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text.rich(TextSpan(children: [
                        TextSpan(text: m.isFree ? '${m.medicineName} (Free Medicine)' : m.medicineName,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: m.isFree ? const Color(0xFF047857) : const Color(0xFF1F2937))),
                        if (m.isFormula) const TextSpan(text: ' (F)',
                            style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                      ]))),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(m.morning > 0 ? _dose(m.morning) : '-', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                          if (m.morningMealTiming != null && m.morning > 0)
                            Text(
                              getMealTimingLabel('morning', m.morningMealTiming, 'ur', compact: true),
                              style: const TextStyle(fontSize: 7, color: kTeal, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(m.afternoon > 0 ? _dose(m.afternoon) : '-', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                          if (m.afternoonMealTiming != null && m.afternoon > 0)
                            Text(
                              getMealTimingLabel('afternoon', m.afternoonMealTiming, 'ur', compact: true),
                              style: const TextStyle(fontSize: 7, color: kTeal, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                    ),
                    _tc(m.evening > 0 ? _dose(m.evening) : '-'),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(m.night > 0 ? _dose(m.night) : '-', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                          if (m.nightMealTiming != null && m.night > 0)
                            Text(
                              getMealTimingLabel('night', m.nightMealTiming, 'ur', compact: true),
                              style: const TextStyle(fontSize: 7, color: kTeal, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                    ),
                    _tc(m.forDays.isNotEmpty ? m.forDays : '-'),
                  ]);
              }),
            ])),
        const SizedBox(height: 10),
      ],
      if (visit.instructions.isNotEmpty)
        _sec('INSTRUCTIONS', Icons.checklist_outlined, const Color(0xFFE11D48),
          Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: visit.instructions.map((inst) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text('• $inst',
                  textDirection: isUrdu(inst) ? TextDirection.rtl : TextDirection.ltr,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF374151))))).toList())),
    ]);
  }

  Widget _sec(String title, IconData icon, Color color, Widget content) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 13, color: color), const SizedBox(width: 5),
          Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
              color: color, letterSpacing: 0.5)),
        ]),
        const SizedBox(height: 5),
        Padding(padding: const EdgeInsets.only(left: 4), child: content),
      ]);

  Widget _lv(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text.rich(TextSpan(style: const TextStyle(fontSize: 11), children: [
      TextSpan(text: '$label: ',
          style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
      TextSpan(text: value, style: const TextStyle(color: Color(0xFF374151))),
    ])),
  );

  Widget _tc(String val, {bool left = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Text(val,
        textAlign: left ? TextAlign.left : TextAlign.center,
        style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
  );
}

// ─── Medicines Tab ──────────────────────────────────────────────────────────
class _MedicinesTab extends StatelessWidget {
  final bool isTablet;
  final PrescriptionProvider provider;
  const _MedicinesTab({required this.isTablet, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MedModeToggle(provider: provider),
              _LanguageIndicator(provider: provider),
            ],
          ),
          const SizedBox(height: 16),
          _MedicineSearchArea(provider: provider),
          const SizedBox(height: 20),
          _MedicineTable(provider: provider),
        ],
      ),
    );
  }
}

class _MedModeToggle extends StatelessWidget {
  final PrescriptionProvider provider;
  const _MedModeToggle({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: kBorder), borderRadius: BorderRadius.circular(8), color: kWhite),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBtn('Medicine', 'medicine', Icons.medical_services,Color(0xFF00B5AD),),
          _buildBtn('Formula', 'formula', Icons.science, const Color(0xFF16A34A)),
        ],
      ),
    );
  }

  Widget _buildBtn(String label, String mode, IconData icon, Color activeColor) {
    final isActive = provider.medMode == mode;
    return InkWell(
      onTap: () => provider.setMedMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeColor : kWhite,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: isActive ? kWhite : kTextMid),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: isActive ? kWhite : kTextMid, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _LanguageIndicator extends StatelessWidget {
  final PrescriptionProvider provider;
  const _LanguageIndicator({required this.provider});

  @override
  Widget build(BuildContext context) {
    final isUrdu = provider.inputLang == 'ur';
    return GestureDetector(
      onTap: () => provider.setInputLang(isUrdu ? 'en' : 'ur'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kBorder),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _pill('EN', !isUrdu),
            const SizedBox(width: 2),
            _pill('اردو', isUrdu),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active ? kTeal : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: active ? kWhite : kTextMid,
        ),
      ),
    );
  }
}

class _MedicineSearchArea extends StatefulWidget {
  final PrescriptionProvider provider;
  const _MedicineSearchArea({required this.provider});

  @override
  State<_MedicineSearchArea> createState() => _MedicineSearchAreaState();
}

class _MedicineSearchAreaState extends State<_MedicineSearchArea> {
  final TextEditingController _searchCtrl = TextEditingController();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  bool _isFree = false;
  int? _selectedMedicineId;
  String? _selectedMedicineCategory;

  String? _morningMealTiming;
  String? _afternoonMealTiming;
  String? _nightMealTiming;

  final Map<String, TextEditingController> _doseCtrls = {
    'm': TextEditingController(text: '0'),
    'a': TextEditingController(text: '0'),
    'e': TextEditingController(text: '0'),
    'n': TextEditingController(text: '0'),
    'days': TextEditingController(text: ''),
    'qty': TextEditingController(text: ''),
  };

  @override
  void dispose() {
    _searchCtrl.dispose();
    for (var c in _doseCtrls.values) c.dispose();
    _hideOverlay();
    super.dispose();
  }

  void _showOverlay() {
    _hideOverlay();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 5),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: widget.provider.medicineSearchResults.length,
                itemBuilder: (context, index) {
                  final med = widget.provider.medicineSearchResults[index];
                  // Handle different API response structures if any
                  final name = med['medicine_name'] ?? med['name'] ?? '';
                  return ListTile(
                    dense: true,
                    title: Text(name, style: const TextStyle(fontSize: 12)),
                    onTap: () {
                      _searchCtrl.value = TextEditingValue(
                        text: name,
                        selection: TextSelection.collapsed(offset: name.length),
                      );
                      setState(() {
                        _selectedMedicineId = med['id'];
                        _selectedMedicineCategory = med['category_name'];
                      });
                      _hideOverlay();
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(fontSize: 12),
                    textDirection: widget.provider.inputLang == 'ur' ? TextDirection.rtl : TextDirection.ltr,
                    onChanged: (val) {
                      widget.provider.updateMedSearch(val);
                      setState(() {
                        _selectedMedicineId = null;
                        _selectedMedicineCategory = null;
                      });
                      if (val.isNotEmpty) _showOverlay(); else _hideOverlay();
                    },
                    decoration: InputDecoration(
                      hintText: widget.provider.inputLang == 'ur'
                          ? (widget.provider.medMode == 'medicine' ? 'دوائی تلاش کریں...' : 'فارمولا تلاش کریں...')
                          : (widget.provider.medMode == 'medicine' ? 'Search medicine...' : 'Search formula...'),
                      hintTextDirection: widget.provider.inputLang == 'ur' ? TextDirection.rtl : TextDirection.ltr,
                      prefixIcon: Icon(widget.provider.medMode == 'medicine' ? Icons.medical_services_outlined : Icons.science_outlined, size: 16),
                      isDense: true,
                      filled: true,
                      fillColor: kWhite,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: kBorder)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isFree = !_isFree;
                    });
                  },
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: _isFree ? const Color(0xFFECFDF5) : kWhite,
                      border: Border.all(color: _isFree ? const Color(0xFF10B981) : kBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _isFree,
                            activeColor: const Color(0xFF059669),
                            checkColor: kWhite,
                            side: BorderSide(color: _isFree ? const Color(0xFF10B981) : kBorder),
                            onChanged: (val) {
                              setState(() {
                                _isFree = val ?? false;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Text(
                          'Free',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF047857),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _doseInput('m', 'صبح'),
                _doseInput('a', 'دوپہر'),
                // _doseInput('e', 'شام'),
                _doseInput('n', 'رات'),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _doseCtrls['days'],
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 11),
                    decoration: InputDecoration(hintText: 'Days', isDense: true, labelText: 'Days', labelStyle: const TextStyle(fontSize: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(4))),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: () async {
                    if (_searchCtrl.text.isNotEmpty) {
                      int? medId = _selectedMedicineId;
                      if (widget.provider.medMode == 'medicine' && medId == null) {
                        medId = await widget.provider.createMedicineIfNeeded(
                          _searchCtrl.text,
                          _selectedMedicineCategory,
                          '${_doseCtrls['m']!.text}-${_doseCtrls['a']!.text}-${_doseCtrls['e']!.text}-${_doseCtrls['n']!.text}',
                        );
                      }

                      final med = PrescriptionMedicine(
                        medicineName: _searchCtrl.text,
                        medicineId: medId,
                        dosage: '${_doseCtrls['m']!.text}-${_doseCtrls['a']!.text}-${_doseCtrls['e']!.text}-${_doseCtrls['n']!.text}',
                        forDays: _doseCtrls['days']!.text,
                        qty: _doseCtrls['qty']!.text,
                        morning: double.tryParse(_doseCtrls['m']!.text) ?? 0,
                        afternoon: double.tryParse(_doseCtrls['a']!.text) ?? 0,
                        evening: double.tryParse(_doseCtrls['e']!.text) ?? 0,
                        night: double.tryParse(_doseCtrls['n']!.text) ?? 0,
                        isFormula: widget.provider.medMode == 'formula',
                        isFree: _isFree,
                        morningMealTiming: _morningMealTiming,
                        afternoonMealTiming: _afternoonMealTiming,
                        nightMealTiming: _nightMealTiming,
                      );
                      widget.provider.addMedicine(med);
                      _searchCtrl.clear();
                      _doseCtrls['m']!.text = '0';
                      _doseCtrls['a']!.text = '0';
                      _doseCtrls['e']!.text = '0';
                      _doseCtrls['n']!.text = '0';
                      _doseCtrls['days']!.text = '';
                      _doseCtrls['qty']!.text = '';
                      setState(() {
                        _isFree = false;
                        _selectedMedicineId = null;
                        _selectedMedicineCategory = null;
                        _morningMealTiming = null;
                        _afternoonMealTiming = null;
                        _nightMealTiming = null;
                      });
                    }
                  },
                  style: IconButton.styleFrom(backgroundColor: kTeal, foregroundColor: kWhite),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _doseInput(String key, String urduLabel) {
    final hasMealTiming = key == 'm' || key == 'a' || key == 'n';
    String? currentTiming;
    if (key == 'm') currentTiming = _morningMealTiming;
    if (key == 'a') currentTiming = _afternoonMealTiming;
    if (key == 'n') currentTiming = _nightMealTiming;

    final lang = widget.provider.inputLang;
    final defaultLabel = lang == 'ur' ? 'وقت' : 'Meal';
    final buttonText = getMealTimingLabel(
        key == 'm'
            ? 'morning'
            : (key == 'a' ? 'afternoon' : 'night'),
        currentTiming,
        lang,
        compact: true);

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Column(
          children: [
            Text(urduLabel, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: kTeal)),
            const SizedBox(height: 2),
            TextField(
              controller: _doseCtrls[key],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
              decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(4))),
            ),
            if (hasMealTiming) ...[
              const SizedBox(height: 4),
              PopupMenuButton<String>(
                tooltip: lang == 'ur' ? 'کھانے کا وقت' : 'Meal timing',
                offset: const Offset(0, 24),
                color: kWhite,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: kBorder, width: 1),
                ),
                onSelected: (val) {
                  setState(() {
                    if (key == 'm') _morningMealTiming = (_morningMealTiming == val) ? null : val;
                    if (key == 'a') _afternoonMealTiming = (_afternoonMealTiming == val) ? null : val;
                    if (key == 'n') _nightMealTiming = (_nightMealTiming == val) ? null : val;
                  });
                },
                itemBuilder: (context) {
                  final items = <String, String>{};
                  if (key == 'm') {
                    items['before_breakfast'] = lang == 'ur' ? 'ناشتے سے پہلے' : 'Before Breakfast';
                    items['after_breakfast'] = lang == 'ur' ? 'ناشتے کے بعد' : 'After Breakfast';
                  } else if (key == 'a') {
                    items['before_lunch'] = lang == 'ur' ? 'دوپہر کے کھانے سے پہلے' : 'Before Lunch';
                    items['after_lunch'] = lang == 'ur' ? 'دوپہر کے کھانے کے بعد' : 'After Lunch';
                  } else {
                    items['before_dinner'] = lang == 'ur' ? 'رات کے کھانے سے پہلے' : 'Before Dinner';
                    items['after_dinner'] = lang == 'ur' ? 'رات کے کھانے کے بعد' : 'After Dinner';
                  }

                  return items.entries.map((entry) {
                    final isSelected = currentTiming == entry.key;
                    return PopupMenuItem<String>(
                      value: entry.key,
                      height: 36,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? kTeal : Colors.transparent,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? kTeal : kTextDark,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check, size: 14, color: kTeal),
                          ],
                        ),
                      ),
                    );
                  }).toList();
                },
                child: Container(
                  height: 22,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: buttonText.isNotEmpty ? kTealLight : Colors.white,
                    border: Border.all(color: buttonText.isNotEmpty ? kTeal : Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        buttonText.isNotEmpty ? buttonText : defaultLabel,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: buttonText.isNotEmpty ? kTeal : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.arrow_drop_down,
                        size: 12,
                        color: buttonText.isNotEmpty ? kTeal : Colors.grey.shade600,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MedicineTable extends StatelessWidget {
  final PrescriptionProvider provider;
  const _MedicineTable({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.prescribedMedicines.isEmpty) return const SizedBox();
    return Container(
      decoration: BoxDecoration(border: Border.all(color: kBorder), borderRadius: BorderRadius.circular(10), color: kWhite),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(color: Color(0xFFF8FAFC), borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
            child: const Row(children: [
              Expanded(child: Text('Medicine', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              SizedBox(width: 80, child: Text('Doses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              SizedBox(width: 40, child: Text('Days', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              SizedBox(width: 40),
            ]),
          ),
          ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: provider.prescribedMedicines.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, idx) {
              final med = provider.prescribedMedicines[idx];
              final displayName = med.isFree ? '${med.medicineName} (Free Medicine)' : med.medicineName;
              return ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                title: Text(displayName, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: med.isFree ? const Color(0xFF047857) : kTextDark)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(med.isFormula ? 'Formula' : 'Medicine', style: const TextStyle(fontSize: 9, color: kTextMid)),
                    if (med.morningMealTiming != null || med.afternoonMealTiming != null || med.nightMealTiming != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          [
                            if (med.morningMealTiming != null) 'Morn: ${getMealTimingLabel("morning", med.morningMealTiming, provider.inputLang)}',
                            if (med.afternoonMealTiming != null) 'Aft: ${getMealTimingLabel("afternoon", med.afternoonMealTiming, provider.inputLang)}',
                            if (med.nightMealTiming != null) 'Night: ${getMealTimingLabel("night", med.nightMealTiming, provider.inputLang)}',
                          ].join(' | '),
                          style: const TextStyle(fontSize: 9, color: kTeal, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 80, child: Text(med.dosage, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kTeal))),
                    SizedBox(width: 40, child: Text('${med.forDays}D', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10))),
                    IconButton(icon: const Icon(Icons.close, size: 14, color: Colors.red), onPressed: () => provider.removeMedicine(idx)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}


// ─── Waiting List Tab ────────────────────────────────────────────────────────
// class _WaitingListTab extends StatefulWidget {
//   final bool isTablet;
//   final PrescriptionProvider provider;
//   const _WaitingListTab({required this.isTablet, required this.provider});
//
//   @override
//   State<_WaitingListTab> createState() => _WaitingListTabState();
// }
//
// class _WaitingListTabState extends State<_WaitingListTab> {
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       widget.provider.loadConsultationPatients();
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (widget.provider.isLoadingPatients) {
//       return const Center(child: Padding(
//         padding: EdgeInsets.all(20.0),
//         child: CircularProgressIndicator(color: kTeal),
//       ));
//     }
//
//     if (widget.provider.consultationPatients.isEmpty) {
//       return const _PlaceholderTab(label: 'No patients in waiting list');
//     }
//
//     return Padding(
//       padding: const EdgeInsets.all(8.0),
//       child: ListView.separated(
//         shrinkWrap: true,
//         physics: const NeverScrollableScrollPhysics(),
//         itemCount: widget.provider.consultationPatients.length,
//         separatorBuilder: (_, __) => const Divider(height: 1, color: kBorder),
//         itemBuilder: (context, index) {
//           final p = widget.provider.consultationPatients[index];
//           return ListTile(
//             leading: CircleAvatar(
//               backgroundColor: kTeal.withOpacity(0.1),
//               child: const Icon(Icons.person, color: kTeal, size: 20),
//             ),
//             title: Text(p['full_name'] ?? 'Unknown', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
//             subtitle: Text('MR: ${p['mr_number']} | Token: ${p['token_no'] ?? 'N/A'}', style: const TextStyle(fontSize: 11)),
//             trailing: const Icon(Icons.chevron_right, size: 18),
//             onTap: () {
//               widget.provider.searchPatient(p['mr_number'].toString());
//             },
//           );
//         },
//       ),
//     );
//   }
// }
//

// ─── Notes Tab ────────────────────────────────────────────────────────────────
class _NotesTab extends StatelessWidget {
  final bool isTablet;
  final PrescriptionProvider provider;
  const _NotesTab({required this.isTablet, required this.provider});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final gap = mq.size.height * 0.016;

    return Padding(
      padding: EdgeInsets.all(mq.size.width * 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TextAreaField(label: 'History / Examination', hint: 'Enter history...', controller: provider.noteControllers['history']!),
          SizedBox(height: gap),
          _TextAreaField(label: 'Treatment', hint: 'Treatment plan...', controller: provider.noteControllers['treatment']!),
          SizedBox(height: gap),
          _TextAreaField(label: 'Consultant Notes', hint: 'Notes...', controller: provider.noteControllers['notes']!),
          SizedBox(height: gap),
          _TextAreaField(label: 'Remarks', hint: 'Remarks...', controller: provider.noteControllers['remarks']!),
          SizedBox(height: gap),
          _ReferToField(isTablet: isTablet, controller: provider.noteControllers['referTo']!, provider: provider),
        ],
      ),
    );
  }
}

class _TextAreaField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  const _TextAreaField({required this.label, required this.hint, required this.controller});

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    final fontSize = isTablet ? 13.0 : 12.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: kTextDark,
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: 3,
          minLines: 3,
          style: TextStyle(fontSize: fontSize, color: kTextDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: kTextMid.withOpacity(0.55),
              fontSize: fontSize,
            ),
            contentPadding: const EdgeInsets.all(12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: kBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: kTeal, width: 1.5),
            ),
            filled: true,
            fillColor: kWhite,
          ),
        ),
      ],
    );
  }
}

class _ReferToField extends StatelessWidget {
  final bool isTablet;
  final TextEditingController controller;
  final PrescriptionProvider provider;
  const _ReferToField({required this.isTablet, required this.controller, required this.provider});

  @override
  Widget build(BuildContext context) {
    final fontSize = isTablet ? 13.0 : 12.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Refer To',
          style: TextStyle(
            color: kTextDark,
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.5,
          child: TextField(
            controller: controller,
            style: TextStyle(fontSize: fontSize, color: kTextDark),
            onChanged: (_) => provider.notifyListeners(), // Refresh checkbox on manual type
            decoration: InputDecoration(
              hintText: 'Refer to...',
              hintStyle: TextStyle(
                color: kTextMid.withOpacity(0.55),
                fontSize: fontSize,
              ),
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: kBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: kTeal, width: 1.5),
              ),
              filled: true,
              fillColor: kWhite,
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => provider.setAdmissionReferral(!provider.isAdmissionReferral),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 20,
                  width: 20,
                  child: Checkbox(
                    value: provider.isAdmissionReferral,
                    onChanged: (val) => provider.setAdmissionReferral(val ?? false),
                    activeColor: kTeal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    side: const BorderSide(color: kBorder, width: 1.5),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Refer patient to Admission',
                  style: TextStyle(
                    color: kTextMid,
                    fontSize: fontSize - 1,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Diagnosis Tab ────────────────────────────────────────────────────────────
class _DiagnosisTab extends StatelessWidget {
  final bool isTablet;
  final PrescriptionProvider provider;
  const _DiagnosisTab({required this.isTablet, required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.diagnosisQuestions.isEmpty) {
      return const _PlaceholderTab(label: 'Select a patient to load diagnosis questions');
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: provider.diagnosisQuestions.map((q) {
          final qId = q['id'];
          final qText = q['question_text'];
          // Support both 'question_type' (online) and 'question_mode' (API/offline)
          final qType = (q['question_mode'] ?? q['question_type'] ?? 'choice').toString().toLowerCase();
          final qOptions = q['options'];

          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  qText,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: kTextDark),
                ),
                const SizedBox(height: 8),
                if (qType == 'text')
                  TextField(
                    onChanged: (val) => provider.setDiagnosisAnswer(qId, val),
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Enter answer...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: kBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: kTeal, width: 1.5),
                      ),
                      filled: true,
                      fillColor: kWhite,
                    ),
                  )
                else if (qOptions is List && qOptions.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    children: qOptions.map((opt) {
                      final optId = opt is Map ? (opt['id'] ?? 0) : 0;
                      final optStr = opt is Map ? (opt['option_text'] ?? opt['label'] ?? opt.toString()) : opt.toString();
                      
                      final isArray = provider.diagnosisAnswers[qId] is List;
                      final currentAnswers = isArray ? List<int>.from(provider.diagnosisAnswers[qId]) : [];
                      final isSelected = isArray 
                          ? currentAnswers.contains(optId)
                          : (provider.diagnosisAnswers[qId]?.toString() == optStr || provider.diagnosisAnswers[qId]?.toString() == optId.toString());

                      return ChoiceChip(
                        label: Text(optStr),
                        selected: isSelected,
                        onSelected: (val) {
                          if (qType == 'mcq') {
                            provider.setDiagnosisAnswer(qId, optId, isMcq: true);
                          } else {
                            provider.setDiagnosisAnswer(qId, val ? optStr : null);
                          }
                        },
                        selectedColor: kTeal.withOpacity(0.2),
                        checkmarkColor: kTeal,
                        labelStyle: TextStyle(
                          color: isSelected ? kTeal : kTextMid,
                          fontSize: 12,
                        ),
                      );
                    }).toList(),
                  )
                else
                  TextField(
                    onChanged: (val) => provider.setDiagnosisAnswer(qId, val),
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Enter answer...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: kBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: kTeal, width: 1.5),
                      ),
                      filled: true,
                      fillColor: kWhite,
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Placeholder Tab ──────────────────────────────────────────────────────────
class _PlaceholderTab extends StatelessWidget {
  final String label;
  const _PlaceholderTab({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline,
              color: kTeal.withOpacity(0.35),
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: kTextMid.withOpacity(0.6),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}