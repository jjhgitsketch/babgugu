import 'package:flutter/foundation.dart';

class AppTabEvents {
  AppTabEvents._();

  static final ValueNotifier<int> homeRedirectTick = ValueNotifier<int>(0);

  static void goHome() {
    homeRedirectTick.value++;
  }
}
