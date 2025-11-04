import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../config/app_config.dart';
import '../places_service.dart';
import 'places_service_platform.dart';

/// Mobile (iOS/Android) implementation of PlacesService
/// Uses HTTP API directly without CORS restrictions
class PlacesServiceWeb extends PlacesServicePlatform {
  bool _isInitialized = false;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (AppConfig.placesApiKey.isEmpty) {
        throw Exception('Google Places API key is not configured');
      }

      _isInitialized = true;
      debugPrint('PlacesService: Mobile platform initialized successfully');
    } catch (e) {
      debugPrint('PlacesService: Error during mobile initialization: $e');
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

    return await _getLocationFromHttpApi(placeId);
  }

  Future<List<PlacePrediction>> _getPredictionsFromHttpApi(String input) async {
    try {
      // Build the Google Places API URL
      final url = Uri.parse('${AppConfig.placesApiBaseUrl}/autocomplete/json').replace(
        queryParameters: {
          'input': input,
          'key': AppConfig.placesApiKey,
          'types': AppConfig.placeTypes.join('|'),
          'locationbias': 'IP_BIAS', // Use IP-based location bias for proximity-based results
        },
      );

      debugPrint('PlacesService: Mobile - Fetching predictions from HTTP API');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final predictions = _parseHttpApiResponse(data);
        debugPrint('PlacesService: Mobile - Found ${predictions.length} predictions for "$input"');
        return predictions;
      } else {
        debugPrint('PlacesService: Mobile - API error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('PlacesService: Mobile - Error: $e');
      return [];
    }
  }

  Future<LatLng?> _getLocationFromHttpApi(String placeId) async {
    try {
      // Build the Google Places API URL
      final url = Uri.parse('${AppConfig.placesApiBaseUrl}/details/json').replace(
        queryParameters: {
          'place_id': placeId,
          'key': AppConfig.placesApiKey,
          'fields': AppConfig.placeFields.join(','),
        },
      );

      debugPrint('PlacesService: Mobile - Fetching place details from HTTP API');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return _parseHttpPlaceDetailsResponse(data);
      } else {
        debugPrint('PlacesService: Mobile - Place details API error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('PlacesService: Mobile - Error getting place location: $e');
      return null;
    }
  }

  List<PlacePrediction> _parseHttpApiResponse(Map<String, dynamic> data) {
    if (data['status'] != 'OK') {
      debugPrint('PlacesService: Mobile - HTTP API status: ${data['status']}');
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
      debugPrint('PlacesService: Mobile - HTTP API status: ${data['status']}');
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
}

