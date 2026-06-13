import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import '../models/spot.dart';
import '../models/date_entry.dart';
import '../models/review.dart';
import 'preferences_service.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final supabase = Supabase.instance.client;

  String get uid => fb_auth.FirebaseAuth.instance.currentUser?.uid ?? '';

  // Upsert profile on login
  Future<void> upsertProfile({required String name, List<String>? vibes, int? budget, String? coupleCode}) async {
    if (uid.isEmpty) return;
    final code = coupleCode ?? uid.substring(0, 6).toUpperCase();
    await supabase.from('profiles').upsert({
      'id': uid,
      'partner1_name': name,
      'vibe_prefs': vibes ?? [],
      'budget_pref': budget ?? 2,
      'couple_code': code,
    });
  }

  // Save visited spot (replaces Hive for history)
  Future<void> saveSpot(Spot spot, {int rating = 5, String note = ''}) async {
    if (uid.isEmpty) return;
    await supabase.from('saved_spots').insert({
      'user_id': uid,
      'spot_id': spot.id,
      'spot_name': spot.name,
      'spot_image_url': spot.imageUrl,
      'visited_on': DateTime.now().toIso8601String().split('T').first,
      'rating': rating,
      'note': note,
    });
  }

  // Save custom spot
  Future<void> saveCustomSpot({
    required String spotId,
    required String spotName,
    required String imageUrl,
    required DateTime visitedOn,
    required int rating,
    required String note,
  }) async {
    if (uid.isEmpty) return;
    await supabase.from('saved_spots').insert({
      'user_id': uid,
      'spot_id': spotId,
      'spot_name': spotName,
      'spot_image_url': imageUrl,
      'visited_on': visitedOn.toIso8601String().split('T').first,
      'rating': rating,
      'note': note,
    });
  }

  // Delete spot from history
  Future<void> deleteSpotFromHistory(String spotId, DateTime visitedOn) async {
    if (uid.isEmpty) return;
    await supabase
        .from('saved_spots')
        .delete()
        .eq('user_id', uid)
        .eq('spot_id', spotId)
        .eq('visited_on', visitedOn.toIso8601String().split('T').first);
  }

  // Fetch history
  Future<List<DateEntry>> fetchHistory() async {
    if (uid.isEmpty) return [];
    try {
      final response = await supabase
          .from('saved_spots')
          .select()
          .eq('user_id', uid)
          .order('visited_on', ascending: false);

      return response.map<DateEntry>((row) {
        return DateEntry(
          spotId: row['spot_id']?.toString() ?? '',
          spotName: row['spot_name']?.toString() ?? '',
          imageUrl: row['spot_image_url']?.toString() ?? '',
          visitedOn: row['visited_on'] != null
              ? DateTime.parse(row['visited_on'].toString())
              : DateTime.now(),
          rating: row['rating'] as int? ?? 5,
          note: row['note']?.toString() ?? '',
        );
      }).toList();
    } catch (e) {
      print('Error fetching history: $e');
      return [];
    }
  }

  // Submit a review
  Future<void> submitReview({
    required String spotId,
    required String reviewText,
    required String vibeRating,
    String? photoUrl,
  }) async {
    if (uid.isEmpty) return;
    final partner1Name = PreferencesService().partner1Name;
    final coupleLabel = partner1Name.isNotEmpty ? '$partner1Name ♥' : 'User ♥';

    await supabase.from('reviews').insert({
      'spot_id': spotId,
      'user_id': uid,
      'couple_label': coupleLabel,
      'review_text': reviewText,
      'vibe_rating': vibeRating,
      'photo_url': photoUrl,
      'visited_on': DateTime.now().toIso8601String().split('T').first,
    });
  }

  // Fetch reviews for a spot
  Future<List<Review>> fetchReviews(String spotId) async {
    try {
      final response = await supabase
          .from('reviews')
          .select()
          .eq('spot_id', spotId)
          .order('created_at', ascending: false);

      return response.map<Review>((row) => Review.fromJson(row)).toList();
    } catch (e) {
      print('Error fetching reviews: $e');
      return [];
    }
  }

  // Upload review photo to Supabase Storage
  Future<String> uploadReviewPhoto(File photo) async {
    if (uid.isEmpty) return '';
    try {
      final fileName = '${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await supabase.storage.from('review-photos').upload(
            fileName,
            photo,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );
      final String publicUrl =
          supabase.storage.from('review-photos').getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      print('Error uploading photo: $e');
      return '';
    }
  }

  // Save swipe decision
  Future<void> saveSwipe(String spotId, String decision) async {
    if (uid.isEmpty) return;
    await supabase.from('swipe_decisions').upsert({
      'user_id': uid,
      'spot_id': spotId,
      'decision': decision,
    });
  }

  // Listen for mutual swipe match in real-time
  Stream<bool> listenForMatch(String spotId) {
    final linkedUid = PreferencesService().linkedPartnerUid;
    if (linkedUid.isEmpty) return const Stream.empty();

    // Set up real-time stream for partner's decisions, and filter spot client-side
    return supabase
        .from('swipe_decisions')
        .stream(primaryKey: ['user_id', 'spot_id'])
        .eq('user_id', linkedUid)
        .map((data) {
          if (data.isEmpty) return false;
          final matchRow = data.firstWhere(
            (row) => row['spot_id'] == spotId,
            orElse: () => <String, dynamic>{},
          );
          return matchRow['decision'] == 'yes';
        });
  }

  // Query profile by couple code (returns partner's uid)
  Future<String?> getPartnerUidByCode(String code) async {
    try {
      final response = await supabase
          .from('profiles')
          .select('id')
          .eq('couple_code', code.trim().toUpperCase())
          .maybeSingle();
      if (response != null) {
        return response['id']?.toString();
      }
      return null;
    } catch (e) {
      print('Error checking code: $e');
      return null;
    }
  }

  // Fetch all spot IDs the user has already swiped on
  Future<List<String>> fetchSwipedSpotIds() async {
    if (uid.isEmpty) return [];
    try {
      final response = await supabase
          .from('swipe_decisions')
          .select('spot_id')
          .eq('user_id', uid);
      return response.map<String>((row) => row['spot_id'].toString()).toList();
    } catch (e) {
      print('Error fetching swiped spot IDs: $e');
      return [];
    }
  }
}
