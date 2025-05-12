import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:style/extensions/context_extensions.dart';
import 'package:style/text/app_text_style.dart';
import 'package:style/theme/colors.dart';
import 'package:style/buttons/buttons_list.dart';
import 'package:style/buttons/switch.dart';
import 'package:data/storage/app_preferences.dart';
import '../../../components/app_page.dart';
import '../../../components/snack_bar.dart';
import '../../../domain/extensions/context_extensions.dart';
import '../../../domain/extensions/go_router_extension.dart';
import '../../../domain/services/auth_service.dart';
import '../../../gen/assets.gen.dart';
import '../../navigation/app_route.dart';
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

  /// Firebase account tab displaying the current Firebase user and sign out option
  Widget _firebaseAccount({required BuildContext context}) {
    return Consumer(
      builder: (context, ref, child) {
        // Get user from AuthService
        final authService = ref.watch(authServiceProvider);
        final currentUser = authService.currentUser;

        String name = 'My Account';
        String email = 'Firebase Authentication';
        String? photoUrl;

        if (currentUser != null) {
          name = currentUser.displayName ?? '';
          if (name.isEmpty && currentUser.email != null) {
            name = currentUser.email!.split('@').first;
          }
          email = currentUser.email ?? 'Firebase Authentication';
          photoUrl = currentUser.photoURL;
        }

        return AccountsTab(
          name: name,
          serviceDescription: email,
          profileImage: photoUrl,
          actions: [
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
              onPressed: () => _showSignOutConfirmDialog(context, ref),
            ),
          ],
          backgroundColor: Colors.deepOrange.shade400,
        );
      },
    );
  }

  /// Shows a confirmation dialog for signing out of Firebase
  void _showSignOutConfirmDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.sign_out_title),
        content: const Text("Are you sure you want to sign out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              // Use AuthService directly for sign out
              await ref.read(authServiceProvider).signOut();
              Navigator.of(context).pop();
              if (context.mounted) {
                showSnackBar(
                  context: context,
                  text: "Successfully signed out",
                );

                // Navigate to login screen
                LoginRoute().go(context);
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Sign Out"),
          ),
        ],
      ),
    );
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
            // Firebase Auth Account Section
            _firebaseAccount(context: context),
            const SizedBox(height: 16),

            // Cloud Storage Account Sections
            // if (FeatureFlag.googleDriveSupport)
            //   _googleAccount(context: context),
            // const SizedBox(height: 8),
            // _dropboxAccount(context: context),
            // const SizedBox(height: 16),

            // Settings
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
    return AccountsTab(
      name: 'Test',
      serviceDescription: "${context.l10n.common_dropbox} - test",
      profileImage: 'test',
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
              // final dropboxAutoBackUp =
              //     ref.watch(AppPreferences.dropboxAutoBackUp);
              return AppSwitch(
                value: false,
                onChanged: (value) {},
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
    // return Consumer(
    //   builder: (context, ref, child) {
    //     final dropboxAccount =
    //         ref.watch(AppPreferences.dropboxCurrentUserAccount);
    //     // if (dropboxAccount != null) {
    //     return AccountsTab(
    //       name: dropboxAccount?.name.display_name ?? '',
    //       serviceDescription:
    //           "${context.l10n.common_dropbox} - ${dropboxAccount?.email}",
    //       profileImage: dropboxAccount?.profile_photo_url ?? '',
    //       actions: [
    //         ActionListItem(
    //           leading: Icon(
    //             CupertinoIcons.arrow_2_circlepath,
    //             color: context.colorScheme.textPrimary,
    //             size: 22,
    //           ),
    //           title: context.l10n.auto_back_up_title,
    //           trailing: Consumer(
    //             builder: (context, ref, child) {
    //               final dropboxAutoBackUp =
    //                   ref.watch(AppPreferences.dropboxAutoBackUp);
    //               return AppSwitch(
    //                 value: dropboxAutoBackUp,
    //                 onChanged: notifier.toggleAutoBackupInDropbox,
    //               );
    //             },
    //           ),
    //         ),
    //         ActionListItem(
    //           leading: SvgPicture.asset(
    //             Assets.images.icLogout,
    //             height: 22,
    //             width: 22,
    //             colorFilter: ColorFilter.mode(
    //               context.colorScheme.textPrimary,
    //               BlendMode.srcATop,
    //             ),
    //           ),
    //           title: context.l10n.sign_out_title,
    //           onPressed: () async {
    //             await notifier.signOutWithDropbox();
    //             if (context.mounted) {
    //               showSnackBar(
    //                 context: context,
    //                 text: context.l10n.successfully_sign_out_from_dropbox,
    //                 icon: SvgPicture.asset(
    //                   Assets.images.icDropbox,
    //                   height: 22,
    //                   width: 22,
    //                 ),
    //               );
    //             }
    //           },
    //         ),
    //       ],
    //       backgroundColor: AppColors.dropBoxColor,
    //     );
    //     // }
    //     // return ActionList(
    //     //   buttons: [
    //     //     ActionListItem(
    //     //       leading: SvgPicture.asset(
    //     //         Assets.images.icDropbox,
    //     //         height: 22,
    //     //         width: 22,
    //     //       ),
    //     //       trailing: Padding(
    //     //         padding: const EdgeInsets.all(8),
    //     //         child: Icon(
    //     //           CupertinoIcons.forward,
    //     //           color: context.colorScheme.containerHigh,
    //     //           size: 18,
    //     //         ),
    //     //       ),
    //     //       subtitle: context.l10n.sign_in_with_dropbox_message,
    //     //       title: context.l10n.sign_in_with_dropbox_title,
    //     //       onPressed: () {
    //     //         notifier.signInWithDropbox();
    //     //       },
    //     //     ),
    //     //   ],
    //     // );
    //   },
    // );
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
