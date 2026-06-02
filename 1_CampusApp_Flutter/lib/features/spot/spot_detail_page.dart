// lib/features/spot/spot_detail_page.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:dio/dio.dart';

import '../../core/theme/app_theme.dart';
import '../../core/network/network_client.dart';
import 'spot_model.dart';

class SpotDetailPage extends StatefulWidget {
  final int spotId;

  const SpotDetailPage({super.key, required this.spotId});

  @override
  State<SpotDetailPage> createState() => _SpotDetailPageState();
}

class _SpotDetailPageState extends State<SpotDetailPage> {
  SpotModel? _spotData;
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;

  int _currentImageIndex = 0;
  bool _isLoading = true;
  String _errorMessage = '';

  // 用于存储从 GuideContent 表拉取的专属讲解词
  String? _guideScript;

  @override
  void initState() {
    super.initState();
    _fetchRealData();
  }

  // 并发调用 Java 后端接口获取基础数据与讲解内容
  Future<void> _fetchRealData() async {
    try {
      // 发起并发网络请求
      final responses = await Future.wait([
        NetworkClient.dio.get('/spot/${widget.spotId}'),
        // 匹配 GuideContentController 中的 @GetMapping("/{spotId}")
        NetworkClient.dio.get('/guide/content/${widget.spotId}')
      ].map((future) => future.catchError((e) {
        debugPrint('关联请求失败: $e');
        return Response(requestOptions: RequestOptions(path: ''), data: {'code': 500});
      })));

      final spotResponse = responses[0];
      final guideResponse = responses[1];

      // 解析景点基础数据
      if (spotResponse.data['code'] == 200) {
        final data = spotResponse.data['data'];
        if (mounted) {
          setState(() {
            _spotData = SpotModel.fromJson(data);
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = spotResponse.data['message'] ?? '获取景点详情失败';
          });
        }
        return;
      }

      // 解析多媒体讲解数据 (GuideContent)
      String? realVideoUrl;
      // 确认接口返回成功，且 data 不为空
      if (guideResponse.data['code'] == 200 && guideResponse.data['data'] != null) {
        final guideData = guideResponse.data['data']; // 直接是 GuideContent 对象

        realVideoUrl = guideData['videoUrl'];

        if (guideData['scriptContent'] != null && guideData['scriptContent'].toString().isNotEmpty) {
          // 清除后端 AI 可能生成的 HTML 标签，如 <h3> 和 <p>
          _guideScript = _stripHtmlIfNeeded(guideData['scriptContent']);
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false; // 图文数据组装完毕，关闭加载动画
        });
      }

      // 异步尝试加载真实视频
      _initVideoPlayer(realVideoUrl);

    } catch (e) {
      debugPrint('==== 网络请求异常: $e ====');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '网络连接异常，请检查后端是否运行并配置了正确的IP';
        });
      }
    }
  }

  // 简单的 HTML 标签过滤工具
  String _stripHtmlIfNeeded(String text) {
    // 将 <p> 替换为换行，去掉其他所有标签
    String parsedText = text.replaceAll(RegExp(r'</p>|<br/?>', caseSensitive: false), '\n');
    parsedText = parsedText.replaceAll(RegExp(r'<[^>]*>'), '');
    return parsedText.trim();
  }

  // 独立的视频初始化方法，真正由数据库驱动
  Future<void> _initVideoPlayer(String? url) async {
    if (url == null || url.isEmpty) {
      // 数据库没有视频时，直接返回，UI 会自动隐藏视频播放区域
      return;
    }

    // 如果是相对路径（如 /videos/xxx.mp4），自动拼接后端基础地址
    String targetVideoUrl = url;
    if (!targetVideoUrl.startsWith('http')) {
      targetVideoUrl = '${NetworkClient.baseUrl}$targetVideoUrl';
    }

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(targetVideoUrl));
      await controller.initialize();

      if (mounted) {
        setState(() {
          _videoPlayerController = controller;
          _chewieController = ChewieController(
            videoPlayerController: _videoPlayerController!,
            aspectRatio: _videoPlayerController!.value.aspectRatio,
            autoPlay: false,
            looping: false,
            materialProgressColors: ChewieProgressColors(
              playedColor: AppTheme.primary,
              handleColor: AppTheme.primary,
              backgroundColor: Colors.grey.withValues(alpha: 0.3),
              bufferedColor: AppTheme.lightBlue,
            ),
            placeholder: Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              ),
            ),
          );
        });
      }
    } catch (e) {
      debugPrint('==== 视频加载失败: $e ====');
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    if (_errorMessage.isNotEmpty || _spotData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('提示')),
        body: Center(
          child: Text(
            _errorMessage.isNotEmpty ? _errorMessage : '景点数据为空',
            style: const TextStyle(color: AppTheme.danger, fontSize: 16),
          ),
        ),
      );
    }

    List<String> displayImages = [];
    if (_spotData!.images.isNotEmpty) {
      displayImages = _spotData!.images;
    } else if (_spotData!.coverImage.isNotEmpty) {
      displayImages = [_spotData!.coverImage];
    }

    return Scaffold(
      appBar: AppBar(title: Text(_spotData!.name)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 高清图片轮播展示区
            if (displayImages.isNotEmpty)
              Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  CarouselSlider(
                    options: CarouselOptions(
                      height: 240,
                      viewportFraction: 1.0,
                      autoPlay: displayImages.length > 1,
                      onPageChanged: (index, reason) {
                        setState(() {
                          _currentImageIndex = index;
                        });
                      },
                    ),
                    items: displayImages.map((imgUrl) {
                      return Builder(
                        builder: (BuildContext context) {
                          final fullImageUrl = imgUrl.startsWith('http')
                              ? imgUrl
                              : '${NetworkClient.baseUrl}$imgUrl';

                          return CachedNetworkImage(
                            imageUrl: fullImageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            placeholder: (context, url) => Container(
                              color: AppTheme.lightBlue.withValues(alpha: 0.3),
                              child: const Center(child: CircularProgressIndicator()),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: AppTheme.lightBlue.withValues(alpha: 0.3),
                              child: const Icon(Icons.broken_image, size: 48, color: AppTheme.primary),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                  if (displayImages.length > 1)
                    Positioned(
                      bottom: 12,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: displayImages.asMap().entries.map((entry) {
                          return Container(
                            width: 8.0,
                            height: 8.0,
                            margin: const EdgeInsets.symmetric(horizontal: 4.0),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentImageIndex == entry.key
                                  ? AppTheme.primary
                                  : Colors.white.withValues(alpha: 0.5),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              )
            else
              Container(
                height: 240,
                width: double.infinity,
                color: AppTheme.lightBlue.withValues(alpha: 0.3),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_not_supported, size: 48, color: AppTheme.primary),
                    SizedBox(height: 8),
                    Text('暂无景点图片', style: TextStyle(color: AppTheme.primary)),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. 标题与评分区域
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _spotData!.name,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, color: AppTheme.warning, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            _spotData!.rating.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 3. 文字介绍排版 (优先展示专属讲解词 scriptContent，没有则展示基础简介)
                  const Text(
                    '景点简介',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textMain),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (_guideScript != null && _guideScript!.isNotEmpty)
                        ? _guideScript!
                        : _spotData!.description,
                    style: const TextStyle(fontSize: 15, color: AppTheme.textSub, height: 1.6),
                  ),
                  const SizedBox(height: 24),

                  // 4. 实景掠影（视频播放器区域）
                  if (_chewieController != null) ...[
                    const Text(
                      '实景掠影',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textMain),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: MediaQuery.of(context).size.width,
                        color: Colors.black,
                        child: AspectRatio(
                          aspectRatio: _videoPlayerController!.value.aspectRatio,
                          child: Chewie(
                            controller: _chewieController!,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
