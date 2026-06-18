import 'package:flutter/material.dart';

import '../../core/network/network_client.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../cache/cache_service.dart';
import '../spot/spot_model.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  String _query = '';
  List<SpotModel> _spots = [];
  bool _loadingSpots = false;

  // 全站功能数据，keywords 字段用于模糊匹配
  final List<Map<String, dynamic>> _functionData = [
    {'title': '西小导 AI 对话', 'type': '功能', 'route': '/chat', 'desc': 'AI 虚拟导游，RAG 多轮问答', 'keywords': '西小导 AI 问答 聊天 RAG 导游 虚拟导游 智能体'},
    {'title': 'AI 探校', 'type': '功能', 'route': '/ai_vision', 'desc': '拍下校园建筑获取详细介绍', 'keywords': 'AI 探校 识图 识别 建筑识别 相机 拍照 视觉'},
    {'title': '智能讲解', 'type': '功能', 'route': '/guide', 'desc': '基于 LBS 的多语种语音讲解', 'keywords': '讲解 语音 TTS 多语种 播报'},
    {'title': '路线规划', 'type': '功能', 'route': '/route', 'desc': '校园内智能导航与路线生成', 'keywords': '路线 规划 导航 寻路 步行'},
    {'title': '景点打卡', 'type': '功能', 'route': '/checkin', 'desc': '点亮地图徽章，记录足迹', 'keywords': '打卡 徽章 足迹 成就'},
    {'title': '校园地图', 'type': '功能', 'route': '/map', 'desc': '全局高德地图导览', 'keywords': '地图 导览 定位 GPS 高德'},
    {'title': '校车时刻表', 'type': '服务', 'route': '/bus', 'desc': '查询校园小黄车发车时间', 'keywords': '校车 小黄车 时刻表 班车'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSpots();
  }

  Future<void> _loadSpots() async {
    if (_loadingSpots) return;
    setState(() => _loadingSpots = true);
    try {
      final cachedRecords = await CacheService.getCachedSpots();
      if (cachedRecords.isNotEmpty && mounted) {
        setState(() {
          _spots = cachedRecords
              .map((e) => SpotModel.fromJson(e))
              .where((spot) => spot.latitude != 0 && spot.longitude != 0)
              .toList();
        });
      }

      try {
        final res = await NetworkClient.get('/spot/list', queryParameters: {
          'page': 1,
          'size': 1000,
        });
        final data = res.data['data'];
        final records = data is Map ? data['records'] : data;
        if (records is List && mounted) {
          setState(() {
            _spots = records
                .whereType<Map>()
                .map((e) => SpotModel.fromJson(Map<String, dynamic>.from(e)))
                .where((spot) => spot.latitude != 0 && spot.longitude != 0)
                .toList();
          });
          await CacheService.preloadSpots();
        }
      } catch (e) {
        debugPrint('搜索页在线加载失败，使用离线缓存: $e');
      }
    } catch (e) {
      debugPrint('搜索页加载地点失败: $e');
    } finally {
      if (mounted) setState(() => _loadingSpots = false);
    }
  }

  List<Map<String, dynamic>> get _allData {
    final spotData = _spots.map((spot) {
      return {
        'title': spot.name,
        'type': '景点',
        'desc': spot.description,
        'keywords': '${spot.name} ${spot.category} ${spot.description}',
        'spot': spot,
      };
    });
    return [..._functionData, ...spotData];
  }

  List<Map<String, dynamic>> get _results {
    if (_query.trim().isEmpty) return [];
    final q = _query.toLowerCase();
    return _allData.where((item) {
      final title = item['title']!.toString().toLowerCase();
      final desc = item['desc']!.toString().toLowerCase();
      final keywords = (item['keywords'] ?? '').toString().toLowerCase();
      return title.contains(q) || desc.contains(q) || keywords.contains(q);
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _offlineSpotResults(String query) async {
    final offlineSpots = await CacheService.searchSpotsOffline(query);
    return offlineSpots.map((spot) {
      return {
        'title': spot.name,
        'type': '景点',
        'desc': spot.description,
        'keywords': '${spot.name} ${spot.category} ${spot.description}',
        'spot': spot,
        'offline': true,
      };
    }).toList();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        leading: const BackButton(color: Colors.black87),
        title: _buildSearchBar(),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: AppTheme.textMain)),
          ),
        ],
      ),
      body: _query.isEmpty ? _buildRecommend() : _buildResults(),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        controller: _ctrl,
        focusNode: _focus,
        autofocus: true,
        textInputAction: TextInputAction.search,
        onChanged: (v) => setState(() => _query = v),
        decoration: InputDecoration(
          hintText: '搜索校园功能或景点...',
          hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: Colors.black38, size: 20),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.black26, size: 18),
                  onPressed: () {
                    _ctrl.clear();
                    setState(() => _query = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.only(top: -4), // 调整文字对齐
        ),
      ),
    );
  }

  Widget _buildRecommend() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '常用功能',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textMain),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _tag('西小导', '/chat'),
              _tag('AI 探校', '/ai_vision'),
              _tag('路线规划', '/route'),
              _tag('建筑识别', '/ai_vision'),
              _tag('智能讲解', '/guide'),
              _tag('图书馆', ''),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(String text, String route) {
    return GestureDetector(
      onTap: () {
        if (route.isNotEmpty) Navigator.pushNamed(context, route);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(text, style: const TextStyle(fontSize: 13, color: AppTheme.textSub)),
      ),
    );
  }

  Widget _buildResults() {
    final res = _results;
    if (res.isEmpty && _query.trim().isNotEmpty) {
      return FutureBuilder<List<Map<String, dynamic>>>(
        future: _offlineSpotResults(_query),
        builder: (context, snapshot) {
          final offline = snapshot.data ?? [];
          if (offline.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off_rounded,
                      size: 64, color: Colors.grey.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text(
                    _loadingSpots ? '正在加载校园地点...' : '暂无搜索结果',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  if (!_loadingSpots)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        '弱网时可先在「离线地图数据」页下载缓存',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                ],
              ),
            );
          }
          return _buildResultList(offline, showOfflineBadge: true);
        },
      );
    }
    if (res.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 64, color: Colors.grey.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              _loadingSpots ? '正在加载校园地点...' : '暂无搜索结果',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return _buildResultList(res);
  }

  Widget _buildResultList(List<Map<String, dynamic>> items,
      {bool showOfflineBadge = false}) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
      itemBuilder: (context, index) {
        final item = items[index];
        IconData icon;
        Color color;
        if (item['type'] == '功能') {
          icon = Icons.widgets_rounded;
          color = AppTheme.primary;
        } else if (item['type'] == '景点') {
          icon = Icons.account_balance_rounded;
          color = Colors.orange;
        } else {
          icon = Icons.info_rounded;
          color = Colors.green;
        }

        return ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(item['title']!,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ),
              if (showOfflineBadge || item['offline'] == true)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '离线',
                    style: TextStyle(fontSize: 10, color: Colors.teal),
                  ),
                ),
            ],
          ),
          subtitle: Text(item['desc']!, style: const TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.black26),
          onTap: () {
            final spot = item['spot'];
            if (spot is SpotModel) {
              Navigator.pushNamed(
                context,
                AppRouter.map,
                arguments: {'spotId': spot.id, 'spotName': spot.name},
              );
              return;
            }

            final route = item['route']?.toString() ?? '';
            if (route.isNotEmpty) {
              Navigator.pushNamed(context, route);
            }
          },
        );
      },
    );
  }
}
