// lib/features/spot/spot_detail_page.dart
import 'dart:ui'; // 引入 ui 库以使用 ImageFilter

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:dio/dio.dart';

import '../../core/theme/app_theme.dart';
import '../../core/network/network_client.dart';
import '../cache/cache_service.dart';
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

  String? _guideScript;

  @override
  void initState() {
    super.initState();
    _fetchRealData();
  }

  Future<void> _fetchRealData() async {
    Map<String, dynamic>? cachedSpot;
    String? cachedGuide;
    try {
      final cachedSpots = await CacheService.getCachedSpots();
      for (final s in cachedSpots) {
        if (s['id'] == widget.spotId) {
          cachedSpot = s;
          break;
        }
      }
      final guide = await CacheService.getCachedGuide(widget.spotId);
      cachedGuide = guide?['script_content']?.toString();
    } catch (_) {}

    try {
      final responses = await Future.wait([
        NetworkClient.get('/spot/${widget.spotId}'),
        NetworkClient.get('/guide/content/${widget.spotId}')
      ].map((future) => future.catchError((e) {
        debugPrint('关联请求失败: $e');
        return Response(requestOptions: RequestOptions(path: ''), data: {'code': 500});
      })));

      final spotResponse = responses[0];
      final guideResponse = responses[1];

      if (spotResponse.data['code'] == 200) {
        final data = spotResponse.data['data'];
        if (mounted) {
          setState(() {
            _spotData = SpotModel.fromJson(data);
          });
        }
      } else if (cachedSpot != null) {
        if (mounted) {
          setState(() {
            _spotData = SpotModel.fromJson(cachedSpot!);
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

      String? realVideoUrl;
      if (guideResponse.data['code'] == 200 && guideResponse.data['data'] != null) {
        final guideData = guideResponse.data['data'];
        realVideoUrl = guideData['videoUrl'];

        if (guideData['scriptContent'] != null && guideData['scriptContent'].toString().isNotEmpty) {
          _guideScript = _stripHtmlIfNeeded(guideData['scriptContent']);
        }
      } else if (cachedGuide != null && cachedGuide.isNotEmpty) {
        _guideScript = _stripHtmlIfNeeded(cachedGuide);
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      _initVideoPlayer(realVideoUrl);

    } catch (e) {
      debugPrint('==== 网络请求异常: $e ====');
      if (cachedSpot != null && mounted) {
        setState(() {
          _spotData = SpotModel.fromJson(cachedSpot!);
          if (cachedGuide != null && cachedGuide.isNotEmpty) {
            _guideScript = _stripHtmlIfNeeded(cachedGuide);
          }
          _isLoading = false;
          _errorMessage = '';
        });
        return;
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '网络连接异常。请先在「离线地图数据」页下载缓存，或检查后端 IP 配置。';
        });
      }
    }
  }

  String _stripHtmlIfNeeded(String text) {
    String parsedText = text.replaceAll(RegExp(r'</p>|<br/?>', caseSensitive: false), '\n');
    parsedText = parsedText.replaceAll(RegExp(r'<[^>]*>'), '');
    return parsedText.trim();
  }

  Future<void> _initVideoPlayer(String? url) async {
    if (url == null || url.isEmpty) {
      return;
    }

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

  Widget _buildWithFrostedGlassBackground({required Widget scaffold}) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/bg.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(color: AppTheme.pageBg),
          ),
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
            child: Container(
              color: const Color(0xFFE0F2FE).withValues(alpha: 0.45),
            ),
          ),
        ),
        scaffold,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildWithFrostedGlassBackground(
        scaffold: const Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        ),
      );
    }

    if (_errorMessage.isNotEmpty || _spotData == null) {
      return _buildWithFrostedGlassBackground(
        scaffold: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.white.withValues(alpha: 0.5),
            elevation: 0,
            title: const Text('提示'),
          ),
          body: Center(
            child: Text(
              _errorMessage.isNotEmpty ? _errorMessage : '景点数据为空',
              style: const TextStyle(color: AppTheme.danger, fontSize: 16),
            ),
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

    return _buildWithFrostedGlassBackground(
      scaffold: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.white.withValues(alpha: 0.5),
          elevation: 0,
          title: Text(_spotData!.name),
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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

                    const Text(
                      '景点简介',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textMain),
                    ),
                    const SizedBox(height: 12),

                    // 🌟 核心修改：为文字加半透明白底容器，提升可读性
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3), // 与列表卡片保持一致的通透感
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Text(
                        (_guideScript != null && _guideScript!.isNotEmpty)
                            ? _guideScript!
                            : _spotData!.description,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppTheme.textMain, // 保持深色文字以确保可读性
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

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
      ),
    );
  }
}