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
import '../../widgets/meeting_card.dart';
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

    debugPrint('Reverse Geocoding 응답: \${response.statusCode}');
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
    debugPrint('Reverse Geocoding 예외: $e');
  }
  return '\${lat.toStringAsFixed(5)}, \${lng.toStringAsFixed(5)}';
}

// ─── 위치 권한 요청 ───
Future<LocationPermission> _ensureLocationPermission(
    BuildContext context) async {
  var permission = await Geolocator.checkPermission();

  if (permission == LocationPermission.denied) {
    if (!context.mounted) return permission;
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Text('📍', style: TextStyle(fontSize: 24)),
          SizedBox(width: 8),
          Text('위치 권한 필요',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ]),
        content: const Text(
          '주변 모임을 찾으려면 위치 접근 권한이 필요해요.\n\n위치 정보는 주변 모임 탐색에만 사용되며 서버에 저장되지 않아요.',
          style: TextStyle(fontSize: 14, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('나중에', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('허용하기'),
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
        title: const Text('위치 권한이 차단됨',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        content: const Text(
          '위치 권한이 영구 차단되어 있어요.\n설정에서 위치 권한을 허용해주세요.',
          style: TextStyle(fontSize: 14, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Geolocator.openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('설정으로 이동'),
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
    debugPrint('위치 가져오기 실패: $e');
    return null;
  }
}

// ═══════════════════════════════════════════
// ─── 위치 선택 화면 ───
// ═══════════════════════════════════════════
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
      await _mapController!.updateCamera(NCameraUpdate.scrollAndZoomTo(
        target: NLatLng(pos.latitude, pos.longitude),
        zoom: 16,
      ));
    }
  }

  void _onMapTap(NPoint point, NLatLng location) async {
    setState(() {
      _selectedLocation = location;
      _selectedAddress = '주소 불러오는 중...';
      _addressLoading = true;
    });
    await _mapController?.clearOverlays();
    await _mapController
        ?.addOverlay(NMarker(id: 'selected', position: location));
    final address =
        await _getAddressFromLatLng(location.latitude, location.longitude);
    if (mounted)
      setState(() {
        _selectedAddress = address;
        _addressLoading = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('위치 선택'),
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
                  )),
              child: const Text('확인',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
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
              locationButtonEnable: true,
            ),
            onMapReady: (controller) async {
              _mapController = controller;
              if (mounted) setState(() => _mapLoading = false);
              await _moveToCurrentLocation();
            },
            onMapTapped: _onMapTap,
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
                        blurRadius: 8)
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.touch_app_outlined,
                        color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text('지도를 탭해서 위치를 선택하세요',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          if (_selectedLocation != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
                          borderRadius: BorderRadius.circular(2)),
                    )),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                              color: AppColors.tagBg,
                              borderRadius: BorderRadius.circular(10)),
                          child:
                              const Icon(Icons.place, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('선택한 위치',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                              _addressLoading
                                  ? const Row(children: [
                                      SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.primary)),
                                      SizedBox(width: 8),
                                      Text('주소 불러오는 중...',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: AppColors.textSecondary)),
                                    ])
                                  : Text(_selectedAddress,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700)),
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
                                )),
                        child: const Text('이 위치로 설정'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_mapLoading)
            const Center(
                child: CircularProgressIndicator(color: AppColors.primary)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// ─── 지도 탐색 화면 ───
// ═══════════════════════════════════════════
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  NaverMapController? _mapController;
  List<MeetingModel> _meetings = [];
  List<_MeetingWithDistance> _nearbyMeetings = [];
  MeetingModel? _selectedMeeting;
  Position? _currentPosition;
  bool _loading = true;
  double _radiusKm = 3.0;

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

    final meetings = results[0] as List<MeetingModel>;
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
      _meetings = withLocation;
      _nearbyMeetings = withDist
          .where((m) => m.distanceKm < 0 || m.distanceKm <= _radiusKm)
          .toList();
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
        caption: const NOverlayCaption(text: '내 위치', textSize: 11),
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

  void _onRadiusChanged(double km) {
    setState(() {
      _radiusKm = km;
      if (_currentPosition != null) {
        _nearbyMeetings = _meetings
            .map((m) {
              final dist = _calcDistance(_currentPosition!.latitude,
                  _currentPosition!.longitude, m.latitude!, m.longitude!);
              return _MeetingWithDistance(meeting: m, distanceKm: dist);
            })
            .where((m) => m.distanceKm <= _radiusKm)
            .toList()
          ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      }
    });
    _addMarkers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('주변 모임 지도'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAll)
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.radar, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text('반경 ${_radiusKm.toStringAsFixed(1)}km',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
                Expanded(
                  child: Slider(
                    value: _radiusKm,
                    min: 1,
                    max: 20,
                    divisions: 19,
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.divider,
                    onChanged: _onRadiusChanged,
                  ),
                ),
                Text('${_nearbyMeetings.length}개',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                NaverMap(
                  options: NaverMapViewOptions(
                    initialCameraPosition: NCameraPosition(
                      target: _currentPosition != null
                          ? NLatLng(_currentPosition!.latitude,
                              _currentPosition!.longitude)
                          : _defaultLocation,
                      zoom: 13,
                    ),
                    mapType: NMapType.basic,
                    locationButtonEnable: true,
                  ),
                  onMapReady: (controller) async {
                    _mapController = controller;
                    if (_currentPosition != null) {
                      await controller
                          .updateCamera(NCameraUpdate.scrollAndZoomTo(
                        target: NLatLng(_currentPosition!.latitude,
                            _currentPosition!.longitude),
                        zoom: 14,
                      ));
                    }
                    await _addMarkers();
                  },
                  onMapTapped: (_, __) =>
                      setState(() => _selectedMeeting = null),
                ),
                if (!_loading)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8)
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.place,
                              color: AppColors.primary, size: 14),
                          const SizedBox(width: 4),
                          Text('${_nearbyMeetings.length}개 모임',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                if (!_loading && _currentPosition == null)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: () async {
                        final perm = await _ensureLocationPermission(context);
                        if (perm == LocationPermission.always ||
                            perm == LocationPermission.whileInUse) {
                          _loadAll();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_off,
                                size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text('위치 권한 필요',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_selectedMeeting != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      decoration: const BoxDecoration(
                        color: AppColors.bg,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(20)),
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 10)
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Center(
                              child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(2)),
                          )),
                          if (_currentPosition != null) ...[
                            Builder(builder: (_) {
                              final dist = _calcDistance(
                                _currentPosition!.latitude,
                                _currentPosition!.longitude,
                                _selectedMeeting!.latitude!,
                                _selectedMeeting!.longitude!,
                              );
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    const Icon(Icons.directions_walk,
                                        size: 14, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      dist < 1
                                          ? '${(dist * 1000).round()}m 거리'
                                          : '${dist.toStringAsFixed(1)}km 거리',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                          MeetingCard(
                            meeting: _selectedMeeting!,
                            onTap: () async {
                              await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MeetingDetailScreen(
                                        meeting: _selectedMeeting!),
                                  ));
                              _loadAll();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_loading)
                  const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MeetingWithDistance {
  final MeetingModel meeting;
  final double distanceKm;
  const _MeetingWithDistance({required this.meeting, required this.distanceKm});
}
