import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../data/spots_repository.dart';
import '../../models/spot.dart';
import '../../services/preferences_service.dart';
import '../../services/spots_filter_service.dart';
import '../../services/weather_service.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';
import '../../services/geoapify_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/horizontal_spot_card.dart';
import '../../widgets/tonight_pick_banner.dart';
import '../../widgets/weather_banner.dart';

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
  final LocationService _locationService = LocationService();
  final NotificationService _notificationService = NotificationService();
  final GeoapifyService _geoapifyService = GeoapifyService();

  WeatherStatus _weather = WeatherStatus.clear;
  bool _showWeatherBanner = false;

  String? _selectedCategory;
  Spot? _tonightPick;
  List<Spot> _allScoredSpots = [];
  bool _isLoadingSpots = false;
  bool _loadingTimedOut = false;

  // Real-time GPS State
  Position? _currentPosition;
  Position? _lastFetchPosition;
  StreamSubscription<Position>? _positionSubscription;

  int _selectedRadiusMeters = 5000;
  final List<Map<String, dynamic>> _radiusOptions = [
    {"label": "1 km", "value": 1000},
    {"label": "5 km", "value": 5000},
    {"label": "10 km", "value": 10000},
    {"label": "25 km", "value": 25000},
  ];

  // Discover section rails
  final List<Map<String, String>> _sectionRails = [
    {"title": "🔥 Trending Tonight", "filter": ""},
    {"title": "📍 Near You", "filter": "near"},
    {"title": "✨ Hidden Gems", "filter": "curated"},
    {"title": "💸 Under ₹500", "filter": "budget"},
    {"title": "☕ Perfect First Dates", "filter": "Cafe"},
    {"title": "🌙 Date Night Energy", "filter": "Restaurant"},
    {"title": "🍸 Night Out", "filter": "Bar"},
    {"title": "🌳 Touch Grass", "filter": "Park"},
    {"title": "🏛️ Culture Mode", "filter": "Museum"},
    {"title": "🏆 Highest Rated", "filter": "rated"},
    {"title": "🎲 Surprise Picks", "filter": "random"},
  ];

  final List<String> _loadingMessages = [
    "Finding the vibe...",
    "Hunting for hidden gems...",
    "Checking where everyone's going tonight...",
    "Curating your next date...",
  ];
  String _currentLoadingMessage = "Finding the vibe...";

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeData() async {
    if (mounted) {
      setState(() {
        _isLoadingSpots = true;
        _loadingTimedOut = false;
        _currentLoadingMessage = _loadingMessages[Random().nextInt(_loadingMessages.length)];
      });
    }

    final safetyTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _isLoadingSpots) {
        print("[DiscoverScreen] Safety timeout triggered after 10s.");
        setState(() {
          _isLoadingSpots = false;
          _loadingTimedOut = true;
        });
        _refreshRecommendations();
      }
    });

    try {
      await _repository.loadSpots().timeout(const Duration(seconds: 5));
      await _prefs.init().timeout(const Duration(seconds: 5));
      await _notificationService.init().timeout(const Duration(seconds: 5));
      await _checkWeather().timeout(const Duration(seconds: 5));

      final locationStatus = await Permission.location.request()
          .timeout(const Duration(seconds: 5), onTimeout: () => PermissionStatus.denied);
      await Permission.notification.request()
          .timeout(const Duration(seconds: 5), onTimeout: () => PermissionStatus.denied);

      if (locationStatus.isGranted) {
        try {
          final pos = await _locationService.getCurrentPosition()
              .timeout(const Duration(seconds: 5));
          _currentPosition = pos;
          _lastFetchPosition = pos;
          print("[DiscoverScreen] GPS: ${pos.latitude},${pos.longitude}");

          // Fetch initial Geoapify spots
          await _fetchSpots(pos.latitude, pos.longitude)
              .timeout(const Duration(seconds: 8));

          // Start location stream for silent 100m re-fetches
          _setupLocationStream();
        } catch (e) {
          print("[DiscoverScreen] Location setup error: $e");
          if (mounted) {
            setState(() => _isLoadingSpots = false);
          }
          _refreshRecommendations();
        }
      } else {
        if (mounted) {
          setState(() => _isLoadingSpots = false);
        }
        _refreshRecommendations();
      }
    } catch (e) {
      print("[DiscoverScreen] Initialize error: $e");
      if (mounted) {
        setState(() => _isLoadingSpots = false);
      }
      _refreshRecommendations();
    } finally {
      safetyTimer.cancel();
    }
  }

  void _setupLocationStream() {
    _positionSubscription?.cancel();
    final stream = _locationService.getPositionStream();
    _notificationService.startProximityMonitoring(stream);

    _positionSubscription = stream.listen((position) async {
      if (!mounted) return;
      setState(() => _currentPosition = position);

      if (_lastFetchPosition == null) {
        _lastFetchPosition = position;
        await _fetchSpots(position.latitude, position.longitude, silent: true);
        return;
      }

      final distance = Geolocator.distanceBetween(
        _lastFetchPosition!.latitude,
        _lastFetchPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      if (distance >= 100) {
        _lastFetchPosition = position;
        await _fetchSpots(position.latitude, position.longitude, silent: true);
      }
    });
  }

  Future<void> _fetchSpots(double lat, double lng, {bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _isLoadingSpots = true;
        _loadingTimedOut = false;
        _currentLoadingMessage = _loadingMessages[Random().nextInt(_loadingMessages.length)];
      });
    }

    Timer? safetyTimer;
    if (!silent) {
      safetyTimer = Timer(const Duration(seconds: 10), () {
        if (mounted && _isLoadingSpots) {
          print("[DiscoverScreen] Fetch timeout after 10s.");
          setState(() {
            _isLoadingSpots = false;
            _loadingTimedOut = true;
          });
          _refreshRecommendations();
        }
      });
    }

    try {
      final liveSpots = await _geoapifyService.fetchNearbySpots(
        lat: lat,
        lng: lng,
        radius: _selectedRadiusMeters,
      ).timeout(const Duration(seconds: 10));

      _repository.setSpots(liveSpots);

      if (mounted) {
        setState(() => _loadingTimedOut = false);
      }
    } catch (e) {
      print("[DiscoverScreen] Fetch error: $e");
      if (_repository.spots.isEmpty) {
        await _repository.loadSpots();
      }
    } finally {
      safetyTimer?.cancel();
      if (mounted) {
        setState(() => _isLoadingSpots = false);
        _refreshRecommendations();
      }
    }
  }

  Future<void> _checkWeather() async {
    final status = await _weatherService.fetchWeather();
    if (mounted) {
      setState(() {
        _weather = status;
        _showWeatherBanner = (status == WeatherStatus.rainy);
      });
    }
  }

  void _refreshRecommendations() {
    setState(() {
      _tonightPick = _filterService.getTonightPick();

      // Get all scored spots for section rails
      _allScoredSpots = _filterService.getFilteredSpots(
        weather: _weather,
        category: _selectedCategory,
        userPosition: _currentPosition,
        radiusMeters: _selectedRadiusMeters,
      );
    });
  }

  void _resetFilters() async {
    await _prefs.clearDislikedSpots();
    setState(() {
      _selectedCategory = null;
      _showWeatherBanner = (_weather == WeatherStatus.rainy);
      _isLoadingSpots = true;
      _loadingTimedOut = false;
    });

    if (_currentPosition != null) {
      await _fetchSpots(_currentPosition!.latitude, _currentPosition!.longitude);
    } else {
      setState(() => _isLoadingSpots = false);
      _refreshRecommendations();
    }
  }

  // --- Get spots for a specific rail section ---
  List<Spot> _getSpotsForSection(String filter) {
    if (_allScoredSpots.isEmpty) return [];

    switch (filter) {
      case '': // Trending Tonight — top scored
        return _allScoredSpots.take(10).toList();

      case 'near': // Near You — sorted by distance
        final sorted = List<Spot>.from(_allScoredSpots);
        sorted.sort((a, b) => (a.distance ?? 99999).compareTo(b.distance ?? 99999));
        return sorted.take(10).toList();

      case 'curated': // Hidden Gems — curated spots from spots.json
        final curated = _allScoredSpots.where(
          (s) => _repository.curatedSpots.any((c) => c.id == s.id),
        ).toList();
        return curated.take(10).toList();

      case 'budget': // Under ₹500
        return _allScoredSpots.where((s) => s.avgSpend <= 500).take(10).toList();

      case 'rated': // Highest Rated — sorted by dateScore
        final sorted = List<Spot>.from(_allScoredSpots);
        sorted.sort((a, b) => (b.dateScore ?? 0).compareTo(a.dateScore ?? 0));
        return sorted.take(10).toList();

      case 'random': // Surprise Picks — random selection
        final shuffled = List<Spot>.from(_allScoredSpots);
        shuffled.shuffle(Random());
        return shuffled.take(8).toList();

      default: // Category filter (e.g., "Cafe", "Restaurant")
        return _allScoredSpots
            .where((s) => s.category.toLowerCase() == filter.toLowerCase())
            .take(10)
            .toList();
    }
  }

  // --- BUILD METHODS ---

  Widget _buildGpsHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPosition != null ? Colors.green : Colors.amber,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _currentPosition != null ? "GPS locked in 📍" : "Exploring nearby vibes ✨",
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.softGrey,
                ),
              ),
            ],
          ),
          if (_currentPosition != null)
            Text(
              "${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}",
              style: GoogleFonts.inter(fontSize: 10, color: AppTheme.softGrey),
            ),
        ],
      ),
    );
  }

  Widget _buildRadiusSelector(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final double currentKm = _selectedRadiusMeters / 1000.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.tune, size: 14, color: isDark ? Colors.white54 : AppTheme.softGrey),
                  const SizedBox(width: 6),
                  Text(
                    "Search Radius",
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : AppTheme.primaryNavy,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.coralAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  "${currentKm.toStringAsFixed(1)} km",
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.coralAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: AppTheme.coralAccent,
              inactiveTrackColor: Colors.white.withOpacity(0.1),
              thumbColor: AppTheme.coralAccent,
              overlayColor: AppTheme.coralAccent.withOpacity(0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              min: 1.0,
              max: 25.0,
              divisions: 48,
              value: currentKm.clamp(1.0, 25.0),
              onChanged: (val) {
                setState(() {
                  _selectedRadiusMeters = (val * 1000).toInt();
                });
              },
              onChangeEnd: (val) {
                if (_currentPosition != null) {
                  _fetchSpots(_currentPosition!.latitude, _currentPosition!.longitude);
                } else {
                  _refreshRecommendations();
                }
              },
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildFallbackBanner(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: AppTheme.coralAccent.withOpacity(isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.coralAccent.withOpacity(0.3), width: 1),
        ),
        child: Row(
          children: [
            const Text("✨", style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Curated Vibes Only 💎",
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.coralAccent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "No live places found nearby. Showing curated fallback spots near you.",
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isDark ? Colors.white70 : AppTheme.primaryNavy.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeoutRetryWidget(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const Text("😭", style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            "Couldn't load nearby spots",
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.primaryNavy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Check your connection and try again.",
            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.softGrey),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              if (_currentPosition != null) {
                _fetchSpots(_currentPosition!.latitude, _currentPosition!.longitude);
              } else {
                _initializeData();
              }
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalRail(BuildContext context, String title, List<Spot> spots) {
    if (spots.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.primaryNavy,
                ),
              ),
              Text(
                "${spots.length} spots",
                style: GoogleFonts.inter(fontSize: 11, color: AppTheme.softGrey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 210,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: spots.length,
            itemBuilder: (context, index) {
              return HorizontalSpotCard(spot: spots[index]);
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "For You ✨",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: isDark ? Colors.white : AppTheme.primaryNavy,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _checkWeather();
          if (_currentPosition != null) {
            await _fetchSpots(_currentPosition!.latitude, _currentPosition!.longitude);
          } else {
            _refreshRecommendations();
          }
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
                  onDismiss: () => setState(() => _showWeatherBanner = false),
                ),

              // GPS + Radius controls
              _buildGpsHeader(context),
              _buildRadiusSelector(context),

              // Fallback banner
              if (!_isLoadingSpots && _geoapifyService.isLastFetchFallback)
                _buildFallbackBanner(context),

              const SizedBox(height: 8),

              // --- Main Content ---
              if (_isLoadingSpots) ...[
                _buildLoadingState(context),
              ] else if (_loadingTimedOut && _allScoredSpots.isEmpty) ...[
                _buildTimeoutRetryWidget(context),
              ] else if (_allScoredSpots.isEmpty) ...[
                EmptyState(
                  message: "No vibes found 🥲\n\nWe looked everywhere but your filters are way too specific. Try widening the radius or switching up the vibe.",
                  buttonText: "Reset Filters",
                  onAction: _resetFilters,
                ),
              ] else ...[
                // Tonight's Move hero card
                if (_tonightPick != null) ...[
                  TonightPickBanner(spot: _tonightPick!),
                  const SizedBox(height: 8),
                ],

                // Section rails (Zepto/Netflix/Spotify style)
                for (final section in _sectionRails) ...[
                  _buildHorizontalRail(
                    context,
                    section['title']!,
                    _getSpotsForSection(section['filter']!),
                  ),
                ],

                const SizedBox(height: 120),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.coralAccent),
              ),
              const SizedBox(width: 10),
              Text(
                _currentLoadingMessage,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.softGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Shimmer placeholders
          ...List.generate(3, (_) => const _SpotShimmerCard()),
        ],
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
          child: Container(
            height: 120,
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }
}
