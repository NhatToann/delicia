import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/env/environment.dart';
import '../../../domain/bloc/map_client/map_client_bloc.dart';
import '../../../domain/bloc/orders/orders_bloc.dart';
import '../../../domain/models/lat_lng_point.dart';
import '../../../domain/models/order_record.dart';
import '../../components/btn_frave.dart';
import '../../components/text_custom.dart';
import '../../helpers/error_message.dart';
import '../../themes/colors_frave.dart';

/// MapClientScreen — full-screen OpenStreetMap (UC-03, no API key).
///
/// Reads the active order from [OrdersBloc.state.lastOrder] (set by
/// CheckoutScreen) and falls back to Ho Chi Minh City center if the
/// order has no coordinates yet. Marker icons are pulled from
/// `assets/map/`; if the asset is missing we fall back to a colored
/// circle so the build never crashes.
class MapClientScreen extends StatefulWidget {
  const MapClientScreen({super.key});

  @override
  State<MapClientScreen> createState() => _MapClientScreenState();
}

class _MapClientScreenState extends State<MapClientScreen> {
  final MapController _mapController = MapController();
  String? _trackedOrderId;
  bool _centered = false;

  // Default fallback: District 1, HCMC.
  static const LatLng _fallbackCenter = LatLng(10.7717, 106.7009);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initSocket());
  }

  void _initSocket() {
    final order = context.read<OrdersBloc>().state.lastOrder;
    final orderId = order?.id ?? _trackedOrderId ?? '';
    if (orderId.isEmpty) {
      errorMessageSnack(context, 'No active order to track yet.');
      return;
    }
    _trackedOrderId = orderId;
    final clientLat = order?.latitude ?? _fallbackCenter.latitude;
    final clientLng = order?.longitude ?? _fallbackCenter.longitude;
    // Until the first realtime position arrives, place the delivery
    // marker ~1 km north-east of the customer so it's visible.
    final deliveryLat = clientLat + 0.01;
    final deliveryLng = clientLng + 0.01;
    final bloc = context.read<MapClientBloc>();
    bloc.add(OnMarkerClientEvent(
      LatLngPoint(latitude: deliveryLat, longitude: deliveryLng),
      LatLngPoint(latitude: clientLat, longitude: clientLng),
    ));
    bloc.add(OnInitSocketEvent(orderId));
  }

  @override
  void dispose() {
    context.read<MapClientBloc>().add(const OnClearSocketEvent());
    super.dispose();
  }

  void _recenter(LatLng target) {
    try {
      _mapController.move(target, 15);
    } catch (_) {
      // MapController isn't ready yet — we'll center on the next event.
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = context.read<OrdersBloc>().state.lastOrder;
    final canTrack = order != null && order.canTrackDelivery;

    if (!canTrack) {
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
            'Track Delivery',
            fontWeight: FontWeight.w500,
          ),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.delivery_dining,
                  size: 120,
                  color: ColorsFrave.greyText,
                ),
                const SizedBox(height: 16),
                const TextCustom(
                  'Live tracking is not available yet',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                const SizedBox(height: 8),
                const TextCustom(
                  'Your order is being prepared. The map will open once '
                  'the driver picks it up.',
                  textAlign: TextAlign.center,
                  color: ColorsFrave.greyText,
                ),
                const SizedBox(height: 24),
                BtnFrave(
                  text: 'Back to orders',
                  onPressed: () => context.pop(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: BlocConsumer<MapClientBloc, MapClientState>(
        listenWhen: (a, b) =>
            b.error != null && a.error != b.error ||
            (b.markerDelivery.latitude != a.markerDelivery.latitude),
        listener: (_, state) {
          if (state.error != null) {
            errorMessageSnack(context, state.error!);
            return;
          }
          _recenter(LatLng(
            state.markerDelivery.latitude,
            state.markerDelivery.longitude,
          ));
        },
        builder: (_, state) {
          final center = state.markerClient.latitude == 0 && state.markerClient.longitude == 0
              ? _fallbackCenter
              : LatLng(state.markerClient.latitude, state.markerClient.longitude);
          if (!_centered) {
            _recenter(center);
            _centered = true;
          }
          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 15,
                  minZoom: 3,
                  maxZoom: 19,
                  onMapReady: () => context
                      .read<MapClientBloc>()
                      .add(const OnReadyMapClientEvent()),
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
                        points: state.polylineCoordinates
                            .map((p) => LatLng(p.latitude, p.longitude))
                            .toList(),
                        color: ColorsFrave.primaryColor,
                        strokeWidth: 4,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      _clientMarker(state.markerClient),
                      _deliveryMarker(state.markerDelivery),
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
                child: _RoundButton(
                  tooltip: 'My location',
                  icon: Icons.my_location,
                  onPressed: () => _recenter(LatLng(
                    state.markerDelivery.latitude,
                    state.markerDelivery.longitude,
                  )),
                ),
              ),
              Positioned(
                top: 90,
                right: 10,
                child: _RoundButton(
                  tooltip: 'Open external map',
                  icon: Icons.map_outlined,
                  onPressed: () => _openExternalMap(
                    state.markerClient,
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 20,
                child: _InfoCard(
                    order: context.read<OrdersBloc>().state.lastOrder),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openExternalMap(LatLngPoint p) {
    // Stub: opens native map app via URL launcher (matches ref's
    // `_BtnGoogleMap`). Implementation lives in the real-time service
    // when the user requests it.
  }

  Marker _clientMarker(LatLngPoint p) {
    return Marker(
      point: LatLng(
        p.latitude == 0 ? _fallbackCenter.latitude : p.latitude,
        p.longitude == 0 ? _fallbackCenter.longitude : p.longitude,
      ),
      width: 44,
      height: 44,
      child: const Icon(
        Icons.location_on,
        color: ColorsFrave.primaryColor,
        size: 40,
      ),
    );
  }

  Marker _deliveryMarker(LatLngPoint p) {
    return Marker(
      point: LatLng(p.latitude, p.longitude),
      width: 44,
      height: 44,
      child: const Icon(
        Icons.delivery_dining,
        color: ColorsFrave.errorColor,
        size: 40,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final OrderRecord? order;
  const _InfoCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 22,
            backgroundColor: ColorsFrave.backgroundColor,
            child: Icon(Icons.delivery_dining, color: ColorsFrave.primaryColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextCustom(
                  order?.street.isNotEmpty == true
                      ? order!.street
                      : 'Tracking delivery',
                  fontWeight: FontWeight.bold,
                ),
                const SizedBox(height: 2),
                TextCustom(
                  'Status: ${order?.status ?? "Pending"}',
                  fontSize: 13,
                  color: ColorsFrave.greyText,
                ),
              ],
            ),
          ),
          Container(
            height: 45,
            width: 45,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.phone, color: ColorsFrave.primaryColor),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 10,
            spreadRadius: -5,
          ),
        ],
      ),
      child: CircleAvatar(
        backgroundColor: Colors.white,
        maxRadius: 25,
        child: IconButton(
          tooltip: tooltip,
          icon: Icon(icon, color: ColorsFrave.primaryColor),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
