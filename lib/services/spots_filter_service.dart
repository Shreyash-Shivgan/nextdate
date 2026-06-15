import 'dart:math';
import 'package:geolocator/geolocator.dart';
import '../models/spot.dart';
import '../data/spots_repository.dart';
import 'preferences_service.dart';
import 'weather_service.dart';

class SpotsFilterService {
  static final SpotsFilterService _instance = SpotsFilterService._internal();
  factory SpotsFilterService() => _instance;
  SpotsFilterService._internal();

  final SpotsRepository _repository = SpotsRepository();
  final PreferencesService _prefs = PreferencesService();

  // --- Diagnostics state ---
  int? lastBeforeFilterCount;
  int? lastAfterRadiusCount;
  int? lastAfterCategoryCount;
  int? lastDisplayedCount;

  // Helper: Filter out disliked spots
  List<Spot> _getUndislikedSpots() {
    final disliked = _prefs.dislikedSpotIds;
    return _repository.spots.where((s) => !disliked.contains(s.id)).toList();
  }

  // Tonight's Pick Selection Algorithm
  Spot? getTonightPick() {
    final available = _getUndislikedSpots();
    if (available.isEmpty) return null;

    final vibePrefs = _prefs.vibePrefs;
    final budgetPref = _prefs.budgetPref;
    final now = DateTime.now();
    final hour = now.hour;

    // 1. Filter by vibe preferences
    List<Spot> filtered = available.where((spot) {
      if (vibePrefs.isEmpty) return true;
      return spot.vibe.any((v) => vibePrefs.contains(v));
    }).toList();

    if (filtered.isEmpty) filtered = List.from(available);

    // 2. Filter by time of day (indoor after 8pm, outdoor before 6pm)
    if (hour >= 20 || hour < 6) {
      final indoorSpots = filtered.where((s) => s.indoor).toList();
      if (indoorSpots.isNotEmpty) filtered = indoorSpots;
    } else if (hour < 18) {
      final outdoorSpots = filtered.where((s) => !s.indoor).toList();
      if (outdoorSpots.isNotEmpty) filtered = outdoorSpots;
    }

    // 3. Filter by budget
    final budgetSpots = filtered.where((s) => s.budget <= budgetPref).toList();
    if (budgetSpots.isNotEmpty) filtered = budgetSpots;

    // 4. Pick highest rated by community reviews count
    if (filtered.isEmpty) return null;
    filtered.sort((a, b) => b.communityReviews.length.compareTo(a.communityReviews.length));
    return filtered.first;
  }

  /// Computes a Date Score on a 50–100 scale.
  /// Factors: distance, vibe match, budget match, rating, reviews, time relevance, curated bonus.
  double computeDateScore(Spot spot, Position? userPosition) {
    double rawScore = 0.0; // 0–10 internal scale, mapped to 50–100

    // 1. Distance Score (0–2.0) — closer = higher
    if (userPosition != null && spot.distance != null) {
      final dist = spot.distance!;
      if (dist <= 1000) {
        rawScore += 2.0;
      } else if (dist <= 3000) {
        rawScore += 1.6;
      } else if (dist <= 5000) {
        rawScore += 1.2;
      } else if (dist <= 10000) {
        rawScore += 0.7;
      } else if (dist <= 25000) {
        rawScore += 0.3;
      }
    } else {
      rawScore += 1.0; // Default middle score if no position
    }

    // 2. Vibe Match (0–2.0)
    final vibePrefs = _prefs.vibePrefs;
    if (vibePrefs.isNotEmpty) {
      final matches = spot.vibe.where((v) => vibePrefs.contains(v)).length;
      rawScore += min(matches * 1.0, 2.0);
    } else {
      rawScore += 1.0; // No prefs = neutral
    }

    // 3. Budget Match (0–1.5)
    final budgetPref = _prefs.budgetPref;
    if (spot.budget == budgetPref) {
      rawScore += 1.5;
    } else if (spot.budget < budgetPref) {
      rawScore += 1.0;
    } else {
      rawScore += 0.3; // Over budget but not zero
    }

    // 4. Rating (0–2.0)
    if (spot.rating != null) {
      rawScore += (spot.rating! / 5.0) * 2.0; // Normalize 5-star to 0–2
    } else {
      rawScore += 1.4; // Default decent rating for unrated places
    }

    // 5. Review Count (0–1.0)
    final reviewBonus = min(spot.communityReviews.length * 0.25, 1.0);
    rawScore += reviewBonus;

    // 6. Time Relevance (0–1.0)
    final hour = DateTime.now().hour;
    final isEvening = hour >= 18 || hour < 6;
    if (isEvening && spot.indoor) {
      rawScore += 1.0; // Indoor spots score higher at night
    } else if (!isEvening && !spot.indoor) {
      rawScore += 1.0; // Outdoor spots score higher during day
    } else {
      rawScore += 0.4;
    }

    // 7. Curated Bonus (0–0.5)
    final isCurated = _repository.curatedSpots.any((s) => s.id == spot.id);
    if (isCurated) {
      rawScore += 0.5;
    }

    // Map 0–10 raw score to 50–100 display score
    final dateScore = 50.0 + (rawScore / 10.0) * 50.0;
    return dateScore.clamp(50.0, 100.0);
  }

  /// Main Filtering Method for Discover.
  /// Now accepts optional radiusMeters for client-side radius enforcement.
  List<Spot> getFilteredSpots({
    required WeatherStatus weather,
    String? category,
    Position? userPosition,
    int? radiusMeters,
  }) {
    List<Spot> list = _getUndislikedSpots();
    lastBeforeFilterCount = list.length;

    print("========== FILTER PIPELINE ==========");
    print("Spots Before Filter: ${list.length}");

    // Weather constraint: if rainy, auto-apply indoor filter
    if (weather == WeatherStatus.rainy) {
      list = list.where((s) => s.indoor).toList();
      print("After Weather Filter (rainy→indoor): ${list.length}");
    }

    // Compute distances if user position available
    if (userPosition != null) {
      for (final spot in list) {
        spot.distance = Geolocator.distanceBetween(
          userPosition.latitude,
          userPosition.longitude,
          spot.lat,
          spot.lng,
        );
      }
    }

    // Client-side radius filtering
    if (radiusMeters != null && userPosition != null) {
      list = list.where((s) => s.distance != null && s.distance! <= radiusMeters).toList();
      lastAfterRadiusCount = list.length;
      print("After Radius Filter (${radiusMeters}m): ${list.length}");
    } else {
      lastAfterRadiusCount = list.length;
    }

    // Category filter — compare directly (already normalized at parse time)
    if (category != null && category.isNotEmpty) {
      list = list.where((s) => s.category.toLowerCase() == category.toLowerCase()).toList();
    }
    lastAfterCategoryCount = list.length;
    print("After Category Filter: ${list.length}");

    // Compute Date Scores and sort
    for (final spot in list) {
      spot.dateScore = computeDateScore(spot, userPosition);
    }
    list.sort((a, b) => (b.dateScore ?? 0).compareTo(a.dateScore ?? 0));

    lastDisplayedCount = list.length;
    print("Displayed Spots: ${list.length}");
    print("=====================================");

    return list;
  }

  /// Get spots for a specific category (used by Discover horizontal rails).
  List<Spot> getSpotsForCategory(String category, Position? userPosition) {
    final list = _getUndislikedSpots()
        .where((s) => s.category.toLowerCase() == category.toLowerCase())
        .toList();

    // Compute distances
    if (userPosition != null) {
      for (final spot in list) {
        spot.distance = Geolocator.distanceBetween(
          userPosition.latitude,
          userPosition.longitude,
          spot.lat,
          spot.lng,
        );
      }
    }

    // Compute Date Scores and sort
    for (final spot in list) {
      spot.dateScore = computeDateScore(spot, userPosition);
    }
    list.sort((a, b) => (b.dateScore ?? 0).compareTo(a.dateScore ?? 0));

    return list;
  }

  /// Get all undisliked spots scored and sorted (for section rails).
  List<Spot> getAllScoredSpots(Position? userPosition) {
    final list = _getUndislikedSpots();

    if (userPosition != null) {
      for (final spot in list) {
        spot.distance = Geolocator.distanceBetween(
          userPosition.latitude,
          userPosition.longitude,
          spot.lat,
          spot.lng,
        );
      }
    }

    for (final spot in list) {
      spot.dateScore = computeDateScore(spot, userPosition);
    }
    list.sort((a, b) => (b.dateScore ?? 0).compareTo(a.dateScore ?? 0));

    return list;
  }
}
