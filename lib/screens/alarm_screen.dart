import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/alarm_manager.dart';
import '../services/location_service.dart';
import '../widgets/location_autocomplete.dart';
import 'dart:async';

class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  final TextEditingController _currentLocationController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final Completer<GoogleMapController> _controller = Completer();
  final LocationService _locationService = LocationService();
  final AlarmManager _alarmManager = AlarmManager();
  final AudioPlayer _audioPlayer = AudioPlayer();
  double _radius = 100; // Default radius in meters
  Set<Circle> _circles = {};
  Set<Marker> _markers = {};
  LatLng? _currentLocation;
  LatLng? _destination;
  Alarm? _editingAlarm;
  String? _selectedRingtone;
  StreamSubscription<LatLng?>? _locationSubscription;
  bool _isMapReady = false;
  bool _isMapError = false;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _initializeAudio();
  }

  Future<void> _initializeLocation() async {
    try {
      final initialized = await _locationService.initialize();
      if (!initialized) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Location Service Required'),
              content: const Text(
                'This app needs location access to track your position. '
                'Please enable location services in your device settings.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Get initial location
      final location = await _locationService.getCurrentLocation();
      if (location != null && mounted) {
        setState(() {
          _currentLocation = location;
          _updateMarkersAndCircle();
        });
      }

      // Set up location stream
      _locationSubscription = _locationService.locationStream.listen(
        (location) {
          if (mounted) {
            setState(() {
              _currentLocation = location;
              _updateMarkersAndCircle();
            });
          }
        },
        onError: (error) {
          debugPrint('Location stream error: $error');
        },
      );
    } catch (e) {
      debugPrint('Error initializing location: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Location Error'),
            content: Text('Error initializing location: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showErrorDialog(String message) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Location Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _updateMarkersAndCircle() {
    if (_currentLocation != null) {
      setState(() {
        // Update marker
        _markers = {
          Marker(
            markerId: const MarkerId('current_location'),
            position: _currentLocation!,
            infoWindow: const InfoWindow(title: 'Current Location'),
          ),
        };

        // Update circle
        _circles = {
          Circle(
            circleId: const CircleId('alarm_radius'),
            center: _currentLocation!,
            radius: _radius,
            fillColor: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
            strokeColor: Theme.of(context).colorScheme.secondary,
            strokeWidth: 2,
          ),
        };
      });

      // Update map camera if map is ready
      if (_isMapReady) {
        _controller.future.then((controller) {
          controller.animateCamera(
            CameraUpdate.newLatLng(_currentLocation!),
          );
        });
      }
    }
  }

  void _onCurrentLocationSelected(LatLng location) {
    setState(() {
      _currentLocation = location;
      _updateMarkersAndCircle();
    });
  }

  void _onDestinationSelected(LatLng location) {
    setState(() {
      _destination = location;
      // Add a marker for the destination
      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: location,
          infoWindow: const InfoWindow(title: 'Destination'),
        ),
      );
    });
  }

  Future<void> _initializeAudio() async {
    // Set default ringtone
    _selectedRingtone = 'notification.mp3'; // You'll need to add this file to your assets
  }

  Future<void> _selectRingtone() async {
    // This is a simplified version. In a real app, you'd want to use a platform-specific
    // method to access the system ringtones
    final ringtones = [
      'notification.mp3',
      'alarm.mp3',
      'alert.mp3',
    ];

    final selectedRingtone = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Ringtone'),
        children: ringtones.map((ringtone) {
          return SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context, ringtone);
            },
            child: Text(ringtone),
          );
        }).toList(),
      ),
    );

    if (selectedRingtone != null) {
      setState(() {
        _selectedRingtone = selectedRingtone;
      });

      // Play a preview of the selected ringtone
      await _audioPlayer.play(AssetSource(_selectedRingtone!));
    }
  }

  Future<void> _saveAlarm() async {
    if (_currentLocation == null) return;

    final alarm = Alarm(
      id: _editingAlarm?.id ?? const Uuid().v4(),
      name: _destinationController.text,
      destination: _currentLocation!,
      radius: _radius,
      isActive: _editingAlarm?.isActive ?? false,
      ringtonePath: _selectedRingtone,
    );

    if (_editingAlarm != null) {
      await _alarmManager.updateAlarm(alarm);
    } else {
      await _alarmManager.addAlarm(alarm);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Alarm'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                LocationAutocomplete(
                  controller: _currentLocationController,
                  label: 'Current Location',
                  prefixIcon: Icons.location_on,
                  onLocationSelected: _onCurrentLocationSelected,
                ),
                const SizedBox(height: 16),
                LocationAutocomplete(
                  controller: _destinationController,
                  label: 'Destination',
                  prefixIcon: Icons.place,
                  onLocationSelected: _onDestinationSelected,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Radius: '),
                    Expanded(
                      child: Slider(
                        value: _radius,
                        min: 50,
                        max: 1000,
                        divisions: 19,
                        label: '${_radius.round()}m',
                        onChanged: (value) {
                          setState(() {
                            _radius = value;
                            _updateMarkersAndCircle();
                          });
                        },
                      ),
                    ),
                    Text('${_radius.round()}m'),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _selectRingtone,
                  icon: const Icon(Icons.music_note),
                  label: Text(_selectedRingtone ?? 'Set Ringtone'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                // Default map view (shows when Google Maps is not ready)
                if (!_isMapReady && _currentLocation != null)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_on, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Current Location:\nLat: ${_currentLocation!.latitude.toStringAsFixed(6)}\nLng: ${_currentLocation!.longitude.toStringAsFixed(6)}',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                // Google Maps view
                if (_currentLocation != null)
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _currentLocation!,
                      zoom: 15,
                    ),
                    circles: _circles,
                    markers: _markers,
                    onMapCreated: (GoogleMapController controller) {
                      _controller.complete(controller);
                      setState(() => _isMapReady = true);
                    },
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    mapType: MapType.normal,
                    zoomControlsEnabled: true,
                    zoomGesturesEnabled: true,
                    compassEnabled: true,
                    onCameraMove: (CameraPosition position) {
                      // Update current location when map is moved
                      if (_isMapReady) {
                        setState(() {
                          _currentLocation = position.target;
                          _updateMarkersAndCircle();
                        });
                      }
                    },
                  ),
                // Loading indicator
                if (_currentLocation == null)
                  const Center(child: CircularProgressIndicator()),
                // Error message if map fails to load
                if (_isMapError)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Card(
                      color: Colors.red.shade100,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Map failed to load. Showing coordinates instead.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red.shade900),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveAlarm,
        backgroundColor: Theme.of(context).colorScheme.secondary,
        icon: const Icon(Icons.save),
        label: const Text('Save Alarm'),
      ),
    );
  }

  @override
  void dispose() {
    _currentLocationController.dispose();
    _destinationController.dispose();
    _audioPlayer.dispose();
    _locationSubscription?.cancel();
    super.dispose();
  }
} 