import 'dart:async';

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
  Timer? _debounce;
  bool _loadingSpots = false;
  List<SpotModel> _spotResults = [];

  static const Map<String, List<String>> _searchAliases = {
    '计信院': ['计算机与信息科学学院 软件学院', '计算机与信息科学学院', '软件学院', '25教', '第25教学楼'],
    '计算机学院': ['计算机与信息科学学院 软件学院', '计算机与信息科学学院', '软件学院'],
    '二十五教': ['25教', '第25教学楼', '计算机与信息科学学院 软件学院'],
    '电信院': ['电子信息工程学院', '博学楼', '明德楼'],
    '数统院': ['数学与统计学院', '数学学院'],
    '生科院': ['生命科学学院'],
    '新传院': ['新闻传媒学院', '传媒学院'],
  };

  // 全站功能数据，景点数据从后端 /spot/list 动态搜索，避免只搜到写死的少数景点。
  final List<Map<String, dynamic>> _featureData = [
    {
      'title': '西小导 AI 对话',
      'type': '功能',
      'route': '/chat',
      'desc': 'AI 虚拟导游，RAG 多轮问答',
      'keywords': '西小导 AI 问答 聊天 RAG 导游 虚拟导游 智能体',
    },
    {
      'title': 'AI 探校',
      'type': '功能',
      'route': '/ai_vision',
      'desc': '拍下校园建筑获取详细介绍',
      'keywords': 'AI 探校 识图 识别 建筑识别 相机 拍照 视觉',
    },
    {
      'title': '智能讲解',
      'type': '功能',
      'route': '/guide',
      'desc': '基于 LBS 的多语种语音讲解',
      'keywords': '讲解 语音 TTS 多语种 播报',
    },
    {
      'title': '路线规划',
      'type': '功能',
      'route': '/route',
      'desc': '校园内智能导航与路线生成',
      'keywords': '路线 规划 导航 寻路 步行',
    },
    {
      'title': '景点打卡',
      'type': '功能',
      'route': '/checkin',
      'desc': '点亮地图徽章，记录足迹',
      'keywords': '打卡 徽章 足迹 成就',
    },
    {
      'title': '校园地图',
      'type': '功能',
      'route': '/map',
      'desc': '全局高德地图导览',
      'keywords': '地图 导览 定位 GPS 高德',
    },
    {
      'title': '校车时刻表',
      'type': '服务',
      'route': '/bus',
      'desc': '查询校园小黄车发车时间',
      'keywords': '校车 小黄车 时刻表 班车',
    },
  ];

  List<Map<String, dynamic>> get _featureResults {
    if (_query.trim().isEmpty) return [];
    final q = _query.toLowerCase();
    return _featureData.where((item) {
      final title = item['title']!.toString().toLowerCase();
      final desc = item['desc']!.toString().toLowerCase();
      final keywords = (item['keywords'] ?? '').toString().toLowerCase();
      return title.contains(q) || desc.contains(q) || keywords.contains(q);
    }).toList();
  }

  void _onQueryChanged(String value) {
    final keyword = value.trim();
    setState(() => _query = value);
    _debounce?.cancel();
    if (keyword.isEmpty) {
      setState(() {
        _loadingSpots = false;
        _spotResults = [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _searchSpots(keyword);
    });
  }

  Future<void> _searchSpots(String keyword) async {
    if (!mounted) return;
    setState(() => _loadingSpots = true);
    try {
      final terms = _expandSearchTerms(keyword);
      final spots = <SpotModel>[];
      final seenSpotIds = <int>{};

      for (final term in terms.take(4)) {
        final termSpots = await _fetchSpotResults(term);
        for (final spot in termSpots) {
          if (seenSpotIds.add(spot.id)) spots.add(spot);
        }
        if (spots.length >= 8) break;
      }

      if (spots.length < 3) {
        final knowledgeTerms = await _searchKnowledgeTerms(terms.join(' '));
        for (final term in knowledgeTerms) {
          if (terms.contains(term)) continue;
          final termSpots = await _fetchSpotResults(term);
          for (final spot in termSpots) {
            if (seenSpotIds.add(spot.id)) spots.add(spot);
          }
          if (spots.length >= 10) break;
        }
      }

      if (!mounted || _query.trim() != keyword) return;
      setState(() {
        _spotResults = spots;
        _loadingSpots = false;
      });
    } catch (_) {
      if (!mounted || _query.trim() != keyword) return;
      setState(() {
        _spotResults = [];
        _loadingSpots = false;
      });
    }
  }

  Future<List<SpotModel>> _fetchSpotResults(String keyword) async {
    final res = await NetworkClient.dio.get(
      '/spot/list',
      queryParameters: {'keyword': keyword, 'page': 1, 'size': 20},
    );
    final records = res.data['code'] == 200
        ? (res.data['data']?['records'] as List? ?? const [])
        : const [];
    return records.map((e) => SpotModel.fromJson(e)).toList();
  }

  Future<List<SpotModel>> _offlineSpotResults(String query) async {
    final keyword = query.trim().toLowerCase();
    if (keyword.isEmpty) return const [];
    final records = await CacheService.getCachedSpots();
    final spots = records.map((item) => SpotModel.fromJson(item)).where((spot) {
      final text = '${spot.name} ${spot.category} ${spot.description}'
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), '');
      final compactKeyword = keyword.replaceAll(RegExp(r'\s+'), '');
      return text.contains(keyword) || text.contains(compactKeyword);
    });
    return spots
        .where((spot) => spot.latitude != 0 && spot.longitude != 0)
        .toList();
  }

  List<String> _expandSearchTerms(String keyword) {
    final compact = keyword.trim().replaceAll(RegExp(r'\s+'), '');
    final terms = <String>[];
    void add(String value) {
      final term = value.trim();
      if (term.isNotEmpty && !terms.contains(term)) terms.add(term);
    }

    add(keyword);
    if (compact != keyword.trim()) add(compact);
    for (final entry in _searchAliases.entries) {
      final alias = entry.key;
      final matchesAlias = alias.contains(compact) || compact.contains(alias);
      final matchesValue = entry.value.any((value) {
        final normalized = value.replaceAll(RegExp(r'\s+'), '');
        return normalized.contains(compact) || compact.contains(normalized);
      });
      if (matchesAlias || matchesValue) {
        for (final value in entry.value) {
          add(value);
        }
      }
    }
    return terms;
  }

  Future<List<String>> _searchKnowledgeTerms(String query) async {
    try {
      final res = await NetworkClient.dio.get(
        '/api/rag/search',
        queryParameters: {'q': query, 'top_k': 5},
      );
      final docs = res.data['code'] == 200
          ? (res.data['data'] as List? ?? const [])
          : const [];
      final terms = <String>[];
      void add(String value) {
        final term = value.trim();
        if (term.length >= 2 && !terms.contains(term)) terms.add(term);
      }

      for (final doc in docs) {
        if (doc is! Map) continue;
        final title = doc['title']?.toString() ?? '';
        add(title);
        for (final part in title.split(RegExp(r'[\s/、，,]+'))) {
          add(part);
        }

        final answer = doc['answer']?.toString() ?? '';
        for (final building in _extractLocatedBuildings(answer)) {
          add(building);
          add(building.replaceAll(RegExp(r'[（(].*?[）)]'), ''));
        }

        final keywords = doc['keywords'];
        if (keywords is List) {
          for (final keyword in keywords.take(8)) {
            add(keyword.toString());
          }
        }
      }
      return terms;
    } catch (_) {
      return const [];
    }
  }

  List<String> _extractLocatedBuildings(String text) {
    final match = RegExp(r'所在楼栋[:：]\s*([^\n]+)').firstMatch(text);
    if (match == null) return const [];
    return (match.group(1) ?? '')
        .split(RegExp(r'[/、，,]| 或 | 和 '))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  @override
  void dispose() {
    _debounce?.cancel();
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
        onChanged: _onQueryChanged,
        onSubmitted: (v) => _searchSpots(v.trim()),
        decoration: InputDecoration(
          hintText: '搜索校园功能或景点...',
          hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: Colors.black38, size: 20),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.cancel,
                    color: Colors.black26,
                    size: 18,
                  ),
                  onPressed: () {
                    _ctrl.clear();
                    _onQueryChanged('');
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
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textMain,
            ),
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
        if (route.isEmpty) {
          _ctrl.text = text;
          _ctrl.selection = TextSelection.collapsed(offset: text.length);
          _onQueryChanged(text);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, color: AppTheme.textSub),
        ),
      ),
    );
  }

  Widget _buildResults() {
    final featureResults = _featureResults;
    final hasResults = featureResults.isNotEmpty || _spotResults.isNotEmpty;
    if (!hasResults && !_loadingSpots) {
      return FutureBuilder<List<SpotModel>>(
        future: _offlineSpotResults(_query),
        builder: (context, snapshot) {
          final offlineSpots = snapshot.data ?? const <SpotModel>[];
          if (offlineSpots.isNotEmpty) {
            return ListView.separated(
              itemCount: offlineSpots.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, indent: 16),
              itemBuilder: (context, index) =>
                  _spotTile(offlineSpots[index], offline: true),
            );
          }

          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 64,
                  color: Colors.grey.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  snapshot.connectionState == ConnectionState.waiting
                      ? '正在搜索景点...'
                      : '暂无搜索结果',
                  style: const TextStyle(color: Colors.grey),
                ),
                if (snapshot.connectionState != ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      '可尝试简称、拼音或相近读音',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    }

    return ListView.separated(
      itemCount:
          featureResults.length + _spotResults.length + (_loadingSpots ? 1 : 0),
      separatorBuilder: (context, index) =>
          const Divider(height: 1, indent: 16),
      itemBuilder: (context, index) {
        if (_loadingSpots && index == 0) {
          return const ListTile(
            leading: SizedBox(
              width: 36,
              height: 36,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            title: Text(
              '正在搜索景点...',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          );
        }

        final effectiveIndex = index - (_loadingSpots ? 1 : 0);
        if (effectiveIndex < _spotResults.length) {
          final spot = _spotResults[effectiveIndex];
          return _spotTile(spot);
        }

        final item = featureResults[effectiveIndex - _spotResults.length];
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
          title: Text(
            item['title']!,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(item['desc']!, style: const TextStyle(fontSize: 12)),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: Colors.black26,
          ),
          onTap: () {
            if (item['route']!.isNotEmpty) {
              Navigator.pushNamed(context, item['route']!);
            }
          },
        );
      },
    );
  }

  Widget _spotTile(SpotModel spot, {bool offline = false}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.account_balance_rounded,
          color: Colors.orange,
          size: 20,
        ),
      ),
      title: Text(
        spot.name,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        '${spot.category}${offline ? ' · 离线缓存' : ''} · ${spot.description}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.black26),
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRouter.map,
          arguments: {'spotId': spot.id, 'spotName': spot.name},
        );
      },
    );
  }
}
