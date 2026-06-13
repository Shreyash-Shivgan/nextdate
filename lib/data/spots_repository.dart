import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/spot.dart';

class SpotsRepository {
  static final SpotsRepository _instance = SpotsRepository._internal();
  factory SpotsRepository() => _instance;
  SpotsRepository._internal();

  List<Spot> _spots = [];
  bool _isLoaded = false;

  List<Spot> get spots => _spots;

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
