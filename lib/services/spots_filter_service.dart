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
      // After 8pm or early morning: prefer indoor
      final indoorSpots = filtered.where((s) => s.indoor).toList();
      if (indoorSpots.isNotEmpty) filtered = indoorSpots;
    } else if (hour < 18) {
      // Before 6pm: prefer outdoor
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

  // Main Filtering Method for Discover
  List<Spot> getFilteredSpots({
    required WeatherStatus weather,
    String? category,
  }) {
    List<Spot> list = _getUndislikedSpots();

    // Weather constraint: if rainy, auto-apply indoor filter
    if (weather == WeatherStatus.rainy) {
      list = list.where((s) => s.indoor).toList();
    }

    // Category filter (if selected)
    if (category != null && category.isNotEmpty) {
      list = list.where((s) => s.category.toLowerCase() == category.toLowerCase()).toList();
    }

    // Score spots based on Saved Preferences
    final scored = list.map((spot) {
      double score = 0.0;

      // 1. Matches saved vibe preferences
      final vibePrefs = _prefs.vibePrefs;
      if (vibePrefs.isNotEmpty) {
        final matches = spot.vibe.where((v) => vibePrefs.contains(v)).length;
        score += matches * 2.0; // Heavy weight to saved vibes
      }

      // 2. Matches budget preference
      final budgetPref = _prefs.budgetPref;
      if (spot.budget == budgetPref) {
        score += 1.5;
      } else if (spot.budget < budgetPref) {
        score += 0.8;
      } else {
        score -= 1.0; // Penalty for over-budget
      }

      return _ScoredSpot(spot, score);
    }).toList();

    // Sort by score descending
    scored.sort((a, b) => b.score.compareTo(a.score));

    return scored.map((s) => s.spot).toList();
  }
}

class _ScoredSpot {
  final Spot spot;
  final double score;
  _ScoredSpot(this.spot, this.score);
}
