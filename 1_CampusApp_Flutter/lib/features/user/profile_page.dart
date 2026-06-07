import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/network/network_client.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = true;
  bool _isAdmin = false;
  String _userName = '加载中...';
  String _campusId = '--';

  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
  }

  Future<void> _fetchUserInfo() async {
    final account = NetworkClient.currentAccount;
    if (account.isEmpty) {
      if (mounted) {
        setState(() {
          _userName = '未登录';
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final response = await NetworkClient.dio.get(
        '/user/infoByAccount',
        queryParameters: {'account': account},
      );
      if (response.data['code'] == 200 && response.data['data'] != null) {
        final data = response.data['data'];
        if (mounted) {
          setState(() {
            _userName = data['username'] ?? '未知用户';
            _campusId = data['campusId']?.toString() ?? '暂未绑定';
            _isAdmin = data['role'] == 1;
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleLogout() {
    NetworkClient.currentAccount = '';
    NetworkClient.currentToken = '';
    NetworkClient.currentUserId = 1;
    Navigator.pushNamedAndRemoveUntil(context, AppRouter.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('个人中心', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textMain),
      ),
      body: _ProfileBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 104),
            child: Column(
              children: [
                _GlassPanel(
                  padding: const EdgeInsets.all(22),
                  child: _isLoading
                      ? const SizedBox(height: 78, child: Center(child: CircularProgressIndicator()))
                      : Row(children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primary.withValues(alpha: 0.10),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.82), width: 1.3),
                            ),
                            child: const Icon(Icons.person_rounded, size: 38, color: AppTheme.primary),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(_userName, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: AppTheme.textMain)),
                              const SizedBox(height: 6),
                              Text('ID: $_campusId', style: const TextStyle(color: AppTheme.textSub, fontSize: 14)),
                            ]),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: (_isAdmin ? AppTheme.warning : AppTheme.success).withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
                            ),
                            child: Text(
                              _isAdmin ? '管理员' : '普通用户',
                              style: TextStyle(
                                color: _isAdmin ? AppTheme.warning : AppTheme.success,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ]),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: _GlassPanel(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _ProfileActionTile(
                          title: '我的打卡徽章',
                          subtitle: '查看已完成的景点打卡',
                          icon: Icons.stars_rounded,
                          color: AppTheme.warning,
                          onTap: () => Navigator.pushNamed(context, AppRouter.checkin),
                        ),
                        _ProfileActionTile(
                          title: '历史评论',
                          subtitle: '查看待审核、已通过和驳回记录',
                          icon: Icons.forum_rounded,
                          color: AppTheme.primary,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserCommentHistoryPage())),
                        ),
                        _ProfileActionTile(
                          title: '写校园故事',
                          subtitle: '选择地点，把你的故事加入故事库',
                          icon: Icons.edit_note_rounded,
                          color: AppTheme.success,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CampusStoryEditorPage())),
                        ),
                        _ProfileActionTile(
                          title: '路线规划历史',
                          subtitle: '常用路线会在这里汇总',
                          icon: Icons.history_rounded,
                          color: const Color(0xFF7C8DA6),
                          onTap: () {},
                        ),
                        if (_isAdmin)
                          _ProfileActionTile(
                            title: '系统后台数据管理',
                            subtitle: '请在网页端后台继续管理',
                            icon: Icons.admin_panel_settings_rounded,
                            color: AppTheme.danger,
                            onTap: () {},
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _handleLogout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.82),
                      foregroundColor: AppTheme.danger,
                      elevation: 7,
                      shadowColor: Colors.black.withValues(alpha: 0.12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: const Text('退出登录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UserCommentHistoryPage extends StatefulWidget {
  const UserCommentHistoryPage({super.key});

  @override
  State<UserCommentHistoryPage> createState() => _UserCommentHistoryPageState();
}

class _UserCommentHistoryPageState extends State<UserCommentHistoryPage> {
  final List<Map<String, dynamic>> _comments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  Future<void> _fetchComments() async {
    setState(() => _loading = true);
    try {
      final res = await NetworkClient.dio.get('/comment/user/${NetworkClient.currentUserId}');
      final data = res.data['data'];
      if (data is List) {
        _comments
          ..clear()
          ..addAll(data.whereType<Map>().map((item) => Map<String, dynamic>.from(item)));
      }
    } catch (e) {
      debugPrint('评论历史加载失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SimpleGlassPage(
      title: '历史评论',
      child: RefreshIndicator(
        onRefresh: _fetchComments,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _comments.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(22),
                    children: const [
                      _GlassPanel(
                        child: Column(children: [
                          Icon(Icons.forum_outlined, size: 52, color: AppTheme.primary),
                          SizedBox(height: 12),
                          Text('还没有评论记录。去智能讲解里留下第一段校园记忆吧。', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSub, height: 1.6)),
                        ]),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 34),
                    itemCount: _comments.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _CommentCard(comment: _comments[index]),
                  ),
      ),
    );
  }
}

class CampusStoryEditorPage extends StatefulWidget {
  const CampusStoryEditorPage({super.key});

  @override
  State<CampusStoryEditorPage> createState() => _CampusStoryEditorPageState();
}

class _CampusStoryEditorPageState extends State<CampusStoryEditorPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final List<Map<String, dynamic>> _spots = [];
  Map<String, dynamic>? _selectedSpot;
  bool _loadingSpots = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _fetchSpots();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _fetchSpots() async {
    setState(() => _loadingSpots = true);
    try {
      final res = await NetworkClient.dio.get('/spot/list', queryParameters: {'page': 1, 'size': 200});
      final records = res.data['data']?['records'];
      if (records is List) {
        _spots
          ..clear()
          ..addAll(records.whereType<Map>().map((item) => Map<String, dynamic>.from(item)));
        if (_spots.isNotEmpty) _selectedSpot = _spots.first;
      }
    } catch (e) {
      debugPrint('地点列表加载失败: $e');
    } finally {
      if (mounted) setState(() => _loadingSpots = false);
    }
  }

  Future<void> _submitStory() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final spot = _selectedSpot;
    if (spot == null || title.isEmpty || content.length < 20) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请选择地点，并填写标题和不少于20字的故事。')));
      return;
    }

    setState(() => _submitting = true);
    try {
      await NetworkClient.dio.post('/ai/story', data: {
        'spotId': spot['id'],
        'title': title,
        'language': 'zh',
        'sourceType': 'user_submitted',
        'storyContent': content,
        'status': 1,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('校园故事已加入对应地点。')));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('提交失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SimpleGlassPage(
      title: '写校园故事',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 34),
        children: [
          _GlassPanel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('选择地点', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.textMain)),
              const SizedBox(height: 10),
              _loadingSpots
                  ? const LinearProgressIndicator()
                  : DropdownButtonFormField<Map<String, dynamic>>(
                      value: _selectedSpot,
                      isExpanded: true,
                      items: _spots
                          .map((spot) => DropdownMenuItem<Map<String, dynamic>>(
                                value: spot,
                                child: Text((spot['name'] ?? '未命名地点').toString(), overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (value) => setState(() => _selectedSpot = value),
                      decoration: _inputDecoration('把故事挂到哪个地点'),
                    ),
              const SizedBox(height: 14),
              TextField(
                controller: _titleController,
                decoration: _inputDecoration('故事标题'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _contentController,
                minLines: 8,
                maxLines: 12,
                decoration: _inputDecoration('写下你的校园故事'),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _submitStory,
                  icon: _submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.cloud_upload_rounded),
                  label: Text(_submitting ? '提交中...' : '提交故事'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  final Map<String, dynamic> comment;

  const _CommentCard({required this.comment});

  @override
  Widget build(BuildContext context) {
    final status = int.tryParse((comment['status'] ?? 0).toString()) ?? 0;
    final spotName = (comment['spotName'] ?? '校园地点').toString();
    final content = (comment['content'] ?? '').toString();
    final rejectReason = (comment['rejectReason'] ?? '').toString();
    final statusMeta = switch (status) {
      1 => ('已通过', AppTheme.success, Icons.check_circle_rounded),
      2 => ('已驳回', AppTheme.danger, Icons.error_rounded),
      _ => ('待审核', AppTheme.warning, Icons.schedule_rounded),
    };

    return _GlassPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(statusMeta.$3, size: 18, color: statusMeta.$2),
          const SizedBox(width: 7),
          Expanded(child: Text(spotName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textMain))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(color: statusMeta.$2.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
            child: Text(statusMeta.$1, style: TextStyle(fontSize: 12, color: statusMeta.$2, fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 10),
        Text(content, style: const TextStyle(fontSize: 14, height: 1.65, color: AppTheme.textMain)),
        if (rejectReason.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('驳回原因：$rejectReason', style: const TextStyle(fontSize: 13, color: AppTheme.danger, height: 1.5)),
        ],
      ]),
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ProfileActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minVerticalPadding: 14,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
        child: Icon(icon, color: color, size: 23),
      ),
      title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textMain)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSub)),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSub),
      onTap: onTap,
    );
  }
}

class _SimpleGlassPage extends StatelessWidget {
  final String title;
  final Widget child;

  const _SimpleGlassPage({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textMain),
      ),
      body: _ProfileBackground(child: SafeArea(child: child)),
    );
  }
}

class _ProfileBackground extends StatelessWidget {
  final Widget child;

  const _ProfileBackground({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
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
          child: Container(color: const Color(0xFFE0F2FE).withValues(alpha: 0.48)),
        ),
      ),
      child,
    ]);
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.66),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.4),
            boxShadow: [
              BoxShadow(color: AppTheme.primary.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.76),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppTheme.primary.withValues(alpha: 0.10))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primary, width: 1.4)),
  );
}
