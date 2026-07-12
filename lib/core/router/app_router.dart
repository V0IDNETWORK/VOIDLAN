import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/about/about_screen.dart';
import '../../presentation/lan_explorer/lan_explorer_screen.dart';
import '../../presentation/lan_explorer/widgets/device_details_screen.dart';
import '../../presentation/messenger/chat_screen.dart';
import '../../presentation/messenger/messenger_screen.dart';
import '../../presentation/shell/main_shell.dart';

/// Route paths, centralized so screens navigate via constants instead
/// of hand-typed strings.
class AppRoutes {
  const AppRoutes._();

  static const explorer = '/';
  static const deviceDetails = 'device';
  static const about = '/about';
  static const messenger = '/messenger';
  static const chat = 'chat';
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _explorerTabKey =
    GlobalKey<NavigatorState>(debugLabel: 'explorerTab');
final GlobalKey<NavigatorState> _aboutTabKey =
    GlobalKey<NavigatorState>(debugLabel: 'aboutTab');
final GlobalKey<NavigatorState> _messengerTabKey =
    GlobalKey<NavigatorState>(debugLabel: 'messengerTab');

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoutes.explorer,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          navigatorKey: _explorerTabKey,
          routes: [
            GoRoute(
              path: AppRoutes.explorer,
              builder: (context, state) => const LanExplorerScreen(),
              routes: [
                GoRoute(
                  path: '${AppRoutes.deviceDetails}/:ip',
                  builder: (context, state) => DeviceDetailsScreen(
                    ipAddress: state.pathParameters['ip']!,
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _aboutTabKey,
          routes: [
            GoRoute(
              path: AppRoutes.about,
              builder: (context, state) => const AboutScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _messengerTabKey,
          routes: [
            GoRoute(
              path: AppRoutes.messenger,
              builder: (context, state) => const MessengerScreen(),
              routes: [
                GoRoute(
                  path: '${AppRoutes.chat}/:conversationId',
                  builder: (context, state) => ChatScreen(
                    conversationId: state.pathParameters['conversationId']!,
                    peerName: state.uri.queryParameters['peerName'] ?? 'Unknown',
                    peerId: state.uri.queryParameters['peerId'] ?? '',
                    peerIp: state.uri.queryParameters['peerIp'] ?? '',
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
