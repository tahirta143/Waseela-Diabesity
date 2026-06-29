import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/services/foot_note_api_service.dart';
import '../../models/prescription_model/foot_note_model.dart';

class FootNoteProvider extends ChangeNotifier {
  final FootNoteApiService _apiService = FootNoteApiService();

  List<FootNoteModel> _history = [];
  List<FootNoteModel> get history => _history;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> loadHistory(String mrNumber) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _apiService.fetchHistory(mrNumber);
      if (res['success'] == true && res['data'] != null) {
        final list = res['data'] as List? ?? [];
        _history = list.map((json) => FootNoteModel.fromJson(json)).toList();
      } else {
        _history = [];
        _errorMessage = res['message'] ?? 'Failed to load history';
      }
    } catch (e) {
      _history = [];
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> save({
    required String mrNumber,
    String? receiptId,
    String? description,
    List<PlatformFile>? files,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _apiService.saveFootNote(
        mrNumber: mrNumber,
        receiptId: receiptId,
        description: description,
        files: files,
      );
      if (res['success'] == true) {
        return true;
      } else {
        _errorMessage = res['message'] ?? 'Failed to save foot notes';
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> deleteImage(int entryId, int imageId) async {
    try {
      final res = await _apiService.deleteImage(imageId);
      if (res['success'] == true) {
        // Remove from local list
        for (var entry in _history) {
          if (entry.id == entryId) {
            entry.images.removeWhere((img) => img.id == imageId);
            break;
          }
        }
        // Remove empty entries that have no description and no images left
        _history.removeWhere((entry) => entry.images.isEmpty && (entry.description == null || entry.description!.trim().isEmpty));
        notifyListeners();
        return true;
      } else {
        _errorMessage = res['message'] ?? 'Failed to delete image';
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  void clearHistory() {
    _history = [];
    _errorMessage = null;
    _isLoading = false;
    _isSaving = false;
    notifyListeners();
  }
}
