import 'dart:convert';
import 'package:http/http.dart' as http;

enum WeatherStatus { clear, rainy }

class WeatherService {
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();

  Future<WeatherStatus> fetchWeather() async {
    try {
      final response = await http.get(Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=19.076&longitude=72.877&current_weather=true'
      ));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final code = data['current_weather']['weathercode'] as num;
        return (code >= 51 && code <= 82) ? WeatherStatus.rainy : WeatherStatus.clear;
      }
    } catch (_) {}
    
    // Fallback: months 6-9 (June-September) = Rainy, else Clear
    final month = DateTime.now().month;
    return (month >= 6 && month <= 9) ? WeatherStatus.rainy : WeatherStatus.clear;
  }
}
