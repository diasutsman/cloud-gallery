import 'package:data/domain/app_disguise_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:style/animations/fade_in_switcher.dart';
import 'package:style/indicators/circular_progress_indicator.dart';
import '../../../../components/web_view_screen.dart';
import '../../../../domain/extensions/context_extensions.dart';
import 'package:data/storage/app_preferences.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:style/buttons/buttons_list.dart';
import 'package:style/buttons/segmented_button.dart';
import 'package:style/buttons/switch.dart';
import 'package:style/extensions/context_extensions.dart';
import '../../../../domain/utils/app_switcher.dart';
import '../../../../gen/assets.gen.dart';
import '../../../navigation/app_route.dart';
import '../accounts_screen_view_model.dart';

class SettingsActionList extends ConsumerWidget {
  const SettingsActionList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ActionList(
      buttons: [
        // _notificationAction(context),
        _themeAction(context, ref),
        _appDisguiseAction(context, ref),
        // _clearCacheAction(context, ref),
        // _rateUsAction(context, ref),
        // _cleanUpMedia(context),
        // _termAndConditionAction(context, ref),
        // _privacyPolicyAction(context, ref),
      ],
    );
  }

  Widget _cleanUpMedia(BuildContext context) => ActionListItem(
        leading: Icon(
          Icons.cleaning_services,
          color: context.colorScheme.textPrimary,
          size: 22,
        ),
        onPressed: () {
          CleanUpRoute().push(context);
        },
        title: context.l10n.clean_up_screen_title,
        trailing: Icon(
          CupertinoIcons.right_chevron,
          color: context.colorScheme.outline,
          size: 22,
        ),
      );

  Widget _notificationAction(BuildContext context) => ActionListItem(
        leading: SvgPicture.asset(
          width: 22,
          height: 22,
          Assets.images.icNotification,
          colorFilter: ColorFilter.mode(
            context.colorScheme.textPrimary,
            BlendMode.srcATop,
          ),
        ),
        title: context.l10n.notification_title,
        trailing: Consumer(
          builder: (context, ref, child) {
            final notifications = ref.watch(AppPreferences.notifications);
            final notificationsPermissionStatusAllowed = ref.watch(
              accountsStateNotifierProvider.select(
                (value) => value.notificationsPermissionStatus,
              ),
            );

            return AppSwitch(
              value:
                  notificationsPermissionStatusAllowed ? notifications : false,
              onChanged: (value) async {
                if (notificationsPermissionStatusAllowed) {
                  ref.read(AppPreferences.notifications.notifier).state = value;
                } else {
                  ref
                      .read(accountsStateNotifierProvider.notifier)
                      .updateNotificationsPermissionStatus(
                        openSettingsIfPermanentlyDenied: true,
                      );
                }
              },
            );
          },
        ),
      );

  // App disguise action is implemented below

  Widget _themeAction(BuildContext context, WidgetRef ref) {
    return ActionListItem(
      leading: Builder(
        builder: (context) {
          final isDarkMode = ref.watch(AppPreferences.isDarkMode);
          return FadeInSwitcher(
            child: isDarkMode ?? context.systemThemeIsDark
                ? Icon(
                    CupertinoIcons.moon_stars,
                    color: context.colorScheme.textPrimary,
                    size: 22,
                  )
                : Icon(
                    CupertinoIcons.sun_max,
                    color: context.colorScheme.textPrimary,
                    size: 22,
                  ),
          );
        },
      ),
      title: context.l10n.theme_title,
      trailing: Consumer(
        builder: (context, ref, child) {
          final isDarkMode = ref.watch(AppPreferences.isDarkMode);
          return AppSegmentedButton(
            segments: [
              AppButtonSegment(
                value: true,
                label: context.l10n.dark_theme_title,
              ),
              AppButtonSegment(
                value: false,
                label: context.l10n.light_theme_title,
              ),
              AppButtonSegment(
                value: null,
                label: context.l10n.system_theme_title,
              ),
            ],
            selected: isDarkMode,
            onSelectionChanged: (source) {
              ref.read(AppPreferences.isDarkMode.notifier).state = source;
            },
          );
        },
      ),
    );
  }

  Widget _rateUsAction(BuildContext context, WidgetRef ref) => ActionListItem(
        leading: SvgPicture.asset(
          width: 22,
          height: 22,
          Assets.images.icRateUs,
          colorFilter: ColorFilter.mode(
            context.colorScheme.textPrimary,
            BlendMode.srcATop,
          ),
        ),
        title: context.l10n.rate_us_title,
        onPressed: ref.read(accountsStateNotifierProvider.notifier).rateUs,
      );

  Widget _clearCacheAction(BuildContext context, WidgetRef ref) =>
      ActionListItem(
        leading: Icon(
          Icons.clear_all_rounded,
          color: context.colorScheme.textPrimary,
          size: 22,
        ),
        title: context.l10n.clear_cache_title,
        onPressed: ref.read(accountsStateNotifierProvider.notifier).clearCache,
        trailing: Consumer(
          builder: (context, ref, child) {
            final clearCacheLoading = ref.watch(
              accountsStateNotifierProvider.select(
                (value) => value.clearCacheLoading,
              ),
            );
            return clearCacheLoading
                ? Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: AppCircularProgressIndicator(size: 18),
                  )
                : const SizedBox();
          },
        ),
      );

  Widget _termAndConditionAction(
    BuildContext context,
    WidgetRef ref,
  ) =>
      ActionListItem(
        leading: SvgPicture.asset(
          width: 22,
          height: 22,
          Assets.images.icTermOfService,
          colorFilter: ColorFilter.mode(
            context.colorScheme.textPrimary,
            BlendMode.srcATop,
          ),
        ),
        title: context.l10n.term_and_condition_title,
        onPressed: () {
          final colors = _getWebPageColors(context, ref);
          showWebView(
            context,
            "https://cloud-gallery.canopas.com/terms-and-conditions?bgColor=${colors.background}&textColor=${colors.text}",
          );
        },
      );

  Widget _privacyPolicyAction(BuildContext context, WidgetRef ref) =>
      ActionListItem(
        leading: SvgPicture.asset(
          width: 22,
          height: 22,
          Assets.images.icPrivacyPolicy,
          colorFilter: ColorFilter.mode(
            context.colorScheme.textPrimary,
            BlendMode.srcATop,
          ),
        ),
        title: context.l10n.privacy_policy_title,
        onPressed: () {
          final colors = _getWebPageColors(context, ref);
          showWebView(
            context,
            "https://cloud-gallery.canopas.com/privacy-policy?bgColor=${colors.background}&textColor=${colors.text}",
          );
        },
      );

  /// App disguise option - allows users to change app icon and name
  Widget _appDisguiseAction(BuildContext context, WidgetRef ref) =>
      ActionListItem(
        leading: Icon(
          Icons.security,
          color: context.colorScheme.textPrimary,
          size: 22,
        ),
        title: "App Disguise & Security",
        subtitle: _getDisguiseSubtitle(ref),
        trailing: Icon(
          CupertinoIcons.right_chevron,
          color: context.colorScheme.outline,
          size: 22,
        ),
        onPressed: () => DisguisePinSettingsRoute().push(context),
      );

  /// Gets a user-friendly subtitle for the app disguise option
  String _getDisguiseSubtitle(WidgetRef ref) {
    final appDisguiseType = ref.watch(
      accountsStateNotifierProvider.select((value) => value.appDisguiseType),
    );

    return 'Currently: ${_getDisguiseName(appDisguiseType)}';
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

  // These methods were removed as we now use the dedicated DisguisePinSettings screen

  // Icon method removed as we're using the dedicated DisguisePinSettings screen

  ({String background, String text}) _getWebPageColors(
    BuildContext context,
    WidgetRef ref,
  ) {
    final isDark =
        (ref.watch(AppPreferences.isDarkMode) ?? context.systemThemeIsDark);
    return (
      background: isDark ? "%23000000" : "%23FFFFFF",
      text: isDark ? "%23FFFFFF" : "%23000000"
    );
  }
}
