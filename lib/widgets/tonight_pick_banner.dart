import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/spot.dart';
import '../screens/spot_detail/spot_detail_screen.dart';
import '../theme/app_theme.dart';

class TonightPickBanner extends StatelessWidget {
  final Spot spot;

  const TonightPickBanner({Key? key, required this.spot}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Calculate Date Score dynamically if not preset
    final double ratingScore = spot.rating ?? (4.5 + (spot.name.hashCode.abs() % 5) * 0.1);
    final String dateScoreStr = ratingScore.toStringAsFixed(1);

    // Format distance text
    final String distanceText = spot.distance != null
        ? (spot.distance! < 1000
            ? "${spot.distance!.round()} m"
            : "${(spot.distance! / 1000).toStringAsFixed(1)} km")
        : "Nearby";

    final String budgetStr = List.generate(spot.budget, (_) => '₹').join();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryNavy.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Background Image
            CachedNetworkImage(
              imageUrl: spot.imageUrl,
              height: 240,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                height: 240,
                color: AppTheme.softGrey.withOpacity(0.1),
                child: const Center(
                  child: CircularProgressIndicator(color: AppTheme.coralAccent),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                height: 240,
                color: AppTheme.softGrey.withOpacity(0.2),
                child: const Icon(Icons.broken_image, color: AppTheme.softGrey),
              ),
            ),
            // Gradient Overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.2),
                      Colors.black.withOpacity(0.4),
                      Colors.black.withOpacity(0.9),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),
            // Badge tag
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.coralAccent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.coralAccent.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.flash_on, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      "TONIGHT'S MOVE 🔥",
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Info Column at bottom
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spot.name,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "⭐ $dateScoreStr Date Score",
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "•",
                        style: TextStyle(color: Colors.white.withOpacity(0.5)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "📍 $distanceText away",
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "•",
                        style: TextStyle(color: Colors.white.withOpacity(0.5)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "💸 $budgetStr",
                        style: GoogleFonts.inter(
                          color: AppTheme.warmGold,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Recommendation reason / Blurb
                  Text(
                    spot.aiBlurb,
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Splash ripple effect overlay
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SpotDetailScreen(spot: spot),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
