import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../icons/icon_source.dart';
import '../icons/pixel_icon_view.dart';

/// The gallery: every icon by group, with search. Tap an icon for a big preview and the apps it
/// replaces. A sliver holding one flat lazy list (like `ListView.builder`): each group header and
/// each row of icons is one entry, built only when it scrolls near the screen.
class IconsTab extends StatefulWidget {
  const IconsTab({super.key, required this.icons});

  final List<PixelIcon> icons;

  @override
  State<IconsTab> createState() => _IconsTabState();
}

class _IconsTabState extends State<IconsTab> {
  String _query = '';

  static const _minCellWidth = 76.0;

  @override
  void initState() {
    super.initState();
    // Make the icon images in idle time, so scrolling never has to.
    precachePixelIcons(widget.icons);
  }

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
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: UiSearchField(
            hint: 'Search ${widget.icons.length} icons',
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        if (icons.isEmpty)
          const SliverPadding(
            padding: EdgeInsets.only(top: UiSpace.lg),
            sliver: SliverToBoxAdapter(
              child: UiEmptyState(
                icon: Icons.search_off_rounded,
                title: 'No icon found',
                message: 'Missing an app? Open Your apps and send an icon request.',
              ),
            ),
          ),
        SliverLayoutBuilder(
          builder: (context, constraints) {
            final cols = UiResponsiveGrid.columnsFor(
              constraints.crossAxisExtent,
              minItemWidth: _minCellWidth,
              spacing: UiSpace.sm,
            );
            final entries = <_Entry>[
              for (final g in groups.entries) ...[
                _Header(g.key, g.value.length),
                for (var i = 0; i < g.value.length; i += cols)
                  _IconRow(g.value.sublist(i, (i + cols).clamp(0, g.value.length))),
              ],
            ];
            return SliverList.builder(
              itemCount: entries.length,
              itemBuilder: (context, i) => switch (entries[i]) {
                // Later headers sit under a row that already adds UiSpace.md below it.
                _Header(:final group, :final count) => Padding(
                  padding: EdgeInsets.only(top: i == 0 ? UiSpace.lg : UiSpace.lg - UiSpace.md, bottom: UiSpace.md),
                  child: UiSectionHeader(group, subtitle: '$count icons'),
                ),
                _IconRow(:final icons) => Padding(
                  padding: const EdgeInsets.only(bottom: UiSpace.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var c = 0; c < cols; c++) ...[
                        if (c > 0) const SizedBox(width: UiSpace.sm),
                        Expanded(child: c < icons.length ? _IconCell(icon: icons[c]) : const SizedBox.shrink()),
                      ],
                    ],
                  ),
                ),
              },
            );
          },
        ),
      ],
    );
  }
}

/// One entry of the flat gallery list.
sealed class _Entry {
  const _Entry();
}

class _Header extends _Entry {
  const _Header(this.group, this.count);

  final String group;
  final int count;
}

class _IconRow extends _Entry {
  const _IconRow(this.icons);

  final List<PixelIcon> icons;
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
