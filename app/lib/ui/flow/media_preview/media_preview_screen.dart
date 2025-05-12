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
import 'media_preview_view_model.dart';
import 'package:data/models/media/media.dart';
import 'package:data/models/media/media_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:style/extensions/context_extensions.dart';
import 'package:style/indicators/circular_progress_indicator.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

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

  // Media Kit player instance
  Player? _player;
  VideoController? _videoController;

  @override
  void initState() {
    super.initState();
    // Initialize MediaKit
    MediaKit.ensureInitialized();

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
        _initializeVideo(
          path: widget.medias[currentIndex].path,
          isNetworkUrl: widget.medias[currentIndex].isFirebaseStored,
        );
      });
    }
  }

  Future<void> _initializeVideo({
    required String path,
    bool isNetworkUrl = false,
  }) async {
    try {
      // Dispose any existing player first to avoid conflicts
      await _disposeCurrentPlayer();

      // Create a new player instance
      _player = Player();

      // Set media source based on whether it's a network URL or local file
      if (isNetworkUrl) {
        debugPrint('Initializing network video player: $path');
        await _player!.open(Media(path));
      } else {
        // For local files
        await _player!.open(Media(File(path).path));
      }

      // Create the video controller for UI
      _videoController = VideoController(_player!);

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error initializing media_kit player: $e');
    }
  }

  Future<void> _disposeCurrentPlayer() async {
    if (_player != null) {
      await _player!.pause();
      await _player!.dispose();
      _player = null;
    }
    _videoController = null;
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

  void _updateVideoOnMediaChange() {
    ref.listen(
      _provider.select(
        (value) => value.medias.elementAtOrNull(value.currentIndex),
      ),
      (previous, next) {
        if (next != null && next.type.isVideo) {
          // Handle both local and Firebase videos
          if (next.sources.contains(AppMediaSource.local) ||
              next.isFirebaseStored) {
            _initializeVideo(
              path: next.path,
              isNetworkUrl: next.isFirebaseStored,
            );
          }
        } else {
          // Not a video, dispose the player
          _disposeCurrentPlayer();
        }
      },
    );
  }

  @override
  void dispose() {
    _disposeCurrentPlayer();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _observeError();
    _observePopOnEmptyMedia();
    _updateVideoOnMediaChange();

    final state = ref.watch(
      _provider.select(
        (state) => (
          medias: state.medias,
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
          if (state.swipeDownPercentage == 0)
            PreviewTopBar(
              provider: _provider,
              onAction: () {
                if (_player != null) {
                  _player?.pause();
                }
              },
            ),
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
        if (_player != null) {
          _player?.pause();
        }
        MediaMetadataDetailsScreen.show(context, media);
      }
    }

    if (media.type.isVideo &&
        (media.sources.contains(AppMediaSource.local) ||
            media.isFirebaseStored)) {
      return DismissiblePage(
        backgroundColor: context.colorScheme.surface,
        enableScale: false,
        onDismiss: context.pop,
        onDragUp: onDragUp,
        onDragDown: _notifier.updateSwipeDownPercentage,
        child: Stack(
          children: [
            Center(
              child: _videoController != null
                  ? SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: Column(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Video(
                                controller: _videoController!,
                                fill: Colors.transparent,
                                fit: BoxFit.contain,
                                width: double.infinity,
                                aspectRatio: media.displayHeight == null ||
                                        media.displayWidth == null
                                    ? null
                                    : media.displayWidth! / media.displayHeight!,
                              ),
                            ),
                          ),
                          SizedBox(height: 16), // Add padding to the bottom
                        ],
                      ),
                    )
                  : Image(
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
                            message: context.l10n.unable_to_load_media_message,
                          ),
                        );
                      },
                    ),
            ),
            if (_videoController == null)
              Center(
                child: AppCircularProgressIndicator(
                  color: context.colorScheme.onPrimary,
                ),
              ),
          ],
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

      return Stack(
        children: [
          Center(
            child: _videoController != null
                ? Video(
                    controller: _videoController!,
                    fill: Colors.transparent,
                    fit: BoxFit.contain,
                  )
                : Image(
                    image: AppMediaImageProvider(
                      media: media,
                      thumbnailSize: Size(800, 600),
                    ),
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.contain,
                  ),
          ),
          if (_videoController == null)
            const Center(
              child: AppCircularProgressIndicator(),
            ),
        ],
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
}
