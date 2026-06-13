import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/preferences_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../home/home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final PreferencesService _prefs = PreferencesService();

  int _currentPage = 0;

  // Page 2 Controller
  final TextEditingController _partner1Controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Page 3 State
  final List<String> _availableVibes = ["Foodie", "Adventurous", "Cozy", "Cultural"];
  final List<String> _selectedVibes = [];
  int _selectedBudget = 2; // Default to ₹₹

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.displayName != null && user.displayName!.isNotEmpty) {
      _partner1Controller.text = user.displayName!;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _partner1Controller.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage == 1) {
      if (!_formKey.currentState!.validate()) {
        return;
      }
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _prevPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _completeOnboarding() async {
    if (_selectedVibes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select at least one vibe chip!"),
          backgroundColor: AppTheme.coralAccent,
        ),
      );
      return;
    }

    // Save preferences
    await _prefs.setPartner1Name(_partner1Controller.text.trim());
    await _prefs.setVibePrefs(_selectedVibes);
    await _prefs.setBudgetPref(_selectedBudget);
    await _prefs.setOnboardingComplete(true);

    try {
      final supabaseService = SupabaseService();
      await supabaseService.upsertProfile(
        name: _partner1Controller.text.trim(),
        vibes: _selectedVibes,
        budget: _selectedBudget,
      );
    } catch (e) {
      print("Failed to sync profile to Supabase: $e");
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                children: List.generate(3, (index) {
                  final active = index == _currentPage;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: active
                            ? AppTheme.coralAccent
                            : AppTheme.softGrey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  _buildWelcomePage(theme),
                  _buildCoupleSetupPage(theme, isDark),
                  _buildPreferencesPage(theme, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Page 1 — Welcome Screen
  Widget _buildWelcomePage(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          // App Logo
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.coralAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_rounded,
              size: 100,
              color: AppTheme.coralAccent,
            ),
          ),
          const SizedBox(height: 32),
          // App Name
          Text(
            "NextDate",
            style: GoogleFonts.outfit(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.displayLarge?.color,
            ),
          ),
          const SizedBox(height: 12),
          // Tagline
          Text(
            "Your next date, figured out.",
            style: GoogleFonts.inter(
              fontSize: 18,
              color: AppTheme.softGrey,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          // Large CTA to begin
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _nextPage,
              child: Text(
                "Begin Discovery",
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Page 2 — Couple Setup
  Widget _buildCoupleSetupPage(ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text(
              "Let's get set up",
              style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Tell us who is planning dates. We'll synchronize options.",
              style: GoogleFonts.inter(fontSize: 15, color: AppTheme.softGrey),
            ),
            const SizedBox(height: 40),
            // Partner 1 Name Field
            Text(
              "Partner 1 Name",
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.coralAccent),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _partner1Controller,
              decoration: InputDecoration(
                hintText: "Enter Name",
                filled: true,
                fillColor: isDark ? const Color(0xff162536) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.softGrey.withOpacity(0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.coralAccent, width: 2),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return "Name cannot be empty";
                return null;
              },
            ),

            // City Field (Auto-locked to Mumbai)
            Text(
              "Date Discovery City",
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.softGrey),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xff0d1b2a) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.softGrey.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: AppTheme.coralAccent),
                  const SizedBox(width: 12),
                  Text(
                    "Mumbai, IN (Auto-detected)",
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white60 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _prevPage,
                    child: const Text("Back"),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _nextPage,
                    child: const Text("Next"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Page 3 — Preferences Setup
  Widget _buildPreferencesPage(ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            "Vibe & Budget",
            style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Select vibes you both enjoy and set your comfortable budget range.",
            style: GoogleFonts.inter(fontSize: 15, color: AppTheme.softGrey),
          ),
          const SizedBox(height: 36),
          // Vibes Chips Title
          Text(
            "What vibes do you prefer? (Select one or more)",
            style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          // Vibes Chip Selection
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableVibes.map((vibe) {
              final isSelected = _selectedVibes.contains(vibe);
              return FilterChip(
                label: Text(vibe),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedVibes.add(vibe);
                    } else {
                      _selectedVibes.remove(vibe);
                    }
                  });
                },
                selectedColor: AppTheme.coralAccent,
                backgroundColor: isDark ? const Color(0xff162536) : Colors.white,
                checkmarkColor: isDark ? AppTheme.primaryNavy : Colors.white,
                labelStyle: GoogleFonts.inter(
                  color: isSelected
                      ? (isDark ? AppTheme.primaryNavy : Colors.white)
                      : (isDark ? Colors.white70 : AppTheme.primaryNavy),
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide(
                  color: isSelected ? AppTheme.coralAccent : AppTheme.softGrey.withOpacity(0.5),
                  width: 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 40),
          // Budget Selector Title
          Text(
            "Budget Preference",
            style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          // Custom Budget Selector buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildBudgetButton(1, "Under ₹500", "₹"),
              const SizedBox(width: 8),
              _buildBudgetButton(2, "₹500 - ₹1500", "₹₹"),
              const SizedBox(width: 8),
              _buildBudgetButton(3, "₹1500+", "₹₹₹"),
            ],
          ),
          const SizedBox(height: 60),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _prevPage,
                  child: const Text("Back"),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _completeOnboarding,
                  child: const Text("Save & Let's Go"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetButton(int level, String label, String rupeeSymbols) {
    final isSelected = _selectedBudget == level;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedBudget = level;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.coralAccent
                : (isDark ? const Color(0xff162536) : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.coralAccent : AppTheme.softGrey.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                rupeeSymbols,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? (isDark ? AppTheme.primaryNavy : Colors.white)
                      : AppTheme.warmGold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? (isDark ? AppTheme.primaryNavy : Colors.white)
                      : (isDark ? Colors.white60 : AppTheme.primaryNavy),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
