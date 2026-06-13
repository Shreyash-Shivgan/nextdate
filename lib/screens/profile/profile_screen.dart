import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/preferences_service.dart';
import '../../theme/app_theme.dart';
import '../onboarding/onboarding_screen.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onThemeChange;
  const ProfileScreen({Key? key, required this.onThemeChange}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final PreferencesService _prefs = PreferencesService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _p1Controller;
  late TextEditingController _p2Controller;
  DateTime? _anniversaryDate;
  String _themeOverride = "auto";
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
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
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Profile saved successfully! ✨"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Determine sign-in info
    String authMethod = "Email & Password";
    String? userInfo = _currentUser?.email;
    String displayName = _currentUser?.displayName ?? "";
    String? photoUrl = _currentUser?.photoURL;

    if (_currentUser != null) {
      for (final provider in _currentUser!.providerData) {
        if (provider.providerId == 'google.com') {
          authMethod = "Google Sign-In";
          userInfo = provider.email;
          if (displayName.isEmpty) displayName = provider.displayName ?? "";
          if (photoUrl == null) photoUrl = provider.photoURL;
        } else if (provider.providerId == 'phone') {
          authMethod = "Phone Number";
          userInfo = provider.phoneNumber;
        }
      }
    }

    if (displayName.isEmpty) {
      displayName = _prefs.partner1Name.isNotEmpty ? _prefs.partner1Name : "User";
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Profile & Settings",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark ? AppTheme.primaryNavy : AppTheme.bgLight,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User Avatar & Welcome Header
              Center(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [AppTheme.coralAccent, AppTheme.warmGold],
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 54,
                            backgroundColor: isDark ? AppTheme.primaryNavy : Colors.white,
                            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                            child: photoUrl == null
                                ? Text(
                                    displayName.isNotEmpty ? displayName[0].toUpperCase() : "U",
                                    style: GoogleFonts.outfit(
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.coralAccent,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppTheme.coralAccent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.verified,
                            color: Colors.white,
                            size: 16,
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      displayName,
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.coralAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        authMethod,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.coralAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (userInfo != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        userInfo,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppTheme.softGrey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Couple Details Section
              Text(
                "Couple Settings",
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.coralAccent,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Partner 1
                      TextFormField(
                        controller: _p1Controller,
                        style: TextStyle(color: isDark ? Colors.white : AppTheme.primaryNavy),
                        decoration: InputDecoration(
                          labelText: "Your Name",
                          prefixIcon: const Icon(Icons.person_outline, color: AppTheme.softGrey),
                          filled: true,
                          fillColor: isDark ? AppTheme.primaryNavy : Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? "Cannot be empty" : null,
                      ),
                      const SizedBox(height: 16),
                      // Partner 2
                      TextFormField(
                        controller: _p2Controller,
                        style: TextStyle(color: isDark ? Colors.white : AppTheme.primaryNavy),
                        decoration: InputDecoration(
                          labelText: "Partner's Name",
                          prefixIcon: const Icon(Icons.favorite_border_rounded, color: AppTheme.softGrey),
                          filled: true,
                          fillColor: isDark ? AppTheme.primaryNavy : Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? "Cannot be empty" : null,
                      ),
                      const SizedBox(height: 16),
                      // Anniversary
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
                                    ? "Set Anniversary Date"
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // App Preference Settings
              Text(
                "Preferences",
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.coralAccent,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Save Changes
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _saveSettings,
                  child: const Text("Save Changes"),
                ),
              ),
              const SizedBox(height: 12),

              // Sign Out
              SizedBox(
                height: 54,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.coralAccent,
                    side: const BorderSide(color: AppTheme.coralAccent, width: 1.5),
                  ),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Sign Out?"),
                        content: const Text("Are you sure you want to sign out? Your preferences and history will remain saved."),
                        actions: [
                          TextButton(
                            child: const Text("Cancel"),
                            onPressed: () => Navigator.pop(context, false),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(foregroundColor: AppTheme.coralAccent),
                            child: const Text("Sign Out"),
                            onPressed: () => Navigator.pop(context, true),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await FirebaseAuth.instance.signOut();
                      if (mounted) {
                        Navigator.pop(context); // Pop profile screen
                      }
                    }
                  },
                  child: const Text("Sign Out"),
                ),
              ),
              const SizedBox(height: 12),

              // Reset App Data
              TextButton(
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
                    if (mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
                        (route) => false,
                      );
                    }
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
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
