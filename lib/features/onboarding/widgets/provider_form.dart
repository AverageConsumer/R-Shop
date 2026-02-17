import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/widgets/console_focusable.dart';
import '../../../models/config/provider_config.dart';
import '../../../services/romm_api_service.dart';
import '../onboarding_controller.dart';
import 'connection_test_indicator.dart';

class ProviderForm extends ConsumerStatefulWidget {
  const ProviderForm({super.key});

  @override
  ConsumerState<ProviderForm> createState() => _ProviderFormState();
}

class _ProviderFormState extends ConsumerState<ProviderForm> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};

  TextEditingController _getController(String key, String? initialValue) {
    if (!_controllers.containsKey(key)) {
      _controllers[key] = TextEditingController(text: initialValue ?? '');
    }
    return _controllers[key]!;
  }

  FocusNode _getFocusNode(String key) {
    if (!_focusNodes.containsKey(key)) {
      _focusNodes[key] = FocusNode();
    }
    return _focusNodes[key]!;
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  void _syncField(String key, String value) {
    ref.read(onboardingControllerProvider.notifier).updateProviderField(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final form = state.providerForm;
    if (form == null) return const SizedBox.shrink();

    final rs = context.rs;
    final controller = ref.read(onboardingControllerProvider.notifier);

    final isRomm = form.type == ProviderType.romm;
    final canSave = !isRomm || state.hasRommPlatformSelected;

    return FocusTraversalGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(rs, form),
          SizedBox(height: rs.spacing.md),
          _buildTypeSelector(rs, form, controller),
          SizedBox(height: rs.spacing.md),
          ..._buildFieldsForType(rs, form),
          SizedBox(height: rs.spacing.md),
          ConnectionTestIndicator(
            isTesting: state.isTestingConnection,
            isSuccess: state.connectionTestSuccess,
            error: state.connectionTestError,
          ),
          if (isRomm) ...[
            SizedBox(height: rs.spacing.md),
            _buildRommPlatformSection(rs, state, controller),
          ],
          SizedBox(height: rs.spacing.md),
          _buildActions(rs, state, controller, canSave: canSave),
        ],
      ),
    );
  }

  Widget _buildHeader(Responsive rs, ProviderFormState form) {
    final fontSize = rs.isSmall ? 14.0 : 16.0;
    return Text(
      form.isEditing ? 'Edit Source' : 'Add Source',
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildTypeSelector(
    Responsive rs,
    ProviderFormState form,
    OnboardingController controller,
  ) {
    final types = ProviderType.values;
    final chipFontSize = rs.isSmall ? 11.0 : 13.0;

    return Wrap(
      spacing: rs.spacing.sm,
      runSpacing: rs.spacing.sm,
      children: types.map((type) {
        final selected = form.type == type;
        return ConsoleFocusable(
          onSelect: () {
            controller.setProviderType(type);
            for (final c in _controllers.values) {
              c.clear();
            }
          },
          borderRadius: rs.radius.round,
          child: GestureDetector(
            onTap: () {
              controller.setProviderType(type);
              for (final c in _controllers.values) {
                c.clear();
              }
            },
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: EdgeInsets.symmetric(
                horizontal: rs.spacing.md,
                vertical: rs.spacing.md,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.redAccent.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(rs.radius.round),
                border: Border.all(
                  color: selected
                      ? Colors.redAccent.withValues(alpha: 0.7)
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Text(
                type.name.toUpperCase(),
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white54,
                  fontSize: chipFontSize,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  List<Widget> _buildFieldsForType(Responsive rs, ProviderFormState form) {
    switch (form.type) {
      case ProviderType.web:
        return [
          _buildTextField(rs, 'url', 'URL', 'https://...', form),
          SizedBox(height: rs.spacing.sm),
          _buildTextField(rs, 'path', 'Path', '/roms/nes/ (optional)', form),
          SizedBox(height: rs.spacing.sm),
          _buildTextField(rs, 'user', 'Username', '(optional)', form),
          SizedBox(height: rs.spacing.sm),
          _buildTextField(rs, 'pass', 'Password', '(optional)', form,
              obscure: true),
        ];
      case ProviderType.ftp:
        return [
          _buildTextField(rs, 'host', 'Host', '192.168.1.100', form),
          SizedBox(height: rs.spacing.sm),
          _buildTextField(rs, 'port', 'Port', '21', form),
          SizedBox(height: rs.spacing.sm),
          _buildTextField(rs, 'path', 'Path', '/roms/nes/', form),
          SizedBox(height: rs.spacing.sm),
          _buildTextField(rs, 'user', 'Username', '(optional)', form),
          SizedBox(height: rs.spacing.sm),
          _buildTextField(rs, 'pass', 'Password', '(optional)', form,
              obscure: true),
        ];
      case ProviderType.smb:
        return [
          _buildTextField(rs, 'host', 'Host', '192.168.1.100', form),
          SizedBox(height: rs.spacing.sm),
          _buildTextField(rs, 'port', 'Port', '445', form),
          SizedBox(height: rs.spacing.sm),
          _buildTextField(rs, 'share', 'Share', 'roms', form),
          SizedBox(height: rs.spacing.sm),
          _buildTextField(rs, 'path', 'Path', '/nes/', form),
          SizedBox(height: rs.spacing.sm),
          _buildTextField(rs, 'user', 'Username', '(optional)', form),
          SizedBox(height: rs.spacing.sm),
          _buildTextField(rs, 'pass', 'Password', '(optional)', form,
              obscure: true),
        ];
      case ProviderType.romm:
        return [
          _buildTextField(rs, 'url', 'URL', 'https://romm.example.com', form),
          SizedBox(height: rs.spacing.sm),
          _buildTextField(rs, 'apiKey', 'API Key', '(optional)', form),
          SizedBox(height: rs.spacing.sm),
          _buildTextField(rs, 'user', 'Username', '(optional)', form),
          SizedBox(height: rs.spacing.sm),
          _buildTextField(rs, 'pass', 'Password', '(optional)', form,
              obscure: true),
        ];
    }
  }

  Widget _buildRommPlatformSection(
    Responsive rs,
    OnboardingState state,
    OnboardingController controller,
  ) {
    final fontSize = rs.isSmall ? 11.0 : 13.0;
    final labelFontSize = rs.isSmall ? 10.0 : 12.0;

    // Loading state
    if (state.isFetchingRommPlatforms) {
      return Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.redAccent.withValues(alpha: 0.7),
            ),
          ),
          SizedBox(width: rs.spacing.sm),
          Text(
            'Fetching platforms...',
            style: TextStyle(color: Colors.grey.shade400, fontSize: fontSize),
          ),
        ],
      );
    }

    // Error state
    if (state.rommFetchError != null) {
      return const SizedBox.shrink();
    }

    final platforms = state.rommPlatforms;
    if (platforms == null || platforms.isEmpty) {
      // Not fetched yet or empty
      if (state.connectionTestSuccess && platforms != null && platforms.isEmpty) {
        return Text(
          'No platforms found on this RomM server.',
          style: TextStyle(color: Colors.orange.shade300, fontSize: fontSize),
        );
      }
      return const SizedBox.shrink();
    }

    final matched = state.rommMatchedPlatform;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PLATFORM',
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: labelFontSize,
            letterSpacing: 1,
          ),
        ),
        SizedBox(height: rs.spacing.xs),
        if (matched != null) _buildMatchedPlatformChip(rs, matched, controller),
        SizedBox(height: rs.spacing.sm),
        _buildPlatformDropdown(rs, platforms, matched, controller),
      ],
    );
  }

  Widget _buildMatchedPlatformChip(
    Responsive rs,
    RommPlatform platform,
    OnboardingController controller,
  ) {
    final fontSize = rs.isSmall ? 11.0 : 13.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: rs.spacing.md,
        vertical: rs.spacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(rs.radius.sm),
        border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade300, size: 16),
          SizedBox(width: rs.spacing.sm),
          Flexible(
            child: Text(
              '${platform.name} (${platform.romCount} ROMs)',
              style: TextStyle(color: Colors.green.shade200, fontSize: fontSize),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformDropdown(
    Responsive rs,
    List<RommPlatform> platforms,
    RommPlatform? selected,
    OnboardingController controller,
  ) {
    final fontSize = rs.isSmall ? 12.0 : 14.0;

    // Sort platforms by name for display
    final sorted = List<RommPlatform>.from(platforms)
      ..sort((a, b) => a.name.compareTo(b.name));

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(rs.radius.sm),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      padding: EdgeInsets.symmetric(horizontal: rs.spacing.md),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selected?.id,
          isExpanded: true,
          dropdownColor: const Color(0xFF1A1A1A),
          hint: Text(
            'Pick a platform...',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: fontSize,
            ),
          ),
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontFamily: 'monospace',
          ),
          items: sorted.map((p) {
            return DropdownMenuItem<int>(
              value: p.id,
              child: Text(
                '${p.name} (${p.romCount})',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (id) {
            if (id == null) return;
            final platform = platforms.firstWhere((p) => p.id == id);
            controller.selectRommPlatform(platform);
          },
        ),
      ),
    );
  }

  Widget _buildTextField(
    Responsive rs,
    String key,
    String label,
    String hint,
    ProviderFormState form, {
    bool obscure = false,
  }) {
    final fontSize = rs.isSmall ? 12.0 : 14.0;
    final labelFontSize = rs.isSmall ? 10.0 : 12.0;
    final fieldController = _getController(key, form.fields[key]?.toString());
    final focusNode = _getFocusNode(key);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: labelFontSize,
            letterSpacing: 1,
          ),
        ),
        SizedBox(height: rs.spacing.xs),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(rs.radius.sm),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: TextField(
            controller: fieldController,
            focusNode: focusNode,
            obscureText: obscure,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.grey.shade700,
                fontSize: fontSize,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: rs.spacing.md,
                vertical: rs.spacing.md,
              ),
            ),
            onChanged: (value) => _syncField(key, value),
          ),
        ),
      ],
    );
  }

  Widget _buildActions(
    Responsive rs,
    OnboardingState state,
    OnboardingController controller, {
    bool canSave = true,
  }) {
    final buttonFontSize = rs.isSmall ? 12.0 : 14.0;

    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            rs: rs,
            label: 'Test',
            icon: Icons.wifi_tethering,
            fontSize: buttonFontSize,
            onTap: state.isTestingConnection ? null : controller.testProviderConnection,
          ),
        ),
        SizedBox(width: rs.spacing.sm),
        Expanded(
          child: _buildActionButton(
            rs: rs,
            label: 'Save',
            icon: Icons.check,
            fontSize: buttonFontSize,
            onTap: canSave ? controller.saveProvider : null,
            primary: true,
          ),
        ),
        SizedBox(width: rs.spacing.sm),
        Expanded(
          child: _buildActionButton(
            rs: rs,
            label: 'Cancel',
            icon: Icons.close,
            fontSize: buttonFontSize,
            onTap: controller.cancelProviderForm,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required Responsive rs,
    required String label,
    required IconData icon,
    required double fontSize,
    VoidCallback? onTap,
    bool primary = false,
  }) {
    final iconSize = rs.isSmall ? 14.0 : 18.0;
    return ConsoleFocusable(
      onSelect: onTap,
      borderRadius: rs.radius.sm,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: EdgeInsets.symmetric(
            horizontal: rs.spacing.md,
            vertical: rs.spacing.md,
          ),
          decoration: BoxDecoration(
            color: primary
                ? Colors.redAccent.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(rs.radius.sm),
            border: Border.all(
              color: primary
                  ? Colors.redAccent.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: onTap == null ? Colors.white24 : Colors.white70, size: iconSize),
              SizedBox(width: rs.spacing.xs),
              Text(
                label,
                style: TextStyle(
                  color: onTap == null ? Colors.white24 : Colors.white,
                  fontSize: fontSize,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
