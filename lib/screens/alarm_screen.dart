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
  bool _hasLocationPermission = false;
  DateTime? _appLoadStartTime;
  DateTime? _mapLoadStartTime;

  @override
  void initState() {
    super.initState();
    _appLoadStartTime = DateTime.now();
    debugPrint('🗺️ AlarmScreen: App load started at ${_appLoadStartTime}');
    
    // Defer initialization slightly to avoid blocking main thread
    // This helps iOS process authorization callbacks properly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLocation();
      _initializeAudio();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load alarm from arguments if editing (can't access route in initState)
    if (_editingAlarm == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Alarm) {
        _editingAlarm = args;
        setState(() {
          _destination = args.destination;
          _destinationController.text = args.name;
          _radius = args.radius;
          _selectedRingtone = args.ringtonePath;
        });
        // Update markers and circle when editing an alarm
        _updateMarkersAndCircle();
      }
    }
  }

  Future<void> _initializeLocation() async {
    try {
      final locationInitStart = DateTime.now();
      debugPrint('📍 AlarmScreen: Starting location initialization...');
      
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

      // Location permission granted - enable map to show
      final locationInitTime = DateTime.now().difference(locationInitStart);
      debugPrint('📍 AlarmScreen: Location permission granted in ${locationInitTime.inMilliseconds}ms');
      
      if (mounted) {
        setState(() {
          _hasLocationPermission = true;
        });
      }

      // Get initial location asynchronously (don't block map loading)
      // Wait a bit for location services to be ready, then try to get location
      Future.delayed(const Duration(milliseconds: 500), () {
        _locationService.getCurrentLocation().then((location) {
          if (location != null && mounted) {
            setState(() {
              _currentLocation = location;
              _updateMarkersAndCircle();
            });
            debugPrint('📍 AlarmScreen: Initial location obtained: ${location.latitude}, ${location.longitude}');
            
            // Center map on current location once we have it
            if (_isMapReady) {
              _controller.future.then((controller) {
                controller.animateCamera(
                  CameraUpdate.newLatLngZoom(location, 15.0),
                );
                debugPrint('🗺️ AlarmScreen: Map centered on current location');
              });
            }
          } else {
            debugPrint('📍 AlarmScreen: Location is null, will wait for location stream');
          }
        }).catchError((error) {
          debugPrint('📍 AlarmScreen: Error getting initial location: $error');
          debugPrint('📍 AlarmScreen: Will rely on location stream for updates');
        });
      });

      // Start location tracking to enable the blue dot
      await _locationService.startTracking();

      // Set up location stream
      _locationSubscription = _locationService.locationStream.listen(
        (location) {
          if (mounted) {
            debugPrint('📍 AlarmScreen: Location updated via stream: ${location.latitude}, ${location.longitude}');
            setState(() {
              _currentLocation = location;
              _updateMarkersAndCircle();
            });
            
            // Center map on current location if it's the first update
            if (_isMapReady && _currentLocation != null) {
              _controller.future.then((controller) {
                controller.animateCamera(
                  CameraUpdate.newLatLngZoom(location, 15.0),
                );
                debugPrint('🗺️ AlarmScreen: Map centered on current location from stream');
              });
            }
          }
        },
        onError: (error) {
          debugPrint('📍 AlarmScreen: Location stream error: $error');
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
    setState(() {
      _markers = {};
      _circles = {};

      // Only add destination marker and circle if destination is set
      // The big blue dot (myLocationEnabled) will show current location automatically
      if (_destination != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('destination'),
            position: _destination!,
            infoWindow: const InfoWindow(title: 'Destination'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
        );

        // Add circle around destination
        _circles.add(
          Circle(
            circleId: const CircleId('alarm_radius'),
            center: _destination!,
            radius: _radius,
            fillColor: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
            strokeColor: Theme.of(context).colorScheme.secondary,
            strokeWidth: 2,
          ),
        );

        // Update map camera to show both current location and destination
        if (_isMapReady && _currentLocation != null) {
          _controller.future.then((controller) {
            // Create bounds to show both locations
            final bounds = LatLngBounds(
              southwest: LatLng(
                _currentLocation!.latitude < _destination!.latitude 
                    ? _currentLocation!.latitude 
                    : _destination!.latitude,
                _currentLocation!.longitude < _destination!.longitude 
                    ? _currentLocation!.longitude 
                    : _destination!.longitude,
              ),
              northeast: LatLng(
                _currentLocation!.latitude > _destination!.latitude 
                    ? _currentLocation!.latitude 
                    : _destination!.latitude,
                _currentLocation!.longitude > _destination!.longitude 
                    ? _currentLocation!.longitude 
                    : _destination!.longitude,
              ),
            );
            controller.animateCamera(
              CameraUpdate.newLatLngBounds(bounds, 100),
            );
          });
        } else if (_isMapReady) {
          // If no current location yet, just focus on destination
          _controller.future.then((controller) {
            controller.animateCamera(
              CameraUpdate.newLatLng(_destination!),
            );
          });
        }
      } else if (_currentLocation != null && _isMapReady) {
        // If no destination, focus on current location
        _controller.future.then((controller) {
          controller.animateCamera(
            CameraUpdate.newLatLng(_currentLocation!),
          );
        });
      }
    });
  }


  void _onDestinationSelected(LatLng location) {
    setState(() {
      _destination = location;
      _updateMarkersAndCircle();
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
    // Validate that both current location and destination are set
    if (_currentLocation == null) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Location Required'),
            content: const Text(
              'Please wait for your current location to be detected. '
              'Make sure location services are enabled.',
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

    if (_destination == null) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Destination Required'),
            content: const Text('Please select a destination for the alarm.'),
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

    // Save alarm with both current location and destination coordinates
    final alarm = Alarm(
      id: _editingAlarm?.id ?? const Uuid().v4(),
      name: _destinationController.text.isEmpty
          ? 'Alarm to ${_destination!.latitude.toStringAsFixed(4)}, ${_destination!.longitude.toStringAsFixed(4)}'
          : _destinationController.text,
      initialLocation: _editingAlarm?.initialLocation ?? _currentLocation!, // Preserve original or use current
      destination: _destination!, // Save destination coordinates
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
                Row(
                  children: [
                    // Current location coordinates on the left
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _currentLocation != null
                                    ? '${_currentLocation!.latitude.toStringAsFixed(6)}, ${_currentLocation!.longitude.toStringAsFixed(6)}'
                                    : 'Getting location...',
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Destination input on the right
                    Expanded(
                      flex: 3,
                      child: LocationAutocomplete(
                        controller: _destinationController,
                        label: 'Destination',
                        prefixIcon: Icons.place,
                        onLocationSelected: _onDestinationSelected,
                      ),
                    ),
                  ],
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
            child: !_hasLocationPermission
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Requesting location permission...'),
                      ],
                    ),
                  )
                : Builder(
                    builder: (context) {
                      // Track when map widget starts building
                      if (_mapLoadStartTime == null) {
                        _mapLoadStartTime = DateTime.now();
                        debugPrint('🗺️ AlarmScreen: Map widget building started at ${_mapLoadStartTime}');
                      }
                      
                      // Show map as soon as permission is granted, even if location isn't ready
                      // Use destination if available, otherwise use a default location
                      final initialTarget = _destination ?? 
                                          _currentLocation ?? 
                                          _editingAlarm?.destination ?? 
                                          const LatLng(37.7749, -122.4194); // San Francisco default
                      
                      return GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: initialTarget,
                      zoom: 15.0,
                    ),
                    circles: _circles,
                    markers: _markers,
                    onMapCreated: (GoogleMapController controller) async {
                      final mapLoadEnd = DateTime.now();
                      _controller.complete(controller);
                      setState(() => _isMapReady = true);
                      
                      // Log map load time
                      if (_mapLoadStartTime != null) {
                        final mapLoadDuration = mapLoadEnd.difference(_mapLoadStartTime!);
                        debugPrint('🗺️ AlarmScreen: Map loaded successfully in ${mapLoadDuration.inMilliseconds}ms');
                      }
                      
                      // Log total time from app load to map ready
                      if (_appLoadStartTime != null) {
                        final totalLoadDuration = mapLoadEnd.difference(_appLoadStartTime!);
                        debugPrint('🗺️ AlarmScreen: Total time from app load to map ready: ${totalLoadDuration.inMilliseconds}ms');
                      }
                      
                      // Center map on current location when created to ensure blue dot is visible
                      if (_currentLocation != null) {
                        await controller.animateCamera(
                          CameraUpdate.newLatLngZoom(_currentLocation!, 15.0),
                        );
                        debugPrint('🗺️ AlarmScreen: Map centered on current location');
                      } else {
                        // Use a default location if current location not available yet
                        final defaultLocation = _editingAlarm?.destination ?? const LatLng(37.7749, -122.4194); // San Francisco default
                        await controller.animateCamera(
                          CameraUpdate.newLatLngZoom(defaultLocation, 15.0),
                        );
                        debugPrint('🗺️ AlarmScreen: Map centered on default location (waiting for current location)');
                      }
                    },
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    mapType: MapType.normal,
                    zoomControlsEnabled: true,
                    zoomGesturesEnabled: true,
                    compassEnabled: true,
                  );
                    },
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
    _locationService.stopTracking();
    super.dispose();
  }
} 