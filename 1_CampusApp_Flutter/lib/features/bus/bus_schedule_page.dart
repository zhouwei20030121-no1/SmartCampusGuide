import 'dart:ui';

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/network_client.dart';

class BusSchedulePage extends StatefulWidget {
  const BusSchedulePage({super.key});

  @override
  State<BusSchedulePage> createState() => _BusSchedulePageState();
}

class _BusSchedulePageState extends State<BusSchedulePage> {
  List<dynamic> _lines = [];
  bool _loading = true;
  int? _expandedIndex;
  int _tabIndex = 0;

  String _n(dynamic s) => (s['stationName'] ?? s['station_name'] ?? '').toString();

  // 换乘查询
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  List<_RoutePlan> _planResults = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await NetworkClient.dio.get('/bus/lines');
      if (res.data['code'] == 200) setState(() => _lines = res.data['data'] ?? []);
    } catch (_) {
      _lines = _mockData();
    } finally {
      setState(() => _loading = false);
    }
  }

  // ─── 换乘搜索逻辑 ───
  void _searchRoute() {
    final from = _fromCtrl.text.trim();
    final to = _toCtrl.text.trim();
    if (from.isEmpty || to.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入始发地和目的地')));
      return;
    }
    if (from == to) {
      setState(() => _planResults = [_RoutePlan('info', '始发地和目的地相同，无需乘车')]);
      return;
    }

    final results = <_RoutePlan>[];
    final fromLines = <int>[];
    final toLines = <int>[];

    for (final line in _lines) {
      final lineId = line['lineId'] as int;
      final lineName = line['lineName'] as String;
      final stations = line['stations'] as Map<String, dynamic>? ?? {};

      bool hasFrom = false, hasTo = false;
      for (final sts in stations.values) {
        for (final s in (sts as List)) {
          final name = _n(s);
          if (name == from) hasFrom = true;
          if (name == to) hasTo = true;
        }
      }
      if (hasFrom) fromLines.add(lineId);
      if (hasTo) toLines.add(lineId);

      if (hasFrom && hasTo) {
        final path = _extractPathSegment(lineId, lineName, from, to);
        results.add(_RoutePlan('direct', '直达：乘坐【$lineName】', lineName: lineName, stations: path));
      }
    }

    if (results.isEmpty) {
      for (final fid in fromLines) {
        for (final tid in toLines) {
          if (fid == tid) continue;
          final transferStations = _findCommonStations(fid, tid);
          final fName = _lineName(fid);
          final tName = _lineName(tid);
          for (final ts in transferStations) {
            if (ts != from && ts != to) {
              final seg1 = _extractPathSegment(fid, fName, from, ts);
              final seg2 = _extractPathSegment(tid, tName, ts, to);
              results.add(_RoutePlan('transfer', '换乘：先乘【$fName】到「$ts」，换乘【$tName】',
                  lineName: '$fName → $tName',
                  stations: [...seg1, ...seg2.skip(1)],
                  transferAt: ts));
              break; // 只需要第一个换乘方案
            }
          }
        }
      }
    }

    if (results.isEmpty) {
      results.add(_RoutePlan('none', '未找到可达路线，建议步行或骑行前往'));
    }

    setState(() => _planResults = results);
  }

  List<String> _extractPathSegment(int lineId, String lineName, String from, String to) {
    for (final line in _lines) {
      if (line['lineId'] != lineId) continue;
      final stations = line['stations'] as Map<String, dynamic>? ?? {};
      for (final sts in stations.values) {
        final list = (sts as List).map((s) => _n(s)).toList();
        final i1 = list.indexOf(from);
        final i2 = list.indexOf(to);
        if (i1 != -1 && i2 != -1) {
          if (i1 <= i2) return list.sublist(i1, i2 + 1);
          return list.sublist(i2, i1 + 1).reversed.toList();
        }
      }
    }
    return [from, to];
  }

  List<String> _findCommonStations(int lineId1, int lineId2) {
    final s1 = _allStations(lineId1);
    final s2 = _allStations(lineId2);
    s1.retainAll(s2);
    return s1.toList();
  }

  Set<String> _allStations(int lineId) {
    final result = <String>{};
    for (final line in _lines) {
      if (line['lineId'] == lineId) {
        final stations = line['stations'] as Map<String, dynamic>? ?? {};
        for (final sts in stations.values) {
          for (final s in (sts as List)) {
            result.add(_n(s));
          }
        }
      }
    }
    return result;
  }

  String _lineName(int lineId) {
    for (final line in _lines) {
      if (line['lineId'] == lineId) return line['lineName'] as String;
    }
    return '未知线路';
  }

  // ─── 实时校车弹窗 ───
  void _showRealtimeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: AlertDialog(
            backgroundColor: Colors.white.withValues(alpha: 0.85),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Row(children: [
              Icon(Icons.directions_bus, color: AppTheme.primary),
              SizedBox(width: 10),
              Text('实时校车位置', style: TextStyle(color: AppTheme.darkBlue, fontSize: 18)),
            ]),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(children: [
                  Image.asset('assets/images/bg.jpg', height: 80, fit: BoxFit.cover,
                      errorBuilder: (_, __, _) => const Icon(Icons.bus_alert, size: 48, color: AppTheme.primary)),
                  const SizedBox(height: 14),
                  const Text('请登录微信小程序',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textMain)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('" 享坐车 "',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  ),
                  const SizedBox(height: 6),
                  const Text('查看实时校车位置',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSub)),
                  const SizedBox(height: 12),
                  const Text('因暂无GPS硬件条件，暂无法在APP内\n提供实时校车追踪功能',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: AppTheme.textSub, height: 1.5)),
                ]),
              ),
            ]),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('我知道了', style: TextStyle(color: AppTheme.primary)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 获取去重后的所有站点名称 ───
  Set<String> _getAllStationNames() {
    final names = <String>{};
    for (final line in _lines) {
      final stations = line['stations'] as Map<String, dynamic>? ?? {};
      for (final sts in stations.values) {
        for (final s in (sts as List)) {
          final n = _n(s);
          if (n.isNotEmpty) names.add(n);
        }
      }
    }
    return names;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/bg.jpg', fit: BoxFit.cover,
              errorBuilder: (_, __, _) => Container(color: AppTheme.pageBg)),
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
                // Tab切换
                _buildTabBar(),
                Expanded(child: _tabIndex == 0 ? _buildScheduleList() : _buildRoutePlan()),
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
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.darkBlue, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('校园班车', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.darkBlue)),
          ),
          // 实时校车按钮
          GestureDetector(
            onTap: _showRealtimeDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.primary, Color(0xFF3A86C5)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.gps_fixed, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text('实时', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
            ),
            child: Row(
              children: ['时刻表', '换乘查询'].asMap().entries.map((e) {
                final active = _tabIndex == e.key;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _tabIndex = e.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: active ? AppTheme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Center(
                        child: Text(e.value,
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600,
                                color: active ? Colors.white : AppTheme.darkBlue)),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  // ─── 时刻表列表 ───
  Widget _buildScheduleList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      itemCount: _lines.length,
      itemBuilder: (_, i) => _card(i),
    );
  }

  Widget _card(int i) {
    final line = _lines[i];
    final name = line['lineName'] ?? '';
    final dirType = line['directionType'] ?? 0;
    final start = line['startTime'] ?? '';
    final end = line['endTime'] ?? '';
    final interval = line['intervalMins'] ?? '';
    final stations = line['stations'] as Map<String, dynamic>? ?? {};
    final expanded = _expandedIndex == i;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Column(children: [
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => _expandedIndex = expanded ? null : i),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: dirType == 1 ? AppTheme.warning.withValues(alpha: 0.15) : AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(dirType == 1 ? Icons.loop : Icons.swap_horiz,
                        color: dirType == 1 ? AppTheme.warning : AppTheme.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textMain)),
                      const SizedBox(height: 4),
                      Text('$start - $end | 约${interval}分钟/班', style: const TextStyle(fontSize: 12, color: AppTheme.darkBlue)),
                    ]),
                  ),
                  Icon(expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: AppTheme.darkBlue),
                ]),
              ),
            ),
            if (expanded)
              ...stations.entries.map((e) => _timeline(e.key.toString(), e.value as List, dirType)),
          ]),
        ),
      ),
    );
  }

  Widget _timeline(String dir, List sts, int dirType) {
    final label = dirType == 1 ? '循环方向' : (dir == '0' ? '上行 · 去程' : '下行 · 返程');
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: dirType == 1 ? AppTheme.warning.withValues(alpha: 0.12) : AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary)),
        ),
        ...sts.asMap().entries.map((e) {
          final s = e.value;
          final order = s['stop_order'] ?? (e.key + 1);
          final name = _n(s);
          final isLast = e.key == sts.length - 1;
          return SizedBox(height: 46, child: Row(children: [
            SizedBox(width: 26, child: Column(children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: isLast ? AppTheme.primary : AppTheme.primary.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Text('$order', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: AppTheme.primary.withValues(alpha: 0.2))),
            ])),
            const SizedBox(width: 14),
            Expanded(child: Text(name, style: const TextStyle(fontSize: 14, color: AppTheme.textMain))),
          ]));
        }),
      ]),
    );
  }

  // ─── 换乘查询页 ───
  Widget _buildRoutePlan() {
    final stations = _getAllStationNames().toList()..sort();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      child: Column(children: [
        // 始发地
        _buildStationInput('始发地', _fromCtrl, stations),
        const SizedBox(height: 8),
        const Center(child: Icon(Icons.swap_vert_rounded, color: AppTheme.primary, size: 24)),
        const SizedBox(height: 8),
        // 目的地
        _buildStationInput('目的地', _toCtrl, stations),
        const SizedBox(height: 16),
        // 查询按钮
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _searchRoute,
            icon: const Icon(Icons.route_rounded),
            label: const Text('查询乘车方案', style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // 结果
        if (_planResults.isNotEmpty)
          ..._planResults.map((r) => _resultCard(r)),
      ]),
    );
  }

  Widget _buildStationInput(String label, TextEditingController ctrl, List<String> stations) {
    return GestureDetector(
      onTap: () => _showStationPicker(label, ctrl, stations),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(ctrl.text.isEmpty ? '选择站点...' : ctrl.text,
                    style: TextStyle(fontSize: 15, color: ctrl.text.isEmpty ? AppTheme.textSub : AppTheme.textMain)),
              ),
              const Icon(Icons.keyboard_arrow_down, color: AppTheme.textSub),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _showStationPicker(String label, TextEditingController ctrl, List<String> stations) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: 400,
            color: Colors.white.withValues(alpha: 0.9),
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Text('选择$label', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.darkBlue)),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: stations.length,
                  itemBuilder: (_, i) => ListTile(
                    title: Text(stations[i], style: const TextStyle(fontSize: 15)),
                    onTap: () => Navigator.pop(ctx, stations[i]),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    if (picked != null) {
      setState(() => ctrl.text = picked);
    }
  }

  Widget _resultCard(_RoutePlan r) {
    final type = r.type;
    IconData icon;
    Color color;
    switch (type) {
      case 'direct':  icon = Icons.check_circle;  color = AppTheme.success; break;
      case 'transfer': icon = Icons.swap_horiz;    color = AppTheme.warning; break;
      case 'info':    icon = Icons.info;           color = AppTheme.primary; break;
      default:        icon = Icons.error;          color = AppTheme.danger;  break;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 12),
                Expanded(child: Text(r.desc, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textMain))),
              ]),
            ),
            // 站点时间线
            if (r.stations != null && r.stations!.isNotEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(28, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (type == 'transfer' && r.transferAt != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('在「${r.transferAt}」换乘',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.warning)),
                      ),
                    ],
                    ...r.stations!.asMap().entries.map((e) {
                      final idx = e.key;
                      final name = e.value;
                      final isLast = idx == r.stations!.length - 1;
                      final isFirst = idx == 0;
                      return SizedBox(
                        height: 44,
                        child: Row(children: [
                          SizedBox(width: 26, child: Column(children: [
                            Container(
                              width: 22, height: 22,
                              decoration: BoxDecoration(
                                color: isFirst ? AppTheme.success : (isLast ? AppTheme.primary : AppTheme.primary.withValues(alpha: 0.7)),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Center(child: Text('${idx + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                            ),
                            if (!isLast) Expanded(child: Container(width: 2, color: AppTheme.primary.withValues(alpha: 0.2))),
                          ])),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(name, style: TextStyle(
                                fontSize: 14,
                                fontWeight: isFirst || isLast ? FontWeight.w600 : FontWeight.normal,
                                color: isFirst || isLast ? AppTheme.primary : AppTheme.textMain)),
                          ),
                        ]),
                      );
                    }),
                  ],
                ),
              ),
          ]),
        ),
      ),
    );
  }

  // ─── Mock 数据 ───
  List<dynamic> _mockData() {
    return [
      {
        'lineId': 1, 'lineName': '八号门A线', 'directionType': 0,
        'startTime': '07:30', 'endTime': '22:30', 'intervalMins': 15,
        'stations': {
          '0': _s(['八号门动物医院','经济管理学院','资源环境学院','六号门','园艺园林学院','共青团花园','楠园','校史馆','第二十一教学楼','中心图书馆','第八教学楼','行署楼','田家炳教育书院','圆顶','五号门']),
          '1': _s(['五号门','圆顶','田家炳教育书院','行署楼','第八教学楼','中心图书馆','第二十一教学楼','校史馆','楠园','共青团花园','园艺园林学院','六号门','资源环境学院','经济管理学院','八号门动物医院']),
        }
      },
      {
        'lineId': 2, 'lineName': '八号门B线', 'directionType': 0,
        'startTime': '07:30', 'endTime': '22:30', 'intervalMins': 15,
        'stations': {
          '0': _s(['八号门动物医院','经济管理学院','资源环境学院','六号门','园艺园林学院','共青团花园','楠园','校史馆','第二十一教学楼','中心图书馆','地理科学学院','心理学部','外国语学院','药学院','梅园','橘园','桃园','四新村博士公寓']),
        }
      },
      {
        'lineId': 3, 'lineName': '音乐学院A线', 'directionType': 0,
        'startTime': '07:30', 'endTime': '22:30', 'intervalMins': 15,
        'stations': {
          '0': _s(['音乐学院','第八教学楼','地理科学学院','心理学部','外国语学院','药学院','梅园','橘园','桃园','四新村博士公寓']),
        }
      },
      {
        'lineId': 5, 'lineName': '新药化大楼A线(循环)', 'directionType': 1,
        'startTime': '07:30', 'endTime': '22:30', 'intervalMins': 15,
        'stations': {
          '0': _s(['药学院','梅园','橘园','桃园','四新村博士公寓','圆顶','田家炳教育书院','第八教学楼','地理科学学院','心理学部','药学院']),
        }
      },
      {
        'lineId': 7, 'lineName': '蚕学宫线', 'directionType': 0,
        'startTime': '07:30', 'endTime': '22:30', 'intervalMins': 15,
        'stations': {
          '0': _s(['蚕学宫','楠园','竹园']),
        }
      },
    ];
  }

  static List<Map<String, dynamic>> _s(List<String> names) {
    return [for (var i = 0; i < names.length; i++) {'stop_order': i + 1, 'station_name': names[i]}];
  }
}

class _RoutePlan {
  final String type;       // direct / transfer / info / none
  final String desc;
  final String? lineName;
  final List<String>? stations;
  final String? transferAt;

  _RoutePlan(this.type, this.desc, {this.lineName, this.stations, this.transferAt});
}
