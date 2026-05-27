import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class GuidePage extends StatefulWidget {
  const GuidePage({super.key});

  @override
  State<GuidePage> createState() => _GuidePageState();
}

class _GuidePageState extends State<GuidePage> {
  bool _isPlaying = false;
  String _currentLang = 'zh';

  void _togglePlay() {
    setState(() => _isPlaying = !_isPlaying);
    // TODO: 触发语音播放/暂停（周玮）
  }

  void _switchLanguage(String lang) {
    setState(() => _currentLang = lang);
    // TODO: 切换语种，重新请求 TTS（周玮）
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('智能讲解')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.headphones, size: 64, color: AppTheme.primary),
            const SizedBox(height: 16),
            const Text('智能讲解播放中...', style: TextStyle(color: AppTheme.textSub)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _togglePlay,
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              label: Text(_isPlaying ? '暂停' : '播放'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _langButton('zh', '中文'),
                _langButton('en', 'English'),
                _langButton('ja', '日本語'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _langButton(String lang, String label) {
    final isActive = _currentLang == lang;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 12)),
        selected: isActive,
        onSelected: (_) => _switchLanguage(lang),
        selectedColor: AppTheme.primary.withValues(alpha: 0.2),
      ),
    );
  }
}
