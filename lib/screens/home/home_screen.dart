import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/preferences_service.dart';
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

  // Theme override state (propagates to main.dart)
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: isDark ? const Color(0xff162536) : Colors.white,
          selectedItemColor: AppTheme.coralAccent,
          unselectedItemColor: AppTheme.softGrey,
          selectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore),
              label: "Discover",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.card_giftcard_outlined),
              activeIcon: Icon(Icons.card_giftcard),
              label: "Surprise",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history),
              label: "History",
            ),
          ],
        ),
      ),
    );
  }
}
