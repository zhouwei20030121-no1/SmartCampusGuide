import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/router/app_router.dart';
import '../../core/network/network_client.dart';

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
    String account = NetworkClient.currentAccount;
    if (account.isEmpty) {
      if (mounted) setState(() { _userName = '未登录'; _isLoading = false; });
      return;
    }
    try {
      final response = await NetworkClient.dio.get('/user/infoByAccount', queryParameters: {'account': account});
      if (response.data['code'] == 200 && response.data['data'] != null) {
        final data = response.data['data'];
        if (mounted) {
          setState(() {
            _userName = data['username'] ?? '未知用户';
            _campusId = data['campusId'] ?? '暂未绑定';
            _isAdmin = (data['role'] == 1);
            _isLoading = false;
          });
        }
      }
    } catch (_) { if (mounted) setState(() => _isLoading = false); }
  }

  void _handleLogout() {
    NetworkClient.currentAccount = '';
    Navigator.pushNamedAndRemoveUntil(context, AppRouter.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('个人中心', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textMain),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE0F2FE), Color(0xFFEBF5FB), Color(0xFFC2DEF5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // 1. 用户信息卡片 - 增加实体感与阴影
                _buildStyledCard(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Row(
                    children: [
                      Container(
                        width: 70, height: 70,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.primary.withValues(alpha: 0.1)),
                        child: const Icon(Icons.person_rounded, size: 35, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_userName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('ID: $_campusId', style: const TextStyle(color: AppTheme.textSub)),
                      ])),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: _isAdmin ? AppTheme.warning.withValues(alpha: 0.2) : AppTheme.success.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                        child: Text(_isAdmin ? '管理员' : '普通用户', style: TextStyle(color: _isAdmin ? AppTheme.warning : AppTheme.success, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 2. 菜单选项列表
                Expanded(
                  child: _buildStyledCard(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildListTile('我的打卡徽章', Icons.stars_rounded, AppTheme.warning, () => Navigator.pushNamed(context, AppRouter.checkin)),
                        _buildListTile('路线规划历史', Icons.history_rounded, AppTheme.primary, () {}),
                        if (_isAdmin) _buildListTile('系统后台数据管理', Icons.admin_panel_settings_rounded, AppTheme.danger, () {}),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 3. 退出按钮
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: _handleLogout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.danger,
                      elevation: 4, // 增加阴影浮起感
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('退出登录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 统一的白色实心美观卡片风格
  Widget _buildStyledCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8), // 调高白色透明度，使其更像实心
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: child,
    );
  }

  Widget _buildListTile(String title, IconData icon, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.textSub),
      onTap: onTap,
    );
  }
}
