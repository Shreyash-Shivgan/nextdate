import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/spot.dart';
import '../../models/date_entry.dart';
import '../../data/spots_repository.dart';
import '../../services/preferences_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/share_card_widget.dart';

class SpotDetailScreen extends StatefulWidget {
  final Spot spot;

  const SpotDetailScreen({Key? key, required this.spot}) : super(key: key);

  @override
  State<SpotDetailScreen> createState() => _SpotDetailScreenState();
}

class _SpotDetailScreenState extends State<SpotDetailScreen> {
  final PreferencesService _prefs = PreferencesService();
  final SpotsRepository _repository = SpotsRepository();
  
  // Split Bill Calculator state
  final TextEditingController _billController = TextEditingController();
  double _perPersonAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _prefs.init();
    _billController.text = widget.spot.avgSpend.toString();
    _calculateSplitBill(widget.spot.avgSpend.toDouble());
  }

  @override
  void dispose() {
    _billController.dispose();
    super.dispose();
  }

  void _calculateSplitBill(double total) {
    setState(() {
      _perPersonAmount = total / 2;
    });
  }

  void _launchDirections() async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${widget.spot.lat},${widget.spot.lng}&travelmode=transit'
    );
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch Maps';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Could not launch navigation: $e"),
            backgroundColor: AppTheme.coralAccent,
          ),
        );
      }
    }
  }

  Future<void> _neverShowAgain() async {
    await _prefs.addDislikedSpotId(widget.spot.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Got it — we won't show '${widget.spot.name}' again 🙅"),
          backgroundColor: AppTheme.primaryNavy,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _saveToHistory() async {
    try {
      final box = Hive.box<DateEntry>('date_history');
      final entry = DateEntry(
        spotId: widget.spot.id,
        spotName: widget.spot.name,
        imageUrl: widget.spot.imageUrl,
        visitedOn: DateTime.now(),
        rating: 5,
        note: "Logged from spot detail page.",
      );
      await box.add(entry);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Added to your date history 💛"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to log history: $e"),
            backgroundColor: AppTheme.coralAccent,
          ),
        );
      }
    }
  }

  void _openShareModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final p1 = _prefs.partner1Name.isNotEmpty ? _prefs.partner1Name : "Partner 1";
        final p2 = _prefs.partner2Name.isNotEmpty ? _prefs.partner2Name : "Partner 2";
        return ShareCardWidget(
          spot: widget.spot,
          partner1: p1,
          partner2: p2,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Fetch combo spot if set
    final Spot? comboSpot = _repository.getComboSpot(widget.spot.comboSpotId);
    
    // Fetch neighbors
    final List<Spot> neighbors = _repository.getSpotsByNeighborhood(widget.spot.neighborhood, excludeId: widget.spot.id);

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Image Header
            Stack(
              children: [
                Hero(
                  tag: 'spot-img-${widget.spot.id}',
                  child: CachedNetworkImage(
                    imageUrl: widget.spot.imageUrl,
                    height: 240,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                // Back Button Overlaid
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ],
            ),

            // Spot Title & Neighborhood
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.spot.name,
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.displayLarge?.color,
                          ),
                        ),
                      ),
                      // Budget
                      Row(
                        children: List.generate(3, (index) {
                          return Text(
                            "₹",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: index < widget.spot.budget ? AppTheme.warmGold : AppTheme.softGrey.withOpacity(0.3),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${widget.spot.neighborhood} • ${widget.spot.category}",
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppTheme.softGrey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Vibe Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: widget.spot.vibe.map((v) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.coralAccent.withOpacity(0.7)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          v,
                          style: GoogleFonts.inter(
                            fontSize: 12,
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

            const Divider(height: 32, indent: 20, endIndent: 20),

            // Info Card Row (Best time, Indoor/Outdoor, Avg spend)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(context, Icons.access_time, "Best Time", widget.spot.bestTime),
                  ),
                  Expanded(
                    child: _buildInfoItem(context, widget.spot.indoor ? Icons.home : Icons.wb_sunny_outlined, "Setting", widget.spot.indoor ? "Cozy Indoor" : "Open Air"),
                  ),
                  Expanded(
                    child: _buildInfoItem(context, Icons.currency_rupee, "Avg Spend", "₹${widget.spot.avgSpend} for 2"),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // AI Blurb Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xff162536) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: const Border(
                    left: BorderSide(color: AppTheme.coralAccent, width: 4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Why this works for a date...",
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppTheme.coralAccent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.spot.aiBlurb,
                      style: GoogleFonts.outfit(
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Activities Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Things to Do",
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...widget.spot.activities.map((activity) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 4.0),
                            child: Icon(Icons.circle, size: 8, color: AppTheme.coralAccent),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              activity,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Pre-date Checklist
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Pre-Date Checklist",
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...widget.spot.checklist.map((item) {
                    return CheckboxListTile(
                      value: false,
                      onChanged: (_) {},
                      title: Text(item, style: theme.textTheme.bodyMedium),
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: AppTheme.coralAccent,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    );
                  }).toList(),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Split Bill Calculator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: isDark ? const Color(0xff162536) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Split Bill Calculator",
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _billController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                prefixText: "₹ ",
                                labelText: "Total Bill Amount",
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onChanged: (value) {
                                final total = double.tryParse(value) ?? 0.0;
                                _calculateSplitBill(total);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Per person (Split 50/50):",
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            "₹${_perPersonAmount.toStringAsFixed(0)}",
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.coralAccent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Combo Route Card
            if (comboSpot != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Make it a Full Route",
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: isDark ? const Color(0xff162536) : Colors.white,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => SpotDetailScreen(spot: comboSpot)),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: comboSpot.imageUrl,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Suggested Combo Spot",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.coralAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      comboSpot.name,
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Start here, then head to ${comboSpot.name} for the full evening.",
                                      style: const TextStyle(fontSize: 11, color: AppTheme.softGrey),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.softGrey),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Neighborhood Explorer
            if (neighbors.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 20.0, bottom: 8.0),
                child: Text(
                  "More in ${widget.spot.neighborhood}",
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: neighbors.length,
                  itemBuilder: (context, index) {
                    final neighbor = neighbors[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => SpotDetailScreen(spot: neighbor)),
                        );
                      },
                      child: Container(
                        width: 140,
                        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xff162536) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              child: CachedNetworkImage(
                                imageUrl: neighbor.imageUrl,
                                height: 80,
                                width: 140,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    neighbor.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    neighbor.category,
                                    style: const TextStyle(fontSize: 10, color: AppTheme.softGrey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Community Reviews Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "From couples who've been here",
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...widget.spot.communityReviews.map((review) {
                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      color: isDark ? const Color(0xff162536) : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  review.coupleName,
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.coralAccent.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    review.vibeRating,
                                    style: const TextStyle(fontSize: 10, color: AppTheme.coralAccent, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "\"${review.review}\"",
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Text(
                                review.visitedOn,
                                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: AppTheme.softGrey),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Bottom Action buttons (Directions, Save to History, Share Card, Never Show again)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  // Get Directions
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.navigation, color: Colors.white),
                      label: Text("Get Directions", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                      onPressed: _launchDirections,
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.coralAccent),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Save to History & Share buttons side by side
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.share, size: 18),
                          label: const Text("Share Card"),
                          onPressed: _openShareModal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle_outline, size: 18),
                          label: const Text("Log Visited"),
                          onPressed: _saveToHistory,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryNavy,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Never show again button
                  TextButton.icon(
                    icon: const Icon(Icons.block, size: 16, color: AppTheme.softGrey),
                    label: const Text(
                      "Don't Recommend This Spot Again",
                      style: TextStyle(color: AppTheme.softGrey, decoration: TextDecoration.underline),
                    ),
                    onPressed: _neverShowAgain,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(BuildContext context, IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: AppTheme.coralAccent, size: 22),
        const SizedBox(height: 6),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: AppTheme.softGrey)),
        const SizedBox(height: 2),
        Text(
          value,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ],
    );
  }
}
