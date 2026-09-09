import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/document_file.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

enum AppStage { upload, uploading, ocr, validating, result, error }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? documentType;
  final List<DocumentFile> selectedFiles = [];
  AppStage stage = AppStage.upload;
  int activeStageIndex = 0; // 0=upload,1=ocr,2=validate
  Map<String, dynamic>? verdict;
  String? errorMessage;
  final picker = ImagePicker();

  final List<Map<String, dynamic>> docTypes = [
    {"value": "BMETLicense", "label": "BMET License", "icon": Icons.badge},
    {"value": "Offer", "label": "Job Offer", "icon": Icons.description},
    {"value": "Visa", "label": "Visa", "icon": Icons.flight},
    {"value": "Passport", "label": "Passport", "icon": Icons.menu_book},
    {"value": "Other", "label": "Other", "icon": Icons.insert_drive_file},
  ];

  Future<void> pickImage(ImageSource source) async {
    if (documentType == null) {
      _toast("Select a document type first");
      return;
    }
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    final bytes = await File(picked.path).readAsBytes();
    final base64Str = "data:image/jpeg;base64,${base64Encode(bytes)}";
    setState(() {
      selectedFiles.add(
        DocumentFile(
          fileName: picked.name,
          fileSize: bytes.length,
          fileData: base64Str,
          documentType: documentType!,
        ),
      );
    });
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  void removeFile(int index) => setState(() => selectedFiles.removeAt(index));

  void resetAll() {
    setState(() {
      selectedFiles.clear();
      documentType = null;
      stage = AppStage.upload;
      activeStageIndex = 0;
      verdict = null;
      errorMessage = null;
    });
  }

  Future<void> startUpload() async {
    if (selectedFiles.isEmpty) return;
    setState(() {
      stage = AppStage.uploading;
      activeStageIndex = 0;
    });

    try {
      final uploadRes = await ApiService.uploadDocuments(selectedFiles);
      if (uploadRes["success"] != true) throw Exception(uploadRes["message"]);
      final int requestId = uploadRes["verificationId"];

      setState(() {
        stage = AppStage.ocr;
        activeStageIndex = 1;
      });
      final ocrRes = await ApiService.ocrAnalysis(requestId);
      if (ocrRes["success"] != true) throw Exception(ocrRes["message"]);

      setState(() {
        stage = AppStage.validating;
        activeStageIndex = 2;
      });
      final valRes = await ApiService.validationAndAIAnalysis(requestId);
      if (valRes["success"] != true) throw Exception(valRes["message"]);

      setState(() {
        stage = AppStage.result;
        verdict = valRes["result"];
      });
    } catch (e) {
      setState(() {
        stage = AppStage.error;
        errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      decoration: const BoxDecoration(
        gradient: AppColors.gradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.shield, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              const Text(
                "Probashi Shield",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            "Verify your job offer & documents securely",
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (stage) {
      case AppStage.upload:
        return _buildUploadUI();
      case AppStage.uploading:
      case AppStage.ocr:
      case AppStage.validating:
        return _buildLoader();
      case AppStage.result:
        return _buildResult();
      case AppStage.error:
        return _buildErrorUI();
    }
  }

  Widget _buildUploadUI() {
    return ListView(
      key: const ValueKey("upload"),
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          "Document Type",
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: docTypes.map((t) {
            final selected = documentType == t["value"];
            return ChoiceChip(
              label: Text(t["label"]),
              avatar: Icon(
                t["icon"],
                size: 18,
                color: selected ? Colors.white : AppColors.primary,
              ),
              selected: selected,
              onSelected: (_) => setState(() => documentType = t["value"]),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: selected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: selected ? AppColors.primary : Colors.grey.shade300,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        const Text(
          "Upload Files",
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _actionCard(
                icon: Icons.camera_alt,
                label: "Take Photo",
                onTap: () => pickImage(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionCard(
                icon: Icons.photo_library,
                label: "Gallery",
                onTap: () => pickImage(ImageSource.gallery),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (selectedFiles.isNotEmpty) ...[
          Text(
            "Selected (${selectedFiles.length})",
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.15,
            ),
            itemCount: selectedFiles.length,
            itemBuilder: (ctx, i) {
              final f = selectedFiles[i];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.insert_drive_file,
                      size: 30,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      f.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        f.documentType,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => removeFile(i),
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
        ElevatedButton.icon(
          onPressed: selectedFiles.isEmpty ? null : startUpload,
          icon: const Icon(Icons.cloud_upload),
          label: const Text("Upload Documents"),
        ),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoader() {
    final labels = ["Uploading", "OCR Extract", "AI Validate"];
    final icons = [
      Icons.cloud_upload,
      Icons.document_scanner,
      Icons.verified_user,
    ];
    return Padding(
      key: const ValueKey("loader"),
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(3, (i) {
              final done = i < activeStageIndex;
              final active = i == activeStageIndex;
              return Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: done || active ? AppColors.gradient : null,
                      color: done || active ? null : Colors.grey.shade200,
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.4),
                                blurRadius: 14,
                                spreadRadius: 2,
                              ),
                            ]
                          : [],
                    ),
                    child: Icon(
                      done ? Icons.check : icons[i],
                      color: done || active ? Colors.white : Colors.grey,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: done || active ? AppColors.primary : Colors.grey,
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 36),
          const CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          Text(
            activeStageIndex == 0
                ? "Uploading your documents securely..."
                : activeStageIndex == 1
                ? "Extracting text with OCR..."
                : "Running AI fraud detection...",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final v = verdict!;
    final String verdictText = (v["verdict"] ?? v["Verdict"] ?? "").toString();
    final List reasons = v["reasonsBangla"] ?? v["ReasonsBangla"] ?? [];
    final String suggestion =
        v["suggestedAction"] ?? v["SuggestedAction"] ?? "-";
    final String bngRec =
        v["bngRecommendation"] ?? v["BngRecommendation"] ?? "";

    final lower = verdictText.toLowerCase();
    final Color badgeColor = lower.contains("verified")
        ? AppColors.success
        : lower.contains("caution")
        ? AppColors.warning
        : AppColors.danger;
    final IconData badgeIcon = lower.contains("verified")
        ? Icons.check_circle
        : lower.contains("caution")
        ? Icons.warning_amber
        : Icons.dangerous;

    return ListView(
      key: const ValueKey("result"),
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(badgeIcon, color: badgeColor, size: 34),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  verdictText,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _resultSection(
          "কারণ (Reasons)",
          Icons.info_outline,
          reasons.isEmpty ? ["-"] : reasons.map((r) => r.toString()).toList(),
        ),
        _resultSection("Suggested Action", Icons.lightbulb_outline, [
          suggestion,
        ]),
        if (bngRec.isNotEmpty)
          _resultSection(
            "AI Recommendation (বাংলা)",
            Icons.smart_toy_outlined,
            [bngRec],
          ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: resetAll,
          icon: const Icon(Icons.refresh),
          label: const Text("Upload Another"),
        ),
      ],
    );
  }

  Widget _resultSection(String title, IconData icon, List<String> lines) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...lines.map(
            (l) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                "•  $l",
                style: const TextStyle(fontSize: 13.5, height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorUI() {
    return Center(
      key: const ValueKey("error"),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                color: AppColors.danger,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              errorMessage ?? "Something went wrong",
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: resetAll,
              icon: const Icon(Icons.refresh),
              label: const Text("Try Again"),
            ),
          ],
        ),
      ),
    );
  }
}
