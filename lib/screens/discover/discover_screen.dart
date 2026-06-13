import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/spots_repository.dart';
import '../../models/spot.dart';
import '../../services/preferences_service.dart';
import '../../services/spots_filter_service.dart';
import '../../services/weather_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/mood_selector.dart';
import '../../widgets/spot_card.dart';
import '../../widgets/tonight_pick_banner.dart';
import '../../widgets/weather_banner.dart';
import '../spot_detail/spot_detail_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({Key? key}) : super(key: key);

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final SpotsRepository _repository = SpotsRepository();
  final PreferencesService _prefs = PreferencesService();
  final WeatherService _weatherService = WeatherService();
  final SpotsFilterService _filterService = SpotsFilterService();

  WeatherStatus _weather = WeatherStatus.clear;
  bool _showWeatherBanner = false;
  bool _isLoadingWeather = true;

  String _selectedMood = 'Low-key';
  String? _selectedCategory;

  Spot? _tonightPick;
  List<Spot> _filteredSpots = [];

  final List<Map<String, String>> _categories = [
    {"name": "Café", "icon": "☕"},
    {"name": "Park", "icon": "🌳"},
    {"name": "Beach", "icon": "🏖️"},
    {"name": "Museum", "icon": "🏛️"},
    {"name": "Restaurant", "icon": "🍕"},
    {"name": "Bar", "icon": "🍹"},
    {"name": "Scenic", "icon": "🌅"},
    {"name": "Activity", "icon": "🎯"},
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _repository.loadSpots();
    await _prefs.init();
    await _checkWeather();
    _refreshRecommendations();
  }

  Future<void> _checkWeather() async {
    if (!mounted) return;
    setState(() {
      _isLoadingWeather = true;
    });

    final status = await _weatherService.fetchWeather();
    
    if (mounted) {
      setState(() {
        _weather = status;
        _showWeatherBanner = (status == WeatherStatus.rainy);
        _isLoadingWeather = false;
      });
    }
  }

  void _refreshRecommendations() {
    setState(() {
      _tonightPick = _filterService.getTonightPick();
      _filteredSpots = _filterService.getFilteredSpots(
        weather: _weather,
        selectedMood: _selectedMood,
        category: _selectedCategory,
      );
    });
  }

  void _resetFilters() async {
    await _prefs.clearDislikedSpots();
    setState(() {
      _selectedCategory = null;
      _selectedMood = 'Low-key';
      _showWeatherBanner = (_weather == WeatherStatus.rainy);
    });
    _refreshRecommendations();
  }

  // Spark Me Roulette Trigger
  void _triggerSparkMe() {
    final candidates = _filterService.getSparkMeCandidates(
      weather: _weather,
      selectedMood: _selectedMood,
    );

    if (candidates.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: EmptyState(
            title: "No Matching Spots",
            message: "Hmm, nothing matches right now — want to widen the search?",
            buttonText: "Reset Filters",
            onAction: () {
              Navigator.pop(context);
              _resetFilters();
            },
          ),
        ),
      );
      return;
    }

    // Show Roulette Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _RouletteDialog(candidates: candidates),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () async {
          await _checkWeather();
          _refreshRecommendations();
        },
        color: AppTheme.coralAccent,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Weather Banner
              if (_showWeatherBanner)
                WeatherBanner(
                  onDismiss: () {
                    setState(() {
                      _showWeatherBanner = false;
                    });
                  },
                ),

              // Tonight's Pick Section
              if (_selectedCategory == null && _tonightPick != null) ...[
                TonightPickBanner(spot: _tonightPick!),
              ],

              // Mood Selector Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  "Choose Your Vibe",
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              MoodSelector(
                selectedMood: _selectedMood,
                onMoodChanged: (mood) {
                  setState(() {
                    _selectedMood = mood;
                  });
                  _refreshRecommendations();
                },
              ),

              const SizedBox(height: 16),

              // Spark Me Button
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _triggerSparkMe,
                      icon: const Text("⚡", style: TextStyle(fontSize: 18)),
                      label: Text(
                        "Spark Me!",
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.coralAccent,
                        foregroundColor: isDark ? AppTheme.primaryNavy : Colors.white,
                        elevation: 8,
                        shadowColor: AppTheme.coralAccent.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Category Pick Grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  "Pick My Vibe",
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // Categories Grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _categories.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.0,
                  ),
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final name = cat['name']!;
                    final icon = cat['icon']!;
                    final isSelected = _selectedCategory == name;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory = isSelected ? null : name;
                        });
                        _refreshRecommendations();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.coralAccent
                              : (isDark ? const Color(0xff162536) : Colors.white),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? AppTheme.coralAccent : AppTheme.softGrey.withOpacity(0.2),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryNavy.withOpacity(0.04),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              icon,
                              style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              name,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? (isDark ? AppTheme.primaryNavy : Colors.white)
                                    : (isDark ? Colors.white70 : AppTheme.primaryNavy),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Filtered spots list title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedCategory == null
                          ? "Recommended Spots"
                          : "$_selectedCategory Spots",
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_selectedCategory != null)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedCategory = null;
                          });
                          _refreshRecommendations();
                        },
                        child: const Text("Clear Category", style: TextStyle(color: AppTheme.coralAccent)),
                      ),
                  ],
                ),
              ),

              // Recommendations List
              if (_filteredSpots.isEmpty)
                EmptyState(
                  message: "No spots match your current filters. Tap below to reset all settings.",
                  buttonText: "Reset Filters",
                  onAction: _resetFilters,
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredSpots.length,
                  itemBuilder: (context, index) {
                    final spot = _filteredSpots[index];
                    return SpotCard(spot: spot);
                  },
                ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

// Spark Me Roulette dialog class
class _RouletteDialog extends StatefulWidget {
  final List<Spot> candidates;

  const _RouletteDialog({Key? key, required this.candidates}) : super(key: key);

  @override
  State<_RouletteDialog> createState() => _RouletteDialogState();
}

class _RouletteDialogState extends State<_RouletteDialog> with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  int _currentIndex = 0;
  Timer? _timer;
  int _timerTick = 0;
  int _maxTicks = 18; // Cycle times
  int _durationMs = 100; // Starting fast speed

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );
    
    _scaleController.value = 1.0;
    _startRoulette();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scaleController.dispose();
    super.dispose();
  }

  void _startRoulette() {
    _timerTick = 0;
    _runTick();
  }

  void _runTick() {
    _timer?.cancel();
    if (_timerTick >= _maxTicks) {
      // Land on final spot
      final finalIndex = _currentIndex;
      
      // Animate win scale pop
      _scaleController.forward(from: 0.0);
      
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted) {
          Navigator.pop(context); // Close dialog
          // Navigate to details with slide up
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  SpotDetailScreen(spot: widget.candidates[finalIndex]),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                const begin = Offset(0.0, 1.0);
                const end = Offset.zero;
                const curve = Curves.easeOutCubic;
                var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                return SlideTransition(
                  position: animation.drive(tween),
                  child: child,
                );
              },
            ),
          );
        }
      });
      return;
    }

    _timerTick++;
    setState(() {
      _currentIndex = (_currentIndex + 1) % widget.candidates.length;
    });

    // Deceleration algorithm: slow down as we get closer to the end
    if (_timerTick > 10) {
      _durationMs = (100 * (1.0 + (_timerTick - 10) * 0.45)).toInt();
    }

    _timer = Timer(Duration(milliseconds: _durationMs), _runTick);
  }

  @override
  Widget build(BuildContext context) {
    final spot = widget.candidates[_currentIndex];
    final isLanded = _timerTick >= _maxTicks;

    return Center(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isLanded ? "✨ YOUR SPARK MATCH ✨" : "🤖 SELECTING DATE SPOT...",
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isLanded ? AppTheme.coralAccent : AppTheme.softGrey,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Spot Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    spot.imageUrl,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 16),

                // Name
                Text(
                  spot.name,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),

                // Neighborhood
                Text(
                  spot.neighborhood,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppTheme.coralAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Flicking indicator
                if (!isLanded)
                  const SizedBox(
                    width: 40,
                    child: LinearProgressIndicator(
                      color: AppTheme.coralAccent,
                      backgroundColor: Colors.transparent,
                    ),
                  )
                else
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("🎉 ", style: TextStyle(fontSize: 20)),
                      Text(
                        "Opening Spot Details...",
                        style: TextStyle(fontSize: 13, color: AppTheme.softGrey),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
