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

  String? _selectedCategory;

  Spot? _tonightPick;
  List<Spot> _filteredSpots = [];

  bool _isLoadingSpots = false;
  String? _selectedNeighborhood;

  final List<Map<String, dynamic>> _mumbaiNeighborhoods = [
    {"name": "Bandra", "lat": 19.0596, "lng": 72.8295},
    {"name": "Colaba", "lat": 18.9067, "lng": 72.8147},
    {"name": "Juhu", "lat": 19.1026, "lng": 72.8242},
    {"name": "Fort", "lat": 18.9345, "lng": 72.8371},
    {"name": "Powai", "lat": 19.1176, "lng": 72.9060},
    {"name": "Worli", "lat": 19.0178, "lng": 72.8173},
    {"name": "Versova", "lat": 19.1351, "lng": 72.8146},
    {"name": "Andheri", "lat": 19.1197, "lng": 72.8468},
    {"name": "Marine Lines", "lat": 18.9447, "lng": 72.8244},
    {"name": "Dadar", "lat": 19.0178, "lng": 72.8478},
  ];


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
    if (mounted) {
      setState(() {
        _isLoadingSpots = true;
      });
    }
    await _repository.loadSpots();
    await _prefs.init();
    await _checkWeather();
    try {
      await _repository.fetchAndMergeLiveSpots();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isLoadingSpots = false;
      });
      _refreshRecommendations();
    }
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
        category: _selectedCategory,
      );
    });
  }

  void _resetFilters() async {
    await _prefs.clearDislikedSpots();
    setState(() {
      _selectedCategory = null;
      _selectedNeighborhood = null;
      _showWeatherBanner = (_weather == WeatherStatus.rainy);
      _isLoadingSpots = true;
    });
    try {
      await _repository.fetchAndMergeLiveSpots();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isLoadingSpots = false;
      });
      _refreshRecommendations();
    }
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

              // Explore Neighborhoods Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  "Explore Neighborhoods",
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  itemCount: _mumbaiNeighborhoods.length,
                  itemBuilder: (context, index) {
                    final neighborhood = _mumbaiNeighborhoods[index];
                    final name = neighborhood['name'] as String;
                    final isSelected = _selectedNeighborhood == name;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: FilterChip(
                        selected: isSelected,
                        showCheckmark: false,
                        label: Text(
                          name,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? (isDark ? AppTheme.primaryNavy : Colors.white)
                                : (isDark ? Colors.white70 : AppTheme.primaryNavy),
                          ),
                        ),
                        selectedColor: AppTheme.coralAccent,
                        backgroundColor: isDark ? const Color(0xff162536) : Colors.white,
                        onSelected: (selected) async {
                          setState(() {
                            _selectedNeighborhood = selected ? name : null;
                            _isLoadingSpots = true;
                          });
                          
                          if (_selectedNeighborhood != null) {
                            final lat = neighborhood['lat'] as double;
                            final lng = neighborhood['lng'] as double;
                            await _repository.fetchAndMergeLiveSpots(lat: lat, lng: lng);
                          } else {
                            await _repository.fetchAndMergeLiveSpots(); // Default center
                          }

                          if (mounted) {
                            setState(() {
                              _isLoadingSpots = false;
                              _refreshRecommendations();
                            });
                          }
                        },
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
              if (_isLoadingSpots)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 3,
                  itemBuilder: (context, index) => const _SpotShimmerCard(),
                )
              else if (_filteredSpots.isEmpty)
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

class _SpotShimmerCard extends StatefulWidget {
  const _SpotShimmerCard({Key? key}) : super(key: key);

  @override
  State<_SpotShimmerCard> createState() => _SpotShimmerCardState();
}

class _SpotShimmerCardState extends State<_SpotShimmerCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.3 + (_controller.value * 0.4),
          child: Card(
            elevation: 8,
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            height: 18,
                            width: 150,
                            color: baseColor,
                          ),
                          Container(
                            height: 18,
                            width: 50,
                            color: baseColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 14,
                        width: 100,
                        color: baseColor,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            height: 20,
                            width: 60,
                            decoration: BoxDecoration(
                              color: baseColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            height: 20,
                            width: 60,
                            decoration: BoxDecoration(
                              color: baseColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

