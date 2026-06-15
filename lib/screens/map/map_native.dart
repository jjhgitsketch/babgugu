// lib/screens/map/map_native.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../models/models.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/meeting_image.dart';
import '../meeting_detail_screen.dart';

class LocationResult {
  final double latitude;
  final double longitude;
  final String address;
  const LocationResult(
      {required this.latitude, required this.longitude, required this.address});
}

double _calcDistance(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLng = (lng2 - lng1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) *
          cos(lat2 * pi / 180) *
          sin(dLng / 2) *
          sin(dLng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

Future<String> _getAddressFromLatLng(double lat, double lng) async {
  try {
    final uri = Uri.parse(
      'https://maps.apigw.ntruss.com/map-reversegeocode/v2/gc'
      '?coords=$lng,$lat&output=json&orders=roadaddr,addr',
    );
    final response = await http.get(uri, headers: {
      'x-ncp-apigw-api-key-id': 'dk4xnd02dq',
      'x-ncp-apigw-api-key': 'JOdRUbGW1KbmNrLUQNDAVNc4Rkm4Loox9NtyYMqr',
    }).timeout(const Duration(seconds: 5));

    debugPrint('Reverse Geocoding status: ${response.statusCode}');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final results = data['results'] as List?;
      if (results != null && results.isNotEmpty) {
        for (final result in results) {
          final name = result['name'] as String? ?? '';
          final region = result['region'] as Map?;
          final land = result['land'] as Map?;
          if (region == null) continue;
          final area1 = region['area1']?['name'] ?? '';
          final area2 = region['area2']?['name'] ?? '';
          final area3 = region['area3']?['name'] ?? '';
          String address = '$area1 $area2 $area3'.trim();
          if (land != null && name == 'roadaddr') {
            final roadName = land['name'] ?? '';
            final number1 = land['number1'] ?? '';
            if (roadName.isNotEmpty) address += ' $roadName $number1'.trim();
          } else if (land != null) {
            final number1 = land['number1'] ?? '';
            final number2 = land['number2'] ?? '';
            if (number1.isNotEmpty) {
              address +=
                  ' $number1${number2.isNotEmpty ? '-$number2' : ''}'.trim();
            }
          }
          if (address.isNotEmpty) return address;
        }
      }
    }
  } catch (e) {
    debugPrint('Failed to get current position: $e');
  }
  return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
}

// ?? ?? ?? ? ?? ??
Future<LocationPermission> _ensureLocationPermission(
  BuildContext context,
) async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    if (!context.mounted) return LocationPermission.denied;
    final openSettings = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '\uC704\uCE58 \uC11C\uBE44\uC2A4\uAC00 \uAEBC\uC838 \uC788\uC5B4\uC694',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          '\uAC00\uAE4C\uC6B4 \uBAA8\uC784\uC744 \uAC70\uB9AC\uC21C\uC73C\uB85C \uBCF4\uC5EC\uB4DC\uB9AC\uB824\uBA74 \uAE30\uAE30 \uC704\uCE58 \uC11C\uBE44\uC2A4\uB97C \uCF1C\uC57C \uD574\uC694.',
          style: TextStyle(fontSize: 14, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('\uB098\uC911\uC5D0',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('\uC124\uC815 \uC5F4\uAE30'),
          ),
        ],
      ),
    );
    if (openSettings == true) {
      await Geolocator.openLocationSettings();
    }
    return LocationPermission.denied;
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    if (!context.mounted) return permission;
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.location_on_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              '\uC704\uCE58 \uAD8C\uD55C \uD544\uC694',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: const Text(
          '\uC8FC\uBCC0 \uBAA8\uC784\uC744 \uCC3E\uC73C\uB824\uBA74 \uC704\uCE58 \uC811\uADFC \uAD8C\uD55C\uC774 \uD544\uC694\uD574\uC694.\n\n\uC704\uCE58 \uC815\uBCF4\uB294 \uC8FC\uBCC0 \uBAA8\uC784 \uD0D0\uC0C9\uC5D0\uB9CC \uC0AC\uC6A9\uD560\uAC8C\uC694.',
          style: TextStyle(fontSize: 14, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('\uB098\uC911\uC5D0',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('\uD5C8\uC6A9'),
          ),
        ],
      ),
    );
    if (proceed != true) return LocationPermission.denied;
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.deniedForever) {
    if (!context.mounted) return permission;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '\uC704\uCE58 \uAD8C\uD55C\uC774 \uCC28\uB2E8\uB410\uC5B4\uC694',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          '\uC704\uCE58 \uAD8C\uD55C\uC774 \uC601\uAD6C \uCC28\uB2E8\uB418\uC5B4 \uC788\uC5B4\uC694. \uC124\uC815\uC5D0\uC11C \uC704\uCE58 \uAD8C\uD55C\uC744 \uD5C8\uC6A9\uD574 \uC8FC\uC138\uC694.',
          style: TextStyle(fontSize: 14, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('\uB098\uC911\uC5D0',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Geolocator.openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('\uC124\uC815\uC73C\uB85C \uC774\uB3D9'),
          ),
        ],
      ),
    );
  }
  return permission;
}

Future<Position?> _getCurrentPosition(BuildContext context) async {
  try {
    final permission = await _ensureLocationPermission(context);
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    );
  } catch (e) {
    debugPrint('Failed to get current position: $e');
    return null;
  }
}

// Location picker screen
// ?? ?? ??
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  NaverMapController? _mapController;
  NLatLng? _selectedLocation;
  String _selectedAddress = '';
  bool _mapLoading = true;
  bool _addressLoading = false;

  static const _defaultLocation = NLatLng(37.5665, 126.9780);

  Future<void> _moveToCurrentLocation() async {
    if (!mounted) return;
    final pos = await _getCurrentPosition(context);
    if (pos != null && _mapController != null && mounted) {
      await _mapController!.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
          target: NLatLng(pos.latitude, pos.longitude),
          zoom: 16,
        ),
      );
    }
  }

  void _onMapTap(NPoint point, NLatLng location) async {
    setState(() {
      _selectedLocation = location;
      _selectedAddress =
          '\uC8FC\uC18C\uB97C \uBD88\uB7EC\uC624\uB294 \uC911...';
      _addressLoading = true;
    });
    await _mapController?.clearOverlays();
    await _mapController?.addOverlay(
      NMarker(id: 'selected', position: location),
    );
    final address =
        await _getAddressFromLatLng(location.latitude, location.longitude);
    if (mounted) {
      setState(() {
        _selectedAddress = address;
        _addressLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final locateButtonBottom =
        safeBottom + (_selectedLocation == null ? 20.0 : 224.0);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('\uC704\uCE58 \uC120\uD0DD'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_selectedLocation != null && !_addressLoading)
            TextButton(
              onPressed: () => Navigator.pop(
                context,
                LocationResult(
                  latitude: _selectedLocation!.latitude,
                  longitude: _selectedLocation!.longitude,
                  address: _selectedAddress,
                ),
              ),
              child: const Text(
                '\uC120\uD0DD',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          NaverMap(
            options: const NaverMapViewOptions(
              initialCameraPosition:
                  NCameraPosition(target: _defaultLocation, zoom: 14),
              mapType: NMapType.basic,
              locationButtonEnable: false,
            ),
            onMapReady: (controller) async {
              _mapController = controller;
              if (mounted) setState(() => _mapLoading = false);
              await _moveToCurrentLocation();
            },
            onMapTapped: _onMapTap,
          ),
          if (!_mapLoading)
            Positioned(
              right: 20,
              bottom: locateButtonBottom,
              child: _MapLocateButton(
                hasLocation: true,
                onTap: _moveToCurrentLocation,
              ),
            ),
          if (_selectedLocation == null && !_mapLoading)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.touch_app_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '\uC9C0\uB3C4\uB97C \uB20C\uB7EC \uC704\uCE58\uB97C \uC120\uD0DD\uD558\uC138\uC694',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_selectedLocation != null)
            Positioned(
              bottom: safeBottom,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.tagBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child:
                              const Icon(Icons.place, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '\uC120\uD0DD\uD55C \uC704\uCE58',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              _addressLoading
                                  ? const Row(
                                      children: [
                                        SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          '\uC8FC\uC18C\uB97C \uBD88\uB7EC\uC624\uB294 \uC911...',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      _selectedAddress,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _addressLoading
                            ? null
                            : () => Navigator.pop(
                                  context,
                                  LocationResult(
                                    latitude: _selectedLocation!.latitude,
                                    longitude: _selectedLocation!.longitude,
                                    address: _selectedAddress,
                                  ),
                                ),
                        child: const Text(
                            '\uC774 \uC704\uCE58\uB85C \uC124\uC815'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_mapLoading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
        ],
      ),
    );
  }
}

// ?? ?? ??
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  NaverMapController? _mapController;
  List<_MeetingWithDistance> _allMeetings = [];
  List<_MeetingWithDistance> _nearbyMeetings = [];
  MeetingModel? _selectedMeeting;
  String _searchQuery = '';

  Position? _currentPosition;
  bool _loading = true;
  double _sheetExtent = 0.38;
  final double _radiusKm = 3.0;

  static const _defaultLocation = NLatLng(37.5665, 126.9780);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final pos = await _getCurrentPosition(context);
    if (!mounted) return;

    final results = await Future.wait([
      SupabaseService.getMeetingsExcludingBlocked(),
      SupabaseService.getMyMeetingIds(),
    ]);
    if (!mounted) return;

    final meetings = (results[0] as List<MeetingModel>)
        .where((m) => !_isPastMeeting(m))
        .toList();
    final myIds = results[1] as Set<String>;
    final myTags = currentUser?.tags ?? [];

    for (final m in meetings) {
      m.isJoined = myIds.contains(m.id);
      m.matchPercent = SupabaseService.calcMatch(myTags, m.tags);
    }

    final withLocation = meetings.where((m) => m.hasLocation).toList();
    List<_MeetingWithDistance> withDist = [];

    if (pos != null) {
      for (final m in withLocation) {
        final dist = _calcDistance(
            pos.latitude, pos.longitude, m.latitude!, m.longitude!);
        withDist.add(_MeetingWithDistance(meeting: m, distanceKm: dist));
      }
      withDist.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    } else {
      withDist = withLocation
          .map((m) => _MeetingWithDistance(meeting: m, distanceKm: -1))
          .toList();
    }

    setState(() {
      _currentPosition = pos;
      _allMeetings = withDist
          .where((m) => m.distanceKm < 0 || m.distanceKm <= _radiusKm)
          .toList();
      _nearbyMeetings = _filterMeetings(_allMeetings, _searchQuery);
      _loading = false;
    });

    if (pos != null && _mapController != null) {
      await _mapController!.updateCamera(NCameraUpdate.scrollAndZoomTo(
        target: NLatLng(pos.latitude, pos.longitude),
        zoom: 14,
      ));
    }
    if (_mapController != null) await _addMarkers();
  }

  Future<void> _addMarkers() async {
    if (_mapController == null) return;
    await _mapController!.clearOverlays();

    if (_currentPosition != null) {
      final myMarker = NMarker(
        id: 'my_location',
        position:
            NLatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        caption:
            const NOverlayCaption(text: '\uB0B4 \uC704\uCE58', textSize: 11),
        iconTintColor: Colors.blue,
      );
      await _mapController!.addOverlay(myMarker);
    }

    for (final item in _nearbyMeetings) {
      final m = item.meeting;
      final marker = NMarker(
        id: m.id,
        position: NLatLng(m.latitude!, m.longitude!),
        caption: NOverlayCaption(
          text: m.title.length > 8 ? '${m.title.substring(0, 8)}...' : m.title,
          textSize: 11,
        ),
      );
      marker.setOnTapListener((_) {
        setState(() => _selectedMeeting = m);
        _mapController?.updateCamera(NCameraUpdate.scrollAndZoomTo(
          target: NLatLng(m.latitude!, m.longitude!),
          zoom: 16,
        ));
      });
      await _mapController!.addOverlay(marker);
    }
  }

  List<_MeetingWithDistance> _filterMeetings(
    List<_MeetingWithDistance> source,
    String query,
  ) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return List<_MeetingWithDistance>.from(source);
    return source.where((item) {
      final meeting = item.meeting;
      return meeting.title.toLowerCase().contains(normalized) ||
          meeting.description.toLowerCase().contains(normalized) ||
          meeting.location.toLowerCase().contains(normalized) ||
          (meeting.category ?? '').toLowerCase().contains(normalized) ||
          meeting.tags.any((tag) => tag.toLowerCase().contains(normalized));
    }).toList();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _nearbyMeetings = _filterMeetings(_allMeetings, value);
      if (_selectedMeeting != null &&
          !_nearbyMeetings
              .any((item) => item.meeting.id == _selectedMeeting!.id)) {
        _selectedMeeting = null;
      }
    });
    _addMarkers();
  }

  Future<void> _moveToMyLocation() async {
    if (_currentPosition == null) {
      await _loadAll();
      return;
    }
    await _mapController?.updateCamera(
      NCameraUpdate.scrollAndZoomTo(
        target:
            NLatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        zoom: 16,
      ),
    );
  }

  Future<void> _openDetail(MeetingModel meeting) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MeetingDetailScreen(meeting: meeting)),
    );
    _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final safeBottom = media.padding.bottom;
    final availableHeight = media.size.height - safeBottom;
    final locateButtonBottom =
        safeBottom + (availableHeight * _sheetExtent) + 16;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            top: 130,
            child: NaverMap(
              options: NaverMapViewOptions(
                initialCameraPosition: NCameraPosition(
                  target: _currentPosition != null
                      ? NLatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        )
                      : _defaultLocation,
                  zoom: 13,
                ),
                mapType: NMapType.basic,
                locationButtonEnable: false,
              ),
              onMapReady: (controller) async {
                _mapController = controller;
                if (_currentPosition != null) {
                  await controller.updateCamera(
                    NCameraUpdate.scrollAndZoomTo(
                      target: NLatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      zoom: 14,
                    ),
                  );
                }
                await _addMarkers();
              },
              onMapTapped: (_, __) => setState(() => _selectedMeeting = null),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          behavior: HitTestBehavior.opaque,
                          child: const Text(
                            '\uB9AC\uC2A4\uD2B8\uB85C \uBCF4\uAE30',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF909090),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              '\uC9C0\uB3C4\uB85C \uBCF4\uAE30',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                                width: 92, height: 3, color: Colors.black),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _MapSearchBox(
                    value: _searchQuery,
                    onChanged: _onSearchChanged,
                    onRefresh: _loadAll,
                  ),
                ),
              ],
            ),
          ),
          if (!_loading && _currentPosition == null)
            Positioned(
              top: 205,
              right: 24,
              child: GestureDetector(
                onTap: () async {
                  final perm = await _ensureLocationPermission(context);
                  if (perm == LocationPermission.always ||
                      perm == LocationPermission.whileInUse) {
                    _loadAll();
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_off, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        '\uC704\uCE58 \uAD8C\uD55C \uD544\uC694',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (!_loading)
            Positioned(
              right: 20,
              bottom: locateButtonBottom,
              child: _MapLocateButton(
                hasLocation: _currentPosition != null,
                onTap: _moveToMyLocation,
              ),
            ),
          Padding(
            padding: EdgeInsets.only(bottom: safeBottom),
            child: NotificationListener<DraggableScrollableNotification>(
              onNotification: (notification) {
                if ((notification.extent - _sheetExtent).abs() > 0.004) {
                  setState(() => _sheetExtent = notification.extent);
                }
                return false;
              },
              child: DraggableScrollableSheet(
                initialChildSize: 0.38,
                minChildSize: 0.10,
                maxChildSize: 0.86,
                snap: true,
                snapSizes: const [0.10, 0.38, 0.86],
                builder: (context, scrollController) {
                  return Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                      border: Border(
                        top: BorderSide(color: Color(0xFFDADADA), width: 1.05),
                      ),
                    ),
                    child: SingleChildScrollView(
                      controller: scrollController,
                      physics: const ClampingScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.86,
                        child: Column(
                          children: [
                            const SizedBox(height: 12),
                            Container(
                              width: 45,
                              height: 3,
                              decoration: BoxDecoration(
                                color: const Color(0xFFBDBDBD),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 12, 20, 9),
                              child: Row(
                                children: [
                                  const Text(
                                    '\uAC00\uAE4C\uC6B4 \uC21C',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const Icon(Icons.keyboard_arrow_down_rounded,
                                      size: 17),
                                  const Spacer(),
                                  Text(
                                    '${_nearbyMeetings.length}\uAC1C',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const _MapFilterChips(),
                            const SizedBox(height: 10),
                            Expanded(
                              child: _loading
                                  ? const Center(
                                      child: CircularProgressIndicator(
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : ListView.separated(
                                      primary: false,
                                      padding: EdgeInsets.fromLTRB(
                                        20,
                                        0,
                                        20,
                                        96 + safeBottom,
                                      ),
                                      itemCount: _nearbyMeetings.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(
                                        height: 25,
                                        color: Color(0xFFE0E0E0),
                                      ),
                                      itemBuilder: (context, index) {
                                        final item = _nearbyMeetings[index];
                                        return _MapMeetingRow(
                                          item: item,
                                          selected: _selectedMeeting?.id ==
                                              item.meeting.id,
                                          onTap: () =>
                                              _openDetail(item.meeting),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
        ],
      ),
    );
  }
}

class _MapLocateButton extends StatelessWidget {
  final bool hasLocation;
  final VoidCallback onTap;

  const _MapLocateButton({required this.hasLocation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 5,
      shadowColor: Colors.black.withValues(alpha: 0.16),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(
            hasLocation
                ? Icons.my_location_rounded
                : Icons.location_searching_rounded,
            size: 22,
            color: hasLocation ? AppColors.primary : Colors.orange,
          ),
        ),
      ),
    );
  }
}

class _MapSearchBox extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onRefresh;

  const _MapSearchBox({
    required this.value,
    required this.onChanged,
    required this.onRefresh,
  });

  @override
  State<_MapSearchBox> createState() => _MapSearchBoxState();
}

class _MapSearchBoxState extends State<_MapSearchBox> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant _MapSearchBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _controller.text.trim().isNotEmpty;

    return Container(
      height: 46,
      padding: const EdgeInsets.only(left: 16, right: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD9D9D9), width: 1.2),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: widget.onChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF241D1D),
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: true,
                fillColor: Colors.white,
                hoverColor: Colors.white,
                hintText: '\uBAA8\uC784, \uC7A5\uC18C \uAC80\uC0C9',
                hintStyle: TextStyle(fontSize: 13, color: Color(0xFF909090)),
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
          IconButton(
            onPressed: hasQuery ? _clear : widget.onRefresh,
            icon: Icon(
              hasQuery ? Icons.close_rounded : Icons.search_rounded,
              size: hasQuery ? 20 : 29,
            ),
            tooltip: hasQuery
                ? '\uAC80\uC0C9\uC5B4 \uC9C0\uC6B0\uAE30'
                : '\uC0C8\uB85C\uACE0\uCE68',
          ),
        ],
      ),
    );
  }
}

class _MapFilterChips extends StatelessWidget {
  const _MapFilterChips();

  @override
  Widget build(BuildContext context) {
    const chips = [
      ('\uC804\uCCB4 \uC7A5\uC18C', Icons.explore_rounded, true),
      ('1\uC778 \uC2DD\uB2F9', Icons.person_rounded, false),
      ('\uC9C4\uD589 \uC911 \uBAA8\uC784', Icons.groups_rounded, false),
    ];

    return SizedBox(
      height: 23,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final chip = chips[index];
          final active = chip.$3;
          return Container(
            width: 68,
            height: 23,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              color: active ? const Color(0xFF444EF8) : const Color(0xFFDDE5F3),
              borderRadius: BorderRadius.circular(19),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  chip.$2,
                  size: index == 0 ? 14 : 12,
                  color: active ? Colors.white : const Color(0xFF444EF8),
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    chip.$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w800,
                      color: active ? Colors.white : const Color(0xFF444EF8),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MapMeetingRow extends StatelessWidget {
  final _MeetingWithDistance item;
  final bool selected;
  final VoidCallback onTap;

  const _MapMeetingRow({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final meeting = item.meeting;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: selected ? AppColors.primaryBg : Colors.transparent,
        child: SizedBox(
          height: 128,
          child: Row(
            children: [
              MeetingImage(
                meeting: meeting,
                width: 105,
                height: 128,
                borderRadius: BorderRadius.circular(13),
                fallbackColor: const Color(0xFFFFECE5),
                iconSize: 42,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            meeting.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 24,
                          color: Colors.black,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _mapTagLine(meeting.tags),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF909090),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 16),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            meeting.location.isEmpty
                                ? '\uC7A5\uC18C \uBBF8\uC815'
                                : meeting.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined, size: 16),
                        const SizedBox(width: 2),
                        Text(
                          _mapShortDate(meeting.meetingTime),
                          style: const TextStyle(fontSize: 11),
                        ),
                        const SizedBox(width: 17),
                        const Icon(Icons.person_outline_rounded, size: 16),
                        const SizedBox(width: 2),
                        Text(
                          '${meeting.currentMembers} / ${meeting.maxMembers}\uBA85',
                          style: const TextStyle(fontSize: 11),
                        ),
                        const Spacer(),
                        const Icon(Icons.auto_awesome, size: 14),
                        const SizedBox(width: 2),
                        Text(
                          '\uCC30\uB5A1\uAD81\uD569 ${meeting.matchPercent}%',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    if (item.distanceKm >= 0) ...[
                      const SizedBox(height: 5),
                      Text(
                        item.distanceKm < 1
                            ? '${(item.distanceKm * 1000).round()}m \uAC70\uB9AC'
                            : '${item.distanceKm.toStringAsFixed(1)}km \uAC70\uB9AC',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeetingWithDistance {
  final MeetingModel meeting;
  final double distanceKm;
  const _MeetingWithDistance({required this.meeting, required this.distanceKm});
}

String _mapTagLine(List<String> tags) {
  if (tags.isEmpty) return '#\uBC25\uAD6C\uAD6C';
  return tags
      .take(3)
      .map((tag) => tag.startsWith('#') ? tag : '#$tag')
      .join(' ');
}

String _mapShortDate(DateTime date) {
  final local = date.toLocal();
  return '${local.month}/${local.day}';
}

bool _isPastMeeting(MeetingModel meeting) {
  if (meeting.status == MeetingStatus.completed) return true;
  final today = DateUtils.dateOnly(DateTime.now());
  final meetingDay = DateUtils.dateOnly(meeting.meetingTime);
  return meetingDay.isBefore(today);
}
