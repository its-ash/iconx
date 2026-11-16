import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../icons/icon_source.dart';
import '../platform/launcher_channel.dart';
import 'apply_tab.dart';
import 'apps_tab.dart';
import 'icons_tab.dart';
import 'settings_screen.dart';

/// Icons (the gallery), Your apps (coverage on this phone) and Apply (launchers).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.platform, this.iconLoader = loadIcons});

  final LauncherPlatform platform;
  final Future<List<PixelIcon>> Function() iconLoader;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<PixelIcon>> _icons = widget.iconLoader();
  int _tab = 0;

  void _openSettings() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PixelIcon>>(
      future: _icons,
      builder: (context, snap) {
        final icons = snap.data;
        // Lazy page: the tabs return slivers, so only the icons and rows on screen are built.
        return UiScaffold.slivers(
          appBar: UiAppBar(
            title: 'iconX',
            actions: [UiIconButton(Icons.settings_rounded, tooltip: 'Settings', onPressed: _openSettings)],
          ),
          gap: UiSpace.lg,
          slivers: [
            if (snap.hasError)
              SliverToBoxAdapter(
                child: UiErrorState(
                  message: 'Could not load the icons.\n${snap.error}',
                  onRetry: () => setState(() => _icons = widget.iconLoader()),
                ),
              )
            else if (icons == null)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: UiSpace.xxxl),
                  child: Center(child: UiSpinner(size: 28)),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: UiTabs(
                  tabs: const [
                    UiTab('Icons', icon: Icons.grid_view_rounded),
                    UiTab('Your apps', icon: Icons.apps_rounded),
                    UiTab('Apply', icon: Icons.check_circle_rounded),
                  ],
                  index: _tab,
                  variant: UiTabsVariant.segment,
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ),
              switch (_tab) {
                0 => IconsTab(icons: icons),
                1 => AppsTab(icons: icons, platform: widget.platform),
                _ => SliverToBoxAdapter(child: ApplyTab(platform: widget.platform)),
              },
            ],
          ],
        );
      },
    );
  }
}
