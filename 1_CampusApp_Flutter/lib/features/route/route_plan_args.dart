/// 地图展示页 → 路线规划页 的参数封装
class RoutePlanArgs {
  final int? startId;
  final int? endId;
  final List<int> waypointIds;
  final String? endName;
  final bool autoPlan;

  const RoutePlanArgs({
    this.startId,
    this.endId,
    this.waypointIds = const [],
    this.endName,
    this.autoPlan = false,
  });

  bool get canAutoPlan =>
      startId != null && endId != null && startId != endId;

  Map<String, dynamic> toMap() => {
        if (endName != null && endName!.isNotEmpty) 'endName': endName,
        if (startId != null) 'startId': startId,
        if (endId != null) 'endId': endId,
        if (waypointIds.isNotEmpty) 'waypointIds': waypointIds,
        'autoPlan': autoPlan || canAutoPlan,
      };

  static RoutePlanArgs? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    return RoutePlanArgs(
      startId: _parseInt(map['startId']),
      endId: _parseInt(map['endId']),
      waypointIds: _parseIntList(map['waypointIds']) ?? const [],
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
    return value
        .map((e) => _parseInt(e))
        .whereType<int>()
        .toList();
  }
}
