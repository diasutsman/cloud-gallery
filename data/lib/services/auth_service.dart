import 'dart:async';
import '../apis/network/client.dart';
import '../apis/network/oauth2.dart';
import '../errors/app_error.dart';
import '../models/dropbox/account/dropbox_account.dart';
import '../models/dropbox/token/dropbox_token.dart';
import '../storage/app_preferences.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as google_drive;
import 'package:url_launcher/url_launcher.dart';
import '../apis/dropbox/dropbox_auth_endpoints.dart';
import '../apis/network/secrets.dart';
import '../apis/network/urls.dart';
import '../storage/provider/preferences_provider.dart';

final googleUserAccountProvider = StateProvider<GoogleSignInAccount?>((ref) {
  final googleSignIn = ref.read(googleSignInProvider);
  googleSignIn.signInSilently(suppressErrors: true);
  final subscription = googleSignIn.onCurrentUserChanged.listen((account) {
    ref.controller.state = account;
  });
  ref.onDispose(() async {
    await subscription.cancel();
  });
  return googleSignIn.currentUser;
});

final googleSignInProvider = Provider(
  (ref) => GoogleSignIn(
    scopes: [google_drive.DriveApi.driveFileScope],
  ),
);

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(
    ref.read(googleSignInProvider),
    ref.read(rawDioProvider),
    ref.read(oauth2Provider),
    ref.read(AppPreferences.dropboxToken.notifier),
    ref.read(AppPreferences.dropboxPKCECodeVerifier.notifier),
    ref.read(AppPreferences.dropboxCurrentUserAccount.notifier),
    ref.read(AppPreferences.googleDriveAutoBackUp.notifier),
    ref.read(AppPreferences.dropboxAutoBackUp.notifier),
    ref.read(AppPreferences.dropboxFileIdAppPropertyTemplateId.notifier),
  ),
);

class AuthService {
  final GoogleSignIn _googleSignIn;
  final Oauth2 _oauth2;
  final Dio _dio;
  final PreferenceNotifier<DropboxToken?> _dropboxTokenController;
  final PreferenceNotifier<DropboxAccount?> _dropboxAccountController;
  final PreferenceNotifier<String?> _dropboxCodeVerifierPrefProvider;
  final PreferenceNotifier<bool> _googleDriveAutoBackUpController;
  final PreferenceNotifier<bool> _dropboxAutoBackUpController;
  final PreferenceNotifier<String?>
      _dropboxFileIdAppPropertyTemplateIdController;

  AuthService(
    this._googleSignIn,
    this._dio,
    this._oauth2,
    this._dropboxTokenController,
    this._dropboxCodeVerifierPrefProvider,
    this._dropboxAccountController,
    this._googleDriveAutoBackUpController,
    this._dropboxAutoBackUpController,
    this._dropboxFileIdAppPropertyTemplateIdController,
  ) {
    signInSilently();
  }

  Future<void> signInSilently() async {
    await _googleSignIn.signInSilently(suppressErrors: true);
  }

  Future<void> signInWithGoogle() async {
    final googleSignInAccount = await _googleSignIn.signIn();
    if (googleSignInAccount != null) {
      await googleSignInAccount.authentication;
    }
  }

  Future<void> signOutWithGoogle() async {
    await _googleSignIn.signOut();
    _googleDriveAutoBackUpController.state = false;
  }

  /// Launches the URL in the browser for OAuth 2 authentication with Dropbox.
  /// Retrieves the code to fetch access token using the Proof of Key Code Exchange (PKCE) flow.
  Future<void> signInWithDropBox() async {
    final codeVerifier = _oauth2.generateCodeVerifier;
    _dropboxCodeVerifierPrefProvider.state = codeVerifier;
    final authorizationUrl = _oauth2.getAuthorizationUrl(
      clientId: AppSecrets.dropBoxAppKey,
      authorizationEndpoint: Uri.parse('${BaseURL.dropboxOAuth2Web}/authorize'),
      additionalParameters: {'token_access_type': 'offline'},
      redirectUri: RedirectURL.auth,
      codeVerifier: codeVerifier,
    );
    await launchUrl(authorizationUrl);
  }

  /// Fetch dropbox access token using the code using the Proof of Key Code Exchange (PKCE) flow.
  Future<void> setDropboxTokenFromCode({required String code}) async {
    if (_dropboxCodeVerifierPrefProvider.state == null) {
      throw const SomethingWentWrongError(
        message: "Dropbox code verifier is missing",
      );
    }
    final res = await _dio.req(
      DropboxTokenEndpoint(
        code: code,
        codeVerifier: _dropboxCodeVerifierPrefProvider.state!,
        clientId: AppSecrets.dropBoxAppKey,
        redirectUrl: RedirectURL.auth,
        clientSecret: AppSecrets.dropBoxAppSecret,
      ),
    );
    if (res.statusCode == 200) {
      _dropboxTokenController.state = DropboxToken(
        access_token: res.data['access_token'],
        token_type: res.data['token_type'],
        refresh_token: res.data['refresh_token'],
        expires_in:
            DateTime.now().add(Duration(seconds: res.data['expires_in'])),
        account_id: res.data['account_id'],
        scope: res.data['scope'],
        uid: res.data['uid'],
      );
      _dropboxCodeVerifierPrefProvider.state = null;
    } else {
      throw const DropboxAuthSessionExpiredError();
    }
  }

  Future<void> signOutWithDropBox() async {
    _dropboxTokenController.state = null;
    _dropboxAccountController.state = null;
    _dropboxAutoBackUpController.state = false;
    _dropboxFileIdAppPropertyTemplateIdController.state = null;
  }

  Future<void> refreshDropboxToken() async {
    if (_dropboxTokenController.state != null) {
      final res = await _dio.req(
        DropboxRefreshTokenEndpoint(
          refreshToken: _dropboxTokenController.state!.refresh_token,
          clientId: AppSecrets.dropBoxAppKey,
          clientSecret: AppSecrets.dropBoxAppSecret,
        ),
      );
      if (res.statusCode == 200) {
        _dropboxTokenController.state = _dropboxTokenController.state!.copyWith(
          access_token: res.data['access_token'],
          expires_in: DateTime.now().add(
            Duration(
              seconds: res.data['expires_in'],
            ),
          ),
          token_type: res.data['token_type'],
        );
        return;
      }
    }
    throw DropboxAuthSessionExpiredError();
  }

  bool get signedInWithGoogle => _googleSignIn.currentUser != null;

  GoogleSignInAccount? get googleAccount => _googleSignIn.currentUser;

  Stream<GoogleSignInAccount?> get onGoogleAccountChange =>
      _googleSignIn.onCurrentUserChanged;

  DropboxAccount? get dropboxAccount => _dropboxAccountController.state;
}
