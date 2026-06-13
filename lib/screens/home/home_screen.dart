import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/preferences_service.dart';
import '../../theme/app_theme.dart';
import '../discover/discover_screen.dart';
import '../mutual_swipe/mutual_swipe_screen.dart';
import '../surprise/surprise_screen.dart';
import '../history/history_screen.dart';
import '../onboarding/onboarding_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final PreferencesService _prefs = PreferencesService();

  late Timer _clockTimer;
  String _timeString = '';

  // Theme override state (propagates to main.dart)
  String _themeName = '';

  final List<Widget> _screens = [
    const DiscoverScreen(),
    const MutualSwipeScreen(),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SettingsBottomSheet(
          onDataReset: () {
            Navigator.pop(context);
            // Redirect to onboarding
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const OnboardingScreen()),
            );
          },
          onThemeChange: () {
            // Trigger refresh
            setState(() {});
          },
        );
      },
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
              icon: Icon(Icons.favorite_outline),
              activeIcon: Icon(Icons.favorite),
              label: "Swipe",
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

class _SettingsBottomSheet extends StatefulWidget {
  final VoidCallback onDataReset;
  final VoidCallback onThemeChange;

  const _SettingsBottomSheet({
    Key? key,
    required this.onDataReset,
    required this.onThemeChange,
  }) : super(key: key);

  @override
  State<_SettingsBottomSheet> createState() => _SettingsBottomSheetState();
}

class _SettingsBottomSheetState extends State<_SettingsBottomSheet> {
  final PreferencesService _prefs = PreferencesService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _p1Controller;
  late TextEditingController _p2Controller;
  DateTime? _anniversaryDate;
  String _themeOverride = "auto";

  @override
  void initState() {
    super.initState();
    _p1Controller = TextEditingController(text: _prefs.partner1Name);
    _p2Controller = TextEditingController(text: _prefs.partner2Name);
    _themeOverride = _prefs.themeOverride;
    
    final annivStr = _prefs.anniversaryDate;
    if (annivStr.isNotEmpty) {
      _anniversaryDate = DateTime.tryParse(annivStr);
    }
  }

  @override
  void dispose() {
    _p1Controller.dispose();
    _p2Controller.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final initialDate = _anniversaryDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppTheme.coralAccent,
              primary: AppTheme.coralAccent,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _anniversaryDate = picked;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    await _prefs.setPartner1Name(_p1Controller.text.trim());
    await _prefs.setPartner2Name(_p2Controller.text.trim());
    await _prefs.setThemeOverride(_themeOverride);

    if (_anniversaryDate != null) {
      await _prefs.setAnniversaryDate(_anniversaryDate!.toIso8601String());
    }

    widget.onThemeChange();
    
    // Broadcast theme override to notify main app
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Settings saved successfully! ⚙️"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff162536) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.softGrey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "App Settings",
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.primaryNavy,
                ),
              ),
              const SizedBox(height: 24),
              // Partner 1 Name
              Text(
                "Partner 1 Name",
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _p1Controller,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? AppTheme.primaryNavy : Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? "Cannot be empty" : null,
              ),
              const SizedBox(height: 16),
              // Partner 2 Name
              Text(
                "Partner 2 Name",
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _p2Controller,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? AppTheme.primaryNavy : Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? "Cannot be empty" : null,
              ),
              const SizedBox(height: 16),
              // Anniversary Date Picker
              Text(
                "Anniversary Date",
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.primaryNavy : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.softGrey.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18, color: AppTheme.coralAccent),
                      const SizedBox(width: 12),
                      Text(
                        _anniversaryDate == null
                            ? "Set Date"
                            : DateFormat('MMMM d, yyyy').format(_anniversaryDate!),
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: isDark ? Colors.white : AppTheme.primaryNavy,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Theme Selector
              Text(
                "Theme Override",
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _themeOverride,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? AppTheme.primaryNavy : Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: "auto", child: Text("Auto (Time-based)")),
                  DropdownMenuItem(value: "afternoon", child: Text("Afternoon Mode (Light)")),
                  DropdownMenuItem(value: "evening", child: Text("Evening Mode (Dark)")),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _themeOverride = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 36),
              // Save Buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveSettings,
                  child: const Text("Save Changes"),
                ),
              ),
              const SizedBox(height: 12),
              // Reset Data Button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Reset App Data?"),
                        content: const Text("This will permanently clear all your preferences, swipe data, and date history."),
                        actions: [
                          TextButton(
                            child: const Text("Cancel"),
                            onPressed: () => Navigator.pop(context, false),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(foregroundColor: AppTheme.coralAccent),
                            child: const Text("Clear Everything"),
                            onPressed: () => Navigator.pop(context, true),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await _prefs.resetAll();
                      widget.onDataReset();
                    }
                  },
                  child: const Text(
                    "Reset All App Data",
                    style: TextStyle(
                      color: AppTheme.coralAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
