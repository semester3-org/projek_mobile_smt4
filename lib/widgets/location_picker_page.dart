import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class PickedLocation {
  const PickedLocation({
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final String address;
  final double latitude;
  final double longitude;
}

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({
    super.key,
    required this.initialAddress,
    this.initialLatitude,
    this.initialLongitude,
    this.title = 'Pilih Lokasi',
    this.primaryColor = const Color(0xFF2563EB),
  });

  final String initialAddress;
  final double? initialLatitude;
  final double? initialLongitude;
  final String title;
  final Color primaryColor;

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  static const LatLng _defaultCenter = LatLng(-6.200000, 106.816666);

  final MapController _mapController = MapController();
  late LatLng _selectedPoint;
  late String _address;
  bool _loadingAddress = false;
  bool _loadingCurrentLocation = false;

  @override
  void initState() {
    super.initState();
    _selectedPoint = LatLng(
      widget.initialLatitude ?? _defaultCenter.latitude,
      widget.initialLongitude ?? _defaultCenter.longitude,
    );
    _address = widget.initialAddress.trim();
    if (widget.initialLatitude == null || widget.initialLongitude == null) {
      _moveToCurrentLocation();
    } else if (_address.isEmpty) {
      _reverseGeocode(_selectedPoint);
    }
  }

  Future<void> _moveToCurrentLocation() async {
    setState(() => _loadingCurrentLocation = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await _reverseGeocode(_selectedPoint);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        await _reverseGeocode(_selectedPoint);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 12));

      if (!mounted) return;
      final point = LatLng(position.latitude, position.longitude);
      setState(() {
        _selectedPoint = point;
        _address = 'Mencari alamat...';
        _loadingAddress = true;
      });
      _mapController.move(point, 16);
      await _reverseGeocode(point);
    } catch (_) {
      if (mounted) await _reverseGeocode(_selectedPoint);
    } finally {
      if (mounted) setState(() => _loadingCurrentLocation = false);
    }
  }

  Future<void> _selectPoint(LatLng point) async {
    setState(() {
      _selectedPoint = point;
      _loadingAddress = true;
      _address = 'Mencari alamat...';
    });
    await _reverseGeocode(point);
  }

  Future<void> _reverseGeocode(LatLng point) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': point.latitude.toString(),
        'lon': point.longitude.toString(),
      });
      final response = await http.get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'Accept-Language': 'id',
          'User-Agent': 'KosFinder/1.0 (com.example.projek_mobile)',
        },
      ).timeout(const Duration(seconds: 12));

      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final displayName = data['display_name'] as String?;
        setState(() {
          _address = displayName?.trim().isNotEmpty == true
              ? displayName!.trim()
              : _coordinateLabel(point);
          _loadingAddress = false;
        });
        return;
      }
    } catch (_) {
      if (!mounted) return;
    }

    setState(() {
      _address = _coordinateLabel(point);
      _loadingAddress = false;
    });
  }

  String _coordinateLabel(LatLng point) {
    return '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';
  }

  void _saveLocation() {
    Navigator.of(context).pop(
      PickedLocation(
        address: _address.trim().isEmpty
            ? _coordinateLabel(_selectedPoint)
            : _address,
        latitude: _selectedPoint.latitude,
        longitude: _selectedPoint.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.primaryColor;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Color(0xFF172033),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedPoint,
              initialZoom: widget.initialLatitude == null ? 12 : 16,
              onTap: (_, point) => _selectPoint(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.projek_mobile',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedPoint,
                    width: 48,
                    height: 48,
                    child: const Icon(
                      Icons.location_pin,
                      color: Color(0xFFE5484D),
                      size: 46,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            right: 16,
            top: 16,
            child: FloatingActionButton.small(
              heroTag: 'current-location-${widget.title}',
              onPressed:
                  _loadingCurrentLocation ? null : _moveToCurrentLocation,
              backgroundColor: Colors.white,
              foregroundColor: primary,
              child: _loadingCurrentLocation
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _loadingAddress
                            ? Icons.hourglass_top_rounded
                            : Icons.place_outlined,
                        color: primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _address.trim().isEmpty
                              ? _coordinateLabel(_selectedPoint)
                              : _address,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF172033),
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _loadingAddress ? null : _saveLocation,
                      style: FilledButton.styleFrom(
                        backgroundColor: primary,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Gunakan Lokasi Ini'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
