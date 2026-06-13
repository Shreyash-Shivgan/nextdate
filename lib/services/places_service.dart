import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/spot.dart';

class PlacesService {
  static const String _apiKey = 'YOUR_API_KEY';

  Future<List<Spot>> fetchNearbySpots({
    double lat = 19.076,
    double lng = 72.877,
    double radius = 15000,
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
      final response = await http.post(
        Uri.parse('https://places.googleapis.com/v1/places:searchNearby'),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-FieldMask':
              'places.id,places.displayName,places.formattedAddress,places.location,places.rating,places.photos,places.currentOpeningHours,places.priceLevel,places.editorialSummary,places.types',
        },
        body: jsonEncode({
          'includedTypes': types,
          'maxResultCount': 20,
          'locationRestriction': {
            'circle': {
              'center': {'latitude': lat, 'longitude': lng},
              'radius': radius,
            }
          }
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic>? places = data['places'];
        if (places == null) return [];

        return places.map((json) => _mapPlaceToSpot(json)).toList();
      } else {
        print('Places API error: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Places API exception: $e');
      return [];
    }
  }

  Spot _mapPlaceToSpot(Map<String, dynamic> json) {
    final String id = json['id'] ?? '';
    final String name = json['displayName']?['text'] ?? 'A Lovely Date Spot';
    final String address = json['formattedAddress'] ?? '';
    final String neighborhood = _deriveNeighborhood(address);

    final double latitude = json['location']?['latitude']?.toDouble() ?? 19.076;
    final double longitude = json['location']?['longitude']?.toDouble() ?? 72.877;
    final double? rating = json['rating']?.toDouble();

    // Price level mapping (1/2/3)
    final String priceLevel = json['priceLevel'] ?? '';
    int budget = 2; // default moderate
    if (priceLevel == 'PRICE_LEVEL_INEXPENSIVE' || priceLevel == 'PRICE_LEVEL_FREE') {
      budget = 1;
    } else if (priceLevel == 'PRICE_LEVEL_MODERATE') {
      budget = 2;
    } else if (priceLevel == 'PRICE_LEVEL_EXPENSIVE' || priceLevel == 'PRICE_LEVEL_VERY_EXPENSIVE') {
      budget = 3;
    }

    final int avgSpend = budget == 1 ? 400 : (budget == 2 ? 1200 : 3000);

    // Categories mapping
    final List<dynamic> rawTypes = json['types'] ?? [];
    final String primaryType = rawTypes.isNotEmpty ? rawTypes[0].toString() : 'restaurant';
    final String category = _mapCategory(primaryType);

    // Editorial Summary
    final String aiBlurb = json['editorialSummary']?['text'] ??
        _getDefaultBlurb(category, name);

    // Photo URL construction
    final List<dynamic>? photos = json['photos'];
    String imageUrl = 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800&q=80';
    if (photos != null && photos.isNotEmpty) {
      final String photoName = photos[0]['name'] ?? '';
      if (photoName.isNotEmpty) {
        imageUrl = 'https://places.googleapis.com/v1/$photoName/media?maxWidthPx=800&key=$_apiKey';
      }
    }

    // Opening Hours / bestTime
    final bool openNow = json['currentOpeningHours']?['openNow'] ?? true;
    final String bestTime = openNow ? 'Open Now' : 'Evening, 6:00 PM';

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
      rating: rating,
    );
  }

  String _deriveNeighborhood(String address) {
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
    for (final area in areas) {
      if (address.toLowerCase().contains(area.toLowerCase())) {
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
    } else if (type == 'park' || type == 'garden' || type == 'tourist_attraction') {
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
