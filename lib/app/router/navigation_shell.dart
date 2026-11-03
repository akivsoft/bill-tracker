import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final NotifierProvider<SelectedNavigationDestination, int>
selectedNavigationDestinationProvider =
    NotifierProvider<SelectedNavigationDestination, int>(
      SelectedNavigationDestination.new,
    );

class SelectedNavigationDestination extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}

class AppNavigationShell extends ConsumerWidget {
  const AppNavigationShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int selected = ref.watch(selectedNavigationDestinationProvider);
    final int routeIndex = navigationShell.currentIndex;
    if (selected != routeIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ref
              .read(selectedNavigationDestinationProvider.notifier)
              .select(routeIndex);
        }
      });
    }
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected == routeIndex ? selected : routeIndex,
        onDestinationSelected: (int index) {
          ref
              .read(selectedNavigationDestinationProvider.notifier)
              .select(index);
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Bills',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Wallets',
          ),
          NavigationDestination(
            icon: Icon(Icons.credit_score_outlined),
            selectedIcon: Icon(Icons.credit_score_rounded),
            label: 'Loans',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
