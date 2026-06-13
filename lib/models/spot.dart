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
  });

  factory Spot.fromJson(Map<String, dynamic> json) {
    return Spot(
      id: json['id'] as String,
      name: json['name'] as String,
      neighborhood: json['neighborhood'] as String,
      category: json['category'] as String,
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
      communityReviews: (json['communityReviews'] as List)
          .map((r) => CommunityReview.fromJson(r as Map<String, dynamic>))
          .toList(),
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
    };
  }
}

class CommunityReview {
  final String coupleName;
  final String review;
  final String vibeRating;
  final String visitedOn;

  CommunityReview({
    required this.coupleName,
    required this.review,
    required this.vibeRating,
    required this.visitedOn,
  });

  factory CommunityReview.fromJson(Map<String, dynamic> json) {
    return CommunityReview(
      coupleName: json['coupleName'] as String,
      review: json['review'] as String,
      vibeRating: json['vibeRating'] as String,
      visitedOn: json['visitedOn'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'coupleName': coupleName,
      'review': review,
      'vibeRating': vibeRating,
      'visitedOn': visitedOn,
    };
  }
}
