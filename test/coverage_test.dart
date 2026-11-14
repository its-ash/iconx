import 'package:flutter_test/flutter_test.dart';
import 'package:iconx/icons/coverage.dart';
import 'package:iconx/icons/icon_source.dart';
import 'package:iconx/platform/launcher_channel.dart';

void main() {
  final rows = List.filled(16, '#' * 16).join('\n');
  final icons = parseIcons(
    '[chrome]\nbg = #000000\nfg = #FFFFFF\napp = com.android.chrome/com.google.android.apps.chrome.Main\n$rows\n'
    '[maps]\nbg = #000000\nfg = #FFFFFF\napp = com.google.android.apps.maps/com.google.android.maps.MapsActivity\n$rows\n',
    file: 'google.txt',
  );

  test('exact component is themed, same package with a new activity is flagged, others missing', () {
    const apps = [
      InstalledApp(label: 'Chrome', component: 'com.android.chrome/com.google.android.apps.chrome.Main'),
      InstalledApp(label: 'Maps', component: 'com.google.android.apps.maps/com.google.android.maps.NewActivity'),
      InstalledApp(label: 'Notes', component: 'com.notes/com.notes.Main'),
    ];
    final c = Coverage.of(icons, apps);
    expect(c.themed.map((e) => e.$1.label), ['Chrome']);
    expect(c.packageOnly.map((e) => e.$2.name), ['maps']);
    expect(c.missing.map((e) => e.label), ['Notes']);
    expect(c.total, 3);
  });

  test('request text lists label and component', () {
    final text = Coverage.requestText(const [InstalledApp(label: 'Notes', component: 'com.notes/com.notes.Main')]);
    expect(text, contains('Notes: com.notes/com.notes.Main'));
    expect(text.split('\n').first, 'iconX icon request');
  });
}
