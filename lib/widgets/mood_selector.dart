import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MoodSelector extends StatelessWidget {
  final String selectedMood;
  final ValueChanged<String> onMoodChanged;

  static const List<Map<String, String>> moods = [
    {"name": "Low-key", "icon": "☕"},
    {"name": "Spontaneous", "icon": "⚡"},
    {"name": "Special Night", "icon": "✨"},
    {"name": "Adventure", "icon": "🧗"},
  ];

  const MoodSelector({
    Key? key,
    required this.selectedMood,
    required this.onMoodChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: moods.length,
        itemBuilder: (context, index) {
          final mood = moods[index];
          final name = mood['name']!;
          final icon = mood['icon']!;
          final isSelected = name == selectedMood;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              avatar: Text(icon, style: const TextStyle(fontSize: 14)),
              label: Text(
                name,
                style: TextStyle(
                  color: isSelected
                      ? (isDark ? AppTheme.primaryNavy : Colors.white)
                      : (isDark ? Colors.white70 : AppTheme.primaryNavy),
                  fontWeight: FontWeight.w600,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  onMoodChanged(name);
                }
              },
              selectedColor: AppTheme.coralAccent,
              backgroundColor: isDark ? const Color(0xff162536) : Colors.white,
              checkmarkColor: isDark ? AppTheme.primaryNavy : Colors.white,
              side: BorderSide(
                color: isSelected ? AppTheme.coralAccent : AppTheme.softGrey.withOpacity(0.3),
                width: 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          );
        },
      ),
    );
  }
}
