import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationService {
  static const fallbackAddress = '';

  static Future<String> getCurrentAddress(BuildContext context) async {
    final position = await getCurrentPosition(context);
    if (position == null) return fallbackAddress;
    return getAddressFromLatLng(position.latitude, position.longitude);
  }

  static Future<Position?> getCurrentPosition(BuildContext context) async {
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
      debugPrint('[LocationService] getCurrentPosition error: $e');
      return null;
    }
  }

  static Future<LocationPermission> _ensureLocationPermission(
    BuildContext context,
  ) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationPermission.denied;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  static Future<String> getAddressFromLatLng(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://maps.apigw.ntruss.com/map-reversegeocode/v2/gc'
        '?coords=$lng,$lat&output=json&orders=roadaddr,addr',
      );
      final response = await http.get(uri, headers: {
        'x-ncp-apigw-api-key-id': 'dk4xnd02dq',
        'x-ncp-apigw-api-key': 'JOdRUbGW1KbmNrLUQNDAVNc4Rkm4Loox9NtyYMqr',
      }).timeout(const Duration(seconds: 5));

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
            var address = '$area1 $area2 $area3'.trim();

            if (land != null && name == 'roadaddr') {
              final roadName = land['name'] ?? '';
              final number1 = land['number1'] ?? '';
              final roadAddress = '$roadName $number1'.trim();
              if (roadAddress.isNotEmpty) {
                address = '$address $roadAddress'.trim();
              }
            } else if (land != null) {
              final number1 = land['number1'] ?? '';
              final number2 = land['number2'] ?? '';
              final lotAddress =
                  '$number1${number2.isNotEmpty ? '-$number2' : ''}'.trim();
              if (lotAddress.isNotEmpty) {
                address = '$address $lotAddress'.trim();
              }
            }

            if (address.isNotEmpty) return address;
          }
        }
      }
    } catch (e) {
      debugPrint('[LocationService] reverse geocode error: $e');
    }
    return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  }
}
