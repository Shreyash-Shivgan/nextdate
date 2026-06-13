import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/spot.dart';
import '../../models/date_entry.dart';
import '../../data/spots_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../home/home_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final SpotsRepository _repository = SpotsRepository();

  @override
  void initState() {
    super.initState();
    _repository.loadSpots();
  }

  // Monday-based week identifier
  DateTime _getMonday(DateTime date) {
    final cleanDate = DateTime(date.year, date.month, date.day);
    return cleanDate.subtract(Duration(days: cleanDate.weekday - 1));
  }

  int _calculateStreak(List<DateEntry> entries) {
    if (entries.isEmpty) return 0;

    // 1. Group unique week Mondays
    final Set<DateTime> activeWeeks = {};
    for (final entry in entries) {
      activeWeeks.add(_getMonday(entry.visitedOn));
    }

    final today = DateTime.now();
    final currentMonday = _getMonday(today);
    final previousMonday = currentMonday.subtract(const Duration(days: 7));

    // Check if the streak is active (at least one entry in current week or previous week)
    if (!activeWeeks.contains(currentMonday) && !activeWeeks.contains(previousMonday)) {
      return 0;
    }

    // Start scanning backwards from the most recent active week
    int streak = 0;
    DateTime checkMonday = activeWeeks.contains(currentMonday) ? currentMonday : previousMonday;

    while (activeWeeks.contains(checkMonday)) {
      streak++;
      checkMonday = checkMonday.subtract(const Duration(days: 7));
    }

    return streak;
  }

  void _openAddMemorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _AddMemoryBottomSheet(
          spots: _repository.spots,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: ValueListenableBuilder<Box<DateEntry>>(
        valueListenable: Hive.box<DateEntry>('date_history').listenable(),
        builder: (context, box, _) {
          final entries = box.values.toList()
            ..sort((a, b) => b.visitedOn.compareTo(a.visitedOn)); // Most recent first

          if (entries.isEmpty) {
            return Scaffold(
              body: EmptyState(
                title: "Your Timeline is Blank",
                message: "Your timeline is a blank page waiting for memories. Plan your first date tonight ✨",
                buttonText: "Find a Spot",
                onAction: () {
                  // Switch to Discover tab. We can simulate it by simulating tab change
                  // In nextdate shell, tab change is managed by HomeScreen index state.
                  // We can pop back or change index. We will trigger notification or tell user.
                  final homeState = context.findAncestorStateOfType<State<HomeScreen>>();
                  if (homeState != null) {
                    // Let's call setState on HomeScreen to index 0
                    // We can access properties by casting or calling methods, but the cleanest is finding the State
                    // and updating index. Since we can't easily import private state or cast directly,
                    // we can trigger index change by calling a callback or popping if nested,
                    // or just tell the home state directly:
                    // (homeState as dynamic).setIndex(0);
                    try {
                      (homeState as dynamic).setState(() {
                        (homeState as dynamic)._currentIndex = 0;
                      });
                    } catch (_) {}
                  }
                },
                iconEmoji: "📅",
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: _openAddMemorySheet,
                backgroundColor: AppTheme.coralAccent,
                foregroundColor: isDark ? AppTheme.primaryNavy : Colors.white,
                child: const Icon(Icons.add),
              ),
            );
          }

          final streak = _calculateStreak(entries);

          return Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Streak Card (Gold background)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.warmGold,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.warmGold.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Text(
                        "🔥",
                        style: TextStyle(fontSize: 36),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "$streak Week Date Streak!",
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryNavy,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            "Keep the flame alive by planning weekly dates.",
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryNavy,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                Text(
                  "Your Date Timeline",
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Timeline List
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final dateStr = DateFormat('MMMM d, yyyy').format(entry.visitedOn);

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      color: isDark ? const Color(0xff162536) : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Thumbnail (60x60 rounded)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: entry.imageUrl,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, err) => Container(
                                  width: 60,
                                  height: 60,
                                  color: AppTheme.softGrey.withOpacity(0.2),
                                  child: const Icon(Icons.image),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.spotName,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    dateStr,
                                    style: const TextStyle(fontSize: 11, color: AppTheme.softGrey),
                                  ),
                                  if (entry.note.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      entry.note,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontStyle: FontStyle.italic,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  // Star Rating
                                  Row(
                                    children: List.generate(5, (starIndex) {
                                      return Icon(
                                        Icons.star,
                                        size: 16,
                                        color: starIndex < entry.rating ? AppTheme.warmGold : AppTheme.softGrey.withOpacity(0.3),
                                      );
                                    }),
                                  ),
                                ],
                              ),
                            ),
                            // Options button to delete
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.softGrey),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text("Delete Memory?"),
                                    content: const Text("Are you sure you want to remove this date from your timeline?"),
                                    actions: [
                                      TextButton(
                                        child: const Text("Cancel"),
                                        onPressed: () => Navigator.pop(context, false),
                                      ),
                                      TextButton(
                                        style: TextButton.styleFrom(foregroundColor: AppTheme.coralAccent),
                                        child: const Text("Delete"),
                                        onPressed: () => Navigator.pop(context, true),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await entry.delete();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 80),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: _openAddMemorySheet,
              backgroundColor: AppTheme.coralAccent,
              foregroundColor: isDark ? AppTheme.primaryNavy : Colors.white,
              child: const Icon(Icons.add),
            ),
          );
        },
      ),
    );
  }
}

// Add Memory bottom sheet class
class _AddMemoryBottomSheet extends StatefulWidget {
  final List<Spot> spots;

  const _AddMemoryBottomSheet({Key? key, required this.spots}) : super(key: key);

  @override
  State<_AddMemoryBottomSheet> createState() => _AddMemoryBottomSheetState();
}

class _AddMemoryBottomSheetState extends State<_AddMemoryBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  
  // Form fields state
  Spot? _selectedSpot;
  String _customSpotName = '';
  DateTime _visitedDate = DateTime.now();
  int _rating = 5;
  final TextEditingController _notesController = TextEditingController();

  bool _useCustomSpot = false;

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _visitedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.coralAccent,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _visitedDate = picked;
      });
    }
  }

  Future<void> _saveMemory() async {
    if (!_formKey.currentState!.validate()) return;

    String spotName = "";
    String imageUrl = "";
    String spotId = "";

    if (_useCustomSpot) {
      spotName = _customSpotName.trim();
      imageUrl = "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800&q=80"; // Default restaurant picture
      spotId = "custom_${DateTime.now().millisecondsSinceEpoch}";
    } else {
      if (_selectedSpot == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please select a date spot!"),
            backgroundColor: AppTheme.coralAccent,
          ),
        );
        return;
      }
      spotName = _selectedSpot!.name;
      imageUrl = _selectedSpot!.imageUrl;
      spotId = _selectedSpot!.id;
    }

    final box = Hive.box<DateEntry>('date_history');
    final entry = DateEntry(
      spotId: spotId,
      spotName: spotName,
      imageUrl: imageUrl,
      visitedOn: _visitedDate,
      rating: _rating,
      note: _notesController.text.trim(),
    );

    await box.add(entry);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Memory saved successfully! ✨"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff162536) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.softGrey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Add Date Memory",
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.primaryNavy,
                ),
              ),
              const SizedBox(height: 20),
              
              // Custom Spot switcher
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Log custom location?"),
                  Switch(
                    value: _useCustomSpot,
                    onChanged: (val) {
                      setState(() {
                        _useCustomSpot = val;
                      });
                    },
                    activeColor: AppTheme.coralAccent,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Spot Selector
              if (!_useCustomSpot) ...[
                DropdownButtonFormField<Spot>(
                  hint: const Text("Select Visited Spot"),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDark ? AppTheme.primaryNavy : Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: widget.spots.map((s) {
                    return DropdownMenuItem(
                      value: s,
                      child: Text(s.name, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedSpot = val;
                    });
                  },
                ),
              ] else ...[
                // Custom Name Field
                TextFormField(
                  decoration: InputDecoration(
                    labelText: "Custom Spot Name",
                    filled: true,
                    fillColor: isDark ? AppTheme.primaryNavy : Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? "Name required" : null,
                  onChanged: (val) {
                    _customSpotName = val;
                  },
                ),
              ],
              const SizedBox(height: 16),

              // Date Picker
              InkWell(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.primaryNavy : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.softGrey.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18, color: AppTheme.coralAccent),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('MMMM d, yyyy').format(_visitedDate),
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: isDark ? Colors.white : AppTheme.primaryNavy,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Rating selection (1-5)
              const Text("Date Rating:"),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final ratingValue = index + 1;
                  return IconButton(
                    icon: Icon(
                      Icons.star,
                      size: 32,
                      color: ratingValue <= _rating ? AppTheme.warmGold : AppTheme.softGrey.withOpacity(0.3),
                    ),
                    onPressed: () {
                      setState(() {
                        _rating = ratingValue;
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 16),

              // Notes Text Field
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: "Write a memory note...",
                  filled: true,
                  fillColor: isDark ? AppTheme.primaryNavy : Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 28),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveMemory,
                  child: const Text("Save Memory ✨"),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
