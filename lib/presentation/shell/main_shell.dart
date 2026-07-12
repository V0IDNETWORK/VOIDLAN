import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Hosts the three primary tabs (LAN Explorer, About, Messenger) behind
/// a single [StatefulShellRoute] so each tab keeps its own navigation
/// stack and scroll position when switching away and back.
///
/// Desktop-width layouts (Windows/Linux, or a resized window) get a
/// persistent [NavigationRail]; narrow layouts (Android) get a bottom
/// [NavigationBar] — the same widget tree adapts automatically rather
/// than branching into separate desktop/mobile screens.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    (icon: Icons.radar_outlined, selected: Icons.radar, label: 'LAN Explorer'),
    (icon: Icons.info_outline, selected: Icons.info, label: 'About'),
    (icon: Icons.chat_bubble_outline, selected: Icons.chat_bubble, label: 'Messenger'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        if (isWide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: _onTap,
                  labelType: NavigationRailLabelType.all,
                  leading: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: _BrandMark(compact: true),
                  ),
                  destinations: [
                    for (final d in _destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selected),
                        label: Text(d.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: navigationShell),
              ],
            ),
          );
        }

        return Scaffold(
          body: navigationShell,
          bottomNavigationBar: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _onTap,
            destinations: [
              for (final d in _destinations)
                NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selected),
                  label: d.label,
                ),
            ],
          ),
        );
      },
    );
  }

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFF7B2FFF), Color(0xFF00E5FF)],
      ).createShader(bounds),
      child: Icon(Icons.hub_outlined, size: compact ? 28 : 40, color: Colors.white),
    );
  }
}
