import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/spot.dart';
import '../../data/spots_repository.dart';
import '../../services/preferences_service.dart';
import '../../theme/app_theme.dart';

class SurpriseModeScreen extends StatefulWidget {
  const SurpriseModeScreen({Key? key}) : super(key: key);

  @override
  State<SurpriseModeScreen> createState() => _SurpriseModeScreenState();
}

class _SurpriseModeScreenState extends State<SurpriseModeScreen> with SingleTickerProviderStateMixin {
  final SpotsRepository _repository = SpotsRepository();
  final PreferencesService _prefs = PreferencesService();

  // Flow State
  Spot? _currentSurpriseSpot;
  bool _isUnlocked = false;

  // Animation controller for envelope shake/reveal
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  final List<String> _neighborhoods = [
    "Bandra", "Colaba", "Juhu", "Fort", "Powai", "Worli", "Versova", "Andheri", "Marine Lines", "Dadar"
  ];
  final List<String> _vibes = ["Foodie", "Adventurous", "Cozy", "Cultural"];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );

    _initializeSurprise();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _initializeSurprise() {
    _repository.loadSpots();
    _prefs.init().then((_) {
      final surpriseId = _prefs.surpriseSpotId;
      if (surpriseId != null) {
        final spot = _repository.getSpotById(surpriseId);
        setState(() {
          _currentSurpriseSpot = spot;
          _isUnlocked = false;
        });
      }
    });
  }

  void _generatePresetSurprise(String type) async {
    final disliked = _prefs.dislikedSpotIds;
    List<Spot> pool = _repository.spots.where((s) => !disliked.contains(s.id)).toList();

    switch (type) {
      case 'first_date':
        pool = pool.where((s) =>
          (s.category.toLowerCase() == 'cafe' || s.category.toLowerCase() == 'restaurant') &&
          s.budget <= 2 &&
          s.vibe.any((v) => v.toLowerCase() == 'cozy')
        ).toList();
        break;

      case 'coffee_date':
        pool = pool.where((s) =>
          s.category.toLowerCase() == 'cafe' &&
          s.budget == 1
        ).toList();
        break;

      case 'evening_plan':
        pool = pool.where((s) =>
          (s.category.toLowerCase() == 'restaurant' || s.category.toLowerCase() == 'bar') &&
          s.budget <= 3 &&
          s.indoor
        ).toList();
        break;

      case 'budget_friendly':
        pool = pool.where((s) => s.budget == 1).toList();
        break;

      case 'something_different':
        pool = pool.where((s) =>
          s.category.toLowerCase() == 'attraction' ||
          s.category.toLowerCase() == 'museum' ||
          s.category.toLowerCase() == 'park'
        ).toList();
        break;

      case 'surprise_me':
      default:
        break;
    }

    if (pool.isEmpty) {
      pool = _repository.spots.where((s) => !disliked.contains(s.id)).toList();
    }

    if (pool.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("No Vibes Found 🥲"),
          content: const Text("No spots match the criteria. Try resetting or add more data!"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      return;
    }

    final random = Random();
    final chosen = pool[random.nextInt(pool.length)];

    await _prefs.setSurpriseSpotId(chosen.id);

    setState(() {
      _currentSurpriseSpot = chosen;
      _isUnlocked = false;
    });
    
    _animController.reset();
  }

  void _unlockSurprise() {
    setState(() {
      _isUnlocked = true;
    });
    _animController.forward(from: 0.0);
  }

  void _resetSurprise() async {
    await _prefs.setSurpriseSpotId(null);
    setState(() {
      _currentSurpriseSpot = null;
      _isUnlocked = false;
    });
    _animController.reset();
  }

  void _launchDirections(Spot spot) async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${spot.lat},${spot.lng}&travelmode=transit'
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget displayBody;

    if (_currentSurpriseSpot == null) {
      // Setup Mode View
      displayBody = _buildSetupView(theme, isDark);
    } else if (!_isUnlocked) {
      // Locked envelope View
      displayBody = _buildLockedView(theme, isDark);
    } else {
      // Unlocked detailed View
      displayBody = _buildUnlockedView(theme, isDark);
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "I'm feeling lucky 🎲",
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Let fate decide. Set your boundaries, we'll cook up the perfect date.",
                style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.softGrey),
              ),
              const SizedBox(height: 24),
              displayBody,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSetupView(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 6,
          itemBuilder: (context, index) {
            final options = [
              {
                "type": "first_date",
                "emoji": "❤️",
                "title": "First Date Vibe",
                "desc": "Cozy spots that make it easy to talk",
              },
              {
                "type": "coffee_date",
                "emoji": "☕",
                "title": "Coffee Run",
                "desc": "Low-pressure coffee dates & cafes",
              },
              {
                "type": "evening_plan",
                "emoji": "🌙",
                "title": "Evening Plan",
                "desc": "Restaurants & bars for sunset vibes",
              },
              {
                "type": "budget_friendly",
                "emoji": "💸",
                "title": "Budget Friendly",
                "desc": "High-vibe, pocket-friendly places",
              },
              {
                "type": "something_different",
                "emoji": "🎉",
                "title": "Something Different",
                "desc": "Museums, parks, & adventure spots",
              },
              {
                "type": "surprise_me",
                "emoji": "✨",
                "title": "Surprise Me",
                "desc": "Total wild card. Let fate choose",
              },
            ];
            final opt = options[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: InkWell(
                onTap: () => _generatePresetSurprise(opt['type']!),
                borderRadius: BorderRadius.circular(16),
                child: Ink(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xff162536) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Text(
                          opt['emoji']!,
                          style: const TextStyle(fontSize: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                opt['title']!,
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : AppTheme.primaryNavy,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                opt['desc']!,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppTheme.softGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: AppTheme.softGrey,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLockedView(ThemeData theme, bool isDark) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          // Locked Envelope Graphic
          Container(
            width: 260,
            height: 200,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xff162536) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.coralAccent, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.coralAccent.withOpacity(0.15),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("✉️", style: TextStyle(fontSize: 70)),
                SizedBox(height: 12),
                Text(
                  "A surprise is waiting for you 🎁",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppTheme.coralAccent,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  "Locked until you arrive!",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.softGrey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          
          // Fix my date Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.favorite, color: Colors.white),
              label: Text("Fix my date 😭", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
              onPressed: _unlockSurprise,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.coralAccent,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Reset
          TextButton(
            onPressed: _resetSurprise,
            child: const Text(
              "Cancel Surprise & Filter Again",
              style: TextStyle(color: AppTheme.softGrey, decoration: TextDecoration.underline),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnlockedView(ThemeData theme, bool isDark) {
    final spot = _currentSurpriseSpot!;
    
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner revealing
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.5)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("✨ ", style: TextStyle(fontSize: 18)),
                Text(
                  "Surprise Unwrapped! Enjoy your date!",
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(" ✨", style: TextStyle(fontSize: 18)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Unwrapped details Card
          Card(
            elevation: 8,
            shadowColor: AppTheme.primaryNavy.withOpacity(0.08),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: CachedNetworkImage(
                    imageUrl: spot.imageUrl,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spot.name,
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "${spot.neighborhood} • ${spot.category}",
                        style: const TextStyle(color: AppTheme.softGrey, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      
                      // AI Blurb
                      Text(
                        "Why this works:",
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.coralAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        spot.aiBlurb,
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Activities
                      Text(
                        "Suggested Activities:",
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.coralAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...spot.activities.map((a) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Row(
                              children: [
                                const Icon(Icons.circle, size: 6, color: AppTheme.coralAccent),
                                const SizedBox(width: 8),
                                Expanded(child: Text(a, style: const TextStyle(fontSize: 12))),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Navigation Direction button
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.navigation, color: Colors.white),
              label: Text("Navigate to Spot", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              onPressed: () => _launchDirections(spot),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.coralAccent),
            ),
          ),
          const SizedBox(height: 12),
          
          // Reset button to do it again
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text("Plan Another Surprise Date"),
            onPressed: _resetSurprise,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }}
