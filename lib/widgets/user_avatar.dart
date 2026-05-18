import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/avatar_option.dart';

/// Avatar com SVG ou inicial de fallback.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.avatarId,
    required this.fallbackInitial,
    this.radius = 40,
  });

  final String? avatarId;
  final String fallbackInitial;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final option = AvatarOption.byId(avatarId);
    final d = radius * 2;

    if (option != null) {
      return ClipOval(
        child: Container(
          width: d,
          height: d,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: SvgPicture.asset(
            option.assetPath,
            width: d,
            height: d,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return _FallbackCircle(radius: radius, letter: fallbackInitial);
  }
}

class _FallbackCircle extends StatelessWidget {
  const _FallbackCircle({required this.radius, required this.letter});

  final double radius;
  final String letter;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      child: Text(
        letter.isNotEmpty ? letter.substring(0, 1).toUpperCase() : '?',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    );
  }
}
