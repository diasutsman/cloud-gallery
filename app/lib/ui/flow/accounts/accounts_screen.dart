import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:style/extensions/context_extensions.dart';
import 'package:style/text/app_text_style.dart';
import 'package:style/theme/colors.dart';
import 'package:style/buttons/buttons_list.dart';
import 'package:style/buttons/switch.dart';
import 'package:data/storage/app_preferences.dart';
import '../../../components/app_page.dart';
import '../../../components/snack_bar.dart';
import '../../../domain/extensions/context_extensions.dart';
import '../../../domain/utils/app_switcher.dart';
import '../../../gen/assets.gen.dart';
import 'accounts_screen_view_model.dart';
import 'components/account_tab.dart';
import 'components/profile_section.dart';
import 'components/settings_action_list.dart';

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen>
    with WidgetsBindingObserver {
  late AccountsStateNotifier notifier;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Builds widget for app disguise options
  Widget _buildAppDisguiseOption(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final appDisguiseType = ref.watch(
          accountsStateNotifierProvider
              .select((value) => value.appDisguiseType),
        );

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: _getDisguiseIcon(appDisguiseType),
            title: const Text('App Disguise'),
            subtitle: Text('Currently: ${_getDisguiseName(appDisguiseType)}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showDisguiseOptionsDialog(context),
          ),
        );
      },
    );
  }

  /// Returns the appropriate icon for the current disguise type
  Widget _getDisguiseIcon(AppDisguiseType disguiseType) {
    switch (disguiseType) {
      case AppDisguiseType.none:
        return const Icon(Icons.visibility_off);
      case AppDisguiseType.calculator:
        return const Icon(Icons.calculate);
      case AppDisguiseType.calendar:
        return const Icon(Icons.calendar_today);
      case AppDisguiseType.notes:
        return const Icon(Icons.note);
      case AppDisguiseType.weather:
        return const Icon(Icons.wb_sunny);
      case AppDisguiseType.clock:
        return const Icon(Icons.access_time);
    }
  }

  /// Returns a user-friendly name for the disguise type
  String _getDisguiseName(AppDisguiseType disguiseType) {
    switch (disguiseType) {
      case AppDisguiseType.none:
        return 'Default';
      case AppDisguiseType.calculator:
        return 'Calculator';
      case AppDisguiseType.calendar:
        return 'Calendar';
      case AppDisguiseType.notes:
        return 'Notes';
      case AppDisguiseType.weather:
        return 'Weather';
      case AppDisguiseType.clock:
        return 'Clock';
    }
  }

  /// Shows a dialog for the user to choose app disguise options
  void _showDisguiseOptionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Choose App Disguise'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                _buildDisguiseOption(context, AppDisguiseType.none),
                _buildDisguiseOption(context, AppDisguiseType.calculator),
                _buildDisguiseOption(context, AppDisguiseType.calendar),
                _buildDisguiseOption(context, AppDisguiseType.notes),
                _buildDisguiseOption(context, AppDisguiseType.weather),
                _buildDisguiseOption(context, AppDisguiseType.clock),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  /// Builds a single disguise option for the dialog
  Widget _buildDisguiseOption(
      BuildContext context, AppDisguiseType disguiseType) {
    final currentDisguiseType = ref.watch(
      accountsStateNotifierProvider.select((value) => value.appDisguiseType),
    );

    return ListTile(
      leading: _getDisguiseIcon(disguiseType),
      title: Text(_getDisguiseName(disguiseType)),
      trailing: currentDisguiseType == disguiseType
          ? const Icon(Icons.check, color: Colors.green)
          : null,
      onTap: () {
        ref
            .read(accountsStateNotifierProvider.notifier)
            .setAppDisguiseType(disguiseType);
        Navigator.of(context).pop();
      },
    );
  }

  void _errorObserver() {
    ref.listen(accountsStateNotifierProvider.select((value) => value.error),
        (previous, next) {
      if (next != null) {
        showErrorSnackBar(context: context, error: next);
      }
    });
  }

  void _clearCacheSucceedObserver() {
    ref.listen(
        accountsStateNotifierProvider.select(
          (value) =>
              (clearCacheLoading: value.clearCacheLoading, error: value.error),
        ), (previous, next) {
      if (previous!.clearCacheLoading &&
          !next.clearCacheLoading &&
          next.error == null) {
        showSnackBar(
          context: context,
          text: "Cache cleared successfully",
        );
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      notifier.updateNotificationsPermissionStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    _errorObserver();
    _clearCacheSucceedObserver();
    return AppPage(
      title: "Accounts",
      bodyBuilder: (context) {
        return ListView(
          padding: context.systemPadding +
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // Firebase Email/Password Auth Profile Section
            const ProfileSection(),
            const SizedBox(height: 16),

            // Cloud Storage Account Sections
            // if (FeatureFlag.googleDriveSupport)
            //   _googleAccount(context: context),
            // const SizedBox(height: 8),
            // _dropboxAccount(context: context),
            // const SizedBox(height: 8),
            _buildAppDisguiseOption(context),
            const SizedBox(height: 16),
            const SettingsActionList(),
            const SizedBox(height: 16),
            _buildVersion(context: context),
          ],
        );
      },
    );
  }

  Widget _googleAccount({required BuildContext context}) {
    return Consumer(
      builder: (context, ref, child) {
        final googleAccount = ref.watch(
          accountsStateNotifierProvider.select((value) => value.googleAccount),
        );

        if (googleAccount != null) {
          return AccountsTab(
            name: googleAccount.displayName ?? googleAccount.email,
            serviceDescription:
                "${context.l10n.common_google_drive} - ${googleAccount.email}",
            profileImage: googleAccount.photoUrl,
            actions: [
              ActionListItem(
                leading: Icon(
                  CupertinoIcons.arrow_2_circlepath,
                  color: context.colorScheme.textPrimary,
                  size: 22,
                ),
                title: context.l10n.auto_back_up_title,
                trailing: Consumer(
                  builder: (context, ref, child) {
                    final googleDriveAutoBackUp =
                        ref.watch(AppPreferences.googleDriveAutoBackUp);
                    return AppSwitch(
                      value: googleDriveAutoBackUp,
                      onChanged: notifier.toggleAutoBackupInGoogleDrive,
                    );
                  },
                ),
              ),
              ActionListItem(
                leading: SvgPicture.asset(
                  Assets.images.icLogout,
                  height: 22,
                  width: 22,
                  colorFilter: ColorFilter.mode(
                    context.colorScheme.textPrimary,
                    BlendMode.srcATop,
                  ),
                ),
                title: context.l10n.sign_out_title,
                onPressed: () async {
                  await notifier.signOutWithGoogle();
                  if (context.mounted) {
                    showSnackBar(
                      context: context,
                      text:
                          context.l10n.successfully_sign_out_from_google_drive,
                      icon: SvgPicture.asset(
                        Assets.images.icGoogleDrive,
                        height: 22,
                        width: 22,
                      ),
                    );
                  }
                },
              ),
            ],
            backgroundColor: AppColors.googleDriveColor,
          );
        }
        return ActionList(
          buttons: [
            ActionListItem(
              leading: SvgPicture.asset(
                Assets.images.icGoogleDrive,
                height: 22,
                width: 22,
              ),
              subtitle: context.l10n.sign_in_with_google_drive_message,
              trailing: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  CupertinoIcons.forward,
                  color: context.colorScheme.containerHigh,
                  size: 18,
                ),
              ),
              title: context.l10n.sign_in_with_google_drive_title,
              onPressed: () {
                notifier.signInWithGoogle();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _dropboxAccount({required BuildContext context}) {
    return Consumer(
      builder: (context, ref, child) {
        final dropboxAccount =
            ref.watch(AppPreferences.dropboxCurrentUserAccount);
        if (dropboxAccount != null) {
          return AccountsTab(
            name: dropboxAccount.name.display_name,
            serviceDescription:
                "${context.l10n.common_dropbox} - ${dropboxAccount.email}",
            profileImage: dropboxAccount.profile_photo_url,
            actions: [
              ActionListItem(
                leading: Icon(
                  CupertinoIcons.arrow_2_circlepath,
                  color: context.colorScheme.textPrimary,
                  size: 22,
                ),
                title: context.l10n.auto_back_up_title,
                trailing: Consumer(
                  builder: (context, ref, child) {
                    final dropboxAutoBackUp =
                        ref.watch(AppPreferences.dropboxAutoBackUp);
                    return AppSwitch(
                      value: dropboxAutoBackUp,
                      onChanged: notifier.toggleAutoBackupInDropbox,
                    );
                  },
                ),
              ),
              ActionListItem(
                leading: SvgPicture.asset(
                  Assets.images.icLogout,
                  height: 22,
                  width: 22,
                  colorFilter: ColorFilter.mode(
                    context.colorScheme.textPrimary,
                    BlendMode.srcATop,
                  ),
                ),
                title: context.l10n.sign_out_title,
                onPressed: () async {
                  await notifier.signOutWithDropbox();
                  if (context.mounted) {
                    showSnackBar(
                      context: context,
                      text: context.l10n.successfully_sign_out_from_dropbox,
                      icon: SvgPicture.asset(
                        Assets.images.icDropbox,
                        height: 22,
                        width: 22,
                      ),
                    );
                  }
                },
              ),
            ],
            backgroundColor: AppColors.dropBoxColor,
          );
        }
        return ActionList(
          buttons: [
            ActionListItem(
              leading: SvgPicture.asset(
                Assets.images.icDropbox,
                height: 22,
                width: 22,
              ),
              trailing: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  CupertinoIcons.forward,
                  color: context.colorScheme.containerHigh,
                  size: 18,
                ),
              ),
              subtitle: context.l10n.sign_in_with_dropbox_message,
              title: context.l10n.sign_in_with_dropbox_title,
              onPressed: () {
                notifier.signInWithDropbox();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildVersion({required BuildContext context}) {
    final version = ref.watch(
      accountsStateNotifierProvider.select((value) => value.version ?? ''),
    );
    return Center(
      child: Text(
        "Version: $version",
        style: AppTextStyles.body2.copyWith(
          color: context.colorScheme.textSecondary,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
