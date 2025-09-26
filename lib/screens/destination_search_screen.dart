import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart' show AppColors;
import 'dart:math' as math;
import '../Services/places_service.dart';
import '../Services/saved_places_service.dart';
import '../models/saved_place.dart';
import 'map_pin_picker_screen.dart';
import 'package:geocoding/geocoding.dart' as geocoding;

class DestinationSearchScreen extends StatefulWidget {
  final double currentLatitude;
  final double currentLongitude;

  const DestinationSearchScreen({
    super.key,
    required this.currentLatitude,
    required this.currentLongitude,
  });

  @override
  State<DestinationSearchScreen> createState() => _DestinationSearchScreenState();
}

class _DestinationSearchScreenState extends State<DestinationSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  List<PlaceSearchResult> _searchResults = [];
  bool _isSearching = false;
  String _lastSearchQuery = '';
  Set<String> _savedIds = <String>{};
  List<SavedPlace> _savedPlaces = <SavedPlace>[];
  double? _anchorLat; // Paombong Municipal Hall latitude
  double? _anchorLng; // Paombong Municipal Hall longitude

  @override
  void initState() {
    super.initState();
    _searchFocusNode.requestFocus();
    _loadSaved();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    final saved = await SavedPlacesService.getAll();
    if (!mounted) return;
    setState(() {
      _savedIds = saved.map((e) => e.id).toSet();
      _savedPlaces = saved;
    });
    // Set Paombong Municipal Hall as anchor if not set
    _anchorLat ??= 14.8312; // approximate
    _anchorLng ??= 120.7895; // approximate
  }

  Future<void> _searchPlaces(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    if (query.trim() == _lastSearchQuery) return;
    
    setState(() {
      _isSearching = true;
      _lastSearchQuery = query.trim();
    });

    try {
      final results = await PlacesService.searchPlaces(
        query: query.trim(),
        latitude: widget.currentLatitude,
        longitude: widget.currentLongitude,
        radius: 20000,
        region: 'ph',
      );

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  void _selectDestination(PlaceSearchResult place) {
    Navigator.pop(context, place);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Search Destination',
          style: GoogleFonts.inter(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search for places...',
                hintStyle: GoogleFonts.inter(
                  color: Colors.grey.shade500,
                  fontSize: 16,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.grey.shade500,
                ),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    : _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: Colors.grey.shade500,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _searchPlaces('');
                            },
                          )
                        : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.black,
              ),
              onChanged: _searchPlaces,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MapPinPickerScreen(
                        initialLatitude: widget.currentLatitude,
                        initialLongitude: widget.currentLongitude,
                      ),
                    ),
                  );
                  if (result == null) return;
                  // Expecting LatLng from picker
                  final latLng = result;
                  if (!mounted) return;
                  final within = await _isWithin20Km(
                    latLng.latitude as double,
                    latLng.longitude as double,
                  );
                  if (!within) {
                    if (!mounted) return;
                    await showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Outside service area'),
                        content: const Text(
                          'The pinned location is more than 20 km away from Paombong Municipal Hall. Please pick a closer location.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                    return;
                  }
                  // Present save details sheet
                  _openSaveDetailsSheet(
                    latitude: latLng.latitude,
                    longitude: latLng.longitude,
                  );
                },
                icon: const Icon(Icons.add_location_alt),
                label: Text(
                  'Drop a pin to add exact location',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),

          // Search results
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final String q = _searchController.text.trim().toLowerCase();

    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
        ),
      );
    }

    // Saved places first (always visible, optionally filtered by query)
    final savedMatches = _savedPlaces.where((p) {
      if (q.isEmpty) return true;
      final a = p.name.toLowerCase();
      final b = (p.address ?? '').toLowerCase();
      return a.contains(q) || b.contains(q);
    }).toList();

    final List<Widget> items = [];
    if (savedMatches.isNotEmpty) {
      items.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text(
          'Saved',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade600,
          ),
        ),
      ));
      for (final s in savedMatches) {
        items.add(_buildSavedPlaceItem(s));
      }
      items.add(const SizedBox(height: 8));
    }

    if (q.isNotEmpty) {
      for (final place in _searchResults) {
        items.add(_buildPlaceItem(place));
      }
    }

    if (items.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      itemCount: items.length,
      itemBuilder: (context, index) => items[index],
      separatorBuilder: (context, index) => Divider(
        height: 1,
        thickness: 1,
        color: Colors.grey.shade200,
        indent: 68,
        endIndent: 12,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_on,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Search for your destination',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter a place name, address, or landmark',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceItem(PlaceSearchResult place) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(horizontal: 0, vertical: -1),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.location_on,
          color: AppColors.primary,
          size: 20,
        ),
      ),
      title: Text(
        place.name,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        place.formattedAddress.isNotEmpty
            ? place.formattedAddress
            : place.vicinity ?? '',
        style: GoogleFonts.inter(
          fontSize: 13,
          color: Colors.grey.shade600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              _savedIds.contains(place.placeId)
                  ? Icons.bookmark
                  : Icons.bookmark_outline,
              color: _savedIds.contains(place.placeId)
                  ? AppColors.primary
                  : Colors.grey.shade400,
              size: 20,
            ),
            onPressed: () async {
              final isSaved = _savedIds.contains(place.placeId);
              if (isSaved) {
                await SavedPlacesService.remove(place.placeId);
              } else {
                await SavedPlacesService.upsert(
                  SavedPlace(
                    id: place.placeId,
                    name: place.name,
                    address: place.formattedAddress.isNotEmpty
                        ? place.formattedAddress
                        : place.vicinity,
                    latitude: place.latitude,
                    longitude: place.longitude,
                  ),
                );
              }
              await _loadSaved();
            },
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: Colors.grey.shade400,
          ),
        ],
      ),
      onTap: () => _selectDestination(place),
    );
  }

  Widget _buildSavedPlaceItem(SavedPlace saved) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(horizontal: 0, vertical: -1),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.bookmark,
          color: Colors.amber.shade700,
          size: 20,
        ),
      ),
      title: Text(
        saved.name,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        saved.address ?? '${saved.latitude.toStringAsFixed(5)}, ${saved.longitude.toStringAsFixed(5)}',
        style: GoogleFonts.inter(
          fontSize: 13,
          color: Colors.grey.shade600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey.shade400,
      ),
      onTap: () {
        final result = PlaceSearchResult(
          placeId: saved.id,
          name: saved.name,
          formattedAddress: saved.address ?? '',
          latitude: saved.latitude,
          longitude: saved.longitude,
          photoReference: null,
          rating: null,
          vicinity: saved.address,
        );
        _selectDestination(result);
      },
    );
  }

  Future<void> _openSaveDetailsSheet({
    required double latitude,
    required double longitude,
  }) async {
    final prefill = await _reverseGeocode(latitude, longitude);
    if (!mounted) return;
    final controllerLine1 = TextEditingController();
    final controllerBarangay = TextEditingController();
    final controllerCity = TextEditingController();

    // Do not prefill the house/street field; keep user-entered only

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Save exact location', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextField(
                controller: controllerLine1,
                decoration: InputDecoration(
                  labelText: 'House no., street name',
                  hintText: 'e.g., 123 Main St',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controllerBarangay,
                decoration: InputDecoration(
                  labelText: 'Barangay',
                  hintText: 'e.g., Sta. Maria',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controllerCity,
                decoration: InputDecoration(
                  labelText: 'City',
                  hintText: 'e.g., Malolos',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final line1 = controllerLine1.text.trim();
                    final brgy = controllerBarangay.text.trim();
                    final city = controllerCity.text.trim();
                    final composed = [
                      if (line1.isNotEmpty) line1,
                      if (brgy.isNotEmpty) brgy,
                      if (city.isNotEmpty) city,
                    ].join(', ');

                    final saved = SavedPlace(
                      id: 'pin_${latitude.toStringAsFixed(6)}_${longitude.toStringAsFixed(6)}',
                      name: line1.isNotEmpty ? line1 : 'Pinned location',
                      address: composed.isNotEmpty ? composed : prefill,
                      latitude: latitude,
                      longitude: longitude,
                      // keep extended fields null for now
                    );
                    await SavedPlacesService.upsert(saved);
                    await _loadSaved();
                    if (!mounted) return;
                    Navigator.pop(context);
                  },
                  child: Text('Save'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _reverseGeocode(double latitude, double longitude) async {
    try {
      final placemarks = await geocoding.placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return null;
      final p = placemarks.first;
      final parts = [
        if ((p.street ?? '').trim().isNotEmpty) p.street,
        if ((p.subLocality ?? '').trim().isNotEmpty) p.subLocality, // barangay
        if ((p.locality ?? '').trim().isNotEmpty) p.locality,
        if ((p.administrativeArea ?? '').trim().isNotEmpty) p.administrativeArea,
      ];
      return parts.whereType<String>().join(', ');
    } catch (_) {
      return null;
    }
  }

  Future<bool> _isWithin20Km(double latitude, double longitude) async {
    final anchorLat = _anchorLat;
    final anchorLng = _anchorLng;
    if (anchorLat == null || anchorLng == null) return true;
    final meters = _distanceBetweenMeters(anchorLat, anchorLng, latitude, longitude);
    return meters <= 20000;
  }

  double _distanceBetweenMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusMeters = 6371000;
    final double dLat = _degToRad(lat2 - lat1);
    final double dLon = _degToRad(lon2 - lon1);
    final double a =
        (math.sin(dLat / 2) * math.sin(dLat / 2)) +
            math.cos(_degToRad(lat1)) *
                math.cos(_degToRad(lat2)) *
                (math.sin(dLon / 2) * math.sin(dLon / 2));
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  double _degToRad(double deg) => deg * (3.141592653589793 / 180.0);
}
