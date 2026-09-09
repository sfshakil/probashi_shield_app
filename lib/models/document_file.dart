class DocumentFile {
  final String fileName;
  final int fileSize;
  final String fileData; // base64 with data URI prefix
  final String documentType;

  DocumentFile({
    required this.fileName,
    required this.fileSize,
    required this.fileData,
    required this.documentType,
  });

  Map<String, dynamic> toJson() => {
    "fileName": fileName,
    "fileSize": fileSize,
    "fileData": fileData,
    "documentType": documentType,
  };
}
