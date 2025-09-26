import 'dart:convert';

class SavedPlace {
  final String id; // use placeId or generated id
  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final String? notes;
  final String? houseNumber;
  final String? landmark;
  final String? entrance;

  const SavedPlace({
    required this.id,
    required this.name,
    this.address,
    required this.latitude,
    required this.longitude,
    this.notes,
    this.houseNumber,
    this.landmark,
    this.entrance,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'notes': notes,
        'houseNumber': houseNumber,
        'landmark': landmark,
        'entrance': entrance,
      };

  factory SavedPlace.fromMap(Map<String, dynamic> map) => SavedPlace(
        id: map['id'] as String,
        name: map['name'] as String,
        address: map['address'] as String?,
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        notes: map['notes'] as String?,
        houseNumber: map['houseNumber'] as String?,
        landmark: map['landmark'] as String?,
        entrance: map['entrance'] as String?,
      );

  String toJson() => jsonEncode(toMap());

  factory SavedPlace.fromJson(String source) =>
      SavedPlace.fromMap(jsonDecode(source) as Map<String, dynamic>);
}


