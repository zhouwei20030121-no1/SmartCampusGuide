import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'features/user/login_page.dart';
import 'core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const SmartCampusApp());
}

class SmartCampusApp extends StatelessWidget {
  const SmartCampusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '西大智能导览',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
