import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/responsive.dart';
import '../../core/providers/timer_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/session_provider.dart';
import '../../data/repositories/session_repository.dart';
import '../../domain/domain.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/session_timer_widget.dart';
import 'widgets/session_debrief_card.dart';
import 'widgets/stopwatch_widget.dart';

enum SessionTab { timer, stopwatch, history }

class SessionsScreen extends ConsumerStatefulWidget {
  final StudySessionMode? launchMode;
  final bool autoStart;
  final SessionTab? initialTab;

  const SessionsScreen({
    super.key,
    this.launchMode,
    this.autoStart = false,
    this.initialTab,
  });

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  late SessionTab _activeTab;
  bool _launchIntentApplied = false;
  int? _subjectId;
  StudySessionMode? _mode;
  DateTime? _fromDate;
  DateTime? _toDate;
  final TextEditingController _queryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab ?? SessionTab.timer;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_launchIntentApplied) return;
    _launchIntentApplied = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.launchMode == null && !widget.autoStart) return;

      setState(() {
        _activeTab = SessionTab.timer;
      });

      if (widget.autoStart && widget.launchMode != null) {
        final l10n = AppLocalizations.of(context)!;
        final timer = ref.read(timerProvider);
        if (!timer.isTimerActive) {
          final settings = ref.read(settingsProvider).settings;
          timer.start(
            widget.launchMode!,
            focusMinutes: settings.focusMinutes,
            breakMinutes: settings.breakMinutes,
          );
          debugPrint('[QuickStart] Started ${widget.launchMode!.dbValue} from dashboard intent');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.sessionQuickStartStarted(_modeText(l10n, widget.launchMode!))),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  SessionFilter _buildFilter({required int limit}) {
    return SessionFilter(
      subjectId: _subjectId,
      mode: _mode,
      startFrom: _fromDate,
      startTo: _toDate,
      query: _queryController.text.trim().isEmpty ? null : _queryController.text.trim(),
      limit: limit,
    );
  }

  Future<void> _openManualLogDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _ManualSessionDialog(),
    );

    if (created == true && mounted) {
      ref.invalidate(allSessionsProvider);
      ref.invalidate(sessionSummaryProvider);
      ref.invalidate(recentSessionsProvider);
      ref.invalidate(filteredSessionsProvider);
      setState(() {});
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final current = isStart ? _fromDate : _toDate;
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: current ?? DateTime.now(),
    );

    if (picked == null) return;

    setState(() {
      if (isStart) {
        _fromDate = DateTime(picked.year, picked.month, picked.day, 0, 0, 0);
      } else {
        _toDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _subjectId = null;
      _mode = null;
      _fromDate = null;
      _toDate = null;
      _queryController.clear();
    });
  }

  bool get _hasHistoryFilters {
    return _subjectId != null ||
        _mode != null ||
        _fromDate != null ||
        _toDate != null ||
        _queryController.text.trim().isNotEmpty;
  }

  String _modeText(AppLocalizations l10n, StudySessionMode mode) {
    switch (mode) {
      case StudySessionMode.pomodoro:
        return l10n.sessionModePomodoro;
      case StudySessionMode.longSession:
        return l10n.sessionModeLongSession;
      case StudySessionMode.manual:
        return l10n.sessionModeManual;
    }
  }

  Future<void> _openHistoryFiltersDialog() async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.historyFiltersTitle),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: _SessionFiltersBar(
                queryController: _queryController,
                selectedSubjectId: _subjectId,
                selectedMode: _mode,
                fromDate: _fromDate,
                toDate: _toDate,
                onSubjectChanged: (value) => setState(() => _subjectId = value),
                onModeChanged: (value) => setState(() => _mode = value),
                onPickStartDate: () => _pickDate(isStart: true),
                onPickEndDate: () => _pickDate(isStart: false),
                onApply: () {
                  setState(() {});
                  Navigator.of(context).pop();
                },
                onClear: _clearFilters,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.close),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen for profile changes to reset filters
    ref.listen<int>(
      settingsProvider.select((s) => s.currentProfileId),
      (prev, next) {
        if (prev != next && prev != null) {
          _clearFilters();
        }
      },
    );

    final l10n = AppLocalizations.of(context)!;
    final isNarrow = MediaQuery.of(context).size.width < 420;
    final isPhoneLandscape = R.isPhoneLandscape(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isPhoneLandscape ? 10.0 : (isNarrow ? 14.0 : 24.0)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isPhoneLandscape) ...[
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.sessionsLabel,
                          style: AppTypography.textTheme.bodyMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.sessionsSubtitle,
                          style: AppTypography.textTheme.headlineLarge,
                        ),
                      ],
                    ),
                    _LogManuallyButton(onTap: _openManualLogDialog, label: l10n.logManually),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              if (_activeTab == SessionTab.history) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _openHistoryFiltersDialog,
                    icon: Icon(_hasHistoryFilters ? Icons.filter_alt : Icons.filter_alt_outlined),
                    label: Text(_hasHistoryFilters ? l10n.filtersActive : l10n.filters),
                  ),
                ),
                SizedBox(height: isPhoneLandscape ? 8 : 12),
              ],

              if (isPhoneLandscape)
                _buildCompactTopBar()
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _buildTabs(),
                ),
              SizedBox(height: isPhoneLandscape ? 8 : 24),

              // Content Area
              Expanded(
                child: _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.outline,
            width: 2.0,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TabItem(
            title: l10n.timerTab,
            isActive: _activeTab == SessionTab.timer,
            onTap: () => setState(() => _activeTab = SessionTab.timer),
          ),
          _TabItem(
            title: l10n.stopwatchTab,
            isActive: _activeTab == SessionTab.stopwatch,
            onTap: () => setState(() => _activeTab = SessionTab.stopwatch),
          ),
          _TabItem(
            title: l10n.historyTab,
            isActive: _activeTab == SessionTab.history,
            onTap: () => setState(() => _activeTab = SessionTab.history),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactTopBar() {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _buildTabs(),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.outline, width: 2),
          ),
          child: IconButton(
            onPressed: _openManualLogDialog,
            icon: const Icon(Icons.edit_document),
            tooltip: l10n.logManually,
            constraints: const BoxConstraints(minHeight: 36, minWidth: 36),
            padding: const EdgeInsets.all(6),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_activeTab == SessionTab.history) {
      return _SessionHistoryList(filter: _buildFilter(limit: 100));
    }
    if (_activeTab == SessionTab.timer) {
      return Stack(
        alignment: Alignment.bottomCenter,
        children: [
          const SingleChildScrollView(child: SessionTimerWidget()),
          const SessionDebriefCard(),
        ],
      );
    }
    return const SingleChildScrollView(child: StopwatchWidget());
  }
}

class _SessionHistoryList extends ConsumerWidget {
  final SessionFilter filter;

  const _SessionHistoryList({required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final asyncSessions = ref.watch(filteredSessionsProvider(filter));

    return asyncSessions.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) {
        return Center(
          child: Text(
            l10n.sessionsLoadError,
            style: AppTypography.textTheme.bodyMedium,
          ),
        );
      },
      data: (sessions) {
        if (sessions.isEmpty) {
          return Center(
            child: Text(
              l10n.noSessionsLogged,
              style: AppTypography.textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          );
        }

        return ListView.separated(
          itemCount: sessions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = sessions[index];
            final dateLabel = '${item.startAt.year}-${item.startAt.month.toString().padLeft(2, '0')}-${item.startAt.day.toString().padLeft(2, '0')}';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.outline, width: 2),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.subjectName ?? item.mode.label,
                          style: AppTypography.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateLabel,
                          style: AppTypography.textTheme.bodySmall?.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    l10n.minutesShortValue(item.durationMinutes.toString()),
                    style: AppTypography.textTheme.bodyLarge?.copyWith(
                      fontFamily: AppTypography.monoFont,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: AppColors.error,
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(l10n.confirmDeleteTitle),
                          content: Text(l10n.confirmDeleteBody),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: Text(l10n.cancel),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: Text(l10n.delete, style: const TextStyle(color: AppColors.error)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && item.id != null) {
                        await ref.read(sessionRepositoryProvider).delete(item.id!);
                        ref.invalidate(allSessionsProvider);
                        ref.invalidate(filteredSessionsProvider);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TabItem extends StatelessWidget {
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const _TabItem({
    required this.title,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          border: Border.all(
            color: isActive ? AppColors.outline : Colors.transparent,
            width: 2.0,
          ),
        ),
        // Shift active tab down to cover the bottom border of the container
        transform: Matrix4.translationValues(0, isActive ? 2.0 : 0.0, 0),
        child: Text(
          title,
          style: AppTypography.textTheme.headlineSmall?.copyWith(
            fontSize: 16,
            color: isActive ? AppColors.onPrimary : AppColors.onSurface,
          ),
        ),
      ),
    );
  }
}

class _LogManuallyButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const _LogManuallyButton({required this.onTap, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outline, width: 2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.outline,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.edit_document, size: 20),
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
        ),
      ),
    );
  }
}

class _SessionFiltersBar extends ConsumerWidget {
  final TextEditingController queryController;
  final int? selectedSubjectId;
  final StudySessionMode? selectedMode;
  final DateTime? fromDate;
  final DateTime? toDate;
  final ValueChanged<int?> onSubjectChanged;
  final ValueChanged<StudySessionMode?> onModeChanged;
  final VoidCallback onPickStartDate;
  final VoidCallback onPickEndDate;
  final VoidCallback onApply;
  final VoidCallback onClear;

  const _SessionFiltersBar({
    required this.queryController,
    required this.selectedSubjectId,
    required this.selectedMode,
    required this.fromDate,
    required this.toDate,
    required this.onSubjectChanged,
    required this.onModeChanged,
    required this.onPickStartDate,
    required this.onPickEndDate,
    required this.onApply,
    required this.onClear,
  });

  String _dateLabel(DateTime? value) {
    if (value == null) return '';
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final subjectsAsync = ref.watch(sessionSubjectsProvider);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline, width: 2),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 148,
            height: 36,
            child: TextField(
              controller: queryController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.searchHistory,
                prefixIcon: const Icon(Icons.search, size: 16),
                prefixIconConstraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
            ),
          ),
          subjectsAsync.when(
            loading: () => const SizedBox(
              width: 180,
              child: LinearProgressIndicator(minHeight: 2),
            ),
            error: (_, __) => SizedBox(width: 180, child: Text(l10n.subjectsError)),
            data: (subjects) {
              return SizedBox(
                width: 200,
                child: DropdownButtonFormField<int?>(
                  initialValue: selectedSubjectId,
                  decoration: InputDecoration(labelText: l10n.subjectLabel, isDense: true),
                  items: [
                    DropdownMenuItem<int?>(value: null, child: Text(l10n.allSubjects)),
                    ...subjects.map(
                      (s) => DropdownMenuItem<int?>(
                        value: s.id,
                        child: Text(s.name),
                      ),
                    ),
                  ],
                  onChanged: onSubjectChanged,
                ),
              );
            },
          ),
          SizedBox(
            width: 170,
            child: DropdownButtonFormField<StudySessionMode?>(
              initialValue: selectedMode,
              decoration: InputDecoration(labelText: l10n.modeLabel, isDense: true),
              items: [
                DropdownMenuItem<StudySessionMode?>(value: null, child: Text(l10n.allModes)),
                DropdownMenuItem<StudySessionMode?>(
                  value: StudySessionMode.pomodoro,
                  child: Text(l10n.sessionModePomodoro),
                ),
                DropdownMenuItem<StudySessionMode?>(
                  value: StudySessionMode.longSession,
                  child: Text(l10n.sessionModeLongSession),
                ),
                DropdownMenuItem<StudySessionMode?>(
                  value: StudySessionMode.manual,
                  child: Text(l10n.sessionModeManual),
                ),
              ],
              onChanged: onModeChanged,
            ),
          ),
          OutlinedButton.icon(
            onPressed: onPickStartDate,
            icon: const Icon(Icons.event),
            label: Text(l10n.filtersFrom(_dateLabel(fromDate).isEmpty ? l10n.anyLabel : _dateLabel(fromDate))),
          ),
          OutlinedButton.icon(
            onPressed: onPickEndDate,
            icon: const Icon(Icons.event_available),
            label: Text(l10n.filtersTo(_dateLabel(toDate).isEmpty ? l10n.anyLabel : _dateLabel(toDate))),
          ),
          FilledButton(
            onPressed: onApply,
            child: Text(l10n.save),
          ),
          TextButton(
            onPressed: onClear,
            child: Text(l10n.clear),
          ),
        ],
      ),
    );
  }
}

class _ManualSessionDialog extends ConsumerStatefulWidget {
  const _ManualSessionDialog();

  @override
  ConsumerState<_ManualSessionDialog> createState() => _ManualSessionDialogState();
}

class _ManualSessionDialogState extends ConsumerState<_ManualSessionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _topicController = TextEditingController();
  final _notesController = TextEditingController();
  int? _subjectId;
  String? _subjectName;
  String _mood = 'focused';
  
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  int _durationHours = 1;
  int _durationMinutes = 0;
  
  bool _saving = false;

  @override
  void dispose() {
    _topicController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && mounted) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    final totalMinutes = (_durationHours * 60) + _durationMinutes;
    if (totalMinutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Duration must be greater than 0')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final startAt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );
      final endAt = startAt.add(Duration(minutes: totalMinutes));

      final session = StudySession(
        startAt: startAt,
        endAt: endAt,
        durationMinutes: totalMinutes,
        subjectId: _subjectId,
        subjectName: _subjectName,
        topic: _topicController.text.trim().isEmpty ? null : _topicController.text.trim(),
        mood: _mood,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        mode: StudySessionMode.manual,
      );

      await ref.read(sessionRepositoryProvider).create(session);
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final subjectsAsync = ref.watch(sessionSubjectsProvider);
    final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    
    return AlertDialog(
      title: Text(l10n.logSessionManuallyTitle),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Date'),
                          child: Text(dateStr),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: _pickTime,
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Start time'),
                          child: Text(_selectedTime.format(context)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: _durationHours.toString(),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Hours'),
                        onChanged: (v) => _durationHours = int.tryParse(v) ?? 0,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        initialValue: _durationMinutes.toString(),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Minutes'),
                        onChanged: (v) => _durationMinutes = int.tryParse(v) ?? 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
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
                TextFormField(
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
                  onChanged: (value) => setState(() => _mood = value ?? 'focused'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: l10n.notesLabel),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? l10n.saving : l10n.save),
        ),
      ],
    );
  }
}

