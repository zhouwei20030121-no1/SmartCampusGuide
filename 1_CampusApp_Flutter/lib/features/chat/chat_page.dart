import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../cache/cache_service.dart';
import '../location/location_service.dart';
import '../spot/spot_model.dart';
import 'chat_api.dart';

const Color _schoolBlue = Color(0xFF023D83);

class ChatPage extends StatefulWidget {
  final String? initialPrompt;

  const ChatPage({super.key, this.initialPrompt});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final LocationService _locationService = LocationService();
  List<SpotModel> _spots = [];
  String _routeStatus = '暂无路线';
  String _persona = '新生';
  _RouteTarget? _focusedRouteTarget;
  final _messages = <_ChatMsg>[
    const _ChatMsg(
      text: '你好，我是西小导。你可以问我校园建筑、路线、校史文化或参观建议，我会结合上下文连续回答。',
      isMe: false,
    ),
  ];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadContextData();
    final prompt = widget.initialPrompt;
    if (prompt != null && prompt.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _sendText(prompt));
    }
  }

  Future<void> _loadContextData() async {
    var records = await CacheService.getCachedSpots();
    if (records.isEmpty) {
      await CacheService.preloadSpots();
      records = await CacheService.getCachedSpots();
    }
    if (!mounted) return;
    setState(() {
      _spots = records.map((item) => SpotModel.fromJson(item)).toList();
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    await _sendText(text);
  }

  Future<void> _sendText(String text) async {
    if (text.isEmpty || _sending) return;
    final mentionedTarget = _extractMentionedRouteTarget(text);

    final routeResponse = _buildRouteAgentResponse(text);
    if (routeResponse != null) {
      setState(() {
        _messages.add(_ChatMsg(text: text, isMe: true));
        _messages.add(
          _ChatMsg(
            text: routeResponse.message,
            isMe: false,
            routePlan: routeResponse.plan,
          ),
        );
        if (routeResponse.plan != null) {
          _focusedRouteTarget = routeResponse.plan!.destination;
          _routeStatus =
              '${routeResponse.plan!.startLabel} -> ${routeResponse.plan!.destination.destination}';
        } else if (mentionedTarget != null) {
          _focusedRouteTarget = mentionedTarget;
        }
      });
      _msgCtrl.clear();
      _scrollToBottom();
      return;
    }

    final history = _messages
        .where((msg) => !msg.isLoading)
        .map(
          (msg) => {
            'role': msg.isMe ? 'user' : 'assistant',
            'content': msg.text,
          },
        )
        .toList();

    setState(() {
      _sending = true;
      _messages.add(_ChatMsg(text: text, isMe: true));
      _messages.add(
        const _ChatMsg(text: '西小导正在检索校园知识库...', isMe: false, isLoading: true),
      );
    });
    _msgCtrl.clear();
    _scrollToBottom();

    try {
      final result = await ChatApi.sendMessage(
        query: text,
        history: history,
        persona: _persona,
        context: _buildEnvironmentContext(),
      );
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((msg) => msg.isLoading);
        _messages.add(
          _ChatMsg(
            text: result.reply,
            isMe: false,
            sources: result.sources,
            fallback: result.fallback,
            model: result.model,
          ),
        );
        _focusedRouteTarget =
            _routeTargetFromSources(result.sources) ??
            _extractMentionedRouteTarget('$text\n${result.reply}') ??
            mentionedTarget ??
            _focusedRouteTarget;
        _sending = false;
      });
    } on ChatApiException catch (e) {
      if (!mounted) return;
      final msg = e.message;
      String friendlyMsg;
      if (msg.contains('连接失败') ||
          msg.contains('Connection refused') ||
          msg.contains('5000')) {
        friendlyMsg = '无法连接西小导服务，请确认 Python AI 服务已在 5000 端口启动。';
      } else if (msg.contains('格式异常') || msg.contains('Format')) {
        friendlyMsg = '西小导服务返回格式异常，请检查 AI 服务日志。';
      } else {
        friendlyMsg = msg;
      }
      setState(() {
        _messages.removeWhere((msg) => msg.isLoading);
        _messages.add(_ChatMsg(text: friendlyMsg, isMe: false, isError: true));
        _sending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((msg) => msg.isLoading);
        _messages.add(
          const _ChatMsg(
            text: '当前使用本地知识库兜底回答，部分生成式能力可能受限，请稍后重试。',
            isMe: false,
            isError: true,
          ),
        );
        _sending = false;
      });
    }
    _scrollToBottom();
  }

  Map<String, dynamic> _buildEnvironmentContext() {
    final now = DateTime.now();
    final hasLocation =
        _locationService.isTracking &&
        _locationService.latitude != 0.0 &&
        _locationService.longitude != 0.0;
    return {
      'latitude': hasLocation
          ? _locationService.latitude.toStringAsFixed(6)
          : '未获取',
      'longitude': hasLocation
          ? _locationService.longitude.toStringAsFixed(6)
          : '未获取',
      'nearby_spot': _locationService.nearbySpot.isNotEmpty
          ? '${_locationService.nearbySpot}，约${_locationService.distance.toStringAsFixed(0)}米'
          : '暂无触发景点',
      'current_time': now.toIso8601String(),
      'weather': '未接入天气接口',
      'is_night': now.hour >= 19 || now.hour < 6,
      'user_speed': _locationService.isTracking ? '步行/模拟定位中' : '未知',
      'route_status': _routeStatus,
      'battery': '未接入电量接口',
      'network': '在线优先，失败时尝试内网穿透地址',
      'offline_cached': _spots.isNotEmpty,
    };
  }

  _RouteAgentResponse? _buildRouteAgentResponse(String text) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return null;

    final isNearestDining =
        cleaned.contains('最近') &&
        (cleaned.contains('食堂') ||
            cleaned.contains('吃饭') ||
            cleaned.contains('餐厅'));
    final hasRouteIntent = isNearestDining || _hasRouteIntent(cleaned);
    if (!hasRouteIntent) return null;

    final startInfo = _extractStart(cleaned);
    final destinationText = isNearestDining
        ? '最近的食堂'
        : _extractDestinationText(cleaned);

    if (destinationText == null || destinationText.isEmpty) {
      return const _RouteAgentResponse(
        message: '你想去哪里？请告诉我目的地，例如“去中心图书馆”或“从二号门到第八教学楼”。',
      );
    }

    final hasReliableLocation =
        _locationService.isTracking &&
        _locationService.latitude != 0.0 &&
        _locationService.longitude != 0.0;
    if (startInfo == null && !hasReliableLocation) {
      return _RouteAgentResponse(
        message: '你现在在哪？告诉我起点后我可以直接生成路线。也可以先开启定位，我会默认用当前位置作为起点。',
        plan: null,
      );
    }

    final destinationCandidates = isNearestDining
        ? _nearestDiningCandidates()
        : _findCandidateSpots(destinationText);
    if (destinationCandidates.length > 1 &&
        !_canAutoResolveDestination(destinationText, destinationCandidates)) {
      final names = destinationCandidates
          .take(4)
          .map((spot) => spot.name)
          .join('、');
      return _RouteAgentResponse(
        message: '“$destinationText”可能对应多个地点：$names。你想去哪个？',
      );
    }

    final destinationSpot = destinationCandidates.isNotEmpty
        ? _resolveDestination(destinationText, destinationCandidates)
        : null;
    final routeTarget = destinationSpot == null
        ? _normalizeRouteTarget(destinationText)
        : _RouteTarget(
            destination: destinationSpot.name,
            aliases: [destinationSpot.name, destinationText],
          );

    if (routeTarget == null) {
      return _RouteAgentResponse(
        message: '我还没识别出目的地。可以换成具体名称，例如“中心图书馆”“第25教学楼”。',
      );
    }

    final waypoints = _recommendWaypoints(cleaned, routeTarget.destination);
    final routeType = _routeTypeFor(cleaned, waypoints);
    var intro = _buildRouteIntro(destinationSpot, waypoints);
    if (destinationCandidates.length > 1) {
      final names = destinationCandidates
          .take(4)
          .map((spot) => spot.name)
          .join('、');
      intro = '$intro\n候选地点：$names；已先按最常用目的地生成路线，可继续追问切换。';
    }
    intro = '$intro\n如果地图步行路径暂不可达，路线规划会给出校内直连替代方案。';
    final startLabel = startInfo?.name ?? '当前位置';
    final startAliases = startInfo?.aliases ?? const [];

    return _RouteAgentResponse(
      message: '已生成 AI Agent 导航助手方案，可进入路线规划查看地图路径。',
      plan: _RoutePlan(
        startLabel: startLabel,
        startAliases: startAliases,
        destination: routeTarget,
        waypoints: waypoints,
        routeType: routeType,
        intro: intro,
      ),
    );
  }

  _RouteTarget? _extractRouteTarget(String text) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return null;
    final lower = cleaned.toLowerCase();
    const routeWords = [
      '导航到',
      '带我去',
      '怎么去',
      '怎么走',
      '如何去',
      '如何到',
      '路线',
      '去',
      'how to go',
      'how do i get to',
      'how can i get to',
      'go to',
      'navigate to',
      'directions to',
      'route to',
      'take me to',
    ];
    if (!routeWords.any((word) => lower.contains(word))) return null;

    var destination = '';
    final fromToMatch = RegExp(
      r'从.+?到(.+?)(怎么走|怎么去|如何去|如何到|路线|导航)?[？?。！!，,、\s]*$',
    ).firstMatch(cleaned);
    if (fromToMatch != null) {
      destination = fromToMatch.group(1) ?? '';
    }
    if (destination.isEmpty) {
      final directGoMatch = RegExp(
        r'^(?:我想|我要|我准备|我打算|帮我|请|麻烦你)?(?:去|到|前往|导航到|带我去)(.+?)[？?。！!，,、\s]*$',
      ).firstMatch(cleaned);
      destination = directGoMatch?.group(1) ?? '';
    }
    if (destination.isEmpty) {
      for (final word in [
        '导航到',
        '带我去',
        '怎么去',
        '怎么走',
        '如何去',
        '如何到',
        '去',
        '想去',
      ]) {
        final index = cleaned.indexOf(word);
        if (index >= 0) {
          destination = index == 0
              ? cleaned.substring(index + word.length)
              : cleaned.substring(0, index);
          break;
        }
      }
    }
    if (destination.isEmpty) {
      final englishMatch = RegExp(
        r'^(?:how\s+to\s+go(?:\s+to)?|how\s+(?:do|can)\s+i\s+get\s+to|go\s+to|navigate\s+to|directions\s+to|route\s+to|take\s+me\s+to)\s+(.+?)[?.!，,、\s]*$',
        caseSensitive: false,
      ).firstMatch(cleaned);
      destination = englishMatch?.group(1) ?? '';
    }
    if (destination.isEmpty) return null;

    destination = destination
        .replaceAll(RegExp(r'(怎么走|怎么去|如何去|如何到|路线|导航)$'), '')
        .replaceAll(RegExp(r'^[去到]'), '')
        .replaceAll(RegExp(r'[？?。！!，,、\s]'), '')
        .trim();
    return _normalizeRouteTarget(destination);
  }

  bool _hasRouteIntent(String text) {
    final lower = text.toLowerCase();
    const routeWords = [
      '导航到',
      '带我去',
      '怎么去',
      '怎么走',
      '如何去',
      '如何到',
      '路线',
      '想去',
      '去',
      'how to go',
      'how do i get to',
      'how can i get to',
      'go to',
      'navigate to',
      'directions to',
      'route to',
      'take me to',
    ];
    return routeWords.any((word) => lower.contains(word));
  }

  _RouteStart? _extractStart(String text) {
    final patterns = [
      RegExp(r'我在(.+?)(，|,|。|想去|去|到|$)'),
      RegExp(r'从(.+?)到'),
      RegExp(r'from\s+(.+?)\s+to\s+', caseSensitive: false),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      final value = match?.group(1)?.trim();
      if (value != null && value.isNotEmpty) {
        final target = _normalizeRouteTarget(value);
        return _RouteStart(
          name: target?.destination ?? value,
          aliases: target?.aliases ?? [value],
        );
      }
    }
    return null;
  }

  String? _extractDestinationText(String text) {
    final fromTo = RegExp(r'从.+?到(.+?)(，|,|。|顺便|$)').firstMatch(text);
    if (fromTo != null) {
      return _resolveContextualDestination(
        _cleanDestination(fromTo.group(1) ?? ''),
      );
    }

    final directGo = RegExp(
      r'^(?:我想|我要|我准备|我打算|帮我|请|麻烦你)?(?:去|到|前往|导航到|带我去)(.+?)(，|,|。|顺便|$)',
    ).firstMatch(text);
    if (directGo != null) {
      return _resolveContextualDestination(
        _cleanDestination(directGo.group(1) ?? ''),
      );
    }

    final wantTo = RegExp(r'想去(.+?)(，|,|。|顺便|$)').firstMatch(text);
    if (wantTo != null) {
      return _resolveContextualDestination(
        _cleanDestination(wantTo.group(1) ?? ''),
      );
    }

    final routeTarget = _extractRouteTarget(text);
    return _resolveContextualDestination(routeTarget?.destination ?? '');
  }

  String _cleanDestination(String value) {
    return value
        .replaceAll(RegExp(r'(怎么走|怎么去|如何去|如何到|路线|导航|看看.*|吧|一下)$'), '')
        .replaceAll(RegExp(r'^[去到]'), '')
        .replaceAll(RegExp(r'[？?。！!，,、\s]+$'), '')
        .trim();
  }

  String? _resolveContextualDestination(String destination) {
    final cleaned = _cleanDestination(destination);
    if (cleaned.isEmpty) return null;
    if (_isContextReference(cleaned)) {
      return _focusedRouteTarget?.destination;
    }
    return cleaned;
  }

  bool _isContextReference(String value) {
    final normalized = _normalizeRouteAlias(
      value,
    ).replaceAll('目标', '').replaceAll('目的地', '').replaceAll('位置', '');
    const references = {
      '这个地方',
      '这个地点',
      '这个楼',
      '这栋楼',
      '这',
      '这个',
      '这里',
      '这儿',
      '此处',
      '那',
      '那个',
      '那里',
      '那儿',
      '那个地方',
      '那个地点',
      '它',
      '他',
      '她',
    };
    return references.contains(normalized);
  }

  _RouteTarget? _extractMentionedRouteTarget(String text) {
    final candidates = <_RouteTarget>[];
    final normalizedText = _normalizeRouteAlias(text);
    for (final target in _knownRouteTargets) {
      if (target.aliases.any((alias) {
        final normalizedAlias = _normalizeRouteAlias(alias);
        return normalizedAlias.isNotEmpty &&
            normalizedText.contains(normalizedAlias);
      })) {
        candidates.add(target);
      }
    }

    for (final spot in _spots) {
      final name = _normalizeRouteAlias(spot.name);
      if (name.isNotEmpty && normalizedText.contains(name)) {
        candidates.add(
          _RouteTarget(destination: spot.name, aliases: [spot.name]),
        );
      }
    }

    if (candidates.isEmpty) return null;
    candidates.sort(
      (a, b) => b.destination.length.compareTo(a.destination.length),
    );
    return candidates.first;
  }

  _RouteTarget? _routeTargetFromSources(List<String> sources) {
    for (final source in sources) {
      final text = source.trim();
      if (text.isEmpty) {
        continue;
      }
      final target = _extractMentionedRouteTarget(text);
      if (target != null) return target;
    }
    return null;
  }

  List<SpotModel> _findCandidateSpots(String keyword) {
    final normalizedKeyword = _normalizeName(keyword);
    if (normalizedKeyword.isEmpty) return const [];
    final candidates = _spots.where((spot) {
      final normalizedName = _normalizeName(spot.name);
      return normalizedName.contains(normalizedKeyword) ||
          normalizedKeyword.contains(normalizedName);
    }).toList();
    candidates.sort((a, b) => a.name.length.compareTo(b.name.length));
    return candidates;
  }

  bool _canAutoResolveDestination(String keyword, List<SpotModel> candidates) {
    final normalized = _normalizeName(keyword);
    return normalized == '图书馆' &&
        candidates.any((spot) => spot.name.contains('中心图书馆'));
  }

  SpotModel? _resolveDestination(String keyword, List<SpotModel> candidates) {
    if (candidates.isEmpty) return null;
    final normalized = _normalizeName(keyword);
    if (normalized == '图书馆') {
      return candidates.firstWhere(
        (spot) => spot.name.contains('中心图书馆'),
        orElse: () => candidates.first,
      );
    }
    return candidates.first;
  }

  List<SpotModel> _nearestDiningCandidates() {
    final diningSpots = _spots.where((spot) {
      return spot.name.contains('食堂') ||
          spot.name.contains('餐厅') ||
          spot.description.contains('食堂') ||
          spot.description.contains('餐饮');
    }).toList();
    if (diningSpots.isEmpty) return const [];
    diningSpots.sort(
      (a, b) => _distanceToCurrent(a).compareTo(_distanceToCurrent(b)),
    );
    return diningSpots.take(3).toList();
  }

  List<_RouteWaypoint> _recommendWaypoints(String query, String destination) {
    final wantsHistory =
        query.contains('历史') ||
        query.contains('历史感') ||
        query.contains('校史') ||
        query.contains('文化');
    if (!wantsHistory) return const [];

    final candidates = _spots
        .where((spot) {
          if (spot.name == destination) return false;
          return spot.category.contains('历史') ||
              spot.name.contains('雨僧') ||
              spot.name.contains('行署') ||
              spot.name.contains('博物馆') ||
              spot.description.contains('历史');
        })
        .take(2);
    return candidates
        .map(
          (spot) => _RouteWaypoint(
            name: spot.name,
            description: _shortDescription(spot),
          ),
        )
        .toList();
  }

  String _routeTypeFor(String query, List<_RouteWaypoint> waypoints) {
    if (waypoints.isNotEmpty) return '历史文化顺路游览';
    if (query.contains('最近')) return '就近推荐路线';
    return '步行导航路线';
  }

  String _buildRouteIntro(
    SpotModel? destination,
    List<_RouteWaypoint> waypoints,
  ) {
    final pieces = <String>[];
    if (destination != null) {
      pieces.add('${destination.name}：${_shortDescription(destination)}');
    }
    for (final waypoint in waypoints) {
      pieces.add('${waypoint.name}：${waypoint.description}');
    }
    return pieces.isEmpty ? '进入路线规划后会展示地图路径和步行路线。' : pieces.join('\n');
  }

  String _shortDescription(SpotModel spot) {
    final text = spot.description.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.length <= 80) return text;
    return '${text.substring(0, 80)}...';
  }

  double _distanceToCurrent(SpotModel spot) {
    final lat = _locationService.latitude;
    final lng = _locationService.longitude;
    if (lat == 0.0 || lng == 0.0) return double.infinity;
    const r = 6371000;
    final lat1 = lat * math.pi / 180;
    final lat2 = spot.latitude * math.pi / 180;
    final deltaLat = (spot.latitude - lat) * math.pi / 180;
    final deltaLng = (spot.longitude - lng) * math.pi / 180;
    final a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLng / 2) *
            math.sin(deltaLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  String _normalizeName(String value) {
    return value
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('西南大学', '')
        .replaceAll('北碚校区', '')
        .replaceAll('（', '')
        .replaceAll('）', '')
        .replaceAll('(', '')
        .replaceAll(')', '')
        .replaceAll('中心', '')
        .toLowerCase();
  }

  String _normalizeRouteAlias(String value) {
    return _normalizeName(value)
        .replaceAll('学院', '院')
        .replaceAll('教学楼', '教')
        .replaceAll('第', '')
        .replaceAll('号', '')
        .replaceAll('（', '')
        .replaceAll('）', '')
        .replaceAll('(', '')
        .replaceAll(')', '');
  }

  List<_RouteTarget> get _knownRouteTargets => const [
    _RouteTarget(
      destination: '计算机与信息科学学院 软件学院',
      aliases: [
        '计算机与信息科学学院 软件学院',
        '计算机与信息科学学院',
        '计算机学院',
        '计信院',
        '软件学院',
        '明德楼',
        '第25教学楼',
        '二十五教',
        '25教',
        'jixinyuan',
        'jxy',
      ],
    ),
    _RouteTarget(
      destination: '物理科学与技术学院',
      aliases: ['物理科学与技术学院', '物理学院', '物院', '立惠楼', '第13教学楼', '第十三教学楼', '13教'],
    ),
    _RouteTarget(destination: '中心图书馆', aliases: ['中心图书馆', '图书馆', '图书馆中心馆']),
    _RouteTarget(
      destination: '学行门（2号门）',
      aliases: ['学行门（2号门）', '学行门', '二号门', '2号门'],
    ),
    _RouteTarget(
      destination: '橘园',
      aliases: ['橘园', '桔园', '菊园', 'juyuan', 'jy'],
    ),
    _RouteTarget(destination: '杏园', aliases: ['杏园', 'xingyuan', 'xy']),
    _RouteTarget(destination: '行署楼A栋', aliases: ['行署楼A栋', '行署楼A', '行署楼']),
    _RouteTarget(destination: '袁隆平雕像', aliases: ['袁隆平雕像', '袁隆平像', '袁隆平']),
  ];

  _RouteTarget? _normalizeRouteTarget(String destination) {
    if (destination.isEmpty) return null;
    final lower = destination.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), ' ');
    final compactLower = lower.replaceAll(' ', '');
    if (compactLower.contains('computercollege') ||
        compactLower.contains('computerscience') ||
        compactLower.contains('softwarecollege') ||
        compactLower.contains('cis') ||
        destination.contains('计算机学院') ||
        destination.contains('软件学院')) {
      return const _RouteTarget(
        destination: '计算机与信息科学学院 软件学院',
        aliases: [
          '计算机与信息科学学院 软件学院',
          '计算机学院',
          '软件学院',
          '明德楼',
          '第25教学楼',
          '25教',
          'computer college',
          'computer science college',
          'software college',
        ],
      );
    }
    if (compactLower.contains('physicalcollege') ||
        compactLower.contains('physicscollege') ||
        compactLower.contains('physics') ||
        destination.contains('物理学院') ||
        destination.contains('物理科学与技术学院')) {
      return const _RouteTarget(
        destination: '物理科学与技术学院',
        aliases: [
          '物理科学与技术学院',
          '物理学院',
          '立惠楼',
          '第13教学楼',
          '第十三教学楼',
          '13教',
          'physical college',
          'physics college',
          'physics',
        ],
      );
    }
    if (destination.contains('二号门') ||
        destination.contains('2号门') ||
        destination.contains('学行门')) {
      return const _RouteTarget(
        destination: '学行门（2号门）',
        aliases: ['学行门（2号门）', '学行门', '二号门', '2号门'],
      );
    }

    final arabicTeaching = RegExp(r'^第?(\d+)教(?:学楼)?$').firstMatch(destination);
    if (arabicTeaching != null) {
      return _teachingBuildingTarget(arabicTeaching.group(1)!);
    }

    final chineseTeaching = RegExp(
      r'^第?([一二两三四五六七八九十]+)教(?:学楼)?$',
    ).firstMatch(destination);
    if (chineseTeaching != null) {
      final number = chineseTeaching.group(1) ?? '';
      return _teachingBuildingTarget(number.replaceAll('两', '二'));
    }

    return _RouteTarget(destination: destination, aliases: [destination]);
  }

  _RouteTarget _teachingBuildingTarget(String number) {
    final normalizedNumber = number.replaceAll('两', '二');
    if (normalizedNumber == '2' || normalizedNumber == '二') {
      return const _RouteTarget(
        destination: '兰华楼（第2教学楼）',
        aliases: ['兰华楼（第2教学楼）', '兰华楼', '第2教学楼', '第二教学楼', '2教', '西塔学院'],
      );
    }
    if (normalizedNumber == '25' || normalizedNumber == '二十五') {
      return const _RouteTarget(
        destination: '计算机与信息科学学院 软件学院',
        aliases: ['计算机与信息科学学院 软件学院', '明德楼', '第25教学楼', '25教'],
      );
    }
    return _RouteTarget(
      destination: '第$normalizedNumber教学楼',
      aliases: ['第$normalizedNumber教学楼', '$normalizedNumber教'],
    );
  }

  void _openRoutePlan(_RoutePlan plan) {
    Navigator.pushNamed(
      context,
      AppRouter.routePlan,
      arguments: {
        'startName': plan.startLabel == '当前位置' ? null : plan.startLabel,
        'startAliases': plan.startAliases,
        'destinationName': plan.destination.destination,
        'destinationAliases': plan.destination.aliases,
        'autoPlan': true,
      },
    );
  }

  void _showVoiceInputSheet() {
    final voiceSamples = ['最近的食堂怎么走？', '第八教学楼在哪里？', '帮我规划一条参观校园的路线'];
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '语音输入模拟',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                '模拟器中先用语音样例代替真实录音，后续接入 ASR 后可替换为实时语音转文字。',
                style: TextStyle(color: AppTheme.textSub, fontSize: 13),
              ),
              const SizedBox(height: 12),
              for (final sample in voiceSamples)
                ListTile(
                  leading: const Icon(Icons.mic, color: _schoolBlue),
                  title: Text(sample),
                  onTap: () {
                    Navigator.pop(context);
                    _sendText(sample);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(color: AppTheme.pageBg),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                color: const Color(0xFFE0F2FE).withValues(alpha: 0.42),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _ChatStatusBar(
                  persona: _persona,
                  onPersonaChanged: (value) => setState(() => _persona = value),
                  onPromptSelected: _sendText,
                  disabled: _sending,
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) => _ChatBubble(
                      msg: _messages[i],
                      onRouteTap: _openRoutePlan,
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(bottom: 8),
                  child: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.76),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, -3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: '语音输入',
                              onPressed: _sending ? null : _showVoiceInputSheet,
                              icon: const Icon(Icons.mic_none_rounded),
                              color: _schoolBlue,
                            ),
                            Expanded(
                              child: TextField(
                                controller: _msgCtrl,
                                enabled: !_sending,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _send(),
                                decoration: InputDecoration(
                                  hintText: '问西小导任何问题...',
                                  filled: true,
                                  fillColor: Colors.white.withValues(
                                    alpha: 0.86,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide(
                                      color: _schoolBlue.withValues(
                                        alpha: 0.28,
                                      ),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: const BorderSide(
                                      color: _schoolBlue,
                                      width: 1.5,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            CircleAvatar(
                              backgroundColor: _sending
                                  ? Colors.grey.shade400
                                  : _schoolBlue,
                              child: IconButton(
                                icon: Icon(
                                  _sending
                                      ? Icons.hourglass_top_rounded
                                      : Icons.send,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                onPressed: _sending ? null : _send,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _schoolBlue,
                size: 18,
              ),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                '西小导 - AI 对话',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _schoolBlue,
                ),
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _ChatStatusBar extends StatelessWidget {
  final String persona;
  final ValueChanged<String> onPersonaChanged;
  final ValueChanged<String> onPromptSelected;
  final bool disabled;

  const _ChatStatusBar({
    required this.persona,
    required this.onPersonaChanged,
    required this.onPromptSelected,
    required this.disabled,
  });

  @override
  Widget build(BuildContext context) {
    final prompts = [
      '介绍一下计信院',
      '怎么去物理学院',
      '学校有什么特色美食？',
      '推荐一条校园参观路线',
      '校史馆什么时候开放？',
    ];
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.52),
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.psychology_alt,
                    color: _schoolBlue,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'RAG 知识库 + 多轮上下文',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: persona,
                      isDense: true,
                      items: const [
                        DropdownMenuItem(value: '新生', child: Text('新生')),
                        DropdownMenuItem(value: '游客', child: Text('游客')),
                        DropdownMenuItem(value: '校友', child: Text('校友')),
                      ],
                      onChanged: disabled
                          ? null
                          : (value) {
                              if (value != null) onPersonaChanged(value);
                            },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final prompt in prompts) ...[
                      ActionChip(
                        label: Text(prompt),
                        backgroundColor: Colors.white.withValues(alpha: 0.85),
                        side: BorderSide(
                          color: _schoolBlue.withValues(alpha: 0.18),
                        ),
                        onPressed: disabled
                            ? null
                            : () => onPromptSelected(prompt),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatMsg {
  final String text;
  final bool isMe;
  final bool isLoading;
  final bool isError;
  final bool fallback;
  final String model;
  final List<String> sources;
  final _RoutePlan? routePlan;

  const _ChatMsg({
    required this.text,
    required this.isMe,
    this.isLoading = false,
    this.isError = false,
    this.fallback = false,
    this.model = '',
    this.sources = const [],
    this.routePlan,
  });
}

class _ChatBubble extends StatelessWidget {
  final _ChatMsg msg;
  final ValueChanged<_RoutePlan>? onRouteTap;

  const _ChatBubble({required this.msg, this.onRouteTap});

  @override
  Widget build(BuildContext context) {
    final bubbleColor = msg.isMe
        ? _schoolBlue
        : msg.isError
        ? const Color(0xFFFFE4E6)
        : Colors.white.withValues(alpha: 0.86);
    final textColor = msg.isMe
        ? Colors.white
        : msg.isError
        ? const Color(0xFFBE123C)
        : AppTheme.textMain;

    return Align(
      alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: msg.isMe
                ? const Radius.circular(16)
                : const Radius.circular(4),
            bottomRight: msg.isMe
                ? const Radius.circular(4)
                : const Radius.circular(16),
          ),
          border: msg.isMe
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.72)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msg.text, style: TextStyle(color: textColor)),
            if (!msg.isMe && msg.routePlan != null) ...[
              const SizedBox(height: 12),
              _RouteActionCard(
                plan: msg.routePlan!,
                onTap: () => onRouteTap?.call(msg.routePlan!),
              ),
            ],
            if (msg.isLoading) ...[
              const SizedBox(height: 8),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _schoolBlue,
                ),
              ),
            ],
            if (!msg.isMe && msg.sources.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '参考：${msg.sources.take(2).join('、')}',
                style: TextStyle(
                  color: AppTheme.textSub.withValues(alpha: 0.85),
                  fontSize: 11,
                ),
              ),
            ],
            if (!msg.isMe && !msg.fallback && msg.model.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'AI 模型：${msg.model}',
                style: TextStyle(
                  color: AppTheme.textSub.withValues(alpha: 0.85),
                  fontSize: 11,
                ),
              ),
            ],
            if (!msg.isMe && msg.fallback) ...[
              const SizedBox(height: 4),
              const Text(
                '本地知识库兜底回答',
                style: TextStyle(color: _schoolBlue, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RouteTarget {
  final String destination;
  final List<String> aliases;

  const _RouteTarget({required this.destination, required this.aliases});
}

class _RouteStart {
  final String name;
  final List<String> aliases;

  const _RouteStart({required this.name, required this.aliases});
}

class _RouteWaypoint {
  final String name;
  final String description;

  const _RouteWaypoint({required this.name, required this.description});
}

class _RoutePlan {
  final String startLabel;
  final List<String> startAliases;
  final _RouteTarget destination;
  final List<_RouteWaypoint> waypoints;
  final String routeType;
  final String intro;

  const _RoutePlan({
    required this.startLabel,
    required this.startAliases,
    required this.destination,
    required this.waypoints,
    required this.routeType,
    required this.intro,
  });
}

class _RouteAgentResponse {
  final String message;
  final _RoutePlan? plan;

  const _RouteAgentResponse({required this.message, this.plan});
}

class _RouteActionCard extends StatelessWidget {
  final _RoutePlan plan;
  final VoidCallback onTap;

  const _RouteActionCard({required this.plan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _schoolBlue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _schoolBlue.withValues(alpha: 0.24)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: _schoolBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.route_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${plan.startLabel} → ${plan.destination.destination}',
                    style: const TextStyle(
                      color: _schoolBlue,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _RouteInfoLine(label: '路线类型', value: plan.routeType),
                  if (plan.waypoints.isNotEmpty)
                    _RouteInfoLine(
                      label: '中途推荐',
                      value: plan.waypoints.map((item) => item.name).join('、'),
                    ),
                  _RouteInfoLine(label: '地图路径', value: '点击进入路线规划查看'),
                  if (plan.intro.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      plan.intro,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSub,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _schoolBlue),
          ],
        ),
      ),
    );
  }
}

class _RouteInfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _RouteInfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        '$label：$value',
        style: const TextStyle(color: AppTheme.textSub, fontSize: 12),
      ),
    );
  }
}
