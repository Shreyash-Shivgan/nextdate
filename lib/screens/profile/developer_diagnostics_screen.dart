import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../../services/geoapify_service.dart';
import '../../services/spots_filter_service.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';

class DeveloperDiagnosticsScreen extends StatefulWidget {
  const DeveloperDiagnosticsScreen({Key? key}) : super(key: key);

  @override
  State<DeveloperDiagnosticsScreen> createState() => _DeveloperDiagnosticsScreenState();
}

class _DeveloperDiagnosticsScreenState extends State<DeveloperDiagnosticsScreen> {
  final GeoapifyService _geoapifyService = GeoapifyService();
  final SpotsFilterService _filterService = SpotsFilterService();
  final LocationService _locationService = LocationService();

  Position? _currentPosition;
  bool _isLoadingGps = false;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentGps();
  }

  Future<void> _loadCurrentGps() async {
    setState(() => _isLoadingGps = true);
    try {
      final pos = await _locationService.getCurrentPosition();
      if (mounted) {
        setState(() => _currentPosition = pos);
      }
    } catch (e) {
      print("Error loading GPS in diagnostics: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingGps = false);
      }
    }
  }

  Future<void> _triggerRefresh() async {
    setState(() => _isRefreshing = true);
    try {
      final pos = await _locationService.getCurrentPosition();
      setState(() {
        _currentPosition = pos;
      });
      // Trigger Geoapify pipeline fetch
      await _geoapifyService.fetchNearbySpots(
        lat: pos.latitude,
        lng: pos.longitude,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Pipeline run completed! ✨"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Pipeline run failed: $e"),
            backgroundColor: AppTheme.coralAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final requestUrl = _geoapifyService.lastRequestUrl;
    final httpStatus = _geoapifyService.lastHttpStatus;
    final featureCount = _geoapifyService.lastFeatureCount;
    final parsedCount = _geoapifyService.lastParsedCount;
    final failedParseCount = _geoapifyService.lastFailedParseCount;
    final isFallback = _geoapifyService.isLastFetchFallback;
    final refreshTime = _geoapifyService.lastRefreshTime;

    final beforeFilterCount = _filterService.lastBeforeFilterCount;
    final afterRadiusCount = _filterService.lastAfterRadiusCount;
    final afterCategoryCount = _filterService.lastAfterCategoryCount;
    final displayedCount = _filterService.lastDisplayedCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Developer Diagnostics 🛠️",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            Card(
              color: isDark ? const Color(0xff162536) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Pipeline Health",
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.coralAccent),
                        ),
                        _buildStatusBadge(isFallback),
                      ],
                    ),
                    const Divider(height: 24),
                    _buildDiagnosticsRow(
                      "Last Run",
                      refreshTime != null ? DateFormat('HH:mm:ss').format(refreshTime) : 'Never',
                      icon: Icons.access_time,
                    ),
                    const SizedBox(height: 8),
                    _buildDiagnosticsRow(
                      "HTTP Code",
                      httpStatus != null ? httpStatus.toString() : 'None',
                      color: httpStatus == 200 ? Colors.green : (httpStatus != null ? Colors.red : null),
                      icon: Icons.http,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // GPS Status Section
            _buildSectionHeader("GPS Coordinates 📍"),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _isLoadingGps
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.coralAccent))
                    : _currentPosition == null
                        ? Column(
                            children: [
                              const Text("GPS Coordinates not locked in 🥲"),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: _loadCurrentGps,
                                child: const Text("Request GPS Lock"),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              _buildDiagnosticsRow("Latitude", _currentPosition!.latitude.toStringAsFixed(6)),
                              const SizedBox(height: 8),
                              _buildDiagnosticsRow("Longitude", _currentPosition!.longitude.toStringAsFixed(6)),
                              const SizedBox(height: 8),
                              _buildDiagnosticsRow("Accuracy", "${_currentPosition!.accuracy.toStringAsFixed(1)}m"),
                            ],
                          ),
              ),
            ),
            const SizedBox(height: 20),

            // API Metrics Section
            _buildSectionHeader("Geoapify Response Metrics 📡"),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildDiagnosticsRow("Features Returned", featureCount?.toString() ?? '0'),
                    const SizedBox(height: 8),
                    _buildDiagnosticsRow("Parsed Spots", parsedCount?.toString() ?? '0'),
                    const SizedBox(height: 8),
                    _buildDiagnosticsRow("Failed Parses", failedParseCount?.toString() ?? '0',
                        color: (failedParseCount ?? 0) > 0 ? Colors.amber : null),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Filtering Pipeline Metrics Section
            _buildSectionHeader("Client Filtering Pipeline 🧪"),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildDiagnosticsRow("Spots Before Filter", beforeFilterCount?.toString() ?? '0'),
                    const SizedBox(height: 8),
                    _buildDiagnosticsRow("After Radius Filter", afterRadiusCount?.toString() ?? '0'),
                    const SizedBox(height: 8),
                    _buildDiagnosticsRow("After Category Filter", afterCategoryCount?.toString() ?? '0'),
                    const SizedBox(height: 8),
                    _buildDiagnosticsRow("Rendered/Displayed Spots", displayedCount?.toString() ?? '0',
                        color: AppTheme.coralAccent),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Request URL Debug Card
            _buildSectionHeader("Last Request URL 🔗"),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: requestUrl == null
                    ? const Text("No requests made yet.")
                    : SelectableText(
                        requestUrl,
                        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.softGrey),
                      ),
              ),
            ),
            const SizedBox(height: 32),

            // Force Pipeline Run Button
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isRefreshing ? null : _triggerRefresh,
                icon: _isRefreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.refresh),
                label: Text(
                  _isRefreshing ? "Running Pipeline..." : "Force Pipeline Run ⚡",
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.coralAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title,
        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.softGrey),
      ),
    );
  }

  Widget _buildDiagnosticsRow(String label, String value, {Color? color, IconData? icon}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: AppTheme.softGrey),
              const SizedBox(width: 8),
            ],
            Text(label, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.softGrey)),
          ],
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color ?? (Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.primaryNavy),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(bool isFallback) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isFallback ? Colors.amber.withOpacity(0.15) : Colors.green.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isFallback ? Colors.amber : Colors.green, width: 1),
      ),
      child: Text(
        isFallback ? "Curated Fallback" : "Live Geoapify",
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isFallback ? Colors.amber : Colors.green,
        ),
      ),
    );
  }
}
