// lib/map_init_native.dart
import 'package:flutter_naver_map/flutter_naver_map.dart';

Future<void> initNaverMap() async {
  // flutter_naver_map 1.3.1 최신 초기화 방식
  await FlutterNaverMap().init(
    clientId: 'dk4xnd02dq',
    onAuthFailed: (ex) {
      switch (ex) {
        case NUnauthorizedClientException():
          print('인증 실패 - 클라이언트 ID 또는 패키지명 확인 필요: $ex');
        default:
          print('네이버 지도 인증 실패: $ex');
      }
    },
  );
}
