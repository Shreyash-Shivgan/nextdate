import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/spot.dart';
import '../../models/date_entry.dart';
import '../../data/spots_repository.dart';
import '../../services/supabase_service.dart';
import '../../services/location_service.dart';
import '../../services/preferences_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../home/home_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final SpotsRepository _repository = SpotsRepository();
  List<DateEntry> _entries = [];
  bool _isLoading = true;
  Position? _currentPosition;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _repository.loadSpots();
    _loadHistory();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await _repository.loadSpots();
      final data = await SupabaseService().fetchHistory();
      
      // Get current location for centering and custom spot logging
      try {
        _currentPosition = await LocationService().getCurrentPosition();
      } catch (_) {}

      setState(() {
        _entries = data;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading history: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  DateTime _getMonday(DateTime date) {
    final cleanDate = DateTime(date.year, date.month, date.day);
    return cleanDate.subtract(Duration(days: cleanDate.weekday - 1));
  }

  int _calculateStreak(List<DateEntry> entries) {
    if (entries.isEmpty) return 0;

    final Set<DateTime> activeWeeks = {};
    for (final entry in entries) {
      activeWeeks.add(_getMonday(entry.visitedOn));
    }

    final today = DateTime.now();
    final currentMonday = _getMonday(today);
    final previousMonday = currentMonday.subtract(const Duration(days: 7));

    if (!activeWeeks.contains(currentMonday) && !activeWeeks.contains(previousMonday)) {
      return 0;
    }

    int streak = 0;
    DateTime checkMonday = activeWeeks.contains(currentMonday) ? currentMonday : previousMonday;

    while (activeWeeks.contains(checkMonday)) {
      streak++;
      checkMonday = checkMonday.subtract(const Duration(days: 7));
    }

    return streak;
  }

  void _openAddMemorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _AddMemoryBottomSheet(
          spots: _repository.spots,
          currentPosition: _currentPosition,
        );
      },
    ).then((_) => _loadHistory());
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _applyMapStyle(controller);
    _fitMapToMarkers();
  }

  void _applyMapStyle(GoogleMapController controller) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      controller.setMapStyle(_darkMapStyle);
    } else {
      controller.setMapStyle(null);
    }
  }

  void _fitMapToMarkers() {
    if (_mapController == null || _entries.isEmpty) return;

    final markers = _buildMarkers();
    if (markers.isEmpty) {
      if (_currentPosition != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            12.0,
          ),
        );
      }
      return;
    }

    double minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    for (final m in markers) {
      if (m.position.latitude < minLat) minLat = m.position.latitude;
      if (m.position.latitude > maxLat) maxLat = m.position.latitude;
      if (m.position.longitude < minLng) minLng = m.position.longitude;
      if (m.position.longitude > maxLng) maxLng = m.position.longitude;
    }

    // Zoom bounds padding
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.02, minLng - 0.02),
          northeast: LatLng(maxLat + 0.02, maxLng + 0.02),
        ),
        60,
      ),
    );
  }

  Set<Marker> _buildMarkers() {
    final Set<Marker> markers = {};
    final prefService = PreferencesService();

    for (final entry in _entries) {
      // 1. Try search active repository spots
      final spot = _repository.getSpotById(entry.spotId);
      double? lat = spot?.lat;
      double? lng = spot?.lng;

      // 2. If not found in repository, fallback to local coordinates cache
      if (lat == null || lng == null) {
        lat = prefService.getSpotLat(entry.spotId);
        lng = prefService.getSpotLng(entry.spotId);
      }

      // 3. Skip if coordinate unknown (e.g. some manual logs)
      if (lat == null || lng == null) continue;

      markers.add(
        Marker(
          markerId: MarkerId(entry.spotId),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: entry.spotName,
            snippet: DateFormat('MMMM d, yyyy').format(entry.visitedOn),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ),
      );
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_mapController != null) {
      _applyMapStyle(_mapController!);
    }

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.coralAccent),
        ),
      );
    }

    if (_entries.isEmpty) {
      return Scaffold(
        body: EmptyState(
          title: "Your Timeline is Blank",
          message: "Your timeline is a blank page waiting for memories. Plan your first date tonight ✨",
          buttonText: "Find a Spot",
          onAction: () {
            final homeState = context.findAncestorStateOfType<State<HomeScreen>>();
            if (homeState != null) {
              try {
                (homeState as dynamic).setState(() {
                  (homeState as dynamic)._currentIndex = 0;
                });
              } catch (_) {}
            }
          },
          iconEmoji: "📅",
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _openAddMemorySheet,
          backgroundColor: AppTheme.coralAccent,
          foregroundColor: isDark ? AppTheme.primaryNavy : Colors.white,
          child: const Icon(Icons.add),
        ),
      );
    }

    final streak = _calculateStreak(_entries);
    final markers = _buildMarkers();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        color: AppTheme.coralAccent,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // Streak Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.warmGold,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.warmGold.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Text(
                    "🔥",
                    style: TextStyle(fontSize: 36),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "$streak Week Date Streak!",
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryNavy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          "Keep the flame alive by planning weekly dates.",
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primaryNavy,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),

            // Visited spots map view
            Text(
              "Your Visited Date Map 🗺️",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.softGrey.withOpacity(0.2),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition != null
                        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                        : const LatLng(19.076, 72.877),
                    zoom: 12.0,
                  ),
                  markers: markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            Text(
              "Your Date Timeline",
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Timeline List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _entries.length,
              itemBuilder: (context, index) {
                final entry = _entries[index];
                final dateStr = DateFormat('MMMM d, yyyy').format(entry.visitedOn);

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  color: isDark ? const Color(0xff162536) : Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: entry.imageUrl,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, err) => Container(
                              width: 60,
                              height: 60,
                              color: AppTheme.softGrey.withOpacity(0.2),
                              child: const Icon(Icons.image),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.spotName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                dateStr,
                                style: const TextStyle(fontSize: 11, color: AppTheme.softGrey),
                              ),
                              if (entry.note.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  entry.note,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                children: List.generate(5, (starIndex) {
                                  return Icon(
                                    Icons.star,
                                    size: 16,
                                    color: starIndex < entry.rating ? AppTheme.warmGold : AppTheme.softGrey.withOpacity(0.3),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.softGrey),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text("Delete Memory?"),
                                content: const Text("Are you sure you want to remove this date from your timeline?"),
                                actions: [
                                  TextButton(
                                    child: const Text("Cancel"),
                                    onPressed: () => Navigator.pop(context, false),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(foregroundColor: AppTheme.coralAccent),
                                    child: const Text("Delete"),
                                    onPressed: () => Navigator.pop(context, true),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              try {
                                setState(() {
                                  _isLoading = true;
                                });
                                await SupabaseService().deleteSpotFromHistory(entry.spotId, entry.visitedOn);
                                await _loadHistory();
                              } catch (e) {
                                print("Error deleting entry: $e");
                                setState(() {
                                  _isLoading = false;
                                });
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddMemorySheet,
        backgroundColor: AppTheme.coralAccent,
        foregroundColor: isDark ? AppTheme.primaryNavy : Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AddMemoryBottomSheet extends StatefulWidget {
  final List<Spot> spots;
  final Position? currentPosition;

  const _AddMemoryBottomSheet({
    Key? key,
    required this.spots,
    this.currentPosition,
  }) : super(key: key);

  @override
  State<_AddMemoryBottomSheet> createState() => _AddMemoryBottomSheetState();
}

class _AddMemoryBottomSheetState extends State<_AddMemoryBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  
  Spot? _selectedSpot;
  String _customSpotName = '';
  DateTime _visitedDate = DateTime.now();
  int _rating = 5;
  final TextEditingController _notesController = TextEditingController();

  bool _useCustomSpot = false;

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _visitedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.coralAccent,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _visitedDate = picked;
      });
    }
  }

  Future<void> _saveMemory() async {
    if (!_formKey.currentState!.validate()) return;

    String spotName = "";
    String imageUrl = "";
    String spotId = "";

    if (_useCustomSpot) {
      spotName = _customSpotName.trim();
      imageUrl = "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800&q=80";
      spotId = "custom_${DateTime.now().millisecondsSinceEpoch}";
      
      final lat = widget.currentPosition?.latitude ?? 19.076;
      final lng = widget.currentPosition?.longitude ?? 72.877;
      await PreferencesService().cacheSpotCoords(spotId, lat, lng);
    } else {
      if (_selectedSpot == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please select a date spot!"),
            backgroundColor: AppTheme.coralAccent,
          ),
        );
        return;
      }
      spotName = _selectedSpot!.name;
      imageUrl = _selectedSpot!.imageUrl;
      spotId = _selectedSpot!.id;
      await PreferencesService().cacheSpotCoords(spotId, _selectedSpot!.lat, _selectedSpot!.lng);
    }

    try {
      final supabaseService = SupabaseService();
      if (_useCustomSpot) {
        await supabaseService.saveCustomSpot(
          spotId: spotId,
          spotName: spotName,
          imageUrl: imageUrl,
          visitedOn: _visitedDate,
          rating: _rating,
          note: _notesController.text.trim(),
        );
      } else {
        await supabaseService.saveSpot(
          _selectedSpot!,
          rating: _rating,
          note: _notesController.text.trim(),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Memory saved successfully! ✨"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to save memory: $e"),
            backgroundColor: AppTheme.coralAccent,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
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
                "Add Date Memory",
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.primaryNavy,
                ),
              ),
              const SizedBox(height: 20),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Log custom location?"),
                  Switch(
                    value: _useCustomSpot,
                    onChanged: (val) {
                      setState(() {
                        _useCustomSpot = val;
                      });
                    },
                    activeColor: AppTheme.coralAccent,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (!_useCustomSpot) ...[
                DropdownButtonFormField<Spot>(
                  hint: const Text("Select Visited Spot"),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDark ? AppTheme.primaryNavy : Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: widget.spots.map((s) {
                    return DropdownMenuItem(
                      value: s,
                      child: Text(s.name, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedSpot = val;
                    });
                  },
                ),
              ] else ...[
                TextFormField(
                  decoration: InputDecoration(
                    labelText: "Custom Spot Name",
                    filled: true,
                    fillColor: isDark ? AppTheme.primaryNavy : Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? "Name required" : null,
                  onChanged: (val) {
                    _customSpotName = val;
                  },
                ),
              ],
              const SizedBox(height: 16),

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
                        DateFormat('MMMM d, yyyy').format(_visitedDate),
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: isDark ? Colors.white : AppTheme.primaryNavy,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text("Date Rating:"),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final ratingValue = index + 1;
                  return IconButton(
                    icon: Icon(
                      Icons.star,
                      size: 32,
                      color: ratingValue <= _rating ? AppTheme.warmGold : AppTheme.softGrey.withOpacity(0.3),
                    ),
                    onPressed: () {
                      setState(() {
                        _rating = ratingValue;
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: "Write a memory note...",
                  filled: true,
                  fillColor: isDark ? AppTheme.primaryNavy : Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveMemory,
                  child: const Text("Save Memory ✨"),
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
