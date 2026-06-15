import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/spot.dart';
import '../theme/app_theme.dart';
import '../screens/spot_detail/spot_detail_screen.dart';

/// Compact card designed for horizontal rails (~70% screen width, ~200px height).
/// Shows venue image, name, Date Score, distance, budget, and AI blurb.
class HorizontalSpotCard extends StatelessWidget {
  final Spot spot;

  const HorizontalSpotCard({Key? key, required this.spot}) : super(key: key);

  String _formatDistance() {
    if (spot.distance == null) return 'Nearby';
    if (spot.distance! < 1000) return '${spot.distance!.round()}m';
    return '${(spot.distance! / 1000).toStringAsFixed(1)}km';
  }

  String _formatBudget() {
    if (spot.budget <= 1) return '₹';
    if (spot.budget == 2) return '₹₹';
    return '₹₹₹';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth * 0.7;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SpotDetailScreen(spot: spot),
          ),
        );
      },
      child: Container(
        width: cardWidth,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.4 : 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Background image
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: spot.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: isDark ? const Color(0xff162536) : Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.coralAccent,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: isDark ? const Color(0xff162536) : Colors.grey[300],
                    child: const Icon(Icons.image_not_supported, color: AppTheme.softGrey, size: 40),
                  ),
                ),
              ),

              // Gradient overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withOpacity(0.3),
                        Colors.black.withOpacity(0.85),
                      ],
                      stops: const [0.0, 0.3, 0.6, 1.0],
                    ),
                  ),
                ),
              ),

              // Date Score badge (top right)
              if (spot.dateScore != null)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _getScoreColor(spot.dateScore!).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: _getScoreColor(spot.dateScore!).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('⭐ ', style: TextStyle(fontSize: 10)),
                        Text(
                          '${spot.dateScore!.round()} Match',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Content (bottom)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Venue name
                      Text(
                        spot.name,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Distance + Budget + Category row
                      Row(
                        children: [
                          Text(
                            '📍 ${_formatDistance()}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.85),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '💸 ${_formatBudget()}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.85),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              spot.category,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // AI Blurb (1 line)
                      Text(
                        spot.aiBlurb,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Colors.white.withOpacity(0.7),
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 85) return const Color(0xff10b981); // Green for great matches
    if (score >= 70) return const Color(0xff3b82f6); // Blue for good matches
    if (score >= 60) return const Color(0xfff59e0b); // Amber for decent
    return const Color(0xff6b7280); // Grey for lower scores
  }
}
