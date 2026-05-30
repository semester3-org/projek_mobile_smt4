import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationViewPage extends StatefulWidget {
  const LocationViewPage({
    super.key,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.title = 'Lokasi Tujuan',
    this.primaryColor = const Color(0xFF2563EB),
  });

  final String address;
  final double latitude;
  final double longitude;
  final String title;
  final Color primaryColor;

  @override
  State<LocationViewPage> createState() => _LocationViewPageState();
}

class _LocationViewPageState extends State<LocationViewPage> {
  final MapController _mapController = MapController();
  LatLng? _currentPoint;
  bool _loadingCurrentLocation = false;

  LatLng get _destination => LatLng(widget.latitude, widget.longitude);

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    setState(() => _loadingCurrentLocation = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() {
        _currentPoint = LatLng(position.latitude, position.longitude);
      });
      _focusRoute();
    } catch (_) {
      // Map still works with the destination marker only.
    } finally {
      if (mounted) setState(() => _loadingCurrentLocation = false);
    }
  }

  void _focusDestination() {
    _mapController.move(_destination, 16);
  }

  void _focusRoute() {
    final current = _currentPoint;
    if (current == null) {
      _focusDestination();
      return;
    }
    final center = LatLng(
      (current.latitude + _destination.latitude) / 2,
      (current.longitude + _destination.longitude) / 2,
    );
    final distanceKm = _distanceKm;
    final zoom = distanceKm == null
        ? 15.0
        : distanceKm < 2
            ? 14.0
            : distanceKm < 8
                ? 12.5
                : 11.0;
    _mapController.move(center, zoom);
  }

  double? get _distanceKm {
    final current = _currentPoint;
    if (current == null) return null;
    final meters = Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      _destination.latitude,
      _destination.longitude,
    );
    return meters / 1000;
  }

  String get _etaLabel {
    final distance = _distanceKm;
    if (distance == null) return '';
    final minutes = ((distance / 18) * 60).ceil().clamp(5, 120);
    return '$minutes mnt';
  }

  @override
  Widget build(BuildContext context) {
    final distance = _distanceKm;
    final markers = <Marker>[
      Marker(
        point: _destination,
        width: 52,
        height: 52,
        child: const Icon(
          Icons.location_pin,
          color: Color(0xFFE5484D),
          size: 50,
        ),
      ),
      if (_currentPoint != null)
        Marker(
          point: _currentPoint!,
          width: 42,
          height: 42,
          child: Icon(
            Icons.my_location_rounded,
            color: widget.primaryColor,
            size: 34,
          ),
        ),
    ];

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
              initialCenter: _destination,
              initialZoom: 16,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.projek_mobile',
              ),
              if (_currentPoint != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [_currentPoint!, _destination],
                      color: widget.primaryColor.withValues(alpha: 0.72),
                      strokeWidth: 4,
                    ),
                  ],
                ),
              MarkerLayer(markers: markers),
            ],
          ),
          Positioned(
            right: 16,
            top: 16,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'view-current-location',
                  onPressed:
                      _loadingCurrentLocation ? null : _loadCurrentLocation,
                  backgroundColor: Colors.white,
                  foregroundColor: widget.primaryColor,
                  child: _loadingCurrentLocation
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: 'view-destination-location',
                  onPressed: _focusDestination,
                  backgroundColor: Colors.white,
                  foregroundColor: widget.primaryColor,
                  child: const Icon(Icons.place_outlined),
                ),
              ],
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.local_shipping_outlined,
                          color: widget.primaryColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.address.trim().isEmpty
                              ? 'Lokasi tujuan'
                              : widget.address,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF172033),
                            fontWeight: FontWeight.w800,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (distance != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _MapMetric(
                          icon: Icons.route_outlined,
                          label: '${distance.toStringAsFixed(1)} km',
                        ),
                        const SizedBox(width: 10),
                        _MapMetric(
                          icon: Icons.schedule_rounded,
                          label: _etaLabel,
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _focusRoute,
                      icon: const Icon(Icons.center_focus_strong_rounded),
                      label: const Text('Fokus Lokasi'),
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

class _MapMetric extends StatelessWidget {
  const _MapMetric({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F7FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD7E8FF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF0B66B7)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF0B4E8A),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
