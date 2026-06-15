class Review {
  final String id;
  final String spotId;
  final String? userId;
  final double rating;
  final String reviewText;
  final DateTime visitedOn;

  Review({
    required this.id,
    required this.spotId,
    this.userId,
    required this.rating,
    required this.reviewText,
    required this.visitedOn,
  });

  String get coupleLabel => 'Couple ♥';
  String get vibeRating => '⭐ ${rating.toStringAsFixed(1)}';
  String? get photoUrl => null;

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id']?.toString() ?? '',
      spotId: json['place_id']?.toString() ?? json['spot_id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : 5.0,
      reviewText: json['review_text']?.toString() ?? '',
      visitedOn: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : (json['visited_on'] != null ? DateTime.parse(json['visited_on'].toString()) : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'place_id': spotId,
      'user_id': userId,
      'rating': rating,
      'review_text': reviewText,
      'created_at': visitedOn.toIso8601String(),
    };
  }
}
