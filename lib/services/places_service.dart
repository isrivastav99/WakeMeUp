import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Conditional imports for platform-specific implementations
// On web: imports web implementation
// On mobile (iOS/Android): imports mobile implementation
import 'implementations/places_service_web.dart' 
    if (dart.library.io) 'implementations/places_service_mobile.dart' 
    as platform_impl;

import 'implementations/places_service_platform.dart';

/// Represents a place prediction from Google Places API
class PlacePrediction {
  final String placeId;
  final String description;

  const PlacePrediction({
    required this.placeId,
    required this.description,
  });

  Map<String, dynamic> toMap() => {
        'place_id': placeId,
        'description': description,
      };

  @override
  String toString() =>
      'PlacePrediction(placeId: $placeId, description: $description)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlacePrediction &&
          runtimeType == other.runtimeType &&
          placeId == other.placeId &&
          description == other.description;

  @override
  int get hashCode => placeId.hashCode ^ description.hashCode;
}

/// Service for interacting with Google Places API
/// Uses platform-specific implementations for web and mobile (iOS/Android)
class PlacesService {
  static final PlacesService _instance = PlacesService._internal();
  factory PlacesService() => _instance;
  PlacesService._internal();

  // Platform-specific implementation selected via conditional imports
  final PlacesServicePlatform _platform = platform_impl.PlacesServiceWeb();

  /// Check if the service is initialized
  bool get isInitialized => _platform.isInitialized;

  /// Check if Google Maps API is loaded (web-specific, returns false on mobile)
  bool get isGoogleMapsLoaded => _platform.isGoogleMapsLoaded;

  /// Initialize the PlacesService
  Future<void> initialize() async {
    await _platform.initialize();
  }

  /// Get place predictions for the given input string
  /// 
  /// Returns a list of [PlacePrediction] objects matching the input.
  /// Returns an empty list if input is empty or if no predictions are found.
  Future<List<PlacePrediction>> getPlacePredictions(String input) async {
    return await _platform.getPlacePredictions(input);
  }

  /// Get the location (LatLng) for a given place ID
  /// 
  /// Returns the [LatLng] coordinates for the place, or null if not found.
  Future<LatLng?> getPlaceLocation(String placeId) async {
    return await _platform.getPlaceLocation(placeId);
  }
}
