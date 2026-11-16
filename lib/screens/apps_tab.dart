import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../icons/coverage.dart';
import '../icons/icon_source.dart';
import '../icons/pixel_icon_view.dart';
import '../platform/launcher_channel.dart';
import 'icons_tab.dart';

/// The apps on this phone: which ones iconX themes, which ones it misses, and an icon request.
/// A sliver: the app lists are lazy, so only the rows on screen are built.
class AppsTab extends StatefulWidget {
  const AppsTab({super.key, required this.icons, required this.platform});

  final List<PixelIcon> icons;
  final LauncherPlatform platform;

  @override
  State<AppsTab> createState() => _AppsTabState();
}

class _AppsTabState extends State<AppsTab> {
  late Future<List<InstalledApp>> _apps = widget.platform.apps();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<InstalledApp>>(
      future: _apps,
      builder: (context, snap) {
        if (snap.hasError) {
          return SliverToBoxAdapter(
            child: UiErrorState(
              message: 'Could not list your apps.',
              onRetry: () => setState(() => _apps = widget.platform.apps()),
            ),
          );
        }
        final apps = snap.data;
        if (apps == null) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: UiSpace.xxxl),
              child: Center(child: UiSpinner(size: 28)),
            ),
          );
        }
        final c = Coverage.of(widget.icons, apps);
        final requestable = [...c.missing, for (final (app, _) in c.packageOnly) app];
        const gap = EdgeInsets.only(top: UiSpace.lg);
        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: UiResponsiveGrid(
                minItemWidth: 140,
                spacing: UiSpace.sm,
                equalHeight: true,
                children: [
                  UiStatCard(
                    label: 'Themed',
                    value: '${c.themed.length} of ${c.total}',
                    icon: Icons.check_circle_rounded,
                    iconStatus: UiStatus.success,
                  ),
                  UiStatCard(
                    label: 'Not yet',
                    value: '${requestable.length}',
                    icon: Icons.hourglass_empty_rounded,
                    iconStatus: requestable.isEmpty ? UiStatus.success : UiStatus.warning,
                  ),
                ],
              ),
            ),
            if (requestable.isNotEmpty)
              SliverPadding(
                padding: gap,
                sliver: SliverToBoxAdapter(
                  child: UiButton(
                    'Request ${requestable.length} icons',
                    icon: Icons.send_rounded,
                    expand: true,
                    onPressed: () => widget.platform.share(Coverage.requestText(requestable)),
                  ),
                ),
              ),
            if (c.packageOnly.isNotEmpty)
              SliverPadding(
                padding: gap,
                sliver: UiSliverListGroup(
                  header: 'Icon exists, app changed',
                  footer:
                      'An update renamed these apps\' start screen, so launchers no longer match the icon. '
                      'Include them in your request.',
                  itemCount: c.packageOnly.length,
                  itemBuilder: (context, i) {
                    final (app, icon) = c.packageOnly[i];
                    return UiListTile(
                      app.label,
                      subtitle: app.component,
                      leading: PixelIconView(icon, size: 40),
                      maxSubtitleLines: 2,
                    );
                  },
                ),
              ),
            if (c.missing.isNotEmpty)
              SliverPadding(
                padding: gap,
                sliver: UiSliverListGroup(
                  header: 'No icon yet',
                  itemCount: c.missing.length,
                  itemBuilder: (context, i) => UiListTile(
                    c.missing[i].label,
                    subtitle: c.missing[i].component,
                    icon: Icons.crop_square_rounded,
                    iconStatus: UiStatus.neutral,
                    maxSubtitleLines: 2,
                  ),
                ),
              ),
            if (c.themed.isNotEmpty)
              SliverPadding(
                padding: gap,
                sliver: UiSliverListGroup(
                  header: 'Themed',
                  itemCount: c.themed.length,
                  itemBuilder: (context, i) {
                    final (app, icon) = c.themed[i];
                    return UiListTile(
                      app.label,
                      leading: PixelIconView(icon, size: 40),
                      chevron: true,
                      onTap: () => showIconDetail(context, icon),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
