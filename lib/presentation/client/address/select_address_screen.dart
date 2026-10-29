import 'dart:convert';
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/env/environment.dart';
import '../../../data/services/map_tile_cache.dart';
import '../../../domain/models/address.dart';
import '../../../domain/utils/text_normalizer.dart';
import '../../components/btn_frave.dart';
import '../../components/map/map_attribution.dart';
import '../../components/text_custom.dart';
import '../../helpers/error_message.dart';
import '../../helpers/l10n_extension.dart';
import '../../helpers/navigation_helper.dart';
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
  // Prefer Da Nang when GPS or an initial route location is unavailable.
  static const LatLng _fallbackCenter = LatLng(16.0471, 108.2068);
  static const String _historyKey = 'delicia.address.search.history.v1';
  static DateTime? _lastGeocoderRequestAt;

  final MapController _mapController = MapController();
  final TileProvider _mapTileProvider = MapTileCache.createProvider();
  final TextEditingController _searchController = TextEditingController();

  LatLng? _pickedPoint;
  LatLng? _searchOrigin;
  String _pickedStreet = '';
  String _pickedDetails = '';
  List<_PlaceResult> _searchResults = const [];
  List<_PlaceResult> _vietnamPlaces = const [];
  List<Address> _history = const [];
  _SearchArea? _searchArea;
  bool _searchAreaResolved = false;
  bool _showHistory = false;
  bool _searching = false;
  String? _searchError;
  bool _busy = false;
  Timer? _searchDebounce;
  int _searchRequestId = 0;

  @override
  void initState() {
    super.initState();
    _pickedPoint = widget.initialCenter ?? _fallbackCenter;
    _searchOrigin = _pickedPoint;
    _loadHistory();
    _loadVietnamPlaces();
  }

  Future<void> _loadVietnamPlaces() async {
    try {
      final datasets = await Future.wait([
        rootBundle.loadString('assets/vietnam_places.json'),
        rootBundle.loadString('assets/vietnam_wards.json'),
      ]);
      final rows = <_PlaceResult>[];
      final provinces = jsonDecode(datasets[0]) as Map<String, dynamic>;
      for (final row in (provinces['data'] as List<dynamic>).whereType<Map>()) {
        final place = _PlaceResult.fromAdministrativeUnit(
          Map<String, dynamic>.from(row),
        );
        if (place.point != null) rows.add(place);
      }
      final wards = jsonDecode(datasets[1]) as List<dynamic>;
      for (final row in wards.whereType<Map>()) {
        final place = _PlaceResult.fromAdministrativeUnit(
          Map<String, dynamic>.from(row),
        );
        if (place.point != null) rows.add(place);
      }
      if (mounted) setState(() => _vietnamPlaces = rows);
    } catch (error) {
      debugPrint('[address-search] Could not load Vietnam place data: $error');
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final encoded = preferences.getString(_historyKey);
      if (!mounted || encoded == null) return;
      final rows = jsonDecode(encoded) as List<dynamic>;
      setState(() {
        _history = rows
            .whereType<Map<dynamic, dynamic>>()
            .map((row) => Address.fromMap((row['id'] ?? '').toString(), row))
            .toList(growable: false);
      });
    } catch (_) {
      // Ignore a stale or partially written local history value.
    }
  }

  Future<void> _saveToHistory(Address address) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final next = <Address>[
        address,
        ..._history.where(
          (saved) =>
              (saved.latitude - address.latitude).abs() > 0.00005 ||
              (saved.longitude - address.longitude).abs() > 0.00005,
        ),
      ].take(8).toList(growable: false);
      await preferences.setString(
        _historyKey,
        jsonEncode(
          next.map((saved) => {'id': saved.id, ...saved.toMap()}).toList(),
        ),
      );
      if (mounted) setState(() => _history = next);
    } catch (_) {
      // Address confirmation must still work if local storage is unavailable.
    }
  }

  void _onSearchChanged(String rawQuery) {
    _searchDebounce?.cancel();
    _searchRequestId++;
    final query = rawQuery.trim();
    if (query.length < 2) {
      setState(() {
        _searchResults = const [];
        _searchError = null;
        _searching = false;
      });
      return;
    }
    setState(() {
      _searchResults = const [];
      _searchError = null;
      _showHistory = false;
    });
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      _searchPlaces(query);
    });
  }

  Future<void> _searchPlaces(String rawQuery, {bool pinFirst = false}) async {
    final query = rawQuery.trim();
    if (query.isEmpty || _busy) return;
    final requestId = ++_searchRequestId;
    final route = ModalRoute.of(context);
    setState(() {
      _searching = true;
      _showHistory = false;
      _searchResults = const [];
      _searchError = null;
    });
    try {
      await _ensureSearchArea();
      var places = <_PlaceResult>[];
      var providerFailed = false;
      final plainQuery = collapseWhitespace(stripDiacritics(query));
      try {
        places = await _searchPhoton(_queryWithSearchArea(query));
      } catch (error) {
        debugPrint('[address-search] Photon lookup failed: $error');
        providerFailed = true;
      }
      // Photon can miss Vietnamese names when the query contains tone marks.
      // Retry the same provider without diacritics for both autocomplete and
      // explicit searches before falling back to the slower Nominatim search.
      if (places.isEmpty && plainQuery != query.toLowerCase()) {
        try {
          places = await _searchPhoton(_queryWithSearchArea(plainQuery));
        } catch (error) {
          debugPrint('[address-search] Plain Photon retry failed: $error');
          providerFailed = true;
        }
      }
      if (places.isEmpty) {
        try {
          places = await _searchPhoton(
            _queryWithSearchArea(query),
            nearbyOnly: false,
          );
        } catch (error) {
          debugPrint('[address-search] Wider Photon lookup failed: $error');
          providerFailed = true;
        }
      }
      if (places.isEmpty && plainQuery != query.toLowerCase()) {
        try {
          places = await _searchPhoton(
            _queryWithSearchArea(plainQuery),
            nearbyOnly: false,
          );
        } catch (error) {
          debugPrint(
            '[address-search] Wider plain Photon lookup failed: $error',
          );
          providerFailed = true;
        }
      }
      if (places.isEmpty && pinFirst) {
        try {
          places = await _searchNominatim(_queryWithSearchArea(query));
        } catch (error) {
          debugPrint('[address-search] Nominatim lookup failed: $error');
          providerFailed = true;
        }
      }
      if (places.isEmpty && pinFirst && plainQuery != query.toLowerCase()) {
        try {
          places = await _searchNominatim(_queryWithSearchArea(plainQuery));
        } catch (error) {
          debugPrint('[address-search] Plain Nominatim retry failed: $error');
          providerFailed = true;
        }
      }
      if (!mounted ||
          requestId != _searchRequestId ||
          route?.isCurrent == false) {
        return;
      }
      if (places.isEmpty) places = _searchLocalVietnamPlaces(query);
      final origin = _searchOrigin ?? _pickedPoint;
      places = [...places]
        ..sort((a, b) {
          final distanceA = origin == null || a.point == null
              ? double.infinity
              : const Distance().as(LengthUnit.Meter, origin, a.point!);
          final distanceB = origin == null || b.point == null
              ? double.infinity
              : const Distance().as(LengthUnit.Meter, origin, b.point!);
          final distanceOrder = distanceA.compareTo(distanceB);
          if (distanceOrder != 0) return distanceOrder;
          if (a.isStreetAddress == b.isStreetAddress) return 0;
          return a.isStreetAddress ? -1 : 1;
        });
      final emptyMessage = !pinFirst
          ? context.l10n.addressSearchTrySubmit
          : providerFailed
          ? context.l10n.addressSearchFailed
          : context.l10n.addressSearchNoResults;
      setState(() {
        _searchResults = places;
        _searchError = places.isEmpty ? emptyMessage : null;
      });
      if (places.isNotEmpty && pinFirst) {
        _selectPlaceResult(places.first, preserveSuggestions: true);
      }
    } catch (error, stackTrace) {
      debugPrint('[address-search] Lookup failed: $error\n$stackTrace');
      if (mounted &&
          requestId == _searchRequestId &&
          route?.isCurrent != false) {
        setState(() => _searchError = context.l10n.addressSearchFailed);
      }
    } finally {
      if (mounted &&
          requestId == _searchRequestId &&
          route?.isCurrent != false) {
        setState(() => _searching = false);
      }
    }
  }

  Future<void> _ensureSearchArea() async {
    if (_searchAreaResolved) return;
    final initialPoint = _searchOrigin ?? _pickedPoint;
    if (initialPoint == null) return;
    var point = initialPoint;
    try {
      // Location-aware suggestions require the real device position. The
      // existing address-picker flow owns the permission prompt; if the user
      // denies it, retain the current map point as a useful fallback.
      final current = await _resolveCurrentPosition().timeout(
        const Duration(seconds: 5),
      );
      point = LatLng(current.latitude, current.longitude);
      _searchOrigin = point;
    } catch (error) {
      // Continue using the selected/map-centered point when GPS is unavailable.
      debugPrint(
        '[address-search] Could not read current GPS for bias: $error',
      );
    }
    final details = await _reverseGeocode(point);
    final area = _SearchArea.fromParts(
      district: details.district,
      city: details.city,
      province: details.province,
      center: point,
    );
    if (area.isNotEmpty) _searchArea = area;
    _searchAreaResolved = true;
  }

  String _queryWithSearchArea(String query) {
    final area = _searchArea;
    if (area == null) return query;
    final normalizedQuery = stripDiacritics(query);
    final seen = <String>{normalizedQuery};
    final missingContext = area.parts
        .where((part) {
          final normalizedPart = stripDiacritics(part);
          return !normalizedQuery.contains(normalizedPart) &&
              seen.add(normalizedPart);
        })
        .toList(growable: false);
    return missingContext.isEmpty
        ? query
        : '$query, ${missingContext.join(', ')}';
  }

  List<_PlaceResult> _searchLocalVietnamPlaces(String query) {
    // A leading house number (e.g. "16 Lê") is not part of an
    // administrative-unit name, so use the remaining words for local fallback.
    final withoutHouseNumber = query.replaceFirst(
      RegExp(r'^\d+[a-zA-Z]?\s+'),
      '',
    );
    final normalized = collapseWhitespace(stripDiacritics(withoutHouseNumber));
    final tokens = normalized.split(' ').where((token) => token.isNotEmpty);
    if (tokens.isEmpty) return const [];
    final matches = <({int score, _PlaceResult place})>[];
    for (final place in _vietnamPlaces) {
      final haystack = stripDiacritics(place.searchText);
      if (!tokens.every(haystack.contains)) continue;
      final name = stripDiacritics(place.fullAddress);
      final score = name.startsWith(normalized)
          ? 0
          : haystack.startsWith(normalized)
          ? 1
          : 2;
      if (_searchArea?.matches(place) ?? true) {
        matches.add((score: score, place: place));
      }
    }
    matches.sort((a, b) => a.score.compareTo(b.score));
    return matches.take(8).map((match) => match.place).toList(growable: false);
  }

  Future<List<_PlaceResult>> _searchPhoton(
    String query, {
    bool nearbyOnly = true,
  }) async {
    final biasPoint = _searchOrigin ?? _pickedPoint;
    const nearbyRadiusDegrees = 0.35;
    final longitudeRadius = biasPoint == null
        ? nearbyRadiusDegrees
        : nearbyRadiusDegrees /
              (cos(biasPoint.latitude * pi / 180).abs().clamp(0.2, 1.0));
    final localBbox = biasPoint == null
        ? null
        : '${biasPoint.longitude - longitudeRadius},'
              '${biasPoint.latitude - nearbyRadiusDegrees},'
              '${biasPoint.longitude + longitudeRadius},'
              '${biasPoint.latitude + nearbyRadiusDegrees}';
    final uri = Uri.https('photon.komoot.io', '/api/', {
      'q': query,
      // Fetch enough candidates to sort by actual distance on device. The
      // old limit of five often returned only prominent distant matches.
      'limit': '50',
      'countrycode': 'VN',
      if (nearbyOnly && localBbox != null) 'bbox': localBbox,
      if (!nearbyOnly) 'bbox': '102.14,8.18,109.47,23.39',
      if (biasPoint != null) ...{
        'lat': biasPoint.latitude.toString(),
        'lon': biasPoint.longitude.toString(),
        'zoom': '15',
        // Lower prominence influence and prefer candidates close to the GPS.
        'location_bias_scale': '0.05',
      },
    });
    final response = await _geocoderGet(uri);
    if (response.statusCode != 200) {
      final body = response.body.length > 240
          ? '${response.body.substring(0, 240)}…'
          : response.body;
      debugPrint('[address-search] Photon HTTP ${response.statusCode}: $body');
      throw const FormatException('Photon search failed');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['features'] is! List) {
      throw const FormatException('Invalid Photon result');
    }
    return (decoded['features'] as List)
        .whereType<Map<String, dynamic>>()
        .map(_PlaceResult.fromPhotonFeature)
        .where((place) => place.point != null)
        .where((place) => _searchArea?.matches(place) ?? true)
        .toList(growable: false);
  }

  Future<List<_PlaceResult>> _searchNominatim(String query) async {
    await _waitForGeocoderSlot();
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '5',
      'countrycodes': 'vn',
    });
    final response = await _geocoderGet(uri);
    if (response.statusCode != 200) {
      throw const FormatException('Address search fallback failed');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) throw const FormatException('Invalid address result');
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(_PlaceResult.fromNominatim)
        .where((place) => place.point != null)
        .where((place) => _searchArea?.matches(place) ?? true)
        .toList(growable: false);
  }

  static Future<void> _waitForGeocoderSlot() async {
    final previous = _lastGeocoderRequestAt;
    if (previous != null) {
      final elapsed = DateTime.now().difference(previous);
      if (elapsed < const Duration(seconds: 1)) {
        await Future<void>.delayed(const Duration(seconds: 1) - elapsed);
      }
    }
    _lastGeocoderRequestAt = DateTime.now();
  }

  static Future<http.Response> _geocoderGet(Uri uri) => http
      .get(
        uri,
        headers: {
          'User-Agent': Environment.tileUserAgent,
          'Accept-Language': 'vi',
        },
      )
      .timeout(const Duration(seconds: 10));

  void _selectPlace(_PlaceResult place) {
    _selectPlaceResult(place);
  }

  void _selectPlaceResult(
    _PlaceResult place, {
    bool preserveSuggestions = false,
  }) {
    final point = place.point;
    if (point == null) return;
    if (!preserveSuggestions) {
      _searchDebounce?.cancel();
      _searchRequestId++;
    }
    setState(() {
      _pickedPoint = point;
      _searchOrigin = point;
      _pickedStreet = place.fullAddress;
      _pickedDetails = place.detailLine;
      _searchArea = _SearchArea.fromParts(
        district: place.district,
        city: place.city,
        province: place.province,
        center: point,
      );
      _searchAreaResolved = true;
      _showHistory = false;
      if (!preserveSuggestions) {
        _searchResults = const [];
        _searching = false;
      }
    });
    _mapController.move(point, 17);
  }

  void _submitSearch(String query) {
    _searchDebounce?.cancel();
    _searchPlaces(query, pinFirst: true);
  }

  void _selectHistoryAddress(Address address) {
    final point = LatLng(address.latitude, address.longitude);
    setState(() {
      _pickedPoint = point;
      _searchOrigin = point;
      _pickedStreet = address.street;
      _pickedDetails = address.reference;
      _searchArea = null;
      _searchAreaResolved = false;
      _searchOrigin = point;
      _showHistory = false;
    });
    _mapController.move(point, 17);
  }

  // ----- Top option: use device GPS --------------------------------

  Future<void> _useCurrentLocation() async {
    setState(() => _busy = true);
    try {
      final pos = await _resolveCurrentPosition();
      if (!mounted) return;
      final point = LatLng(pos.latitude, pos.longitude);
      final details = await _reverseGeocode(point);
      if (!mounted) return;
      setState(() {
        _pickedPoint = point;
        _searchOrigin = point;
        _pickedStreet = details.address;
        _pickedDetails = details.details;
        _searchArea = _SearchArea.fromParts(
          district: details.district,
          city: details.city,
          province: details.province,
          center: point,
        );
        _searchAreaResolved = true;
        _searchResults = const [];
        _showHistory = false;
      });
      _mapController.move(point, 16);
    } catch (e) {
      // Catch absolutely everything: Vivo devices in particular can
      // throw non-standard exception types (PlatformException,
      // MissingPluginException, etc.) that the geolocator plugin
      // wraps in plain Strings. We surface a friendly message either
      // way so the user is never silently dropped back on the home
      // screen.
      if (!mounted) return;
      errorTextSnack(context, _humanizeGeolocatorError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _humanizeGeolocatorError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('service') || s.contains('gps')) {
      return context.l10n.addressEnableGpsForLocation;
    }
    if (s.contains('permission') || s.contains('denied')) {
      return context.l10n.addressPermissionDenied;
    }
    return context.l10n.addressLocationFailed;
  }

  Future<Position> _resolveCurrentPosition() async {
    final l10n = context.l10n;
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) {
      throw l10n.addressEnableGpsForLocation;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw l10n.addressPermissionDenied;
    }
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // ----- Bottom option: tap on map ----------------------------------

  Future<void> _onMapTap(TapPosition _, LatLng point) async {
    if (_busy || _searching) return;
    setState(() => _busy = true);
    try {
      final details = await _reverseGeocode(point);
      if (!mounted) return;
      setState(() {
        _pickedPoint = point;
        _searchOrigin = point;
        _pickedStreet = details.address;
        _pickedDetails = details.details;
        _searchArea = _SearchArea.fromParts(
          district: details.district,
          city: details.city,
          province: details.province,
          center: point,
        );
        _searchAreaResolved = true;
        _searchResults = const [];
        _showHistory = false;
      });
    } catch (e) {
      if (!mounted) return;
      errorTextSnack(context, context.l10n.addressLocationFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<
    ({
      String address,
      String details,
      String district,
      String city,
      String province,
    })
  >
  _reverseGeocode(LatLng point) async {
    try {
      await _waitForGeocoderSlot();
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': point.latitude.toStringAsFixed(7),
        'lon': point.longitude.toStringAsFixed(7),
        'format': 'jsonv2',
        'addressdetails': '1',
        'zoom': '17',
        'layer': 'address',
        'accept-language': 'vi',
      });
      final response = await _geocoderGet(uri);
      if (response.statusCode != 200) return _coordinateDetails(point);
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return _coordinateDetails(point);
      final rawAddress = decoded['address'];
      if (rawAddress is! Map<String, dynamic>) return _coordinateDetails(point);

      // A map tap identifies a point on a road, not a specific building.
      // Reverse geocoders return the nearest indexed object, so omit its
      // house number to avoid assigning a neighbour's number to this pin.
      final details = _PlaceResult._parts([
        rawAddress['road'] ??
            rawAddress['pedestrian'] ??
            rawAddress['residential'],
        rawAddress['neighbourhood'] ?? rawAddress['quarter'],
        rawAddress['suburb'] ?? rawAddress['township'],
        rawAddress['city_district'] ?? rawAddress['district'],
        rawAddress['city'] ?? rawAddress['town'] ?? rawAddress['village'],
        rawAddress['state'],
        rawAddress['country'],
      ]);
      if (details.isEmpty) return _coordinateDetails(point);
      return (
        address: details,
        details: details,
        district:
            '${rawAddress['suburb'] ?? rawAddress['neighbourhood'] ?? rawAddress['city_district'] ?? rawAddress['district'] ?? rawAddress['county'] ?? ''}',
        city:
            '${rawAddress['city'] ?? rawAddress['town'] ?? rawAddress['municipality'] ?? rawAddress['village'] ?? ''}',
        province: '${rawAddress['state'] ?? ''}',
      );
    } catch (_) {
      return _coordinateDetails(point);
    }
  }

  ({
    String address,
    String details,
    String district,
    String city,
    String province,
  })
  _coordinateDetails(LatLng point) {
    final coords =
        '${point.latitude.toStringAsFixed(5)}, '
        '${point.longitude.toStringAsFixed(5)}';
    final label = viL10n.addressExactCoordinates(coords);
    return (
      address: label,
      details: label,
      district: '',
      city: '',
      province: '',
    );
  }

  // ----- Confirm ----------------------------------------------------

  Future<void> _confirm() async {
    final point = _pickedPoint;
    if (point == null) return;
    final address = Address(
      id: 'user-${DateTime.now().millisecondsSinceEpoch}',
      street: _pickedStreet.isEmpty
          ? '${point.latitude.toStringAsFixed(4)}, '
                '${point.longitude.toStringAsFixed(4)}'
          : _pickedStreet,
      reference: _pickedDetails.isEmpty
          ? context.l10n.mapSelectedOnMap
          : _pickedDetails,
      latitude: point.latitude,
      longitude: point.longitude,
    );
    await _saveToHistory(address);
    if (!mounted) return;
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
          onPressed: () => goBack(context),
        ),
        title: TextCustom(
          context.l10n.addressChoose,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
        centerTitle: true,
      ),
      body: RepaintBoundary(
        child: Builder(
          builder: (context) {
            // Belt + suspenders: wrap the map widget in a try/catch
            // builder so that a single tile-load failure can never
            // prevent the rest of the screen (the hint card, the
            // confirm button) from being usable. On Vivo, geolocator
            // / map tile plugins have been seen to throw async
            // exceptions that would otherwise leave the user on a
            // blank screen.
            try {
              return Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 14,
                      minZoom: 3,
                      maxZoom: 19,
                      onTap: _onMapTap,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: Environment.tileServerUrl,
                        tileProvider: _mapTileProvider,
                        userAgentPackageName: 'com.example.delicia',
                        maxNativeZoom: 19,
                        keepBuffer: 1,
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
                    child: _SearchPanel(
                      controller: _searchController,
                      searching: _searching,
                      searchError: _searchError,
                      showHistory: _showHistory,
                      history: _history,
                      results: _searchResults,
                      onSearchChanged: _onSearchChanged,
                      onSearchSubmitted: _submitSearch,
                      onToggleHistory: () => setState(() {
                        _searchDebounce?.cancel();
                        _searchRequestId++;
                        _showHistory = !_showHistory;
                        _searchResults = const [];
                        _searchError = null;
                        _searching = false;
                      }),
                      onUseCurrentLocation: _busy || _searching
                          ? null
                          : _useCurrentLocation,
                      onSelectPlace: _selectPlace,
                      onSelectHistory: _selectHistoryAddress,
                    ),
                  ),
                  const Positioned(
                    left: 12,
                    bottom: 165,
                    child: MapAttribution(),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _BottomPanel(
                      street: _pickedStreet,
                      details: _pickedDetails,
                      busy: _busy,
                      onConfirm: _pickedPoint == null ? null : _confirm,
                    ),
                  ),
                ],
              );
            } catch (e, st) {
              debugPrint('[delicia] SelectAddress map build failed: $e\n$st');
              return _MapFallback(
                message: e.toString(),
                street: _pickedStreet,
                details: _pickedDetails,
                busy: _busy,
                onUseCurrentLocation: _busy || _searching
                    ? null
                    : _useCurrentLocation,
                onConfirm: _pickedPoint == null ? null : _confirm,
              );
            }
          },
        ),
      ),
    );
  }
}

class _SearchArea {
  const _SearchArea({
    this.district = '',
    this.city = '',
    this.province = '',
    this.center,
  });

  final String district;
  final String city;
  final String province;
  final LatLng? center;

  bool get isNotEmpty =>
      district.isNotEmpty || city.isNotEmpty || province.isNotEmpty;

  List<String> get parts => [
    district,
    city,
    province,
  ].where((part) => part.trim().isNotEmpty).toList(growable: false);

  factory _SearchArea.fromParts({
    required String district,
    required String city,
    required String province,
    LatLng? center,
  }) => _SearchArea(
    district: district.trim(),
    city: city.trim(),
    province: province.trim(),
    center: center,
  );

  bool matches(_PlaceResult place) {
    bool sameArea(String expected, String actual) {
      if (expected.isEmpty || actual.isEmpty) return true;
      final a = stripDiacritics(expected).replaceAll(RegExp(r'[^a-z0-9]'), '');
      final b = stripDiacritics(actual).replaceAll(RegExp(r'[^a-z0-9]'), '');
      return a == b || a.contains(b) || b.contains(a);
    }

    final hasCityPair = city.isNotEmpty && place.city.isNotEmpty;
    if (hasCityPair && !sameArea(city, place.city)) return false;
    final hasProvincePair = province.isNotEmpty && place.province.isNotEmpty;
    if (hasProvincePair && !sameArea(province, place.province)) return false;
    // OSM providers don't agree on whether `district` means the current ward,
    // an older district, or a suburb. Use it only when city-level fields are
    // absent; within a city, rank by GPS distance instead of dropping matches.
    if (!hasCityPair && !hasProvincePair && district.isNotEmpty) {
      if (place.district.isNotEmpty) return sameArea(district, place.district);
    }
    if (hasCityPair || hasProvincePair) return true;
    final origin = center;
    final point = place.point;
    if (origin == null || point == null) return false;
    return const Distance().as(LengthUnit.Kilometer, origin, point) <= 35;
  }
}

class _PlaceResult {
  const _PlaceResult({
    required this.point,
    required this.fullAddress,
    required this.detailLine,
    this.searchText = '',
    this.isAdministrativeUnit = false,
    this.isStreetAddress = false,
    this.district = '',
    this.city = '',
    this.province = '',
  });

  final LatLng? point;
  final String fullAddress;
  final String detailLine;
  final String searchText;
  final bool isAdministrativeUnit;
  final bool isStreetAddress;
  final String district;
  final String city;
  final String province;

  factory _PlaceResult.fromAdministrativeUnit(Map<String, dynamic> row) {
    final name = row['name'] is Map ? row['name'] as Map : const {};
    final parent = row['parent'] is Map ? row['parent'] as Map : const {};
    final parentName = parent['name'] is Map
        ? (parent['name'] as Map)['local']?.toString() ?? ''
        : '';
    final localName = (name['local'] ?? '').toString();
    final level = row['level'] == 1 ? 'Tỉnh/Thành phố' : 'Xã/Phường';
    final geo = row['geo'] is Map ? row['geo'] as Map : const {};
    final latitude = double.tryParse('${geo['lat'] ?? ''}');
    final longitude = double.tryParse('${geo['lon'] ?? ''}');
    final address = _parts([localName, parentName]);
    return _PlaceResult(
      point: latitude == null || longitude == null
          ? null
          : LatLng(latitude, longitude),
      fullAddress: address,
      detailLine: parentName.isEmpty ? level : '$level · $parentName',
      searchText: _parts([
        localName,
        name['en'],
        name['slug'],
        parentName,
        parent['name'] is Map ? (parent['name'] as Map)['en'] : null,
      ]),
      isAdministrativeUnit: true,
      province: row['level'] == 1 ? localName : parentName,
    );
  }

  factory _PlaceResult.fromNominatim(Map<String, dynamic> row) {
    final latitude = double.tryParse('${row['lat'] ?? ''}');
    final longitude = double.tryParse('${row['lon'] ?? ''}');
    final rawAddress = row['address'];
    final address = rawAddress is Map<String, dynamic>
        ? rawAddress
        : const <String, dynamic>{};
    final houseNumber = address['house_number']?.toString().trim() ?? '';
    final street =
        address['road'] ?? address['pedestrian'] ?? address['residential'];
    final streetAddress = _streetFirstAddress(houseNumber, street, '');
    final detailLine = _parts([
      address['neighbourhood'] ?? address['quarter'],
      address['suburb'] ?? address['village'],
      address['city_district'] ?? address['district'],
      address['city'] ?? address['town'] ?? address['village'],
      address['state'],
      address['postcode'],
      address['country'],
    ]);
    final display = (row['display_name'] ?? '').toString().trim();
    return _PlaceResult(
      point: latitude == null || longitude == null
          ? null
          : LatLng(latitude, longitude),
      fullAddress: streetAddress.isEmpty
          ? (detailLine.isEmpty ? display : detailLine)
          : streetAddress,
      detailLine: detailLine.isEmpty ? display : detailLine,
      isStreetAddress: houseNumber.isNotEmpty || street != null,
      district:
          '${address['suburb'] ?? address['neighbourhood'] ?? address['city_district'] ?? address['district'] ?? address['county'] ?? ''}',
      city:
          '${address['city'] ?? address['town'] ?? address['municipality'] ?? address['village'] ?? ''}',
      province: '${address['state'] ?? ''}',
    );
  }

  factory _PlaceResult.fromPhotonFeature(Map<String, dynamic> feature) {
    final rawProperties = feature['properties'];
    final properties = rawProperties is Map<String, dynamic>
        ? rawProperties
        : const <String, dynamic>{};
    final rawGeometry = feature['geometry'];
    final rawCoordinates = rawGeometry is Map<String, dynamic>
        ? rawGeometry['coordinates']
        : null;
    final coordinates = rawCoordinates is List ? rawCoordinates : const [];
    final longitude = coordinates.isNotEmpty
        ? double.tryParse('${coordinates[0]}')
        : null;
    final latitude = coordinates.length > 1
        ? double.tryParse('${coordinates[1]}')
        : null;
    final street = properties['street'] ?? properties['street_name'];
    final houseNumber = properties['housenumber']?.toString().trim() ?? '';
    final display = (properties['name'] ?? '').toString().trim();
    final streetAddress = _streetFirstAddress(houseNumber, street, display);
    final detailLine = _parts([
      properties['district'] ?? properties['county'],
      properties['city'] ?? properties['locality'],
      properties['state'],
      properties['postcode'],
      properties['country'],
    ]);
    return _PlaceResult(
      point: latitude == null || longitude == null
          ? null
          : LatLng(latitude, longitude),
      fullAddress: streetAddress.isEmpty
          ? (detailLine.isEmpty ? display : detailLine)
          : streetAddress,
      detailLine: detailLine.isEmpty ? display : detailLine,
      isStreetAddress:
          houseNumber.isNotEmpty ||
          street != null ||
          properties['type'] == 'street',
      district:
          '${properties['district'] ?? properties['county'] ?? properties['suburb'] ?? ''}',
      city: '${properties['city'] ?? properties['locality'] ?? ''}',
      province: '${properties['state'] ?? ''}',
    );
  }

  static String _parts(Iterable<Object?> values) {
    final seen = <String>{};
    return values
        .map((value) => value?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty && seen.add(value.toLowerCase()))
        .join(', ');
  }

  static String _streetFirstAddress(
    String houseNumber,
    Object? street,
    String fallbackName,
  ) {
    final streetName = street?.toString().trim() ?? '';
    if (streetName.isNotEmpty) {
      return houseNumber.isEmpty ? streetName : '$houseNumber, $streetName';
    }
    return fallbackName;
  }
}

/// Used when the [FlutterMap] widget itself fails to build (some
/// Vivo builds throw a PlatformException during the first paint
/// of the map view). Renders the same hint + confirm UI on a flat
/// background so the user can still complete the flow.
class _MapFallback extends StatelessWidget {
  final String message;
  final String street;
  final String details;
  final bool busy;
  final VoidCallback? onUseCurrentLocation;
  final VoidCallback? onConfirm;

  const _MapFallback({
    required this.message,
    required this.street,
    required this.details,
    required this.busy,
    required this.onUseCurrentLocation,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF5F5F5),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HintCard(onUseCurrentLocation: onUseCurrentLocation),
              const SizedBox(height: 24),
              TextCustom(
                context.l10n.mapUnavailable,
                fontWeight: FontWeight.w600,
                fontSize: 16,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              TextCustom(
                context.l10n.addressPasteHint,
                color: ColorsFrave.greyText,
                fontSize: 13,
                textAlign: TextAlign.center,
                maxLines: 3,
              ),
              const Spacer(),
              _BottomPanel(
                street: street,
                details: details,
                busy: busy,
                onConfirm: onConfirm,
              ),
            ],
          ),
        ),
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
            Expanded(
              child: TextCustom(
                context.l10n.actionUseCurrentLocation,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextButton(
              onPressed: onUseCurrentLocation,
              child: TextCustom(
                context.l10n.addressUse,
                color: ColorsFrave.primaryColor,
                fontWeight: FontWeight.bold,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.controller,
    required this.searching,
    required this.searchError,
    required this.showHistory,
    required this.history,
    required this.results,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onToggleHistory,
    required this.onUseCurrentLocation,
    required this.onSelectPlace,
    required this.onSelectHistory,
  });

  final TextEditingController controller;
  final bool searching;
  final String? searchError;
  final bool showHistory;
  final List<Address> history;
  final List<_PlaceResult> results;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onToggleHistory;
  final VoidCallback? onUseCurrentLocation;
  final ValueChanged<_PlaceResult> onSelectPlace;
  final ValueChanged<Address> onSelectHistory;

  @override
  Widget build(BuildContext context) {
    // Match the two-character threshold used by _onSearchChanged so a
    // two-character query can display Photon suggestions once they arrive.
    final queryTooShort =
        controller.text.trim().isNotEmpty && controller.text.trim().length < 2;
    final showPlaces =
        showHistory ||
        results.isNotEmpty ||
        searching ||
        searchError != null ||
        queryTooShort;
    return Material(
      color: Colors.white,
      elevation: 5,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            child: Row(
              children: [
                const Icon(Icons.search, color: ColorsFrave.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    textInputAction: TextInputAction.search,
                    onChanged: onSearchChanged,
                    onSubmitted: onSearchSubmitted,
                    decoration: InputDecoration(
                      hintText: context.l10n.addressSearchHint,
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.addressSearch,
                  onPressed: () => onSearchSubmitted(controller.text),
                  icon: searching
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.arrow_forward_rounded),
                ),
                IconButton(
                  tooltip: context.l10n.addressRecentPlaces,
                  onPressed: onToggleHistory,
                  icon: const Icon(Icons.history_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onUseCurrentLocation,
              icon: const Icon(Icons.my_location, size: 18),
              label: Text(context.l10n.actionUseCurrentLocation),
            ),
          ),
          if (showPlaces)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 210),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: queryTooShort
                    ? [
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.info_outline),
                          title: Text(context.l10n.addressSearchTypeMore),
                        ),
                      ]
                    : searchError != null
                    ? [
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.info_outline),
                          title: Text(searchError!),
                        ),
                      ]
                    : searching && results.isEmpty
                    ? [
                        ListTile(
                          dense: true,
                          leading: const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          title: Text(context.l10n.addressSearching),
                        ),
                      ]
                    : showHistory
                    ? history.isEmpty
                          ? [
                              ListTile(
                                dense: true,
                                title: Text(context.l10n.addressHistoryEmpty),
                              ),
                            ]
                          : [
                              for (final address in history)
                                ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.history),
                                  title: Text(
                                    address.street,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    address.reference,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () => onSelectHistory(address),
                                ),
                            ]
                    : [
                        for (final place in results)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.place_outlined),
                            title: Text(
                              place.fullAddress,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              place.isAdministrativeUnit
                                  ? '${place.detailLine} · Open Admin Data'
                                  : place.detailLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => onSelectPlace(place),
                          ),
                      ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  final String street;
  final String details;
  final bool busy;
  final VoidCallback? onConfirm;
  const _BottomPanel({
    required this.street,
    required this.details,
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
                      street.isEmpty ? context.l10n.addressTapMap : street,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (details.isNotEmpty && details != street) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 28),
                  child: TextCustom(
                    details,
                    color: ColorsFrave.greyText,
                    fontSize: 12,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              BtnFrave(
                text: busy
                    ? context.l10n.addressLocating
                    : (onConfirm == null
                          ? context.l10n.addressPickLocation
                          : context.l10n.actionUseThisAddress),
                onPressed: onConfirm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
