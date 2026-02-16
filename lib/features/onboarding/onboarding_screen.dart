import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/responsive/responsive.dart';
import '../../providers/app_providers.dart';
import '../../providers/download_providers.dart';
import '../../widgets/console_hud.dart';
import '../../widgets/download_overlay.dart';
import 'onboarding_controller.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/folder_analysis_view.dart';
import 'widgets/pixel_mascot.dart';
import '../../services/rom_folder_service.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final FocusNode _focusNode = FocusNode();
  final GlobalKey<_RepoUrlStepState> _repoUrlKey = GlobalKey<_RepoUrlStepState>();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final isOverlayExpanded = ref.read(downloadOverlayExpandedProvider);
    if (isOverlayExpanded) {
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final state = ref.read(onboardingControllerProvider);
    if (state.needsRepoUrl) {
      if (event.logicalKey == LogicalKeyboardKey.gameButtonA ||
          event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.select) {
        _repoUrlKey.currentState?.submit();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.gameButtonY) {
        _repoUrlKey.currentState?.pasteFromClipboard();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.gameButtonB ||
          event.logicalKey == LogicalKeyboardKey.backspace ||
          event.logicalKey == LogicalKeyboardKey.escape) {
        _handleBack();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.gameButtonA ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.select) {
      _handleContinue();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.gameButtonB ||
        event.logicalKey == LogicalKeyboardKey.backspace ||
        event.logicalKey == LogicalKeyboardKey.escape) {
      _handleBack();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _handleContinue() {
    final state = ref.read(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final feedback = ref.read(feedbackServiceProvider);
    final audioManager = ref.read(audioManagerProvider);
    if (!state.canProceed) return;
    if (state.needsRepoUrl) {
      _repoUrlKey.currentState?.submit();
      return;
    }
    audioManager.stopTyping();
    if (state.isLastStep) {
      feedback.success();
      _finishOnboarding();
    } else if (state.needsFolderSelection && state.folderAnalysis == null) {
      feedback.tick();
      _pickFolder();
    } else {
      feedback.tick();
      controller.nextStep();
    }
  }

  void _handleBack() {
    final state = ref.read(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final feedback = ref.read(feedbackServiceProvider);
    final audioManager = ref.read(audioManagerProvider);
    if (!state.isFirstStep) {
      audioManager.stopTyping();
      feedback.cancel();
      controller.previousStep();
    }
  }

  Future<void> _pickFolder() async {
    final storageService = ref.read(storageServiceProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final path = await storageService.pickFolder();
    if (path != null) {
      await controller.setRomPath(path);
    }
  }

  void _finishOnboarding() async {
    final state = ref.read(onboardingControllerProvider);
    final storage = ref.read(storageServiceProvider);
    final romPath = state.romPath;
    if (romPath != null) {
      ref.read(romPathProvider.notifier).state = romPath;
    }
    final repoUrl = state.repoUrl;
    if (repoUrl != null) {
      ref.read(repoUrlProvider.notifier).state = repoUrl;
    }
    await storage.setOnboardingCompleted(true);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final rs = context.rs;
    ref.listen(onboardingControllerProvider.select((s) => s.currentStep), (prev, next) {
      if (next != OnboardingStep.repoUrl) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_focusNode.hasFocus) {
            _focusNode.requestFocus();
          }
        });
      }
    });
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            _handleBack();
          }
        },
        child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            const _AnimatedBackground(),
            const _RadialGlow(),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: rs.isSmall ? rs.spacing.md : rs.spacing.lg,
                  vertical: rs.isSmall ? rs.spacing.lg : rs.spacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: rs.isSmall ? rs.spacing.xl : 40),
                    rs.isPortrait
                        ? _buildPortraitContent(state, rs)
                        : _buildLandscapeContent(state, rs),
                    const Spacer(),
                  ],
                ),
              ),
            ),
            _buildControls(state, rs),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildLandscapeContent(OnboardingState state, Responsive rs) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PixelMascot(size: rs.isSmall ? 36 : 48),
        Expanded(
          child: _buildContent(state),
        ),
      ],
    );
  }

  Widget _buildPortraitContent(OnboardingState state, Responsive rs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            PixelMascot(size: rs.isSmall ? 32 : 40),
            SizedBox(width: rs.spacing.sm),
          ],
        ),
        SizedBox(height: rs.spacing.sm),
        _buildContent(state),
      ],
    );
  }

  Widget _buildContent(OnboardingState state) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: _buildStepContent(state),
    );
  }

  Widget _buildStepContent(OnboardingState state) {
    final controller = ref.read(onboardingControllerProvider.notifier);
    switch (state.currentStep) {
      case OnboardingStep.welcome:
        return _WelcomeStep(onComplete: controller.onMessageComplete);
      case OnboardingStep.legalNotice:
        return _LegalNoticeStep(onComplete: controller.onMessageComplete);
      case OnboardingStep.repoUrl:
        return _RepoUrlStep(
          key: _repoUrlKey,
          isTestingConnection: state.isTestingConnection,
          error: state.repoUrlError,
          onSubmit: controller.submitRepoUrl,
          onComplete: controller.onMessageComplete,
        );
      case OnboardingStep.folderSelect:
        return _FolderSelectStep(
          canProceed: state.canProceed,
          onSelectFolder: _pickFolder,
          onComplete: controller.onMessageComplete,
        );
      case OnboardingStep.folderAnalysis:
        return _FolderAnalysisStep(
          result: state.folderAnalysis,
          isCreatingFolders: state.isCreatingFolders,
          createdFolders: state.createdFolders,
          onComplete: controller.onMessageComplete,
        );
      case OnboardingStep.complete:
        return _CompleteStep(
          gameCount: state.folderAnalysis?.totalGames ?? 0,
          systemCount: state.folderAnalysis?.existingFoldersCount ?? 0,
          onComplete: controller.onMessageComplete,
        );
    }
  }

  Widget _buildControls(OnboardingState state, Responsive rs) {
    return ConsoleHud(
      buttons: [
        ControlButton(
          label: 'A',
          action: state.isLastStep
              ? 'Start!'
              : state.needsFolderSelection
                  ? 'Select'
                  : state.needsRepoUrl
                      ? 'Connect'
                      : 'Continue',
          onTap: state.canProceed ? _handleContinue : null,
          highlight: state.canProceed,
        ),
        if (!state.isFirstStep)
          ControlButton(
            label: 'B',
            action: 'Back',
            onTap: _handleBack,
          ),
        if (state.needsRepoUrl)
          ControlButton(
            label: 'Y',
            action: 'Paste',
            onTap: () => _repoUrlKey.currentState?.pasteFromClipboard(),
          ),
        if (ref.watch(downloadCountProvider) > 0)
          ControlButton(
            label: '',
            action: 'Downloads',
            icon: Icons.play_arrow_rounded,
            highlight: true,
            onTap: () => toggleDownloadOverlay(ref),
          ),
      ],
    );
  }
}

class _AnimatedBackground extends StatelessWidget {
  const _AnimatedBackground();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.redAccent.withValues(alpha: 0.25),
            Colors.redAccent.withValues(alpha: 0.12),
            const Color(0xFF080808),
            const Color(0xFF030303),
            Colors.black,
          ],
          stops: const [0.0, 0.15, 0.35, 0.6, 1.0],
        ),
      ),
    );
  }
}

class _RadialGlow extends StatelessWidget {
  const _RadialGlow();
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.3, -0.3),
              radius: 1.2,
              colors: [
                Colors.redAccent.withValues(alpha: 0.35),
                Colors.redAccent.withValues(alpha: 0.15),
                Colors.redAccent.withValues(alpha: 0.05),
                Colors.transparent,
              ],
              stops: const [0.0, 0.3, 0.6, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  final VoidCallback onComplete;
  const _WelcomeStep({required this.onComplete});
  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final labelFontSize = rs.isSmall ? 10.0 : 12.0;
    return Column(
      key: const ValueKey('welcome'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChatBubble(
          message:
              "Hey there! I'm Pixel, your R-Shop guide! Ready to explore your retro game collection?",
          onComplete: onComplete,
        ),
        SizedBox(height: rs.spacing.md),
        Padding(
          padding: EdgeInsets.only(left: rs.isSmall ? 40 : 60),
          child: Text(
            'Welcome to R-Shop',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: labelFontSize,
              letterSpacing: 2,
            ),
          ),
        ),
      ],
    );
  }
}

class _LegalNoticeStep extends StatelessWidget {
  final VoidCallback onComplete;
  const _LegalNoticeStep({required this.onComplete});
  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final labelFontSize = rs.isSmall ? 10.0 : 12.0;
    final iconSize = rs.isSmall ? 12.0 : 16.0;
    return Column(
      key: const ValueKey('legalNotice'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChatBubble(
          message:
              "Heads up! R-Shop connects to a file server YOU configure to browse and download ROMs. Make sure you have the legal right to download any content \u2013 respect copyright laws in your region.",
          onComplete: onComplete,
        ),
        SizedBox(height: rs.spacing.md),
        Padding(
          padding: EdgeInsets.only(left: rs.isSmall ? 40 : 60),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.orange.shade400, size: iconSize),
              SizedBox(width: rs.spacing.sm),
              Text(
                'LEGAL NOTICE',
                style: TextStyle(
                  color: Colors.orange.shade400,
                  fontSize: labelFontSize,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RepoUrlStep extends StatefulWidget {
  final bool isTestingConnection;
  final String? error;
  final Future<void> Function(String url) onSubmit;
  final VoidCallback onComplete;

  const _RepoUrlStep({
    super.key,
    required this.isTestingConnection,
    required this.error,
    required this.onSubmit,
    required this.onComplete,
  });

  @override
  State<_RepoUrlStep> createState() => _RepoUrlStepState();
}

class _RepoUrlStepState extends State<_RepoUrlStep> {
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _textFieldFocusNode = FocusNode();
  bool _connectionSuccess = false;

  bool get hasText => _urlController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _textFieldFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _RepoUrlStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isTestingConnection && !widget.isTestingConnection && widget.error == null) {
      setState(() => _connectionSuccess = true);
    }
  }

  Future<void> pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _urlController.text = data!.text!;
    }
  }

  void submit() {
    if (widget.isTestingConnection) return;
    final url = _urlController.text.trim();
    if (url.isNotEmpty) {
      setState(() => _connectionSuccess = false);
      widget.onSubmit(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final labelFontSize = rs.isSmall ? 10.0 : 12.0;
    final iconSize = rs.isSmall ? 12.0 : 16.0;

    return Column(
      key: const ValueKey('repoUrl'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChatBubble(
          message:
              "Now paste your repository URL. This should point to a file server with an Apache-style directory listing.",
          onComplete: widget.onComplete,
        ),
        SizedBox(height: rs.isSmall ? rs.spacing.md : rs.spacing.lg),
        Padding(
          padding: EdgeInsets.only(left: rs.isSmall ? 40 : 60),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF2A2A2A),
                      const Color(0xFF1A1A1A),
                      const Color(0xFF222222),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(rs.radius.md),
                  border: Border.all(
                    color: widget.error != null
                        ? Colors.redAccent.withValues(alpha: 0.8)
                        : _connectionSuccess
                            ? Colors.green.withValues(alpha: 0.8)
                            : Colors.redAccent.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.error != null
                          ? Colors.redAccent.withValues(alpha: 0.15)
                          : _connectionSuccess
                              ? Colors.green.withValues(alpha: 0.15)
                              : Colors.redAccent.withValues(alpha: 0.08),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        focusNode: _textFieldFocusNode,
                        enabled: !widget.isTestingConnection,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: rs.isSmall ? 13.0 : 15.0,
                          fontFamily: 'monospace',
                        ),
                        decoration: InputDecoration(
                          hintText: 'https://...',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: rs.isSmall ? 13.0 : 15.0,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: rs.spacing.md,
                            vertical: rs.spacing.sm,
                          ),
                        ),
                        onSubmitted: (_) => submit(),
                      ),
                    ),
                    _FocusableIconButton(
                      onTap: widget.isTestingConnection ? null : pasteFromClipboard,
                      icon: Icons.content_paste_rounded,
                      size: rs.isSmall ? 20.0 : 24.0,
                      padding: rs.spacing.sm,
                    ),
                  ],
                ),
              ),
              SizedBox(height: rs.spacing.sm),
              if (widget.isTestingConnection)
                Row(
                  children: [
                    SizedBox(
                      width: iconSize,
                      height: iconSize,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.redAccent.withValues(alpha: 0.7),
                      ),
                    ),
                    SizedBox(width: rs.spacing.sm),
                    Text(
                      'Testing connection...',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: labelFontSize,
                      ),
                    ),
                  ],
                )
              else if (_connectionSuccess)
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: iconSize),
                    SizedBox(width: rs.spacing.sm),
                    Text(
                      'Connection successful!',
                      style: TextStyle(
                        color: Colors.green.shade300,
                        fontSize: labelFontSize,
                      ),
                    ),
                  ],
                )
              else if (widget.error != null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, color: Colors.redAccent, size: iconSize),
                    SizedBox(width: rs.spacing.sm),
                    Expanded(
                      child: Text(
                        widget.error!,
                        style: TextStyle(
                          color: Colors.redAccent.shade100,
                          fontSize: labelFontSize,
                        ),
                      ),
                    ),
                  ],
                ),
              SizedBox(height: rs.spacing.md),
              _FocusableButton(
                onTap: widget.isTestingConnection ? null : submit,
                disabled: widget.isTestingConnection,
                borderRadius: rs.radius.lg,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.link_rounded,
                      color: widget.isTestingConnection ? Colors.white38 : Colors.white,
                      size: rs.isSmall ? 18 : 24,
                    ),
                    SizedBox(width: rs.spacing.sm),
                    Text(
                      'Connect',
                      style: TextStyle(
                        color: widget.isTestingConnection ? Colors.white38 : Colors.white,
                        fontSize: rs.isSmall ? 13.0 : 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FolderSelectStep extends StatelessWidget {
  final bool canProceed;
  final VoidCallback onSelectFolder;
  final VoidCallback onComplete;
  const _FolderSelectStep({
    required this.canProceed,
    required this.onSelectFolder,
    required this.onComplete,
  });
  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final buttonFontSize = rs.isSmall ? 13.0 : 16.0;
    final iconSize = rs.isSmall ? 18.0 : 24.0;
    return Column(
      key: const ValueKey('folderSelect'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChatBubble(
          message:
              "Let's set up your ROM folder! Press A or tap the button below to select your ES-DE roms directory.",
          onComplete: onComplete,
        ),
        SizedBox(height: rs.isSmall ? rs.spacing.lg : rs.spacing.xl),
        Padding(
          padding: EdgeInsets.only(left: rs.isSmall ? 40 : 60),
          child: GestureDetector(
            onTap: onSelectFolder,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: rs.isSmall ? rs.spacing.lg : rs.spacing.xl,
                vertical: rs.isSmall ? rs.spacing.sm : rs.spacing.md,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.redAccent.withValues(alpha: 0.3),
                    Colors.redAccent.withValues(alpha: 0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(rs.radius.lg),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withValues(alpha: 0.2),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_open, color: Colors.white, size: iconSize),
                  SizedBox(width: rs.spacing.sm),
                  Text(
                    'Select ROM Folder',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: buttonFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FolderAnalysisStep extends StatelessWidget {
  final FolderAnalysisResult? result;
  final bool isCreatingFolders;
  final List<String> createdFolders;
  final VoidCallback onComplete;
  const _FolderAnalysisStep({
    required this.result,
    required this.isCreatingFolders,
    required this.createdFolders,
    required this.onComplete,
  });
  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    if (result == null) {
      return const Column(
        key: ValueKey('folderAnalysis'),
        children: [
          ChatBubble(message: "Scanning your ROM folder...", onComplete: null),
        ],
      );
    }
    return Column(
      key: const ValueKey('folderAnalysis'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChatBubble(
          message:
              "Check this out! I found ${result!.totalGames} games across ${result!.existingFoldersCount} systems!",
          onComplete: onComplete,
        ),
        SizedBox(height: rs.spacing.md),
        FolderAnalysisView(
          result: result!,
          isCreatingFolders: isCreatingFolders,
          createdFolders: createdFolders,
        ),
      ],
    );
  }
}

class _CompleteStep extends StatelessWidget {
  final int gameCount;
  final int systemCount;
  final VoidCallback onComplete;
  const _CompleteStep({
    required this.gameCount,
    required this.systemCount,
    required this.onComplete,
  });
  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final labelFontSize = rs.isSmall ? 11.0 : 14.0;
    final iconSize = rs.isSmall ? 16.0 : 20.0;
    return Column(
      key: const ValueKey('complete'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChatBubble(
          message:
              "Perfect! You're all set up with $gameCount games across $systemCount systems. Have fun exploring! Press A to jump in.",
          onComplete: onComplete,
        ),
        SizedBox(height: rs.isSmall ? rs.spacing.lg : rs.spacing.xl),
        Padding(
          padding: EdgeInsets.only(left: rs.isSmall ? 40 : 60),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: rs.isSmall ? rs.spacing.md : rs.spacing.lg,
              vertical: rs.isSmall ? rs.spacing.sm : rs.spacing.md,
            ),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(rs.radius.md),
              border: Border.all(
                color: Colors.green.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: iconSize),
                SizedBox(width: rs.spacing.sm),
                Text(
                  'Setup Complete',
                  style: TextStyle(
                    color: Colors.green.shade300,
                    fontSize: labelFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FocusableIconButton extends StatefulWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final double size;
  final double padding;

  const _FocusableIconButton({
    required this.onTap,
    required this.icon,
    required this.size,
    required this.padding,
  });

  @override
  State<_FocusableIconButton> createState() => _FocusableIconButtonState();
}

class _FocusableIconButtonState extends State<_FocusableIconButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (focused) => setState(() => _focused = focused),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.gameButtonA ||
             event.logicalKey == LogicalKeyboardKey.select)) {
          widget.onTap?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: widget.padding),
          decoration: _focused
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ],
                )
              : null,
          child: Icon(
            widget.icon,
            color: _focused ? Colors.white : Colors.grey.shade400,
            size: widget.size,
          ),
        ),
      ),
    );
  }
}

class _FocusableButton extends StatefulWidget {
  final VoidCallback? onTap;
  final bool disabled;
  final double borderRadius;
  final Widget child;

  const _FocusableButton({
    required this.onTap,
    required this.disabled,
    required this.borderRadius,
    required this.child,
  });

  @override
  State<_FocusableButton> createState() => _FocusableButtonState();
}

class _FocusableButtonState extends State<_FocusableButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    return Focus(
      onFocusChange: (focused) => setState(() => _focused = focused),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.gameButtonA ||
             event.logicalKey == LogicalKeyboardKey.select)) {
          widget.onTap?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: rs.isSmall ? rs.spacing.lg : rs.spacing.xl,
            vertical: rs.isSmall ? rs.spacing.sm : rs.spacing.md,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.redAccent.withValues(alpha: widget.disabled ? 0.15 : 0.3),
                Colors.redAccent.withValues(alpha: widget.disabled ? 0.08 : 0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: _focused
                  ? Colors.redAccent.withValues(alpha: 0.9)
                  : Colors.redAccent.withValues(alpha: widget.disabled ? 0.2 : 0.5),
              width: _focused ? 2.5 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withValues(alpha: _focused ? 0.4 : 0.2),
                blurRadius: _focused ? 24 : 20,
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
