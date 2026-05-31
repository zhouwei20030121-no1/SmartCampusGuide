// 文件路径: lib/features/spot/spot_model.dart

class SpotModel {
  final int id;
  final String name;
  final String description;
  final double latitude;
  final double longitude;
  final String category;

  SpotModel({
    required this.id,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.category,
  });

  factory SpotModel.fromJson(Map<String, dynamic> json) {
    return SpotModel(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      // 兼容 BigDecimal 传过来的 String 或 num，防止解析报错
      latitude: double.tryParse(json['latitude']?.toString() ?? '0') ?? 0.0,
      longitude: double.tryParse(json['longitude']?.toString() ?? '0') ?? 0.0,
      category: json['category'] ?? 'default',
    );
  }
}