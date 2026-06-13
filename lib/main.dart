import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'theme/app_theme.dart';
import 'models/date_entry.dart';
import 'models/spot.dart';
import 'data/spots_repository.dart';
import 'services/preferences_service.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/spot_detail/spot_detail_screen.dart';
import 'screens/auth/auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );
  
  // Initialize Preferences
  final prefs = PreferencesService();
  await prefs.init();


  // Load spots
  final repo = SpotsRepository();
  await repo.loadSpots();

  runApp(const NextDateApp());
}

class NextDateApp extends StatefulWidget {
  const NextDateApp({Key? key}) : super(key: key);

  static _NextDateAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_NextDateAppState>()!;

  @override
  State<NextDateApp> createState() => _NextDateAppState();
}

class _NextDateAppState extends State<NextDateApp> {
  final PreferencesService _prefs = PreferencesService();
  Key _appKey = UniqueKey();

  void refreshApp() {
    setState(() {
      _appKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Resolve active theme based on preferences or time
    final override = _prefs.themeOverride;
    ThemeData themeData;
    
    if (override == 'afternoon') {
      themeData = AppTheme.afternoonTheme;
    } else if (override == 'evening') {
      themeData = AppTheme.eveningTheme;
    } else {
      // Auto: Afternoon before 6pm, Evening 6pm onwards
      final hour = DateTime.now().hour;
      if (hour >= 18 || hour < 6) {
        themeData = AppTheme.eveningTheme;
      } else {
        themeData = AppTheme.afternoonTheme;
      }
    }

    return MaterialApp(
      key: _appKey,
      title: 'NextDate',
      debugShowCheckedModeBanner: false,
      theme: themeData,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          if (snapshot.hasData) {
            final bool onboardingDone = _prefs.isOnboardingComplete;
            return onboardingDone ? const MainAppLoader() : const OnboardingScreen();
          }
          return const AuthScreen();
        },
      ),
    );
  }
}

// Loads HomeScreen and performs anniversary checks
class MainAppLoader extends StatefulWidget {
  const MainAppLoader({Key? key}) : super(key: key);

  @override
  State<MainAppLoader> createState() => _MainAppLoaderState();
}

class _MainAppLoaderState extends State<MainAppLoader> {
  final PreferencesService _prefs = PreferencesService();
  final SpotsRepository _repository = SpotsRepository();
  bool _showAnniversaryOverlay = false;

  @override
  void initState() {
    super.initState();
    _checkAnniversary();
  }

  void _checkAnniversary() {
    final annivStr = _prefs.anniversaryDate;
    if (annivStr.isEmpty) return;

    final annivDate = DateTime.tryParse(annivStr);
    if (annivDate == null) return;

    final today = DateTime.now();
    // Check if today matches anniversary month and day
    if (today.month == annivDate.month && today.day == annivDate.day) {
      setState(() {
        _showAnniversaryOverlay = true;
      });
    }
  }

  void _openAnniversarySpot() {
    setState(() {
      _showAnniversaryOverlay = false;
    });

    // Pick top budget (budget = 3) spot
    final budget3Spots = _repository.spots.where((s) => s.budget == 3).toList();
    Spot selectedSpot;

    if (budget3Spots.isNotEmpty) {
      // Pick random premium spot
      selectedSpot = budget3Spots[DateTime.now().millisecond % budget3Spots.length];
    } else {
      // Fallback
      selectedSpot = _repository.spots.first;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SpotDetailScreen(spot: selectedSpot),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const HomeScreen(),
        
        // Anniversary Overlay
        if (_showAnniversaryOverlay)
          _buildAnniversaryOverlay(),
      ],
    );
  }

  Widget _buildAnniversaryOverlay() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        color: AppTheme.primaryNavy.withOpacity(0.95),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                
                // Ring/Heart glow graphic
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.warmGold.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.warmGold, width: 2),
                  ),
                  child: const Text(
                    "🎉",
                    style: TextStyle(fontSize: 80),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                Text(
                  "Happy Anniversary!",
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                Text(
                  "Tonight deserves something special. We've handpicked a premium date experience just for the two of you.",
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const Spacer(),
                
                // CTA Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.coralAccent,
                      foregroundColor: Colors.white,
                      elevation: 8,
                      shadowColor: AppTheme.coralAccent.withOpacity(0.4),
                    ),
                    onPressed: _openAnniversarySpot,
                    child: Text(
                      "Reveal Anniversary Spot ✨",
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Skip Button
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showAnniversaryOverlay = false;
                    });
                  },
                  child: const Text(
                    "Go to Home Screen",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
