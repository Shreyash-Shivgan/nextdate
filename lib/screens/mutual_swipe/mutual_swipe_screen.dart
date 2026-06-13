import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/spot.dart';
import '../../data/spots_repository.dart';
import '../../services/preferences_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/confetti_overlay.dart';
import '../../widgets/empty_state.dart';

class MutualSwipeScreen extends StatefulWidget {
  const MutualSwipeScreen({Key? key}) : super(key: key);

  @override
  State<MutualSwipeScreen> createState() => _MutualSwipeScreenState();
}

class _MutualSwipeScreenState extends State<MutualSwipeScreen> {
  final SpotsRepository _repository = SpotsRepository();
  final PreferencesService _prefs = PreferencesService();

  // Swiping state
  bool _couchMode = false;
  bool _isPartner1Active = true; // For single mode

  // Current indices in the spot database
  int _p1Index = 0;
  int _p2Index = 0;

  // Active spots for swiping (excluding disliked spots)
  List<Spot> _swipableSpots = [];

  // Match overlay state
  Spot? _matchedSpot;
  bool _showMatchOverlay = false;

  // Drag Gesture variables for Single Mode
  double _dragDx = 0.0;
  double _dragDy = 0.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _initializeSwipeScreen();
  }

  void _initializeSwipeScreen() {
    _repository.loadSpots();
    _prefs.init().then((_) {
      final disliked = _prefs.dislikedSpotIds;
      setState(() {
        _swipableSpots = _repository.spots.where((s) => !disliked.contains(s.id)).toList();
        _findNextIndices();
      });
    });
  }

  void _findNextIndices() {
    // Find first unswiped spot for Partner 1
    int nextP1 = _swipableSpots.length;
    for (int i = 0; i < _swipableSpots.length; i++) {
      if (_prefs.getSwipeP1(_swipableSpots[i].id) == null) {
        nextP1 = i;
        break;
      }
    }

    // Find first unswiped spot for Partner 2
    int nextP2 = _swipableSpots.length;
    for (int i = 0; i < _swipableSpots.length; i++) {
      if (_prefs.getSwipeP2(_swipableSpots[i].id) == null) {
        nextP2 = i;
        break;
      }
    }

    setState(() {
      _p1Index = nextP1;
      _p2Index = nextP2;
    });
  }

  Future<void> _handleSwipe(bool isP1, Spot spot, bool isYes) async {
    final choice = isYes ? "yes" : "no";
    if (isP1) {
      await _prefs.setSwipeP1(spot.id, choice);
    } else {
      await _prefs.setSwipeP2(spot.id, choice);
    }

    // Reset drag offsets
    setState(() {
      _dragDx = 0.0;
      _dragDy = 0.0;
      _isDragging = false;
    });

    // Match detection check
    if (isYes) {
      final oppositeSwipe = isP1 ? _prefs.getSwipeP2(spot.id) : _prefs.getSwipeP1(spot.id);
      if (oppositeSwipe == "yes") {
        // MATCH!
        setState(() {
          _matchedSpot = spot;
          _showMatchOverlay = true;
        });
      }
    }

    _findNextIndices();
  }

  Future<void> _resetAllSwipes() async {
    await _prefs.clearAllSwipeData();
    _initializeSwipeScreen();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final p1Name = _prefs.partner1Name.isNotEmpty ? _prefs.partner1Name : "Partner 1";
    final p2Name = _prefs.partner2Name.isNotEmpty ? _prefs.partner2Name : "Partner 2";

    // Detect if single person has run out of spots
    final bool p1Finished = _p1Index >= _swipableSpots.length;
    final bool p2Finished = _p2Index >= _swipableSpots.length;

    Widget bodyWidget;

    if (_swipableSpots.isEmpty) {
      bodyWidget = const Center(child: CircularProgressIndicator(color: AppTheme.coralAccent));
    } else if (_couchMode) {
      // Couch Mode (Side by side panels)
      bodyWidget = Row(
        children: [
          // Partner 1 Column
          Expanded(
            child: _buildMiniSwipePanel(
              partnerName: p1Name,
              isP1: true,
              currentIndex: _p1Index,
              isFinished: p1Finished,
              isDark: isDark,
            ),
          ),
          VerticalDivider(width: 1, color: AppTheme.softGrey.withOpacity(0.3)),
          // Partner 2 Column
          Expanded(
            child: _buildMiniSwipePanel(
              partnerName: p2Name,
              isP1: false,
              currentIndex: _p2Index,
              isFinished: p2Finished,
              isDark: isDark,
            ),
          ),
        ],
      );
    } else {
      // Single Mode (One stack with toggle)
      final activeIndex = _isPartner1Active ? _p1Index : _p2Index;
      final activeName = _isPartner1Active ? p1Name : p2Name;
      final finished = _isPartner1Active ? p1Finished : p2Finished;

      if (finished) {
        bodyWidget = EmptyState(
          title: "All Swiped!",
          message: "$activeName has seen all options. Toggle partner or reset below to play again.",
          buttonText: "Reset Swipe Choices",
          onAction: _resetAllSwipes,
          iconEmoji: "🏁",
        );
      } else {
        bodyWidget = _buildSingleSwipeStack(
          activeName: activeName,
          isP1: _isPartner1Active,
          index: activeIndex,
          isDark: isDark,
          theme: theme,
        );
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // Single Mode Header Partner Switcher (Hidden in Couch Mode)
              if (!_couchMode)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: isDark ? const Color(0xff162536) : Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person, color: AppTheme.coralAccent, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _isPartner1Active ? p1Name : p2Name,
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            "Switch Swiper",
                            style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.softGrey),
                          ),
                          Switch(
                            value: !_isPartner1Active,
                            onChanged: (val) {
                              setState(() {
                                _isPartner1Active = !val;
                              });
                            },
                            activeColor: AppTheme.coralAccent,
                            activeTrackColor: AppTheme.coralAccent.withOpacity(0.2),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              Expanded(child: bodyWidget),
            ],
          ),

          // Match Overlay
          if (_showMatchOverlay && _matchedSpot != null)
            ConfettiOverlay(
              spot: _matchedSpot!,
              partner1: p1Name,
              partner2: p2Name,
              onDismiss: () {
                setState(() {
                  _showMatchOverlay = false;
                  _matchedSpot = null;
                });
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          setState(() {
            _couchMode = !_couchMode;
          });
        },
        backgroundColor: AppTheme.coralAccent,
        foregroundColor: isDark ? AppTheme.primaryNavy : Colors.white,
        icon: const Icon(Icons.weekend),
        label: Text(_couchMode ? "Single Mode" : "Couch Mode"),
      ),
    );
  }

  // Couch Mode split panel helper
  Widget _buildMiniSwipePanel({
    required String partnerName,
    required bool isP1,
    required int currentIndex,
    required bool isFinished,
    required bool isDark,
  }) {
    if (isFinished) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("🏁", style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text(
                "$partnerName is done!",
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Waiting on partner to match.",
                style: GoogleFonts.inter(fontSize: 11, color: AppTheme.softGrey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _resetAllSwipes,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text("Reset", style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      );
    }

    final spot = _swipableSpots[currentIndex];

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            partnerName,
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.coralAccent),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              elevation: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    CachedNetworkImage(
                      imageUrl: spot.imageUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            spot.name,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            spot.neighborhood,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppTheme.warmGold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton.filled(
                icon: const Icon(Icons.close, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: () => _handleSwipe(isP1, spot, false),
              ),
              IconButton.filled(
                icon: const Icon(Icons.check, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () => _handleSwipe(isP1, spot, true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Single Mode card stack builder with Drag Gestures
  Widget _buildSingleSwipeStack({
    required String activeName,
    required bool isP1,
    required int index,
    required bool isDark,
    required ThemeData theme,
  }) {
    final topSpot = _swipableSpots[index];
    
    // Stack cards for depth
    final List<Widget> stackChildren = [];

    // Card 3 (Backmost)
    if (index + 2 < _swipableSpots.length) {
      final thirdSpot = _swipableSpots[index + 2];
      stackChildren.add(
        Transform.translate(
          offset: const Offset(0, 16),
          child: Transform.rotate(
            angle: -0.04,
            child: _buildSwipeCardMockup(thirdSpot, isDark),
          ),
        ),
      );
    }

    // Card 2 (Middle)
    if (index + 1 < _swipableSpots.length) {
      final secondSpot = _swipableSpots[index + 1];
      stackChildren.add(
        Transform.translate(
          offset: const Offset(0, 8),
          child: Transform.rotate(
            angle: 0.02,
            child: _buildSwipeCardMockup(secondSpot, isDark),
          ),
        ),
      );
    }

    // Card 1 (Top Draggable Card)
    stackChildren.add(
      GestureDetector(
        onPanStart: (details) {
          setState(() {
            _isDragging = true;
          });
        },
        onPanUpdate: (details) {
          setState(() {
            _dragDx += details.delta.dx;
            _dragDy += details.delta.dy;
          });
        },
        onPanEnd: (details) {
          if (_dragDx > 120) {
            _handleSwipe(isP1, topSpot, true);
          } else if (_dragDx < -120) {
            _handleSwipe(isP1, topSpot, false);
          } else {
            // bounce back
            setState(() {
              _dragDx = 0;
              _dragDy = 0;
              _isDragging = false;
            });
          }
        },
        child: Transform.translate(
          offset: Offset(_dragDx, _dragDy),
          child: Transform.rotate(
            angle: _dragDx / 400, // rotate slightly with drag
            child: Stack(
              children: [
                _buildSwipeCardMockup(topSpot, isDark),
                // Left/Nope overlay
                if (_dragDx < -20)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity((_dragDx.abs() / 150).clamp(0.0, 0.6)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text(
                          "NOPE ✗",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                // Right/Yes overlay
                if (_dragDx > 20)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity((_dragDx / 150).clamp(0.0, 0.6)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text(
                          "YES ✓",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 80),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: stackChildren,
            ),
          ),
          const SizedBox(height: 24),
          // Action Buttons Below Stack
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FloatingActionButton(
                heroTag: 'swipe-left',
                onPressed: () => _handleSwipe(isP1, topSpot, false),
                backgroundColor: Colors.white,
                foregroundColor: Colors.redAccent,
                child: const Icon(Icons.close, size: 28),
              ),
              FloatingActionButton(
                heroTag: 'swipe-right',
                onPressed: () => _handleSwipe(isP1, topSpot, true),
                backgroundColor: AppTheme.coralAccent,
                foregroundColor: Colors.white,
                child: const Icon(Icons.favorite, size: 28),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeCardMockup(Spot spot, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff162536) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Background Image
            CachedNetworkImage(
              imageUrl: spot.imageUrl,
              height: double.infinity,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            // Gradient
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.85),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            // Information overlay
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.coralAccent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      spot.category,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    spot.name,
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: AppTheme.warmGold, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        spot.neighborhood,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      const Spacer(),
                      // Budget
                      Row(
                        children: List.generate(3, (index) {
                          return Text(
                            "₹",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: index < spot.budget ? AppTheme.warmGold : Colors.white24,
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    spot.aiBlurb,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
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
}
