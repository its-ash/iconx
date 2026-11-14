import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../icons/icon_source.dart';
import '../icons/pixel_icon_view.dart';

/// The gallery: every icon by group, with search. Tap an icon for a big preview and the apps it
/// replaces.
class IconsTab extends StatefulWidget {
  const IconsTab({super.key, required this.icons});

  final List<PixelIcon> icons;

  @override
  State<IconsTab> createState() => _IconsTabState();
}

class _IconsTabState extends State<IconsTab> {
  String _query = '';

  List<PixelIcon> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.icons;
    return [
      for (final i in widget.icons)
        if (i.label.toLowerCase().contains(q) || i.name.contains(q) || i.packages.any((p) => p.contains(q))) i,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final icons = _filtered;
    final groups = <String, List<PixelIcon>>{};
    for (final i in icons) {
      groups.putIfAbsent(i.group, () => []).add(i);
    }
    return UiColumn(
      gap: UiSpace.lg,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiSearchField(hint: 'Search ${widget.icons.length} icons', onChanged: (v) => setState(() => _query = v)),
        if (icons.isEmpty)
          const UiEmptyState(
            icon: Icons.search_off_rounded,
            title: 'No icon found',
            message: 'Missing an app? Open Your apps and send an icon request.',
          ),
        for (final entry in groups.entries)
          UiColumn(
            gap: UiSpace.md,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UiSectionHeader(entry.key, subtitle: '${entry.value.length} icons'),
              UiResponsiveGrid(
                minItemWidth: 76,
                spacing: UiSpace.sm,
                runSpacing: UiSpace.md,
                children: [for (final i in entry.value) _IconCell(icon: i)],
              ),
            ],
          ),
      ],
    );
  }
}

class _IconCell extends StatelessWidget {
  const _IconCell({required this.icon});

  final PixelIcon icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(UiRadius.md),
      onTap: () => showIconDetail(context, icon),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: UiSpace.xs),
        child: Column(
          children: [
            PixelIconView(icon, size: 56),
            const SizedBox(height: UiSpace.xs),
            Text(
              icon.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: context.text.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Big preview and the launcher components the icon replaces.
Future<void> showIconDetail(BuildContext context, PixelIcon icon) {
  return UiSheet.show<void>(
    context,
    title: icon.label,
    subtitle: icon.group,
    child: UiColumn(
      gap: UiSpace.lg,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: PixelIconView(icon, size: 180)),
        UiKeyValueList([
          UiKeyValue('Drawable', icon.name, mono: true),
          for (final c in icon.components) UiKeyValue('Replaces', c, mono: true, stacked: true, maxLines: 3),
        ]),
      ],
    ),
  );
}
