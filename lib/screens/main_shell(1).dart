import 'package:flutter/material.dart';

import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/banner_ad_widget.dart';
import 'home_screen.dart';
import 'leaderboard_screen.dart';
import 'profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final _leaderboardKey = GlobalKey<LeaderboardScreenState>();
  final _profileKey = GlobalKey<ProfileScreenState>();

  late final List<Widget> _pages = [
    const HomeScreen(),
    LeaderboardScreen(key: _leaderboardKey),
    ProfileScreen(key: _profileKey),
  ];

  void _onTap(int i) {
    if (i == _index) return;
    SoundService.instance.playTap();
    setState(() => _index = i);
    // Oyundan dönülünce puanlar/sıralama güncel görünsün
    if (i == 1) _leaderboardKey.currentState?.reload();
    if (i == 2) _profileKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_index != 0) setState(() => _index = 0);
      },
      child: Scaffold(
        backgroundColor: AppColors.bg0,
        body: AppBackground(
          child: Column(
            children: [
              Expanded(
                child: IndexedStack(index: _index, children: _pages),
              ),
              const BannerAdWidget(),
              _buildNavBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavBar() {
    const items = [
      (Icons.home_rounded, 'ANA SAYFA'),
      (Icons.leaderboard_rounded, 'SIRALAMA'),
      (Icons.person_rounded, 'PROFİL'),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF120E36).withOpacity(0.92),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (int i = 0; i < items.length; i++)
                _NavItem(
                  icon: items[i].$1,
                  label: items[i].$2,
                  selected: _index == i,
                  onTap: () => _onTap(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: selected ? 18 : 16,
          vertical: 11,
        ),
        decoration: BoxDecoration(
          gradient: selected ? AppGradients.gold : null,
          borderRadius: BorderRadius.circular(22),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.gold.withOpacity(0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: selected ? AppColors.ink : Colors.white38,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: selected
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
