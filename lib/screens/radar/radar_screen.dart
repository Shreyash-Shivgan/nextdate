import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/spots_repository.dart';
import '../../models/spot.dart';
import '../../services/geoapify_service.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import '../spot_detail/spot_detail_screen.dart';

class RadarScreen extends StatefulWidget {
  const RadarScreen({Key? key}) : super(key: key);

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoading = false;
  bool _loadingTimedOut = false;
  bool _hasSuccessfulResponse = false;
  Spot? _selectedSpot;
  String _selectedCategory = "All";
  int _radiusMeters = 5000;
  int? _lastPrintedAfterCategoryFilter;
  int? _lastPrintedDisplayedSpots;

  double _pulseOffset = 0.0;
  Timer? _pulseTimer;
  bool _pulseGrowing = true;

  final SpotsRepository _repository = SpotsRepository();
  final LocationService _locationService = LocationService();
  final GeoapifyService _geoapifyService = GeoapifyService();

  final List<Map<String, String>> _mapCategories = [
    {"id": "All", "name": "All Vibes ✨"},
    {"id": "Restaurant", "name": "Food Dates 🍝"},
    {"id": "Cafe", "name": "Coffee Runs ☕"},
    {"id": "Bar", "name": "Night Out 🍸"},
    {"id": "Park", "name": "Touch Grass 🌳"},
    {"id": "Attraction", "name": "Main Character Moments ✨"},
    {"id": "Museum", "name": "Culture Mode 🏛️"},
  ];

  final List<Map<String, dynamic>> _radiusOptions = [
    {"label": "1 km", "value": 1000},
    {"label": "5 km", "value": 5000},
    {"label": "10 km", "value": 10000},
    {"label": "25 km", "value": 25000},
  ];

  final List<String> _loadingMessages = [
    "Finding the vibe...",
    "Hunting for hidden gems...",
    "Checking where everyone's going tonight...",
    "Curating your next date..."
  ];
  String _currentLoadingMessage = "Finding the vibe...";

  @override
  void initState() {
    super.initState();
    _repository.addListener(_onRepositoryChanged);
    _initializeLocation();

    // Pulse animation timer
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (mounted) {
        setState(() {
          if (_pulseGrowing) {
            _pulseOffset += 50.0;
            if (_pulseOffset >= 200.0) _pulseGrowing = false;
          } else {
            _pulseOffset -= 50.0;
            if (_pulseOffset <= 0.0) _pulseGrowing = true;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    _repository.removeListener(_onRepositoryChanged);
    _mapController?.dispose();
    super.dispose();
  }

  void _onRepositoryChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _initializeLocation() async {
    setState(() {
      _isLoading = true;
      _hasSuccessfulResponse = false;
      _currentLoadingMessage = _loadingMessages[Random().nextInt(_loadingMessages.length)];
    });

    final safetyTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _isLoading) {
        print("[RadarScreen] Safety timeout triggered after 10s.");
        setState(() {
          _isLoading = false;
          _loadingTimedOut = true;
        });
      }
    });

    try {
      final pos = await _locationService.getCurrentPosition().timeout(const Duration(seconds: 5));
      _currentPosition = pos;

      // Zoom map if already loaded
      if (_mapController != null) {
        _zoomToUser();
      }

      // Fetch live spots around current location
      await _fetchNearby(pos.latitude, pos.longitude).timeout(const Duration(seconds: 8));
    } catch (e) {
      print("Location or fetch error in Radar: $e");
    } finally {
      safetyTimer.cancel();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchNearby(double lat, double lng) async {
    setState(() {
      _isLoading = true;
      _loadingTimedOut = false;
      _hasSuccessfulResponse = false;
      _currentLoadingMessage = _loadingMessages[Random().nextInt(_loadingMessages.length)];
    });

    final safetyTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _isLoading) {
        print("[RadarScreen] Fetch timeout after 10s.");
        setState(() {
          _isLoading = false;
          _loadingTimedOut = true;
        });
      }
    });

    try {
      final liveSpots = await _geoapifyService.fetchNearbySpots(
        lat: lat,
        lng: lng,
        radius: _radiusMeters,
      ).timeout(const Duration(seconds: 10));
      _repository.setSpots(liveSpots);
      _hasSuccessfulResponse = true;
      if (mounted) setState(() => _loadingTimedOut = false);
    } catch (e) {
      print("Failed to fetch spots: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to discover nearby spots: $e')),
      );
    } finally {
      safetyTimer.cancel();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _applyMapStyle(controller);
    if (_currentPosition != null) {
      _zoomToUser();
    }
  }

  void _applyMapStyle(GoogleMapController controller) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      controller.setMapStyle(_darkMapStyle);
    } else {
      controller.setMapStyle(null);
    }
  }

  void _zoomToUser() {
    if (_mapController == null || _currentPosition == null) return;
    _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        13.5,
      ),
    );
  }

  Set<Marker> _buildMarkers() {
    final Set<Marker> markers = {};

    // User's location marker
    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
          infoWindow: const InfoWindow(title: "You are here"),
        ),
      );
    }

    if (!_hasSuccessfulResponse) {
      return markers;
    }

    final spots = _repository.spots;

    // Filter by category
    final filteredSpots = _selectedCategory == "All"
        ? spots
        : spots.where((s) => s.category.toLowerCase() == _selectedCategory.toLowerCase()).toList();

    if (_lastPrintedAfterCategoryFilter != filteredSpots.length || _lastPrintedDisplayedSpots != filteredSpots.length) {
      _lastPrintedAfterCategoryFilter = filteredSpots.length;
      _lastPrintedDisplayedSpots = filteredSpots.length;
      print("After Category Filter: ${filteredSpots.length}");
      print("Displayed Spots: ${filteredSpots.length}");
    }

    for (final spot in filteredSpots) {
      final isCurated = _repository.curatedSpots.any((s) => s.id == spot.id);
      final double dateScoreVal = spot.dateScore ?? 75;

      markers.add(
        Marker(
          markerId: MarkerId(spot.id),
          position: LatLng(spot.lat, spot.lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isCurated ? BitmapDescriptor.hueRose : BitmapDescriptor.hueOrange,
          ),
          infoWindow: InfoWindow(
            title: spot.name,
            snippet: '⭐ ${dateScoreVal.round()} Match',
          ),
          onTap: () {
            setState(() {
              _selectedSpot = spot;
            });
          },
        ),
      );
    }

    return markers;
  }

  Set<Circle> _buildCircles() {
    if (_currentPosition == null) return {};
    return {
      Circle(
        circleId: const CircleId('radar_circle'),
        center: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        radius: _radiusMeters.toDouble(),
        fillColor: AppTheme.coralAccent.withOpacity(0.04),
        strokeColor: AppTheme.coralAccent.withOpacity(0.2),
        strokeWidth: 1,
      ),
      // Animated inner pulse circle!
      Circle(
        circleId: const CircleId('radar_pulse_circle'),
        center: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        radius: (_radiusMeters.toDouble() * 0.35) + _pulseOffset,
        fillColor: AppTheme.coralAccent.withOpacity(0.08),
        strokeColor: AppTheme.coralAccent.withOpacity(0.3),
        strokeWidth: 2,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_mapController != null) {
      _applyMapStyle(_mapController!);
    }

    return Scaffold(
      body: Stack(
        children: [
          // Google Map Background
          if (_currentPosition == null && !_loadingTimedOut)
            const Center(child: CircularProgressIndicator(color: AppTheme.coralAccent))
          else if (_currentPosition == null && _loadingTimedOut)
            _buildTimeoutRetryWidget(isDark)
          else
            Positioned.fill(
              child: GoogleMap(
                onMapCreated: _onMapCreated,
                initialCameraPosition: CameraPosition(
                  target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                  zoom: 13,
                ),
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                markers: _buildMarkers(),
                circles: _buildCircles(),
                onTap: (_) {
                  setState(() {
                    _selectedSpot = null;
                  });
                },
              ),
            ),

          // Top Overlay (Gradient + Category Chips)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    isDark ? AppTheme.primaryNavy.withOpacity(0.9) : Colors.white.withOpacity(0.9),
                    isDark ? AppTheme.primaryNavy.withOpacity(0.0) : Colors.white.withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Radius selectors row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Date Radar 📡",
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppTheme.primaryNavy,
                          ),
                        ),
                        Row(
                          children: _radiusOptions.map((opt) {
                            final label = opt['label'] as String;
                            final val = opt['value'] as int;
                            final isSel = _radiusMeters == val;

                            return Padding(
                              padding: const EdgeInsets.only(left: 6.0),
                              child: ChoiceChip(
                                label: Text(label),
                                selected: isSel,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _radiusMeters = val;
                                      _selectedSpot = null;
                                    });
                                    if (_currentPosition != null) {
                                      _fetchNearby(_currentPosition!.latitude, _currentPosition!.longitude);
                                    }
                                  }
                                },
                                labelStyle: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isSel
                                      ? (isDark ? AppTheme.primaryNavy : Colors.white)
                                      : (isDark ? Colors.white70 : AppTheme.primaryNavy),
                                ),
                                showCheckmark: false,
                                selectedColor: AppTheme.coralAccent,
                                backgroundColor: isDark ? const Color(0xff162536) : Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Categories chips list
                  SizedBox(
                    height: 38,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      itemCount: _mapCategories.length,
                      itemBuilder: (context, idx) {
                        final cat = _mapCategories[idx];
                        final String catId = cat['id']!;
                        final String catName = cat['name']!;
                        final isSel = _selectedCategory == catId;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: ChoiceChip(
                            label: Text(catName),
                            selected: isSel,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedCategory = catId;
                                  _selectedSpot = null;
                                });
                              }
                            },
                            showCheckmark: false,
                            labelStyle: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSel
                                  ? (isDark ? AppTheme.primaryNavy : Colors.white)
                                  : (isDark ? Colors.white70 : AppTheme.primaryNavy),
                            ),
                            selectedColor: AppTheme.coralAccent,
                            backgroundColor: isDark ? const Color(0xff162536) : Colors.white,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Floating Controls (Recenter, Reload)
          Positioned(
            right: 16,
            bottom: _selectedSpot == null ? 32 : 230,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: "recenter_btn",
                  mini: true,
                  onPressed: _zoomToUser,
                  backgroundColor: isDark ? const Color(0xff162536) : Colors.white,
                  foregroundColor: AppTheme.coralAccent,
                  child: const Icon(Icons.gps_fixed),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: "reload_btn",
                  mini: true,
                  onPressed: () {
                    if (_currentPosition != null) {
                      _fetchNearby(_currentPosition!.latitude, _currentPosition!.longitude);
                    }
                  },
                  backgroundColor: isDark ? const Color(0xff162536) : Colors.white,
                  foregroundColor: AppTheme.coralAccent,
                  child: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),

          // Loading Indicator Overlay
          if (_isLoading)
            Positioned(
              top: 130,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.coralAccent,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2))
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _currentLoadingMessage,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Fallback Badge Overlay
          if (!_isLoading && _geoapifyService.isLastFetchFallback)
            Positioned(
              top: 130,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.coralAccent.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 2))
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("✨", style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Text(
                        "Showing curated fallback spots",
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // No Places Found Overlay
          if (!_isLoading && _hasSuccessfulResponse && (() {
            final spots = _repository.spots;
            final filteredSpots = _selectedCategory == "All"
                ? spots
                : spots.where((s) => s.category.toLowerCase() == _selectedCategory.toLowerCase()).toList();
            return filteredSpots.isEmpty;
          })())
            Positioned(
              top: 130,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xff162536) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.coralAccent.withOpacity(0.5), width: 1.5),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_off, color: AppTheme.coralAccent),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          "No places found within selected radius",
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : AppTheme.primaryNavy,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom Slide-up Details Card
          if (_selectedSpot != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: _buildSelectedSpotCard(isDark, theme),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeoutRetryWidget(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("📡", style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              "Radar couldn't lock on",
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.primaryNavy,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Check GPS & network, then try again.",
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.softGrey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _initializeLocation,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedSpotCard(bool isDark, ThemeData theme) {
    final spot = _selectedSpot!;
    final curated = _repository.curatedSpots.any((s) => s.id == spot.id);
    final distanceText = spot.distance != null && spot.distance! > 0
        ? (spot.distance! < 1000
            ? '${spot.distance!.round()}m away'
            : '${(spot.distance! / 1000).toStringAsFixed(1)}km away')
        : 'Nearby';

    return Hero(
      tag: "radar_spot_card_${spot.id}",
      child: Card(
        elevation: 16,
        color: isDark ? const Color(0xff162536) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: curated
              ? const BorderSide(color: AppTheme.coralAccent, width: 1.5)
              : BorderSide(color: AppTheme.softGrey.withOpacity(0.2), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      spot.imageUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, _, __) {
                        return Container(
                          width: 80,
                          height: 80,
                          color: AppTheme.softGrey.withOpacity(0.2),
                          child: const Icon(Icons.image, color: AppTheme.softGrey),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Details Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                spot.name,
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : AppTheme.primaryNavy,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.close, size: 18, color: AppTheme.softGrey),
                              onPressed: () {
                                setState(() {
                                  _selectedSpot = null;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Tags Row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.coralAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.star, color: AppTheme.coralAccent, size: 10),
                                  const SizedBox(width: 4),
                                  Text(
                                    _getPlayfulTagline(spot, curated),
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.coralAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              distanceText,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.coralAccent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Brief blurb snippet
                        Text(
                          spot.aiBlurb,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : AppTheme.primaryNavy.withOpacity(0.7),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Footer Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedSpot = null;
                        });
                      },
                      child: Text(
                        "Dismiss",
                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SpotDetailScreen(spot: spot),
                          ),
                        );
                      },
                      child: Text(
                        "View Details",
                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getPlayfulTagline(Spot spot, bool curated) {
    if (curated) {
      return "Trending Tonight 🔥";
    }
    if (spot.budget == 1) {
      return "Low-key underrated 💎";
    }
    if (spot.category == 'Attraction') {
      return "Main Character Spot ✨";
    }
    return "Trending Tonight 🔥";
  }
}

const String _darkMapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#1d2c3d"
      }
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#8ec3b9"
      }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#1a3646"
      }
    ]
  },
  {
    "featureType": "administrative.country",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#4b687a"
      }
    ]
  },
  {
    "featureType": "administrative.land_parcel",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#64779e"
      }
    ]
  },
  {
    "featureType": "administrative.province",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#4b687a"
      }
    ]
  },
  {
    "featureType": "landscape.man_made",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#334e68"
      }
    ]
  },
  {
    "featureType": "landscape.natural",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#162536"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#1d2c3d"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#6f9ba5"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry.fill",
    "stylers": [
      {
        "color": "#122a3a"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#3b736b"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#304a5d"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#98a5be"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#2c4557"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#1f384a"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#e9bc62"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#0e1626"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#4e5d6c"
      }
    ]
  }
]
''';
