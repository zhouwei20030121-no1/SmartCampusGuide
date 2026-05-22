import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _msgCtrl = TextEditingController();
  final _messages = <_ChatMsg>[];

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  void _send() {
    if (_msgCtrl.text.isEmpty) return;
    setState(() {
      _messages.add(_ChatMsg(_msgCtrl.text, true));
      _messages.add(_ChatMsg('收到你的问题，让我想想...', false));
    });
    _msgCtrl.clear();
    // TODO: 调用 Python RAG 接口获取真实回复（陈昱霖）
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('西小导 - AI 对话')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (ctx, i) => _ChatBubble(msg: _messages[i]),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black12, blurRadius: 4, offset: const Offset(0, -2)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    decoration: InputDecoration(
                      hintText: '问西小导任何问题...',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppTheme.primary,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: _send,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMsg {
  final String text;
  final bool isMe;

  _ChatMsg(this.text, this.isMe);
}

class _ChatBubble extends StatelessWidget {
  final _ChatMsg msg;

  const _ChatBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7),
        decoration: BoxDecoration(
          color: msg.isMe ? AppTheme.primary : Colors.grey[200],
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
        ),
        child: Text(msg.text,
            style: TextStyle(color: msg.isMe ? Colors.white : AppTheme.textMain)),
      ),
    );
  }
}
