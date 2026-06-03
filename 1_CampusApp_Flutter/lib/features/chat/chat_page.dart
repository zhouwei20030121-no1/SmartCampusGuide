import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'chat_api.dart';

const Color _schoolBlue = Color(0xFF023D83);

class ChatPage extends StatefulWidget {
  final String? initialPrompt;

  const ChatPage({super.key, this.initialPrompt});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String _persona = '新生';
  final _messages = <_ChatMsg>[
    const _ChatMsg(
      text: '你好，我是西小导。你可以问我校园建筑、路线、校史文化或参观建议，我会结合上下文连续回答。',
      isMe: false,
    ),
  ];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final prompt = widget.initialPrompt;
    if (prompt != null && prompt.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _sendText(prompt));
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    await _sendText(text);
  }

  Future<void> _sendText(String text) async {
    if (text.isEmpty || _sending) return;

    final history = _messages
        .where((msg) => !msg.isLoading)
        .map(
          (msg) => {
            'role': msg.isMe ? 'user' : 'assistant',
            'content': msg.text,
          },
        )
        .toList();

    setState(() {
      _sending = true;
      _messages.add(_ChatMsg(text: text, isMe: true));
      _messages.add(
        const _ChatMsg(text: '西小导正在检索校园知识库...', isMe: false, isLoading: true),
      );
    });
    _msgCtrl.clear();
    _scrollToBottom();

    try {
      final result = await ChatApi.sendMessage(
        query: text,
        history: history,
        persona: _persona,
      );
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((msg) => msg.isLoading);
        _messages.add(
          _ChatMsg(
            text: result.reply,
            isMe: false,
            sources: result.sources,
            fallback: result.fallback,
            model: result.model,
          ),
        );
        _sending = false;
      });
    } on ChatApiException catch (e) {
      if (!mounted) return;
      final msg = e.message;
      String friendlyMsg;
      if (msg.contains('连接失败') ||
          msg.contains('Connection refused') ||
          msg.contains('5000')) {
        friendlyMsg = '无法连接西小导服务，请确认 Python AI 服务已在 5000 端口启动。';
      } else if (msg.contains('格式异常') || msg.contains('Format')) {
        friendlyMsg = '西小导服务返回格式异常，请检查 AI 服务日志。';
      } else {
        friendlyMsg = msg;
      }
      setState(() {
        _messages.removeWhere((msg) => msg.isLoading);
        _messages.add(_ChatMsg(text: friendlyMsg, isMe: false, isError: true));
        _sending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((msg) => msg.isLoading);
        _messages.add(
          const _ChatMsg(
            text: '当前使用本地知识库兜底回答，部分生成式能力可能受限，请稍后重试。',
            isMe: false,
            isError: true,
          ),
        );
        _sending = false;
      });
    }
    _scrollToBottom();
  }

  void _showVoiceInputSheet() {
    final voiceSamples = ['最近的食堂怎么走？', '第八教学楼在哪里？', '帮我规划一条参观校园的路线'];
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '语音输入模拟',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                '模拟器中先用语音样例代替真实录音，后续接入 ASR 后可替换为实时语音转文字。',
                style: TextStyle(color: AppTheme.textSub, fontSize: 13),
              ),
              const SizedBox(height: 12),
              for (final sample in voiceSamples)
                ListTile(
                  leading: const Icon(Icons.mic, color: _schoolBlue),
                  title: Text(sample),
                  onTap: () {
                    Navigator.pop(context);
                    _sendText(sample);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Stack(
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
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                color: const Color(0xFFE0F2FE).withValues(alpha: 0.42),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _ChatStatusBar(
                  persona: _persona,
                  onPersonaChanged: (value) => setState(() => _persona = value),
                  onPromptSelected: _sendText,
                  disabled: _sending,
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) => _ChatBubble(msg: _messages[i]),
                  ),
                ),
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(bottom: 8),
                  child: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.76),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, -3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: '语音输入',
                              onPressed: _sending ? null : _showVoiceInputSheet,
                              icon: const Icon(Icons.mic_none_rounded),
                              color: _schoolBlue,
                            ),
                            Expanded(
                              child: TextField(
                                controller: _msgCtrl,
                                enabled: !_sending,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _send(),
                                decoration: InputDecoration(
                                  hintText: '问西小导任何问题...',
                                  filled: true,
                                  fillColor: Colors.white.withValues(
                                    alpha: 0.86,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide(
                                      color: _schoolBlue.withValues(
                                        alpha: 0.28,
                                      ),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: const BorderSide(
                                      color: _schoolBlue,
                                      width: 1.5,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            CircleAvatar(
                              backgroundColor: _sending
                                  ? Colors.grey.shade400
                                  : _schoolBlue,
                              child: IconButton(
                                icon: Icon(
                                  _sending
                                      ? Icons.hourglass_top_rounded
                                      : Icons.send,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                onPressed: _sending ? null : _send,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _schoolBlue,
                size: 18,
              ),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                '西小导 - AI 对话',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _schoolBlue,
                ),
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _ChatStatusBar extends StatelessWidget {
  final String persona;
  final ValueChanged<String> onPersonaChanged;
  final ValueChanged<String> onPromptSelected;
  final bool disabled;

  const _ChatStatusBar({
    required this.persona,
    required this.onPersonaChanged,
    required this.onPromptSelected,
    required this.disabled,
  });

  @override
  Widget build(BuildContext context) {
    final prompts = [
      '介绍一下计信院',
      '第八教学楼怎么走？',
      '学校有什么特色美食？',
      '推荐一条校园参观路线',
      '校史馆什么时候开放？',
    ];
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.52),
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.psychology_alt,
                    color: _schoolBlue,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'RAG 知识库 + 多轮上下文',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: persona,
                      isDense: true,
                      items: const [
                        DropdownMenuItem(value: '新生', child: Text('新生')),
                        DropdownMenuItem(value: '游客', child: Text('游客')),
                        DropdownMenuItem(value: '校友', child: Text('校友')),
                      ],
                      onChanged: disabled
                          ? null
                          : (value) {
                              if (value != null) onPersonaChanged(value);
                            },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final prompt in prompts) ...[
                      ActionChip(
                        label: Text(prompt),
                        backgroundColor: Colors.white.withValues(alpha: 0.85),
                        side: BorderSide(
                          color: _schoolBlue.withValues(alpha: 0.18),
                        ),
                        onPressed: disabled
                            ? null
                            : () => onPromptSelected(prompt),
                      ),
                      const SizedBox(width: 8),
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

class _ChatMsg {
  final String text;
  final bool isMe;
  final bool isLoading;
  final bool isError;
  final bool fallback;
  final String model;
  final List<String> sources;

  const _ChatMsg({
    required this.text,
    required this.isMe,
    this.isLoading = false,
    this.isError = false,
    this.fallback = false,
    this.model = '',
    this.sources = const [],
  });
}

class _ChatBubble extends StatelessWidget {
  final _ChatMsg msg;

  const _ChatBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final bubbleColor = msg.isMe
        ? _schoolBlue
        : msg.isError
        ? const Color(0xFFFFE4E6)
        : Colors.white.withValues(alpha: 0.86);
    final textColor = msg.isMe
        ? Colors.white
        : msg.isError
        ? const Color(0xFFBE123C)
        : AppTheme.textMain;

    return Align(
      alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: msg.isMe
                ? const Radius.circular(16)
                : const Radius.circular(4),
            bottomRight: msg.isMe
                ? const Radius.circular(4)
                : const Radius.circular(16),
          ),
          border: msg.isMe
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.72)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msg.text, style: TextStyle(color: textColor)),
            if (msg.isLoading) ...[
              const SizedBox(height: 8),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _schoolBlue,
                ),
              ),
            ],
            if (!msg.isMe && msg.sources.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '参考：${msg.sources.take(2).join('、')}',
                style: TextStyle(
                  color: AppTheme.textSub.withValues(alpha: 0.85),
                  fontSize: 11,
                ),
              ),
            ],
            if (!msg.isMe && !msg.fallback && msg.model.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'AI 模型：${msg.model}',
                style: TextStyle(
                  color: AppTheme.textSub.withValues(alpha: 0.85),
                  fontSize: 11,
                ),
              ),
            ],
            if (!msg.isMe && msg.fallback) ...[
              const SizedBox(height: 4),
              const Text(
                '本地知识库兜底回答',
                style: TextStyle(color: _schoolBlue, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
