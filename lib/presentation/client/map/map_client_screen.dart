import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/env/environment.dart';
import '../../../data/services/map_tile_cache.dart';
import '../../../domain/bloc/auth/auth_bloc.dart';
import '../../../domain/bloc/map_client/map_client_bloc.dart';
import '../../../domain/bloc/orders/orders_bloc.dart';
import '../../../domain/models/lat_lng_point.dart';
import '../../../domain/models/order_record.dart';
import '../../../domain/services/app_failure.dart';
import '../../components/map/driver_card.dart';
import '../../components/map/eta_bar.dart';
import '../../components/map/grab_bottom_sheet.dart';
import '../../components/map/map_attribution.dart';
import '../../components/map/order_timeline.dart';
import '../../components/map/route_polyline_layer.dart';
import '../../helpers/error_message.dart';
import '../../helpers/l10n_extension.dart';
import '../../helpers/navigation_helper.dart';
import '../../themes/colors_frave.dart';

/// MapClientScreen — Grab-style live tracking map (UC-03).
///
/// Renders the configured OSM-derived tiles, the real road route from the
/// courier to the customer (via `RouteService`/OSRM), and a
/// draggable bottom sheet carrying the courier card, the order timeline
/// and the ETA.
///
/// Reads the active order from [OrdersBloc.state.lastOrder] (set by
/// CheckoutScreen) and falls back to Ho Chi Minh City centre if the order
/// has no coordinates yet.
class MapClientScreen extends StatefulWidget {
  const MapClientScreen({super.key});

  @override
  State<MapClientScreen> createState() => _MapClientScreenState();
}

class _MapClientScreenState extends State<MapClientScreen>
    with SingleTickerProviderStateMixin {
  /// Animated wrapper around a [MapController] so the camera glides
  /// between waypoints instead of snapping. `flutter_map` receives the
  /// inner controller via [flutterMapController]; the animated wrapper
  /// only adds the transitions.
  ///
  /// Built in [initState] because [AnimatedMapController.vsync] needs this
  /// State's ticker provider, which isn't available in a field
  /// initializer.
  late final AnimatedMapController _mapController;

  MapController get _flutterMapController => _mapController.mapController;

  final TileProvider _mapTileProvider = MapTileCache.createProvider();
  MapClientBloc? _mapClientBloc;

  final GlobalKey<GrabBottomSheetState> _sheetKey =
      GlobalKey<GrabBottomSheetState>();

  String? _trackedOrderId;
  String? _selectedOrderId;
  bool _centered = false;

  /// Auto-fit cadence. Re-fitting on every GPS ping would fight the
  /// user's own panning, so we only nudge the camera periodically.
  static const Duration _autoFitInterval = Duration(seconds: 5);

  Timer? _autoFitTimer;
  Timer? _simulationTimer;
  StreamSubscription<Position>? _positionSub;
  LatLng? _myLocation;
  bool _locationStarted = false;
  bool _simulationActive = false;

  /// Default fallback: District 1, HCMC.
  static const LatLng _fallbackCenter = LatLng(10.7717, 106.7009);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mapClientBloc ??= context.read<MapClientBloc>();
  }

  @override
  void initState() {
    super.initState();
    _mapController = AnimatedMapController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
      // A new camera move supersedes the in-flight one, so rapid GPS
      // ticks don't queue up into a laggy camera.
      cancelPreviousAnimations: true,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _initSocket());
    _autoFitTimer = Timer.periodic(_autoFitInterval, (_) {
      if (!mounted ||
          _sheetKey.currentState?.isExpanded == true ||
          _trackableOrder(
                context.read<OrdersBloc>().state,
                selectedOrderId: _selectedOrderId,
              ) ==
              null) {
        return;
      }
      _fitToMarkers();
    });
  }

  void _initSocket() {
    if (!mounted) return;
    final orders = context.read<OrdersBloc>();
    final clientId = context.read<AuthBloc>().state.user?.uid ?? '';
    if (clientId.isNotEmpty && orders.state.activeClientId != clientId) {
      orders.add(OnLoadMyOrdersEvent(clientId));
    }
    final order = _trackableOrder(orders.state);
    if (order != null) _startTrackingOrder(order);
    if (!_locationStarted) {
      _locationStarted = true;
      _startCurrentLocation();
    }
  }

  static OrderRecord? _trackableOrder(
    OrdersState state, {
    String? selectedOrderId,
  }) {
    if (selectedOrderId != null) {
      for (final order in state.myOrders) {
        if (order.id == selectedOrderId && order.canTrackDelivery) return order;
      }
      if (state.lastOrder?.id == selectedOrderId &&
          state.lastOrder!.canTrackDelivery) {
        return state.lastOrder;
      }
    }
    for (final order in state.myOrders) {
      if (order.canTrackDelivery) return order;
    }
    final lastOrder = state.lastOrder;
    if (lastOrder != null) {
      for (final order in state.myOrders) {
        if (order.id == lastOrder.id) {
          return order.canTrackDelivery ? order : null;
        }
      }
      if (lastOrder.canTrackDelivery) return lastOrder;
    }
    return null;
  }

  void _startTrackingOrder(OrderRecord order) {
    if (!mounted || _trackedOrderId == order.id) return;
    _trackedOrderId = order.id;
    final bloc = context.read<MapClientBloc>();
    bloc.add(
      OnMarkerClientEvent(
        const LatLngPoint(latitude: 0, longitude: 0),
        LatLngPoint(latitude: order.latitude, longitude: order.longitude),
      ),
    );
    bloc.add(OnInitSocketEvent(order.id));
    _centered = false;
  }

  Future<void> _startCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) errorTextSnack(context, context.l10n.addressEnableGps);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted)
          errorTextSnack(context, context.l10n.addressPermissionDenied);
        return;
      }
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && mounted) {
        _updateMyLocation(LatLng(last.latitude, last.longitude));
      }
      _positionSub =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
            ),
          ).listen((position) {
            if (mounted) {
              _updateMyLocation(LatLng(position.latitude, position.longitude));
            }
          });
      final current = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        _updateMyLocation(LatLng(current.latitude, current.longitude));
      }
    } catch (error) {
      if (mounted) {
        errorMessageSnack(
          context,
          AppFailure(AppFailureCodes.trackingStart, '$error'),
        );
      }
    }
  }

  void _updateMyLocation(LatLng location) {
    final shouldCenter = _myLocation == null;
    setState(() {
      _myLocation = location;
      if (shouldCenter) _centered = false;
    });
  }

  /// Starts a local courier simulation when there is no real trackable
  /// order. A fallback straight route appears immediately; OSRM replaces it
  /// with road geometry if the routing service is reachable.
  void _startRouteSimulation() {
    if (_simulationActive) return;
    final customer = _myLocation ?? _fallbackCenter;
    // Demo pickup point near District 1; OSRM supplies the road route from
    // this restaurant to the customer's actual current position.
    final start = LatLngPoint(
      latitude: customer.latitude + 0.008,
      longitude: customer.longitude - 0.009,
    );
    final destination = LatLngPoint(
      latitude: customer.latitude,
      longitude: customer.longitude,
    );
    final bloc = context.read<MapClientBloc>();

    setState(() => _simulationActive = true);
    _centered = false;
    bloc.add(OnMarkerClientEvent(start, destination));

    // Give the bloc a frame to publish the endpoints before fitting.
    Timer(const Duration(milliseconds: 300), () {
      if (mounted) _fitToMarkers();
    });
  }

  void _beginSimulationOnRoute(List<LatLngPoint> route) {
    if (!_simulationActive || _simulationTimer != null || route.length < 2) {
      return;
    }
    final bloc = context.read<MapClientBloc>();
    final start = bloc.state.markerDelivery;
    final destination = bloc.state.markerClient;
    const steps = 24;
    var step = 0;
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 600), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      step++;
      final progress = (step / steps).clamp(0.0, 1.0).toDouble();
      bloc.add(
        OnMockDeliveryPositionEvent(
          _pointAlongRoute(
            route,
            progress,
            start,
            destination,
          ),
        ),
      );
      if (step >= steps) {
        timer.cancel();
        _simulationTimer = null;
        if (mounted) setState(() {});
      }
    });
  }

  void _stopRouteSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    if (!mounted) return;
    setState(() => _simulationActive = false);
    context.read<MapClientBloc>().add(const OnClearSocketEvent());
  }

  static LatLngPoint _pointAlongRoute(
    List<LatLngPoint> route,
    double progress,
    LatLngPoint start,
    LatLngPoint destination,
  ) {
    final points = route.length > 1 ? route : [start, destination];
    final scaledIndex = progress * (points.length - 1);
    final index = scaledIndex.floor().clamp(0, points.length - 2).toInt();
    final fraction = scaledIndex - index;
    final from = points[index];
    final to = points[index + 1];
    return LatLngPoint(
      latitude: from.latitude + (to.latitude - from.latitude) * fraction,
      longitude: from.longitude + (to.longitude - from.longitude) * fraction,
    );
  }

  @override
  void dispose() {
    _autoFitTimer?.cancel();
    _simulationTimer?.cancel();
    _positionSub?.cancel();
    _mapClientBloc?.add(const OnClearSocketEvent());
    // Disposes the internally-created MapController as well.
    _mapController.dispose();
    super.dispose();
  }

  /// Frames both markers plus the courier trail in the viewport. Skipped
  /// when either endpoint is still unset so we don't zoom to Null Island.
  void _fitToMarkers() {
    if (!mounted) return;
    final state = context.read<MapClientBloc>().state;
    // Route endpoints are included so a long detour stays in frame, but
    // only when we actually have geometry — an empty list would make
    // `LatLngBounds.fromPoints` return nothing.
    final points = <LatLng>[
      if (state.markerClient.latitude != 0 || state.markerClient.longitude != 0)
        LatLng(state.markerClient.latitude, state.markerClient.longitude),
      if (state.markerDelivery.latitude != 0 ||
          state.markerDelivery.longitude != 0)
        LatLng(state.markerDelivery.latitude, state.markerDelivery.longitude),
      if (_myLocation != null) _myLocation!,
      ...state.routePolyline.map((p) => LatLng(p.latitude, p.longitude)),
    ];
    if (points.isEmpty) return;

    try {
      _mapController.animatedFitCamera(
        cameraFit: CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          // Bottom padding leaves room for the bottom sheet + ETA bar.
          padding: const EdgeInsets.fromLTRB(64, 140, 64, 280),
          maxZoom: 16,
        ),
      );
    } catch (_) {
      // The map isn't attached yet (first timer tick can beat layout) —
      // the next tick will pick it up.
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersState = context.watch<OrdersBloc>().state;
    final trackingOrders = ordersState.myOrders
        .where((candidate) => candidate.canTrackDelivery)
        .toList(growable: false);
    final order = _trackableOrder(
      ordersState,
      selectedOrderId: _selectedOrderId,
    );
    final showRoute = order != null || _simulationActive;
    if (order != null && order.id != _trackedOrderId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startTrackingOrder(order);
      });
    }
    return Scaffold(
      body: BlocConsumer<MapClientBloc, MapClientState>(
        listenWhen: (a, b) =>
            (b.error != null && a.error != b.error) ||
            (b.markerDelivery.latitude != a.markerDelivery.latitude) ||
            !identical(a.routePolyline, b.routePolyline),
        listener: (_, state) {
          if (state.error != null) {
            errorMessageSnack(context, state.error!);
          }
          // OSRM may replace the instant straight preview after the first
          // camera fit. Keep the full road geometry visible during a demo.
          if (_simulationActive && state.routePolyline.length > 1) {
            _beginSimulationOnRoute(state.routePolyline);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _simulationActive) _fitToMarkers();
            });
          }
        },
        builder: (context, state) {
          final center =
              _myLocation ??
              (order == null ||
                      (state.markerClient.latitude == 0 &&
                          state.markerClient.longitude == 0)
                  ? _fallbackCenter
                  : LatLng(
                      state.markerClient.latitude,
                      state.markerClient.longitude,
                    ));
          if (!_centered) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              try {
                _flutterMapController.move(center, 15);
                _centered = true;
              } catch (_) {
                // Map still attaching — `onMapReady` will recenter below.
              }
            });
          }

          return Stack(
            children: [
              FlutterMap(
                mapController: _flutterMapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 15,
                  minZoom: 3,
                  maxZoom: 19,
                  backgroundColor: const Color(0xFFF3F0E8),
                  onMapReady: () {
                    context.read<MapClientBloc>().add(
                      const OnReadyMapClientEvent(),
                    );
                    // First reliable opportunity to frame the map — the
                    // post-frame callback above can beat attachment.
                    if (!_centered) {
                      _centered = true;
                      _fitToMarkers();
                    }
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
                  // Breadcrumbs first so the live route paints over them.
                  if (showRoute)
                    BreadcrumbTrailLayer(points: state.polylineCoordinates),
                  if (showRoute)
                    RoutePolylineLayer(
                      points: state.routePolyline,
                      color: ColorsFrave.primaryColor,
                    ),
                  MarkerLayer(
                    markers: [
                      if (showRoute &&
                          (state.markerClient.latitude != 0 ||
                              state.markerClient.longitude != 0))
                        _clientMarker(state.markerClient),
                      if (_myLocation != null && !_simulationActive)
                        _myLocationMarker(_myLocation!),
                      if (showRoute &&
                          (state.markerDelivery.latitude != 0 ||
                              state.markerDelivery.longitude != 0))
                        _courierMarker(state.markerDelivery),
                    ],
                  ),
                ],
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 66,
                left: 10,
                child: const MapAttribution(),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _RoundButton(
                          tooltip: context.l10n.actionBack,
                          icon: Icons.arrow_back,
                          onPressed: () => goBack(context),
                        ),
                        Row(
                          children: [
                            if (trackingOrders.length > 1)
                              PopupMenuButton<String>(
                                tooltip: context.l10n.ordersTitle,
                                icon: const Icon(Icons.receipt_long_outlined),
                                color: Colors.white,
                                onSelected: (orderId) {
                                  final selected = trackingOrders.firstWhere(
                                    (candidate) => candidate.id == orderId,
                                  );
                                  setState(() => _selectedOrderId = orderId);
                                  _startTrackingOrder(selected);
                                },
                                itemBuilder: (context) => [
                                  for (final candidate in trackingOrders)
                                    PopupMenuItem<String>(
                                      value: candidate.id,
                                      child: SizedBox(
                                        width: 220,
                                        child: Text(
                                          candidate.street.isEmpty
                                              ? candidate.id
                                              : candidate.street,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            _RoundButton(
                              tooltip: context.l10n.mapFitRoute,
                              icon: Icons.fit_screen_outlined,
                              onPressed: _fitToMarkers,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_myLocation != null)
                Positioned(
                  right: 16,
                  bottom: MediaQuery.paddingOf(context).bottom + 106,
                  child: _RoundButton(
                    tooltip: context.l10n.mapCurrentLocation,
                    icon: Icons.my_location,
                    onPressed: () {
                      _mapController.animateTo(dest: _myLocation!, zoom: 16);
                    },
                  ),
                ),
              GrabBottomSheet(
                key: _sheetKey,
                // The ETA header and grab handle need room even at the
                // collapsed stop, including on compact-height devices.
                minSize: 0.24,
                initialSize: 0.3,
                snapSizes: const [0.3, 0.56],
                pinnedHeader: order == null && !_simulationActive
                    ? null
                    : Padding(
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
                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: order == null
                        ? [
                            _NoActiveTrackingCard(
                              simulationActive: _simulationActive,
                              onToggleSimulation: _simulationActive
                                  ? _stopRouteSimulation
                                  : _startRouteSimulation,
                              onViewOrders: () => context.go('/client/orders'),
                            ),
                          ]
                        : [
                            DriverCard(
                              driver: state.driver,
                              fallbackSubtitle: _streetLabel(context, order),
                            ),
                            const SizedBox(height: 18),
                            Divider(
                              height: 1,
                              color: ColorsFrave.backgroundColor,
                            ),
                            const SizedBox(height: 18),
                            OrderTimeline(activeStage: state.stage),
                            const SizedBox(height: 8),
                            _DeliveryAddress(order: order),
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

  static String _streetLabel(BuildContext context, OrderRecord? order) {
    final street = order?.street ?? '';
    return street.isEmpty ? context.l10n.mapDeliveringToSavedAddress : street;
  }

  Marker _clientMarker(LatLngPoint p) {
    return Marker(
      point: LatLng(
        p.latitude == 0 ? _fallbackCenter.latitude : p.latitude,
        p.longitude == 0 ? _fallbackCenter.longitude : p.longitude,
      ),
      width: 48,
      height: 48,
      child: const _PulseMarker(
        image: 'assets/map/delivery-destination.png',
        pulseColor: ColorsFrave.errorColor,
      ),
    );
  }

  Marker _courierMarker(LatLngPoint p) {
    if (p.latitude == 0 && p.longitude == 0) {
      // No courier position yet — don't render a pin at Null Island.
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
      child: const _PulseMarker(
        image: 'assets/map/food-delivery-marker.png',
        pulseColor: ColorsFrave.primaryColor,
      ),
    );
  }

  Marker _myLocationMarker(LatLng point) => Marker(
    point: point,
    width: 34,
    height: 34,
    child: Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1687F8),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8)],
      ),
    ),
  );
}

class _NoActiveTrackingCard extends StatelessWidget {
  const _NoActiveTrackingCard({
    required this.simulationActive,
    required this.onToggleSimulation,
    required this.onViewOrders,
  });

  final bool simulationActive;
  final VoidCallback onToggleSimulation;
  final VoidCallback onViewOrders;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.location_searching_rounded,
            size: 38,
            color: ColorsFrave.primaryColor,
          ),
          const SizedBox(height: 10),
          Text(
            context.l10n.mapNoActiveOrder,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ColorsFrave.darkText,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onToggleSimulation,
            icon: Icon(
              simulationActive ? Icons.stop_circle_outlined : Icons.route,
            ),
            label: Text(
              simulationActive
                  ? context.l10n.mapSimulationStop
                  : context.l10n.mapSimulationStart,
            ),
          ),
          const SizedBox(height: 6),
          FilledButton(
            onPressed: onViewOrders,
            style: FilledButton.styleFrom(
              backgroundColor: ColorsFrave.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(context.l10n.mapBackToOrders),
          ),
        ],
      ),
    );
  }
}

/// Courier / customer pin with a soft pulsing halo so the moving marker
/// stands out against the busy map underneath it.
class _PulseMarker extends StatefulWidget {
  final String image;
  final Color pulseColor;

  const _PulseMarker({required this.image, required this.pulseColor});

  @override
  State<_PulseMarker> createState() => _PulseMarkerState();
}

class _PulseMarkerState extends State<_PulseMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // 0 -> 1 fades the halo out while growing it, so the pulse reads
        // as a ripple rather than a blinking blob.
        final t = _controller.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 22 + (28 * t),
              width: 22 + (28 * t),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.pulseColor.withValues(alpha: 0.35 * (1 - t)),
              ),
            ),
            child!,
          ],
        );
      },
        child: Container(
          width: 38,
          height: 38,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: widget.pulseColor, width: 2),
            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 5)],
          ),
          child: ClipOval(
            child: Image.asset(
              widget.image,
              fit: BoxFit.cover,
              // A missing asset shouldn't blank out the whole pin.
              errorBuilder: (_, _, _) => Icon(Icons.location_on, color: widget.pulseColor),
            ),
          ),
        ),
    );
  }
}

/// Drop-off address strip pinned at the bottom of the sheet body.
class _DeliveryAddress extends StatelessWidget {
  final OrderRecord? order;

  const _DeliveryAddress({required this.order});

  @override
  Widget build(BuildContext context) {
    final street = order?.street ?? '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColorsFrave.backgroundColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.home_outlined, color: ColorsFrave.primaryColor),
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
                  street.isEmpty ? context.l10n.mapSavedAddress : street,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
          icon: Icon(icon, color: ColorsFrave.darkText),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
