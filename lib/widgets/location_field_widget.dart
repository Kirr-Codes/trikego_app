import 'package:flutter/material.dart';
import '../utils/dialog_utils.dart';

class LocationFieldWidget extends StatelessWidget {
  final String hintText;
  final String? displayText;
  final IconData icon;
  final Color iconColor;
  final bool isCurrentLocation;
  final VoidCallback? onTap;

  const LocationFieldWidget({
    super.key,
    required this.hintText,
    this.displayText,
    required this.icon,
    required this.iconColor,
    this.isCurrentLocation = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ??
          (isCurrentLocation && displayText != null
              ? () => DialogUtils.showFullAddressDialog(context, displayText!)
              : null),
      child: Container(
        decoration: BoxDecoration(
          color: isCurrentLocation
              ? Colors.green.shade50
              : const Color(0xFFF2F2F4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isCurrentLocation
                ? Colors.green.shade200
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                displayText ?? hintText,
                style: TextStyle(
                  fontSize: 14,
                  color: displayText != null
                      ? Colors.black87
                      : Colors.black.withValues(alpha: 0.4),
                  fontWeight: displayText != null
                      ? FontWeight.w500
                      : FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            if (isCurrentLocation && displayText != null)
              Icon(
                Icons.visibility_outlined,
                size: 16,
                color: Colors.green.shade600,
              ),
          ],
        ),
      ),
    );
  }
}
