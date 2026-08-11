import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bottom-navigation shell holding the five primary destinations.
///
/// Uses `StatefulShellRoute` so each tab keeps its own navigation stack and
/// scroll position - going Coach -> Learn -> back to Train should land you
/// exactly where you were.
class HomeShell extends StatelessWidget {
  const HomeShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const List<NavigationDestination> _destinations =
      <NavigationDestination>[
        NavigationDestination(
          icon: Icon(Icons.today_outlined),
          selectedIcon: Icon(Icons.today),
          label: 'Today',
        ),
        NavigationDestination(
          icon: Icon(Icons.fitness_center_outlined),
          selectedIcon: Icon(Icons.fitness_center),
          label: 'Train',
        ),
        NavigationDestination(
          icon: Icon(Icons.restaurant_outlined),
          selectedIcon: Icon(Icons.restaurant),
          label: 'Eat',
        ),
        NavigationDestination(
          icon: Icon(Icons.trending_up_outlined),
          selectedIcon: Icon(Icons.trending_up),
          label: 'Progress',
        ),
        NavigationDestination(
          icon: Icon(Icons.forum_outlined),
          selectedIcon: Icon(Icons.forum),
          label: 'Coach',
        ),
      ];

  void _onTap(int index) => navigationShell.goBranch(
    index,
    // Tapping the active tab pops it back to its root, which is the
    // behaviour users expect from every other app they use.
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onTap,
        destinations: _destinations,
      ),
    );
  }
}
