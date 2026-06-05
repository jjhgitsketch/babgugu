// lib/screens/map/map_interface.dart
// 웹/모바일 공통 인터페이스
export 'map_stub.dart'
    if (dart.library.io) 'map_native.dart';
