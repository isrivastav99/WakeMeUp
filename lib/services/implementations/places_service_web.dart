import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:js' as js;
import '../../config/app_config.dart';
import '../places_service.dart';
import 'places_service_platform.dart';

/// Web implementation of PlacesService
/// Uses HTTP API with CORS proxy (since browsers have CORS restrictions)
/// Note: This class is named PlacesServiceWeb but is also used as the default import for web
class PlacesServiceWeb extends PlacesServicePlatform {
  bool _isInitialized = false;
  bool _isGoogleMapsLoaded = false;

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isGoogleMapsLoaded => _isGoogleMapsLoaded;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (AppConfig.placesApiKey.isEmpty) {
        throw Exception('Google Places API key is not configured');
      }

      _isInitialized = true;
      debugPrint('PlacesService: Web platform initialized successfully');
    } catch (e) {
      debugPrint('PlacesService: Error during web initialization: $e');
      rethrow;
    }
  }

  @override
  Future<List<PlacePrediction>> getPlacePredictions(String input) async {
    if (input.trim().isEmpty) {
      return [];
    }

    if (!_isInitialized) {
      await initialize();
    }

    // Use HTTP API with CORS proxy for web
    return await _getPredictionsFromHttpApi(input);
  }

  @override
  Future<LatLng?> getPlaceLocation(String placeId) async {
    if (placeId.isEmpty) {
      return null;
    }

    if (!_isInitialized) {
      await initialize();
    }

    // Use HTTP API with CORS proxy for web
    return await _getLocationFromHttpApi(placeId);
  }

  Future<List<PlacePrediction>> _getPredictionsFromHttpApi(String input) async {
    try {
      // Build the Google Places API URL
      final googleUrl = Uri.parse('${AppConfig.placesApiBaseUrl}/autocomplete/json').replace(
        queryParameters: {
          'input': input,
          'key': AppConfig.placesApiKey,
          'types': AppConfig.placeTypes.join('|'),
          'locationbias': 'IP_BIAS', // Use IP-based location bias for proximity-based results
        },
      );

      // Use CORS proxy for web
      final url = Uri.parse('http://localhost:8082/proxy').replace(
        queryParameters: {'url': googleUrl.toString()},
      );

      debugPrint('PlacesService: Web - Fetching predictions via CORS proxy');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final predictions = _parseHttpApiResponse(data);
        debugPrint('PlacesService: Web - Found ${predictions.length} predictions for "$input"');
        return predictions;
      } else {
        debugPrint('PlacesService: Web - API error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('PlacesService: Web - Error: $e');
      return [];
    }
  }

  Future<LatLng?> _getLocationFromHttpApi(String placeId) async {
    try {
      // Build the Google Places API URL
      final googleUrl = Uri.parse('${AppConfig.placesApiBaseUrl}/details/json').replace(
        queryParameters: {
          'place_id': placeId,
          'key': AppConfig.placesApiKey,
          'fields': AppConfig.placeFields.join(','),
        },
      );

      // Use CORS proxy for web
      final url = Uri.parse('http://localhost:8082/proxy').replace(
        queryParameters: {'url': googleUrl.toString()},
      );

      debugPrint('PlacesService: Web - Fetching place details via CORS proxy');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return _parseHttpPlaceDetailsResponse(data);
      } else {
        debugPrint('PlacesService: Web - Place details API error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('PlacesService: Web - Error getting place location: $e');
      return null;
    }
  }

  List<PlacePrediction> _parseHttpApiResponse(Map<String, dynamic> data) {
    if (data['status'] != 'OK') {
      debugPrint('PlacesService: Web - HTTP API status: ${data['status']}');
      return [];
    }

    final predictions = data['predictions'] as List?;
    if (predictions == null) return [];

    return predictions.map((prediction) {
      return PlacePrediction(
        placeId: prediction['place_id']?.toString() ?? '',
        description: prediction['description']?.toString() ?? '',
      );
    }).toList();
  }

  LatLng? _parseHttpPlaceDetailsResponse(Map<String, dynamic> data) {
    if (data['status'] != 'OK') {
      debugPrint('PlacesService: Web - HTTP API status: ${data['status']}');
      return null;
    }

    final result = data['result'] as Map<String, dynamic>?;
    if (result == null) return null;

    final geometry = result['geometry'] as Map<String, dynamic>?;
    if (geometry == null) return null;

    final location = geometry['location'] as Map<String, dynamic>?;
    if (location == null) return null;

    final lat = location['lat'];
    final lng = location['lng'];

    if (lat != null && lng != null) {
      return LatLng(lat.toDouble(), lng.toDouble());
    }

    return null;
  }

  // Optional: Web-specific methods for JavaScript API (if needed in the future)
  // These methods are kept for potential future use but not currently called
  bool _isGoogleMapsApiLoaded() {
    try {
      debugPrint('PlacesService: Web - Checking Google Maps API availability...');

      final google = js.context['google'];
      if (google == null) return false;

      final maps = google['maps'];
      if (maps == null) return false;

      final places = maps['places'];
      if (places == null) return false;

      debugPrint('PlacesService: Web - ✅ All required Google Maps API components are available');
      return true;
    } catch (e) {
      debugPrint('PlacesService: Web - Error checking Google Maps API: $e');
      return false;
    }
  }
}

