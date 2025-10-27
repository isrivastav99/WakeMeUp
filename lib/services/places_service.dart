import 'dart:async';
import 'dart:js_util';
import 'dart:html';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PlacesService {
  static final PlacesService _instance = PlacesService._internal();
  factory PlacesService() => _instance;
  PlacesService._internal();

  final String _apiKey = 'AIzaSyDtOY4mSwiJlUlb51SAcH7xhgyeV-0hFt4';
  final String _baseUrl = 'https://maps.googleapis.com/maps/api/place';
  bool _isGoogleMapsLoaded = false;

  bool get isGoogleMapsLoaded => _isGoogleMapsLoaded;

  Future<void> initialize() async {
    if (kIsWeb) {
      try {
        // Check if Google Maps API is loaded
        if (window.hasProperty('google') &&
            getProperty(window, 'google') != null &&
            getProperty(getProperty(window, 'google'), 'maps') != null &&
            getProperty(getProperty(getProperty(window, 'google'), 'maps'), 'places') != null) {
          _isGoogleMapsLoaded = true;
          debugPrint('Google Maps Places API is loaded');
        } else {
          debugPrint('Google Maps Places API is not loaded');
        }
      } catch (e) {
        debugPrint('Error checking Google Maps API: $e');
      }
    }
  }

  Future<List<Map<String, dynamic>>> getPlacePredictions(String input) async {
    if (kIsWeb && _isGoogleMapsLoaded) {
      try {
        final completer = Completer<List<Map<String, dynamic>>>();
        
        // Create a new AutocompleteSuggestion instance
        final autocomplete = callMethod(
          getProperty(getProperty(getProperty(window, 'google'), 'maps'), 'places'),
          'AutocompleteSuggestion',
          [],
        );

        // Set up the options
        final options = jsify({
          'input': input,
          'types': ['establishment', 'geocode'],
        });

        // Get predictions
        final service = callMethod(
          getProperty(getProperty(getProperty(window, 'google'), 'maps'), 'places'),
          'AutocompleteService',
          [],
        );

        callMethod(service, 'getPlacePredictions', [options, (results, status) {
          if (status == 'OK') {
            final predictions = (results as List)
                .map((result) => {
                      'place_id': getProperty(result, 'place_id'),
                      'description': getProperty(result, 'description'),
                    })
                .toList();
            completer.complete(predictions);
          } else {
            completer.complete([]);
          }
        }]);

        return await completer.future;
      } catch (e) {
        debugPrint('Error getting place predictions: $e');
        return [];
      }
    } else {
      // Fallback to HTTP API
      try {
        final response = await http.get(
          Uri.parse('$_baseUrl/autocomplete/json?input=$input&key=$_apiKey'),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'OK') {
            return (data['predictions'] as List)
                .map((prediction) => {
                      'place_id': prediction['place_id'],
                      'description': prediction['description'],
                    })
                .toList();
          }
        }
        return [];
      } catch (e) {
        debugPrint('Error getting place predictions via HTTP: $e');
        return [];
      }
    }
  }

  Future<LatLng?> getPlaceLocation(String placeId) async {
    if (kIsWeb && _isGoogleMapsLoaded) {
      try {
        final completer = Completer<LatLng?>();
        
        final service = callMethod(
          getProperty(getProperty(getProperty(window, 'google'), 'maps'), 'places'),
          'PlacesService',
          [document.createElement('div')],
        );

        final request = jsify({
          'placeId': placeId,
          'fields': ['geometry'],
        });

        callMethod(service, 'getDetails', [request, (place, status) {
          if (status == 'OK') {
            final location = getProperty(getProperty(place, 'geometry'), 'location');
            final lat = callMethod(location, 'lat', []);
            final lng = callMethod(location, 'lng', []);
            completer.complete(LatLng(lat.toDouble(), lng.toDouble()));
          } else {
            completer.complete(null);
          }
        }]);

        return await completer.future;
      } catch (e) {
        debugPrint('Error getting place location: $e');
        return null;
      }
    } else {
      // Fallback to HTTP API
      try {
        final response = await http.get(
          Uri.parse('$_baseUrl/details/json?place_id=$placeId&key=$_apiKey'),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'OK') {
            final location = data['result']['geometry']['location'];
            return LatLng(
              location['lat'].toDouble(),
              location['lng'].toDouble(),
            );
          }
        }
        return null;
      } catch (e) {
        debugPrint('Error getting place location via HTTP: $e');
        return null;
      }
    }
  }
} 