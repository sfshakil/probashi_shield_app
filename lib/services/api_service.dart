import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/document_file.dart';

class ApiService {
  // Replace with your PC's LAN IP (not localhost) while testing on a phone/emulator.
  static const String baseUrl = "https://192.168.0.104:9001/User/Documents";

  static Future<Map<String, dynamic>> uploadDocuments(
    List<DocumentFile> docs,
  ) async {
    final res = await http.post(
      Uri.parse("$baseUrl/UploadDocuments"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"documents": docs.map((d) => d.toJson()).toList()}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> ocrAnalysis(int requestId) async {
    final res = await http.post(
      Uri.parse("$baseUrl/OCRAnalysis?requestId=$requestId"),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> validationAndAIAnalysis(
    int requestId,
  ) async {
    final res = await http.post(
      Uri.parse("$baseUrl/ValidationAndAIAnalysis?requestId=$requestId"),
    );
    return jsonDecode(res.body);
  }
}
