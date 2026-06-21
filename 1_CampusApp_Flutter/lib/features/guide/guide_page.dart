import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/network_client.dart';
import '../../core/theme/app_theme.dart';

class GuidePage extends StatefulWidget {
  final String? spotName;
  final String? initialDescription;

  const GuidePage({super.key, this.spotName, this.initialDescription});

  @override
  State<GuidePage> createState() => _GuidePageState();
}

class _GuidePageState extends State<GuidePage> {
  static const MethodChannel _ttsChannel = MethodChannel(
    'smart_campus_guide/tts',
  );
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<void>? _audioCompleteSub;
  int _playbackSerial = 0;

  String _spotName = '';
  String _guideText = '';
  String _persona = '新生';
  String _language = 'zh';
  String _voice = 'gentle_guide';
  String _guideMode = 'standard';
  double _rate = 1.0;
  bool _loading = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _spotName = widget.spotName ?? '';
    _guideText = _sanitizeGuideText(widget.initialDescription ?? '');
    if (_spotName.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchGuide());
    }
  }

  @override
  void dispose() {
    _stop(updateState: false);
    _audioCompleteSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _fetchGuide() async {
    if (_spotName.trim().isEmpty) return;
    final requestLanguage = _language;
    final requestPersona = _persona;
    final requestVoice = _voice;
    final requestMode = _guideMode;
    setState(() => _loading = true);
    try {
      final res = await NetworkClient.dio.post(
        '/ai/guide/dynamic',
        data: {
          'spotName': _spotName,
          'persona': requestPersona,
          'language': requestLanguage,
          'voice': requestVoice,
          'style': requestMode,
          'guideMode': requestMode,
          'forceRefresh': false,
          'environment': {
            'scene': 'vision_linked_guide',
            'visualContext': widget.initialDescription ?? '',
          },
        },
      );
      final text = res.data['code'] == 200
          ? _sanitizeGuideText((res.data['data']?['text'] ?? '').toString())
          : '';
      if (!mounted || _language != requestLanguage) return;
      setState(() {
        _guideText = text.isNotEmpty
            ? text
            : (_guideText.isNotEmpty
                  ? _guideText
                  : _emptyGuideText(requestLanguage));
      });
    } catch (_) {
      if (!mounted || _language != requestLanguage) return;
      setState(() {
        _guideText = _guideText.isNotEmpty
            ? _guideText
            : _serviceUnavailableText(requestLanguage);
      });
    } finally {
      if (mounted && _language == requestLanguage) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _stop();
      return;
    }
    final metricStart = DateTime.now();
    debugPrint('[TTS_METRIC] click_start spot=$_spotName');
    await _startPlayback(metricStart: metricStart);
  }

  Future<void> _startPlayback({DateTime? metricStart}) async {
    final effectiveMetricStart = metricStart ?? DateTime.now();
    if (_guideText.trim().isEmpty) {
      await _fetchGuide();
    }
    final text = _sanitizeGuideText(_guideText);
    if (text.isEmpty) return;
    final playbackSerial = ++_playbackSerial;
    await _stop(updateState: false, invalidate: false, markStopped: false);
    if (!mounted || playbackSerial != _playbackSerial) return;
    final voice = _voice;
    final language = _language;
    final rate = _rate;
    final elapsedMs = DateTime.now()
        .difference(effectiveMetricStart)
        .inMilliseconds;
    debugPrint(
      '[TTS_METRIC] tts_request_start serial=$playbackSerial elapsed_ms=$elapsedMs chars=${text.length} voice=$voice language=$language',
    );
    setState(() => _isPlaying = true);
    if (_shouldUseNativeTts(language)) {
      final ok = await _playNativeTts(
        text,
        playbackSerial,
        voice: voice,
        language: language,
        rate: rate,
      );
      if (!ok && mounted) setState(() => _isPlaying = false);
      return;
    }
    try {
      final ok = await _playCloudTtsChunks(
        text,
        playbackSerial,
        metricStart: effectiveMetricStart,
        voice: voice,
        language: language,
        rate: rate,
      );
      if (ok) {
        return;
      }
    } catch (e) {
      debugPrint('云端 TTS 播放失败，不使用系统 TTS: $e');
    }
    if (mounted && playbackSerial == _playbackSerial) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('云端语音暂不可用，请稍后重试')));
      setState(() => _isPlaying = false);
    }
  }

  bool _shouldUseNativeTts(String language) {
    final normalized = language.toLowerCase();
    return normalized.startsWith('ja') ||
        normalized.startsWith('fr') ||
        normalized.startsWith('ko');
  }

  Future<bool> _playNativeTts(
    String text,
    int playbackSerial, {
    required String voice,
    required String language,
    required double rate,
  }) async {
    if (!mounted || playbackSerial != _playbackSerial) return false;
    await _stop(updateState: false, invalidate: false, markStopped: false);
    if (!mounted || playbackSerial != _playbackSerial) return false;
    try {
      final result = await _ttsChannel.invokeMapMethod<String, dynamic>(
        'speak',
        {'text': text, 'voice': voice, 'language': language, 'rate': rate},
      );
      if (result?['ok'] == true) return true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result?['reason']?.toString() ?? 'TTS 播放失败')),
        );
      }
    } on MissingPluginException {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('TTS 通道不可用')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('TTS 播放失败：$e')));
      }
    }
    return false;
  }

  Future<bool> _playCloudTtsChunks(
    String text,
    int playbackSerial, {
    required DateTime metricStart,
    required String voice,
    required String language,
    required double rate,
  }) async {
    final chunks = _splitTtsChunks(text);
    if (chunks.isEmpty) return false;

    await _audioPlayer.setReleaseMode(ReleaseMode.stop);
    _audioCompleteSub?.cancel();
    _audioCompleteSub = null;

    Future<String?> synthesize(int index) {
      return _synthesizeTtsAudioUrl(
        chunks[index],
        voice: voice,
        language: language,
        rate: rate,
      );
    }

    var nextAudio = synthesize(0);
    for (var index = 0; index < chunks.length; index++) {
      final audioUrl = await nextAudio;
      if (!mounted || playbackSerial != _playbackSerial) return false;
      if (audioUrl == null || audioUrl.isEmpty) {
        if (index == 0) return false;
        break;
      }

      nextAudio = index + 1 < chunks.length
          ? synthesize(index + 1)
          : Future<String?>.value(null);

      final completed = await _playTtsAudioUrlAndWait(
        audioUrl,
        playbackSerial,
        metricStart,
        chunkIndex: index,
      );
      if (!completed) return false;
    }

    if (mounted && playbackSerial == _playbackSerial) {
      setState(() => _isPlaying = false);
    }
    return true;
  }

  Future<String?> _synthesizeTtsAudioUrl(
    String text, {
    required String voice,
    required String language,
    required double rate,
  }) async {
    final res = await NetworkClient.aiDio.post(
      '/api/tts/synthesize',
      data: {'text': text, 'voice': voice, 'language': language, 'rate': rate},
    );
    final payload = res.data['data'];
    final audioUrl = payload is Map ? payload['url']?.toString() : null;
    if (audioUrl == null || audioUrl.isEmpty) return null;
    return _resolveTtsAudioUrl(audioUrl);
  }

  Future<bool> _playTtsAudioUrlAndWait(
    String audioUrl,
    int playbackSerial,
    DateTime metricStart, {
    required int chunkIndex,
  }) async {
    final completed = Completer<void>();
    _audioCompleteSub?.cancel();
    _audioCompleteSub = _audioPlayer.onPlayerComplete.listen((_) {
      if (!completed.isCompleted) completed.complete();
    });
    final elapsedMs = DateTime.now().difference(metricStart).inMilliseconds;
    debugPrint(
      '[TTS_METRIC] audio_play_start serial=$playbackSerial chunk=${chunkIndex + 1} elapsed_ms=$elapsedMs url=$audioUrl',
    );
    await _audioPlayer.play(UrlSource(audioUrl));

    while (!completed.isCompleted) {
      if (!mounted || playbackSerial != _playbackSerial) return false;
      await Future.any([
        completed.future,
        Future<void>.delayed(const Duration(milliseconds: 180)),
      ]);
    }
    return mounted && playbackSerial == _playbackSerial;
  }

  List<String> _splitTtsChunks(String text) {
    final normalized = _sanitizeGuideText(
      text,
    ).replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return const [];

    final chunks = <String>[];
    final buffer = StringBuffer();
    final sentencePattern = RegExp(r'[^。！？!?；;]+[。！？!?；;]?');
    for (final match in sentencePattern.allMatches(normalized)) {
      final sentence = match.group(0)?.trim() ?? '';
      if (sentence.isEmpty) continue;
      final wouldExceed = buffer.length + sentence.length > 90;
      if (wouldExceed && buffer.isNotEmpty) {
        chunks.add(buffer.toString().trim());
        buffer.clear();
      }
      buffer.write(sentence);
      if (buffer.length >= 70) {
        chunks.add(buffer.toString().trim());
        buffer.clear();
      }
    }
    if (buffer.isNotEmpty) chunks.add(buffer.toString().trim());
    if (chunks.isEmpty && normalized.isNotEmpty) return [normalized];
    return chunks;
  }

  Future<void> _stop({
    bool updateState = true,
    bool invalidate = true,
    bool markStopped = true,
  }) async {
    if (invalidate) _playbackSerial++;
    _audioCompleteSub?.cancel();
    _audioCompleteSub = null;
    if (markStopped) {
      if (updateState && mounted) {
        setState(() => _isPlaying = false);
      } else {
        _isPlaying = false;
      }
    }
    try {
      await _audioPlayer.stop();
    } catch (_) {}
    try {
      await _ttsChannel.invokeMethod('stop');
    } catch (_) {}
  }

  String _resolveTtsAudioUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final base = NetworkClient.aiBaseUrl.replaceFirst(RegExp(r'/$'), '');
    final path = url.startsWith('/') ? url : '/$url';
    return '$base$path';
  }

  String _sanitizeGuideText(String text) {
    return text
        .replaceAll(RegExp(r'[（(][^（）()]{0,120}[）)]'), '')
        .replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (m) => m.group(1) ?? '')
        .replaceAll(RegExp(r'[*#>`_~]+'), '')
        .replaceAll(
          RegExp(
            r'(脚步声|手指|指向|转身|微笑|笑意|镜头|旁白|动作|语气|停顿|音效|音乐|掌声|轻声|大声|慢速|快速)[^。！？\n]{0,80}[。！？]?',
          ),
          '',
        )
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim()
        .replaceAll(RegExp(r'^[，,。；;\s]+|[，,。；;\s]+$'), '');
  }

  Future<void> _reloadWith({
    String? persona,
    String? language,
    String? voice,
    String? mode,
    double? rate,
  }) async {
    final wasPlaying = _isPlaying;
    setState(() {
      if (persona != null) _persona = persona;
      if (language != null && language != _language) {
        _language = language;
        _guideText = '';
      }
      if (voice != null) _voice = voice;
      if (mode != null) _guideMode = mode;
      if (rate != null) _rate = rate;
    });
    await _stop();
    await _fetchGuide();
    if (wasPlaying && mounted) {
      final metricStart = DateTime.now();
      debugPrint('[TTS_METRIC] click_start spot=$_spotName reason=reload');
      await _startPlayback(metricStart: metricStart);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _spotName.isEmpty ? '智能讲解' : _spotName;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(
                    '新生',
                    _persona == '新生',
                    () => _reloadWith(persona: '新生', mode: 'practical'),
                  ),
                  _chip(
                    '游客',
                    _persona == '游客',
                    () => _reloadWith(persona: '游客', mode: 'deep'),
                  ),
                  _chip(
                    '校友',
                    _persona == '校友',
                    () => _reloadWith(persona: '校友', mode: 'deep'),
                  ),
                  _chip(
                    '标准',
                    _guideMode == 'standard',
                    () => _reloadWith(mode: 'standard'),
                  ),
                  _chip(
                    '深度',
                    _guideMode == 'deep',
                    () => _reloadWith(mode: 'deep'),
                  ),
                  _chip(
                    '故事',
                    _guideMode == 'story',
                    () => _reloadWith(mode: 'story'),
                  ),
                  _chip(
                    '实用',
                    _guideMode == 'practical',
                    () => _reloadWith(mode: 'practical'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  _chip(
                    '中文',
                    _language == 'zh',
                    () => _reloadWith(language: 'zh'),
                  ),
                  _chip(
                    'EN',
                    _language == 'en',
                    () => _reloadWith(language: 'en'),
                  ),
                  _chip(
                    '阳光女声',
                    _voice == 'gentle_guide',
                    () => _reloadWith(voice: 'gentle_guide'),
                  ),
                  _chip(
                    '温柔女声',
                    _voice == 'young_female',
                    () => _reloadWith(voice: 'young_female'),
                  ),
                  _chip(
                    '朝气男声',
                    _voice == 'young_male',
                    () => _reloadWith(voice: 'young_male'),
                  ),
                  _chip(
                    '京腔男声',
                    _voice == 'calm_male',
                    () => _reloadWith(voice: 'calm_male'),
                  ),
                  _chip('0.8x', _rate == 0.8, () => _reloadWith(rate: 0.8)),
                  _chip('1.0x', _rate == 1.0, () => _reloadWith(rate: 1.0)),
                  _chip('1.25x', _rate == 1.25, () => _reloadWith(rate: 1.25)),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          child: Text(
                            _guideText.isNotEmpty
                                ? _guideText
                                : _placeholderText(_language),
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.75,
                              color: AppTheme.textMain,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _loading ? null : _togglePlay,
                  icon: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                  label: Text(_isPlaying ? '停止播放' : '播放讲解'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppTheme.primary.withValues(alpha: 0.18),
    );
  }

  String _emptyGuideText(String language) {
    return switch (language) {
      'en' => 'No guide script is available yet.',
      'ja' => 'まだ講解文を取得できていません。',
      'fr' => 'Aucun texte de guide n est disponible pour le moment.',
      'ko' => '아직 안내 문구를 가져오지 못했습니다.',
      _ => '暂未获取到讲解词。',
    };
  }

  String _serviceUnavailableText(String language) {
    return switch (language) {
      'en' =>
        'The guide service is temporarily unavailable. Please try again later.',
      'ja' => '講解サービスは一時的に利用できません。しばらくしてからもう一度お試しください。',
      'fr' =>
        'Le service de guide est temporairement indisponible. Veuillez reessayer plus tard.',
      'ko' => '안내 서비스가 일시적으로 사용할 수 없습니다. 잠시 후 다시 시도해 주세요.',
      _ => '讲解服务暂不可用，请稍后重试。',
    };
  }

  String _placeholderText(String language) {
    return switch (language) {
      'en' =>
        'Select a campus spot or enter from an AI vision result to view the guide.',
      'ja' => 'スポットを選択するか、AI 探校の認識結果から講解を開いてください。',
      'fr' =>
        'Selectionnez un lieu du campus ou ouvrez le guide depuis un resultat de reconnaissance IA.',
      'ko' => '캠퍼스 장소를 선택하거나 AI 탐색 인식 결과에서 안내를 열어 주세요.',
      _ => '请选择一个景点或从 AI 探校识别结果进入讲解。',
    };
  }
}
