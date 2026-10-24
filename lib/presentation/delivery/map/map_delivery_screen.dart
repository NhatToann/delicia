import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/env/environment.dart';
import '../../../domain/bloc/map_delivery/map_delivery_bloc.dart';
import '../../../domain/bloc/orders/orders_bloc.dart';
import '../../../domain/models/lat_lng_point.dart';
import '../../../domain/services/realtime_service.dart';
import '../../components/btn_frave.dart';
import '../../components/text_custom.dart';
import '../../helpers/error_message.dart';
import '../../themes/colors_frave.dart';

/// MapDeliveryScreen — full-screen OpenStreetMap shown to the delivery
/// driver while they travel to the customer (UC-03).
///
/// Reads the current GPS position via [Geolocator] and pipes the
/// updates into [MapDeliveryBloc.OnUpdateCurrentLocationEvent]. The
/// bloc then forwards each tick to [RealtimeService.publishPosition]
/// so the client app receives it through the Firebase RTDB listener.
class MapDeliveryScreen extends StatefulWidget {
  final String orderId;
  const MapDeliveryScreen({super.key, required this.orderId});

  @override
  State<MapDeliveryScreen> createState() => _MapDeliveryScreenState();
}

class _MapDeliveryScreenState extends State<MapDeliveryScreen> {
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionSub;
  RealtimeService? _realtime;

  // Default fallback: District 1, HCMC.
  static const LatLng _fallbackCenter = LatLng(10.7717, 106.7009);
  static const double _deliverySeedOffset = 0.01;

  @override
  void initState() {
    super.initState();
    _realtime = RealtimeService();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _startTracking();
      if (!mounted) return;
      final order = context.read<OrdersBloc>().state.lastOrder;
      final clientLat = order?.latitude ?? _fallbackCenter.latitude;
      final clientLng = order?.longitude ?? _fallbackCenter.longitude;
      final deliveryLat = clientLat + _deliverySeedOffset;
      final deliveryLng = clientLng + _deliverySeedOffset;
      context.read<MapDeliveryBloc>().add(
            OnMarkertsDeliveryEvent(
              LatLngPoint(latitude: clientLat, longitude: clientLng),
              LatLngPoint(latitude: deliveryLat, longitude: deliveryLng),
            ),
          );
      context
          .read<MapDeliveryBloc>()
          .add(OnEmitLocationDeliveryEvent(widget.orderId));
    });
  }

  Future<void> _startTracking() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        errorMessageSnack(context, 'Location permission denied');
        return;
      }
      final isServiceOn = await Geolocator.isLocationServiceEnabled();
      if (!isServiceOn) {
        if (!mounted) return;
        errorMessageSnack(context, 'Please enable GPS');
        return;
      }
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((pos) {
        if (!mounted) return;
        context.read<MapDeliveryBloc>().add(
              OnUpdateCurrentLocationEvent(
                DeliveryPositionUpdate(
                  orderId: widget.orderId,
                  latitude: pos.latitude,
                  longitude: pos.longitude,
                ),
              ),
            );
      });
    } catch (e) {
      if (!mounted) return;
      errorMessageSnack(context, 'Failed to start tracking: $e');
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    context.read<MapDeliveryBloc>().add(const OnDisconnectDeliveryEvent());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<MapDeliveryBloc, MapDeliveryState>(
        listenWhen: (a, b) =>
            b.error != null && a.error != b.error ||
            (b.currentLocation.latitude != a.currentLocation.latitude),
        listener: (_, state) {
          if (state.error != null) {
            errorMessageSnack(context, state.error!);
            return;
          }
          if (state.currentLocation.latitude != 0 ||
              state.currentLocation.longitude != 0) {
            try {
              _mapController.move(
                LatLng(
                  state.currentLocation.latitude,
                  state.currentLocation.longitude,
                ),
                16,
              );
            } catch (_) {/* map not ready yet */}
          }
        },
        builder: (_, state) {
          final hasCurrent = state.currentLocation.latitude != 0 ||
              state.currentLocation.longitude != 0;
          final center = hasCurrent
              ? LatLng(state.currentLocation.latitude, state.currentLocation.longitude)
              : _fallbackCenter;
          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 16,
                  minZoom: 3,
                  maxZoom: 19,
                  onMapReady: () => context
                      .read<MapDeliveryBloc>()
                      .add(const OnMapReadyEvent()),
                ),
                children: [
                  TileLayer(
                    urlTemplate: Environment.tileServerUrl,
                    userAgentPackageName: 'com.example.delicia',
                    maxNativeZoom: 19,
                  ),
                  PolylineLayer<Object>(
                    polylines: [
                      Polyline(
                        points: state.polyline
                            .map((p) => LatLng(p.latitude, p.longitude))
                            .toList(),
                        color: ColorsFrave.primaryColor,
                        strokeWidth: 4,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      _selfMarker(state.currentLocation, hasCurrent),
                      _clientMarker(state.markerClient),
                    ],
                  ),
                ],
              ),
              Positioned(
                top: 40,
                left: 10,
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.pop(),
                  ),
                ),
              ),
              Positioned(
                top: 40,
                right: 10,
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                    tooltip: 'My location',
                    icon: const Icon(Icons.my_location,
                        color: ColorsFrave.primaryColor),
                    onPressed: () => _mapController.move(center, 16),
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                top: 100,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TextCustom(
                        'Customer location',
                        fontWeight: FontWeight.bold,
                      ),
                      const SizedBox(height: 4),
                      TextCustom(
                        '${state.markerClient.latitude.toStringAsFixed(4)}, '
                        '${state.markerClient.longitude.toStringAsFixed(4)}',
                        color: ColorsFrave.greyText,
                        fontSize: 13,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 20,
                child: BtnFrave(
                  text: 'Delivered',
                  onPressed: () {
                    context
                        .read<MapDeliveryBloc>()
                        .add(const OnDisconnectDeliveryEvent());
                    context.pop();
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Marker _selfMarker(LatLngPoint p, bool hasLocation) {
    return Marker(
      point: hasLocation
          ? LatLng(p.latitude, p.longitude)
          : _fallbackCenter,
      width: 44,
      height: 44,
      child: const Icon(
        Icons.delivery_dining,
        color: ColorsFrave.primaryColor,
        size: 40,
      ),
    );
  }

  Marker _clientMarker(LatLngPoint p) {
    return Marker(
      point: LatLng(p.latitude, p.longitude),
      width: 44,
      height: 44,
      child: const Icon(
        Icons.location_on,
        color: ColorsFrave.errorColor,
        size: 40,
      ),
    );
  }
}
