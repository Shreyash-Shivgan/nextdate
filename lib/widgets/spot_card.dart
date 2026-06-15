import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/spot.dart';
import '../screens/spot_detail/spot_detail_screen.dart';
import '../theme/app_theme.dart';

class SpotCard extends StatelessWidget {
  final Spot spot;

  const SpotCard({Key? key, required this.spot}) : super(key: key);

  String _getDurationText(String category) {
    switch (category) {
      case 'Cafe':
        return '60 mins';
      case 'Restaurant':
        return '90 mins';
      case 'Bar':
        return '120 mins';
      case 'Park':
        return '90 mins';
      case 'Museum':
        return '120 mins';
      case 'Attraction':
        return '60 mins';
      default:
        return '90 mins';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Date Score (50-100 scale)
    final double dateScoreVal = spot.dateScore ?? 75;
    final String dateScoreStr = '${dateScoreVal.round()} Match';

    // Format distance text — fix "Nearby away" bug
    final String distanceText;
    final String distanceBadgeText;
    if (spot.distance != null && spot.distance! > 0) {
      if (spot.distance! < 1000) {
        distanceText = '${spot.distance!.round()}m away';
      } else {
        distanceText = '${(spot.distance! / 1000).toStringAsFixed(1)}km away';
      }
      distanceBadgeText = '📍 $distanceText';
    } else {
      distanceText = 'Nearby';
      distanceBadgeText = '📍 Nearby';
    }

    final String budgetStr = List.generate(spot.budget, (_) => '₹').join();
    final String duration = _getDurationText(spot.category);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff162536) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xff22354a) : const Color(0xfff0f2f5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SpotDetailScreen(spot: spot),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Immersive Image Section
              Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: spot.imageUrl,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 220,
                      color: isDark ? const Color(0xff0e1823) : Colors.grey[100],
                      child: const Center(
                        child: CircularProgressIndicator(color: AppTheme.coralAccent),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 220,
                      color: isDark ? const Color(0xff0e1823) : Colors.grey[200],
                      child: const Icon(Icons.broken_image, color: AppTheme.softGrey),
                    ),
                  ),
                  // Gradient Overlay on Image for better text visibility
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(0.4),
                            Colors.black.withOpacity(0.0),
                            Colors.black.withOpacity(0.6),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Top Row: Date Score & Distance Badges
                  Positioned(
                    top: 14,
                    left: 14,
                    right: 14,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Date Score Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.coralAccent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.coralAccent.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('⭐ ', style: TextStyle(fontSize: 10)),
                              Text(
                                dateScoreStr,
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Distance Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            distanceBadgeText,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Bottom Row: Name and Indoor/Outdoor Badge overlay
                  Positioned(
                    bottom: 12,
                    left: 14,
                    right: 14,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            spot.name,
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: spot.indoor
                                ? Colors.teal.withOpacity(0.85)
                                : AppTheme.warmGold.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            spot.indoor ? "Indoor" : "Outdoor",
                            style: GoogleFonts.inter(
                              color: spot.indoor ? Colors.white : AppTheme.primaryNavy,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Content Details Section
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          spot.neighborhood.toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.coralAccent,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "•",
                          style: TextStyle(color: isDark ? Colors.white30 : Colors.black26),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getDisplayCategoryName(spot.category),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppTheme.softGrey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Playful copywriting blurb
                    Text(
                      spot.aiBlurb,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.4,
                        color: isDark ? Colors.white70 : AppTheme.primaryNavy.withOpacity(0.8),
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 14),
                    // Quick vibe tags & stats row
                    Row(
                      children: [
                        // Vibes mapping
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: spot.vibe.map((v) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: isDark
                                      ? const Color(0xff1f3045)
                                      : const Color(0xfff5f7fa),
                                ),
                                child: Text(
                                  v,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : AppTheme.primaryNavy.withOpacity(0.7),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // stats (duration & budget)
                        Row(
                          children: [
                            const Icon(Icons.access_time_filled, size: 12, color: AppTheme.softGrey),
                            const SizedBox(width: 3),
                            Text(
                              duration,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.softGrey,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              "💸 $budgetStr",
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Display name mapper for categories (Gen Z!)
  String _getDisplayCategoryName(String category) {
    switch (category) {
      case 'Restaurant':
        return 'Food Dates 🍝';
      case 'Cafe':
        return 'Coffee Runs ☕';
      case 'Bar':
        return 'Night Out 🍸';
      case 'Park':
        return 'Touch Grass 🌳';
      case 'Museum':
        return 'Culture Mode 🏛️';
      case 'Attraction':
        return 'Main Character Moments ✨';
      default:
        return 'Vibe Spot ✨';
    }
  }
}
