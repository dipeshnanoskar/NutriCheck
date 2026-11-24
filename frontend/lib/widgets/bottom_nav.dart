import 'package:flutter/material.dart';
import '../core/theme.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onChanged;

  const AppBottomNav({super.key, required this.currentIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = const [
      (icon: Icons.home_rounded, label: 'Home'),
      (icon: Icons.qr_code_scanner_rounded, label: 'Scan'),
      (icon: Icons.history_rounded, label: 'History'),
      (icon: Icons.person_rounded, label: 'Profile'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (i) {
            final active = i == currentIndex;
            final item = items[i];
            return InkWell(
              onTap: () => onChanged(i),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      color: active ? AppColors.greenPrimary : AppColors.muted,
                      size: 24,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: active ? AppColors.greenPrimary : AppColors.muted,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
