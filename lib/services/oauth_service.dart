import 'dart:convert';

import 'package:flutter_appauth/flutter_appauth.dart';

import '../models.dart';
import '../oauth_config.dart';

class OAuthTokens {
  OAuthTokens({required this.access, this.refresh, required this.expiry});

  final String access;
  final String? refresh;
  final DateTime expiry;

  bool get expired =>
      DateTime.now().isAfter(expiry.subtract(const Duration(seconds: 60)));

  Map<String, dynamic> toJson() => {
        'access': access,
        'refresh': refresh,
        'expiry': expiry.toIso8601String(),
      };

  factory OAuthTokens.fromJson(Map<String, dynamic> j) => OAuthTokens(
        access: j['access'] as String,
        refresh: j['refresh'] as String?,
        expiry: DateTime.parse(j['expiry'] as String),
      );
}

class OAuthSignIn {
  OAuthSignIn(this.tokens, this.email, this.name);

  final OAuthTokens tokens;
  final String? email;
  final String? name;
}

class OAuthService {
  final FlutterAppAuth _appAuth = const FlutterAppAuth();

  AuthorizationServiceConfiguration _config(OAuthClient c) =>
      AuthorizationServiceConfiguration(
        authorizationEndpoint: c.authEndpoint,
        tokenEndpoint: c.tokenEndpoint,
      );

  Future<OAuthSignIn> signIn(MailProvider provider) async {
    final c = OAuthConfig.clientFor(provider);
    if (c == null) {
      throw StateError(
          'OAuth nie je nakonfigurované (pozri OAUTH_SETUP.md a lib/oauth_config.dart).');
    }
    final AuthorizationTokenResponse? res =
        await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        c.clientId,
        OAuthConfig.redirectUrl,
        serviceConfiguration: _config(c),
        scopes: c.scopes,
        additionalParameters: c.extra,
        promptValues: const ['select_account'],
      ),
    );
    if (res == null || res.accessToken == null) {
      throw StateError('Prihlásenie bolo zrušené alebo zlyhalo.');
    }
    final tokens = OAuthTokens(
      access: res.accessToken!,
      refresh: res.refreshToken,
      expiry: res.accessTokenExpirationDateTime ??
          DateTime.now().add(const Duration(minutes: 50)),
    );
    final claims = _claims(res.idToken);
    final email = (claims['email'] ?? claims['preferred_username']) as String?;
    final name = claims['name'] as String?;
    return OAuthSignIn(tokens, email, name);
  }

  Future<OAuthTokens> refresh(MailProvider provider, OAuthTokens old) async {
    final c = OAuthConfig.clientFor(provider);
    if (c == null || old.refresh == null) {
      throw StateError('Platnosť prihlásenia vypršala, pridaj účet znova.');
    }
    final TokenResponse? res = await _appAuth.token(
      TokenRequest(
        c.clientId,
        OAuthConfig.redirectUrl,
        refreshToken: old.refresh,
        serviceConfiguration: _config(c),
        scopes: c.scopes,
      ),
    );
    if (res == null || res.accessToken == null) {
      throw StateError('Obnovenie prihlásenia zlyhalo, pridaj účet znova.');
    }
    return OAuthTokens(
      access: res.accessToken!,
      refresh: res.refreshToken ?? old.refresh,
      expiry: res.accessTokenExpirationDateTime ??
          DateTime.now().add(const Duration(minutes: 50)),
    );
  }

  Map<String, dynamic> _claims(String? idToken) {
    if (idToken == null) return const {};
    try {
      final parts = idToken.split('.');
      if (parts.length < 2) return const {};
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      return jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return const {};
    }
  }
}
