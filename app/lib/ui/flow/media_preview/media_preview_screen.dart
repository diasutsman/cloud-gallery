import 'dart:async';
import 'dart:io';
import 'package:data/log/logger.dart';
import 'package:data/storage/app_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:style/animations/dismissible_page.dart';
import 'package:style/theme/theme.dart';
import '../../../components/app_page.dart';
import '../../../components/place_holder_screen.dart';
import '../../../components/snack_bar.dart';
import '../../../domain/extensions/context_extensions.dart';
import '../../../domain/extensions/widget_extensions.dart';
import '../../../domain/image_providers/app_media_image_provider.dart';
import '../../../gen/assets.gen.dart';
import '../media_metadata_details/media_metadata_details.dart';
import 'components/download_require_view.dart';
import 'components/local_media_image_preview.dart';
import 'components/network_image_preview/network_image_preview.dart';
import 'components/top_bar.dart';
import 'components/video_player_components/video_actions.dart';
import 'media_preview_view_model.dart';
import 'package:data/models/media/media.dart';
import 'package:data/models/media/media_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:style/extensions/context_extensions.dart';
import 'package:style/indicators/circular_progress_indicator.dart';
import 'package:video_player/video_player.dart';
import 'components/video_player_components/video_duration_slider.dart';

class MediaPreview extends ConsumerStatefulWidget {
  final List<AppMedia> medias;
  final String heroTag;
  final Future<List<AppMedia>> Function() onLoadMore;
  final String startFrom;

  const MediaPreview({
    super.key,
    required this.medias,
    required this.heroTag,
    required this.onLoadMore,
    required this.startFrom,
  });

  @override
  ConsumerState<MediaPreview> createState() => _MediaPreviewState();
}

class _MediaPreviewState extends ConsumerState<MediaPreview> {
  late AutoDisposeStateNotifierProvider<MediaPreviewStateNotifier,
      MediaPreviewState> _provider;
  late PageController _pageController;
  late MediaPreviewStateNotifier _notifier;

  VideoPlayerController? _videoPlayerController;

  @override
  void initState() {
    super.initState();
    final currentIndex =
        widget.medias.indexWhere((element) => element.id == widget.startFrom);

    _provider = mediaPreviewStateNotifierProvider(
      (startIndex: currentIndex, medias: widget.medias),
    );
    _notifier = ref.read(_provider.notifier);

    _pageController = PageController(initialPage: currentIndex, keepPage: true);

    if (widget.medias[currentIndex].type.isVideo &&
        (widget.medias[currentIndex].sources.contains(AppMediaSource.local) ||
            widget.medias[currentIndex].isFirebaseStored)) {
      runPostFrame(() {
        _initializeVideoControllerWithListener(
          path: widget.medias[currentIndex].path,
        );
        _notifier.updateInitializedVideoPath(widget.medias[currentIndex].path);
      });
    }
  }

  Future<void> _initializeVideoControllerWithListener({
    required String path,
    bool isNetworkUrl = false,
  }) async {
    try {
      // Dispose any existing controller first to avoid conflicts
      if (_videoPlayerController != null) {
        await _videoPlayerController!.pause();
        _videoPlayerController!.removeListener(_observeVideoController);
        await _videoPlayerController!.dispose();
        _videoPlayerController = null;
      }

      // Create the appropriate controller
      if (isNetworkUrl) {
        debugPrint('Initializing network video player: $path');
        // For network URLs (Firebase storage URLs)
        _videoPlayerController = VideoPlayerController.networkUrl(
          Uri.parse(path),
          // Add explicit video format options for better compatibility
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: false,
            allowBackgroundPlayback: false,
          ),
        );
      } else {
        // For local files
        _videoPlayerController = VideoPlayerController.file(File(path));
      }

      // Setup listener before initialization
      _videoPlayerController!.addListener(_observeVideoController);

      // Initialize the controller
      _notifier.updateVideoBuffering(true);
      await _videoPlayerController!.initialize();

      // Update state after initialization
      _notifier.updateVideoInitialized(
        _videoPlayerController!.value.isInitialized,
      );
      _notifier.updateVideoBuffering(false);

      // Start playback
      if (_videoPlayerController!.value.isInitialized) {
        await _videoPlayerController!.play();
      }
    } catch (e) {
      debugPrint('Error initializing video player: $e');
      _notifier.updateVideoInitialized(false);
      _notifier.updateVideoBuffering(false);
    }
  }

  void _observeVideoController() {
    _notifier.updateVideoInitialized(
      _videoPlayerController?.value.isInitialized ?? false,
    );
    _notifier.updateVideoBuffering(
      _videoPlayerController?.value.isBuffering ?? false,
    );
    _notifier.updateVideoPosition(
      position: _videoPlayerController?.value.position ?? Duration.zero,
    );
    _notifier.updateVideoMaxDuration(
      _videoPlayerController?.value.duration ?? Duration.zero,
    );
    _notifier
        .updateVideoPlaying(_videoPlayerController?.value.isPlaying ?? false);
  }

  void _observeError() {
    ref.listen(
      _provider.select((value) => value.error),
      (previous, next) {
        if (next != null) {
          showErrorSnackBar(context: context, error: next);
        }
      },
    );
  }

  void _observePopOnEmptyMedia() {
    ref.listen(
      _provider.select((value) => value.medias),
      (previous, next) {
        if (next.isEmpty && context.mounted) {
          context.pop();
        }
      },
    );
  }

  void _updateVideoControllerOnMediaChange() {
    ref.listen(
        _provider.select(
          (value) => value.medias.elementAtOrNull(value.currentIndex),
        ), (previous, next) {
      if (_videoPlayerController != null) {
        _videoPlayerController?.removeListener(_observeVideoController);
        _notifier.updateVideoInitialized(false);
        _notifier.updateInitializedVideoPath(null);
        _videoPlayerController?.dispose();
        _videoPlayerController = null;
      }
      if (next != null && next.type.isVideo) {
        // Handle both local and Firebase videos
        if (next.sources.contains(AppMediaSource.local)) {
          // For local videos
          _initializeVideoControllerWithListener(path: next.path);
          _notifier.updateInitializedVideoPath(next.path);
        } else if (next.isFirebaseStored) {
          // For Firebase videos
          _initializeVideoControllerWithListener(
            path: next.path,
            isNetworkUrl: true,
          );
          _notifier.updateInitializedVideoPath(next.path);
        }
      }
    });
  }

  @override
  void dispose() {
    _videoPlayerController?.removeListener(_observeVideoController);
    _videoPlayerController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _observeError();
    _observePopOnEmptyMedia();
    _updateVideoControllerOnMediaChange();

    final state = ref.watch(
      _provider.select(
        (state) => (
          medias: state.medias,
          showActions: state.showActions,
          isImageZoomed: state.isImageZoomed,
          swipeDownPercentage: state.swipeDownPercentage,
        ),
      ),
    );
    return AppPage(
      backgroundColor: appColorSchemeDark.surface.withValues(
        alpha: 1 - state.swipeDownPercentage,
      ),
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _notifier.toggleActionVisibility,
            child: state.medias.isEmpty
                ? PlaceHolderScreen(
                    icon: SvgPicture.asset(
                      Assets.images.ilNoMediaFound,
                      width: 100,
                    ),
                    title: context.l10n.empty_media_title,
                    message: context.l10n.empty_media_message,
                  )
                : PageView.builder(
                    physics: state.isImageZoomed
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    onPageChanged: (value) => _notifier.changeVisibleMediaIndex(
                      value,
                      widget.onLoadMore,
                    ),
                    controller: _pageController,
                    itemCount: state.medias.length,
                    itemBuilder: (context, index) => _preview(
                      context: context,
                      media: state.medias[index],
                      isZoomed: state.isImageZoomed,
                    ),
                  ),
          ),
          if (state.swipeDownPercentage == 0) ...[
            PreviewTopBar(
              provider: _provider,
              onAction: () {
                if (_videoPlayerController != null &&
                    (_videoPlayerController?.value.isInitialized ?? false)) {
                  _videoPlayerController?.pause();
                }
              },
            ),
            _videoActions(context),
            // _videoDurationSlider(context),
          ],
        ],
      ),
    );
  }

  Widget _preview({
    required BuildContext context,
    required AppMedia media,
    required bool isZoomed,
  }) {
    void onDragUp(displacement) async {
      if (displacement > 100) {
        if (_videoPlayerController != null &&
            (_videoPlayerController?.value.isInitialized ?? false)) {
          _videoPlayerController?.pause();
        }
        MediaMetadataDetailsScreen.show(context, media);
      }
    }

    if (media.type.isVideo && media.sources.contains(AppMediaSource.local)) {
      return DismissiblePage(
        backgroundColor: context.colorScheme.surface,
        enableScale: false,
        onDismiss: context.pop,
        onDragUp: onDragUp,
        onDragDown: _notifier.updateSwipeDownPercentage,
        child: Center(
          child: Consumer(
            builder: (context, ref, child) {
              final state = ref.watch(
                _provider.select(
                  (state) => (
                    initialized: state.isVideoInitialized,
                    buffring: state.isVideoBuffering,
                    initializedVideoPath: state.initializedVideoPath,
                  ),
                ),
              );

              return Hero(
                tag: "${widget.heroTag}${media.toString()}",
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (state.initialized &&
                        media.path == state.initializedVideoPath)
                      AspectRatio(
                        aspectRatio: _videoPlayerController!.value.aspectRatio,
                        child: VideoPlayer(_videoPlayerController!),
                      ),
                    if (!state.initialized ||
                        media.path != state.initializedVideoPath)
                      Image(
                        image: AppMediaImageProvider(media: media),
                        width: double.infinity,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          Logger().e(
                            'Error loading image: $error, st: $stackTrace',
                          );
                          return AppPage(
                            body: PlaceHolderScreen(
                              title: context.l10n.unable_to_load_media_error,
                              message:
                                  context.l10n.unable_to_load_media_message,
                            ),
                          );
                        },
                        frameBuilder:
                            (context, child, frame, wasSynchronouslyLoaded) {
                          if (wasSynchronouslyLoaded) {
                            return child;
                          } else {
                            final width = context.mediaQuerySize.width;
                            double multiplier = 1;
                            if (media.displayWidth != null &&
                                media.displayWidth! > 0) {
                              multiplier = width / media.displayWidth!;
                            }
                            return SizedBox(
                              width: width,
                              height: media.displayHeight != null &&
                                      media.displayHeight! > 0
                                  ? media.displayHeight! * multiplier
                                  : width,
                              child: child,
                            );
                          }
                        },
                      ),
                    if (state.buffring ||
                        !state.initialized &&
                            media.path == state.initializedVideoPath)
                      AppCircularProgressIndicator(
                        color: context.colorScheme.onPrimary,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    } else if (media.type.isVideo &&
        (media.isGoogleDriveStored ||
            media.isDropboxStored ||
            media.isFirebaseStored)) {
      return DismissiblePage(
        enableScale: false,
        backgroundColor: context.colorScheme.surface,
        onDismiss: context.pop,
        onDragUp: onDragUp,
        onDragDown: _notifier.updateSwipeDownPercentage,
        child: _cloudVideoView(context: context, media: media),
      );
    } else if (media.type.isImage &&
        media.sources.contains(AppMediaSource.local)) {
      return DismissiblePage(
        backgroundColor: context.colorScheme.surface,
        onScaleChange: (scale) {
          _notifier.updateIsImageZoomed(scale > 1);
        },
        onDismiss: context.pop,
        onDragUp: onDragUp,
        onDragDown: _notifier.updateSwipeDownPercentage,
        child: LocalMediaImagePreview(media: media, heroTag: widget.heroTag),
      );
    } else if (media.type.isImage &&
        (media.isGoogleDriveStored ||
            media.isDropboxStored ||
            media.isFirebaseStored)) {
      return DismissiblePage(
        backgroundColor: context.colorScheme.surface,
        onScaleChange: (scale) {
          _notifier.updateIsImageZoomed(scale > 1);
        },
        onDismiss: context.pop,
        onDragUp: onDragUp,
        onDragDown: _notifier.updateSwipeDownPercentage,
        child: NetworkImagePreview(media: media, heroTag: widget.heroTag),
      );
    } else {
      return PlaceHolderScreen(
        title: context.l10n.unable_to_load_media_error,
        message: context.l10n.unable_to_load_media_message,
      );
    }
  }

  Widget _cloudVideoView({
    required BuildContext context,
    required AppMedia media,
  }) {
    // If it's a Firebase video, play it directly
    if (media.isFirebaseStored && media.type.isVideo) {
      ref
          .read(loggerProvider)
          .d('Playing Firebase video directly: ${media.path}');

      return Consumer(
        builder: (context, ref, child) {
          final state = ref.watch(
            _provider.select(
              (state) => (
                initialized: state.isVideoInitialized,
                buffering: state.isVideoBuffering,
                initializedVideoPath: state.initializedVideoPath,
              ),
            ),
          );

          // Initialize the video player if needed
          if (_videoPlayerController == null ||
              media.path != state.initializedVideoPath) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_videoPlayerController != null) {
                _videoPlayerController!.removeListener(_observeVideoController);
                _videoPlayerController!.dispose();
                _videoPlayerController = null;
              }
              _initializeVideoControllerWithListener(
                path: media.path,
                isNetworkUrl: true,
              );
              _notifier.updateInitializedVideoPath(media.path);
            });
          }

          return Stack(
            children: [
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (state.initialized &&
                        media.path == state.initializedVideoPath &&
                        _videoPlayerController != null)
                      AspectRatio(
                        aspectRatio: _videoPlayerController!.value.aspectRatio,
                        child: VideoPlayer(_videoPlayerController!),
                      ),
                    // Show thumbnail while loading
                    if (!state.initialized ||
                        media.path != state.initializedVideoPath)
                      Hero(
                        tag: "${widget.heroTag}${media.toString()}",
                        child: Image(
                          image: AppMediaImageProvider(
                            media: media,
                            thumbnailSize: Size(800, 600),
                          ),
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.contain,
                        ),
                      ),
                    // Show loading indicator if buffering
                    if (state.buffering ||
                        (!state.initialized &&
                            media.path == state.initializedVideoPath))
                      const AppCircularProgressIndicator(),
                  ],
                ),
              ),
              _videoActions(context),
              Positioned(
                left: 0,
                right: 0,
                bottom: 30,
                child: _videoDurationSlider(context),
              ),
            ],
          );
        },
      );
    }
    // For Google Drive and Dropbox videos, or any other media type, show download view
    else {
      return Consumer(
        builder: (context, ref, child) {
          final process = ref.watch(
            _provider.select(
              (value) => media.driveMediaRefId != null &&
                      media.isGoogleDriveStored
                  ? value.downloadMediaProcesses[media.driveMediaRefId]
                  : media.dropboxMediaRefId != null
                      ? value.downloadMediaProcesses[media.dropboxMediaRefId]
                      : value.downloadMediaProcesses[media.id],
            ),
          );
          return DownloadRequireView(
            heroTag: widget.heroTag,
            dropboxAccessToken:
                ref.read(AppPreferences.dropboxToken)?.access_token,
            media: media,
            downloadProcess: process,
            onDownload: () {
              ref.read(loggerProvider).d('Downloading media: ${media.name}');
              ref
                  .read(loggerProvider)
                  .d('Downloading media: ${media.isFirebaseStored}');
              if (media.isGoogleDriveStored) {
                _notifier.downloadFromGoogleDrive(media: media);
              } else if (media.isDropboxStored) {
                _notifier.downloadFromDropbox(media: media);
              } else if (media.isFirebaseStored) {
                _notifier.downloadFromFirebase(media: media);
              }
            },
          );
        },
      );
    }
  }

  Widget _videoActions(BuildContext context) => Consumer(
        builder: (context, ref, child) {
          final state = ref.watch(
            _provider.select(
              (state) => (
                showActions: state.showActions &&
                    state.medias
                            .elementAtOrNull(state.currentIndex)
                            ?.type
                            .isVideo ==
                        true &&
                    state.isVideoInitialized,
                isPlaying: state.isVideoPlaying,
                isInitialized: state.isVideoInitialized,
                position: state.videoPosition,
              ),
            ),
          );

          return VideoActions(
            showActions: state.showActions,
            isPlaying: state.isPlaying || !state.isInitialized,
            onBackward: () {
              _videoPlayerController
                  ?.seekTo(state.position - const Duration(seconds: 10));
            },
            onForward: () {
              _videoPlayerController
                  ?.seekTo(state.position + const Duration(seconds: 10));
            },
            onPlayPause: () {
              if (state.isPlaying) {
                _videoPlayerController?.pause();
              } else {
                _videoPlayerController?.play();
              }
            },
          );
        },
      );

  Widget _videoDurationSlider(BuildContext context) => Consumer(
        builder: (context, ref, child) {
          final ({
            bool showDurationSlider,
            Duration duration,
            Duration position
          }) state = ref.watch(
            _provider.select(
              (state) => (
                showDurationSlider: state.showActions &&
                    state.medias
                            .elementAtOrNull(state.currentIndex)
                            ?.type
                            .isVideo ==
                        true,
                duration: state.videoMaxDuration,
                position: state.videoPosition
              ),
            ),
          );
          return VideoDurationSlider(
            showSlider: state.showDurationSlider,
            duration: state.duration,
            position: state.position,
            onChangeEnd: (duration) {
              _notifier.pointerOnSlider(false);
              _videoPlayerController?.seekTo(duration);
            },
            onChangeStart: (duration) {
              _notifier.pointerOnSlider(true);
            },
            onChanged: (duration) {
              _notifier.updateVideoPosition(position: duration, isManual: true);
            },
          );
        },
      );
}
