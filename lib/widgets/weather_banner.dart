import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WeatherBanner extends StatelessWidget {
  final VoidCallback onDismiss;

  const WeatherBanner({Key? key, required this.onDismiss}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xffe2f0fe).withOpacity(0.9), // Light pastel rain-blue
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.shade300.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Text(
            "🌧️",
            style: TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              "It's raining in Mumbai — showing cozy indoor spots 🌧️",
              style: TextStyle(
                color: AppTheme.primaryNavy,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppTheme.primaryNavy, size: 18),
            onPressed: onDismiss,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
