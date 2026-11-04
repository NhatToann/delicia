import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/env/environment.dart';
import '../../../data/services/map_tile_cache.dart';
import '../../../domain/bloc/driver_orders/driver_orders_bloc.dart';
import '../../../domain/models/delivery_status.dart';
import '../../../domain/models/order_record.dart';
import '../../components/text_custom.dart';
import '../../../domain/bloc/map_delivery/map_delivery_bloc.dart';
import '../../../domain/bloc/orders/orders_bloc.dart';
import '../../../domain/models/hcmc_location.dart';
import '../../../domain/models/lat_lng_point.dart';
import '../../../domain/services/app_failure.dart';
import '../../../domain/services/realtime_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../components/map/eta_bar.dart';
import '../../components/map/grab_bottom_sheet.dart';
import '../../components/map/map_attribution.dart';
import '../../components/map/order_timeline.dart';
import '../../components/map/route_polyline_layer.dart';
import '../../helpers/error_message.dart';
import '../../helpers/l10n_extension.dart';
import '../../helpers/navigation_helper.dart';
import '../../themes/colors_frave.dart';

/// MapDeliveryScreen — driver-facing live map (UC-03).
///
/// Reads the current GPS position via [Geolocator] and pipes the updates
/// into [MapDeliveryBloc.OnUpdateCurrentLocationEvent]. The bloc forwards
/// each tick to [RealtimeService.publishPosition] so the client app
/// receives it through the Firebase RTDB listener, and separately keeps
/// the OSRM road route between the driver and the customer up to date.
///
/// The sheet mirrors the client's Grab-style layout but shows the driver's
/// own controls — the address they're heading to, the order progress, and
/// the "Delivered" confirm button.
class MapDeliveryScreen extends StatefulWidget {
  final String orderId;
  const MapDeliveryScreen({super.key, required this.orderId});

  @override
  State<MapDeliveryScreen> createState() => _MapDeliveryScreenState();
}

class _MapDeliveryScreenState extends State<MapDeliveryScreen>
    with SingleTickerProviderStateMixin {
  /// See [MapClientScreen] — the animated wrapper needs a ticker provider,
  /// so it can't be built in a field initializer.
  late final AnimatedMapController _mapController;

  MapController get _flutterMapController => _mapController.mapController;

  final TileProvider _mapTileProvider = MapTileCache.createProvider();
  MapDeliveryBloc? _mapDeliveryBloc;

  StreamSubscription<Position>? _positionSub;
  Timer? _autoFitTimer;

  final GlobalKey<GrabBottomSheetState> _sheetKey =
      GlobalKey<GrabBottomSheetState>();

  /// Default fallback: District 1, HCMC.
  static const LatLng _fallbackCenter = LatLng(10.7717, 106.7009);

  /// Auto-fit cadence — matching the client's so both ends of the trip
  /// frame the same way.
  static const Duration _autoFitInterval = Duration(seconds: 5);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mapDeliveryBloc ??= context.read<MapDeliveryBloc>();
  }

  @override
  void initState() {
    super.initState();
    _mapController = AnimatedMapController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
      cancelPreviousAnimations: true,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _startTracking();
      if (!mounted) return;
      OrderRecord? order;
      final deliveryState = context.read<DriverOrdersBloc>().state;
      for (final o in deliveryState.assignedOrders) {
        if (o.id == widget.orderId) {
          order = o;
          break;
        }
      }
      order ??= context.read<OrdersBloc>().state.lastOrder;

      final clientLat = (order != null &&
              HcmcLocation.isInHcmc(order.latitude, order.longitude))
          ? order.latitude
          : _fallbackCenter.latitude;
      final clientLng = (order != null &&
              HcmcLocation.isInHcmc(order.latitude, order.longitude))
          ? order.longitude
          : _fallbackCenter.longitude;
      final deliveryLat = Environment.restaurantLatitude;
      final deliveryLng = Environment.restaurantLongitude;
      context.read<MapDeliveryBloc>().add(
        OnMarkertsDeliveryEvent(
          LatLngPoint(latitude: clientLat, longitude: clientLng),
          LatLngPoint(latitude: deliveryLat, longitude: deliveryLng),
        ),
      );
      context.read<MapDeliveryBloc>().add(
        OnEmitLocationDeliveryEvent(widget.orderId),
      );
      // Watch where the *client* is so the destination marker is live.
      context.read<MapDeliveryBloc>().add(
        OnWatchClientLocationEvent(widget.orderId),
      );
    });
    _autoFitTimer = Timer.periodic(_autoFitInterval, (_) {
      if (!mounted || _sheetKey.currentState?.isExpanded == true) return;
      _fitToRoute();
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
        errorTextSnack(context, context.l10n.addressPermissionDenied);
        return;
      }
      final isServiceOn = await Geolocator.isLocationServiceEnabled();
      if (!isServiceOn) {
        if (!mounted) return;
        errorTextSnack(context, context.l10n.addressEnableGps);
        return;
      }
      _positionSub =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
            ),
          ).listen((pos) {
            if (!mounted) return;
            final loc = HcmcLocation.sanitize(pos.latitude, pos.longitude);
            context.read<MapDeliveryBloc>().add(
              OnUpdateCurrentLocationEvent(
                DeliveryPositionUpdate(
                  orderId: widget.orderId,
                  latitude: loc.latitude,
                  longitude: loc.longitude,
                ),
              ),
            );
          });
    } catch (e) {
      if (!mounted) return;
      errorMessageSnack(
        context,
        AppFailure(AppFailureCodes.trackingStart, '$e'),
      );
    }
  }

  /// Frames the driver and the drop-off point together, including the live
  /// route so a detour stays in view.
  void _fitToRoute() {
    if (!mounted) return;
    final state = context.read<MapDeliveryBloc>().state;
    final client = LatLng(
      state.markerClient.latitude,
      state.markerClient.longitude,
    );
    if (client.latitude == 0 && client.longitude == 0) return;

    final points = <LatLng>[client];
    if (state.currentLocation.latitude != 0 &&
        state.currentLocation.longitude != 0) {
      points.add(
        LatLng(state.currentLocation.latitude, state.currentLocation.longitude),
      );
    }
    points.addAll(
      state.routePolyline.map((p) => LatLng(p.latitude, p.longitude)),
    );

    try {
      _mapController.animatedFitCamera(
        cameraFit: CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.fromLTRB(64, 140, 64, 300),
          maxZoom: 17,
        ),
      );
    } catch (_) {
      // Map not attached yet — the next timer tick will retry.
    }
  }

  @override
  void dispose() {
    _autoFitTimer?.cancel();
    _positionSub?.cancel();
    _mapDeliveryBloc?.add(const OnDisconnectDeliveryEvent());
    _mapController.dispose();
    context.read<MapDeliveryBloc>().add(const OnUnwatchClientLocationEvent());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    OrderRecord? order;
    final deliveryState = context.watch<DriverOrdersBloc>().state;
    for (final o in deliveryState.assignedOrders) {
      if (o.id == widget.orderId) {
        order = o;
        break;
      }
    }
    order ??= context.read<OrdersBloc>().state.lastOrder;

    return Scaffold(
      body: BlocConsumer<MapDeliveryBloc, MapDeliveryState>(
        listenWhen: (a, b) =>
            (b.error != null && a.error != b.error) ||
            (b.currentLocation.latitude != a.currentLocation.latitude),
        listener: (_, state) {
          if (state.error != null) {
            errorMessageSnack(context, state.error!);
          }
        },
        builder: (context, state) {
          final hasCurrent =
              state.currentLocation.latitude != 0 ||
              state.currentLocation.longitude != 0;
          final center = hasCurrent
              ? LatLng(
                  state.currentLocation.latitude,
                  state.currentLocation.longitude,
                )
              : _fallbackCenter;

          return Stack(
            children: [
              FlutterMap(
                mapController: _flutterMapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 16,
                  minZoom: 3,
                  maxZoom: 19,
                  onMapReady: () {
                    context.read<MapDeliveryBloc>().add(
                      const OnMapReadyEvent(),
                    );
                    _fitToRoute();
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: Environment.tileServerUrl,
                    tileProvider: _mapTileProvider,
                    userAgentPackageName: 'com.example.delicia',
                    maxNativeZoom: 19,
                    keepBuffer: 1,
                  ),
                  // Where the driver has already been, drawn dimmed under
                  // the live route.
                  BreadcrumbTrailLayer(points: state.polyline),
                  RoutePolylineLayer(
                    points: state.routePolyline,
                    color: ColorsFrave.secondaryColor,
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
                top: MediaQuery.paddingOf(context).top + 66,
                left: 10,
                child: const MapAttribution(),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _RoundIconButton(
                        icon: Icons.arrow_back,
                        tooltip: context.l10n.actionBack,
                        onPressed: _safeBack,
                      ),
                      _RoundIconButton(
                        icon: Icons.fit_screen_outlined,
                        tooltip: context.l10n.mapFitRoute,
                        onPressed: _fitToRoute,
                      ),
                    ],
                  ),
                ),
              ),
              GrabBottomSheet(
                key: _sheetKey,
                initialSize: 0.3,
                snapSizes: const [0.3, 0.56],
                pinnedHeader: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: EtaBar(
                    etaLabel: etaLabelFor(context.l10n, state.etaMinutes),
                    distanceLabel: state.routeDistanceMeters == null
                        ? null
                        : state.remainingDistanceLabel,
                    isLoading: state.routeDistanceMeters == null,
                    onTap: _sheetKey.currentState?.toggle,
                  ),
                ),
                builder: (context, scrollController) {
                  final customerPhone = order?.receiverPhone?.isNotEmpty == true
                      ? order!.receiverPhone!
                      : (order?.reference.isNotEmpty == true ? order!.reference : '');

                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      _CustomerAddress(
                        street: order?.street ?? '',
                        coordinates: state.markerClient,
                        customerName: order?.receiverName,
                        customerPhone: customerPhone,
                      ),
                      const SizedBox(height: 18),
                      Divider(height: 1, color: ColorsFrave.backgroundColor),
                      const SizedBox(height: 18),
                      OrderTimeline(activeStage: state.stage),
                      const SizedBox(height: 18),
                      _DeliveredButton(onPressed: _confirmDelivered),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _safeBack() {
    if (!mounted) return;
    // No previous screen — fall back to the delivery home placeholder.
    goBack(context, fallback: '/delivery/home');
  }

  /// Stops the realtime broadcast and records delivery completion in the system.
  void _confirmDelivered() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const TextCustom('\u0110\u00e3 giao h\u00e0ng?', fontWeight: FontWeight.bold),
        content: const TextCustom(
          'X\u00e1c nh\u1eadn \u0111\u01a1n h\u00e0ng \u0111\u00e3 \u0111\u01b0\u1ee3c giao \u0111\u1ebfn tay kh\u00e1ch h\u00e0ng?',
          color: ColorsFrave.greyText,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const TextCustom('H\u1ee7y', color: ColorsFrave.greyText),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorsFrave.successColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _executeDeliveryCompletion();
            },
            child: const TextCustom('\u0110\u1ed3ng \u00fd', color: Colors.white),
          ),
        ],
      ),
    );
  }

  void _executeDeliveryCompletion() {
    // 1. Disconnect map updates
    _mapDeliveryBloc?.add(const OnDisconnectDeliveryEvent());

    // 2. Identify current status
    final driverOrdersBloc = context.read<DriverOrdersBloc>();
    final assignedOrders = driverOrdersBloc.state.assignedOrders;
    OrderRecord? matchedOrder;
    for (final o in assignedOrders) {
      if (o.id == widget.orderId) {
        matchedOrder = o;
        break;
      }
    }
    matchedOrder ??= driverOrdersBloc.state.activeOrder ??
        context.read<OrdersBloc>().state.lastOrder;

    final currentStatus = matchedOrder != null
        ? DeliveryStatus.fromString(matchedOrder.status)
        : DeliveryStatus.onTheWay;

    // 3. Update in DeliveryBloc (records status in Firebase Realtime Database)
    driverOrdersBloc.add(
      UpdateOrderStatusEvent(
        orderId: widget.orderId,
        currentStatus: currentStatus,
        targetStatus: DeliveryStatus.delivered,
      ),
    );

    // 4. Update in OrdersBloc for immediate UI reflection
    context.read<OrdersBloc>().add(
      const OnUpdateLastOrderStatusEvent(OrderRecord.statusDelivered),
    );

    _safeBack();
  }

  Marker _selfMarker(LatLngPoint p, bool hasLocation) {
    if (!hasLocation) {
      // No GPS fix yet — hide the pin rather than parking it at Null
      // Island in the Gulf of Guinea.
      return Marker(
        point: _fallbackCenter,
        width: 0,
        height: 0,
        child: const SizedBox.shrink(),
      );
    }
    return Marker(
      point: LatLng(p.latitude, p.longitude),
      width: 48,
      height: 48,
      child: Container(
        decoration: BoxDecoration(
          color: ColorsFrave.secondaryColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8)],
        ),
        child: const Icon(Icons.delivery_dining, color: Colors.white, size: 22),
      ),
    );
  }

  Marker _clientMarker(LatLngPoint p) {
    if (p.latitude == 0 && p.longitude == 0) {
      return Marker(
        point: _fallbackCenter,
        width: 0,
        height: 0,
        child: const SizedBox.shrink(),
      );
    }
    return Marker(
      point: LatLng(p.latitude, p.longitude),
      width: 44,
      height: 44,
      child: Image.asset(
        'assets/map/delivery-destination.png',
        width: 34,
        height: 34,
        errorBuilder: (_, _, _) => const Icon(
          Icons.location_on,
          color: ColorsFrave.errorColor,
          size: 34,
        ),
      ),
    );
  }
}

/// Drop-off card for the driver: street address plus raw coordinates as a
/// fallback when the address string is missing, along with quick customer contact.
class _CustomerAddress extends StatelessWidget {
  final String street;
  final LatLngPoint coordinates;
  final String? customerName;
  final String? customerPhone;

  const _CustomerAddress({
    required this.street,
    required this.coordinates,
    this.customerName,
    this.customerPhone,
  });

  Future<void> _makePhoneCall(String phone) async {
    final uri = Uri.parse('tel:${phone.replaceAll(' ', '')}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  Future<void> _sendSms(String phone) async {
    final uri = Uri.parse('sms:${phone.replaceAll(' ', '')}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final hasCoords = coordinates.latitude != 0 || coordinates.longitude != 0;
    final hasPhone = customerPhone != null && customerPhone!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColorsFrave.backgroundColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: ColorsFrave.primaryColor.withValues(alpha: 0.15),
                child: const Icon(
                  Icons.person,
                  color: ColorsFrave.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextCustom(
                      customerName ?? 'Khách hàng',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    const SizedBox(height: 2),
                    TextCustom(
                      hasPhone ? customerPhone! : 'Khách nhận đơn',
                      color: ColorsFrave.greyText,
                      fontSize: 12,
                    ),
                  ],
                ),
              ),
              if (hasPhone) ...[
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: ColorsFrave.successColor.withValues(alpha: 0.15),
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size(36, 36),
                  ),
                  icon: const Icon(Icons.phone, color: ColorsFrave.successColor, size: 18),
                  tooltip: 'Gọi khách hàng',
                  onPressed: () => _makePhoneCall(customerPhone!),
                ),
                const SizedBox(width: 6),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: ColorsFrave.primaryColor.withValues(alpha: 0.15),
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size(36, 36),
                  ),
                  icon: const Icon(Icons.message, color: ColorsFrave.primaryColor, size: 18),
                  tooltip: 'Gửi tin nhắn SMS',
                  onPressed: () => _sendSms(customerPhone!),
                ),
              ],
            ],
          ),
          const Divider(height: 18),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: ColorsFrave.errorColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.mapDeliverTo,
                      style: const TextStyle(
                        fontSize: 11,
                        color: ColorsFrave.greyText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      street.isNotEmpty
                          ? street
                          : (hasCoords
                              ? '${coordinates.latitude.toStringAsFixed(4)}, '
                                '${coordinates.longitude.toStringAsFixed(4)}'
                              : context.l10n.mapAddressUnavailable),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: ColorsFrave.darkText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeliveredButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _DeliveredButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorsFrave.secondaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          context.l10n.mapDelivered,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _RoundIconButton({
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
          icon: Icon(icon, color: ColorsFrave.darkText),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
