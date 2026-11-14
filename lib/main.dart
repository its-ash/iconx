import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import 'platform/launcher_channel.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const IconXApp(platform: MethodChannelLauncherPlatform()));
}

class IconXApp extends StatelessWidget {
  const IconXApp({super.key, required this.platform});

  final LauncherPlatform platform;

  @override
  Widget build(BuildContext context) {
    return UiApp(
      title: 'iconX',
      home: HomeScreen(platform: platform),
    );
  }
}
