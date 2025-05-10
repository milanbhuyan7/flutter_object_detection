class CustomModel {
  final String name;
  final String description;
  final bool isCustom;
  final String? filePath;

  CustomModel({
    required this.name,
    required this.description,
    this.isCustom = false,
    this.filePath,
  });

  factory CustomModel.fromMap(Map<String, dynamic> map) {
    return CustomModel(
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      isCustom: map['isCustom'] as bool? ?? false,
      filePath: map['filePath'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'isCustom': isCustom,
      'filePath': filePath,
    };
  }
}