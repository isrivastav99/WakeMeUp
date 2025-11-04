import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/places_service.dart';

class LocationAutocomplete extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData? prefixIcon;
  final Function(LatLng) onLocationSelected;

  const LocationAutocomplete({
    Key? key,
    required this.controller,
    required this.label,
    this.prefixIcon,
    required this.onLocationSelected,
  }) : super(key: key);

  @override
  State<LocationAutocomplete> createState() => _LocationAutocompleteState();
}

class _LocationAutocompleteState extends State<LocationAutocomplete> {
  List<PlacePrediction> _predictions = [];
  bool _isLoading = false;
  OverlayEntry? _overlayEntry;
  final _placesService = PlacesService();
  final GlobalKey _textFieldKey = GlobalKey();
  Timer? _debounceTimer;
  final Map<String, List<PlacePrediction>> _cache = {};

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _debounceTimer?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _onTextChanged() {
    final query = widget.controller.text.trim();
    
    // Clear previous timer
    _debounceTimer?.cancel();
    
    if (query.isEmpty) {
      _removeOverlay();
      return;
    }
    
    // Minimum 2 characters before making API calls (industry standard)
    if (query.length < 2) {
      _removeOverlay();
      return;
    }
    
    // Check cache first
    if (_cache.containsKey(query)) {
      setState(() {
        _predictions = _cache[query]!;
        _isLoading = false;
      });
      _showOverlay();
      return;
    }
    
    // Debounce API calls - wait 500ms after user stops typing
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      
      setState(() {
        _isLoading = true;
      });

      try {
        final predictions = await _placesService.getPlacePredictions(query);
        
        if (!mounted) return;
        
        // Cache the results
        _cache[query] = predictions;
        
        setState(() {
          _predictions = predictions;
          _isLoading = false;
        });

        if (predictions.isNotEmpty) {
          _showOverlay();
        } else {
          _removeOverlay();
        }
      } catch (e) {
        debugPrint('LocationAutocomplete: Error: $e');
        if (!mounted) return;
        
        setState(() {
          _isLoading = false;
        });
        _removeOverlay();
      }
    });
  }

  void _showOverlay() {
    _removeOverlay();

    // Get the render box of the text field to calculate position
    final RenderBox? renderBox = _textFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final overlay = OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: () => _removeOverlay(), // Dismiss on tap outside
        child: Container(
          color: Colors.transparent, // Invisible overlay covering entire screen
          child: Stack(
            children: [
              // Invisible full-screen tap area
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => _removeOverlay(),
                  child: Container(color: Colors.transparent),
                ),
              ),
              // Actual suggestions dropdown
              Positioned(
                top: position.dy + size.height + 8, // Position below the input field with 8px gap
                left: position.dx,
                right: MediaQuery.of(context).size.width - position.dx - size.width,
                child: GestureDetector(
                  onTap: () {}, // Prevent tap from bubbling up to dismiss
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4, // Max 40% of screen height
                      ),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: _predictions.length,
                        itemBuilder: (context, index) {
                          final prediction = _predictions[index];
                          return ListTile(
                            title: Text(prediction.description),
                            onTap: () => _onPredictionSelected(prediction),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlay);
    _overlayEntry = overlay;
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _onPredictionSelected(PlacePrediction prediction) async {
    widget.controller.text = prediction.description;
    _removeOverlay();

    try {
      final location = await _placesService.getPlaceLocation(prediction.placeId);
      if (location != null) {
        widget.onLocationSelected(location);
      }
    } catch (e) {
      debugPrint('LocationAutocomplete: Error getting location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: _textFieldKey,
      controller: widget.controller,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: widget.prefixIcon != null ? Icon(widget.prefixIcon) : null,
        suffixIcon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
            : null,
      ),
    );
  }
} 