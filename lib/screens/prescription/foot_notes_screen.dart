import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';

import '../../custum widgets/drawer/base_scaffold.dart';
import '../../custum widgets/custom_loader.dart';
import '../../providers/prescription_provider/prescription_provider.dart';
import '../../providers/prescription_provider/foot_note_provider.dart';
import '../../providers/camp_provider.dart';
import '../../models/prescription_model/foot_note_model.dart';
import '../../global/global_api.dart';
import './widgets/shared_consultation_widgets.dart';

class AddFootNotesScreen extends StatefulWidget {
  const AddFootNotesScreen({super.key});

  @override
  State<AddFootNotesScreen> createState() => _AddFootNotesScreenState();
}

class _AddFootNotesScreenState extends State<AddFootNotesScreen> {
  final TextEditingController _mrSearchCtrl = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final List<PlatformFile> _selectedFiles = [];

  static const kTeal = Color(0xFF00B5AD);
  static const kTealLight = Color(0xFFE6F7F6);
  static const kBorder = Color(0xFFE2E8F0);
  static const kTextDark = Color(0xFF1A202C);
  static const kTextMid = Color(0xFF4A5568);
  static const kBgLight = Color(0xFFF4F7FA);
  static const kWhite = Colors.white;

  String? _lastPatientMr;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<PrescriptionProvider>();
      final camp = context.read<CampProvider>();
      
      provider.clearForm();
      if (camp.isCampMode && camp.campId != null) {
        await provider.loadCampPatients(camp.campId!);
        if (camp.medicalAssistant.isNotEmpty) {
          final cleaned = camp.medicalAssistant.replaceFirst(RegExp(r'^Dr\.\s*', caseSensitive: false), '');
          provider.setDoctorName(cleaned);
        }
      } else {
        await provider.loadConsultationPatients();
      }

      if (!mounted) return;
      // Initial check for selected patient history
      final patient = provider.currentPatient;
      if (patient != null) {
        _lastPatientMr = patient.mrNumber;
        _mrSearchCtrl.text = patient.mrNumber;
        context.read<FootNoteProvider>().loadHistory(patient.mrNumber);
      }
    });
  }

  @override
  void dispose() {
    _mrSearchCtrl.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _resolveImageUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    final base = GlobalApi.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
    return '$base$url';
  }

  Future<void> _pickImages() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        int accepted = 0;
        for (var file in result.files) {
          if (_selectedFiles.length >= 6) {
            _showSnackBar('Maximum 6 images allowed', Colors.orange);
            break;
          }

          final sizeMb = file.size / (1024 * 1024);
          if (sizeMb > 8) {
            _showSnackBar('File "${file.name}" is larger than 8MB limit', Colors.red);
            continue;
          }

          _selectedFiles.add(file);
          accepted++;
        }
        if (accepted > 0) {
          setState(() {});
        }
      }
    } catch (e) {
      _showSnackBar('Error picking files: $e', Colors.red);
    }
  }

  void _removeSelectedFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  Future<void> _handleSave(PrescriptionProvider prescriptionProvider, FootNoteProvider footnoteProvider) async {
    final patient = prescriptionProvider.currentPatient;
    if (patient == null) {
      _showSnackBar('Select a patient first', Colors.red);
      return;
    }

    final desc = _descriptionController.text.trim();
    if (desc.isEmpty && _selectedFiles.isEmpty) {
      _showSnackBar('Add at least one image or a description', Colors.orange);
      return;
    }

    final success = await footnoteProvider.save(
      mrNumber: patient.mrNumber,
      receiptId: prescriptionProvider.receiptId,
      description: desc.isNotEmpty ? desc : null,
      files: _selectedFiles.isNotEmpty ? _selectedFiles : null,
    );

    if (success) {
      _showSnackBar('Foot notes saved successfully', Colors.green);
      _descriptionController.clear();
      setState(() {
        _selectedFiles.clear();
      });
      footnoteProvider.loadHistory(patient.mrNumber);
    } else {
      _showSnackBar(footnoteProvider.errorMessage ?? 'Failed to save foot notes', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prescriptionProvider = context.watch<PrescriptionProvider>();
    final footnoteProvider = context.watch<FootNoteProvider>();
    final isMobile = MediaQuery.of(context).size.width < 900;
    
    final patient = prescriptionProvider.currentPatient;

    // Trigger history load if patient changed
    if (patient != null && patient.mrNumber != _lastPatientMr) {
      _lastPatientMr = patient.mrNumber;
      _mrSearchCtrl.text = patient.mrNumber;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        footnoteProvider.loadHistory(patient.mrNumber);
      });
    } else if (patient == null && _lastPatientMr != null) {
      _lastPatientMr = null;
      _mrSearchCtrl.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        footnoteProvider.clearHistory();
      });
    }

    return BaseScaffold(
      title: 'Add Foot Notes',
      drawerIndex: 26,
      showNotificationIcon: true,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Main Content ────────────────────────────────────────────────
          Expanded(
            flex: 9,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 110.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isMobile) ...[
                    SharedConsultationDropdown(
                      department: 'Prescription',
                      onSelect: (p) => prescriptionProvider.selectConsultationPatient(p, department: 'Prescription'),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Header Card with MR Search
                  FadeInUp(
                    duration: const Duration(milliseconds: 300),
                    child: _buildPatientSearchCard(prescriptionProvider),
                  ),
                  const SizedBox(height: 16),

                  // Foot Notes Entry Form / Placeholder
                  if (patient != null) ...[
                    FadeInUp(
                      delay: const Duration(milliseconds: 100),
                      child: _buildFootNotesFormCard(prescriptionProvider, footnoteProvider),
                    ),
                    const SizedBox(height: 16),

                    // Past Foot Notes History Card
                    FadeInUp(
                      delay: const Duration(milliseconds: 200),
                      child: _buildHistoryCard(footnoteProvider),
                    ),
                  ] else ...[
                    // No Patient Selected State card exactly mirroring React's card
                    FadeInUp(
                      delay: const Duration(milliseconds: 100),
                      child: _buildNoPatientPlaceholder(),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Sidebar (Desktop Only) ──────────────────────────────────────
          if (!isMobile)
            Expanded(
              flex: 3,
              child: SharedConsultationSidebar(
                department: 'Prescription',
                onSelect: (p) => prescriptionProvider.selectConsultationPatient(p, department: 'Prescription'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPatientSearchCard(PrescriptionProvider provider) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('PATIENT DETAILS', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kTeal)),
                  const Spacer(),
                  _buildDateStrip(),
                ],
              ),
              const SizedBox(height: 20),
              _buildInfoGrid(provider),
            ],
          ),
        ),
        if (provider.isLoading)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const CustomLoader(size: 50, color: kTeal),
            ),
          ),
      ],
    );
  }

  Widget _buildDateStrip() {
    final now = DateTime.now();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kTealLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kTeal.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_month, color: kTeal, size: 14),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(DateFormat('dd MMM yyyy').format(now), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kTextDark)),
              Text(TimeOfDay.fromDateTime(now).format(context), style: const TextStyle(fontSize: 9, color: kTeal)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoGrid(PrescriptionProvider provider) {
    final patient = provider.currentPatient;
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildInfoField('MR No.*', 'Enter MR no.', 
              controller: _mrSearchCtrl, 
              onSubmitted: (val) {
                final mr = val.trim();
                _mrSearchCtrl.text = mr;
                provider.searchPatient(mr);
              },
              width: constraints.maxWidth * (isMobile ? 1 : 0.18)),
            _buildInfoField('Patient Name', '', 
              initialValue: patient?.fullName, readOnly: true,
              width: constraints.maxWidth * (isMobile ? 1 : 0.18)),
            _buildInfoField('Age / Gender', '', 
              initialValue: patient != null ? '${patient.age} / ${patient.gender}' : '', readOnly: true,
              width: constraints.maxWidth * (isMobile ? 1 : 0.18)),
            _buildInfoField('Phone', '', 
              initialValue: patient?.phoneNumber, readOnly: true,
              width: constraints.maxWidth * (isMobile ? 1 : 0.18)),
            _buildInfoField('Consultant', '', 
              initialValue: provider.doctorName != null 
                  ? ((provider.doctorName!.toLowerCase().startsWith('dr.') || provider.doctorName!.toLowerCase().startsWith('dr '))
                      ? provider.doctorName
                      : 'Dr. ${provider.doctorName}')
                  : '', readOnly: true,
              width: constraints.maxWidth * (isMobile ? 1 : 0.18)),
          ],
        );
      }
    );
  }

  Widget _buildInfoField(String label, String hint, {TextEditingController? controller, String? initialValue, bool readOnly = false, double width = 150, Function(String)? onSubmitted}) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: kTextMid, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          TextField(
            controller: controller ?? (TextEditingController(text: initialValue)..selection = TextSelection.collapsed(offset: (initialValue ?? '').length)),
            readOnly: readOnly,
            onSubmitted: onSubmitted,
            style: TextStyle(fontSize: 12, color: readOnly ? kTextMid : kTextDark),
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              filled: true,
              fillColor: readOnly ? kBgLight : kWhite,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: kBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: kBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: kTeal)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPatientPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kBgLight,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.info_outline_rounded, size: 48, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          const Text(
            'Select a patient from the right panel to add foot notes',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kTextMid),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Or enter an MR number above',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFootNotesFormCard(PrescriptionProvider prescriptionProvider, FootNoteProvider footnoteProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.add_photo_alternate_outlined, color: kTeal, size: 18),
              const SizedBox(width: 8),
              const Text('Add Foot Note Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kTextDark)),
            ],
          ),
          const Divider(height: 24, color: kBorder),

          // Responsive grid layout (dual column for desktop, single stacked for mobile)
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 800;
              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildImageUploadSection(),
                    const SizedBox(height: 16),
                    _buildDescriptionSection(),
                  ],
                );
              } else {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 11,
                      child: _buildImageUploadSection(),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 9,
                      child: _buildDescriptionSection(),
                    ),
                  ],
                );
              }
            }
          ),
          
          const SizedBox(height: 20),

          // Save Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: footnoteProvider.isSaving ? null : () => _handleSave(prescriptionProvider, footnoteProvider),
              icon: footnoteProvider.isSaving
                  ? const SizedBox(width: 18, height: 18, child: CustomLoader(size: 18, color: kWhite))
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(
                footnoteProvider.isSaving ? 'Saving...' : 'Save Foot Notes',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kTeal,
                foregroundColor: kWhite,
                disabledBackgroundColor: kTeal.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageUploadSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kBgLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('FOOT IMAGES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kTextMid)),
              Text('${_selectedFiles.length}/6', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 12),
          // Upload Box mimicking dropzone
          InkWell(
            onTap: _pickImages,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kTeal.withValues(alpha: 0.3), style: BorderStyle.solid),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, color: kTeal, size: 28),
                  SizedBox(height: 8),
                  Text('Click to upload images', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kTextMid)),
                  SizedBox(height: 4),
                  Text('PNG, JPG up to 8MB limit · max 6 images', style: TextStyle(fontSize: 9, color: Colors.grey)),
                ],
              ),
            ),
          ),
          if (_selectedFiles.isNotEmpty) ...[
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _selectedFiles.length,
              itemBuilder: (context, idx) {
                final file = _selectedFiles[idx];
                return Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kBorder),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: file.bytes != null
                            ? Image.memory(file.bytes!, fit: BoxFit.cover)
                            : (file.path != null ? Image.file(File(file.path!), fit: BoxFit.cover) : const Icon(Icons.image)),
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () => _removeSelectedFile(idx),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 12),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DOCTOR\'S DESCRIPTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kTextMid)),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 8,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Describe findings — lesions, ulcers, discoloration, sensation, pulse, etc...',
              fillColor: kBgLight,
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kTeal)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(FootNoteProvider footnoteProvider) {
    if (footnoteProvider.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: kTeal),
        ),
      );
    }

    if (footnoteProvider.history.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_toggle_off_outlined, color: kTeal, size: 18),
              const SizedBox(width: 8),
              const Text('Foot Notes History / Past History', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kTextDark)),
            ],
          ),
          const Divider(height: 24, color: kBorder),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: footnoteProvider.history.length,
            separatorBuilder: (_, index) => const SizedBox(height: 16),
            itemBuilder: (context, idx) {
              final entry = footnoteProvider.history[idx];
              String formattedDate = '';
              try {
                formattedDate = DateFormat('dd MMM yyyy - hh:mm a').format(DateTime.parse(entry.createdAt).toLocal());
              } catch (_) {
                formattedDate = entry.createdAt;
              }

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kBgLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(formattedDate, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kTextDark)),
                        Text(
                          entry.doctorName.isNotEmpty ? 'By: ${entry.doctorName}' : '',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kTeal),
                        ),
                      ],
                    ),
                    if (entry.receiptId != null && entry.receiptId!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('Receipt ID: ${entry.receiptId}', style: const TextStyle(fontSize: 9, color: kTextMid)),
                    ],
                    const Divider(height: 16, color: kBorder),
                    
                    // Responsive row containing images on left, description inside card on right
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 600;
                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHistoryImagesSection(entry, footnoteProvider),
                              const SizedBox(height: 12),
                              _buildHistoryDescriptionSection(entry),
                            ],
                          );
                        } else {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 170,
                                child: _buildHistoryImagesSection(entry, footnoteProvider),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildHistoryDescriptionSection(entry),
                              ),
                            ],
                          );
                        }
                      }
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryImagesSection(FootNoteModel entry, FootNoteProvider footnoteProvider) {
    if (entry.images.isNotEmpty) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: entry.images.map((img) {
          final fullUrl = _resolveImageUrl(img.url);
          return Stack(
            children: [
              GestureDetector(
                onTap: () => _showZoomDialog(context, fullUrl),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      fullUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => const Center(
                        child: Icon(Icons.broken_image, size: 20, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  onTap: () => _confirmDeleteImage(context, footnoteProvider, entry.id, img.id),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 10),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      );
    } else {
      return Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Center(
          child: Text(
            'No image',
            style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
  }

  Widget _buildHistoryDescriptionSection(FootNoteModel entry) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DESCRIPTION', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Text(
            (entry.description != null && entry.description!.isNotEmpty)
                ? entry.description!
                : 'No description added',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: (entry.description != null && entry.description!.isNotEmpty) ? kTextDark : Colors.grey,
              fontStyle: (entry.description != null && entry.description!.isNotEmpty) ? FontStyle.normal : FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteImage(BuildContext context, FootNoteProvider provider, int entryId, int imageId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Attachment'),
        content: const Text('Are you sure you want to delete this image?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await provider.deleteImage(entryId, imageId);
              if (success) {
                _showSnackBar('Image deleted', Colors.green);
              } else {
                _showSnackBar(provider.errorMessage ?? 'Failed to delete image', Colors.red);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showZoomDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(8),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, stack) => const Center(
                  child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
