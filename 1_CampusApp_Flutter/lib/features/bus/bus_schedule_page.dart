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

  @override
  void initState() {
    super.initState();
    _load();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 背景图
          Positioned.fill(
            child: Image.asset('assets/images/bg.jpg', fit: BoxFit.cover,
              errorBuilder: (_, __, _) => Container(color: AppTheme.pageBg)),
          ),
          // 毛玻璃蒙版
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                color: const Color(0xFFE0F2FE).withValues(alpha: 0.45),
              ),
            ),
          ),
          // 内容
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildList()),
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
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppTheme.darkBlue, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          const Text('校园班车时刻表',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.darkBlue)),
        ],
      ),
    );
  }

  Widget _buildList() {
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
    final fare = line['fareInfo'] ?? '';
    final stations = line['stations'] as Map<String, dynamic>? ?? {};
    final expanded = _expandedIndex == i;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => setState(() => _expandedIndex = expanded ? null : i),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: dirType == 1
                              ? AppTheme.warning.withValues(alpha: 0.15)
                              : AppTheme.primary.withValues(alpha: 0.12),
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
                          Text('$start - $end | 约${interval}分钟/班',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSub)),
                          Text(fare, style: const TextStyle(fontSize: 11, color: AppTheme.textSub)),
                        ]),
                      ),
                      Icon(expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.textSub),
                    ],
                  ),
                ),
              ),
              if (expanded)
                ...stations.entries.map((e) => _timeline(e.key.toString(), e.value as List, dirType)),
            ],
          ),
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
          final name = s['station_name'] ?? '';
          final isLast = e.key == sts.length - 1;
          return SizedBox(
            height: 46,
            child: Row(children: [
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
            ]),
          );
        }),
      ]),
    );
  }

  List<dynamic> _mockData() {
    return [
      {
        'lineId': 1, 'lineName': '八号门A线', 'directionType': 0,
        'startTime': '07:30', 'endTime': '22:30', 'intervalMins': 15, 'fareInfo': '一卡通/钉钉扫码',
        'stations': {
          '0': _mockStations(['八号门动物医院','经济管理学院','资源环境学院','六号门','园艺园林学院','共青团花园','楠园','校史馆','第二十一教学楼','中心图书馆','第八教学楼','行署楼','田家炳教育书院','圆顶','五号门']),
          '1': _mockStations(['五号门','圆顶','田家炳教育书院','行署楼','第八教学楼','中心图书馆','第二十一教学楼','校史馆','楠园','共青团花园','园艺园林学院','六号门','资源环境学院','经济管理学院','八号门动物医院']),
        }
      },
      {
        'lineId': 3, 'lineName': '音乐学院A线', 'directionType': 0,
        'startTime': '07:30', 'endTime': '22:30', 'intervalMins': 15, 'fareInfo': '一卡通/钉钉扫码',
        'stations': {
          '0': _mockStations(['音乐学院','第八教学楼','地理科学学院','心理学部','外国语学院','药学院','梅园','橘园','桃园','四新村博士公寓']),
        }
      },
      {
        'lineId': 7, 'lineName': '蚕学宫线', 'directionType': 0,
        'startTime': '07:30', 'endTime': '22:30', 'intervalMins': 15, 'fareInfo': '一卡通/钉钉扫码',
        'stations': {
          '0': _mockStations(['蚕学宫','楠园(第四运动场)','竹园']),
        }
      },
    ];
  }

  static List<Map<String, dynamic>> _mockStations(List<String> names) {
    return [for (var i = 0; i < names.length; i++) {'stop_order': i + 1, 'station_name': names[i]}];
  }
}
