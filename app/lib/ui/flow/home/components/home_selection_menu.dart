import 'dart:io';
import 'package:data/models/media/media_extension.dart';
import '../../../../components/app_dialog.dart';
import '../../../../components/selection_menu.dart';
import '../../../../domain/extensions/context_extensions.dart';
// Firebase-only implementation no longer needs the assets
import '../home_screen_view_model.dart';
import 'package:data/models/media/media.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Firebase-only implementation no longer needs SVG
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:style/extensions/context_extensions.dart';

class HomeSelectionMenu extends ConsumerWidget {
  const HomeSelectionMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      homeViewStateNotifier.select(
        (state) => (
          selectedMedias: state.selectedMedias,
          googleAccount: state.googleAccount,
          dropboxAccount: state.dropboxAccount
        ),
      ),
    );

    return SelectionMenu(
      useSystemPadding: false,
      items: [
        _clearSelectionAction(context, ref),
        // Firebase actions
        if (state.selectedMedias.values.any(
          (element) =>
              !element.sources.contains(AppMediaSource.firebase) &&
              element.sources.contains(AppMediaSource.local),
        ))
          _uploadToFirebaseAction(context, ref),
        if (state.selectedMedias.values.any(
          (element) => element.sources.contains(AppMediaSource.firebase),
        ))
          _downloadFromFirebaseAction(context, ref),
        if (state.selectedMedias.values.any(
          (element) => element.sources.contains(AppMediaSource.firebase),
        ))
          _deleteMediaFromFirebaseAction(context, ref),
        // Google Drive actions - commented out as we're focusing on Firebase
        /*
        if (state.selectedMedias.values.any(
          (element) =>
              !element.sources.contains(AppMediaSource.googleDrive) &&
              element.sources.contains(AppMediaSource.local) &&
              state.googleAccount != null,
        ))
          _uploadToGoogleDriveAction(context, ref),
        if (state.selectedMedias.values
                .any((element) => element.isGoogleDriveStored) &&
            state.googleAccount != null)
          _downloadFromGoogleDriveAction(context, ref),
        if (state.selectedMedias.values.any(
              (element) => element.sources.contains(AppMediaSource.googleDrive),
            ) &&
            state.googleAccount != null)
          _deleteMediaFromGoogleDriveAction(context, ref),
        */
        // Dropbox actions - commented out as we're focusing on Firebase
        /*
        if (state.selectedMedias.values.any(
          (element) =>
              !element.sources.contains(AppMediaSource.dropbox) &&
              element.sources.contains(AppMediaSource.local) &&
              state.dropboxAccount != null,
        ))
          _uploadToDropboxAction(context, ref),
        if (state.selectedMedias.values
                .any((element) => element.isDropboxStored) &&
            state.dropboxAccount != null)
          _downloadFromDropboxAction(context, ref),
        if (state.selectedMedias.values.any(
              (element) => element.sources.contains(AppMediaSource.dropbox),
            ) &&
            state.dropboxAccount != null)
          _deleteMediaFromDropboxAction(context, ref),
        */
        if (state.selectedMedias.values.any(
          (element) => element.sources.contains(AppMediaSource.local),
        ))
          _deleteFromDevice(context, ref),
        if (state.selectedMedias.values.any((element) => element.isLocalStored))
          _shareAction(context, state.selectedMedias, ref),
      ],
      show: state.selectedMedias.isNotEmpty,
    );
  }

  Widget _clearSelectionAction(BuildContext context, WidgetRef ref) {
    return SelectionMenuAction(
      title: context.l10n.common_cancel,
      icon: Icon(
        Icons.close,
        color: context.colorScheme.textPrimary,
        size: 22,
      ),
      onTap: ref.read(homeViewStateNotifier.notifier).clearSelection,
    );
  }

  // Note: Google Drive upload action has been removed
  // since we're focusing on Firebase as the primary cloud storage provider.

  // Note: Dropbox actions have been removed
  // since we're focusing on Firebase as the primary cloud storage provider.

  // Firebase actions
  Widget _uploadToFirebaseAction(BuildContext context, WidgetRef ref) {
    return SelectionMenuAction(
      icon: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 0, right: 8),
            child: Icon(
              CupertinoIcons.cloud_upload,
              color: context.colorScheme.textPrimary,
              size: 22,
            ),
          ),
          // Using a simple icon for Firebase
          Icon(
            Icons.whatshot,
            color: Colors.orange,
            size: 14,
          ),
        ],
      ),
      title: 'Upload to Firebase',
      onTap: () {
        showAppAlertDialog(
          context: context,
          title: 'Upload to Firebase',
          message:
              'Are you sure you want to upload the selected media to Firebase?',
          actions: [
            AppAlertAction(
              title: context.l10n.common_cancel,
              onPressed: () {
                context.pop();
              },
            ),
            AppAlertAction(
              title: context.l10n.common_upload,
              onPressed: () {
                context.pop();
                ref.read(homeViewStateNotifier.notifier).uploadToFirebase();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _downloadFromFirebaseAction(BuildContext context, WidgetRef ref) {
    return SelectionMenuAction(
      icon: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Icon(
            CupertinoIcons.cloud_download,
            color: context.colorScheme.textPrimary,
            size: 22,
          ),
          // Icon(
          //   Icons.download,
          //   color: context.colorScheme.textPrimary,
          //   size: 14,
          // ),
        ],
      ),
      title: 'Download',
      onTap: () async {
        showAppAlertDialog(
          context: context,
          title: 'Download',
          message: 'Are you sure you want to download the selected media?',
          actions: [
            AppAlertAction(
              title: context.l10n.common_cancel,
              onPressed: () {
                context.pop();
              },
            ),
            AppAlertAction(
              title: context.l10n.common_download,
              onPressed: () {
                context.pop();
                ref.read(homeViewStateNotifier.notifier).downloadFromFirebase();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _deleteMediaFromFirebaseAction(BuildContext context, WidgetRef ref) {
    return SelectionMenuAction(
      icon: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Icon(
            CupertinoIcons.trash,
            color: context.colorScheme.alert,
            size: 22,
          ),
          // Icon(
          //   Icons.download,
          //   color: context.colorScheme.textPrimary,
          //   size: 14,
          // ),
        ],
      ),
      title: 'Delete',
      onTap: () {
        showAppAlertDialog(
          context: context,
          title: 'Delete',
          message: 'Are you sure you want to delete the selected media?',
          actions: [
            AppAlertAction(
              title: context.l10n.common_cancel,
              onPressed: () {
                context.pop();
              },
            ),
            AppAlertAction(
              isDestructiveAction: true,
              title: context.l10n.common_delete,
              onPressed: () {
                context.pop();
                ref.read(homeViewStateNotifier.notifier).deleteFirebaseMedias();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _deleteFromDevice(BuildContext context, WidgetRef ref) {
    return SelectionMenuAction(
      icon: Icon(
        CupertinoIcons.delete,
        size: 22,
        color: context.colorScheme.alert,
      ),
      title: context.l10n.delete_from_device_title,
      onTap: () {
        showAppAlertDialog(
          context: context,
          title: context.l10n.delete_from_device_title,
          message: context.l10n.delete_from_device_confirmation_message,
          actions: [
            AppAlertAction(
              title: context.l10n.common_cancel,
              onPressed: () {
                context.pop();
              },
            ),
            AppAlertAction(
              isDestructiveAction: true,
              title: context.l10n.common_delete,
              onPressed: () {
                context.pop();
                ref.read(homeViewStateNotifier.notifier).deleteLocalMedias();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _shareAction(
    BuildContext context,
    Map<String, AppMedia> selectedMedias,
    WidgetRef ref,
  ) {
    return SelectionMenuAction(
      icon: Icon(
        Platform.isIOS ? CupertinoIcons.share : Icons.share_rounded,
        color: context.colorScheme.textPrimary,
        size: 22,
      ),
      title: context.l10n.common_share,
      onTap: () {
        Share.shareXFiles(
          selectedMedias.values
              .where((element) => element.isLocalStored)
              .map((e) => XFile(e.path))
              .toList(),
        );
        ref.read(homeViewStateNotifier.notifier).clearSelection();
      },
    );
  }
}
