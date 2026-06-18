import 'package:flutter/material.dart';

import '../../features/user/login_page.dart';
import '../../features/user/register_page.dart';
import '../../features/user/profile_page.dart';
import '../../features/map/map_page.dart';
import '../../features/spot/spot_detail_page.dart';
import '../../features/guide/guide_page.dart';
import '../../features/chat/chat_page.dart';
import '../../features/ai_vision/ai_vision_page.dart';
import '../../features/route/route_page.dart';
import '../../features/route/route_plan_args.dart';
import '../../features/social/checkin_page.dart';
import '../../features/home/home_page.dart';
import '../../features/home/search_page.dart';
import '../../features/bus/bus_schedule_page.dart';
import '../../features/spot/spot_list_page.dart';
import '../../features/story/campus_story_page.dart';
import '../../features/cache/offline_download_page.dart';
// 🌟 1. 必须导入这个公告列表页
import '../../features/announcement/announcement_list_page.dart';

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
  static const String aiVision = '/ai_vision';
  static const String routePlan = '/route';
  static const String checkin = '/checkin';
  static const String campusStory = '/story';
  static const String search = '/search';
  static const String spotList = '/spot/list';
  static const String offlineDownload = '/offline_download';
  // 🌟 2. 定义公告路由常量
  static const String announcement = '/announcement';

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
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => MapPage(
            initialSpotId: int.tryParse(args?['spotId']?.toString() ?? ''),
            initialSpotName: args?['spotName']?.toString(),
          ),
        );
      case spotDetail:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => SpotDetailPage(spotId: args?['spotId'] ?? 0),
        );
      case guide:
        final guideArgs = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => GuidePage(
            spotName: guideArgs?['spotName']?.toString(),
            initialDescription: guideArgs?['description']?.toString(),
          ),
        );
      case chat:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => ChatPage(initialPrompt: args?['prompt']?.toString()),
        );
      case aiVision:
        return MaterialPageRoute(builder: (_) => const AiVisionPage());
      case routePlan:
        final routeArgs = RoutePlanArgs.fromMap(
          settings.arguments as Map<String, dynamic>?,
        );
        return MaterialPageRoute(
          builder: (_) => RoutePage(
            initialEndName: routeArgs?.endName,
            initialStartId: routeArgs?.startId,
            initialEndId: routeArgs?.endId,
            initialWaypointIds: routeArgs?.waypointIds,
            initialStartName: routeArgs?.startName,
            initialStartAliases: routeArgs?.startAliases,
            initialDestinationName: routeArgs?.destinationName,
            initialDestinationAliases: routeArgs?.destinationAliases,
            autoPlanOnOpen:
                (routeArgs?.autoPlan ?? false) ||
                (routeArgs?.hasDestination ?? false),
          ),
        );
      case checkin:
        return MaterialPageRoute(builder: (_) => const CheckinPage());
      case campusStory:
        return MaterialPageRoute(builder: (_) => const CampusStoryPage());
      case busSchedule:
        return MaterialPageRoute(builder: (_) => const BusSchedulePage());
      case search:
        return PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const SearchPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        );
      case spotList:
        return MaterialPageRoute(builder: (_) => const SpotListPage());
      case offlineDownload:
        return MaterialPageRoute(builder: (_) => const OfflineDownloadPage());
      // 🌟 3. 在这里添加 case
      case announcement:
        return MaterialPageRoute(builder: (_) => const AnnouncementListPage());
      default:
        return MaterialPageRoute(builder: (_) => const LoginPage());
    }
  }
}
