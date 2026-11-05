import 'models.dart';

/// Konfigurácia OAuth2. Podrobný postup je v OAUTH_SETUP.md.
///
/// Vlož ID klientov (nie sú tajné, ide o „public client“ s PKCE).
class OAuthConfig {
  /// Google: OAuth client ID typu „iOS“, napr. 1234-abc.apps.googleusercontent.com
  static const googleClientId = '';

  /// Microsoft: Application (client) ID z Azure portálu.
  static const microsoftClientId = '';

  static const _googleSuffix = '.apps.googleusercontent.com';

  /// Jedna spoločná schéma presmerovania pre oboch poskytovateľov.
  /// Google vyžaduje „obrátené“ client ID, preto ho použijeme aj pre Microsoft.
  static String get redirectScheme {
    if (googleClientId.endsWith(_googleSuffix)) {
      final prefix =
          googleClientId.substring(0, googleClientId.length - _googleSuffix.length);
      return 'com.googleusercontent.apps.$prefix';
    }
    return 'sk.konverzo.konverzo_mail';
  }

  static String get redirectUrl => '$redirectScheme:/oauth2redirect';

  static bool isConfigured(MailProvider p) {
    switch (p) {
      case MailProvider.gmail:
        return googleClientId.isNotEmpty;
      case MailProvider.outlook:
        return microsoftClientId.isNotEmpty;
      case MailProvider.custom:
        return false;
    }
  }

  static OAuthClient? clientFor(MailProvider p) {
    switch (p) {
      case MailProvider.gmail:
        if (googleClientId.isEmpty) return null;
        return const OAuthClient(
          clientId: googleClientId,
          authEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
          tokenEndpoint: 'https://oauth2.googleapis.com/token',
          scopes: ['openid', 'email', 'profile', 'https://mail.google.com/'],
          extra: {'access_type': 'offline'},
        );
      case MailProvider.outlook:
        if (microsoftClientId.isEmpty) return null;
        return const OAuthClient(
          clientId: microsoftClientId,
          authEndpoint:
              'https://login.microsoftonline.com/common/oauth2/v2.0/authorize',
          tokenEndpoint:
              'https://login.microsoftonline.com/common/oauth2/v2.0/token',
          scopes: [
            'openid',
            'email',
            'profile',
            'offline_access',
            'https://outlook.office.com/IMAP.AccessAsUser.All',
            'https://outlook.office.com/SMTP.Send',
          ],
          extra: {},
        );
      case MailProvider.custom:
        return null;
    }
  }
}

class OAuthClient {
  const OAuthClient({
    required this.clientId,
    required this.authEndpoint,
    required this.tokenEndpoint,
    required this.scopes,
    required this.extra,
  });

  final String clientId;
  final String authEndpoint;
  final String tokenEndpoint;
  final List<String> scopes;
  final Map<String, String> extra;
}
