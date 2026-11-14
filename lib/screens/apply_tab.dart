import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../platform/launcher_channel.dart';

/// Launchers that support icon packs, with one-tap apply where the launcher allows it.
class ApplyTab extends StatefulWidget {
  const ApplyTab({super.key, required this.platform});

  final LauncherPlatform platform;

  @override
  State<ApplyTab> createState() => _ApplyTabState();
}

class _ApplyTabState extends State<ApplyTab> {
  late Future<List<LauncherInfo>> _launchers = widget.platform.launchers();

  Future<void> _apply(LauncherInfo l) async {
    final r = await widget.platform.apply(l.id);
    if (!mounted) return;
    switch (r) {
      case ApplyResult.applied:
        context.showToast('Sent iconX to ${l.name}');
      case ApplyResult.opened:
        context.showToast('In ${l.name}, open its settings and choose iconX as the icon pack');
      case ApplyResult.failed:
        context.showToast('Could not open ${l.name}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LauncherInfo>>(
      future: _launchers,
      builder: (context, snap) {
        final launchers = snap.data;
        if (launchers == null) {
          if (snap.hasError) {
            return UiErrorState(
              message: 'Could not check your launchers.',
              onRetry: () => setState(() => _launchers = widget.platform.launchers()),
            );
          }
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: UiSpace.xxxl),
            child: Center(child: UiSpinner(size: 28)),
          );
        }
        final installed = launchers.where((l) => l.installed).toList();
        final others = launchers.where((l) => !l.installed).toList();
        return UiColumn(
          gap: UiSpace.lg,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const UiAlert(
              'Most phones\' built-in home screens (Motorola, Samsung, Pixel) do not load icon packs. '
              'Install a launcher that does, such as Lawnchair or Nova, and set it as your home app.',
              title: 'You need an icon pack launcher',
              status: UiStatus.info,
            ),
            if (installed.isNotEmpty)
              UiListGroup(
                header: 'On this phone',
                children: [
                  for (final l in installed)
                    UiListTile(
                      l.name,
                      subtitle: l.isDefault ? 'Your home screen' : 'Installed',
                      icon: Icons.home_rounded,
                      iconStatus: l.isDefault ? UiStatus.success : UiStatus.accent,
                      trailing: UiButton('Apply', size: UiSize.sm, onPressed: () => _apply(l)),
                    ),
                ],
              ),
            UiListGroup(
              header: installed.isEmpty ? 'Supported launchers' : 'Also supported',
              footer: 'In any of these: launcher settings, then Icon pack (or Icon style), then iconX.',
              children: [
                for (final l in others)
                  UiListTile(l.name, icon: Icons.home_outlined, iconStatus: UiStatus.neutral, value: 'Not installed'),
              ],
            ),
            UiButton(
              'Check again',
              icon: Icons.refresh_rounded,
              variant: UiButtonVariant.secondary,
              onPressed: () => setState(() => _launchers = widget.platform.launchers()),
            ),
          ],
        );
      },
    );
  }
}
