import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  String _query = '';

  // 全站功能与景点数据，keywords 字段用于模糊匹配
  final List<Map<String, dynamic>> _allData = [
    {'title': '西小导 AI 对话', 'type': '功能', 'route': '/chat', 'desc': 'AI 虚拟导游，RAG 多轮问答', 'keywords': '西小导 AI 问答 聊天 RAG 导游 虚拟导游 智能体'},
    {'title': 'AI 识图', 'type': '功能', 'route': '/ai_vision', 'desc': '拍下校园建筑获取详细介绍', 'keywords': 'AI 识图 识别 建筑识别 相机 拍照 视觉'},
    {'title': '智能讲解', 'type': '功能', 'route': '/guide', 'desc': '基于 LBS 的多语种语音讲解', 'keywords': '讲解 语音 TTS 多语种 播报'},
    {'title': '路线规划', 'type': '功能', 'route': '/route', 'desc': '校园内智能导航与路线生成', 'keywords': '路线 规划 导航 寻路 步行'},
    {'title': '景点打卡', 'type': '功能', 'route': '/checkin', 'desc': '点亮地图徽章，记录足迹', 'keywords': '打卡 徽章 足迹 成就'},
    {'title': '校园地图', 'type': '功能', 'route': '/map', 'desc': '全局高德地图导览', 'keywords': '地图 导览 定位 GPS 高德'},
    {'title': '中心图书馆', 'type': '景点', 'route': '/spot/2', 'desc': '藏书丰富的现代化学习中心', 'keywords': '图书馆 学习 自习 借书'},
    {'title': '含弘门', 'type': '景点', 'route': '/spot/3', 'desc': '西南大学一号门标志建筑', 'keywords': '含弘门 一号门 校门 入口'},
    {'title': '雨僧楼（第1教学楼）', 'type': '景点', 'route': '/spot/1', 'desc': '历史悠久的红砖建筑', 'keywords': '雨僧楼 1教 第一教学楼 吴宓 文学院'},
    {'title': '校车时刻表', 'type': '服务', 'route': '/bus', 'desc': '查询校园小黄车发车时间', 'keywords': '校车 小黄车 时刻表 班车'},
  ];

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
              _tag('AI 识图', '/ai_vision'),
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
    if (res.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text('暂无搜索结果', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: res.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
      itemBuilder: (context, index) {
        final item = res[index];
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
          title: Text(item['title']!, style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text(item['desc']!, style: const TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.black26),
          onTap: () {
            // 这里如果是景点，应该跳详情页；如果是功能，直接跳路由
            if (item['route']!.isNotEmpty) {
              Navigator.pushNamed(context, item['route']!);
            }
          },
        );
      },
    );
  }
}
