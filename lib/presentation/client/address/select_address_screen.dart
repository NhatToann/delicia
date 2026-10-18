import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/env/environment.dart';
import '../../../domain/models/address.dart';
import '../../components/btn_frave.dart';
import '../../components/text_custom.dart';
import '../../helpers/error_message.dart';
import '../../themes/colors_frave.dart';

/// Result returned to the caller via `context.pop`. The home screen
/// uses this to update the "Deliver to" card.
typedef SelectedAddress = ({Address address});

/// Lets the user pick a delivery address in one of two ways:
///
///   1. Use the device's current GPS location (`geolocator`).
///   2. Tap anywhere on a [FlutterMap] to drop a pin and reverse-
///      geocode that point into a street name (`geocoding`).
///
/// Both paths return the same [Address] so the rest of the app can
/// keep treating "the user's address" as a single thing.
class SelectAddressScreen extends StatefulWidget {
  /// Optional pre-selected location, shown on the map when the
  /// user opens the picker.
  final LatLng? initialCenter;

  const SelectAddressScreen({super.key, this.initialCenter});

  @override
  State<SelectAddressScreen> createState() => _SelectAddressScreenState();
}

class _SelectAddressScreenState extends State<SelectAddressScreen> {
  static const LatLng _fallbackCenter = LatLng(10.7717, 106.7009);

  final MapController _mapController = MapController();

  LatLng? _pickedPoint;
  String _pickedStreet = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _pickedPoint = widget.initialCenter ?? _fallbackCenter;
  }

  // ----- Top option: use device GPS --------------------------------

  Future<void> _useCurrentLocation() async {
    setState(() => _busy = true);
    try {
      final pos = await _resolveCurrentPosition();
      if (!mounted) return;
      final point = LatLng(pos.latitude, pos.longitude);
      final street = await _reverseGeocode(point);
      if (!mounted) return;
      setState(() {
        _pickedPoint = point;
        _pickedStreet = street;
      });
      _mapController.move(point, 16);
    } catch (e) {
      if (!mounted) return;
      errorMessageSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Position> _resolveCurrentPosition() async {
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) {
      throw 'Please enable GPS to use your current location';
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw 'Location permission denied';
    }
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // ----- Bottom option: tap on map ----------------------------------

  Future<void> _onMapTap(TapPosition _, LatLng point) async {
    setState(() => _busy = true);
    try {
      final street = await _reverseGeocode(point);
      if (!mounted) return;
      setState(() {
        _pickedPoint = point;
        _pickedStreet = street;
      });
    } catch (e) {
      if (!mounted) return;
      errorMessageSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String> _reverseGeocode(LatLng point) async {
    try {
      final geocoding = Geocoding();
      final placemarks = await geocoding.placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (placemarks.isEmpty) {
        return '${point.latitude.toStringAsFixed(4)}, '
            '${point.longitude.toStringAsFixed(4)}';
      }
      final p = placemarks.first;
      final parts = <String>[
        if ((p.name ?? '').isNotEmpty) p.name!,
        if ((p.subLocality ?? '').isNotEmpty) p.subLocality!,
        if ((p.locality ?? '').isNotEmpty) p.locality!,
      ];
      final main = parts.join(', ');
      return main.isNotEmpty
          ? main
          : '${point.latitude.toStringAsFixed(4)}, '
              '${point.longitude.toStringAsFixed(4)}';
    } catch (_) {
      // geocoding can fail in restricted regions — fall back to raw
      // coordinates so the user can still submit an address.
      return '${point.latitude.toStringAsFixed(4)}, '
          '${point.longitude.toStringAsFixed(4)}';
    }
  }

  // ----- Confirm ----------------------------------------------------

  void _confirm() {
    final point = _pickedPoint;
    if (point == null) return;
    final address = Address(
      id: 'user-${DateTime.now().millisecondsSinceEpoch}',
      street: _pickedStreet.isEmpty
          ? '${point.latitude.toStringAsFixed(4)}, '
              '${point.longitude.toStringAsFixed(4)}'
          : _pickedStreet,
      reference: 'Selected on map',
      latitude: point.latitude,
      longitude: point.longitude,
    );
    context.pop(address);
  }

  @override
  Widget build(BuildContext context) {
    final center = _pickedPoint ?? _fallbackCenter;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ColorsFrave.darkText),
          onPressed: () => context.pop(),
        ),
        title: const TextCustom(
          'Choose delivery address',
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 14,
              minZoom: 3,
              maxZoom: 19,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: Environment.tileServerUrl,
                userAgentPackageName: 'com.example.delicia',
                maxNativeZoom: 19,
              ),
              if (_pickedPoint != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _pickedPoint!,
                      width: 44,
                      height: 44,
                      child: const Icon(
                        Icons.location_on,
                        color: ColorsFrave.primaryColor,
                        size: 40,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: _HintCard(
              onUseCurrentLocation: _busy ? null : _useCurrentLocation,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomPanel(
              street: _pickedStreet,
              busy: _busy,
              onConfirm: _pickedPoint == null ? null : _confirm,
            ),
          ),
        ],
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  final VoidCallback? onUseCurrentLocation;
  const _HintCard({required this.onUseCurrentLocation});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            const Icon(
              Icons.my_location,
              color: ColorsFrave.primaryColor,
              size: 22,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: TextCustom(
                'Use my current location',
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextButton(
              onPressed: onUseCurrentLocation,
              child: const TextCustom(
                'Use',
                color: ColorsFrave.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  final String street;
  final bool busy;
  final VoidCallback? onConfirm;
  const _BottomPanel({
    required this.street,
    required this.busy,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.place_outlined,
                    color: ColorsFrave.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextCustom(
                      street.isEmpty
                          ? 'Tap on the map to drop a pin'
                          : street,
                      fontWeight: FontWeight.w600,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              BtnFrave(
                text: busy
                    ? 'Locating…'
                    : (onConfirm == null
                        ? 'Pick a location'
                        : 'Use this address'),
                onPressed: onConfirm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
