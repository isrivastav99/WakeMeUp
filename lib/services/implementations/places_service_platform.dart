import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../places_service.dart';

/// Platform interface for PlacesService implementations
/// This abstract class defines the contract that all platform-specific implementations must follow
abstract class PlacesServicePlatform {
  /// Initialize the platform-specific implementation
  Future<void> initialize();

  /// Get place predictions for the given input string
  Future<List<PlacePrediction>> getPlacePredictions(String input);

  /// Get the location (LatLng) for a given place ID
  Future<LatLng?> getPlaceLocation(String placeId);

  /// Check if the service is initialized
  bool get isInitialized;

  /// Check if Google Maps API is loaded (web-specific, returns false on mobile)
  bool get isGoogleMapsLoaded => false;
}

