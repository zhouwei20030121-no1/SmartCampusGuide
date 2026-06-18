import 'dart:math' as math;

import '../spot/spot_model.dart';

/// 基于缓存景点坐标构建校园路网，离线 A* 寻路（与后端 RoutePlanServiceImpl 逻辑对齐）。
class OfflineRoutePlanner {
  static const double _earthRadius = 6371000.0;
  static const int _kNeighbors = 15;

  static double haversine(double lat1, double lng1, double lat2, double lng2) {
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return _earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _toRad(double deg) => deg * math.pi / 180;

  static bool _hasCoords(SpotModel s) =>
      s.latitude != 0 && s.longitude != 0;

  /// 构建 k 近邻路网边，供缓存与离线展示。
  static List<Map<String, dynamic>> buildGraphEdges(List<SpotModel> spots) {
    final valid = spots.where(_hasCoords).toList();
    final edges = <Map<String, dynamic>>[];
    for (final s1 in valid) {
      final neighbors = valid
          .where((s2) => s2.id != s1.id)
          .map((s2) => MapEntry(
                s2,
                haversine(s1.latitude, s1.longitude, s2.latitude, s2.longitude),
              ))
          .toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      for (final entry in neighbors.take(_kNeighbors)) {
        edges.add({
          'from_id': s1.id,
          'to_id': entry.key.id,
          'distance': entry.value,
        });
      }
    }
    return edges;
  }

  static List<SpotModel> planAdvancedRoute({
    required List<SpotModel> allSpots,
    required int startId,
    required int endId,
    List<int> waypoints = const [],
    String strategy = 'DISTANCE',
    String userIdentity = 'TOURIST',
  }) {
    final valid = allSpots.where(_hasCoords).toList();
    if (valid.isEmpty) return [];

    final pathSequence = <int>[startId];
    if (waypoints.isNotEmpty) {
      pathSequence.addAll(waypoints);
    }

    if (strategy.toUpperCase() == 'PERSONALIZED' && waypoints.isEmpty) {
      final start = _findById(valid, startId);
      final end = _findById(valid, endId);
      if (start != null && end != null) {
        for (final s in _findTopPersonaSpots(start, end, valid, userIdentity, 2)) {
          pathSequence.add(s.id);
        }
      }
    }
    pathSequence.add(endId);

    final finalPath = <SpotModel>[];
    for (var i = 0; i < pathSequence.length - 1; i++) {
      final segment = _aStarSegment(
        pathSequence[i],
        pathSequence[i + 1],
        valid,
        strategy,
        userIdentity,
      );
      if (segment.isEmpty) continue;
      if (finalPath.isEmpty) {
        finalPath.addAll(segment);
      } else {
        finalPath.addAll(segment.skip(1));
      }
    }
    return finalPath;
  }

  static SpotModel? _findById(List<SpotModel> spots, int id) {
    for (final s in spots) {
      if (s.id == id) return s;
    }
    return null;
  }

  static List<SpotModel> _findTopPersonaSpots(
    SpotModel start,
    SpotModel end,
    List<SpotModel> allSpots,
    String identity,
    int limit,
  ) {
    final baseDist =
        haversine(start.latitude, start.longitude, end.latitude, end.longitude);
    final vX = end.longitude - start.longitude;
    final vY = end.latitude - start.latitude;

    final candidates = allSpots
        .where((s) =>
            _hasCoords(s) && s.id != start.id && s.id != end.id)
        .where((s) {
          final distToStart = haversine(
              start.latitude, start.longitude, s.latitude, s.longitude);
          final distToEnd =
              haversine(s.latitude, s.longitude, end.latitude, end.longitude);
          if (distToStart + distToEnd > math.max(baseDist * 1.4, 500.0)) {
            return false;
          }
          final uX = s.longitude - start.longitude;
          final uY = s.latitude - start.latitude;
          return (vX * uX) + (vY * uY) >= 0;
        })
        .toList()
      ..sort((a, b) =>
          _personaScore(b, identity).compareTo(_personaScore(a, identity)));

    final best = candidates.take(limit).toList()
      ..sort((a, b) => haversine(start.latitude, start.longitude, a.latitude,
              a.longitude)
          .compareTo(haversine(
              start.latitude, start.longitude, b.latitude, b.longitude)));
    return best;
  }

  static double _personaScore(SpotModel spot, String identity) {
    var score = 0.0;
    final id = identity.toUpperCase();
    if (id == 'TOURIST') {
      score = spot.visitCount * spot.visitCount.toDouble();
    } else if (id == 'FRESHMAN') {
      score = spot.description.length.toDouble();
    } else if (id == 'ALUMNI') {
      score = 100000.0 / math.max(spot.id, 1);
    }
    if (_isPreferredCategory(spot, identity)) {
      score += 1000000.0;
    }
    return score;
  }

  static bool _isPreferredCategory(SpotModel spot, String identity) {
    final cat = spot.category.trim();
    final id = identity.toUpperCase();
    if (id == 'FRESHMAN') {
      return cat == '教学设施' || cat == '生活服务';
    } else if (id == 'TOURIST') {
      return cat == '自然景观' || cat == '历史建筑';
    } else if (id == 'ALUMNI') {
      return cat == '历史建筑' || cat == '校园文化';
    }
    return false;
  }

  static List<SpotModel> _aStarSegment(
    int startId,
    int endId,
    List<SpotModel> allSpots,
    String strategy,
    String userIdentity,
  ) {
    final startSpot = _findById(allSpots, startId);
    final endSpot = _findById(allSpots, endId);
    if (startSpot == null || endSpot == null) return [];

    if (strategy.toUpperCase() == 'DISTANCE') {
      return [startSpot, endSpot];
    }

    var maxScore = 1.0;
    if (strategy.toUpperCase() == 'PERSONALIZED') {
      for (final s in allSpots) {
        final sc = _personaScore(s, userIdentity);
        if (sc > maxScore) maxScore = sc;
      }
    }

    final nodeMap = <int, _Node>{};
    for (final s in allSpots) {
      nodeMap[s.id] = _Node(s)..gCost = double.infinity;
    }

    final graph = <int, List<_Node>>{};
    for (final s1 in allSpots) {
      if (!_hasCoords(s1)) continue;
      final neighbors = allSpots
          .where((s2) => s2.id != s1.id && _hasCoords(s2))
          .map((s2) => MapEntry(
                s2,
                haversine(
                    s1.latitude, s1.longitude, s2.latitude, s2.longitude),
              ))
          .toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      graph[s1.id] = neighbors
          .take(_kNeighbors)
          .map((e) => nodeMap[e.key.id]!)
          .toList();
    }

    final openSet = PriorityQueue<_Node>((a, b) => a.fCost.compareTo(b.fCost));
    final closedSet = <int>{};

    final startNode = nodeMap[startId]!;
    startNode
      ..gCost = 0
      ..hCost = haversine(startSpot.latitude, startSpot.longitude,
          endSpot.latitude, endSpot.longitude);
    openSet.add(startNode);

    while (openSet.isNotEmpty) {
      final current = openSet.removeFirst();
      if (current.spot.id == endId) {
        return _reconstructPath(current);
      }
      closedSet.add(current.spot.id);

      for (final neighbor in graph[current.spot.id] ?? const []) {
        if (closedSet.contains(neighbor.spot.id)) continue;

        final physicalDistance = haversine(
          current.spot.latitude,
          current.spot.longitude,
          neighbor.spot.latitude,
          neighbor.spot.longitude,
        );
        var moveCost = physicalDistance;

        final strat = strategy.toUpperCase();
        if (strat == 'TIME') {
          final cat = neighbor.spot.category;
          if (cat == '生活服务') {
            moveCost += 20000.0;
          } else if (cat == '教学设施') {
            moveCost += 10000.0;
          }
        } else if (strat == 'PERSONALIZED') {
          final score = _personaScore(neighbor.spot, userIdentity);
          final discount = math.max(0.01, 1.0 - (score / maxScore));
          moveCost = physicalDistance * discount;
        }

        final tentativeG = current.gCost + moveCost;
        if (tentativeG < neighbor.gCost) {
          neighbor
            ..parent = current
            ..gCost = tentativeG
            ..hCost = haversine(
              neighbor.spot.latitude,
              neighbor.spot.longitude,
              endSpot.latitude,
              endSpot.longitude,
            );
          openSet.remove(neighbor);
          openSet.add(neighbor);
        }
      }
    }
    return [startSpot, endSpot];
  }

  static List<SpotModel> _reconstructPath(_Node endNode) {
    final path = <SpotModel>[];
    _Node? curr = endNode;
    while (curr != null) {
      path.add(curr.spot);
      curr = curr.parent;
    }
    return path.reversed.toList();
  }
}

class _Node {
  _Node(this.spot);

  final SpotModel spot;
  double gCost = double.infinity;
  double hCost = 0;
  _Node? parent;

  double get fCost => gCost + hCost;
}

/// 简易优先队列（无额外依赖）。
class PriorityQueue<T> {
  PriorityQueue(this._compare);

  final int Function(T a, T b) _compare;
  final List<T> _heap = [];

  bool get isNotEmpty => _heap.isNotEmpty;

  void add(T item) {
    _heap.add(item);
    _bubbleUp(_heap.length - 1);
  }

  void remove(T item) {
    final index = _heap.indexOf(item);
    if (index < 0) return;
    final last = _heap.removeLast();
    if (index < _heap.length) {
      _heap[index] = last;
      _bubbleUp(index);
      _bubbleDown(index);
    }
  }

  T removeFirst() {
    final first = _heap.first;
    final last = _heap.removeLast();
    if (_heap.isNotEmpty) {
      _heap[0] = last;
      _bubbleDown(0);
    }
    return first;
  }

  void _bubbleUp(int index) {
    while (index > 0) {
      final parent = (index - 1) >> 1;
      if (_compare(_heap[index], _heap[parent]) >= 0) break;
      final tmp = _heap[index];
      _heap[index] = _heap[parent];
      _heap[parent] = tmp;
      index = parent;
    }
  }

  void _bubbleDown(int index) {
    while (true) {
      final left = index * 2 + 1;
      final right = left + 1;
      var smallest = index;
      if (left < _heap.length &&
          _compare(_heap[left], _heap[smallest]) < 0) {
        smallest = left;
      }
      if (right < _heap.length &&
          _compare(_heap[right], _heap[smallest]) < 0) {
        smallest = right;
      }
      if (smallest == index) break;
      final tmp = _heap[index];
      _heap[index] = _heap[smallest];
      _heap[smallest] = tmp;
      index = smallest;
    }
  }
}
