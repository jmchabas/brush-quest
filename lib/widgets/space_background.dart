import 'package:flutter/material.dart';

class SpaceBackground extends StatelessWidget {
  final Widget child;

  const SpaceBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D0B2E),
        image: DecorationImage(
          image: AssetImage('assets/images/background_space.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: child,
    );
  }
}
