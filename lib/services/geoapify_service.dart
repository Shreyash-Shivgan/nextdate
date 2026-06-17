import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../models/spot.dart';
import '../data/spots_repository.dart';

const _apiKey = 'c036c73dfdb54bf4b67113acb92388f8';

class GeoapifyService {
  static final GeoapifyService _instance = GeoapifyService._internal();
  factory GeoapifyService() => _instance;
  GeoapifyService._internal();

  // --- Public diagnostics state ---
  bool isLastFetchFallback = false;
  String? lastRequestUrl;
  int? lastHttpStatus;
  int? lastFeatureCount;
  int? lastParsedCount;
  int? lastFailedParseCount;
  int? lastFilteredCount;
  int? lastDisplayedCount;
  DateTime? lastRefreshTime;

  Future<List<Spot>> fetchNearbySpots({
    required double lat,
    required double lng,
    int radius = 5000,
  }) async {
    final categories = [
      'catering.restaurant',
      'catering.cafe',
      'catering.bar',
      'leisure.park',
      'tourism.attraction',
      'tourism.sights',
      'entertainment.museum',
      'amenity.library',
      'commercial.books',
      'entertainment.culture',
    ];

    final uri = Uri.parse('https://api.geoapify.com/v2/places').replace(
      queryParameters: {
        'categories': categories.join(','),
        'filter': 'circle:$lng,$lat,$radius',
        'bias': 'proximity:$lng,$lat',
        'limit': '150',
        'apiKey': _apiKey,
      },
    );

    lastRequestUrl = uri.toString();
    lastRefreshTime = DateTime.now();

    print("========== GEOAPIFY PIPELINE ==========");
    print("GPS: $lat,$lng");
    print("Radius: ${radius}m");
    print("Geoapify URL: $uri");

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      lastHttpStatus = response.statusCode;
      print("HTTP: ${response.statusCode}");
      print("Response Body Length: ${response.body.length}");

      if (response.statusCode != 200) {
        print("ERROR: Geoapify returned ${response.statusCode}");
        print("Error Body: ${response.body.length > 500 ? response.body.substring(0, 500) : response.body}");
        throw Exception('Geoapify HTTP ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final List features = data['features'] as List? ?? [];
      lastFeatureCount = features.length;
      print("Features Returned: ${features.length}");

      final repository = SpotsRepository();
      final List<Spot> spots = [];
      int failedCount = 0;

      for (final feature in features) {
        try {
          final spot = _mapToSpot(feature, repository, lat, lng);
          if (spot != null) {
            spots.add(spot);
          } else {
            failedCount++;
          }
        } catch (e) {
          failedCount++;
          print("Parse error: $e");
        }
      }

      lastParsedCount = spots.length;
      lastFailedParseCount = failedCount;
      print("Parsed: ${spots.length}");
      print("Failed Parses: $failedCount");

      if (spots.isEmpty) {
        isLastFetchFallback = true;
        print("[FALLBACK] Zero places parsed. Loading curated spots...");
        final fallback = await _loadFallbackSpots(lat, lng, repository);
        lastParsedCount = fallback.length;
        print("[FALLBACK] Loaded ${fallback.length} curated spots.");
        print("========================================");
        return fallback;
      }

      isLastFetchFallback = false;
      print("========================================");
      return spots;
    } on TimeoutException {
      print("ERROR: Geoapify request timed out after 10s");
      lastHttpStatus = -1;
      isLastFetchFallback = true;
      final fallback = await _loadFallbackSpots(lat, lng, SpotsRepository());
      print("========================================");
      return fallback;
    } catch (e) {
      print("ERROR: Geoapify fetch failed: $e");
      lastHttpStatus = -1;
      isLastFetchFallback = true;
      final fallback = await _loadFallbackSpots(lat, lng, SpotsRepository());
      print("========================================");
      return fallback;
    }
  }

  Future<List<Spot>> _loadFallbackSpots(double lat, double lng, SpotsRepository repository) async {
    if (repository.curatedSpots.isEmpty) {
      await repository.loadSpots();
    }
    final curated = repository.curatedSpots;
    final List<Spot> fallbackSpots = [];
    for (final s in curated) {
      final dist = Geolocator.distanceBetween(lat, lng, s.lat, s.lng);
      fallbackSpots.add(s.copyWith(distance: dist));
    }
    fallbackSpots.sort((a, b) => (a.distance ?? 0.0).compareTo(b.distance ?? 0.0));
    return fallbackSpots;
  }

  Spot? _mapToSpot(Map<String, dynamic> place, SpotsRepository repository, double userLat, double userLng) {
    final props = place['properties'] ?? {};
    final String? rawName = props['name'] as String?;
    if (rawName == null || rawName.trim().isEmpty) {
      return null; // Skip features without a real commercial venue name
    }
    final String name = rawName.trim();
    final String id = props['place_id'] ?? DateTime.now().millisecondsSinceEpoch.toString();

    // --- Parse coordinates safely ---
    if (place['geometry'] == null || place['geometry']['coordinates'] == null) {
      return null; // Skip features without valid coordinates
    }
    final coords = place['geometry']['coordinates'] as List;
    if (coords.length < 2) return null;

    final double longitude = (coords[0] as num).toDouble();
    final double latitude = (coords[1] as num).toDouble();

    // Validate coordinates are reasonable
    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      return null;
    }

    final double distance = Geolocator.distanceBetween(userLat, userLng, latitude, longitude);

    // 1. Check curated match (proximity + name similarity)
    final curatedSpot = repository.findCuratedMatch(name, latitude, longitude);
    if (curatedSpot != null) {
      return curatedSpot.copyWith(distance: distance);
    }

    // 2. Generate enrichment for unmatched places
    final String uniqueString = "${id}_$name";
    final int hash = uniqueString.hashCode;

    final categoriesVal = props['categories'];
    final List categoriesList = categoriesVal is List ? categoriesVal : [];
    
    String category = 'Activity';
    for (final catVal in categoriesList) {
      final normalized = Spot.normalizeCategory(catVal.toString());
      if (normalized != 'Activity') {
        category = normalized;
        break;
      }
    }

    if (category == 'Activity') {
      return null; // Skip generic unmatched activities to only keep primary date spots
    }
    final List<String> vibe = _mapVibe(category);

    int budget = 2;
    if (category == 'Restaurant' || category == 'Bar') {
      budget = 2 + (hash.abs() % 2);
    } else if (category == 'Cafe' || category == 'Park') {
      budget = 1;
    } else {
      budget = 1 + (hash.abs() % 2);
    }

    final int avgSpend = budget == 1 ? 400 : (budget == 2 ? 1200 : 3000);
    final bool indoor = _isIndoor(category);

    return Spot(
      id: id,
      name: name,
      neighborhood: props['suburb'] ?? props['city'] ?? props['district'] ?? 'Nearby',
      category: category,
      vibe: vibe,
      budget: budget,
      avgSpend: avgSpend,
      indoor: indoor,
      imageUrl: _getCuratedFallbackImage(category, hash),
      aiBlurb: _generateBlurb(category, name),
      activities: _generateActivities(category),
      bestTime: _getBestTime(category),
      checklist: _getChecklist(category),
      lat: latitude,
      lng: longitude,
      distance: distance,
      comboSpotId: null,
      communityReviews: [],
    );
  }

  List<String> _mapVibe(String category) {
    switch (category) {
      case 'Cafe': return ['Cozy', 'Foodie'];
      case 'Restaurant': return ['Foodie', 'Cozy'];
      case 'Bar': return ['Cozy', 'Adventurous'];
      case 'Park': return ['Adventurous', 'Scenic'];
      case 'Museum': return ['Cultural', 'Cozy'];
      default: return ['Adventurous'];
    }
  }

  bool _isIndoor(String category) {
    return const ['Cafe', 'Restaurant', 'Museum', 'Bar'].contains(category);
  }

  String _generateBlurb(String category, String name) {
    switch (category) {
      case 'Cafe': return 'Coffee, comfy corners, and enough time to decide whether you\'re soulmates.';
      case 'Restaurant': return 'Low-key one of the best places to impress someone without looking like you\'re trying too hard.';
      case 'Bar': return 'Ideal when you\'re looking for moody lighting, craft cocktails, and deep conversations.';
      case 'Park': return 'Touch grass and stroll around. The perfect excuse to walk close and share a playlist.';
      case 'Museum': return 'Culture mode activated. Walk hand-in-hand and pretend you understand modern art.';
      case 'Attraction': return 'Perfect if you\'re feeling a little main-character energy tonight.';
      default: return 'Low-key a perfect spot to match the vibe and start a cute conversation.';
    }
  }

  String _getBestTime(String category) {
    if (category == 'Cafe') return 'Morning, 10:30 AM';
    if (category == 'Bar' || category == 'Restaurant') return 'Night, 8:30 PM';
    if (category == 'Park' || category == 'Attraction') return 'Evening, 5:30 PM';
    return 'Afternoon, 3:00 PM';
  }

  List<String> _generateActivities(String category) {
    switch (category) {
      case 'Cafe': return ['Try the signature coffee brew or sweet treats', 'Share a delicious dessert', 'Enjoy a cozy chat together'];
      case 'Restaurant': return ['Order a gourmet dinner course', 'Sip on refreshing drinks', 'Indulge in a sweet dessert'];
      case 'Park': return ['Take a peaceful nature stroll', 'Find a quiet spot to sit', 'Enjoy the scenic views'];
      case 'Museum': return ['Admire historical artifacts or beautiful paintings', 'Walk hand-in-hand through halls', 'Discuss art and history'];
      case 'Bar': return ['Sip on craft cocktails', 'Enjoy the music and ambiance', 'Try standard finger foods'];
      default: return ['Explore the unique venue', 'Take memorable photographs', 'Bond over a new experience'];
    }
  }

  List<String> _getChecklist(String category) {
    switch (category) {
      case 'Cafe':
      case 'Restaurant': return ['Book in advance', 'Dress smart casual', 'Check menu reviews'];
      case 'Park':
      case 'Attraction': return ['Carry water', 'Wear walking shoes', 'Avoid visiting in high heat'];
      case 'Bar': return ['Carry physical ID', 'Confirm opening hours', 'Pre-book weekend tables'];
      case 'Museum': return ['Maintain silence', 'Check ticket prices', 'No flash photography'];
      default: return ['Dress comfortably', 'Reach 10 minutes early', 'Have fun planning!'];
    }
  }

  String _getCuratedFallbackImage(String category, int hash) {
    final Map<String, List<String>> categoryImages = {
      'Cafe': [
        'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=800&q=80',
        'https://images.unsplash.com/photo-1498804103079-a6351b050096?w=800&q=80',
        'https://images.unsplash.com/photo-1453614512568-c4024d13c247?w=800&q=80',
        'https://images.unsplash.com/photo-1447933601403-0c6688de566e?w=800&q=80',
        'https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=800&q=80',
        'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=800&q=80',
        'https://images.unsplash.com/photo-1511920170033-f8396924c348?w=800&q=80',
        'https://images.unsplash.com/photo-1515694346937-94d85e41e6f0?w=800&q=80',
        'https://images.unsplash.com/photo-1521017432531-fbd92d768814?w=800&q=80',
        'https://images.unsplash.com/photo-1485182708500-e8f1f318ba72?w=800&q=80',
      ],
      'Restaurant': [
        'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800&q=80',
        'https://images.unsplash.com/photo-1552566626-52f8b828add9?w=800&q=80',
        'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800&q=80',
        'https://images.unsplash.com/photo-1550966871-3ed3cdb5ed0c?w=800&q=80',
        'https://images.unsplash.com/photo-1559339352-11d035aa65de?w=800&q=80',
        'https://images.unsplash.com/photo-1544025162-d76694265947?w=800&q=80',
        'https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=800&q=80',
        'https://images.unsplash.com/photo-1533777857889-4be7c70b33f7?w=800&q=80',
        'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800&q=80',
        'https://images.unsplash.com/photo-1514362545857-3bc16c4c7d1b?w=800&q=80',
      ],
      'Park': [
        'https://images.unsplash.com/photo-1502082553048-f009c37129b9?w=800&q=80',
        'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=800&q=80',
        'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=800&q=80',
        'https://images.unsplash.com/photo-1448375240586-882707db888b?w=800&q=80',
        'https://images.unsplash.com/photo-1519331379826-f10be5486c6f?w=800&q=80',
        'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=800&q=80',
        'https://images.unsplash.com/photo-1518495973542-4542c06a5843?w=800&q=80',
        'https://images.unsplash.com/photo-1473448912268-2022ce9509d8?w=800&q=80',
        'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=800&q=80',
        'https://images.unsplash.com/photo-1461896836934-ffe607ba8211?w=800&q=80',
      ],
      'Museum': [
        'https://images.unsplash.com/photo-1580537659444-1297eb700224?w=800&q=80',
        'https://images.unsplash.com/photo-1569003339405-ea396a5a8a90?w=800&q=80',
        'https://images.unsplash.com/photo-1507842217343-583bb7270b66?w=800&q=80',
        'https://images.unsplash.com/photo-1521587760476-6c12a4b040da?w=800&q=80',
        'https://images.unsplash.com/photo-1481627834876-b7833e8f5570?w=800&q=80',
        'https://images.unsplash.com/photo-1491841538374-7227d8ce6a6a?w=800&q=80',
        'https://images.unsplash.com/photo-1544947950-fa07a98d237f?w=800&q=80',
        'https://images.unsplash.com/photo-1512820790803-83ca734da794?w=800&q=80',
        'https://images.unsplash.com/photo-1554941068-a252680d25d9?w=800&q=80',
        'https://images.unsplash.com/photo-1506880018603-83d5b814b5a6?w=800&q=80',
      ],
      'Bar': [
        'https://images.unsplash.com/photo-1514933651103-005eec06c04b?w=800&q=80',
        'https://images.unsplash.com/photo-1470337458703-46ad1756a187?w=800&q=80',
        'https://images.unsplash.com/photo-1574096079513-d8259312b785?w=800&q=80',
        'https://images.unsplash.com/photo-1510812431401-41d2bd2722f3?w=800&q=80',
        'https://images.unsplash.com/photo-1527661591475-527312dd65f5?w=800&q=80',
        'https://images.unsplash.com/photo-1482049016688-2d3e1b311543?w=800&q=80',
        'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?w=800&q=80',
        'https://images.unsplash.com/photo-1543007630-9710e4a00a20?w=800&q=80',
        'https://images.unsplash.com/photo-1560512823-829485b8bf24?w=800&q=80',
        'https://images.unsplash.com/photo-1516997121675-4c2d04f3ba15?w=800&q=80',
      ],
      'Attraction': [
        'https://images.unsplash.com/photo-1533105079780-92b9be482077?w=800&q=80',
        'https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?w=800&q=80',
        'https://images.unsplash.com/photo-1501854140801-50d01698950b?w=800&q=80',
        'https://images.unsplash.com/photo-1472396961693-142e6e269027?w=800&q=80',
        'https://images.unsplash.com/photo-1513694203232-719a280e022f?w=800&q=80',
        'https://images.unsplash.com/photo-1533240332313-0db49b439ad3?w=800&q=80',
        'https://images.unsplash.com/photo-1519681393784-d120267933ba?w=800&q=80',
        'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=800&q=80',
        'https://images.unsplash.com/photo-1454496522488-7a8e488e8606?w=800&q=80',
        'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800&q=80',
      ],
      'Activity': [
        'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800&q=80',
        'https://images.unsplash.com/photo-1513151233558-d860c5398176?w=800&q=80',
        'https://images.unsplash.com/photo-1485846234645-a62644f84728?w=800&q=80',
        'https://images.unsplash.com/photo-1516280440614-37939bbacd6a?w=800&q=80',
      ],
    };

    final imageList = categoryImages[category] ?? categoryImages['Activity']!;
    return imageList[hash.abs() % imageList.length];
  }
}
