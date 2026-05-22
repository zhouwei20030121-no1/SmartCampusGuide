import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('个人中心')),
      body: const Center(
        child: Text('个人中心页面 - 待实现（李卓尔）',
            style: TextStyle(color: AppTheme.textSub)),
      ),
    );
  }
}
