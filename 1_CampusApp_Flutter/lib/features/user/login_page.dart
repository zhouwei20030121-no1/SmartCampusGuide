import 'package:flutter/material.dart';
import '../../core/network/network_client.dart';
import '../../core/router/app_router.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final response = await NetworkClient.dio.post(
        '/user/login',
        data: {
          'account': _accountController.text.trim(),
          'password': _passwordController.text.trim(),
        },
      );

      if (!mounted) return;
      if (response.data['code'] == 200) {
        // 💡 新增：登录成功时，将账号暂存到内存中
        NetworkClient.setLoginSession(
          _accountController.text.trim(),
          response.data['data']?.toString() ?? '',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('登录成功！'),
            backgroundColor: Colors.green,
            duration: Duration(milliseconds: 800),
          ),
        );
        Navigator.pushReplacementNamed(context, AppRouter.home);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.data['message'] ?? response.data['msg'] ?? '账号或密码错误')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('网络连接失败，请检查后端是否启动')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/login_bg.jpg', fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.3)),

          Center(
            child: Transform.translate(
              offset: Offset(0, -MediaQuery.of(context).size.height * 0.10),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 94),
                      padding: const EdgeInsets.fromLTRB(30, 42, 30, 30),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'SWU Guide',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF023D83),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              '西大智慧校园导览',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 30),

                            TextFormField(
                              controller: _accountController,
                              decoration: InputDecoration(
                                labelText: '学号 / 手机号 / 用户名',
                                prefixIcon: const Icon(Icons.person_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              validator: (value) =>
                                  value!.isEmpty ? '请输入账号' : null,
                            ),
                            const SizedBox(height: 20),

                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: '密码',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              validator: (value) =>
                                  value!.isEmpty ? '请输入密码' : null,
                            ),
                            const SizedBox(height: 30),

                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF023D83),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: _isLoading
                                    ? const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                    : const Text(
                                        '登 录',
                                        style: TextStyle(fontSize: 18),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 15),

                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF023D83),
                              ),
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  AppRouter.register,
                                );
                              },
                              child: const Text('没有账号？点击注册'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _buildSchoolBadge(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchoolBadge() {
    const badgeSize = 125.0;
    return Container(
      width: badgeSize,
      height: badgeSize,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: Container(
          color: Colors.white,
          child: Image.asset(
            'assets/images/校徽.png',
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Center(
              child: Text(
                '西大',
                style: TextStyle(
                  color: Color(0xFF023D83),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
