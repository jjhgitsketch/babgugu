// lib/screens/map/map_interface.dart
//
// Common map export. Web/unsupported platforms use the stub implementation,
// while mobile platforms use the native Naver Map implementation.
export 'map_stub.dart' if (dart.library.io) 'map_native.dart';
