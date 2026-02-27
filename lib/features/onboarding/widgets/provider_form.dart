import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/console_focusable.dart';
import '../../../models/config/provider_config.dart';
import '../../../providers/app_providers.dart';
import '../../../services/romm_api_service.dart';
import '../onboarding_controller.dart';
import 'connection_test_indicator.dart';

/// Returns true when the URL points at a private/local network address.
bool isPrivateNetworkUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  final host = uri.host;
  if (host.isEmpty) return false;
  if (host == 'localhost' || host == '127.0.0.1') return true;
  final privateIp = RegExp(
    r'^(10\.\d+\.\d+\.\d+|192\.168\.\d+\.\d+|172\.(1[6-9]|2\d|3[01])\.\d+\.\d+)$',
  );
  return privateIp.hasMatch(host);
}

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
  final GlobalKey _testIndicatorKey = GlobalKey();

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

  bool _isHttpWithCredentials(ProviderFormState form) {
    final url = form.fields['url']?.toString() ?? '';
    if (!url.startsWith('http://') || isPrivateNetworkUrl(url)) {
      return false;
    }
    final hasAuth = (form.fields['user']?.toString() ?? '').isNotEmpty ||
        (form.fields['pass']?.toString() ?? '').isNotEmpty ||
        (form.fields['apiKey']?.toString() ?? '').isNotEmpty;
    return hasAuth;
  }

  bool _isNonLanHttp(ProviderFormState form) {
    final url = form.fields['url']?.toString() ?? '';
    return url.startsWith('http://') && !isPrivateNetworkUrl(url);
  }

  bool _isNonLanHttpBlocked(ProviderFormState form) {
    if (!_isNonLanHttp(form)) return false;
    final storage = ref.read(storageServiceProvider);
    return !storage.getAllowNonLanHttp();
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
    _syncControllersWithForm();
  }

  /// Updates TextEditingController values from the current form state after a type switch.
  void _syncControllersWithForm() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final form = ref.read(onboardingControllerProvider).providerForm;
      if (form == null) return;

      // Clear all controllers first
      for (final c in _controllers.values) {
        c.clear();
      }

      // Restore values from form fields
      for (final entry in form.fields.entries) {
        final value = entry.value?.toString() ?? '';
        if (value.isNotEmpty) {
          _getController(entry.key, null).text = value;
        }
      }

      // Auto-fill RomM from global if empty
      if (form.type == ProviderType.romm) {
        final urlField = form.fields['url']?.toString() ?? '';
        if (urlField.isEmpty) {
          _autoFillRommFromGlobal();
        }
      }
    });
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
      } catch (e) {
        debugPrint('ProviderForm: auth autofill failed: $e');
      }
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

    // Auto-scroll to test indicator when error or success appears
    ref.listen(
      onboardingControllerProvider.select((s) => (s.connectionTestError, s.connectionTestSuccess, s.isTestingConnection)),
      (prev, next) {
        if (next.$1 != null || next.$2 || next.$3) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final ctx = _testIndicatorKey.currentContext;
            if (ctx != null) {
              Scrollable.ensureVisible(ctx,
                  duration: const Duration(milliseconds: 300),
                  alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
            }
          });
        }
      },
    );

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
          if (_isNonLanHttpBlocked(form))
            Padding(
              padding: EdgeInsets.only(bottom: rs.spacing.sm),
              child: Row(
                children: [
                  Icon(Icons.block, color: Colors.red.shade300, size: 16),
                  SizedBox(width: rs.spacing.xs),
                  Expanded(
                    child: Text(
                      'HTTP to non-local servers is blocked. '
                      'Use HTTPS, or enable after setup in Settings.',
                      style: TextStyle(
                        color: Colors.red.shade300,
                        fontSize: rs.isSmall ? 10 : 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_isHttpWithCredentials(form))
            Padding(
              padding: EdgeInsets.only(bottom: rs.spacing.sm),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange.shade300, size: 16),
                  SizedBox(width: rs.spacing.xs),
                  Expanded(
                    child: Text(
                      'Credentials will be sent unencrypted over HTTP',
                      style: TextStyle(
                        color: Colors.orange.shade300,
                        fontSize: rs.isSmall ? 10 : 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ConnectionTestIndicator(
            key: _testIndicatorKey,
            isTesting: state.isTestingConnection,
            isSuccess: state.connectionTestSuccess,
            error: state.connectionTestError,
          ),
          if (isRomm) ...[
            SizedBox(height: rs.spacing.md),
            _buildRommPlatformSection(rs, state, controller),
          ],
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
        const SingleActivator(LogicalKeyboardKey.arrowLeft, includeRepeats: false): () => _cycleType(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight, includeRepeats: false): () => _cycleType(1),
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
                _syncControllersWithForm();
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
          SizedBox(height: rs.spacing.sm),
          _buildTextField(rs, 'domain', 'Domain', '(optional)', form),
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
          ListenableBuilder(
            listenable: textFocusNode,
            builder: (context, child) {
              final hasFocus = textFocusNode.hasFocus;
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF252525),
                  borderRadius: BorderRadius.circular(rs.radius.sm),
                  border: Border.all(
                    color: hasFocus
                        ? AppTheme.primaryColor
                        : AppTheme.primaryColor.withValues(alpha: 0.4),
                    width: 2,
                  ),
                  boxShadow: hasFocus
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: child,
              );
            },
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape, includeRepeats: false): () =>
                    consoleFocusNode.requestFocus(),
                const SingleActivator(LogicalKeyboardKey.gameButtonB, includeRepeats: false): () =>
                    consoleFocusNode.requestFocus(),
                const SingleActivator(LogicalKeyboardKey.goBack, includeRepeats: false): () =>
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
