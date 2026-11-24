import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/history_item.dart';
import 'status_badge.dart';

class HistoryCard extends StatelessWidget {
  final HistoryItem item;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const HistoryCard({super.key, required this.item, this.onTap, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(kCardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: item.image.isNotEmpty
                ? Image.network(item.image, width: 52, height: 52, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fallbackThumb())
                : _fallbackThumb(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)),
                if (item.brand.isNotEmpty)
                  Text(item.brand,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusBadge(status: item.overall, fontSize: 11),
        ],
      ),
    );

    final tappable = InkWell(borderRadius: BorderRadius.circular(kCardRadius), onTap: onTap, child: card);

    if (onDismiss == null) return tappable;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: AppColors.redLight, borderRadius: BorderRadius.circular(kCardRadius)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: AppColors.red),
      ),
      onDismissed: (_) => onDismiss!(),
      child: tappable,
    );
  }

  Widget _fallbackThumb() => Container(
        width: 52,
        height: 52,
        color: AppColors.greenLight,
        child: const Icon(Icons.fastfood_rounded, color: AppColors.greenPrimary, size: 22),
      );
}
