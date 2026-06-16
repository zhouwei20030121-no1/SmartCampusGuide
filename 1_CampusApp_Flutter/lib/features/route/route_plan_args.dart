/// 地图展示页 → 路线规划页 的参数封装
class RoutePlanArgs {
  final int? startId;
  final int? endId;
  final List<int> waypointIds;
  final String? startName;
  final List<String> startAliases;
  final String? destinationName;
  final List<String> destinationAliases;
  final String? endName;
  final bool autoPlan;

  const RoutePlanArgs({
    this.startId,
    this.endId,
    this.waypointIds = const [],
    this.startName,
    this.startAliases = const [],
    this.destinationName,
    this.destinationAliases = const [],
    this.endName,
    this.autoPlan = false,
  });

  bool get canAutoPlan => startId != null && endId != null && startId != endId;

  bool get hasDestination =>
      endId != null ||
      (destinationName != null && destinationName!.isNotEmpty) ||
      (endName != null && endName!.isNotEmpty);

  Map<String, dynamic> toMap() => {
    if (endName != null && endName!.isNotEmpty) 'endName': endName,
    if (startId != null) 'startId': startId,
    if (endId != null) 'endId': endId,
    if (waypointIds.isNotEmpty) 'waypointIds': waypointIds,
    if (startName != null && startName!.isNotEmpty) 'startName': startName,
    if (startAliases.isNotEmpty) 'startAliases': startAliases,
    if (destinationName != null && destinationName!.isNotEmpty)
      'destinationName': destinationName,
    if (destinationAliases.isNotEmpty) 'destinationAliases': destinationAliases,
    'autoPlan': autoPlan || canAutoPlan,
  };

  static RoutePlanArgs? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    return RoutePlanArgs(
      startId: _parseInt(map['startId']),
      endId: _parseInt(map['endId']),
      waypointIds: _parseIntList(map['waypointIds']) ?? const [],
      startName: map['startName']?.toString(),
      startAliases: _parseStringList(map['startAliases']) ?? const [],
      destinationName:
          map['destinationName']?.toString() ?? map['endName']?.toString(),
      destinationAliases:
          _parseStringList(map['destinationAliases']) ?? const [],
      endName: map['endName']?.toString(),
      autoPlan: map['autoPlan'] == true,
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static List<int>? _parseIntList(dynamic value) {
    if (value is! List) return null;
    return value.map((e) => _parseInt(e)).whereType<int>().toList();
  }

  static List<String>? _parseStringList(dynamic value) {
    if (value is! List) return null;
    return value
        .map((e) => e?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }
}
