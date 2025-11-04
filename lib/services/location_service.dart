import 'dart:async';
import 'dart:math' show pi, sin, cos, sqrt, atan2;
import 'package:location/location.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final Location _location = Location();
  final List<Function()> _proximityCallbacks = [];
  bool _isTracking = false;
  bool _serviceEnabled = false;
  PermissionStatus? _permissionGranted;
  StreamController<LatLng>? _locationController;
  StreamSubscription<LocationData>? _locationSubscription;

  void _log(String message) {
    debugPrint('📍 LocationService: $message');
  }

  Future<bool> initialize() async {
    try {
      _log('Initializing location service for mobile platform');

      // Initialize location settings first
      // Use lower accuracy for simulator, high for device
      await _location.changeSettings(
        accuracy: LocationAccuracy.high,
        interval: 5000, // Reduced from 10000 to get updates faster
        distanceFilter: 5, // Reduced from 10 to get updates faster
      );

      // Check if location service is enabled
      _serviceEnabled = await _location.serviceEnabled();
      if (!_serviceEnabled) {
        _serviceEnabled = await _location.requestService();
        if (!_serviceEnabled) {
          _log('Location service is not enabled');
          return false;
        }
      }

      // Check initial permission status (but don't request yet - let requestPermission() handle it)
      // This is just to cache the status, so we don't request unnecessarily
      _permissionGranted = await _location.hasPermission();
      
      // If permission is already granted, we're good
      if (_permissionGranted == PermissionStatus.granted ||
          _permissionGranted == PermissionStatus.grantedLimited) {
        _log('Location permission already granted');
      } else {
        _log('Location permission not yet granted - will be requested when needed');
      }

      _log('Location service initialized successfully');
      return true;
    } catch (e) {
      _log('Error initializing location service: $e');
      return false;
    }
  }

  Future<bool> requestPermission() async {
    try {
      // Check if we already have permission cached (avoid redundant checks)
      if (_permissionGranted == PermissionStatus.granted ||
          _permissionGranted == PermissionStatus.grantedLimited) {
        _log('Location permission already granted (cached)');
        return true;
      }

      _log('Checking location permission status...');

      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          _log('Location service could not be enabled');
          return false;
        }
      }

      // Check current permission status
      PermissionStatus permissionGranted = await _location.hasPermission();
      
      // Update cached status
      _permissionGranted = permissionGranted;
      
      // If permission is already granted, return early
      if (permissionGranted == PermissionStatus.granted ||
          permissionGranted == PermissionStatus.grantedLimited) {
        _log('Location permission already granted');
        return true;
      }
      
      // Only request if permission is denied
      if (permissionGranted == PermissionStatus.denied ||
          permissionGranted == PermissionStatus.deniedForever) {
        _log('Requesting location permission...');
        
        // Request permission - triggers iOS locationManagerDidChangeAuthorization callback
        permissionGranted = await _location.requestPermission();
        
        // Update cached status
        _permissionGranted = permissionGranted;
        
        // Small delay to allow iOS callback to fully process
        // This helps minimize the synchronous authorization check warning
        await Future.delayed(const Duration(milliseconds: 200));
        
        if (permissionGranted != PermissionStatus.granted &&
            permissionGranted != PermissionStatus.grantedLimited) {
          _log('Location permission denied by user');
          return false;
        }
      }

      _log('Location permission granted');
      return true;
    } catch (e) {
      _log('Error requesting location permission: $e');
      return false;
    }
  }

  /// Gets current location asynchronously without blocking
  /// Returns null if location cannot be obtained
  Future<LatLng?> getCurrentLocation() async {
    // This method is already async and non-blocking
    // The timeout doesn't make it synchronous - it just ensures the Future completes
    try {
      _log('Getting current location for mobile platform (async, non-blocking)');
      
      // Ensure we have permission before trying to get location
      // This is also async, so it won't block
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        _log('Permission not granted, cannot get location');
        return null;
      }
      
      // Get location asynchronously with timeout
      // The timeout is just a safety mechanism - the operation remains async
      // Even though we use 'await', this doesn't block the main thread - it's still async
      // Note: getLocation() returns Future<LocationData> (non-nullable), but coordinates can be null
      LocationData locationData;
      try {
        locationData = await _location.getLocation().timeout(
          const Duration(seconds: 10),
        );
      } on TimeoutException {
        _log('Timeout waiting for location - this may happen on iOS simulator');
        return null;
      } catch (e) {
        // Catch any other exceptions (permission denied, service unavailable, etc.)
        _log('Exception getting location: $e');
        return null;
      }
      
      // Check if coordinates are null (LocationData object itself is never null, but coordinates can be)
      if (locationData.latitude == null || locationData.longitude == null) {
        _log('Location coordinates are null - latitude: ${locationData.latitude}, longitude: ${locationData.longitude}');
        _log('This may happen if location services are not available or GPS signal is weak');
        return null;
      }
      
      final latLng = LatLng(
        locationData.latitude!,
        locationData.longitude!,
      );
      
      _log('Current location obtained: ${latLng.latitude}, ${latLng.longitude}');
      return latLng;
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
    if (_isTracking) {
      _log('Location tracking is already active');
      return;
    }

    _log('Starting location tracking for mobile platform');

    // Check permission - requestPermission() will check cache first and only request if needed
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      _log('Location permission not granted - cannot start tracking');
      throw Exception('Location permission not granted');
    }

    _isTracking = true;

    _locationSubscription = _location.onLocationChanged.listen(
      (LocationData locationData) {
        _log('Location update received - latitude: ${locationData.latitude}, longitude: ${locationData.longitude}');
        if (locationData.latitude != null && locationData.longitude != null) {
          final latLng = LatLng(
            locationData.latitude!,
            locationData.longitude!,
          );
          _locationController?.add(latLng);
          _log('Location updated and sent to stream: ${latLng.latitude}, ${latLng.longitude}');
        } else {
          _log('Location data received but coordinates are null');
        }
      },
      onError: (error) {
        _log('Location tracking error: $error');
        _log('Note: On iOS simulator, make sure to set a custom location via Debug > Location > Custom Location');
        _isTracking = false;
      },
      cancelOnError: false,
    );

    _log('Location tracking started successfully');
  }

  Future<void> stopTracking() async {
    if (!_isTracking) {
      _log('Location tracking is not active');
      return;
    }

    _log('Stopping location tracking');
    _isTracking = false;
    
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    
    _log('Location tracking stopped');
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