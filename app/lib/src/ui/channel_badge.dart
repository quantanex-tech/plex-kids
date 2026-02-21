import 'package:flutter/material.dart';

class ChannelBadge extends StatelessWidget {
  final String imageUrl;
  final VoidCallback onTap;

  const ChannelBadge({super.key, required this.imageUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2),
          ),
          child: ClipOval(
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.tv),
            ),
          ),
        ),
      ),
    );
  }
}
