import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../discover/discover_screen.dart';
import '../surprise/surprise_screen.dart';
import '../history/history_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  late Timer _clockTimer;
  String _timeString = '';
  String _themeName = '';

  final List<Widget> _screens = [
    const DiscoverScreen(),
    const SurpriseModeScreen(),
    const HistoryScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _timeString = _formatDateTime(DateTime.now());
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _updateTime());
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  void _updateTime() {
    final DateTime now = DateTime.now();
    final String formatted = _formatDateTime(now);
    if (mounted) {
      setState(() {
        _timeString = formatted;
      });
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('hh:mm a').format(dateTime);
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(
          onThemeChange: () {
            if (mounted) {
              setState(() {});
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    _themeName = isDark ? "Evening Mode 🌙" : "Afternoon Mode ☀️";

    return Scaffold(
      extendBody: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.primaryNavy : AppTheme.bgLight,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text("💞 ", style: TextStyle(fontSize: 16)),
                    Text(
                      "NextDate",
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: isDark ? Colors.white : AppTheme.primaryNavy,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Text(
                  "$_timeString • $_themeName",
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.softGrey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: isDark ? Colors.white : AppTheme.primaryNavy,
            ),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildRedesignedNavbar(isDark),
    );
  }

  Widget _buildRedesignedNavbar(bool isDark) {
    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).padding.bottom + 16,
        top: 8,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(isDark ? 0.08 : 0.6),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: Colors.white.withOpacity(isDark ? 0.15 : 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                if (isDark)
                  BoxShadow(
                    color: AppTheme.primaryNavy.withOpacity(0.05),
                    blurRadius: 15,
                    spreadRadius: 0,
                  ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavbarItem(
                  index: 0,
                  icon: Icons.explore_outlined,
                  activeIcon: Icons.explore,
                  label: "Discover",
                  isDark: isDark,
                ),
                _buildNavbarItem(
                  index: 1,
                  icon: Icons.casino_outlined,
                  activeIcon: Icons.casino,
                  label: "Surprise",
                  isDark: isDark,
                ),
                _buildNavbarItem(
                  index: 2,
                  icon: Icons.history_outlined,
                  activeIcon: Icons.history,
                  label: "History",
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavbarItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isDark,
  }) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                color: AppTheme.coralAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.coralAccent.withOpacity(0.1),
                    blurRadius: 8,
                  ),
                ],
              )
            : const BoxDecoration(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected
                  ? AppTheme.coralAccent
                  : (isDark ? Colors.white70 : AppTheme.primaryNavy.withOpacity(0.6)),
              size: 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: AppTheme.coralAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
