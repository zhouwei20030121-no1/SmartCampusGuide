import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/network/network_client.dart';
import '../../core/theme/app_theme.dart';

class CampusStoryPage extends StatefulWidget {
  const CampusStoryPage({super.key});

  @override
  State<CampusStoryPage> createState() => _CampusStoryPageState();
}

class _CampusStoryPageState extends State<CampusStoryPage> {
  final TextEditingController _searchController = TextEditingController();
  final List<Map<String, dynamic>> _stories = [];
  final List<Map<String, dynamic>> _spots = [];
  Map<String, dynamic>? _selectedSpot;
  bool _loading = true;
  bool _loadingSpots = true;

  @override
  void initState() {
    super.initState();
    _fetchSpots();
    _fetchStories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchSpots() async {
    setState(() => _loadingSpots = true);
    try {
      final res = await NetworkClient.dio.get('/spot/list', queryParameters: {'page': 1, 'size': 200});
      final records = res.data['data']?['records'];
      if (records is List) {
        _spots
          ..clear()
          ..addAll(records.whereType<Map>().map((item) => Map<String, dynamic>.from(item)));
      }
    } catch (e) {
      debugPrint('地点筛选加载失败: $e');
    } finally {
      if (mounted) setState(() => _loadingSpots = false);
    }
  }

  Future<void> _fetchStories() async {
    setState(() => _loading = true);
    try {
      final params = <String, dynamic>{
        'page': 1,
        'size': 80,
        'language': 'zh',
        'keyword': _searchController.text.trim(),
      };
      if (_selectedSpot != null) {
        params['spotId'] = _selectedSpot!['id'];
      }
      final res = await NetworkClient.dio.get('/ai/story/list', queryParameters: params);
      final records = res.data['data']?['records'];
      if (records is List) {
        _stories
          ..clear()
          ..addAll(records.whereType<Map>().map((item) => Map<String, dynamic>.from(item)));
      }
    } catch (e) {
      debugPrint('校园故事加载失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('校园故事', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textMain),
      ),
      body: _StoryBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _fetchStories,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
              children: [
                _buildFilters(),
                const SizedBox(height: 14),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 90),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_stories.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 36),
                    child: _GlassPanel(
                      child: Column(children: [
                        Icon(Icons.auto_stories_outlined, size: 54, color: AppTheme.primary),
                        SizedBox(height: 16),
                        Text(
                          '暂无匹配的校园故事，可以换个关键词或地点试试。',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSub, height: 1.6),
                        ),
                      ]),
                    ),
                  )
                else
                  ..._stories.map((story) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _StoryTile(story: story),
                      )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return _GlassPanel(
      child: Column(children: [
        TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _fetchStories(),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: '搜索故事标题、内容或地点',
            prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _searchController.clear();
                      _fetchStories();
                    },
                  ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.74),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _loadingSpots
                ? const LinearProgressIndicator()
                : DropdownButtonFormField<Map<String, dynamic>?>(
                    value: _selectedSpot,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<Map<String, dynamic>?>(value: null, child: Text('全部地点')),
                      ..._spots.map((spot) => DropdownMenuItem<Map<String, dynamic>?>(
                            value: spot,
                            child: Text((spot['name'] ?? '未命名地点').toString(), overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedSpot = value);
                      _fetchStories();
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.74),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _fetchStories,
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('筛选'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _StoryTile extends StatelessWidget {
  final Map<String, dynamic> story;

  const _StoryTile({required this.story});

  @override
  Widget build(BuildContext context) {
    final title = (story['title'] ?? story['spotName'] ?? '校园故事').toString();
    final content = (story['storyContent'] ?? story['story'] ?? '').toString();
    final spotName = (story['spotName'] ?? '').toString();

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CampusStoryDetailPage(story: story)),
      ),
      child: _GlassPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.auto_stories_outlined, color: AppTheme.warning, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.textMain)),
            ),
          ]),
          if (spotName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(spotName, style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 10),
          Text(
            content,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, height: 1.65, color: AppTheme.textSub),
          ),
        ]),
      ),
    );
  }
}

class CampusStoryDetailPage extends StatelessWidget {
  final Map<String, dynamic> story;

  const CampusStoryDetailPage({super.key, required this.story});

  @override
  Widget build(BuildContext context) {
    final title = (story['title'] ?? story['spotName'] ?? '校园故事').toString();
    final spotName = (story['spotName'] ?? '').toString();
    final content = (story['storyContent'] ?? story['story'] ?? '').toString();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('故事详情', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textMain),
      ),
      body: _StoryBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _GlassPanel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.textMain)),
                  if (spotName.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(spotName, style: const TextStyle(fontSize: 14, color: AppTheme.primary, fontWeight: FontWeight.w800)),
                  ],
                  const SizedBox(height: 18),
                  Text(content, style: const TextStyle(fontSize: 16, height: 1.9, color: AppTheme.textMain)),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryBackground extends StatelessWidget {
  final Widget child;

  const _StoryBackground({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
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
          child: Container(color: const Color(0xFFE0F2FE).withValues(alpha: 0.48)),
        ),
      ),
      child,
    ]);
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;

  const _GlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.64),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.84), width: 1.4),
            boxShadow: [
              BoxShadow(color: AppTheme.primary.withValues(alpha: 0.10), blurRadius: 18, offset: const Offset(0, 8)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
