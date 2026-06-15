import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/spot.dart';
import 'geoapify_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  
  // Track previous proximity state to identify *new* entries
  List<Spot> _previousSpots = [];
  StreamSubscription<Position>? _proximitySubscription;

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
    );
  }

  Future<void> showProximityAlert(Spot spot) async {
    await _plugin.show(
      spot.id.hashCode,
      '📍 ${spot.name} nearby',
      '${spot.distance?.round() ?? 0}m away · Perfect for a date tonight ✨',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'proximity_channel',
          'Nearby Spots',
          channelDescription: 'Get notified when romantic date spots are nearby',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  void startProximityMonitoring(Stream<Position> positionStream) {
    _proximitySubscription?.cancel();
    final geoapifyService = GeoapifyService();

    _proximitySubscription = positionStream.listen((position) async {
      try {
        final spots = await geoapifyService.fetchNearbySpots(
          lat: position.latitude,
          lng: position.longitude,
          radius: 1000,
        );

        final closeSpots = spots.where((s) => s.distance != null && s.distance! <= 500).toList();
        final prefs = await SharedPreferences.getInstance();
        final now = DateTime.now().millisecondsSinceEpoch;

        for (final spot in closeSpots) {
          // Check if this was NOT in the previous list of close spots (newly entered)
          final wasPreviouslyClose = _previousSpots.any((prev) => prev.id == spot.id && prev.distance != null && prev.distance! <= 500);

          if (!wasPreviouslyClose) {
            final key = 'notif_time_${spot.id}';
            final lastNotified = prefs.getInt(key) ?? 0;
            const oneHour = 60 * 60 * 1000;

            if (now - lastNotified > oneHour) {
              await showProximityAlert(spot);
              await prefs.setInt(key, now);
            }
          }
        }

        _previousSpots = closeSpots;
      } catch (e) {
        print("Proximity monitoring fetch error: $e");
      }
    });
  }

  void stopProximityMonitoring() {
    _proximitySubscription?.cancel();
    _proximitySubscription = null;
  }
}
