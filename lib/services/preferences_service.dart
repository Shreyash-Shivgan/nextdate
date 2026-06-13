import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  late SharedPreferences _prefs;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  // Onboarding Complete
  bool get isOnboardingComplete => _prefs.getBool('onboarding_complete') ?? false;
  Future<void> setOnboardingComplete(bool complete) async {
    await _prefs.setBool('onboarding_complete', complete);
  }

  // Partner Names
  String get partner1Name => _prefs.getString('partner1_name') ?? '';
  Future<void> setPartner1Name(String name) async {
    await _prefs.setString('partner1_name', name);
  }

  String get partner2Name => _prefs.getString('partner2_name') ?? '';
  Future<void> setPartner2Name(String name) async {
    await _prefs.setString('partner2_name', name);
  }

  // Vibe Preferences
  List<String> get vibePrefs => _prefs.getStringList('vibe_prefs') ?? [];
  Future<void> setVibePrefs(List<String> vibes) async {
    await _prefs.setStringList('vibe_prefs', vibes);
  }

  // Budget Preference (1, 2, 3)
  int get budgetPref => _prefs.getInt('budget_pref') ?? 2;
  Future<void> setBudgetPref(int budget) async {
    await _prefs.setInt('budget_pref', budget);
  }

  // Anniversary Date (ISO format)
  String get anniversaryDate => _prefs.getString('anniversary_date') ?? '';
  Future<void> setAnniversaryDate(String dateStr) async {
    await _prefs.setString('anniversary_date', dateStr);
  }

  // Disliked Spot IDs
  List<String> get dislikedSpotIds => _prefs.getStringList('disliked_spot_ids') ?? [];
  Future<void> addDislikedSpotId(String id) async {
    final list = dislikedSpotIds;
    if (!list.contains(id)) {
      list.add(id);
      await _prefs.setStringList('disliked_spot_ids', list);
    }
  }
  Future<void> clearDislikedSpots() async {
    await _prefs.remove('disliked_spot_ids');
  }

  // Swipes
  String? getSwipeP1(String spotId) => _prefs.getString('swipe_p1_$spotId');
  Future<void> setSwipeP1(String spotId, String choice) async {
    await _prefs.setString('swipe_p1_$spotId', choice);
  }

  String? getSwipeP2(String spotId) => _prefs.getString('swipe_p2_$spotId');
  Future<void> setSwipeP2(String spotId, String choice) async {
    await _prefs.setString('swipe_p2_$spotId', choice);
  }

  Future<void> clearAllSwipeData() async {
    final keys = _prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith('swipe_p1_') || key.startsWith('swipe_p2_')) {
        await _prefs.remove(key);
      }
    }
  }

  // Surprise Spot ID
  String? get surpriseSpotId => _prefs.getString('surprise_spot_id');
  Future<void> setSurpriseSpotId(String? id) async {
    if (id == null) {
      await _prefs.remove('surprise_spot_id');
    } else {
      await _prefs.setString('surprise_spot_id', id);
    }
  }

  // Theme Override ("auto", "afternoon", "evening")
  String get themeOverride => _prefs.getString('theme_override') ?? 'auto';
  Future<void> setThemeOverride(String override) async {
    await _prefs.setString('theme_override', override);
  }

  // Reset all data
  Future<void> resetAll() async {
    await _prefs.clear();
  }
}
