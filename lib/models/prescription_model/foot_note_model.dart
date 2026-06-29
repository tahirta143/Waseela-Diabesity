class FootNoteModel {
  final int id;
  final String mrNumber;
  final String? receiptId;
  final String doctorName;
  final String? description;
  final String createdAt;
  final List<FootNoteImageModel> images;

  FootNoteModel({
    required this.id,
    required this.mrNumber,
    this.receiptId,
    required this.doctorName,
    this.description,
    required this.createdAt,
    required this.images,
  });

  factory FootNoteModel.fromJson(Map<String, dynamic> json) {
    var list = json['images'] as List? ?? [];
    List<FootNoteImageModel> imageList = list.map((i) => FootNoteImageModel.fromJson(i)).toList();

    return FootNoteModel(
      id: json['id'] ?? 0,
      mrNumber: json['mr_number'] ?? '',
      receiptId: json['receipt_id']?.toString(),
      doctorName: json['doctor_name'] ?? json['recorded_by'] ?? '',
      description: json['description'],
      createdAt: json['created_at'] ?? '',
      images: imageList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mr_number': mrNumber,
      'receipt_id': receiptId,
      'doctor_name': doctorName,
      'description': description,
      'created_at': createdAt,
      'images': images.map((i) => i.toJson()).toList(),
    };
  }
}

class FootNoteImageModel {
  final int id;
  final String url;
  final String fileName;

  FootNoteImageModel({
    required this.id,
    required this.url,
    required this.fileName,
  });

  factory FootNoteImageModel.fromJson(Map<String, dynamic> json) {
    return FootNoteImageModel(
      id: json['id'] ?? 0,
      url: json['url'] ?? '',
      fileName: json['file_name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'file_name': fileName,
    };
  }
}
