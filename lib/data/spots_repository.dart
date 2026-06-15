import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../models/spot.dart';

class SpotsRepository {
  static final SpotsRepository _instance = SpotsRepository._internal();
  factory SpotsRepository() => _instance;
  SpotsRepository._internal();

  List<Spot> _spots = [];
  List<Spot> _curatedSpots = [];
  final List<void Function()> _listeners = [];

  void addListener(void Function() listener) => _listeners.add(listener);
  void removeListener(void Function() listener) => _listeners.remove(listener);
  void notifyListeners() {
    for (final l in _listeners) {
      l();
    }
  }

  List<Spot> get spots => _spots;
  List<Spot> get curatedSpots => _curatedSpots;

  Future<void> loadSpots() async {
    if (_curatedSpots.isNotEmpty) return;
    try {
      final jsonString = await rootBundle.loadString('assets/data/spots.json');
      final List<dynamic> jsonList = jsonDecode(jsonString);
      _curatedSpots = jsonList.map((s) => Spot.fromJson(s)).toList();
      if (_spots.isEmpty) {
        _spots = List.from(_curatedSpots);
      }
      notifyListeners();
    } catch (e) {
      print("Error loading spots.json: $e");
    }
  }

  void setSpots(List<Spot> newSpots) {
    // Merge: curated spots that aren't duplicated in live results + live results
    final liveIds = newSpots.map((s) => s.id).toSet();
    final uniqueCurated = _curatedSpots.where((s) => !liveIds.contains(s.id)).toList();
    _spots = [...newSpots, ...uniqueCurated];
    notifyListeners();
  }

  List<String> get allCategories {
    final cats = _spots.map((s) => s.category).toSet().toList();
    cats.sort();
    return cats;
  }

  List<Spot> getSpotsByCategory(String category) {
    return _spots.where((s) => s.category.toLowerCase() == category.toLowerCase()).toList();
  }

  Spot? findCuratedMatch(String name, double lat, double lng) {
    final cleanName = name.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
    if (cleanName.isEmpty) return null;

    for (final spot in _curatedSpots) {
      final dist = Geolocator.distanceBetween(lat, lng, spot.lat, spot.lng);
      
      // Proximity match: very close (< 100 meters)
      if (dist <= 100) {
        return spot;
      }
      
      // Proximity + Name match: < 500 meters and name matches
      if (dist <= 500) {
        final cleanCuratedName = spot.name.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
        if (cleanCuratedName.contains(cleanName) || cleanName.contains(cleanCuratedName)) {
          return spot;
        }
      }
    }
    return null;
  }

  Spot? getSpotById(String id) {
    // Look first in active query spots, then in curated spots
    try {
      return spots.firstWhere((s) => s.id == id);
    } catch (_) {
      try {
        return curatedSpots.firstWhere((s) => s.id == id);
      } catch (_) {
        return null;
      }
    }
  }

  List<Spot> getSpotsByNeighborhood(String neighborhood, {String? excludeId}) {
    return spots
        .where((s) => s.neighborhood.toLowerCase() == neighborhood.toLowerCase() && s.id != excludeId)
        .toList();
  }

  Spot? getComboSpot(String? comboSpotId) {
    if (comboSpotId == null) return null;
    return getSpotById(comboSpotId);
  }
}
