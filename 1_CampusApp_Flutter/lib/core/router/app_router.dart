import 'package:flutter/material.dart';

import '../../features/user/login_page.dart';
import '../../features/user/register_page.dart';
import '../../features/user/profile_page.dart';
import '../../features/map/map_page.dart';
import '../../features/spot/spot_detail_page.dart';
import '../../features/guide/guide_page.dart';
import '../../features/chat/chat_page.dart';
import '../../features/ar/ar_page.dart';
import '../../features/route/route_page.dart';
import '../../features/social/checkin_page.dart';
import '../../features/home/home_page.dart';
import '../../features/bus/bus_schedule_page.dart';

class AppRouter {
  static const String busSchedule = '/bus';
  static const String home = '/home';
  static const String login = '/login';
  static const String register = '/register';
  static const String profile = '/profile';
  static const String map = '/map';
  static const String spotDetail = '/spot/detail';
  static const String guide = '/guide';
  static const String chat = '/chat';
  static const String ar = '/ar';
  static const String routePlan = '/route';
  static const String checkin = '/checkin';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(builder: (_) => const HomePage());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterPage());
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfilePage());
      case map:
        return MaterialPageRoute(builder: (_) => const MapPage());
      case spotDetail:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => SpotDetailPage(spotId: args?['spotId'] ?? 0),
        );
      case guide:
        return MaterialPageRoute(builder: (_) => const GuidePage());
      case chat:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => ChatPage(initialPrompt: args?['prompt']?.toString()),
        );
      case ar:
        return MaterialPageRoute(builder: (_) => const ARPage());
      case routePlan:
        return MaterialPageRoute(builder: (_) => const RoutePage());
      case checkin:
        return MaterialPageRoute(builder: (_) => const CheckinPage());
      case busSchedule:
        return MaterialPageRoute(builder: (_) => const BusSchedulePage());
      default:
        return MaterialPageRoute(builder: (_) => const LoginPage());
    }
  }
}
