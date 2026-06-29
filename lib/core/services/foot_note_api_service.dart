import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../../global/global_api.dart';
import 'auth_storage_service.dart';

class FootNoteApiService {
  final AuthStorageService _storage = AuthStorageService();

  Future<Map<String, String>> _headers() async {
    final token = await _storage.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> fetchHistory(String mrNumber) async {
    try {
      final headers = await _headers();
      final response = await http.get(
        Uri.parse('${GlobalApi.baseUrl}/foot-notes/by-mr/$mrNumber'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> saveFootNote({
    required String mrNumber,
    String? receiptId,
    String? description,
    List<PlatformFile>? files,
  }) async {
    try {
      final token = await _storage.getToken();
      final uri = Uri.parse('${GlobalApi.baseUrl}/foot-notes');
      final request = http.MultipartRequest('POST', uri);

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['mr_number'] = mrNumber;
      if (receiptId != null) {
        request.fields['receipt_id'] = receiptId;
      }
      if (description != null) {
        request.fields['description'] = description;
      }

      if (files != null && files.isNotEmpty) {
        for (var file in files) {
          if (file.bytes != null) {
            final multipartFile = http.MultipartFile.fromBytes(
              'images',
              file.bytes!,
              filename: file.name,
            );
            request.files.add(multipartFile);
          } else if (file.path != null) {
            final multipartFile = await http.MultipartFile.fromPath(
              'images',
              file.path!,
              filename: file.name,
            );
            request.files.add(multipartFile);
          }
        }
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      return jsonDecode(responseBody);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteImage(int imageId) async {
    try {
      final headers = await _headers();
      final response = await http.delete(
        Uri.parse('${GlobalApi.baseUrl}/foot-notes/images/$imageId'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
