import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/widgets/console_focusable.dart';
import '../../../models/config/provider_config.dart';
import '../../../providers/app_providers.dart';
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
  final Map<String, FocusNode> _consoleFocusNodes = {};
  final FocusNode _typeSelectorFocusNode = FocusNode(debugLabel: 'typeSelector');

  TextEditingController _getController(String key, String? initialValue) {
    if (!_controllers.containsKey(key)) {
      _controllers[key] = TextEditingController(text: initialValue ?? '');
    }
    return _controllers[key]!;
  }

  FocusNode _getFocusNode(String key) {
    if (!_focusNodes.containsKey(key)) {
      _focusNodes[key] = FocusNode(skipTraversal: true);
    }
    return _focusNodes[key]!;
  }

  FocusNode _getConsoleFocusNode(String key) {
    if (!_consoleFocusNodes.containsKey(key)) {
      _consoleFocusNodes[key] = FocusNode(debugLabel: 'console_$key');
    }
    return _consoleFocusNodes[key]!;
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focusNodes.values) {
      f.dispose();
    }
    for (final f in _consoleFocusNodes.values) {
      f.dispose();
    }
    _typeSelectorFocusNode.dispose();
    super.dispose();
  }

  void _syncField(String key, String value) {
    ref.read(onboardingControllerProvider.notifier).updateProviderField(key, value);
  }

  void _cycleType(int delta) {
    final state = ref.read(onboardingControllerProvider);
    final form = state.providerForm;
    if (form == null) return;
    const types = ProviderType.values;
    final currentIndex = types.indexOf(form.type);
    final newIndex = (currentIndex + delta) % types.length;
    ref.read(onboardingControllerProvider.notifier).setProviderType(types[newIndex]);
    for (final c in _controllers.values) {
      c.clear();
    }
    if (types[newIndex] == ProviderType.romm) {
      _autoFillRommFromGlobal();
    }
  }

  void _autoFillRommFromGlobal() {
    final storage = ref.read(storageServiceProvider);
    final globalUrl = storage.getRommUrl();
    if (globalUrl == null || globalUrl.isEmpty) return;

    // Pre-fill URL
    _getController('url', null).text = globalUrl;
    _syncField('url', globalUrl);

    // Pre-fill auth
    final authJson = storage.getRommAuth();
    if (authJson != null) {
      try {
        final map = jsonDecode(authJson) as Map<String, dynamic>;
        final auth = AuthConfig.fromJson(map);
        if (auth.apiKey != null && auth.apiKey!.isNotEmpty) {
          _getController('apiKey', null).text = auth.apiKey!;
          _syncField('apiKey', auth.apiKey!);
        }
        if (auth.user != null && auth.user!.isNotEmpty) {
          _getController('user', null).text = auth.user!;
          _syncField('user', auth.user!);
        }
        if (auth.pass != null && auth.pass!.isNotEmpty) {
          _getController('pass', null).text = auth.pass!;
          _syncField('pass', auth.pass!);
        }
      } catch (_) {}
    }
  }

  bool _didAutoFill = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final form = state.providerForm;
    if (form == null) return const SizedBox.shrink();

    final rs = context.rs;
    final controller = ref.read(onboardingControllerProvider.notifier);

    final isRomm = form.type == ProviderType.romm;

    // Auto-fill from global config on first render if RomM and URL empty
    if (isRomm && !_didAutoFill && !form.isEditing) {
      final urlField = form.fields['url']?.toString() ?? '';
      if (urlField.isEmpty) {
        _didAutoFill = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _autoFillRommFromGlobal();
        });
      }
    }
    if (!isRomm) _didAutoFill = false;

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
          SizedBox(height: rs.spacing.lg),
          _buildSaveButton(rs, state, controller),
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
    const types = ProviderType.values;
    final chipFontSize = rs.isSmall ? 11.0 : 13.0;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _cycleType(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _cycleType(1),
      },
      child: ConsoleFocusable(
        focusNode: _typeSelectorFocusNode,
        autofocus: true,
        focusScale: 1.0,
        borderRadius: rs.radius.sm,
        child: Wrap(
          spacing: rs.spacing.sm,
          runSpacing: rs.spacing.sm,
          children: types.map((type) {
            final selected = form.type == type;
            return GestureDetector(
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
            );
          }).toList(),
        ),
      ),
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

  bool _canSave(ProviderFormState form, OnboardingState state) {
    final fields = form.fields;
    bool hasField(String key) =>
        (fields[key]?.toString() ?? '').trim().isNotEmpty;

    switch (form.type) {
      case ProviderType.web:
        return hasField('url');
      case ProviderType.ftp:
        return hasField('host') && hasField('port') && hasField('path');
      case ProviderType.smb:
        return hasField('host') && hasField('port') &&
               hasField('share') && hasField('path');
      case ProviderType.romm:
        return hasField('url') && state.hasRommPlatformSelected;
    }
  }

  Widget _buildSaveButton(
    Responsive rs,
    OnboardingState state,
    OnboardingController controller,
  ) {
    final fontSize = rs.isSmall ? 12.0 : 14.0;
    final form = state.providerForm;
    final canSave = form != null && _canSave(form, state);

    return ConsoleFocusable(
      onSelect: canSave ? controller.saveProvider : null,
      borderRadius: rs.radius.sm,
      child: GestureDetector(
        onTap: canSave ? controller.saveProvider : null,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 48),
          padding: EdgeInsets.symmetric(vertical: rs.spacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: canSave
                  ? [
                      Colors.green.withValues(alpha: 0.3),
                      Colors.green.withValues(alpha: 0.15),
                    ]
                  : [
                      Colors.grey.withValues(alpha: 0.1),
                      Colors.grey.withValues(alpha: 0.05),
                    ],
            ),
            borderRadius: BorderRadius.circular(rs.radius.sm),
            border: Border.all(
              color: canSave
                  ? Colors.green.withValues(alpha: 0.5)
                  : Colors.grey.withValues(alpha: 0.2),
            ),
          ),
          child: Center(
            child: Text(
              'Save',
              style: TextStyle(
                color: canSave ? Colors.white : Colors.white38,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
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
    final textFocusNode = _getFocusNode(key);
    final consoleFocusNode = _getConsoleFocusNode(key);

    return ConsoleFocusable(
      key: ValueKey('field_$key'),
      focusNode: consoleFocusNode,
      focusScale: 1.0,
      borderRadius: rs.radius.sm,
      onSelect: () => textFocusNode.requestFocus(),
      child: Column(
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
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape): () =>
                    consoleFocusNode.requestFocus(),
                const SingleActivator(LogicalKeyboardKey.gameButtonB): () =>
                    consoleFocusNode.requestFocus(),
                const SingleActivator(LogicalKeyboardKey.goBack): () =>
                    consoleFocusNode.requestFocus(),
              },
              child: TextField(
                controller: fieldController,
                focusNode: textFocusNode,
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
                onSubmitted: (_) => consoleFocusNode.requestFocus(),
              ),
            ),
          ),
        ],
      ),
    );
  }

}
