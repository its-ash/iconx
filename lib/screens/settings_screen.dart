import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const UiScaffold(
      appBar: UiAppBar(title: 'Settings'),
      scrollable: true,
      body: UiColumn(
        gap: UiSpace.lg,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UiAppearanceSection(),
          UiUpdateSection(storeId: 'iconx'),
          UiDeveloperSection(),
        ],
      ),
    );
  }
}
