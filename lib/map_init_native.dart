// flutter_naver_map initialization
import 'package:flutter/foundation.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

Future<void> initNaverMap() async {
  // flutter_naver_map 1.3.1 최신 초기화 방식
  await FlutterNaverMap().init(
    clientId: 'dk4xnd02dq',
    onAuthFailed: (ex) {
      switch (ex) {
        case NUnauthorizedClientException():
          debugPrint('Naver Map authentication failed: $ex');
        default:
          debugPrint('Naver Map authentication failed: $ex');
      }
    },
  );
}
