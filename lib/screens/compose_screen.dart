import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state.dart';

/// Na veľkej ploche otvorí písanie správy v dialógu, na malej na celú obrazovku.
Future<void> openCompose(BuildContext context) {
  final wide = MediaQuery.of(context).size.width >= 700;
  if (wide) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 640),
          child: const ComposeScreen(),
        ),
      ),
    );
  }
  return Navigator.of(context).push(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => const ComposeScreen()),
  );
}

class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key});

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  TextEditingController? _to;
  final _subject = TextEditingController();
  final _body = TextEditingController();
  Account? _account;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final accounts = context.read<AppState>().accounts;
    final filter = context.read<AppState>().accountFilter;
    _account = accounts.firstWhere(
      (a) => a.id == filter,
      orElse: () => accounts.first,
    );
  }

  Future<void> _send() async {
    final to = (_to?.text ?? '').trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(to)) {
      setState(() => _error = 'Zadaj platnú emailovú adresu.');
      return;
    }
    if (_body.text.trim().isEmpty) {
      setState(() => _error = 'Správa je prázdna.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await context.read<AppState>().sendNew(
            account: _account!,
            to: to,
            subject: _subject.text.trim(),
            body: _body.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Odoslanie zlyhalo: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nová správa'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _sending
                ? const Center(
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)))
                : FilledButton(onPressed: _send, child: const Text('Odoslať')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (state.accounts.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<Account>(
                value: _account,
                decoration: const InputDecoration(
                    labelText: 'Z účtu', border: OutlineInputBorder()),
                items: [
                  for (final a in state.accounts)
                    DropdownMenuItem(value: a, child: Text(a.email)),
                ],
                onChanged: (a) => setState(() => _account = a),
              ),
            ),
          Autocomplete<String>(
            optionsBuilder: (v) {
              final q = v.text.trim().toLowerCase();
              if (q.isEmpty) return const Iterable<String>.empty();
              return state.knownContacts.where((e) => e.contains(q)).take(6);
            },
            fieldViewBuilder: (context, controller, focus, onSubmit) {
              _to = controller;
              return TextField(
                controller: controller,
                focusNode: focus,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                    labelText: 'Komu', border: OutlineInputBorder()),
              );
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _subject,
            decoration: const InputDecoration(
                labelText: 'Predmet', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            minLines: 8,
            maxLines: 20,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
                labelText: 'Správa',
                alignLabelWithHint: true,
                border: OutlineInputBorder()),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
    );
  }
}
