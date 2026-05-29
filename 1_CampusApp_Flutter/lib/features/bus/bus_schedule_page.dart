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
    _loadLines();
  }

  Future<void> _loadLines() async {
    try {
      final res = await NetworkClient.dio.get('/bus/lines');
      if (res.data['code'] == 200) {
        setState(() => _lines = res.data['data'] ?? []);
      }
    } catch (_) {
      _lines = _mockData();
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('校园班车', style: TextStyle(color: AppTheme.textMain)),
        backgroundColor: Colors.white.withValues(alpha: 0.85),
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
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
                itemBuilder: (ctx, i) => _buildLineCard(i),
              ),
      ),
    );
  }

  Widget _buildLineCard(int index) {
    final line = _lines[index];
    final name = line['lineName'] ?? '';
    final dirType = line['directionType'] ?? 0;
    final startTime = line['startTime'] ?? '';
    final endTime = line['endTime'] ?? '';
    final interval = line['intervalMins'] ?? '';
    final fare = line['fareInfo'] ?? '';
    final stations = line['stations'] ?? {};
    final expanded = _expandedIndex == index;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _expandedIndex = expanded ? null : index),
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
                    child: Icon(
                      dirType == 1 ? Icons.loop : Icons.swap_horiz,
                      color: dirType == 1 ? AppTheme.warning : AppTheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textMain)),
                        const SizedBox(height: 4),
                        Text('$startTime - $endTime | 约$interval分钟/班 | $fare',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSub)),
                      ],
                    ),
                  ),
                  Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: AppTheme.textSub),
                ],
              ),
            ),
          ),
          if (expanded)
            ...stations.entries.map((entry) {
              final dir = entry.key.toString();
              final sts = entry.value as List;
              return _buildStationTimeline(dir, sts, dirType);
            }),
        ],
      ),
    );
  }

  Widget _buildStationTimeline(String dir, List stations, int dirType) {
    final dirLabel = dirType == 1 ? '循环方向' : (dir == '0' ? '上行(去程)' : '下行(返程)');
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: dirType == 1 ? AppTheme.warning.withValues(alpha: 0.1) : AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(dirLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary)),
          ),
          ...stations.asMap().entries.map((e) {
            final idx = e.key;
            final s = e.value;
            final isLast = idx == stations.length - 1;
            return _timelineRow(
              s['stop_order'] ?? (idx + 1),
              s['station_name'] ?? '',
              isLast,
            );
          }),
        ],
      ),
    );
  }

  Widget _timelineRow(dynamic order, String name, bool isLast) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Center(
                    child: Text('$order', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: AppTheme.primary.withValues(alpha: 0.3)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name, style: const TextStyle(fontSize: 14, color: AppTheme.textMain)),
          ),
        ],
      ),
    );
  }

  /// 离线兜底数据
  List<dynamic> _mockData() {
    return [
      {
        'lineId': 1,
        'lineName': '八号门A线',
        'directionType': 0,
        'startTime': '07:30',
        'endTime': '22:30',
        'intervalMins': 15,
        'fareInfo': '一卡通/钉钉扫码',
        'stations': {
          '0': [
            {'stop_order': 1, 'station_name': '八号门动物医院'},
            {'stop_order': 2, 'station_name': '经济管理学院'},
            {'stop_order': 3, 'station_name': '资源环境学院'},
            {'stop_order': 4, 'station_name': '六号门'},
            {'stop_order': 5, 'station_name': '园艺园林学院'},
            {'stop_order': 6, 'station_name': '共青团花园'},
            {'stop_order': 7, 'station_name': '楠园'},
            {'stop_order': 8, 'station_name': '校史馆'},
            {'stop_order': 9, 'station_name': '第二十一教学楼'},
            {'stop_order': 10, 'station_name': '中心图书馆'},
            {'stop_order': 11, 'station_name': '第八教学楼'},
            {'stop_order': 12, 'station_name': '行署楼'},
            {'stop_order': 13, 'station_name': '田家炳教育书院'},
            {'stop_order': 14, 'station_name': '圆顶'},
            {'stop_order': 15, 'station_name': '五号门'},
          ],
          '1': [
            {'stop_order': 1, 'station_name': '五号门'},
            {'stop_order': 2, 'station_name': '圆顶'},
            {'stop_order': 3, 'station_name': '田家炳教育书院'},
            {'stop_order': 4, 'station_name': '行署楼'},
            {'stop_order': 5, 'station_name': '第八教学楼'},
            {'stop_order': 6, 'station_name': '中心图书馆'},
            {'stop_order': 7, 'station_name': '第二十一教学楼'},
            {'stop_order': 8, 'station_name': '校史馆'},
            {'stop_order': 9, 'station_name': '楠园'},
            {'stop_order': 10, 'station_name': '共青团花园'},
            {'stop_order': 11, 'station_name': '园艺园林学院'},
            {'stop_order': 12, 'station_name': '六号门'},
            {'stop_order': 13, 'station_name': '资源环境学院'},
            {'stop_order': 14, 'station_name': '经济管理学院'},
            {'stop_order': 15, 'station_name': '八号门动物医院'},
          ]
        }
      },
      {
        'lineId': 7,
        'lineName': '蚕学宫线',
        'directionType': 0,
        'startTime': '07:30',
        'endTime': '22:30',
        'intervalMins': 15,
        'fareInfo': '一卡通/钉钉扫码',
        'stations': {
          '0': [
            {'stop_order': 1, 'station_name': '蚕学宫'},
            {'stop_order': 2, 'station_name': '楠园(第四运动场)'},
            {'stop_order': 3, 'station_name': '竹园'},
          ]
        }
      },
    ];
  }
}
