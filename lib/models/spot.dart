class Spot {
  final String id;
  final String name;
  final String neighborhood;
  final String category;
  final List<String> vibe;
  final int budget;
  final int avgSpend;
  final bool indoor;
  final String imageUrl;
  final String aiBlurb;
  final List<String> activities;
  final String bestTime;
  final List<String> checklist;
  final double lat;
  final double lng;
  final String? comboSpotId;
  final List<CommunityReview> communityReviews;
  final double? rating;
  double? distance;
  double? dateScore;

  Spot({
    required this.id,
    required this.name,
    required this.neighborhood,
    required this.category,
    required this.vibe,
    required this.budget,
    required this.avgSpend,
    required this.indoor,
    required this.imageUrl,
    required this.aiBlurb,
    required this.activities,
    required this.bestTime,
    required this.checklist,
    required this.lat,
    required this.lng,
    this.comboSpotId,
    required this.communityReviews,
    this.rating,
    this.distance,
    this.dateScore,
  });

  static String normalizeCategory(String cat) {
    final lower = cat.toLowerCase().replaceAll('é', 'e').trim();
    if (lower.contains('restaurant')) return 'Restaurant';
    if (lower.contains('cafe')) return 'Cafe';
    if (lower.contains('bar') || lower.contains('pub') || lower.contains('lounge')) return 'Bar';
    if (lower.contains('park') || lower.contains('garden')) return 'Park';
    if (lower.contains('attraction') || lower.contains('tourism')) return 'Attraction';
    if (lower.contains('museum')) return 'Museum';
    return 'Activity';
  }

  factory Spot.fromJson(Map<String, dynamic> json) {
    return Spot(
      id: json['id'] as String,
      name: json['name'] as String,
      neighborhood: json['neighborhood'] as String,
      category: normalizeCategory(json['category'] as String),
      vibe: List<String>.from(json['vibe'] as List),
      budget: json['budget'] as int,
      avgSpend: json['avgSpend'] as int,
      indoor: json['indoor'] as bool,
      imageUrl: json['imageUrl'] as String,
      aiBlurb: json['aiBlurb'] as String,
      activities: List<String>.from(json['activities'] as List),
      bestTime: json['bestTime'] as String,
      checklist: List<String>.from(json['checklist'] as List),
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      comboSpotId: json['comboSpotId'] as String?,
      communityReviews: json['communityReviews'] != null
          ? (json['communityReviews'] as List)
              .map((r) => CommunityReview.fromJson(r as Map<String, dynamic>))
              .toList()
          : [],
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : null,
      distance: json['distance'] != null ? (json['distance'] as num).toDouble() : null,
      dateScore: json['dateScore'] != null ? (json['dateScore'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'neighborhood': neighborhood,
      'category': category,
      'vibe': vibe,
      'budget': budget,
      'avgSpend': avgSpend,
      'indoor': indoor,
      'imageUrl': imageUrl,
      'aiBlurb': aiBlurb,
      'activities': activities,
      'bestTime': bestTime,
      'checklist': checklist,
      'lat': lat,
      'lng': lng,
      'comboSpotId': comboSpotId,
      'communityReviews': communityReviews.map((r) => r.toJson()).toList(),
      'rating': rating,
      'distance': distance,
      'dateScore': dateScore,
    };
  }

  Spot copyWith({
    String? id,
    String? name,
    String? neighborhood,
    String? category,
    List<String>? vibe,
    int? budget,
    int? avgSpend,
    bool? indoor,
    String? imageUrl,
    String? aiBlurb,
    List<String>? activities,
    String? bestTime,
    List<String>? checklist,
    double? lat,
    double? lng,
    String? comboSpotId,
    List<CommunityReview>? communityReviews,
    double? rating,
    double? distance,
    double? dateScore,
  }) {
    return Spot(
      id: id ?? this.id,
      name: name ?? this.name,
      neighborhood: neighborhood ?? this.neighborhood,
      category: category ?? this.category,
      vibe: vibe ?? this.vibe,
      budget: budget ?? this.budget,
      avgSpend: avgSpend ?? this.avgSpend,
      indoor: indoor ?? this.indoor,
      imageUrl: imageUrl ?? this.imageUrl,
      aiBlurb: aiBlurb ?? this.aiBlurb,
      activities: activities ?? this.activities,
      bestTime: bestTime ?? this.bestTime,
      checklist: checklist ?? this.checklist,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      comboSpotId: comboSpotId ?? this.comboSpotId,
      communityReviews: communityReviews ?? this.communityReviews,
      rating: rating ?? this.rating,
      distance: distance ?? this.distance,
      dateScore: dateScore ?? this.dateScore,
    );
  }
}

class CommunityReview {
  final String coupleName;
  final String review;
  final String vibeRating;
  final String visitedOn;
  final String? photoUrl;

  CommunityReview({
    required this.coupleName,
    required this.review,
    required this.vibeRating,
    required this.visitedOn,
    this.photoUrl,
  });

  factory CommunityReview.fromJson(Map<String, dynamic> json) {
    return CommunityReview(
      coupleName: json['coupleName'] as String,
      review: json['review'] as String,
      vibeRating: json['vibeRating'] as String,
      visitedOn: json['visitedOn'] as String,
      photoUrl: json['photoUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'coupleName': coupleName,
      'review': review,
      'vibeRating': vibeRating,
      'visitedOn': visitedOn,
      'photoUrl': photoUrl,
    };
  }
}
