// lib/features/spot/spot_list_page.dart
import 'dart:ui'; // 引入 ui 库以使用 ImageFilter

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/network_client.dart';
import 'spot_model.dart';

class SpotListPage extends StatefulWidget {
  const SpotListPage({super.key});

  @override
  State<SpotListPage> createState() => _SpotListPageState();
}

class _SpotListPageState extends State<SpotListPage> {
  final TextEditingController _searchController = TextEditingController();
  List<SpotModel> _spotList = [];
  bool _isLoading = true;
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _fetchSpots();
  }

  Future<void> _fetchSpots() async {
    setState(() => _isLoading = true);
    try {
      final response = await NetworkClient.dio.get(
        '/spot/list',
        queryParameters: {'keyword': _keyword, 'page': 1, 'size': 50},
      );
      if (response.data['code'] == 200) {
        final List<dynamic> records = response.data['data']['records'] ?? [];
        if (mounted) {
          setState(() {
            _spotList = records.map((e) => SpotModel.fromJson(e)).toList();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. 全局背景图
        Positioned.fill(
          child: Image.asset(
            'assets/images/bg.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(color: AppTheme.pageBg),
          ),
        ),
        // 2. 全局毛玻璃蒙版 (参数与 home_page 保持一致)
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
            child: Container(
              color: const Color(0xFFE0F2FE).withValues(alpha: 0.45),
            ),
          ),
        ),
        // 3. 透明主体页面
        Scaffold(
          backgroundColor: Colors.transparent, // 必须透明以透出底部毛玻璃
          appBar: AppBar(
            backgroundColor: Colors.white.withValues(alpha: 0.5), // Appbar 半透明
            elevation: 0,
            title: const Text('全部景点'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(50), // 调整高度对齐主页视觉
              child: Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                child: SizedBox(
                  height: 40, // 强制高度为 40，与主页一致
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '搜索校园景点、服务设施...',
                      hintStyle: TextStyle(
                        color: Colors.black38.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                      prefixIcon: Icon(
                          Icons.search_rounded,
                          color: Colors.black45.withValues(alpha: 0.6),
                          size: 18
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.7), // 背景半透明 0.7
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      // 移除默认的下划线和边框，改用完全对齐主页的圆角和边框颜色
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20), // 圆角 20
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.6), width: 1.0),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.6), width: 1.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: Colors.black45),
                        onPressed: () {
                          _searchController.clear();
                          _keyword = '';
                          _fetchSpots();
                        },
                      )
                          : null,
                    ),
                    style: const TextStyle(fontSize: 13, color: AppTheme.textMain),
                    onSubmitted: (value) {
                      _keyword = value.trim();
                      _fetchSpots();
                    },
                  ),
                ),
              ),
            ),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : _spotList.isEmpty
              ? const Center(child: Text('暂无相关景点', style: TextStyle(color: AppTheme.textSub)))
              : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _spotList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final spot = _spotList[index];
              return _buildSpotCard(context, spot);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSpotCard(BuildContext context, SpotModel spot) {
    String displayImageUrl = spot.coverImage.isNotEmpty ? spot.coverImage : (spot.images.isNotEmpty ? spot.images.first : '');
    if (displayImageUrl.isNotEmpty && !displayImageUrl.startsWith('http')) {
      displayImageUrl = '${NetworkClient.baseUrl}$displayImageUrl';
    }

    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/spot/detail', arguments: {'spotId': spot.id}),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.3), // 大幅降低白底不透明度
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.0), // 细微的白色反光边框
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04), // 极弱的阴影
                blurRadius: 10,
                offset: const Offset(0, 4)
            )
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: displayImageUrl.isNotEmpty
                  ? CachedNetworkImage(imageUrl: displayImageUrl, width: 100, height: 100, fit: BoxFit.cover, errorWidget: (_, __, ___) => _buildPlaceholder())
                  : _buildPlaceholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(spot.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textMain), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const Spacer(),
                    Text(spot.description, style: const TextStyle(fontSize: 12, color: AppTheme.textSub), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black26),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(width: 100, height: 100, color: AppTheme.lightBlue.withValues(alpha: 0.2), child: const Icon(Icons.account_balance, color: AppTheme.primary, size: 32));
  }
}