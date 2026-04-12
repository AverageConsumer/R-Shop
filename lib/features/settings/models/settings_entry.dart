import 'package:flutter/material.dart';

enum SettingsEntryType { nav, toggle, cycle, slider, spinner, custom }

class SettingsSection {
  final String title;
  final List<SettingsEntry> entries;
  const SettingsSection(this.title, this.entries);
}

class SettingsEntry {
  final String title;
  final String subtitle;
  final SettingsEntryType type;
  final FocusNode? focusNode;
  final VoidCallback? onTap;
  final bool? toggleValue;
  final String? displayValue;
  final IconData? icon;
  final double? sliderValue;
  final ValueChanged<double>? onSliderChanged;
  final int? spinnerValue;
  final int? spinnerMin;
  final int? spinnerMax;
  final ValueChanged<int>? onSpinnerChanged;
  final Widget? custom;

  const SettingsEntry._({
    required this.title,
    required this.subtitle,
    required this.type,
    this.focusNode,
    this.onTap,
    this.toggleValue,
    this.displayValue,
    this.icon,
    this.sliderValue,
    this.onSliderChanged,
    this.spinnerValue,
    this.spinnerMin,
    this.spinnerMax,
    this.onSpinnerChanged,
    this.custom,
  });

  const SettingsEntry.nav({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onSelect,
    FocusNode? focusNode,
  }) : this._(
          title: title,
          subtitle: subtitle,
          type: SettingsEntryType.nav,
          icon: icon,
          onTap: onSelect,
          focusNode: focusNode,
        );

  const SettingsEntry.toggle({
    required String title,
    required String subtitle,
    required bool value,
    required VoidCallback onChanged,
    FocusNode? focusNode,
  }) : this._(
          title: title,
          subtitle: subtitle,
          type: SettingsEntryType.toggle,
          toggleValue: value,
          onTap: onChanged,
          focusNode: focusNode,
        );

  const SettingsEntry.cycle({
    required String title,
    required String subtitle,
    required String displayValue,
    required VoidCallback onCycle,
    FocusNode? focusNode,
  }) : this._(
          title: title,
          subtitle: subtitle,
          type: SettingsEntryType.cycle,
          displayValue: displayValue,
          onTap: onCycle,
          focusNode: focusNode,
        );

  const SettingsEntry.slider({
    required String title,
    required String subtitle,
    required double value,
    required ValueChanged<double> onChanged,
    FocusNode? focusNode,
  }) : this._(
          title: title,
          subtitle: subtitle,
          type: SettingsEntryType.slider,
          sliderValue: value,
          onSliderChanged: onChanged,
          focusNode: focusNode,
        );

  const SettingsEntry.spinner({
    required String title,
    required String subtitle,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
    FocusNode? focusNode,
  }) : this._(
          title: title,
          subtitle: subtitle,
          type: SettingsEntryType.spinner,
          spinnerValue: value,
          spinnerMin: min,
          spinnerMax: max,
          onSpinnerChanged: onChanged,
          focusNode: focusNode,
        );

  const SettingsEntry.custom({
    required Widget child,
    String title = '',
    String subtitle = '',
    VoidCallback? onTap,
    FocusNode? focusNode,
  }) : this._(
          title: title,
          subtitle: subtitle,
          type: SettingsEntryType.custom,
          custom: child,
          onTap: onTap,
          focusNode: focusNode,
        );
}
