import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/network/network_client.dart';
import '../../core/theme/app_theme.dart';
import '../location/location_service.dart';

class BusSchedulePage extends StatefulWidget {
  const BusSchedulePage({super.key});

  @override
  State<BusSchedulePage> createState() => _BusSchedulePageState();
}

class _BusSchedulePageState extends State<BusSchedulePage> {
  final LocationService _locationService = LocationService();
  final TextEditingController _fromCtrl = TextEditingController();
  final TextEditingController _toCtrl = TextEditingController();
  final TextEditingController _assistantCtrl = TextEditingController();

  List<dynamic> _lines = [];
  Map<String, dynamic>? _nearest;
  Map<String, dynamic>? _plan;
  Map<String, dynamic>? _activeReminder;
  String _assistantReply = '';
  bool _loading = true;
  bool _planning = false;
  bool _asking = false;
  int? _expandedIndex;
  int _tabIndex = 0;
  String _preference = 'fastest';
  String _reminderNotice = '';

  static const Map<String, List<double>> _fallbackStationCoords = {
    '一号门': [29.8198, 106.4310],
    '二号门': [29.8218, 106.4218],
    '五号门': [29.8174, 106.4206],
    '中心图书馆': [29.8235, 106.4308],
    '八教': [29.8230, 106.4260],
    '共青团花园': [29.8210, 106.4270],
    '竹园': [29.8150, 106.4220],
    '大礼堂': [29.8224, 106.4254],
    '田家炳': [29.8205, 106.4240],
    '音乐学院': [29.8178, 106.4285],
  };

  @override
  void initState() {
    super.initState();
    _locationService.addListener(_handleLocationChanged);
    _load();
    _locationService.startTracking();
  }

  @override
  void dispose() {
    _locationService.removeListener(_handleLocationChanged);
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _assistantCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await NetworkClient.dio.get('/bus/lines');
      if (res.data['code'] == 200) {
        _lines = res.data['data'] ?? [];
      }
    } catch (_) {
      _lines = _mockData();
    } finally {
      if (_lines.isEmpty) _lines = _mockData();
      if (mounted) setState(() => _loading = false);
    }
    await _loadNearest();
  }

  Future<void> _loadNearest() async {
    try {
      final res = await NetworkClient.dio.get('/bus/nearest', queryParameters: {
        'lat': _locationService.latitude,
        'lng': _locationService.longitude,
      });
      if (res.data['code'] == 200 && mounted) {
        final data = Map<String, dynamic>.from(res.data['data'] ?? {});
        setState(() => _nearest = data['available'] == true ? data : _nearestFromLocal());
      }
    } catch (_) {
      if (mounted) setState(() => _nearest = _nearestFromLocal());
    }
  }

  void _handleLocationChanged() {
    final localNearest = _nearestFromLocal();
    if (localNearest['available'] == true && mounted) {
      setState(() => _nearest = localNearest);
    }

    final reminder = _activeReminder;
    if (reminder == null) return;
    final lat = _asDouble(reminder['targetLat']);
    final lng = _asDouble(reminder['targetLng']);
    if (lat == 0 || lng == 0) return;
    final distance = _distanceMeters(_locationService.latitude, _locationService.longitude, lat, lng);
    if (distance <= 80) {
      setState(() => _reminderNotice = "即将到达${reminder['targetStation']}，请准备下车");
    } else if (distance > 180 && _reminderNotice.contains('即将到达')) {
      setState(() => _reminderNotice = '你可能已经偏离下车站，建议重新规划校车路线');
    }
  }

  Future<void> _searchRoute() async {
    final to = _toCtrl.text.trim();
    if (to.isEmpty) {
      _showSnack('请选择目的地');
      return;
    }
    setState(() {
      _planning = true;
      _plan = null;
    });
    try {
      final res = await NetworkClient.dio.post('/bus/plan', data: {
        'fromLat': _locationService.latitude,
        'fromLng': _locationService.longitude,
        'fromStation': _fromCtrl.text.trim(),
        'toStation': to,
        'preference': _preference,
      });
      if (res.data['code'] == 200 && mounted) {
        var data = Map<String, dynamic>.from(res.data['data'] ?? {});
        if (!_hasUsablePlan(data)) {
          data = _localPlan(_fromCtrl.text.trim(), to);
        }
        setState(() => _plan = data);
        if (_hasUsablePlan(data)) await _prefetchGuides(data);
      } else if (mounted) {
        setState(() => _plan = _localPlan(_fromCtrl.text.trim(), to));
      }
    } catch (_) {
      final fallback = _localPlan(_fromCtrl.text.trim(), to);
      if (mounted) setState(() => _plan = fallback);
    } finally {
      if (mounted) setState(() => _planning = false);
    }
  }

  Future<void> _askAssistant() async {
    final message = _assistantCtrl.text.trim();
    if (message.isEmpty) {
      _showSnack('请输入你的校车问题');
      return;
    }
    setState(() {
      _asking = true;
      _assistantReply = '';
    });
    final parsed = _parseAssistantQuery(message);
    try {
      final res = await NetworkClient.dio.post('/bus/assistant', data: {
        'message': message,
        'lat': _locationService.latitude,
        'lng': _locationService.longitude,
        if ((parsed['from'] ?? '').isNotEmpty) 'fromStation': parsed['from'],
        if ((parsed['to'] ?? '').isNotEmpty) 'toStation': parsed['to'],
        'preference': _preference,
      });
      if (res.data['code'] == 200 && mounted) {
        final data = Map<String, dynamic>.from(res.data['data'] ?? {});
        var plan = data['plan'] is Map ? Map<String, dynamic>.from(data['plan']) : <String, dynamic>{};
        if (!_hasUsablePlan(plan)) {
          plan = _localPlan(parsed['from'] ?? '', parsed['to'] ?? '');
        }
        setState(() {
          if ((parsed['from'] ?? '').isNotEmpty) _fromCtrl.text = parsed['from']!;
          if ((parsed['to'] ?? '').isNotEmpty) _toCtrl.text = parsed['to']!;
          _assistantReply = _hasUsablePlan(plan) ? _assistantReplyForPlan(plan) : (data['reply']?.toString() ?? '没有解析到完整的起终点，请补充目的地。');
          _plan = plan.isNotEmpty ? plan : _plan;
        });
      } else if (mounted) {
        final fallback = _localPlan(parsed['from'] ?? '', parsed['to'] ?? '');
        setState(() {
          _plan = fallback;
          _assistantReply = _hasUsablePlan(fallback) ? _assistantReplyForPlan(fallback) : '我已经识别到你的问题，但还缺少明确目的地。可以说“从二号门到中心图书馆”。';
        });
      }
    } catch (_) {
      if (mounted) {
        final fallback = _localPlan(parsed['from'] ?? '', parsed['to'] ?? '');
        setState(() {
          if ((parsed['from'] ?? '').isNotEmpty) _fromCtrl.text = parsed['from']!;
          if ((parsed['to'] ?? '').isNotEmpty) _toCtrl.text = parsed['to']!;
          _plan = fallback;
          _assistantReply = _hasUsablePlan(fallback)
              ? _assistantReplyForPlan(fallback)
              : '我已经识别到你的问题，但还缺少明确目的地。可以说“从二号门到中心图书馆”。';
        });
      }
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  Future<void> _prefetchGuides(Map<String, dynamic> plan) async {
    final best = plan['best'];
    if (best is! Map) return;
    final stations = (best['stations'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .skip(1)
        .take(3)
        .toList();
    if (stations.isEmpty) return;
    try {
      await NetworkClient.dio.post('/bus/guide/prefetch', data: {'stations': stations});
    } catch (_) {}
  }

  void _enableReminder(Map<String, dynamic> plan) {
    final best = plan['best'];
    if (best is! Map || best['reminder'] is! Map) {
      _showSnack('该方案暂无下车提醒信息');
      return;
    }
    setState(() {
      _activeReminder = Map<String, dynamic>.from(best['reminder']);
      _reminderNotice = "已开启${_activeReminder!['targetStation']}下车提醒";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
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
              child: Container(color: const Color(0xFFE0F2FE).withValues(alpha: 0.45)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildTabBar(),
                Expanded(
                  child: _tabIndex == 0
                      ? _buildScheduleList()
                      : _tabIndex == 1
                          ? _buildRoutePlan()
                          : _buildAssistant(),
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
          _iconButton(Icons.arrow_back_ios_new_rounded, () => Navigator.pop(context)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('校园班车', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.darkBlue)),
          ),
          _smallAction(Icons.refresh_rounded, '刷新', _load),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final tabs = ['时刻表', '智能规划', 'AI助手'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: _glass(
        padding: const EdgeInsets.all(4),
        radius: 14,
        child: Row(
          children: tabs.asMap().entries.map((entry) {
            final active = _tabIndex == entry.key;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _tabIndex = entry.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 36,
                  decoration: BoxDecoration(
                    color: active ? AppTheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Center(
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: active ? Colors.white : AppTheme.darkBlue,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildScheduleList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        children: [
          _nearestCard(),
          const SizedBox(height: 12),
          ..._lines.asMap().entries.map((entry) => _lineCard(entry.key, entry.value)),
        ],
      ),
    );
  }

  Widget _nearestCard() {
    final nearest = _nearest;
    if (nearest == null || nearest['available'] == false) {
      return _glass(
        child: const Text('正在计算最近校车站...', style: TextStyle(color: AppTheme.textSub)),
      );
    }
    final station = nearest['station'] is Map ? Map<String, dynamic>.from(nearest['station']) : <String, dynamic>{};
    final crowding = nearest['crowding'] is Map ? Map<String, dynamic>.from(nearest['crowding']) : <String, dynamic>{};
    return _glass(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _roundIcon(Icons.near_me_rounded, AppTheme.success),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('智能最近站点推荐', style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.textMain)),
              const SizedBox(height: 4),
              Text(
                "${station['stationName'] ?? '附近站点'} · 约${station['distanceMeters'] ?? '-'}米 · 步行${nearest['walkMinutes'] ?? '-'}分钟",
                style: const TextStyle(fontSize: 12, color: AppTheme.textSub),
              ),
            ]),
          ),
          _crowdChip(crowding['level']?.toString() ?? '低'),
        ]),
        const SizedBox(height: 12),
        Text(
          nearest['suggestion']?.toString() ?? '已根据当前位置推荐最近校车站。',
          style: const TextStyle(fontSize: 13, height: 1.55, color: AppTheme.darkBlue),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _outlineAction(Icons.route_rounded, '去规划', () => setState(() => _tabIndex = 1))),
          const SizedBox(width: 10),
          Expanded(child: _outlineAction(Icons.psychology_alt_rounded, '问助手', () => setState(() => _tabIndex = 2))),
        ]),
      ]),
    );
  }

  Widget _lineCard(int index, dynamic line) {
    final map = Map<String, dynamic>.from(line as Map);
    final expanded = _expandedIndex == index;
    final eta = map['eta'] is Map ? Map<String, dynamic>.from(map['eta']) : _etaLocal(map);
    final stations = map['stations'] as Map<String, dynamic>? ?? {};
    return _glass(
      margin: const EdgeInsets.only(bottom: 14),
      padding: EdgeInsets.zero,
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _expandedIndex = expanded ? null : index),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              _roundIcon(Icons.directions_bus_filled_rounded, AppTheme.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(map['lineName']?.toString() ?? '校车线路',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textMain)),
                  const SizedBox(height: 4),
                  Text(
                    "${map['startTime'] ?? '--'} - ${map['endTime'] ?? '--'} | ${map['intervalMins'] ?? '-'}分钟/班",
                    style: const TextStyle(fontSize: 12, color: AppTheme.darkBlue),
                  ),
                ]),
              ),
              _etaBlock(eta),
              Icon(expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: AppTheme.darkBlue),
            ]),
          ),
        ),
        if (expanded) ...stations.entries.map((entry) => _timeline(entry.key, entry.value as List)),
      ]),
    );
  }

  Widget _timeline(String dir, List stations) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
          child: Text(dir == '0' ? '去程' : '返程', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary)),
        ),
        ...stations.asMap().entries.map((entry) {
          final station = Map<String, dynamic>.from(entry.value as Map);
          final isLast = entry.key == stations.length - 1;
          return SizedBox(
            height: 42,
            child: Row(children: [
              SizedBox(
                width: 26,
                child: Column(children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: isLast ? 1 : 0.72), borderRadius: BorderRadius.circular(11)),
                    child: Center(child: Text('${station['stopOrder'] ?? station['stop_order'] ?? entry.key + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                  ),
                  if (!isLast) Expanded(child: Container(width: 2, color: AppTheme.primary.withValues(alpha: 0.2))),
                ]),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(_stationName(station), style: const TextStyle(fontSize: 14, color: AppTheme.textMain))),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _buildRoutePlan() {
    final stations = _stationNames().toList()..sort();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      child: Column(children: [
        _nearestCard(),
        const SizedBox(height: 12),
        _stationInput('上车站', _fromCtrl, stations, hint: '默认使用当前位置最近站点'),
        const SizedBox(height: 8),
        const Icon(Icons.swap_vert_rounded, color: AppTheme.primary, size: 24),
        const SizedBox(height: 8),
        _stationInput('目的站', _toCtrl, stations, hint: '选择目的地附近站点'),
        const SizedBox(height: 12),
        _preferenceSelector(),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _planning ? null : _searchRoute,
            icon: _planning
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.route_rounded),
            label: const Text('生成校车 + 步行方案', style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        if (_reminderNotice.isNotEmpty) ...[
          const SizedBox(height: 12),
          _notice(_reminderNotice, Icons.notifications_active_rounded),
        ],
        const SizedBox(height: 16),
        if (_plan != null) _planCards(_plan!),
      ]),
    );
  }

  Widget _preferenceSelector() {
    final items = {
      'fastest': '最快',
      'less_walk': '少走路',
      'less_transfer': '少换乘',
    };
    return _glass(
      padding: const EdgeInsets.all(8),
      radius: 14,
      child: Row(
        children: items.entries.map((entry) {
          final selected = _preference == entry.key;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: ChoiceChip(
                label: Center(child: Text(entry.value)),
                selected: selected,
                onSelected: (_) => setState(() => _preference = entry.key),
                selectedColor: AppTheme.primary.withValues(alpha: 0.18),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _planCards(Map<String, dynamic> plan) {
    if (plan['available'] == false) {
      return _notice(plan['message']?.toString() ?? '没有找到合适方案', Icons.error_outline_rounded, color: AppTheme.danger);
    }
    final plans = (plan['plans'] as List<dynamic>? ?? const []).whereType<Map>().toList();
    return Column(
      children: [
        _glass(
          child: Row(children: [
            _roundIcon(Icons.auto_awesome_rounded, AppTheme.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                plan['message']?.toString() ?? '已生成最优乘车方案',
                style: const TextStyle(fontSize: 13, height: 1.5, color: AppTheme.darkBlue, fontWeight: FontWeight.w700),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        ...plans.map((item) => _planCard(Map<String, dynamic>.from(item), isBest: item == plans.first)),
      ],
    );
  }

  Widget _planCard(Map<String, dynamic> plan, {required bool isBest}) {
    final crowding = plan['crowding'] is Map ? Map<String, dynamic>.from(plan['crowding']) : <String, dynamic>{};
    final eta = plan['eta'] is Map ? Map<String, dynamic>.from(plan['eta']) : <String, dynamic>{};
    final stations = (plan['stations'] as List<dynamic>? ?? const []).map((item) => item.toString()).toList();
    return _glass(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _roundIcon(isBest ? Icons.recommend_rounded : Icons.alt_route_rounded, isBest ? AppTheme.success : AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(plan['lineName']?.toString() ?? '推荐方案', style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.textMain)),
              const SizedBox(height: 4),
              Text(plan['summary']?.toString() ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textSub)),
            ]),
          ),
          _crowdChip(crowding['level']?.toString() ?? '低'),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _metric('步行', "${plan['walkToStartMinutes']} + ${plan['walkFromEndMinutes']} 分钟"),
          _metric('等车', "${plan['waitMinutes']} 分钟"),
          _metric('乘车', "${plan['rideMinutes']} 分钟"),
          _metric('末班', eta['lastBus']?.toString() ?? '--'),
        ]),
        const SizedBox(height: 12),
        Text(crowding['reason']?.toString() ?? '已完成拥挤度预测', style: const TextStyle(fontSize: 12, color: AppTheme.textSub)),
        const SizedBox(height: 12),
        _stationStrip(stations),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _outlineAction(Icons.notifications_active_rounded, '下车提醒', () => _enableReminder({'best': plan}))),
          const SizedBox(width: 10),
          Expanded(child: _outlineAction(Icons.volume_up_rounded, '讲解缓存', () => _prefetchGuides({'best': plan}).then((_) => _showSnack('已预缓存后续站点讲解')))),
        ]),
      ]),
    );
  }

  Widget _stationStrip(List<String> stations) {
    if (stations.isEmpty) return const SizedBox.shrink();
    return Column(
      children: stations.asMap().entries.map((entry) {
        final isLast = entry.key == stations.length - 1;
        return Row(children: [
          Icon(isLast ? Icons.location_on_rounded : Icons.circle, size: isLast ? 18 : 9, color: isLast ? AppTheme.primary : AppTheme.success),
          const SizedBox(width: 8),
          Expanded(child: Text(entry.value, style: const TextStyle(fontSize: 13, color: AppTheme.textMain))),
        ]);
      }).toList(),
    );
  }

  Widget _buildAssistant() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _nearestCard(),
        const SizedBox(height: 12),
        _glass(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('AI 校园通勤助手', style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.textMain, fontSize: 17)),
            const SizedBox(height: 10),
            TextField(
              controller: _assistantCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: '例如：我现在在二号门，要去中心图书馆，怎么坐校车最快？',
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.74),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _asking ? null : _askAssistant,
                icon: _asking
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.psychology_alt_rounded),
                label: const Text('生成通勤建议'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ]),
        ),
        if (_assistantReply.isNotEmpty) ...[
          const SizedBox(height: 12),
          _notice(_assistantReply, Icons.chat_bubble_outline_rounded),
        ],
        const SizedBox(height: 12),
        if (_plan != null) _planCards(_plan!),
      ]),
    );
  }

  Widget _stationInput(String label, TextEditingController ctrl, List<String> stations, {required String hint}) {
    return GestureDetector(
      onTap: () => _showStationPicker(label, ctrl, stations),
      child: _glass(
        radius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              ctrl.text.isEmpty ? hint : ctrl.text,
              style: TextStyle(fontSize: 15, color: ctrl.text.isEmpty ? AppTheme.textSub : AppTheme.textMain),
            ),
          ),
          const Icon(Icons.keyboard_arrow_down, color: AppTheme.textSub),
        ]),
      ),
    );
  }

  Future<void> _showStationPicker(String label, TextEditingController ctrl, List<String> stations) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: 440,
            color: Colors.white.withValues(alpha: 0.92),
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Text('选择$label', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.darkBlue)),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: stations.length,
                  itemBuilder: (_, index) => ListTile(
                    title: Text(stations[index], style: const TextStyle(fontSize: 15)),
                    onTap: () => Navigator.pop(context, stations[index]),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => ctrl.text = picked);
    }
  }

  Set<String> _stationNames() {
    final names = <String>{};
    for (final line in _linePool()) {
      final stations = (line as Map)['stations'] as Map<String, dynamic>? ?? {};
      for (final list in stations.values) {
        for (final station in (list as List)) {
          final name = _stationName(Map<String, dynamic>.from(station as Map));
          if (name.isNotEmpty) names.add(name);
        }
      }
    }
    names.addAll(_fallbackStationCoords.keys);
    return names;
  }

  Map<String, dynamic>? _nearestStationLocal(double lat, double lng) {
    Map<String, dynamic>? best;
    var bestDistance = double.infinity;
    for (final line in _linePool()) {
      final stations = (line as Map)['stations'] as Map<String, dynamic>? ?? {};
      for (final list in stations.values) {
        for (final raw in (list as List)) {
          final station = Map<String, dynamic>.from(raw as Map);
          final name = _stationName(station);
          final fallback = _stationCoord(name);
          final rawLat = _asDouble(station['latitude']);
          final rawLng = _asDouble(station['longitude']);
          final sLat = rawLat == 0 ? (fallback?[0] ?? 0) : rawLat;
          final sLng = rawLng == 0 ? (fallback?[1] ?? 0) : rawLng;
          if (sLat == 0 || sLng == 0) continue;
          final distance = _distanceMeters(lat, lng, sLat, sLng);
          if (distance < bestDistance) {
            bestDistance = distance;
            best = {
              'stationName': name,
              'latitude': sLat,
              'longitude': sLng,
              'distanceMeters': bestDistance.round(),
            };
          }
        }
      }
    }
    return best;
  }

  Map<String, dynamic> _localPlan(String from, String to) {
    final resolvedTo = _resolveStationName(to);
    if (resolvedTo.isEmpty) {
      return {'available': false, 'message': '请先输入或选择目的站，例如“中心图书馆”。'};
    }
    final nearest = _nearestStationLocal(_locationService.latitude, _locationService.longitude);
    final start = _resolveStationName(from.isEmpty ? (nearest?['stationName']?.toString() ?? '') : from);
    if (start.isEmpty) {
      return {'available': false, 'message': '还没有获取到当前位置附近站点，请稍后重试或手动选择上车站。'};
    }
    if (start == resolvedTo) {
      final plan = _walkOnlyPlan(start, resolvedTo, nearest);
      return {'available': true, 'message': '你已经在目的站附近，建议直接步行前往。', 'plans': [plan], 'best': plan};
    }

    final candidates = <Map<String, dynamic>>[];
    final paths = <Map<String, dynamic>>[];
    for (final line in _linePool()) {
      final lineMap = Map<String, dynamic>.from(line as Map);
      final stations = lineMap['stations'] as Map<String, dynamic>? ?? {};
      for (final list in stations.values) {
        final names = (list as List).map((item) => _stationName(Map<String, dynamic>.from(item as Map))).where((name) => name.isNotEmpty).toList();
        if (names.length < 2) continue;
        paths.add({'line': lineMap, 'names': names});
        final i1 = names.indexOf(start);
        final i2 = names.indexOf(resolvedTo);
        if (i1 >= 0 && i2 >= 0 && i1 != i2) {
          final segment = i1 < i2 ? names.sublist(i1, i2 + 1) : names.sublist(i2, i1 + 1).reversed.toList();
          candidates.add(_buildLocalBusPlan(lineMap, segment, start, resolvedTo));
        }
      }
    }

    for (final first in paths) {
      for (final second in paths) {
        if (identical(first, second)) continue;
        final firstLine = Map<String, dynamic>.from(first['line'] as Map);
        final secondLine = Map<String, dynamic>.from(second['line'] as Map);
        final firstNames = List<String>.from(first['names'] as List);
        final secondNames = List<String>.from(second['names'] as List);
        final firstStart = firstNames.indexOf(start);
        final secondEnd = secondNames.indexOf(resolvedTo);
        if (firstStart < 0 || secondEnd < 0) continue;
        for (final transfer in firstNames.toSet().intersection(secondNames.toSet())) {
          if (transfer == start || transfer == resolvedTo) continue;
          final firstTransfer = firstNames.indexOf(transfer);
          final secondTransfer = secondNames.indexOf(transfer);
          final left = firstStart < firstTransfer
              ? firstNames.sublist(firstStart, firstTransfer + 1)
              : firstNames.sublist(firstTransfer, firstStart + 1).reversed.toList();
          final right = secondTransfer < secondEnd
              ? secondNames.sublist(secondTransfer, secondEnd + 1)
              : secondNames.sublist(secondEnd, secondTransfer + 1).reversed.toList();
          if (left.length < 2 || right.length < 2) continue;
          candidates.add(_buildLocalBusPlan(
            firstLine,
            [...left, ...right.skip(1)],
            start,
            resolvedTo,
            transferAt: transfer,
            transfers: 1,
            lineName: '${firstLine['lineName']} → ${secondLine['lineName']}',
          ));
          break;
        }
      }
    }

    candidates.sort((a, b) => _localScore(a).compareTo(_localScore(b)));
    final unique = <String, Map<String, dynamic>>{};
    for (final item in candidates) {
      unique.putIfAbsent('${item['lineName']}-${(item['stations'] as List).join("/")}', () => item);
      if (unique.length >= 3) break;
    }
    final plans = unique.values.toList();
    if (plans.isEmpty) return {'available': false, 'message': '未找到可达方案，建议换站点或步行前往'};
    return {
      'available': true,
      'algorithm': 'CampusBus-Dijkstra 本地兜底算法',
      'preference': _preference,
      'message': '已根据当前位置、站点时刻表和本地线路生成校车 + 步行方案',
      'plans': plans,
      'best': plans.first,
    };
  }

  Map<String, dynamic> _nearestFromLocal() {
    final station = _nearestStationLocal(_locationService.latitude, _locationService.longitude);
    if (station == null) return {'available': false, 'message': '还没有可用站点数据'};
    final distance = (station['distanceMeters'] as num).toDouble();
    final eta = _bestEtaForStation(station['stationName'].toString());
    final etaText = eta == null || eta['running'] == false ? '当前可能停运' : '最近一班约${eta['waitMinutes']}分钟后到站';
    return {
      'available': true,
      'station': station,
      'walkMinutes': _walkMinutes(distance),
      'crowding': _crowdingLocal(),
      'suggestion': '你附近最近的校车站是${station['stationName']}，约${station['distanceMeters']}米，步行约${_walkMinutes(distance)}分钟。$etaText，可在智能规划中选择目的站生成完整方案。',
    };
  }

  Map<String, dynamic> _buildLocalBusPlan(
    Map<String, dynamic> line,
    List<String> segment,
    String start,
    String to, {
    String? transferAt,
    int transfers = 0,
    String? lineName,
  }) {
    final eta = _etaLocal(line);
    final wait = eta['running'] == false ? 999 : (eta['waitMinutes'] as int? ?? 0);
    final ride = math.max(3, (segment.length - 1) * 3 + transfers * 6);
    final startCoord = _stationCoord(start);
    final toCoord = _stationCoord(to);
    final walkStartMeters = startCoord == null ? 80.0 : _distanceMeters(_locationService.latitude, _locationService.longitude, startCoord[0], startCoord[1]);
    final walkEndMeters = toCoord == null ? 80.0 : 60.0;
    final walkStart = _walkMinutes(walkStartMeters);
    final walkEnd = _walkMinutes(walkEndMeters);
    final total = walkStart + wait + ride + walkEnd;
    final displayLine = lineName ?? line['lineName'];
    return {
      'type': transfers == 0 ? 'direct' : 'transfer',
      'lineName': displayLine,
      'summary': '$displayLine，预计等车${wait >= 999 ? "较久" : "$wait分钟"}，全程约$total分钟',
      'stations': segment,
      'transferAt': transferAt,
      'transferCount': transfers,
      'stationCount': math.max(0, segment.length - 1),
      'walkToStartMeters': walkStartMeters.round(),
      'walkFromEndMeters': walkEndMeters.round(),
      'walkToStartMinutes': walkStart,
      'walkFromEndMinutes': walkEnd,
      'waitMinutes': wait,
      'rideMinutes': ride,
      'totalMinutes': total,
      'eta': eta,
      'crowding': _crowdingLocal(),
      'reminder': {
        'targetStation': to,
        'targetLat': toCoord?[0] ?? 0,
        'targetLng': toCoord?[1] ?? 0,
        'radiusMeters': 80,
        'missedThresholdMeters': 180,
      },
    };
  }

  Map<String, dynamic> _walkOnlyPlan(String start, String to, Map<String, dynamic>? nearest) {
    final distance = nearest?['distanceMeters'] is num ? (nearest!['distanceMeters'] as num).toDouble() : 120.0;
    final minutes = _walkMinutes(distance);
    return {
      'type': 'walk_only',
      'lineName': '步行建议',
      'summary': '当前位置已接近$to，建议直接步行约$minutes分钟',
      'stations': [start, to],
      'walkToStartMinutes': minutes,
      'walkFromEndMinutes': 0,
      'waitMinutes': 0,
      'rideMinutes': 0,
      'totalMinutes': minutes,
      'eta': {'running': true, 'lastBus': '--'},
      'crowding': {'level': '低', 'reason': '无需乘车'},
    };
  }

  double _localScore(Map<String, dynamic> plan) {
    final total = _asDouble(plan['totalMinutes']);
    final walk = _asDouble(plan['walkToStartMinutes']) + _asDouble(plan['walkFromEndMinutes']);
    final transfer = _asDouble(plan['transferCount']);
    if (_preference == 'less_walk') return total + walk * 3 + transfer * 8;
    if (_preference == 'less_transfer') return total + transfer * 25;
    return total + transfer * 8;
  }

  bool _hasUsablePlan(Map<String, dynamic> plan) {
    final plans = plan['plans'];
    return plan['available'] == true && plans is List && plans.isNotEmpty;
  }

  Map<String, String> _parseAssistantQuery(String message) {
    final mentioned = <MapEntry<int, String>>[];
    for (final name in _allKnownStations()) {
      final index = _stationMentionIndex(message, name);
      if (index >= 0) mentioned.add(MapEntry(index, name));
    }
    mentioned.sort((a, b) => a.key.compareTo(b.key));
    final names = mentioned.map((item) => item.value).toList();
    final result = <String, String>{};
    if (names.length >= 2) {
      result['from'] = names.first;
      result['to'] = names.last;
    } else if (names.length == 1) {
      final name = names.first;
      if (message.contains('从$name') || message.contains('在$name') || message.contains('我现在在$name')) {
        result['from'] = name;
      } else {
        result['to'] = name;
      }
    }
    if (!result.containsKey('to')) {
      final afterGo = RegExp(r'(?:去|到|前往)([\u4e00-\u9fa5A-Za-z0-9]+)').firstMatch(message)?.group(1) ?? '';
      final resolved = _resolveStationName(afterGo);
      if (resolved.isNotEmpty) result['to'] = resolved;
    }
    return result;
  }

  int _stationMentionIndex(String message, String station) {
    final candidates = <String>[station];
    if (station == '中心图书馆') candidates.addAll(['图书馆', '中图']);
    if (station == '八教') candidates.addAll(['第八教学楼', '8教']);
    if (station == '一号门') candidates.addAll(['1号门', '一门']);
    if (station == '二号门') candidates.addAll(['2号门', '二门']);
    var best = -1;
    for (final item in candidates) {
      final index = message.indexOf(item);
      if (index >= 0 && (best < 0 || index < best)) best = index;
    }
    if (best >= 0) return best;
    return _messageMentionsStation(message, station) ? 9999 : -1;
  }

  String _assistantReplyForPlan(Map<String, dynamic> plan) {
    final best = plan['best'] is Map ? Map<String, dynamic>.from(plan['best']) : <String, dynamic>{};
    if (best.isEmpty) return plan['message']?.toString() ?? '已生成通勤建议。';
    final stations = (best['stations'] as List<dynamic>? ?? const []).map((item) => item.toString()).toList();
    final start = stations.isNotEmpty ? stations.first : '最近站点';
    final end = stations.isNotEmpty ? stations.last : '目的站';
    return '建议从$start上车，乘坐${best['lineName'] ?? '推荐线路'}，在$end附近下车。步行到站约${best['walkToStartMinutes'] ?? 0}分钟，等车约${best['waitMinutes'] ?? 0}分钟，全程约${best['totalMinutes'] ?? 0}分钟。';
  }

  List<dynamic> _linePool() {
    final result = <dynamic>[];
    final seen = <String>{};
    for (final line in [..._lines, ..._mockData()]) {
      if (line is! Map) continue;
      final name = line['lineName']?.toString() ?? '';
      final key = '$name-${line['lineId'] ?? ''}';
      if (seen.add(key)) result.add(line);
    }
    return result;
  }

  Set<String> _allKnownStations() => {..._stationNames(), ..._fallbackStationCoords.keys};

  String _resolveStationName(String text) {
    final normalized = _normalizeStationText(text);
    if (normalized.isEmpty) return '';
    for (final name in _allKnownStations()) {
      final n = _normalizeStationText(name);
      if (n == normalized || n.contains(normalized) || normalized.contains(n)) return name;
    }
    return '';
  }

  bool _messageMentionsStation(String message, String station) {
    final msg = _normalizeStationText(message);
    final name = _normalizeStationText(station);
    if (msg.contains(name)) return true;
    if (station == '中心图书馆' && (msg.contains('图书馆') || msg.contains('中图'))) return true;
    if (station == '八教' && (msg.contains('第八教学楼') || msg.contains('8教'))) return true;
    if (station == '一号门' && (msg.contains('1号门') || msg.contains('一门'))) return true;
    if (station == '二号门' && (msg.contains('2号门') || msg.contains('二门'))) return true;
    return false;
  }

  String _normalizeStationText(String text) {
    return text
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('西南大学', '')
        .replaceAll('北碚校区', '')
        .replaceAll('（', '')
        .replaceAll('）', '')
        .replaceAll('(', '')
        .replaceAll(')', '')
        .replaceAll('1号门', '一号门')
        .replaceAll('2号门', '二号门')
        .toLowerCase();
  }

  List<double>? _stationCoord(String name) {
    return _fallbackStationCoords[name] ?? _fallbackStationCoords[_resolveStationNameFromFallback(name)];
  }

  String _resolveStationNameFromFallback(String text) {
    final normalized = _normalizeStationText(text);
    for (final name in _fallbackStationCoords.keys) {
      final n = _normalizeStationText(name);
      if (n == normalized || n.contains(normalized) || normalized.contains(n)) return name;
    }
    return text;
  }

  Map<String, dynamic>? _bestEtaForStation(String stationName) {
    Map<String, dynamic>? best;
    for (final line in _linePool()) {
      final lineMap = Map<String, dynamic>.from(line as Map);
      final stations = lineMap['stations'] as Map<String, dynamic>? ?? {};
      final serves = stations.values.any((list) => (list as List).any((item) => _stationName(Map<String, dynamic>.from(item as Map)) == stationName));
      if (!serves) continue;
      final eta = _etaLocal(lineMap);
      if (best == null || _asDouble(eta['waitMinutes']) < _asDouble(best['waitMinutes'])) best = eta;
    }
    return best;
  }

  Map<String, dynamic> _crowdingLocal() {
    final now = TimeOfDay.now();
    final minutes = now.hour * 60 + now.minute;
    if (minutes >= 450 && minutes <= 510) return {'level': '高', 'reason': '早高峰，教学区方向客流较集中'};
    if (minutes >= 700 && minutes <= 750) return {'level': '中', 'reason': '午间食堂和宿舍方向客流增加'};
    if (minutes >= 1050 && minutes <= 1110) return {'level': '高', 'reason': '晚高峰，宿舍和校门方向客流较集中'};
    if (minutes >= 1290) return {'level': '中', 'reason': '接近末班时段，请留意末班车风险'};
    return {'level': '低', 'reason': '当前不在典型高峰时段'};
  }

  Map<String, dynamic> _etaLocal(Map<String, dynamic> line) {
    final start = _parseClock(line['startTime']?.toString()) ?? const TimeOfDay(hour: 7, minute: 0);
    final end = _parseClock(line['endTime']?.toString()) ?? const TimeOfDay(hour: 22, minute: 30);
    final interval = int.tryParse(line['intervalMins']?.toString() ?? '') ?? 15;
    final now = TimeOfDay.now();
    final nowMin = now.hour * 60 + now.minute;
    final startMin = start.hour * 60 + start.minute;
    final endMin = end.hour * 60 + end.minute;
    if (nowMin > endMin) {
      return {'running': false, 'nextBus': null, 'waitMinutes': 999, 'lastBus': _fmt(end)};
    }
    final next = nowMin <= startMin ? startMin : startMin + ((nowMin - startMin) / interval).ceil() * interval;
    if (next > endMin) {
      return {'running': false, 'nextBus': null, 'waitMinutes': 999, 'lastBus': _fmt(end)};
    }
    return {'running': true, 'nextBus': _fmtMinutes(next), 'waitMinutes': math.max(0, next - nowMin), 'lastBus': _fmt(end)};
  }

  TimeOfDay? _parseClock(String? text) {
    if (text == null || text.isEmpty) return null;
    final parts = text.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _fmt(TimeOfDay time) => '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  String _fmtMinutes(int minutes) => '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  String _stationName(Map<String, dynamic> station) => (station['stationName'] ?? station['station_name'] ?? '').toString();
  int _walkMinutes(double meters) => math.max(1, (meters / 75).ceil());
  double _asDouble(dynamic value) => value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;

  double _distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  Widget _glass({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    EdgeInsetsGeometry margin = EdgeInsets.zero,
    double radius = 20,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          margin: margin,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.66),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _roundIcon(IconData icon, Color color) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(13)),
      child: Icon(icon, color: color, size: 23),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
        ),
        child: Icon(icon, color: AppTheme.darkBlue, size: 18),
      ),
    );
  }

  Widget _smallAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppTheme.primary, Color(0xFF01306B)]), borderRadius: BorderRadius.circular(14)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _outlineAction(IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.primary,
        side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.45)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
    );
  }

  Widget _etaBlock(Map<String, dynamic> eta) {
    final running = eta['running'] != false;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(running ? '${eta['waitMinutes'] ?? '-'}分钟' : '停运', style: TextStyle(color: running ? AppTheme.success : AppTheme.danger, fontWeight: FontWeight.w900, fontSize: 13)),
        const SizedBox(height: 2),
        Text(running ? '下一班 ${eta['nextBus'] ?? '--'}' : '末班 ${eta['lastBus'] ?? '--'}', style: const TextStyle(fontSize: 10, color: AppTheme.textSub)),
      ]),
    );
  }

  Widget _crowdChip(String level) {
    final firstCode = level.isEmpty ? 0 : level.codeUnitAt(0);
    final color = firstCode == 0x9AD8
        ? AppTheme.danger
        : firstCode == 0x4E2D
            ? AppTheme.warning
            : AppTheme.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(999)),
      child: Text('拥挤$level', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900)),
    );
  }

  Widget _metric(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
      child: Text('$label $value', style: const TextStyle(fontSize: 12, color: AppTheme.darkBlue, fontWeight: FontWeight.w700)),
    );
  }

  Widget _notice(String text, IconData icon, {Color color = AppTheme.primary}) {
    return _glass(
      radius: 16,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(fontSize: 13, height: 1.55, color: color == AppTheme.primary ? AppTheme.darkBlue : color))),
      ]),
    );
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  List<dynamic> _mockData() {
    return [
      {
        'lineId': 1,
        'lineName': '1路循环线',
        'startTime': '07:00',
        'endTime': '22:30',
        'intervalMins': 15,
        'stations': {
          '0': _s([
            ['一号门', 29.8198, 106.4310],
            ['二号门', 29.8218, 106.4218],
            ['共青团花园', 29.8210, 106.4270],
            ['中心图书馆', 29.8235, 106.4308],
            ['八教', 29.8230, 106.4260],
            ['五号门', 29.8174, 106.4206],
          ]),
        },
      },
      {
        'lineId': 2,
        'lineName': '2路教学区线',
        'startTime': '07:10',
        'endTime': '18:40',
        'intervalMins': 20,
        'stations': {
          '0': _s([
            ['一号门', 29.8198, 106.4310],
            ['音乐学院', 29.8178, 106.4285],
            ['田家炳', 29.8205, 106.4240],
            ['八教', 29.8230, 106.4260],
          ]),
        },
      },
      {
        'lineId': 102,
        'lineName': '3路图书馆线',
        'startTime': '07:10',
        'endTime': '18:40',
        'intervalMins': 20,
        'stations': {
          '0': _s([
            ['竹园', 29.8150, 106.4220],
            ['二号门', 29.8218, 106.4218],
            ['大礼堂', 29.8224, 106.4254],
            ['中心图书馆', 29.8235, 106.4308],
          ]),
        },
      },
    ];
  }

  static List<Map<String, dynamic>> _s(List<List<dynamic>> items) {
    return [
      for (var i = 0; i < items.length; i++)
        {
          'stopOrder': i + 1,
          'stationName': items[i][0],
          'latitude': items[i][1],
          'longitude': items[i][2],
        }
    ];
  }
}
