import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/spot.dart';
import '../services/places_service.dart';


class SpotsRepository {
  static final SpotsRepository _instance = SpotsRepository._internal();
  factory SpotsRepository() => _instance;
  SpotsRepository._internal();

  List<Spot> _spots = [];
  List<Spot> _apiSpots = [];
  bool _isLoaded = false;

  List<Spot> get spots {
    final Map<String, Spot> merged = {};
    for (final s in _spots) {
      merged[s.name.toLowerCase().trim()] = s;
    }
    for (final s in _apiSpots) {
      merged[s.name.toLowerCase().trim()] = s;
    }
    return merged.values.toList();
  }

  Future<void> loadSpots() async {
    if (_isLoaded) return;
    try {
      final String jsonString = await rootBundle.loadString('assets/data/spots.json');
      final List<dynamic> jsonList = json.decode(jsonString) as List;
      _spots = jsonList.map((j) => Spot.fromJson(j as Map<String, dynamic>)).toList();
      _isLoaded = true;
    } catch (e) {
      print('Error loading spots data: $e');
      _spots = [];
    }
  }

  Future<void> fetchAndMergeLiveSpots({double? lat, double? lng}) async {
    try {
      final service = PlacesService();
      final fetched = lat != null && lng != null
          ? await service.fetchNearbySpots(lat: lat, lng: lng)
          : await service.fetchNearbySpots();
      if (fetched.isNotEmpty) {
        _apiSpots = fetched;
      }
    } catch (e) {
      print('Error fetching live spots: $e');
      // Fail silently, fallback is already in _spots
    }
  }


  Spot? getSpotById(String id) {
    try {
      return _spots.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Spot> getSpotsByNeighborhood(String neighborhood, {String? excludeId}) {
    return _spots
        .where((s) => s.neighborhood.toLowerCase() == neighborhood.toLowerCase() && s.id != excludeId)
        .toList();
  }

  Spot? getComboSpot(String? comboSpotId) {
    if (comboSpotId == null) return null;
    return getSpotById(comboSpotId);
  }
}
