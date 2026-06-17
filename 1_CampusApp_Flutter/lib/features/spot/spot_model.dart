// lib/features/spot/spot_model.dart

class SpotModel {
  final int id;
  final String name;
  final String description;
  final double latitude;
  final double longitude;
  final String category;
  final int visitCount;

  // 多媒体相关字段
  final String coverImage;
  final List<String> images;
  final String? videoUrl;
  final double rating;

  SpotModel({
    required this.id,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.category,

    this.visitCount = 0,

    this.coverImage = '',
    this.images = const [],
    this.videoUrl,
    this.rating = 0.0,
  });

  factory SpotModel.fromJson(Map<String, dynamic> json) {
    // 处理后端以逗号分隔的图片组字符串
    List<String> parsedImages = [];
    final String? imagesStr = json['images'];
    if (imagesStr != null && imagesStr.isNotEmpty) {
      parsedImages = imagesStr.split(',');
    }

    return SpotModel(
      id: json['id'],
      name: json['name'] ?? '未知景点',
      description: json['description'] ?? '暂无介绍',
      latitude: double.tryParse(json['latitude']?.toString() ?? '0') ?? 0.0,
      longitude: double.tryParse(json['longitude']?.toString() ?? '0') ?? 0.0,
      category: json['category'] ?? 'default',

      visitCount: json['visitCount'] ?? 0,

      coverImage: json['coverImage'] ?? '',
      images: parsedImages,
      videoUrl: json['videoUrl'],
      rating: double.tryParse(json['rating']?.toString() ?? '0') ?? 5.0,
    );
  }
}