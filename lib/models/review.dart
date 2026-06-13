class Review {
  final String id;
  final String spotId;
  final String? userId;
  final String coupleLabel;
  final String reviewText;
  final String vibeRating;
  final String? photoUrl;
  final DateTime visitedOn;

  Review({
    required this.id,
    required this.spotId,
    this.userId,
    required this.coupleLabel,
    required this.reviewText,
    required this.vibeRating,
    this.photoUrl,
    required this.visitedOn,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id']?.toString() ?? '',
      spotId: json['spot_id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      coupleLabel: json['couple_label']?.toString() ?? 'User ♥',
      reviewText: json['review_text']?.toString() ?? '',
      vibeRating: json['vibe_rating']?.toString() ?? 'Romantic',
      photoUrl: json['photo_url']?.toString(),
      visitedOn: json['visited_on'] != null
          ? DateTime.parse(json['visited_on'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'spot_id': spotId,
      'user_id': userId,
      'couple_label': coupleLabel,
      'review_text': reviewText,
      'vibe_rating': vibeRating,
      'photo_url': photoUrl,
      'visited_on': visitedOn.toIso8601String().split('T').first,
    };
  }
}
