import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_place.dart';

class SavedPlacesService {
  static const String _storageKey = 'saved_places_v1';

  static Future<List<SavedPlace>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey);
    if (raw == null) return [];
    return raw
        .map((s) => SavedPlace.fromMap(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  static Future<void> upsert(SavedPlace place) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getAll();
    final filtered = existing.where((p) => p.id != place.id).toList();
    filtered.add(place);
    final encoded = filtered.map((p) => jsonEncode(p.toMap())).toList();
    await prefs.setStringList(_storageKey, encoded);
  }

  static Future<void> remove(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getAll();
    final filtered = existing.where((p) => p.id != id).toList();
    final encoded = filtered.map((p) => jsonEncode(p.toMap())).toList();
    await prefs.setStringList(_storageKey, encoded);
  }

  static Future<bool> isSaved(String id) async {
    final existing = await getAll();
    return existing.any((p) => p.id == id);
  }
}


