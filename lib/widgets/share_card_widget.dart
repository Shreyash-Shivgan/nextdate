import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/spot.dart';
import '../theme/app_theme.dart';

class ShareCardWidget extends StatefulWidget {
  final Spot spot;
  final String partner1;

  const ShareCardWidget({
    Key? key,
    required this.spot,
    required this.partner1,
  }) : super(key: key);

  @override
  State<ShareCardWidget> createState() => _ShareCardWidgetState();
}

class _ShareCardWidgetState extends State<ShareCardWidget> {
  final GlobalKey _globalKey = GlobalKey();
  bool _isSaving = false;

  Future<Uint8List?> _capturePng() async {
    try {
      final RenderRepaintBoundary boundary =
          _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print("Error capturing PNG: $e");
      return null;
    }
  }

  Future<void> _saveToGallery() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final bytes = await _capturePng();
      if (bytes != null) {
        await SaverGallery.saveImage(
          bytes,
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

  String _buildShareMessage() {
    return "Hey! 🗓️ Our next date is planned ✨\n\n"
        "📍 ${widget.spot.name}, ${widget.spot.neighborhood}\n"
        "💰 Budget for two: ₹${widget.spot.avgSpend}\n"
        "🕐 Best time: ${widget.spot.bestTime}\n"
        "🗺️ https://www.google.com/maps/dir/?api=1&destination=${widget.spot.lat},${widget.spot.lng}&travelmode=transit\n\n"
        "${widget.spot.aiBlurb}\n\n"
        "Planned with NextDate 💛";
  }

  Future<void> _shareToWhatsApp() async {
    final message = _buildShareMessage();
    final url = Uri.parse("whatsapp://send?text=${Uri.encodeComponent(message)}");
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        final webUrl = Uri.parse("https://wa.me/?text=${Uri.encodeComponent(message)}");
        if (await canLaunchUrl(webUrl)) {
          await launchUrl(webUrl);
        } else {
          throw 'Could not launch WhatsApp';
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to share on WhatsApp: $e"),
            backgroundColor: AppTheme.coralAccent,
          ),
        );
      }
    }
  }

  Future<void> _shareToInstagram() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final bytes = await _capturePng();
      if (bytes != null) {
        await SaverGallery.saveImage(
          bytes,
          quality: 100,
          name: "nextdate_${widget.spot.id}_${DateTime.now().millisecondsSinceEpoch}",
          androidRelativePath: "Pictures/NextDate",
          androidExistNotSave: false,
        );

        final url = Uri.parse("instagram://story-camera");
        if (await canLaunchUrl(url)) {
          await launchUrl(url);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Saved to gallery! (Instagram app not installed to open camera)"),
                backgroundColor: AppTheme.primaryNavy,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to save/open Instagram: $e"),
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

  Future<void> _shareAnywhere() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final bytes = await _capturePng();
      if (bytes != null) {
        final tempDir = await getTemporaryDirectory();
        final file = await File('${tempDir.path}/nextdate_${widget.spot.id}.png').create();
        await file.writeAsBytes(bytes);

        await Share.shareXFiles(
          [XFile(file.path)],
          text: _buildShareMessage(),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to share: $e"),
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

  Widget _buildShareAction({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool useGradientIcon = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff162536) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isSaving ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                if (useGradientIcon)
                  ShaderMask(
                    shaderCallback: (bounds) => const RadialGradient(
                      center: Alignment.bottomLeft,
                      radius: 0.85,
                      colors: [
                        Colors.yellow,
                        Colors.orange,
                        Colors.red,
                        Colors.pink,
                        Colors.purple,
                      ],
                      tileMode: TileMode.clamp,
                    ).createShader(bounds),
                    child: Icon(icon, color: Colors.white, size: 28),
                  )
                else
                  Icon(icon, color: iconColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: AppTheme.softGrey,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final coupleLabel = "${widget.partner1}'s Next Date ✨";

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

          // Card preview
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
                      // Background Image
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
                                Colors.black.withOpacity(0.15),
                                Colors.black.withOpacity(0.85),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                      // Title left top (White Outfitters/Outfit font)
                      Positioned(
                        top: 24,
                        left: 24,
                        child: Text(
                          coupleLabel,
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            shadows: const [
                              Shadow(
                                blurRadius: 4,
                                color: Colors.black54,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Info block left bottom
                      Positioned(
                        left: 24,
                        right: 140,
                        bottom: 24,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.spot.name,
                              style: GoogleFonts.outfit(
                                fontSize: 28,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                shadows: const [
                                  Shadow(
                                    blurRadius: 4,
                                    color: Colors.black54,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.spot.aiBlurb,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.white70,
                                fontStyle: FontStyle.italic,
                                shadows: const [
                                  Shadow(
                                    blurRadius: 4,
                                    color: Colors.black54,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            // Row of Badges
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    widget.spot.neighborhood,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    widget.spot.bestTime,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    List.generate(widget.spot.budget, (_) => "₹").join(),
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Logo bottom-right
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

          // 2x2 Actions Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.3,
            children: [
              _buildShareAction(
                icon: Icons.download_rounded,
                iconColor: AppTheme.coralAccent,
                title: "Download PNG",
                subtitle: "Save to gallery",
                onTap: _saveToGallery,
              ),
              _buildShareAction(
                icon: Icons.chat_bubble_rounded,
                iconColor: Colors.green,
                title: "WhatsApp",
                subtitle: "Send to partner",
                onTap: _shareToWhatsApp,
              ),
              _buildShareAction(
                icon: Icons.camera_alt_rounded,
                iconColor: Colors.transparent, // handled by shader
                useGradientIcon: true,
                title: "Instagram",
                subtitle: "Open stories",
                onTap: _shareToInstagram,
              ),
              _buildShareAction(
                icon: Icons.share_rounded,
                iconColor: AppTheme.primaryNavy,
                title: "Share Anywhere",
                subtitle: "System share",
                onTap: _shareAnywhere,
              ),
            ],
          ),
          if (_isSaving) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(color: AppTheme.coralAccent),
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
