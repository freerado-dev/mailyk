import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../oauth_config.dart';
import '../state.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key, this.firstRun = false});

  final bool firstRun;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: Text(firstRun ? 'Vitaj' : 'Účty'),
        automaticallyImplyLeading: !firstRun,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (firstRun)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Pridaj emailový účet. Správy od jedného človeka sa zobrazia ako jedna konverzácia.',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              for (final a in state.accounts)
                Card(
                  elevation: 0,
                  child: ListTile(
                    leading: Icon(a.oauth
                        ? Icons.verified_user_outlined
                        : Icons.mail_outline),
                    title: Text(a.email),
                    subtitle: Text(
                        '${a.imapHost}${a.oauth ? ' · OAuth2' : ''}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => state.removeAccount(a),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Pridať účet'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddAccountScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddAccountScreen extends StatefulWidget {
  const AddAccountScreen({super.key});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  MailProvider _provider = MailProvider.gmail;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _user = TextEditingController();
  final _password = TextEditingController();
  final _imapHost = TextEditingController();
  final _imapPort = TextEditingController(text: '993');
  final _smtpHost = TextEditingController();
  final _smtpPort = TextEditingController(text: '465');
  bool _busy = false;
  String? _error;

  bool get _oauthAvailable => OAuthConfig.isConfigured(_provider);

  String get _providerLabel =>
      _provider == MailProvider.gmail ? 'Google' : 'Microsoft';

  String get _hint {
    switch (_provider) {
      case MailProvider.gmail:
        return _oauthAvailable
            ? 'Odporúčané je prihlásenie cez Google. Alternatívne môžeš použiť heslo aplikácie.'
            : 'Prihlásenie cez Google nie je nakonfigurované (pozri OAUTH_SETUP.md). '
                'Zapni dvojstupňové overenie a vytvor „heslo aplikácie“ na '
                'myaccount.google.com/apppasswords.';
      case MailProvider.outlook:
        return _oauthAvailable
            ? 'Prihlás sa cez Microsoft. Heslom cez IMAP už väčšina účtov nefunguje.'
            : 'Outlook.com a Microsoft 365 vyžadujú OAuth2. Nastav ho podľa OAUTH_SETUP.md. '
                'Pracovné účty s povoleným IMAP heslom môžu fungovať aj bez toho.';
      case MailProvider.custom:
        return 'Zadaj údaje o IMAP a SMTP serveri od svojho poskytovateľa.';
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = 'Pripojenie zlyhalo: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInOAuth() => _run(() => context
      .read<AppState>()
      .addOAuthAccount(_provider, email: _email.text.trim()));

  Future<void> _savePassword() => _run(() async {
        final account = Account.preset(
          provider: _provider,
          name: _name.text.trim().isEmpty
              ? _email.text.trim()
              : _name.text.trim(),
          email: _email.text.trim(),
          username: _user.text.trim(),
          imapHost: _imapHost.text.trim(),
          imapPort: int.tryParse(_imapPort.text) ?? 993,
          smtpHost: _smtpHost.text.trim(),
          smtpPort: int.tryParse(_smtpPort.text) ?? 465,
        );
        await context
            .read<AppState>()
            .addPasswordAccount(account, _password.text);
      });

  Widget _field(TextEditingController c, String label,
      {bool obscure = false, TextInputType? type}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        obscureText: obscure,
        keyboardType: type,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _passwordForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(_name, 'Meno'),
        _field(_email, 'Emailová adresa', type: TextInputType.emailAddress),
        if (_provider == MailProvider.custom)
          _field(_user, 'Používateľské meno (ak sa líši od emailu)'),
        _field(
            _password,
            _provider == MailProvider.gmail ? 'Heslo aplikácie' : 'Heslo',
            obscure: true),
        if (_provider == MailProvider.custom) ...[
          _field(_imapHost, 'IMAP server (napr. imap.example.com)'),
          _field(_imapPort, 'IMAP port (993)', type: TextInputType.number),
          _field(_smtpHost, 'SMTP server (napr. smtp.example.com)'),
          _field(_smtpPort, 'SMTP port (465 alebo 587)',
              type: TextInputType.number),
        ],
        FilledButton.tonal(
          onPressed: _busy ? null : _savePassword,
          child: const Text('Pripojiť heslom'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final oauth = _oauthAvailable;
    return Scaffold(
      appBar: AppBar(title: const Text('Nový účet')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<MailProvider>(
                segments: const [
                  ButtonSegment(value: MailProvider.gmail, label: Text('Gmail')),
                  ButtonSegment(
                      value: MailProvider.outlook, label: Text('Outlook')),
                  ButtonSegment(
                      value: MailProvider.custom, label: Text('Iný IMAP')),
                ],
                selected: {_provider},
                onSelectionChanged: (s) => setState(() => _provider = s.first),
              ),
              const SizedBox(height: 12),
              Text(_hint, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              if (oauth) ...[
                FilledButton.icon(
                  icon: const Icon(Icons.login),
                  label: Text('Prihlásiť sa cez $_providerLabel'),
                  onPressed: _busy ? null : _signInOAuth,
                ),
                const SizedBox(height: 8),
                ExpansionTile(
                  title: const Text('Použiť heslo namiesto toho'),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  childrenPadding: const EdgeInsets.only(top: 8),
                  children: [_passwordForm()],
                ),
              ] else
                _passwordForm(),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
