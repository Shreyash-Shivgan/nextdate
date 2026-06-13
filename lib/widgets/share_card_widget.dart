import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:intl/intl.dart';
import '../models/spot.dart';
import '../theme/app_theme.dart';

class ShareCardWidget extends StatefulWidget {
  final Spot spot;
  final String partner1;
  final String partner2;

  const ShareCardWidget({
    Key? key,
    required this.spot,
    required this.partner1,
    required this.partner2,
  }) : super(key: key);

  @override
  State<ShareCardWidget> createState() => _ShareCardWidgetState();
}

class _ShareCardWidgetState extends State<ShareCardWidget> {
  final GlobalKey _globalKey = GlobalKey();
  bool _isSaving = false;

  Future<void> _saveToGallery() async {
    setState(() {
      _isSaving = true;
    });

    try {
      // Find the repaint boundary
      final RenderRepaintBoundary boundary =
          _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      
      // Capture image
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        final Uint8List pngBytes = byteData.buffer.asUint8List();
        
        // Save to gallery
        final result = await SaverGallery.saveImage(
          pngBytes,
          quality: 100,
          name: "nextdate_${widget.spot.id}_${DateTime.now().millisecondsSinceEpoch}",
          androidRelativePath: "Pictures/NextDate",
          androidExistNotSave: false,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Saved to gallery ✨"),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception("Failed to convert image bytes");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to save image: $e"),
            backgroundColor: AppTheme.coralAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final todayStr = DateFormat('MMMM d, yyyy').format(DateTime.now());
    final coupleNames = "${widget.partner1} & ${widget.partner2}";

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.softGrey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Share Your Next Date",
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(height: 16),
          // Scrollable wrapper for fixed-size card
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: RepaintBoundary(
              key: _globalKey,
              child: Container(
                width: 600,
                height: 340,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      // Full-bleed background image
                      CachedNetworkImage(
                        imageUrl: widget.spot.imageUrl,
                        width: 600,
                        height: 340,
                        fit: BoxFit.cover,
                      ),
                      // Dark gradient overlay
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withOpacity(0.2),
                                Colors.black.withOpacity(0.85),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                      // Couple Names (Outfit 20sp white)
                      Positioned(
                        top: 24,
                        left: 24,
                        child: Text(
                          coupleNames,
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            shadows: [
                              const Shadow(
                                blurRadius: 4,
                                color: Colors.black54,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Spot Name (Outfit 28sp white bold)
                      Positioned(
                        left: 24,
                        right: 24,
                        bottom: 64,
                        child: Text(
                          widget.spot.name,
                          style: GoogleFonts.outfit(
                            fontSize: 28,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              const Shadow(
                                blurRadius: 4,
                                color: Colors.black54,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Visit Date (Inter 14sp white)
                      Positioned(
                        left: 24,
                        bottom: 24,
                        child: Text(
                          "Planned for: $todayStr",
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      // NextDate logo text (bottom-right in coral)
                      Positioned(
                        right: 24,
                        bottom: 24,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              "💞 ",
                              style: TextStyle(fontSize: 14),
                            ),
                            Text(
                              "NextDate",
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                color: AppTheme.coralAccent,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Download button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.download, color: Colors.white),
              label: Text(_isSaving ? "Saving..." : "Download as PNG"),
              onPressed: _isSaving ? null : _saveToGallery,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.coralAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
