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
      appBar: AppBar(
        title: const Text('校园班车', style: TextStyle(color: AppTheme.textMain)),
        backgroundColor: Colors.white.withValues(alpha: 0.85),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE0F2FE), Color(0xFFF8FAFC)],
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                padding: const EdgeInsets.only(top: 100, bottom: 30, left: 16, right: 16),
                itemCount: _lines.length,
                itemBuilder: (_, i) => _card(i),
              ),
      ),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _expandedIndex = expanded ? null : i),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: dirType == 1
                          ? AppTheme.warning.withValues(alpha: 0.15)
                          : AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(dirType == 1 ? Icons.loop : Icons.swap_horiz,
                        color: dirType == 1 ? AppTheme.warning : AppTheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textMain)),
                      const SizedBox(height: 4),
                      Text('$start - $end | 约${interval}分钟/班 | $fare',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSub)),
                    ]),
                  ),
                  Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppTheme.textSub),
                ],
              ),
            ),
          ),
          if (expanded)
            ...stations.entries.map((e) {
              final dir = e.key.toString();
              final sts = e.value as List;
              return _timeline(dir, sts, dirType);
            }),
        ],
      ),
    );
  }

  Widget _timeline(String dir, List sts, int dirType) {
    final label = dirType == 1 ? '循环方向' : (dir == '0' ? '上行(去程)' : '下行(返程)');
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: dirType == 1 ? AppTheme.warning.withValues(alpha: 0.1) : AppTheme.primary.withValues(alpha: 0.08),
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
            height: 44,
            child: Row(children: [
              SizedBox(width: 24, child: Column(children: [
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(11)),
                  child: Center(child: Text('$order', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                ),
                if (!isLast) Expanded(child: Container(width: 2, color: AppTheme.primary.withValues(alpha: 0.3))),
              ])),
              const SizedBox(width: 12),
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
          '0': [for (var s in ['八号门动物医院','经济管理学院','资源环境学院','六号门','园艺园林学院','共青团花园','楠园','校史馆','第二十一教学楼','中心图书馆','第八教学楼','行署楼','田家炳教育书院','圆顶','五号门']) {'stop_order': _mockStations0.indexOf(s)+1, 'station_name': s}]
        }
      },
      {
        'lineId': 3, 'lineName': '音乐学院A线', 'directionType': 0,
        'startTime': '07:30', 'endTime': '22:30', 'intervalMins': 15, 'fareInfo': '一卡通/钉钉扫码',
        'stations': {
          '0': [for (var s in ['音乐学院','第八教学楼','地理科学学院','心理学部','外国语学院','药学院','梅园','橘园','桃园','四新村博士公寓']) {'stop_order': _mockStations3.indexOf(s)+1, 'station_name': s}]
        }
      },
      {
        'lineId': 7, 'lineName': '蚕学宫线', 'directionType': 0,
        'startTime': '07:30', 'endTime': '22:30', 'intervalMins': 15, 'fareInfo': '一卡通/钉钉扫码',
        'stations': {
          '0': [for (var s in ['蚕学宫','楠园(第四运动场)','竹园']) {'stop_order': _mockStations7.indexOf(s)+1, 'station_name': s}]
        }
      },
    ];
  }
}

const _mockStations0 = ['八号门动物医院','经济管理学院','资源环境学院','六号门','园艺园林学院','共青团花园','楠园','校史馆','第二十一教学楼','中心图书馆','第八教学楼','行署楼','田家炳教育书院','圆顶','五号门'];
const _mockStations3 = ['音乐学院','第八教学楼','地理科学学院','心理学部','外国语学院','药学院','梅园','橘园','桃园','四新村博士公寓'];
const _mockStations7 = ['蚕学宫','楠园(第四运动场)','竹园'];
