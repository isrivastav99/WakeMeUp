import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'location_service.dart';
import 'package:location/location.dart';

class Alarm {
  final String id;
  final String name;
  final LatLng initialLocation; // Location when alarm was created
  final LatLng destination; // Destination to reach
  final double radius;
  bool isActive;
  String? ringtonePath;

  Alarm({
    required this.id,
    required this.name,
    required this.initialLocation,
    required this.destination,
    required this.radius,
    this.isActive = false,
    this.ringtonePath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'initialLocation': {
          'latitude': initialLocation.latitude,
          'longitude': initialLocation.longitude,
        },
        'destination': {
          'latitude': destination.latitude,
          'longitude': destination.longitude,
        },
        'radius': radius,
        'isActive': isActive,
        'ringtonePath': ringtonePath,
      };

  factory Alarm.fromJson(Map<String, dynamic> json) => Alarm(
        id: json['id'],
        name: json['name'],
        initialLocation: json['initialLocation'] != null
            ? LatLng(
                json['initialLocation']['latitude'],
                json['initialLocation']['longitude'],
              )
            : LatLng(
                // Fallback for old alarms without initialLocation
                json['destination']['latitude'],
                json['destination']['longitude'],
              ),
        destination: LatLng(
          json['destination']['latitude'],
          json['destination']['longitude'],
        ),
        radius: json['radius'],
        isActive: json['isActive'],
        ringtonePath: json['ringtonePath'],
      );
}

class AlarmManager {
  static final AlarmManager _instance = AlarmManager._internal();
  factory AlarmManager() => _instance;
  AlarmManager._internal();

  final List<Alarm> _alarms = [];
  final LocationService _locationService = LocationService();
  final _prefs = SharedPreferences.getInstance();
  final List<Function(Alarm)> _onAlarmTriggered = [];

  Future<void> initialize() async {
    await _loadAlarms();
    _locationService.addProximityCallback(_checkProximity);
    await _locationService.startTracking();
  }

  Future<void> _loadAlarms() async {
    final prefs = await _prefs;
    final alarmsJson = prefs.getStringList('alarms') ?? [];
    _alarms.clear();
    _alarms.addAll(
      alarmsJson.map((json) => Alarm.fromJson(jsonDecode(json))).toList(),
    );
  }

  Future<void> _saveAlarms() async {
    final prefs = await _prefs;
    final alarmsJson = _alarms
        .map((alarm) => jsonEncode(alarm.toJson()))
        .toList();
    await prefs.setStringList('alarms', alarmsJson);
  }

  List<Alarm> getAlarms() => List.unmodifiable(_alarms);

  Future<void> addAlarm(Alarm alarm) async {
    _alarms.add(alarm);
    await _saveAlarms();
  }

  Future<void> updateAlarm(Alarm alarm) async {
    final index = _alarms.indexWhere((a) => a.id == alarm.id);
    if (index != -1) {
      _alarms[index] = alarm;
      await _saveAlarms();
    }
  }

  Future<void> removeAlarm(String id) async {
    _alarms.removeWhere((alarm) => alarm.id == id);
    await _saveAlarms();
  }

  void addAlarmTriggeredCallback(Function(Alarm) callback) {
    _onAlarmTriggered.add(callback);
  }

  void removeAlarmTriggeredCallback(Function(Alarm) callback) {
    _onAlarmTriggered.remove(callback);
  }

  void _checkProximity() async {
    try {
      final location = Location();
      final locationData = await location.getLocation();
      final userLocation = LatLng(
        locationData.latitude!,
        locationData.longitude!,
      );

      for (final alarm in _alarms) {
        if (!alarm.isActive) continue;

        final distance = _locationService.calculateDistance(
          userLocation,
          alarm.destination,
        );

        if (distance <= alarm.radius) {
          for (final callback in _onAlarmTriggered) {
            callback(alarm);
          }
        }
      }
    } catch (e) {
      print('Error checking proximity: $e');
    }
  }

  void dispose() {
    _locationService.stopTracking();
  }
} 