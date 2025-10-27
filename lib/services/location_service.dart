import 'dart:async';
import 'dart:math' show pi, sin, cos, sqrt, atan2;
import 'package:location/location.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:html' as html;
import 'dart:js_util';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final Location _location = Location();
  final List<Function()> _proximityCallbacks = [];
  Timer? _locationTimer;
  bool _isTracking = false;
  bool _serviceEnabled = false;
  PermissionStatus? _permissionGranted;
  StreamController<LatLng>? _locationController;
  StreamSubscription<LocationData>? _locationSubscription;
  html.Geolocation? _webGeolocation;
  Timer? _webLocationTimer;

  void _log(String message) {
    debugPrint('📍 LocationService: $message');
  }

  Future<bool> initialize() async {
    try {
      if (kIsWeb) {
        _log('Initializing web geolocation');
        _webGeolocation = html.window.navigator.geolocation;
        return true;
      }

      // Initialize location settings
      await _location.changeSettings(
        accuracy: LocationAccuracy.high,
        interval: 10000,
        distanceFilter: 10,
      );

      // Check if location service is enabled
      _serviceEnabled = await _location.serviceEnabled();
      if (!_serviceEnabled) {
        _serviceEnabled = await _location.requestService();
        if (!_serviceEnabled) {
          return false;
        }
      }

      // Check location permission
      _permissionGranted = await _location.hasPermission();
      if (_permissionGranted == PermissionStatus.denied) {
        _permissionGranted = await _location.requestPermission();
        if (_permissionGranted != PermissionStatus.granted) {
          return false;
        }
      }

      return true;
    } catch (e) {
      _log('Error initializing location service: $e');
      return false;
    }
  }

  Future<bool> requestPermission() async {
    try {
      if (kIsWeb) {
        try {
          final completer = Completer<bool>();
          
          void successCallback(html.Geoposition position) {
            _log('Web geolocation permission granted');
            completer.complete(true);
          }

          void errorCallback(dynamic error) {
            String errorMessage;
            final errorCode = getProperty(error, 'code');
            if (errorCode != null) {
              switch (errorCode) {
                case 1: // PERMISSION_DENIED
                  errorMessage = 'User denied the request for Geolocation';
                  break;
                case 2: // POSITION_UNAVAILABLE
                  errorMessage = 'Location information is unavailable';
                  break;
                case 3: // TIMEOUT
                  errorMessage = 'The request to get user location timed out';
                  break;
                default:
                  errorMessage = 'An unknown error occurred';
              }
            } else {
              errorMessage = 'An unknown error occurred: $error';
            }
            _log('Web geolocation error: $errorMessage');
            completer.complete(false);
          }

          _webGeolocation!.getCurrentPosition().then(successCallback).catchError(errorCallback);
          return await completer.future;
        } catch (e) {
          _log('Web permission request failed: $e');
          return false;
        }
      }

      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) return false;
      }

      PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) return false;
      }

      return true;
    } catch (e) {
      _log('Error requesting location permission: $e');
      return false;
    }
  }

  Future<LatLng?> getCurrentLocation() async {
    try {
      if (kIsWeb) {
        try {
          final completer = Completer<LatLng?>();
          
          void successCallback(html.Geoposition position) {
            if (position.coords != null) {
              completer.complete(LatLng(
                (position.coords!.latitude ?? 0).toDouble(),
                (position.coords!.longitude ?? 0).toDouble(),
              ));
            } else {
              _log('Error: Coordinates are null');
              completer.complete(null);
            }
          }

          void errorCallback(dynamic error) {
            String errorMessage;
            final errorCode = getProperty(error, 'code');
            if (errorCode != null) {
              switch (errorCode) {
                case 1: // PERMISSION_DENIED
                  errorMessage = 'User denied the request for Geolocation';
                  break;
                case 2: // POSITION_UNAVAILABLE
                  errorMessage = 'Location information is unavailable';
                  break;
                case 3: // TIMEOUT
                  errorMessage = 'The request to get user location timed out';
                  break;
                default:
                  errorMessage = 'An unknown error occurred';
              }
            } else {
              errorMessage = 'An unknown error occurred: $error';
            }
            _log('Error getting web location: $errorMessage');
            completer.complete(null);
          }

          _webGeolocation!.getCurrentPosition().then(successCallback).catchError(errorCallback);
          return await completer.future;
        } catch (e) {
          _log('Error getting web location: $e');
          return null;
        }
      }

      final locationData = await _location.getLocation();
      return LatLng(
        locationData.latitude ?? 0,
        locationData.longitude ?? 0,
      );
    } catch (e) {
      _log('Error getting current location: $e');
      return null;
    }
  }

  Stream<LatLng> get locationStream {
    _locationController ??= StreamController<LatLng>.broadcast();
    return _locationController!.stream;
  }

  Future<void> startTracking() async {
    if (_isTracking) return;

    final hasPermission = await requestPermission();
    if (!hasPermission) {
      _log('Location permission not granted. Requesting permission again...');
      // Try one more time to get permission
      final retryPermission = await requestPermission();
      if (!retryPermission) {
        throw Exception('Location permission not granted');
      }
    }

    _isTracking = true;

    if (kIsWeb) {
      // For web, we'll use a timer to periodically get the current location
      _webLocationTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
        try {
          final position = await getCurrentLocation();
          if (position != null) {
            _locationController?.add(position);
          }
        } catch (e) {
          _log('Error getting web location: $e');
          _isTracking = false;
          timer.cancel();
        }
      });

      // Get initial location
      try {
        final position = await getCurrentLocation();
        if (position != null) {
          _locationController?.add(position);
        }
      } catch (e) {
        _log('Error getting initial web location: $e');
      }
    } else {
      _locationSubscription = _location.onLocationChanged.listen(
        (LocationData locationData) {
          final latLng = LatLng(
            locationData.latitude ?? 0,
            locationData.longitude ?? 0,
          );
          _locationController?.add(latLng);
        },
        onError: (error) {
          _log('Location error: $error');
          _isTracking = false;
        },
      );
    }
  }

  Future<void> stopTracking() async {
    _isTracking = false;
    if (kIsWeb) {
      _webLocationTimer?.cancel();
      _webLocationTimer = null;
    } else {
      await _locationSubscription?.cancel();
      _locationSubscription = null;
    }
  }

  void addProximityCallback(Function() callback) {
    _proximityCallbacks.add(callback);
  }

  void removeProximityCallback(Function() callback) {
    _proximityCallbacks.remove(callback);
  }

  void _checkProximity(LocationData userLocation) {
    // This will be implemented by the alarm manager
    for (var callback in _proximityCallbacks) {
      callback();
    }
  }

  // Calculate distance between two points using Haversine formula
  double calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // in kilometers
    final lat1 = point1.latitude * pi / 180;
    final lat2 = point2.latitude * pi / 180;
    final dLat = (point2.latitude - point1.latitude) * pi / 180;
    final dLon = (point2.longitude - point1.longitude) * pi / 180;

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c * 1000; // Convert to meters
  }

  void dispose() {
    stopTracking();
    _locationController?.close();
    _locationController = null;
  }
} 