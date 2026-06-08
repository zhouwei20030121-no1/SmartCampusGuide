import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'cache_service.dart';

class OfflineDownloadPage extends StatefulWidget {
  const OfflineDownloadPage({super.key});

  @override
  State<OfflineDownloadPage> createState() => _OfflineDownloadPageState();
}

class _OfflineDownloadPageState extends State<OfflineDownloadPage> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _cachedSpots = [];

  @override
  void initState() {
    super.initState();
    _loadCachedData();
  }

  Future<void> _loadCachedData() async {
    final spots = await CacheService.getCachedSpots();
    if (mounted) {
      setState(() => _cachedSpots = spots);
    }
  }

  Future<void> _handleDownload() async {
    setState(() => _isLoading = true);
    final success = await CacheService.preloadSpots();
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '离线数据更新成功！' : '下载失败，请检查网络'),
          backgroundColor: success ? Colors.teal : Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
    _loadCachedData();
  }

  Future<void> _handleClearCache() async {
    await CacheService.clearCache();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('本地缓存已清空'),
          backgroundColor: Colors.blueAccent,
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
      case '自然景观': return const Color(0xFF2563EB);
      case '教学设施': return const Color(0xFF3B82F6);
      case '历史建筑': return const Color(0xFF60A5FA);
      case '校园文化': return const Color(0xFF93C5FD);
      case '生活服务': return const Color(0xFFBFDBFE);
      default: return const Color(0xFF3B82F6);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ====================== 背景层：全屏背景图 + 高斯模糊 + 蓝色蒙版 ======================
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 加载指定背景图
                  Image.asset(
                    'assets/images/bg.jpg',
                    fit: BoxFit.cover,
                  ),
                  // 半透明蓝色蒙版，保证文字可读性
                  Container(
                    color: const Color(0xFFE0F2FE).withOpacity(0.45),
                  ),
                ],
              ),
            ),
          ),

          // ====================== 内容层 ======================
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildControlPanel(),
                const SizedBox(height: 24),
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

  // 标题栏
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
          const Text(
            "离线地图数据",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E40AF),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // 控制面板（毛玻璃悬浮卡片）
  Widget _buildControlPanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _glassCard(
        borderRadius: 24,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "已缓存景点",
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "${_cachedSpots.length}",
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ],
                ),
                _isLoading
                    ? const CircularProgressIndicator(color: Color(0xFF3B82F6))
                    : Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.cloud_done_rounded,
                    color: Color(0xFF3B82F6),
                    size: 32,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
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
                    color: const Color(0xFF2563EB),
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

  // 空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 80,
            color: Colors.blueAccent.withOpacity(0.25),
          ),
          const SizedBox(height: 20),
          const Text(
            "暂无离线数据\n请点击上方按钮下载",
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

  // 缓存列表
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

  // 列表项（高级毛玻璃卡片）
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
                color: color.withOpacity(0.12),
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
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
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
                  _formatTime(spot['cached_at']),
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

  // 毛玻璃卡片 通用组件
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
            color: Colors.white.withOpacity(0.65),
            border: Border.all(color: Colors.white.withOpacity(0.6)),
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E40AF).withOpacity(0.04),
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

  // 毛玻璃按钮 通用组件
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
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(16),
      )
          : BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
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

  // 毛玻璃图标按钮 通用组件
  Widget _glassIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: const Color(0xFF1E40AF)),
        onPressed: onTap,
      ),
    );
  }
}