import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'cache_service.dart';

class OfflineDownloadPage extends StatefulWidget {
  const OfflineDownloadPage({super.key});

  @override
  State<OfflineDownloadPage> createState() => _OfflineDownloadPageState();
}

class _OfflineDownloadPageState extends State<OfflineDownloadPage> {
  bool _isLoading = false;
  double _progress = 0;
  String _progressLabel = '';
  List<Map<String, dynamic>> _cachedSpots = [];
  Map<String, int> _stats = const {
    'spots': 0,
    'guides': 0,
    'routes': 0,
    'graphEdges': 0,
  };
  String? _lastSyncTime;

  @override
  void initState() {
    super.initState();
    _loadCachedData();
  }

  Future<void> _loadCachedData() async {
    final spots = await CacheService.getCachedSpots();
    final stats = await CacheService.getCacheStats();
    final lastSync = await CacheService.getLastSyncTime();
    if (mounted) {
      setState(() {
        _cachedSpots = spots;
        _stats = stats;
        _lastSyncTime = lastSync;
      });
    }
  }

  Future<void> _handleDownload() async {
    setState(() {
      _isLoading = true;
      _progress = 0;
      _progressLabel = '准备下载…';
    });
    final success = await CacheService.preloadAll(
      onProgress: (stage, progress) {
        if (!mounted) return;
        setState(() {
          _progressLabel = stage;
          _progress = progress;
        });
      },
    );
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '离线数据更新成功！（景点/讲解/路线/路网）'
                : '下载失败：${CacheService.lastError ?? '请检查后端服务和网络'}',
          ),
          backgroundColor: success ? Colors.teal : Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
    _loadCachedData();
  }

  Future<void> _handleClearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清理离线缓存'),
        content: const Text('将删除本地景点、讲解、路线和路网缓存。清理后可通过「一键下载」重新拉取。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认清理')),
        ],
      ),
    );
    if (confirmed != true) return;

    await CacheService.clearCache();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('本地缓存已清空，可点击「一键下载」重新获取'),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
    _loadCachedData();
  }

  String _formatTime(int? ms) {
    if (ms == null) return '未知时间';
    final date = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Color _getCategoryColor(String? category) {
    switch (category?.trim()) {
      case '自然景观':
      case '教学设施':
      case '历史建筑':
      case '校园文化':
      case '生活服务':
        return AppTheme.primary;
      default:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/bg.jpg',
                    fit: BoxFit.cover,
                  ),
                  Container(
                    color: const Color(0xFFE0F2FE).withValues(alpha: 0.45),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildControlPanel(),
                const SizedBox(height: 16),
                Expanded(
                  child: _cachedSpots.isEmpty
                      ? _buildEmptyState()
                      : _buildSpotList(),
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _glassIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              "离线地图数据",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _glassCard(
        borderRadius: 24,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '离线能力概览',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF475569),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _statChip('景点', _stats['spots'] ?? 0, Icons.place_rounded),
                _statChip('讲解', _stats['guides'] ?? 0, Icons.record_voice_over_rounded),
                _statChip('路线', _stats['routes'] ?? 0, Icons.route_rounded),
                _statChip('路网边', _stats['graphEdges'] ?? 0, Icons.hub_rounded),
              ],
            ),
            if (_lastSyncTime != null) ...[
              const SizedBox(height: 10),
              Text(
                '上次同步：$_lastSyncTime',
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ],
            if (_isLoading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Text(
                _progressLabel,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              '弱网可用：查景点 · 看路线方向 · 阅读讲解',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _glassButton(
                    text: "清理缓存",
                    icon: Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                    isOutline: true,
                    onTap: _isLoading ? null : _handleClearCache,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _glassButton(
                    text: "一键下载",
                    icon: Icons.download_rounded,
                    color: AppTheme.primary,
                    isOutline: false,
                    onTap: _isLoading ? null : _handleDownload,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, int count, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text(
            '$label $count',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 80,
            color: AppTheme.primary.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 20),
          const Text(
            "暂无离线数据\n请点击「一键下载」获取景点、讲解、路线与路网",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF94A3B8),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpotList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      physics: const BouncingScrollPhysics(),
      itemCount: _cachedSpots.length,
      itemBuilder: (context, index) {
        final spot = _cachedSpots[index];
        final color = _getCategoryColor(spot['category']);
        return _buildSpotItem(spot, color);
      },
    );
  }

  Widget _buildSpotItem(Map<String, dynamic> spot, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _glassCard(
        borderRadius: 20,
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.place_rounded, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spot['name'] ?? "未知景点",
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMain,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      spot['category'] ?? "通用",
                      style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.teal, size: 20),
                const SizedBox(height: 4),
                Text(
                  _formatTime(spot['cached_at'] as int?),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassCard({
    required Widget child,
    required double borderRadius,
    required EdgeInsets padding,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.65),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.04),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _glassButton({
    required String text,
    required IconData icon,
    required Color color,
    required bool isOutline,
    required VoidCallback? onTap,
  }) {
    return Container(
      decoration: isOutline
          ? BoxDecoration(
              border: Border.all(color: color.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(16),
            )
          : BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: isOutline ? color : Colors.white),
                const SizedBox(width: 6),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isOutline ? color : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _glassIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: AppTheme.primary),
        onPressed: onTap,
      ),
    );
  }
}
