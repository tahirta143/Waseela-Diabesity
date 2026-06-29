import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/prescription_model/prescription_model.dart';
import '../../models/mr_model/mr_patient_model.dart';
import '../../models/eye_model/fundus_examination_model.dart';

// ─── Vitals key → display label map (matches React buildVitals) ───────────────
const _vitalsLabelMap = {
  'bp': 'B.P.',
  'temp': 'Temp',
  'pulse': 'Pulse',
  'weight': 'Weight',
  'height': 'Height',
  'spo2': 'SpO2',
  'pain_scale': 'Pain',
  'blood': 'Blood Group',
};

// Keys to EXCLUDE from the vitals strip
const _vitalsExcludeKeys = {'receiptId', 'receipt_id'};

class PDFEyePrescriptionService {
  static Future<void> sharePrescription(PrescriptionModel rx, PatientModel patient,
      {List<FundusRecord>? recentFundusRecords, String? campName}) async {
    final pdf = await _generateDocument(rx, patient, recentFundusRecords: recentFundusRecords, campName: campName);
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Prescription_${rx.mrNumber}.pdf',
    );
  }

  static Future<pw.Document> _generateDocument(PrescriptionModel rx, PatientModel patient,
      {List<FundusRecord>? recentFundusRecords, String? campName}) async {
    // ignore: avoid_print
    print('📄 [PDFEyePrescriptionService] Generating document. Medicines: ${rx.medicines.length}');

    final pdf = pw.Document();
    final font = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();

    pw.MemoryImage? logoImage;
    pw.MemoryImage? logo2Image;
    try {
      final logoBytes = await rootBundle.load('assets/images/logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (e) {
      // ignore: avoid_print
      print('Warning: failed to load assets/images/logo.png: $e');
    }
    try {
      final logo2Bytes = await rootBundle.load('assets/images/logo_2.jpeg');
      logo2Image = pw.MemoryImage(logo2Bytes.buffer.asUint8List());
    } catch (e) {
      // ignore: avoid_print
      print('Warning: failed to load assets/images/logo_2.jpeg: $e');
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(20, 20, 20, 30),
        footer: (pw.Context context) => _buildFooter(context, font, campName: campName),
        build: (pw.Context context) => [
          // ── Header ────────────────────────────────────────────────────────
          _buildHeader(rx, patient, font, fontBold, logoImage, logo2Image),
          pw.SizedBox(height: 8),

          // ── Patient strip ─────────────────────────────────────────────────
          _buildPatientStrip(rx, patient, font, fontBold),
          pw.SizedBox(height: 6),

          // ── Vitals bar ────────────────────────────────────────────────────
          if (_hasVitals(rx)) ...[
            _buildVitalsBar(rx, font, fontBold),
            pw.SizedBox(height: 6),
          ],

          // ── Notes bar (History / Treatment / Notes / Remarks) ─────────────
          if (_hasNotes(rx)) ...[
            _buildNotesBar(rx, font, fontBold),
            pw.SizedBox(height: 8),
          ],

          // ── Two-column body (Rx left | Investigations/Diagnosis right) ────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // LEFT: Rx symbol + medicines + instructions
              pw.Expanded(
                flex: 6,
                child: pw.Container(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(right: pw.BorderSide(color: PdfColors.grey400, width: 1)),
                  ),
                  padding: const pw.EdgeInsets.only(right: 12),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Rx symbol
                      pw.RichText(
                        text: pw.TextSpan(children: [
                          pw.TextSpan(
                            text: 'R',
                            style: pw.TextStyle(font: fontBold, fontSize: 28, color: PdfColors.blue900),
                          ),
                          pw.WidgetSpan(
                            child: pw.Text(
                              'x',
                              style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.blue900),
                            ),
                          ),
                        ]),
                      ),
                      pw.SizedBox(height: 8),

                      // Medicines
                      if (rx.medicines.isNotEmpty)
                        _buildMedicines(rx, font, fontBold)
                      else
                        pw.Text('No medicines prescribed',
                            style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600)),

                      // Instructions
                      if (rx.instructions.isNotEmpty) ...[
                        pw.SizedBox(height: 12),
                        _buildInstructions(rx, font, fontBold),
                      ],
                    ],
                  ),
                ),
              ),

              pw.SizedBox(width: 12),

              // RIGHT: Refer-to / Diagnosis / Eye / Investigations
              pw.Expanded(
                flex: 4,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (rx.referTo?.isNotEmpty == true) ...[
                      _sectionTitle('Follow-ups', fontBold),
                      pw.Text('- ${rx.referTo}',
                          style: pw.TextStyle(font: font, fontSize: 10)),
                      pw.SizedBox(height: 10),
                    ],
                    if (rx.diagnosis.isNotEmpty) ...[
                      _buildDiagnosis(rx, font, fontBold),
                    ],
                    if (rx.investigations.isNotEmpty)
                      _buildInvestigations(rx, font, fontBold),
                    if (rx.eyeDetails != null)
                      _buildEyeDetails(rx.eyeDetails!, font, fontBold),
                    if (recentFundusRecords != null && recentFundusRecords.isNotEmpty) ...[
                      pw.SizedBox(height: 10),
                      _buildRecentFundus(recentFundusRecords, font, fontBold),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return pdf;
  }

  static Future<void> printPrescription(PrescriptionModel rx, PatientModel patient,
      {List<FundusRecord>? recentFundusRecords, String? campName}) async {
    try {
      final pdf = await _generateDocument(rx, patient, recentFundusRecords: recentFundusRecords, campName: campName);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Prescription_${rx.mrNumber}.pdf',
      );
    } catch (e) {
      rethrow;
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  static bool _hasVitals(PrescriptionModel rx) =>
      rx.vitals.entries
          .where((e) => !_vitalsExcludeKeys.contains(e.key) && e.value.isNotEmpty)
          .isNotEmpty;

  static bool _hasNotes(PrescriptionModel rx) =>
      [rx.historyExamination, rx.treatment, rx.consultantNotes, rx.remarks]
          .any((n) => n != null && n.isNotEmpty);

  static String _formatDoctorName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '—';
    if (trimmed.toLowerCase().startsWith('dr.') || trimmed.toLowerCase().startsWith('dr ')) {
      return trimmed;
    }
    return 'Dr. $trimmed';
  }

  // ─── Header (logos + hospital + metadata alignment) ──────────────────────────
  static pw.Widget _buildHeader(
    PrescriptionModel rx,
    PatientModel patient,
    pw.Font font,
    pw.Font fontBold,
    pw.MemoryImage? logoImage,
    pw.MemoryImage? logo2Image,
  ) {
    String dateStr;
    if (rx.createdAt != null && rx.createdAt!.isNotEmpty) {
      try {
        final parsed = DateTime.parse(rx.createdAt!);
        dateStr = DateFormat('dd MMM yyyy - hh:mm a').format(parsed.toLocal());
      } catch (_) {
        dateStr = rx.createdAt!;
      }
    } else {
      dateStr = DateFormat('dd MMM yyyy - hh:mm a').format(DateTime.now());
    }

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(width: 2, color: PdfColors.black)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Left: Logos & Hospital Info
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logoImage != null) ...[
                pw.Image(logoImage, height: 40),
                pw.SizedBox(width: 6),
              ],
              if (logo2Image != null) ...[
                pw.Image(logo2Image, height: 40),
                pw.SizedBox(width: 8),
              ],
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('WASEELA DIABESITY CLINIC',
                      style: pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColors.blue900)),
                  pw.Text('OPD Prescription',
                      style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700)),
                  pw.SizedBox(height: 4),
                  pw.Text(_formatDoctorName(rx.doctorName),
                      style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.blue900)),
                  pw.Text('Medical Officer',
                      style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700)),
                ],
              ),
            ],
          ),

          // Right: Meta (MR, Date, Token, Receipt)
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.RichText(
                text: pw.TextSpan(children: [
                  pw.TextSpan(text: 'MR.No: ', style: pw.TextStyle(font: font, fontSize: 9)),
                  pw.TextSpan(text: rx.mrNumber, style: pw.TextStyle(font: fontBold, fontSize: 9)),
                ]),
              ),
              pw.SizedBox(height: 2),
              pw.RichText(
                text: pw.TextSpan(children: [
                  pw.TextSpan(text: 'Date: ', style: pw.TextStyle(font: font, fontSize: 8)),
                  pw.TextSpan(text: dateStr, style: pw.TextStyle(font: fontBold, fontSize: 8)),
                ]),
              ),
              pw.SizedBox(height: 2),
              pw.RichText(
                text: pw.TextSpan(children: [
                  pw.TextSpan(text: 'Token: ', style: pw.TextStyle(font: font, fontSize: 8)),
                  pw.TextSpan(text: rx.tokenNumber ?? '—', style: pw.TextStyle(font: fontBold, fontSize: 8)),
                  pw.TextSpan(text: '  |  Receipt: ', style: pw.TextStyle(font: font, fontSize: 8)),
                  pw.TextSpan(text: rx.receiptId ?? '—', style: pw.TextStyle(font: fontBold, fontSize: 8)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Patient Strip (matches React patient-bar grid) ────────────────────────
  // Fields: Patient Name | Gender | Age | OPD/Doctor | Phone | Father/Husb
  static pw.Widget _buildPatientStrip(PrescriptionModel rx, PatientModel patient, pw.Font font, pw.Font fontBold) {
    final fullName = patient.fullName.isNotEmpty ? patient.fullName : (patient.firstName.isNotEmpty ? patient.firstName : '-');
    final age = patient.age != null ? '${patient.age} yrs' : '-';
    final guardian = patient.guardianName.isNotEmpty ? patient.guardianName : '-';

    final fields = [
      _PField('Patient Name', fullName),
      _PField('Gender', patient.gender.isNotEmpty ? patient.gender : '-'),
      _PField('Age', age),
      _PField('OPD/Doctor', rx.doctorName.isNotEmpty ? _formatDoctorName(rx.doctorName) : '-'),
      _PField('Phone', patient.phoneNumber.isNotEmpty ? patient.phoneNumber : '-'),
      _PField('Father/Husb', guardian),
    ];

    // 3-column grid layout matching React patient-bar
    final List<List<_PField>> rows = [];
    for (int i = 0; i < fields.length; i += 3) {
      rows.add(fields.sublist(i, i + 3 > fields.length ? fields.length : i + 3));
    }

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: rows.map((rowFields) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Row(
            children: rowFields.map((e) {
              return pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 70,
                      child: pw.Text('${e.label}:',
                          style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey800)),
                    ),
                    pw.Expanded(
                      child: pw.Text(e.value,
                          style: pw.TextStyle(font: fontBold, fontSize: 9)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        )).toList(),
      ),
    );
  }

  // ─── Vitals bar (inline, matches React vitals-bar) ─────────────────────────
  static pw.Widget _buildVitalsBar(PrescriptionModel rx, pw.Font font, pw.Font fontBold) {
    final vitalsItems = rx.vitals.entries
        .where((e) => !_vitalsExcludeKeys.contains(e.key) && e.value.isNotEmpty)
        .map((e) {
          final label = _vitalsLabelMap[e.key] ?? e.key.toUpperCase();
          return '$label: ${e.value}';
        })
        .join(',   ');

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 5),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 1.0)),
      ),
      child: pw.Row(
        children: [
          pw.Text('Vitals: ', style: pw.TextStyle(font: fontBold, fontSize: 9)),
          pw.SizedBox(width: 4),
          pw.Expanded(
            child: pw.Text(vitalsItems,
                style: pw.TextStyle(font: font, fontSize: 9)),
          ),
        ],
      ),
    );
  }

  // ─── Notes bar (matches React notes-bar: History / Treatment / Notes / Remarks) ─
  static pw.Widget _buildNotesBar(PrescriptionModel rx, pw.Font font, pw.Font fontBold) {
    final notesFields = [
      if (rx.historyExamination?.isNotEmpty == true)
        _NField('History / Examination', rx.historyExamination!),
      if (rx.treatment?.isNotEmpty == true)
        _NField('Treatment', rx.treatment!),
      if (rx.consultantNotes?.isNotEmpty == true)
        _NField('Consultant Notes', rx.consultantNotes!),
      if (rx.remarks?.isNotEmpty == true)
        _NField('Remarks', rx.remarks!),
    ];

    if (notesFields.isEmpty) return pw.SizedBox();

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 5),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 1.0)),
      ),
      child: pw.Wrap(
        spacing: 16,
        runSpacing: 4,
        children: notesFields.map((n) => pw.RichText(
          text: pw.TextSpan(
            style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey800),
            children: [
              pw.TextSpan(text: '${n.label}: ',
                  style: pw.TextStyle(font: pw.Font.helveticaOblique(), color: PdfColors.black)),
              pw.TextSpan(text: n.value),
            ],
          ),
        )).toList(),
      ),
    );
  }

  static String _getMealTimingLabel(String? value) {
    switch (value) {
      case 'before_breakfast':
        return 'Before Breakfast';
      case 'after_breakfast':
        return 'After Breakfast';
      case 'before_lunch':
        return 'Before Lunch';
      case 'after_lunch':
        return 'After Lunch';
      case 'before_dinner':
        return 'Before Dinner';
      case 'after_dinner':
        return 'After Dinner';
      default:
        return '';
    }
  }

  // ─── Medicines (matches React buildMedRows with dosage + meal timing) ────────
  static pw.Widget _buildMedicines(PrescriptionModel rx, pw.Font font, pw.Font fontBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: rx.medicines.asMap().entries.map((e) {
        final med = e.value;
        final index = e.key + 1;

        // Build timing string
        final timingParts = <String>[];
        if (med.morning > 0) {
          final t = _getMealTimingLabel(med.morningMealTiming);
          timingParts.add('Morn: ${_fmtDose(med.morning)}${t.isNotEmpty ? " ($t)" : ""}');
        }
        if (med.afternoon > 0) {
          final t = _getMealTimingLabel(med.afternoonMealTiming);
          timingParts.add('Aft: ${_fmtDose(med.afternoon)}${t.isNotEmpty ? " ($t)" : ""}');
        }
        if (med.evening > 0) {
          timingParts.add('Eve: ${_fmtDose(med.evening)}');
        }
        if (med.night > 0) {
          final t = _getMealTimingLabel(med.nightMealTiming);
          timingParts.add('Night: ${_fmtDose(med.night)}${t.isNotEmpty ? " ($t)" : ""}');
        }
        
        final hasQty = med.qty.isNotEmpty && med.qty != '0';
        final qtyStr = hasQty ? '  |  Qty: ${med.qty}' : '';
        final timingStr = timingParts.isEmpty ? '' : timingParts.join('  |  ') + qtyStr;

        return pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 8),
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(
              color: PdfColors.grey300,
              style: pw.BorderStyle.dashed,
            )),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('$index. ',
                  style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.black)),
              pw.Expanded(
                child: pw.Wrap(
                  crossAxisAlignment: pw.WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    // Name
                    pw.Text(med.medicineName,
                        style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.black)),
                    
                    // Formula Badge
                    if (med.isFormula)
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey500, width: 0.5),
                          borderRadius: pw.BorderRadius.circular(3),
                          color: PdfColors.grey200,
                        ),
                        child: pw.Text('Formula',
                            style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.black)),
                      ),
                      
                    // Days
                    if (med.forDays.isNotEmpty && med.forDays != '0')
                      pw.Text('- ${med.forDays} Day(s)',
                          style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700)),
                          
                    // Timing
                    if (timingStr.isNotEmpty)
                      pw.Text(timingStr,
                          style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.black)),
                          
                    // Dosage
                    if (med.dosage.isNotEmpty)
                      pw.Text(med.dosage,
                          style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey800)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // Format dose: show as integer if whole number (e.g. 1.0 → "1", 0.5 → "0.5")
  static String _fmtDose(double d) => d == d.toInt() ? d.toInt().toString() : d.toString();

  // ─── Instructions ─────────────────────────────────────────────────────────
  static pw.Widget _buildInstructions(PrescriptionModel rx, pw.Font font, pw.Font fontBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Patient Instructions', fontBold),
        ...rx.instructions.asMap().entries.map((e) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3, left: 4),
          child: pw.Text('${e.key + 1}. ${e.value}',
              style: pw.TextStyle(font: font, fontSize: 10)),
        )),
      ],
    );
  }

  // ─── Diagnosis ────────────────────────────────────────────────────────────
  static pw.Widget _buildDiagnosis(PrescriptionModel rx, pw.Font font, pw.Font fontBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Observations', fontBold),
        ...rx.diagnosis.map((d) {
          final displayAnswer = (d.answerDisplay?.isNotEmpty == true)
              ? d.answerDisplay!
              : (d.answerText ?? '-');
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(d.questionText,
                    style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey800)),
                pw.Text('- $displayAnswer',
                    style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700)),
              ],
            ),
          );
        }),
        pw.SizedBox(height: 8),
      ],
    );
  }

  // ─── Investigations (grouped by type, bullet list) ─────────────────────────
  static pw.Widget _buildInvestigations(PrescriptionModel rx, pw.Font font, pw.Font fontBold) {
    const groups = [
      {'key': 'lab', 'label': 'Lab Tests'},
      {'key': 'xray', 'label': 'X-Ray'},
      {'key': 'ultrasound', 'label': 'Ultrasound'},
      {'key': 'ct_scan', 'label': 'CT Scan'},
    ];

    final groupWidgets = <pw.Widget>[];
    for (final g in groups) {
      final items = rx.investigations.where((i) => i.investigationType == g['key']).toList();
      if (items.isEmpty) continue;
      groupWidgets.add(pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(g['label']!,
              style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.grey800)),
          pw.SizedBox(height: 2),
          ...items.map((i) => pw.Padding(
            padding: const pw.EdgeInsets.only(left: 8, bottom: 2),
            child: pw.Text('- ${i.testName}',
                style: pw.TextStyle(font: font, fontSize: 9)),
          )),
          pw.SizedBox(height: 4),
        ],
      ));
    }

    if (groupWidgets.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Investigations', fontBold),
        ...groupWidgets,
        pw.SizedBox(height: 6),
      ],
    );
  }

  // ─── Eye Details ──────────────────────────────────────────────────────────
  static pw.Widget _buildEyeDetails(EyePrescriptionDetails eye, pw.Font font, pw.Font fontBold) {
    final hasRefraction = _hasRefractionData(eye.rightRefraction) ||
        _hasRefractionData(eye.leftRefraction) ||
        _hasRefractionData(eye.add01Refraction) ||
        _hasRefractionData(eye.add02Refraction);
    final hasVision = _hasVisionData(eye.rightVision) || _hasVisionData(eye.leftVision);

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(6),
        color: PdfColors.grey50,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('EYE DETAILS',
              style: pw.TextStyle(font: fontBold, fontSize: 10, letterSpacing: 1)),
          pw.SizedBox(height: 8),

          if (hasRefraction) ...[
            pw.Text('REFRACTION',
                style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey700)),
            pw.SizedBox(height: 4),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: ['Eye', 'Sph', 'Cyl', 'Axis', 'VA', 'Add'].map((h) =>
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text(h, style: pw.TextStyle(font: fontBold, fontSize: 8)))).toList(),
                ),
                if (_hasRefractionData(eye.rightRefraction))
                  _refractionRow('Right', eye.rightRefraction, font, fontBold),
                if (_hasRefractionData(eye.leftRefraction))
                  _refractionRow('Left', eye.leftRefraction, font, fontBold),
                if (_hasRefractionData(eye.add01Refraction))
                  _refractionRow('A D D', eye.add01Refraction, font, fontBold),
                if (_hasRefractionData(eye.add02Refraction))
                  _refractionRow('A D D', eye.add02Refraction, font, fontBold),
              ],
            ),
            pw.SizedBox(height: 8),
          ],

          if (hasVision) ...[
            pw.Text('VISION',
                style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey700)),
            pw.SizedBox(height: 4),
            if (_hasVisionData(eye.rightVision)) _visionRow('Right', eye.rightVision, font, fontBold),
            if (_hasVisionData(eye.leftVision)) _visionRow('Left', eye.leftVision, font, fontBold),
            pw.SizedBox(height: 8),
          ],

          if (eye.presentingComplaints.isNotEmpty)
            _eyeMetaRow('Presenting Complaints', eye.presentingComplaints, font, fontBold),
          if (eye.complaints.isNotEmpty)
            _eyeMetaRow('Complaints', eye.complaints.map((c) => c.name).join(', '), font, fontBold),
          if (eye.examinations.isNotEmpty)
            _eyeMetaRow('Examinations', eye.examinations.map((c) => c.name).join(', '), font, fontBold),
          if (eye.diagnosis.isNotEmpty)
            _eyeMetaRow('Diagnosis', eye.diagnosis.map((c) => c.name).join(', '), font, fontBold),
          if (eye.advised.isNotEmpty)
            _eyeMetaRow('Advised', eye.advised.map((c) => c.name).join(', '), font, fontBold),
          if (eye.treatmentType.isNotEmpty)
            _eyeMetaRow('Treatment', eye.treatmentType, font, fontBold),
          if (eye.remarks.isNotEmpty)
            _eyeMetaRow('Remarks', eye.remarks, font, fontBold),
        ],
      ),
    );
  }

  // ─── Recent Fundus ────────────────────────────────────────────────────────
  static pw.Widget _buildRecentFundus(List<FundusRecord> records, pw.Font font, pw.Font fontBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(6),
        color: PdfColors.grey50,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('RECENT FUNDUS EXAMINATIONS',
              style: pw.TextStyle(font: fontBold, fontSize: 10, letterSpacing: 1)),
          pw.SizedBox(height: 8),
          ...records.map((record) {
            final findingsStr = record.findings.entries
                .where((e) => e.value.right == true || e.value.left == true)
                .map((e) {
                  final side = (e.value.right == true && e.value.left == true)
                      ? 'Both'
                      : (e.value.right == true ? 'Right' : 'Left');
                  return '${e.key} ($side)';
                })
                .join(', ');

            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Date: ${record.examinationDate}',
                      style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.grey700)),
                  if (findingsStr.isNotEmpty)
                    pw.Text('Findings: $findingsStr',
                        style: pw.TextStyle(font: font, fontSize: 8)),
                  if (record.otherFindings.isNotEmpty)
                    pw.Text('Other: ${record.otherFindings}',
                        style: pw.TextStyle(font: font, fontSize: 8,
                            fontStyle: pw.FontStyle.italic)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Footer ───────────────────────────────────────────────────────────────
  static pw.Widget _buildFooter(pw.Context context, pw.Font font, {String? campName}) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        if (campName != null && campName.isNotEmpty)
          pw.Container(
            alignment: pw.Alignment.bottomRight,
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Text(
              campName.toUpperCase(),
              style: pw.TextStyle(
                font: font,
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey900,
              ),
            ),
          ),
        pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.only(top: 4),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400, width: 0.5)),
          ),
          child: pw.Text(
            'This report is not meant to be used for medicolegal purpose(s).',
            style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey500),
          ),
        ),
      ],
    );
  }

  // ─── Small helpers ─────────────────────────────────────────────────────────

  static pw.Widget _sectionTitle(String title, pw.Font fontBold) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 5),
      padding: const pw.EdgeInsets.only(bottom: 2),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blue100, width: 2)),
      ),
      child: pw.Text(
        title.toUpperCase(),
        style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.blue900, letterSpacing: 1),
      ),
    );
  }

  static bool _hasRefractionData(RefractionMatrix r) =>
      r.sph.isNotEmpty || r.cyl.isNotEmpty || r.axis.isNotEmpty || r.va.isNotEmpty || r.addition.isNotEmpty;

  static pw.TableRow _refractionRow(String label, RefractionMatrix r, pw.Font font, pw.Font fontBold) {
    return pw.TableRow(
      children: [
        pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(label, style: pw.TextStyle(font: fontBold, fontSize: 8))),
        pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(r.sph.isEmpty ? '-' : r.sph, style: pw.TextStyle(font: font, fontSize: 8))),
        pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(r.cyl.isEmpty ? '-' : r.cyl, style: pw.TextStyle(font: font, fontSize: 8))),
        pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(r.axis.isEmpty ? '-' : r.axis, style: pw.TextStyle(font: font, fontSize: 8))),
        pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(r.va.isEmpty ? '-' : r.va, style: pw.TextStyle(font: font, fontSize: 8))),
        pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(r.addition.isEmpty ? '-' : r.addition, style: pw.TextStyle(font: font, fontSize: 8))),
      ],
    );
  }

  static bool _hasVisionData(VisionStats v) =>
      v.varValue.isNotEmpty || v.ph.isNotEmpty || v.ref.isNotEmpty;

  static pw.Widget _visionRow(String label, VisionStats v, pw.Font font, pw.Font fontBold) {
    final parts = [
      if (v.varValue.isNotEmpty) 'VAR ${v.varValue}',
      if (v.ph.isNotEmpty) 'PH ${v.ph}',
      if (v.ref.isNotEmpty) 'REF ${v.ref}',
    ].join(' | ');
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Text('$label: $parts', style: pw.TextStyle(font: font, fontSize: 9)),
    );
  }

  static pw.Widget _eyeMetaRow(String label, String value, pw.Font font, pw.Font fontBold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.RichText(
        text: pw.TextSpan(children: [
          pw.TextSpan(text: '$label: ', style: pw.TextStyle(font: fontBold, fontSize: 9)),
          pw.TextSpan(text: value, style: pw.TextStyle(font: font, fontSize: 9)),
        ]),
      ),
    );
  }
}

// ─── Private data classes ──────────────────────────────────────────────────────
class _PField {
  final String label;
  final String value;
  const _PField(this.label, this.value);
}

class _NField {
  final String label;
  final String value;
  const _NField(this.label, this.value);
}
