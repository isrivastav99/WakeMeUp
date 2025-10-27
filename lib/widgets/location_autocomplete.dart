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
  List<Map<String, dynamic>> _predictions = [];
  bool _isLoading = false;
  OverlayEntry? _overlayEntry;
  final _placesService = PlacesService();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _removeOverlay();
    super.dispose();
  }

  void _onTextChanged() async {
    if (widget.controller.text.isEmpty) {
      _removeOverlay();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final predictions = await _placesService.getPlacePredictions(widget.controller.text);
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
      setState(() {
        _isLoading = false;
      });
      _removeOverlay();
    }
  }

  void _showOverlay() {
    _removeOverlay();

    final overlay = OverlayEntry(
      builder: (context) => Positioned(
        top: 100,
        left: 16,
        right: 16,
        child: Material(
          elevation: 4,
          child: ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: _predictions.length,
            itemBuilder: (context, index) {
              final prediction = _predictions[index];
              return ListTile(
                title: Text(prediction['description']),
                onTap: () => _onPredictionSelected(prediction),
              );
            },
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

  Future<void> _onPredictionSelected(Map<String, dynamic> prediction) async {
    widget.controller.text = prediction['description'];
    _removeOverlay();

    try {
      final location = await _placesService.getPlaceLocation(prediction['place_id']);
      if (location != null) {
        widget.onLocationSelected(location);
      }
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
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