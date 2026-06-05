// lib/screens/notification_screen.dart
import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.markAllRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifications = NotificationService.instance.notifications;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('알림'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: notifications.isEmpty
          ? const Center(
              child: Text('알림이 없어요', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            )
          : ListView.separated(
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.divider),
              itemBuilder: (_, i) {
                final n = notifications[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications_rounded, color: AppColors.primary, size: 20),
                  ),
                  title: Text(n.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text(n.body, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                );
              },
            ),
    );
  }
}
