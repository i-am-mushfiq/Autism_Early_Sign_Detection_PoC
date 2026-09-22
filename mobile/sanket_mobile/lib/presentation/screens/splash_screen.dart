import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/sanket_logo.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SanketLogo(size: 92, showWordmark: true),
                SizedBox(height: 36),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: SanketColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
