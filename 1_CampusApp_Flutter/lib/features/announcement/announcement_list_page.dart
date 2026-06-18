import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/network_client.dart';
import 'announcement_detail_page.dart';

class AnnouncementListPage extends StatefulWidget {
  const AnnouncementListPage({super.key});

  @override
  State<AnnouncementListPage> createState() => _AnnouncementListPageState();
}

class _AnnouncementListPageState extends State<AnnouncementListPage> {
  List<dynamic> _announcements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final res = await NetworkClient.dio.get('/announcement/list');
      if (res.data['code'] == 200 && mounted) {
        setState(() {
          _announcements = res.data['data'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          '校园公告',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.primary,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.primary),
        centerTitle: false,
      ),
      // ====================== 层叠背景 + 毛玻璃内容 ======================
      body: Stack(
        children: [
          // 1. 背景图 + 全局模糊 + 蓝色蒙版
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

          // 2. 内容列表
          SafeArea(
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primary,
              ),
            )
                : _announcements.isEmpty
                ? Center(
              child: Text(
                '暂无校园公告',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.primary.withValues(alpha: 0.4),
                ),
              ),
            )
                : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: _announcements.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              physics: const BouncingScrollPhysics(),
              itemBuilder: (ctx, i) {
                final item = _announcements[i];
                return _buildPremiumGlassCard(item);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ====================== 高级毛玻璃公告卡片 ======================
  Widget _buildPremiumGlassCard(dynamic item) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.65),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AnnouncementDetailPage(
                      url: item['pdfUrl'],
                      title: item['title'],
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(22),
              splashColor: AppTheme.primary.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // 图标区域
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.campaign_rounded,
                        color: AppTheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),

                    // 标题 + 时间
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title'] ?? '未命名公告',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textMain,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                size: 14,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                item['publishDate'] ?? '未知日期',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // PDF 标签
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.picture_as_pdf_rounded,
                            size: 14,
                            color: Color(0xFFEF4444),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'PDF',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
