import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iconx/main.dart';
import 'package:iconx/platform/launcher_channel.dart';

/// Frame timings while flinging through the icon gallery. Run on a phone:
/// `make perf` (profile mode). The report is written to build/gallery_scroll.timeline_summary.json.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('gallery scroll', (tester) async {
    await tester.pumpWidget(const IconXApp(platform: MethodChannelLauncherPlatform()));
    await tester.pumpAndSettle();
    final list = find.byType(Scrollable).first;

    await binding.watchPerformance(() async {
      for (var i = 0; i < 6; i++) {
        await tester.fling(list, const Offset(0, -1500), 4000);
        await tester.pumpAndSettle();
      }
      for (var i = 0; i < 6; i++) {
        await tester.fling(list, const Offset(0, 1500), 4000);
        await tester.pumpAndSettle();
      }
    }, reportKey: 'gallery_scroll');
  });
}
