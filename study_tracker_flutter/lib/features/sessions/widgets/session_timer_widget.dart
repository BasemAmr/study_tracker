import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/providers/timer_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/utils/session_atmosphere_utils.dart';
import '../../../data/repositories/session_repository.dart';
import '../../../domain/domain.dart';
import '../../../l10n/app_localizations.dart';
import 'fullscreen_timer_screen.dart';

class SessionTimerWidget extends ConsumerStatefulWidget {
  const SessionTimerWidget({super.key});

  @override
  ConsumerState<SessionTimerWidget> createState() => _SessionTimerWidgetState();
}

class _SessionTimerWidgetState extends ConsumerState<SessionTimerWidget> {
  static const String _cityBg = 'assets/backgrounds/city-twilight.png';
  static const String _cozyBg = 'assets/backgrounds/cozy-cafe.png';

  StudySessionMode _selectedMode = StudySessionMode.pomodoro;
  bool _showDetails = false;
  int? _subjectId;
  String? _subjectName;
  String? _mood;
  String _backgroundImage = _cityBg;

  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = ref.read(settingsProvider).settings;
    if (settings.defaultBackground != null && settings.defaultBackground!.isNotEmpty) {
      _backgroundImage = settings.defaultBackground!;
    }
  }

  @override
  void dispose() {
    _topicController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _startTimer() {
    final settings = ref.read(settingsProvider).settings;
    ref.read(timerProvider).start(
      _selectedMode,
      focusMinutes: settings.focusMinutes,
      breakMinutes: settings.breakMinutes,
      subjectId: _subjectId,
      subjectName: _subjectName,
      topic: _topicController.text.trim().isEmpty ? null : _topicController.text.trim(),
      mood: _mood,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      backgroundImage: _backgroundImage,
    );
    setState(() {
      _showDetails = true;
    });
  }

  Future<void> _stopAndSaveSession() async {
    final timer = ref.read(timerProvider);
    
    // Update metadata one last time before stopping
    timer.topic = _topicController.text.trim().isEmpty ? null : _topicController.text.trim();
    timer.notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();
    timer.mood = _mood;
    timer.subjectId = _subjectId;
    timer.subjectName = _subjectName;

    timer.stop(); // This triggers auto-save in TimerProvider
    
    // Force instant UI refresh
    ref.invalidate(allSessionsProvider);
    ref.invalidate(sessionSummaryProvider);
    ref.invalidate(recentSessionsProvider);
    // Also invalidate the family member if possible, or just wait for the stream
    // Since it's a stream, it should update, but invalidation helps if it's cached.

    setState(() {
      _topicController.clear();
      _notesController.clear();
      _mood = null;
      _subjectId = null;
      _subjectName = null;
      _showDetails = false;
    });
  }

  Future<void> _openFullscreen() async {
    final selected = await Navigator.of(context, rootNavigator: true).push<String>(
      PageRouteBuilder(
        opaque: true,
        fullscreenDialog: true,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FullscreenTimerScreen(
            backgroundImage: _backgroundImage,
            selectedMode: _selectedMode,
            onModeChanged: (mode) => setState(() => _selectedMode = mode),
            onStopAndSave: _stopAndSaveSession,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _backgroundImage = selected;
      });
    }
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
                        border: Border.all(color: AppColors.outline, width: 2),
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

  @override
  Widget build(BuildContext context) {
    // Listen for profile changes to reset setup
    ref.listen<int>(
      settingsProvider.select((s) => s.currentProfileId),
      (prev, next) {
        if (prev != next && prev != null) {
          setState(() {
            _subjectId = null;
            _subjectName = null;
            _topicController.clear();
            _notesController.clear();
            _mood = null;
          });
        }
      },
    );

    final l10n = AppLocalizations.of(context)!;
    final timerState = ref.watch(timerProvider);
    final settings = ref.watch(settingsProvider).settings;
    final subjectsAsync = ref.watch(sessionSubjectsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 320,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.outline, width: 2),
            boxShadow: const [
              BoxShadow(
                color: AppColors.outline,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
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
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color: HSVColor.fromAHSV(
                      (settings.overlayOpacity ?? 0.5).clamp(0.0, 1.0).toDouble(),
                      ((settings.overlayHue ?? 210) % 360).toDouble(),
                      0.45,
                      0.24,
                    ).toColor(),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: _GlassButton(
                  icon: Icons.fullscreen,
                  label: l10n.sessionFullscreen,
                  onTap: _openFullscreen,
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!timerState.isTimerActive)
                        _ModeSelector(
                          selectedMode: _selectedMode,
                          onModeChanged: (mode) => setState(() => _selectedMode = mode),
                        )
                      else
                        _ActiveStateBadge(timerProvider: timerState),
                      const SizedBox(height: 14),
                      FittedBox(
                        child: Text(
                          timerState.isTimerActive ? timerState.timerDisplay : '00:00',
                          style: AppTypography.textTheme.displayLarge?.copyWith(
                            fontSize: 72,
                            color: Colors.white,
                            fontWeight: FontWeight.w300,
                            fontFamily: AppTypography.monoFont,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        timerState.isTimerActive
                            ? l10n.sessionFocusedMinutes(timerState.totalSeconds ~/ 60)
                            : (_selectedMode == StudySessionMode.pomodoro
                                ? l10n.sessionFocusBreakLine(settings.focusMinutes, settings.breakMinutes)
                                : l10n.sessionContinuousFocusMode),
                        style: AppTypography.textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      _TimerControls(
                        timerProvider: timerState,
                        onStart: _startTimer,
                        onStopAndSave: _stopAndSaveSession,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          l10n.sessionAtmosphere,
          style: AppTypography.textTheme.headlineSmall?.copyWith(fontSize: 18),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _AtmospherePill(
              label: l10n.sessionAtmosphereCityTwilight,
              isActive: _backgroundImage == _cityBg,
              color: Colors.blue.shade900,
              onTap: () => setState(() => _backgroundImage = _cityBg),
            ),
            _AtmospherePill(
              label: l10n.sessionAtmosphereCozyCafe,
              isActive: _backgroundImage == _cozyBg,
              color: Colors.orange.shade300,
              onTap: () => setState(() => _backgroundImage = _cozyBg),
            ),
            _AtmospherePill(
              label: l10n.sessionAtmosphereCustom,
              isActive: _isCustomBackground,
              isIcon: true,
              icon: Icons.image,
              onTap: _pickCustomBackground,
            ),
            _AtmospherePill(
              label: l10n.sessionAtmosphereOverlay,
              isActive: false,
              isIcon: true,
              icon: Icons.color_lens,
              onTap: _pickOverlayHue,
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => setState(() => _showDetails = !_showDetails),
          icon: Icon(_showDetails ? Icons.expand_less : Icons.expand_more),
          label: Text(_showDetails ? l10n.sessionHideDetails : l10n.sessionShowDetails),
        ),
        if (_showDetails)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outline, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                subjectsAsync.when(
                  loading: () => const LinearProgressIndicator(minHeight: 2),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (subjects) {
                    return DropdownButtonFormField<int?>(
                      initialValue: _subjectId,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: l10n.subjectOptional),
                      items: [
                        DropdownMenuItem<int?>(value: null, child: Text(l10n.generalStudy)),
                        ...subjects.map(
                          (s) => DropdownMenuItem<int?>(value: s.id, child: Text(s.name)),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _subjectId = value;
                          String? selectedName;
                          for (final subject in subjects) {
                            if (subject.id == value) {
                              selectedName = subject.name;
                              break;
                            }
                          }
                          _subjectName = selectedName;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _topicController,
                  decoration: InputDecoration(labelText: l10n.topicLabel),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _mood,
                  decoration: InputDecoration(labelText: l10n.moodLabel),
                  items: [
                    DropdownMenuItem(value: 'focused', child: Text(l10n.moodFocused)),
                    DropdownMenuItem(value: 'productive', child: Text(l10n.moodProductive)),
                    DropdownMenuItem(value: 'calm', child: Text(l10n.moodCalm)),
                    DropdownMenuItem(value: 'tired', child: Text(l10n.moodTired)),
                    DropdownMenuItem(value: 'stressed', child: Text(l10n.moodStressed)),
                    DropdownMenuItem(value: 'distracted', child: Text(l10n.moodDistracted)),
                  ],
                  onChanged: (value) => setState(() => _mood = value),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: l10n.notesLabel),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ModeSelector extends StatelessWidget {
  final StudySessionMode selectedMode;
  final ValueChanged<StudySessionMode> onModeChanged;

  const _ModeSelector({required this.selectedMode, required this.onModeChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
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
            isSelected: selectedMode == StudySessionMode.pomodoro,
            onTap: () => onModeChanged(StudySessionMode.pomodoro),
          ),
          _ModePill(
            label: l10n.sessionModeLongSession,
            icon: Icons.schedule,
            isSelected: selectedMode == StudySessionMode.longSession,
            onTap: () => onModeChanged(StudySessionMode.longSession),
          ),
        ],
      ),
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

class _ActiveStateBadge extends StatelessWidget {
  final TimerProvider timerProvider;

  const _ActiveStateBadge({required this.timerProvider});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    IconData icon = Icons.track_changes;
    String text = l10n.sessionStatusFocusing;

    if (timerProvider.state == TimerState.breakPhase) {
      icon = Icons.coffee;
      text = l10n.sessionStatusBreakTime;
    } else if (timerProvider.state == TimerState.paused) {
      icon = Icons.pause;
      text = l10n.sessionStatusPaused;
    }

    final modeLabel = timerProvider.mode == StudySessionMode.pomodoro
        ? l10n.sessionModePomodoro
        : timerProvider.mode == StudySessionMode.longSession
            ? l10n.sessionModeLongSession
            : l10n.sessionModeManual;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          const SizedBox(width: 6),
          Text(
            '· $modeLabel',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _TimerControls extends StatelessWidget {
  final TimerProvider timerProvider;
  final VoidCallback onStart;
  final Future<void> Function() onStopAndSave;

  const _TimerControls({
    required this.timerProvider,
    required this.onStart,
    required this.onStopAndSave,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (!timerProvider.isTimerActive) {
      return _SolidButton(
        icon: Icons.play_arrow,
        label: l10n.sessionStart,
        color: AppColors.primary,
        onTap: onStart,
      );
    }

    if (timerProvider.state == TimerState.breakPhase) {
      return Wrap(
        spacing: 8,
        children: [
          _SolidButton(
            label: l10n.sessionSkipBreak,
            color: AppColors.surface,
            textColor: AppColors.onSurface,
            onTap: () => timerProvider.skipBreak(),
          ),
          _SolidButton(
            icon: Icons.stop,
            label: l10n.sessionStopAndSave,
            color: AppColors.error,
            onTap: onStopAndSave,
          ),
        ],
      );
    }

    if (timerProvider.state == TimerState.paused) {
      return Wrap(
        spacing: 8,
        children: [
          _SolidButton(
            icon: Icons.play_arrow,
            label: l10n.sessionResume,
            color: AppColors.primary,
            onTap: () => timerProvider.resume(),
          ),
          _SolidButton(
            icon: Icons.stop,
            label: l10n.sessionStopAndSave,
            color: AppColors.error,
            onTap: onStopAndSave,
          ),
        ],
      );
    }

    return Wrap(
      spacing: 8,
      children: [
        _SolidButton(
          icon: Icons.pause,
          label: l10n.sessionPause,
          color: AppColors.primary,
          onTap: () => timerProvider.pause(),
        ),
        _SolidButton(
          icon: Icons.stop,
          label: l10n.sessionStopAndSave,
          color: AppColors.error,
          onTap: onStopAndSave,
        ),
      ],
    );
  }
}

class _SolidButton extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _SolidButton({
    this.icon,
    required this.label,
    required this.color,
    this.textColor = Colors.white,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: color == AppColors.surface ? Border.all(color: AppColors.outline) : null,
          boxShadow: color == AppColors.surface
              ? null
              : const [
                  BoxShadow(
                    color: Colors.black26,
                    offset: Offset(0, 2),
                  )
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: textColor),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _GlassButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white70),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _AtmospherePill extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color? color;
  final bool isIcon;
  final IconData? icon;
  final VoidCallback onTap;

  const _AtmospherePill({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.color,
    this.isIcon = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.surfaceContainer : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.outline,
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.outline,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isIcon)
              Icon(icon, size: 16, color: AppColors.onSurface)
            else
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.outline),
                ),
              ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
