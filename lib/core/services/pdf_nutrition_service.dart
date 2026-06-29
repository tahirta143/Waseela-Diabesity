import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/nutrition_model/nutrition_prescription_model.dart';
import 'package:intl/intl.dart';

class PDFNutritionService {
  static Future<void> printPrescription(NutritionPrescriptionModel rx, {String? campAddress}) async {
    final pdf = pw.Document();

    try {
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
          margin: const pw.EdgeInsets.all(32),
          footer: (pw.Context context) => _buildFooter(context, font, campAddress: campAddress),
          build: (pw.Context context) => [
            _buildHeader(rx, font, fontBold, logoImage, logo2Image),
            pw.SizedBox(height: 10),
            _buildPatientStrip(rx, font, fontBold),
            pw.SizedBox(height: 10),
            if (_hasVitals(rx)) ...[
              _buildVitalsStrip(rx, font, fontBold),
              pw.SizedBox(height: 15),
            ],
            _buildMacroGrid(rx, font, fontBold),
            pw.SizedBox(height: 20),
            _buildDietPlanSection(rx, font, fontBold),
            pw.SizedBox(height: 20),
            _buildSpecificationsAndRecs(rx, font, fontBold),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Prescription_${rx.mrNumber}.pdf',
      );
    } catch (e) {
      rethrow;
    }
  }

  static pw.Widget _buildHeader(
    NutritionPrescriptionModel rx,
    pw.Font font,
    pw.Font fontBold,
    pw.MemoryImage? logoImage,
    pw.MemoryImage? logo2Image,
  ) {
    String dateStr;
    try {
      dateStr = rx.createdAt != null && rx.createdAt!.isNotEmpty
          ? DateFormat('dd MMM yyyy - hh:mm a').format(DateTime.parse(rx.createdAt!))
          : DateFormat('dd MMM yyyy - hh:mm a').format(DateTime.now());
    } catch (e) {
      dateStr = DateFormat('dd MMM yyyy - hh:mm a').format(DateTime.now());
    }

    final rawDoc = rx.doctorName.trim();
    final cleanDocName = (rawDoc.toLowerCase().startsWith('dr.') || rawDoc.toLowerCase().startsWith('dr '))
        ? rawDoc
        : (rawDoc.isEmpty ? '—' : 'Dr. $rawDoc');

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(width: 2, color: PdfColors.blue900)),
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
                  pw.Text('Diet & Nutrition Prescription',
                      style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700)),
                  pw.SizedBox(height: 4),
                  pw.Text(cleanDocName,
                      style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.blue900)),
                  pw.Text('Clinical Nutritionist',
                      style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700)),
                ],
              ),
            ],
          ),
          // Right: MR, Date, Token, Receipt
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.RichText(text: pw.TextSpan(children: [
                pw.TextSpan(text: 'MR No: ', style: pw.TextStyle(font: font, fontSize: 10)),
                pw.TextSpan(text: rx.mrNumber, style: pw.TextStyle(font: fontBold, fontSize: 10)),
              ])),
              pw.Text(dateStr, style: pw.TextStyle(font: font, fontSize: 9)),
              if (rx.receiptId != null)
                pw.Text('Receipt: ${rx.receiptId}', style: pw.TextStyle(font: font, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPatientStrip(NutritionPrescriptionModel rx, pw.Font font, pw.Font fontBold) {
    final patientName = rx.patientName ?? '${rx.patientFirstName ?? ""} ${rx.patientLastName ?? ""}'.trim();
    
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const pw.BoxDecoration(
        color: PdfColors.blue50,
        border: pw.Border(left: pw.BorderSide(width: 4, color: PdfColors.blue700)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _patientField('Patient', patientName.isNotEmpty ? patientName : '—', font, fontBold),
          _patientField('Age', rx.patientAge != null ? '${rx.patientAge} yrs' : '—', font, fontBold),
          _patientField('Gender', rx.patientGender ?? '—', font, fontBold),
          _patientField('Phone', rx.patientPhone ?? '—', font, fontBold),
          _patientField('Father/Husband', rx.fatherHusbandName ?? '—', font, fontBold),
        ],
      ),
    );
  }

  static pw.Widget _patientField(String label, String value, pw.Font font, pw.Font fontBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600)),
        pw.Text(value, style: pw.TextStyle(font: fontBold, fontSize: 10)),
      ],
    );
  }

  static bool _hasVitals(NutritionPrescriptionModel rx) {
    return rx.bp != null || rx.temp != null || rx.pulse != null || rx.weight != null || rx.height != null;
  }

  static pw.Widget _buildVitalsStrip(NutritionPrescriptionModel rx, pw.Font font, pw.Font fontBold) {
    final vitals = [
      if (rx.weight != null) 'Weight: ${rx.weight} kg',
      if (rx.height != null) 'Height: ${rx.height} in',
      if (rx.bp != null) 'BP: ${rx.bp}',
      if (rx.pulse != null) 'Pulse: ${rx.pulse} bpm',
      if (rx.temp != null) 'Temp: ${rx.temp} F',
      if (rx.bloodGroup != null) 'Blood: ${rx.bloodGroup}',
    ];

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
      child: pw.Row(
        children: [
          pw.Text('VITALS: ', style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.blue700)),
          pw.SizedBox(width: 5),
          pw.Text(vitals.join('  |  '), style: pw.TextStyle(font: font, fontSize: 9)),
        ],
      ),
    );
  }

  static pw.Widget _buildMacroGrid(NutritionPrescriptionModel rx, pw.Font font, pw.Font fontBold) {
    return pw.Row(
      children: [
        _macroCard('Daily Kilocalories', rx.totalKilocalories ?? '-', 'kcal', font, fontBold),
        pw.SizedBox(width: 10),
        _macroCard('Total Carbs', rx.totalCarbs ?? '-', 'g', font, fontBold),
        pw.SizedBox(width: 10),
        _macroCard('Total Proteins', rx.totalProteins ?? '-', 'g', font, fontBold),
        pw.SizedBox(width: 10),
        _macroCard('Total Fats', rx.totalFats ?? '-', 'g', font, fontBold),
      ],
    );
  }

  static pw.Widget _macroCard(String label, String value, String unit, pw.Font font, pw.Font fontBold) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: const pw.BoxDecoration(
          color: PdfColors.grey100,
          border: pw.Border(left: pw.BorderSide(width: 3, color: PdfColors.blue700)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label.toUpperCase(), style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.grey700)),
            pw.SizedBox(height: 2),
            pw.Text('$value $unit', style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.blue900)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildDietPlanSection(NutritionPrescriptionModel rx, pw.Font font, pw.Font fontBold) {
    final headers = ['Meal Part', 'Time', 'Food Items'];
    final data = rx.dietPlans.where((p) => p.mealTime != '--:--' || p.foodItems.isNotEmpty).map((p) => [
          p.mealPart,
          p.mealTime,
          p.foodItems,
        ]).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Daily Diet Plan', fontBold),
        if (data.isEmpty)
          pw.Text('No diet plan specified.', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600))
        else
          pw.Table.fromTextArray(
            headers: headers,
            data: data,
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            headerStyle: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.blue900),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue50),
            cellStyle: pw.TextStyle(font: font, fontSize: 10),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(6),
            },
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
      ],
    );
  }

  static pw.Widget _buildSpecificationsAndRecs(NutritionPrescriptionModel rx, pw.Font font, pw.Font fontBold) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 4,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _sectionTitle('Diet Specifications', fontBold),
              _specItem('Fluid Intake', rx.totalFluidIntake ?? '-', font),
              _specItem('Diet Order', rx.dietOrder ?? '-', font),
              _specItem('Diet Type', rx.dietType ?? '-', font),
            ],
          ),
        ),
        pw.SizedBox(width: 30),
        pw.Expanded(
          flex: 6,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (rx.dietaryRecommendations?.isNotEmpty ?? false) ...[
                _sectionTitle('Dietary Recommendations', fontBold, color: PdfColors.orange900),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(color: PdfColors.orange50, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
                  child: pw.Text(rx.dietaryRecommendations!, style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.orange900)),
                ),
                pw.SizedBox(height: 10),
              ],
              if (rx.lifestyleRecommendations?.isNotEmpty ?? false) ...[
                _sectionTitle('Lifestyle Recommendations', fontBold, color: PdfColors.green900),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(color: PdfColors.green50, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
                  child: pw.Text(rx.lifestyleRecommendations!, style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.green900)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _sectionTitle(String title, pw.Font fontBold, {PdfColor color = PdfColors.blue900}) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8, top: 10),
      padding: const pw.EdgeInsets.only(bottom: 2),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blue50, width: 2)),
      ),
      child: pw.Text(title.toUpperCase(), style: pw.TextStyle(font: fontBold, fontSize: 10, color: color, letterSpacing: 1)),
    );
  }

  static pw.Widget _specItem(String label, String value, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, style: pw.BorderStyle.dashed)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.blue800)),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context, pw.Font font, {String? campAddress}) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        if (campAddress != null && campAddress.isNotEmpty)
          pw.Container(
            alignment: pw.Alignment.bottomRight,
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Text(
              campAddress.toUpperCase(),
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
}
