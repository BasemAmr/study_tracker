import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/typography.dart';
import '../../../core/providers/timer_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/utils/session_atmosphere_utils.dart';
import '../../../domain/domain.dart';
import '../../../l10n/app_localizations.dart';

class FullscreenTimerScreen extends ConsumerStatefulWidget {
  final String backgroundImage;
  final StudySessionMode selectedMode;
  final ValueChanged<StudySessionMode> onModeChanged;
  final Future<void> Function() onStopAndSave;

  const FullscreenTimerScreen({
    super.key,
    required this.backgroundImage,
    required this.selectedMode,
    required this.onModeChanged,
    required this.onStopAndSave,
  });

  @override
  ConsumerState<FullscreenTimerScreen> createState() => _FullscreenTimerScreenState();
}

class _FullscreenTimerScreenState extends ConsumerState<FullscreenTimerScreen> {
  static const String _cityBg = 'assets/backgrounds/city-twilight.png';
  static const String _cozyBg = 'assets/backgrounds/cozy-cafe.png';

  late String _backgroundImage;
  late StudySessionMode _selectedMode;

  @override
  void initState() {
    super.initState();
    _backgroundImage = widget.backgroundImage;
    _selectedMode = widget.selectedMode;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  bool get _isCustomBackground => _backgroundImage != _cityBg && _backgroundImage != _cozyBg;

  Future<void> _pickCustomBackground() async {
    final l10n = AppLocalizations.of(context)!;
    final selectedPath = await pickAndStoreSessionOverlayImage();
    if (selectedPath == null || !mounted) return;

    setState(() {
      _backgroundImage = selectedPath;
    });

    final settings = ref.read(settingsProvider);
    settings.updateField(defaultBackground: selectedPath);
    await settings.saveSettings();

    final dir = await getSessionOverlayImagesDirectory();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.sessionCustomOverlaySaved(dir.path)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickOverlayHue() async {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.read(settingsProvider);
    var hue = (settings.settings.overlayHue ?? 210).toDouble().clamp(0.0, 360.0).toDouble();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final preview = HSVColor.fromAHSV(1, hue, 0.45, 0.25).toColor();
            return AlertDialog(
              title: Text(l10n.sessionOverlayHueTitle),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 44,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: preview,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0x66FFFFFF), width: 1.2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(l10n.sessionHueValue(hue.round())),
                    Slider(
                      value: hue.toDouble(),
                      min: 0,
                      max: 360,
                      onChanged: (value) => setModalState(() => hue = value),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l10n.apply),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) return;
    settings.updateField(overlayHue: hue.round());
    await settings.saveSettings();
  }

  void _close() {
    Navigator.of(context).pop(_backgroundImage);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final timerState = ref.watch(timerProvider);
    final settings = ref.watch(settingsProvider).settings;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: isAssetBackgroundPath(_backgroundImage)
                ? Image.asset(
                    _backgroundImage,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: const Color(0xFF2C352C)),
                  )
                : Image.file(
                    File(_backgroundImage),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: const Color(0xFF2C352C)),
                  ),
          ),
          Positioned.fill(
            child: Container(
              color: HSVColor.fromAHSV(
                (settings.overlayOpacity ?? 0.5).clamp(0.0, 1.0).toDouble(),
                ((settings.overlayHue ?? 210) % 360).toDouble(),
                0.45,
                0.24,
              ).toColor(),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compactTop = constraints.maxWidth < 380;
                      return Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _StatusBadge(timerProvider: timerState),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _close,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: compactTop ? 10 : 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black38,
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.close_fullscreen, color: Colors.white70, size: 16),
                                  if (!compactTop) ...[
                                    const SizedBox(width: 6),
                                    Text(l10n.sessionExitFullscreen, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const Spacer(),
                if (!timerState.isTimerActive)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ModePill(
                          label: l10n.sessionModePomodoro,
                          icon: Icons.timer,
                          isSelected: _selectedMode == StudySessionMode.pomodoro,
                          onTap: () {
                            setState(() => _selectedMode = StudySessionMode.pomodoro);
                            widget.onModeChanged(_selectedMode);
                          },
                        ),
                        _ModePill(
                          label: l10n.sessionModeLongSession,
                          icon: Icons.schedule,
                          isSelected: _selectedMode == StudySessionMode.longSession,
                          onTap: () {
                            setState(() => _selectedMode = StudySessionMode.longSession);
                            widget.onModeChanged(_selectedMode);
                          },
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    timerState.isTimerActive ? timerState.timerDisplay : '00:00',
                    style: TextStyle(
                      fontFamily: AppTypography.monoFont,
                      fontSize: 160,
                      fontWeight: FontWeight.w200,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  timerState.isTimerActive
                      ? l10n.sessionFocusedMinutes(timerState.totalSeconds ~/ 60)
                      : (_selectedMode == StudySessionMode.pomodoro
                          ? l10n.sessionFocusBreakLine(settings.focusMinutes, settings.breakMinutes)
                          : l10n.sessionContinuousFocusMode),
                  style: AppTypography.textTheme.bodyLarge?.copyWith(
                    color: Colors.white70,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 36),
                _FullscreenControls(
                  timerProvider: timerState,
                  settings: settings,
                  selectedMode: _selectedMode,
                  onStopAndSave: widget.onStopAndSave,
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _TextButton(
                        label: l10n.sessionAtmosphereCityTwilight,
                        isActive: _backgroundImage == _cityBg,
                        onTap: () => setState(() => _backgroundImage = _cityBg),
                      ),
                      _TextButton(
                        label: l10n.sessionAtmosphereCozyCafe,
                        isActive: _backgroundImage == _cozyBg,
                        onTap: () => setState(() => _backgroundImage = _cozyBg),
                      ),
                      _TextButton(
                        label: l10n.sessionAtmosphereCustom,
                        isActive: _isCustomBackground,
                        icon: Icons.image,
                        onTap: _pickCustomBackground,
                      ),
                      _TextButton(
                        label: l10n.sessionAtmosphereOverlay,
                        isActive: false,
                        icon: Icons.color_lens,
                        onTap: _pickOverlayHue,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final TimerProvider timerProvider;

  const _StatusBadge({required this.timerProvider});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    IconData icon = Icons.timer;
    String text = l10n.sessionStatusReady;

    if (timerProvider.state == TimerState.breakPhase) {
      icon = Icons.coffee;
      text = l10n.sessionStatusBreakTime;
    } else if (timerProvider.state == TimerState.paused) {
      icon = Icons.pause;
      text = l10n.sessionStatusPaused;
    } else if (timerProvider.state == TimerState.running) {
      icon = Icons.track_changes;
      text = l10n.sessionStatusFocusing;
    }

    final modeLabel = timerProvider.mode == StudySessionMode.pomodoro
        ? l10n.sessionModePomodoro
        : timerProvider.mode == StudySessionMode.longSession
            ? l10n.sessionModeLongSession
            : l10n.sessionModeManual;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
          if (timerProvider.isTimerActive) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                modeLabel,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ]
        ],
      ),
    );
  }
}

class _FullscreenControls extends StatelessWidget {
  final TimerProvider timerProvider;
  final dynamic settings;
  final StudySessionMode selectedMode;
  final Future<void> Function() onStopAndSave;

  const _FullscreenControls({
    required this.timerProvider,
    required this.settings,
    required this.selectedMode,
    required this.onStopAndSave,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (!timerProvider.isTimerActive) {
      return GestureDetector(
        onTap: () => timerProvider.start(
          selectedMode,
          focusMinutes: settings.focusMinutes,
          breakMinutes: settings.breakMinutes,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(40),
            boxShadow: const [BoxShadow(color: Colors.black26, offset: Offset(0, 4), blurRadius: 10)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_arrow, color: Colors.black87),
              const SizedBox(width: 8),
              Text(l10n.sessionStart, style: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    if (timerProvider.state == TimerState.breakPhase) {
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        children: [
          _HollowButton(label: l10n.sessionSkipBreak, onTap: () => timerProvider.skipBreak()),
          _DangerButton(icon: Icons.stop, label: l10n.sessionStopAndSave, onTap: onStopAndSave),
        ],
      );
    }

    if (timerProvider.state == TimerState.paused) {
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        children: [
          GestureDetector(
            onTap: () => timerProvider.resume(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_arrow, color: Colors.black87),
                  const SizedBox(width: 8),
                  Text(l10n.sessionResume, style: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          _DangerButton(icon: Icons.stop, label: l10n.sessionStopAndSave, onTap: onStopAndSave),
        ],
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      children: [
        _HollowButton(icon: Icons.pause, label: l10n.sessionPause, onTap: () => timerProvider.pause()),
        _DangerButton(icon: Icons.stop, label: l10n.sessionStopAndSave, onTap: onStopAndSave),
      ],
    );
  }
}

class _ModePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModePill({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.black87 : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.black87 : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HollowButton extends StatelessWidget {
  final IconData? icon;
  final String label;
  final VoidCallback onTap;

  const _HollowButton({this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, color: Colors.white), const SizedBox(width: 8)],
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DangerButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.2),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.red[200]),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: Colors.red[200], fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

class _TextButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final IconData? icon;
  final VoidCallback onTap;

  const _TextButton({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white24 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 14, color: Colors.white54), const SizedBox(width: 4)],
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
