import 'package:flutter/material.dart';

class CircleIconButtonWidget extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const CircleIconButtonWidget({
    super.key,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.black87, size: 22),
        ),
      ),
    );
  }
}
