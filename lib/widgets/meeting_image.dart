import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

class MeetingImage extends StatelessWidget {
  final MeetingModel meeting;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final Color fallbackColor;
  final double iconSize;
  final bool showFallbackIcon;
  final BoxFit fit;

  const MeetingImage({
    super.key,
    required this.meeting,
    this.width,
    this.height,
    this.borderRadius = BorderRadius.zero,
    this.fallbackColor = const Color(0xFFFFEEEE),
    this.iconSize = 42,
    this.showFallbackIcon = true,
    this.fit = BoxFit.cover,
  });

  IconData get _fallbackIcon => meeting.type == MeetingType.delivery
      ? Icons.delivery_dining_rounded
      : Icons.restaurant_rounded;

  @override
  Widget build(BuildContext context) {
    final imageUrl = meeting.imageUrl?.trim() ?? '';

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: width,
        height: height,
        child: imageUrl.isEmpty
            ? _FallbackImage(
                color: fallbackColor,
                icon: _fallbackIcon,
                iconSize: iconSize,
                showIcon: showFallbackIcon,
              )
            : Image.network(
                imageUrl,
                width: width,
                height: height,
                fit: fit,
                errorBuilder: (_, __, ___) => _FallbackImage(
                  color: fallbackColor,
                  icon: _fallbackIcon,
                  iconSize: iconSize,
                  showIcon: showFallbackIcon,
                ),
              ),
      ),
    );
  }
}

class _FallbackImage extends StatelessWidget {
  final Color color;
  final IconData icon;
  final double iconSize;
  final bool showIcon;

  const _FallbackImage({
    required this.color,
    required this.icon,
    required this.iconSize,
    required this.showIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      alignment: Alignment.center,
      child: showIcon
          ? Icon(icon, size: iconSize, color: AppColors.primary)
          : null,
    );
  }
}
