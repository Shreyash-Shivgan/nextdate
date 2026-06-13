class DateEntry {
  final String spotId;
  final String spotName;
  final String imageUrl;
  final DateTime visitedOn;
  final int rating;
  final String note;

  DateEntry({
    required this.spotId,
    required this.spotName,
    required this.imageUrl,
    required this.visitedOn,
    required this.rating,
    required this.note,
  });
}
