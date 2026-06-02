import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import 'ai_vision_api.dart';

const Color _schoolBlue = Color(0xFF023D83);

class AiVisionPage extends StatefulWidget {
  const AiVisionPage({super.key});

  @override
  State<AiVisionPage> createState() => _AiVisionPageState();
}

class _AiVisionPageState extends State<AiVisionPage> with WidgetsBindingObserver {
  CameraController? _cameraCtrl;
  List<CameraDescription>? _cameras;
  bool _cameraReady = false;
  bool _recognizing = false;
  AiVisionResult? _result;
  String? _errorMsg;
  String? _statusMsg;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _cameraCtrl;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      ctrl.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraCtrl?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() => _statusMsg = '未检测到摄像头设备');
        return;
      }
      // 优先使用后置摄像头，没有则用前置
      var cam = _cameras!.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );
      _cameraCtrl = CameraController(cam, ResolutionPreset.medium);
      await _cameraCtrl!.initialize();
      if (!mounted) return;
      setState(() {
        _cameraReady = true;
      });
    } on CameraException catch (e) {
      setState(() => _statusMsg = '摄像头初始化失败：${e.description}');
    } catch (e) {
      setState(() => _statusMsg = '摄像头异常：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 相机预览
          _buildPreview(),
          // 扫描框
          if (_cameraReady) _buildScanFrame(),
          // 顶部栏
          _buildTopBar(),
          // AR 识别结果卡片
          if (_result != null) _buildArOverlay(),
          // 错误提示
          if (_errorMsg != null) _buildErrorTip(),
          // 状态提示
          if (_statusMsg != null && !_cameraReady) _buildStatusOverlay(),
          // 底部操作栏
          if (_cameraReady) _buildBottomBar(),
        ],
      ),
    );
  }

  /// 摄像头或图片预览
  Widget _buildPreview() {
    if (_selectedImage != null) {
      return SizedBox.expand(
        child: Image.file(_selectedImage!, fit: BoxFit.cover),
      );
    }

    if (!_cameraReady || _cameraCtrl == null) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: _statusMsg != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.camera_alt,
                      size: 48,
                      color: Colors.white54,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _statusMsg!,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                )
              : const CircularProgressIndicator(color: Colors.white54),
        ),
      );
    }
    return CameraPreview(_cameraCtrl!);
  }

  /// 扫描框
  Widget _buildScanFrame() {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(
            children: [
              _corner(Alignment.topLeft),
              _corner(Alignment.topRight),
              _corner(Alignment.bottomLeft),
              _corner(Alignment.bottomRight),
              Center(
                child: _recognizing
                    ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            '正在识别…',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.account_balance_rounded,
                            size: 60,
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '对准校园建筑',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _corner(Alignment align) {
    return Align(
      alignment: align,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          border: Border(
            left: align == Alignment.topLeft || align == Alignment.bottomLeft
                ? const BorderSide(color: _schoolBlue, width: 3.5)
                : BorderSide.none,
            right: align == Alignment.topRight || align == Alignment.bottomRight
                ? const BorderSide(color: _schoolBlue, width: 3.5)
                : BorderSide.none,
            top: align == Alignment.topLeft || align == Alignment.topRight
                ? const BorderSide(color: _schoolBlue, width: 3.5)
                : BorderSide.none,
            bottom:
                align == Alignment.bottomLeft || align == Alignment.bottomRight
                ? const BorderSide(color: _schoolBlue, width: 3.5)
                : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft: align == Alignment.topLeft
                ? const Radius.circular(8)
                : Radius.zero,
            topRight: align == Alignment.topRight
                ? const Radius.circular(8)
                : Radius.zero,
            bottomLeft: align == Alignment.bottomLeft
                ? const Radius.circular(8)
                : Radius.zero,
            bottomRight: align == Alignment.bottomRight
                ? const Radius.circular(8)
                : Radius.zero,
          ),
        ),
      ),
    );
  }

  /// 顶部栏
  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              const Text(
                'AI 实景识图',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                ),
              ),
              if (_result != null &&
                  _result!.recognized &&
                  _result!.fallback) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '兜底模式',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ],
              const Spacer(),
              // 切换摄像头
              if (_cameras != null && _cameras!.length > 1)
                IconButton(
                  icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                  onPressed: _switchCamera,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 底部操作栏
  Widget _buildBottomBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 从相册选择
              IconButton(
                icon: const Icon(
                  Icons.photo_library_rounded,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: _recognizing ? null : _pickFromGallery,
              ),
              const SizedBox(width: 24),
              // 拍照识别按钮
              GestureDetector(
                onTap: _recognizing ? null : _captureAndRecognize,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: _schoolBlue.withValues(alpha: 0.4),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _recognizing ? Colors.white54 : Colors.white,
                      ),
                      child: _recognizing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: _schoolBlue,
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt_rounded,
                              color: _schoolBlue,
                              size: 30,
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 32),
              // 重新识别
              if (_result != null)
                TextButton.icon(
                  icon: const Icon(
                    Icons.refresh,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: const Text(
                    '重新识别',
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: () {
                    setState(() {
                      _result = null;
                      _errorMsg = null;
                      _selectedImage = null;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// AR 识别结果卡片 (悬浮 AR 标签)
  Widget _buildArOverlay() {
    final result = _result!;
    return Positioned(
      bottom: 180, // 悬浮在底部操作栏上方，考虑到 SafeArea 的高度
      left: 32,
      right: 32,
      child: AnimatedOpacity(
        opacity: 1,
        duration: const Duration(milliseconds: 400),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.93),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
            boxShadow: [
              BoxShadow(
                color: _schoolBlue.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: result.recognized
              ? _buildRecognizedCard(result)
              : _buildUnrecognizedCard(),
        ),
      ),
    );
  }

  /// 识别成功卡片
  Widget _buildRecognizedCard(AiVisionResult result) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.location_on_rounded, color: _schoolBlue, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                result.buildingName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '已识别',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          result.description.isNotEmpty
              ? result.description
              : '这是${result.buildingName}，点击下方按钮了解更多。',
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.textSub,
            height: 1.5,
          ),
        ),
        if (result.fallback) ...[
          const SizedBox(height: 6),
          Text(
            '本地模式识别，结果仅供参考',
            style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
          ),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.photo_library_rounded, size: 16),
                label: const Text('换图片'),
                style: TextButton.styleFrom(foregroundColor: _schoolBlue),
                onPressed: _recognizing ? null : _pickFromGallery,
              ),
              TextButton.icon(
                icon: const Icon(Icons.auto_stories_outlined, size: 16),
                label: const Text('讲讲它的历史'),
                style: TextButton.styleFrom(foregroundColor: _schoolBlue),
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/chat',
                    arguments: {
                      'prompt':
                          '我刚通过 AI 识图扫到了【${result.buildingName}】，请用新生视角介绍它的历史，并告诉我附近还可以看什么。',
                    },
                  );
                },
              ),
              FilledButton.icon(
                icon: const Icon(Icons.psychology_alt_rounded, size: 16),
                label: const Text('问问西小导'),
                style: FilledButton.styleFrom(
                  backgroundColor: _schoolBlue,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/chat',
                    arguments: {
                      'prompt':
                          '我刚通过 AI 识图扫到了【${result.buildingName}】，请用新生视角介绍它，并告诉我附近还可以看什么。',
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 识别失败卡片
  Widget _buildUnrecognizedCard() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.help_outline_rounded, color: Colors.orange, size: 36),
        const SizedBox(height: 10),
        const Text(
          '未能识别',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.orange,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '当前图片未能匹配到校园建筑，请尝试对准建筑主体重新拍摄，或选择更清晰的建筑照片。',
          style: TextStyle(fontSize: 14, color: AppTheme.textSub, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('重新识别'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _schoolBlue,
                side: BorderSide(color: _schoolBlue.withValues(alpha: 0.65)),
              ),
              onPressed: () {
                setState(() {
                  _result = null;
                  _errorMsg = null;
                  _selectedImage = null;
                });
              },
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              icon: const Icon(Icons.photo_library_rounded, size: 16),
              label: const Text('换图片'),
              style: FilledButton.styleFrom(
                backgroundColor: _schoolBlue,
                foregroundColor: Colors.white,
              ),
              onPressed: _recognizing ? null : _pickFromGallery,
            ),
          ],
        ),
      ],
    );
  }

  /// 从相册选择照片 + 识别（自动压缩到 1024px 以内）
  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (xFile == null) return;

    setState(() {
      _recognizing = true;
      _errorMsg = null;
      _result = null;
      _statusMsg = null;
      _selectedImage = File(xFile.path);
    });

    try {
      final bytes = await File(xFile.path).readAsBytes();
      final base64Image = base64.encode(bytes);

      final result = await AiVisionApi.recognize(base64Image);
      if (!mounted) return;

      setState(() {
        _result = result;
        _recognizing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = '识别失败：$e';
        _recognizing = false;
      });
    }
  }

  /// 拍照 + 识别
  Future<void> _captureAndRecognize() async {
    final ctrl = _cameraCtrl;
    if (ctrl == null || !ctrl.value.isInitialized) return;

    setState(() {
      _recognizing = true;
      _errorMsg = null;
      _result = null;
      _selectedImage = null;
    });

    try {
      // 拍照
      final xFile = await ctrl.takePicture();
      if (!mounted) return;

      // 读取图片字节并转 base64
      final bytes = await File(xFile.path).readAsBytes();
      final base64Image = base64.encode(bytes);

      // 调用视觉识别 API
      final result = await AiVisionApi.recognize(base64Image);
      if (!mounted) return;

      setState(() {
        _result = result;
        _recognizing = false;
      });
    } on AiVisionException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = e.message;
        _recognizing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = '识别失败：$e';
        _recognizing = false;
      });
    }
  }

  /// 切换前后摄像头
  Future<void> _switchCamera() async {
    final cams = _cameras;
    if (cams == null || cams.length < 2) return;

    final current = _cameraCtrl!.description;
    final newCam = cams.firstWhere(
      (c) => c.lensDirection != current.lensDirection,
      orElse: () => current,
    );

    await _cameraCtrl?.dispose();
    _cameraCtrl = CameraController(newCam, ResolutionPreset.medium);
    await _cameraCtrl!.initialize();
    if (!mounted) return;
    setState(() {});
  }

  /// 错误提示
  Widget _buildErrorTip() {
    return Positioned(
      bottom: 140,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFE4E6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFBE123C)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _errorMsg!,
                style: const TextStyle(color: Color(0xFFBE123C), fontSize: 13),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _errorMsg = null),
              child: const Icon(
                Icons.close,
                size: 16,
                color: Color(0xFFBE123C),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 无摄像头时的状态覆盖
  Widget _buildStatusOverlay() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.videocam_off_rounded,
            size: 48,
            color: Colors.white54,
          ),
          const SizedBox(height: 16),
          Text(
            _statusMsg ?? '摄像头不可用',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: _recognizing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.photo_library_rounded),
            label: Text(_recognizing ? '识别中...' : '选择图片识别'),
            style: FilledButton.styleFrom(
              backgroundColor: _schoolBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: _recognizing ? null : _pickFromGallery,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text('重试', style: TextStyle(color: Colors.white)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white38),
            ),
            onPressed: () {
              setState(() {
                _statusMsg = null;
              });
              _initCamera();
            },
          ),
        ],
      ),
    );
  }
}
