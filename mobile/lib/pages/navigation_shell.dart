import 'package:flutter/material.dart';
import 'package:future_world_corn_mobile/theme/app_theme.dart';
import 'package:future_world_corn_mobile/pages/home_page.dart';
import 'package:future_world_corn_mobile/pages/portfolio_page.dart';
import 'package:future_world_corn_mobile/pages/governance_page.dart';
import 'package:future_world_corn_mobile/pages/more_page.dart';

class NavigationShell extends StatefulWidget {
  const NavigationShell({super.key});

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  int _selectedIndex = 0;

  static const _pages = <Widget>[
    HomePage(),
    PortfolioPage(),
    GovernancePage(),
    MorePage(),
  ];

  static const _labels = <String>['首页', '投资', '治理', '更多'];

  static const _icons = <IconData>[
    Icons.home,
    Icons.account_balance_wallet,
    Icons.how_to_vote,
    Icons.more_horiz,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.background,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: AppTheme.muted,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        elevation: 8,
        items: List.generate(
          _pages.length,
          (i) => BottomNavigationBarItem(
            icon: Icon(_icons[i]),
            label: _labels[i],
          ),
        ),
      ),
    );
  }
}
