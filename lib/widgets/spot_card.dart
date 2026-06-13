import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/spot.dart';
import '../screens/spot_detail/spot_detail_screen.dart';
import '../theme/app_theme.dart';

class SpotCard extends StatelessWidget {
  final Spot spot;

  const SpotCard({Key? key, required this.spot}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 8,
      shadowColor: AppTheme.primaryNavy.withOpacity(0.08),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SpotDetailScreen(spot: spot),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Section
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: spot.imageUrl,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 180,
                      color: AppTheme.softGrey.withOpacity(0.1),
                      child: const Center(
                        child: CircularProgressIndicator(color: AppTheme.coralAccent),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 180,
                      color: AppTheme.softGrey.withOpacity(0.2),
                      child: const Icon(Icons.broken_image, color: AppTheme.softGrey),
                    ),
                  ),
                  // Category Badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryNavy.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        spot.category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Indoor/Outdoor Badge
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: spot.indoor ? AppTheme.coralAccent : AppTheme.warmGold,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        spot.indoor ? "Cozy Indoor 🏠" : "Open Air 🍃",
                        style: TextStyle(
                          color: spot.indoor ? Colors.white : AppTheme.primaryNavy,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Text Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          spot.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Budget Badge
                      Row(
                        children: List.generate(3, (index) {
                          return Text(
                            "₹",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: index < spot.budget
                                  ? AppTheme.warmGold
                                  : AppTheme.softGrey.withOpacity(0.4),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: AppTheme.coralAccent),
                      const SizedBox(width: 4),
                      Text(
                        spot.neighborhood,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.white70 : AppTheme.primaryNavy.withOpacity(0.7),
                        ),
                      ),
                      const Spacer(),
                      // Distance Placeholder
                      Text(
                        "📍 Nearby (~1.5 km)",
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: AppTheme.softGrey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Vibe Chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: spot.vibe.map((v) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.coralAccent.withOpacity(0.5),
                            width: 1,
                          ),
                          color: AppTheme.coralAccent.withOpacity(0.05),
                        ),
                        child: Text(
                          v,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.coralAccent,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
