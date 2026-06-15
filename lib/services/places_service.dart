import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/spot.dart';

class PlacesService {
  // Overpass API endpoint
  static const String _overpassUrl = 'https://overpass-api.de/api/interpreter';

  Future<List<Spot>> fetchNearbySpots({
    double lat = 19.076,
    double lng = 72.877,
    double radius = 8000,
    List<String> types = const [
      'restaurant',
      'cafe',
      'park',
      'museum',
      'bar',
      'library',
      'tourist_attraction'
    ],
  }) async {
    try {
      // Build Overpass QL query with name validation to restrict to active places
      // Note: No spaces inside coordinates of (around:...) parameter to avoid syntax issues.
      final String query = '''
[out:json][timeout:30];
(
  nwr["amenity"~"restaurant|cafe|bar|pub|library"]["name"](around:$radius,$lat,$lng);
  nwr["leisure"~"park|garden"]["name"](around:$radius,$lat,$lng);
  nwr["tourism"~"museum|art_gallery|attraction|viewpoint"]["name"](around:$radius,$lat,$lng);
);
out center;
''';

      print('Fetching spots from Overpass API...');
      final String url = '$_overpassUrl?data=' + Uri.encodeComponent(query);

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'NextDateApp/1.0',
          'Accept': '*/*',
        },
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic>? elements = data['elements'];
        if (elements == null) return [];

        final List<Spot> spots = [];
        for (final item in elements) {
          final tags = item['tags'] ?? {};
          final String name = tags['name']?.toString() ?? '';
          if (name.isEmpty) continue;

          try {
            spots.add(_mapElementToSpot(item, lat, lng));
          } catch (e) {
            print('Error mapping element ${item['id']}: $e');
          }
        }
        return spots;
      } else {
        print('Overpass API error: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Overpass API exception: $e');
      return [];
    }
  }

  Spot _mapElementToSpot(Map<String, dynamic> json, double searchLat, double searchLng) {
    final String id = json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
    final Map<String, dynamic> tags = json['tags'] ?? {};
    final String name = tags['name'] ?? 'A Lovely Date Spot';

    // Construct address
    final List<String> addressParts = [];
    if (tags['addr:housenumber'] != null) addressParts.add(tags['addr:housenumber'].toString());
    if (tags['addr:street'] != null) addressParts.add(tags['addr:street'].toString());
    if (tags['addr:suburb'] != null) addressParts.add(tags['addr:suburb'].toString());
    if (tags['addr:city'] != null) addressParts.add(tags['addr:city'].toString());
    String address = addressParts.join(', ');
    if (address.isEmpty) {
      address = "${tags['name'] ?? 'Spot'} Area, Mumbai";
    }

    final String neighborhood = _deriveNeighborhood(address, name);

    // Get coordinates (Overpass nodes have 'lat' and 'lon', ways/relations have center coordinates)
    final double latitude = json['lat']?.toDouble() ?? json['center']?['lat']?.toDouble() ?? searchLat;
    final double longitude = json['lon']?.toDouble() ?? json['center']?['lon']?.toDouble() ?? searchLng;

    // Stable hash of name+id for assigning stable budget & images
    final String uniqueString = "${id}_$name";
    final int hash = uniqueString.hashCode;

    // Budget determination (1/2/3)
    int budget = 2; // Default moderate
    final String amenity = tags['amenity']?.toString() ?? '';
    final String leisure = tags['leisure']?.toString() ?? '';
    final String tourism = tags['tourism']?.toString() ?? '';

    if (amenity == 'bar' || amenity == 'pub') {
      budget = 2 + (hash.abs() % 2); // 2 or 3
    } else {
      budget = 1 + (hash.abs() % 3); // 1, 2, or 3
    }

    final int avgSpend = budget == 1 ? 400 : (budget == 2 ? 1200 : 3000);

    // Category mapping
    String primaryType = 'restaurant';
    if (amenity.isNotEmpty) {
      primaryType = amenity;
    } else if (leisure.isNotEmpty) {
      primaryType = leisure;
    } else if (tourism.isNotEmpty) {
      primaryType = tourism;
    }
    final String category = _mapCategory(primaryType);

    // AI Blurb (description/comment or default)
    final String aiBlurb = tags['description']?.toString() ??
        tags['comment']?.toString() ??
        _getDefaultBlurb(category, name);

    // Curated high quality Unsplash photos based on category
    final Map<String, List<String>> categoryImages = {
      'Café': [
        'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=800&q=80',
        'https://images.unsplash.com/photo-1498804103079-a6351b050096?w=800&q=80',
        'https://images.unsplash.com/photo-1453614512568-c4024d13c247?w=800&q=80',
      ],
      'Restaurant': [
        'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800&q=80',
        'https://images.unsplash.com/photo-1552566626-52f8b828add9?w=800&q=80',
        'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800&q=80',
      ],
      'Park': [
        'https://images.unsplash.com/photo-1502082553048-f009c37129b9?w=800&q=80',
        'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=800&q=80',
        'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=800&q=80',
      ],
      'Museum': [
        'https://images.unsplash.com/photo-1580537659444-1297eb700224?w=800&q=80',
        'https://images.unsplash.com/photo-1569003339405-ea396a5a8a90?w=800&q=80',
      ],
      'Bar': [
        'https://images.unsplash.com/photo-1514933651103-005eec06c04b?w=800&q=80',
        'https://images.unsplash.com/photo-1470337458703-46ad1756a187?w=800&q=80',
      ],
      'Library': [
        'https://images.unsplash.com/photo-1507842217343-583bb7270b66?w=800&q=80',
        'https://images.unsplash.com/photo-1521587760476-6c12a4b040da?w=800&q=80',
      ],
      'Scenic': [
        'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=800&q=80',
        'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&q=80',
      ],
      'Beach': [
        'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&q=80',
        'https://images.unsplash.com/photo-1519046904884-53103b34b206?w=800&q=80',
      ],
      'Activity': [
        'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800&q=80',
        'https://images.unsplash.com/photo-1513151233558-d860c5398176?w=800&q=80',
      ],
    };

    final imageList = categoryImages[category] ?? categoryImages['Activity']!;
    final String imageUrl = imageList[hash.abs() % imageList.length];

    // Opening Hours / bestTime
    final String bestTime = tags['opening_hours'] != null
        ? "Hours: ${tags['opening_hours']}"
        : "Evening, 6:00 PM";

    // Indoor / outdoor mapping
    final bool indoor = _isIndoor(primaryType);

    // Vibe tags mapping
    final List<String> vibe = _mapVibe(primaryType);

    // Activities & Checklist generation
    final List<String> activities = _generateActivities(category);
    final List<String> checklist = _generateChecklist(category);

    return Spot(
      id: id,
      name: name,
      neighborhood: neighborhood,
      category: category,
      vibe: vibe,
      budget: budget,
      avgSpend: avgSpend,
      indoor: indoor,
      imageUrl: imageUrl,
      aiBlurb: aiBlurb,
      activities: activities,
      bestTime: bestTime,
      checklist: checklist,
      lat: latitude,
      lng: longitude,
      comboSpotId: null,
      communityReviews: [],
      rating: tags['stars'] != null ? double.tryParse(tags['stars'].toString()) : 4.0,
    );
  }

  String _deriveNeighborhood(String address, String name) {
    const areas = [
      'Bandra',
      'Colaba',
      'Juhu',
      'Fort',
      'Powai',
      'Worli',
      'Versova',
      'Andheri',
      'Marine Lines',
      'Dadar'
    ];
    final combined = "$name, $address".toLowerCase();
    for (final area in areas) {
      if (combined.contains(area.toLowerCase())) {
        return area;
      }
    }
    return 'Mumbai';
  }

  String _mapCategory(String type) {
    switch (type) {
      case 'cafe':
      case 'coffee_shop':
        return 'Café';
      case 'park':
      case 'garden':
      case 'amusement_park':
        return 'Park';
      case 'museum':
      case 'art_gallery':
        return 'Museum';
      case 'bar':
      case 'pub':
      case 'night_club':
        return 'Bar';
      case 'restaurant':
      case 'meal_takeaway':
      case 'food':
        return 'Restaurant';
      case 'library':
      case 'book_store':
        return 'Library';
      case 'tourist_attraction':
      case 'scenic_point':
      case 'viewpoint':
        return 'Scenic';
      default:
        return 'Activity';
    }
  }

  String _getDefaultBlurb(String category, String name) {
    return 'A wonderful $category experience at $name, offering beautiful vibes and perfect date opportunities.';
  }

  bool _isIndoor(String type) {
    const indoorTypes = ['restaurant', 'cafe', 'coffee_shop', 'museum', 'art_gallery', 'library', 'book_store', 'bar', 'pub'];
    return indoorTypes.contains(type);
  }

  List<String> _mapVibe(String type) {
    if (type == 'cafe' || type == 'coffee_shop' || type == 'restaurant' || type == 'food') {
      return ['Foodie', 'Cozy'];
    } else if (type == 'park' || type == 'garden' || type == 'tourist_attraction' || type == 'viewpoint') {
      return ['Adventurous', 'Scenic'];
    } else if (type == 'museum' || type == 'art_gallery' || type == 'library' || type == 'book_store') {
      return ['Cultural', 'Cozy'];
    } else if (type == 'bar' || type == 'pub' || type == 'night_club') {
      return ['Cozy', 'Foodie'];
    }
    return ['Adventurous'];
  }

  List<String> _generateActivities(String category) {
    switch (category) {
      case 'Café':
        return ['Try the signature coffee brew', 'Share a delicious dessert', 'Enjoy a cozy chat together'];
      case 'Restaurant':
        return ['Order a gourmet dinner course', 'Sip on refreshing drinks', 'Indulge in a sweet dessert'];
      case 'Park':
        return ['Take a peaceful nature stroll', 'Find a quiet spot to sit', 'Enjoy the green scenic views'];
      case 'Museum':
      case 'Library':
        return ['Admire historical artifacts', 'Walk hand-in-hand through halls', 'Discuss art and history'];
      case 'Bar':
        return ['Sip on craft cocktails', 'Enjoy the music and ambiance', 'Try standard finger foods'];
      default:
        return ['Explore the unique venue', 'Take memorable photographs', 'Bond over a new experience'];
    }
  }

  List<String> _generateChecklist(String category) {
    switch (category) {
      case 'Café':
      case 'Restaurant':
        return ['Book in advance', 'Dress smart casual', 'Check menu reviews'];
      case 'Park':
        return ['Carry water', 'Wear walking shoes', 'Avoid visiting in high heat'];
      case 'Bar':
        return ['Carry physical ID', 'Confirm opening hours', 'Pre-book weekend tables'];
      case 'Museum':
      case 'Library':
        return ['Maintain silence', 'Check ticket prices', 'No flash photography'];
      default:
        return ['Dress comfortably', 'Reach 10 minutes early', 'Have fun planning!'];
    }
  }
}
