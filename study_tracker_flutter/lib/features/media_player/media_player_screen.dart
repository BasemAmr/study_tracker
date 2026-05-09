import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/media_player_provider.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/app_card.dart';

class MediaPlayerScreen extends ConsumerWidget {
  const MediaPlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = ref.read(mediaPlayerProvider);
    final isScanning = ref.watch(mediaPlayerProvider.select((p) => p.isScanning));
    final libraryFolderPath = ref.watch(mediaPlayerProvider.select((p) => p.libraryFolderPath));
    final tracks = ref.watch(mediaPlayerProvider.select((p) => p.tracks));
    final currentIndex = ref.watch(mediaPlayerProvider.select((p) => p.currentIndex));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compactHeight = constraints.maxHeight < 560;
              return ListView(
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Focus Audio',
                        style: AppTypography.textTheme.headlineLarge,
                      ),
                      FilledButton.icon(
                        onPressed: isScanning ? null : () => media.pickAndLoadFolder(),
                        icon: isScanning
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.file_open),
                        label: const Text('Add Audio Files'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    libraryFolderPath == null
                        ? 'No files loaded yet'
                        : 'Folder: $libraryFolderPath',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const AppCard(
                    padding: EdgeInsets.all(16),
                    child: _NowPlayingControls(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: compactHeight ? 180 : 280,
                    child: AppCard(
                      padding: const EdgeInsets.all(12),
                      child: tracks.isEmpty
                          ? Center(
                              child: Text(
                                'No local audio found. Add files to start.',
                                style: AppTypography.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: tracks.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final item = tracks[index];
                                final isCurrent = currentIndex == index;
                                return InkWell(
                                  onTap: () => media.playAt(index),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isCurrent ? AppColors.primaryContainer : AppColors.surface,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppColors.outline, width: 2),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isCurrent ? Icons.graphic_eq : Icons.music_note,
                                          color: isCurrent
                                              ? AppColors.onPrimaryContainer
                                              : AppColors.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            item.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: isCurrent
                                                  ? AppColors.onPrimaryContainer
                                                  : AppColors.onSurface,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NowPlayingControls extends ConsumerWidget {
  const _NowPlayingControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = ref.read(mediaPlayerProvider);
    final total = ref.watch(mediaPlayerProvider.select((p) => p.duration));
    final position = ref.watch(mediaPlayerProvider.select((p) => p.position));
    final isPlaying = ref.watch(mediaPlayerProvider.select((p) => p.isPlaying));
    final currentTrack = ref.watch(mediaPlayerProvider.select((p) => p.currentTrack));

    final current = position > total ? total : position;
    final progress = total.inMilliseconds <= 0
        ? 0.0
        : current.inMilliseconds / total.inMilliseconds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          currentTrack?.title ?? 'No media playing',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Slider(
          value: progress.clamp(0.0, 1.0),
          onChanged: (value) {
            if (total.inMilliseconds <= 0) return;
            final ms = (total.inMilliseconds * value).round();
            media.seek(Duration(milliseconds: ms));
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_fmt(current), style: AppTypography.textTheme.labelSmall),
            Text(_fmt(total), style: AppTypography.textTheme.labelSmall),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: media.previousTrack,
                  icon: const Icon(Icons.skip_previous),
                ),
              ),
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: media.rewind10s,
                  icon: const Icon(Icons.replay_10),
                ),
              ),
              SizedBox(
                width: 56,
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: media.togglePlayPause,
                  child: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                ),
              ),
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: media.skipForward10s,
                  icon: const Icon(Icons.forward_10),
                ),
              ),
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: media.nextTrack,
                  icon: const Icon(Icons.skip_next),
                ),
              ),
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: media.stopPlayback,
                  icon: const Icon(Icons.stop),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
