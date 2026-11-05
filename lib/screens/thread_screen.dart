import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../layout.dart';
import '../models.dart';
import '../state.dart';
import '../util.dart';
import '../widgets/avatar.dart';

/// Vlákno konverzácie. Funguje v troch podobách:
///  • celá obrazovka (compact) s tlačidlom späť,
///  • pravý panel vo viacpanelovom rozložení,
///  • Flex režim: vlákno v hornej polovici, písanie a rýchle odpovede dole.
class ThreadView extends StatefulWidget {
  const ThreadView({
    super.key,
    required this.conversation,
    this.showBack = false,
    this.flex,
  });

  final Conversation conversation;
  final bool showBack;
  final FlexSplit? flex;

  @override
  State<ThreadView> createState() => _ThreadViewState();
}

class _ThreadViewState extends State<ThreadView> {
  late final AppState _state;
  late final TextEditingController _controller;
  final _scroll = ScrollController();
  bool _sending = false;

  String get _email => widget.conversation.contactEmail;

  @override
  void initState() {
    super.initState();
    _state = context.read<AppState>();
    // Koncept sa drží v AppState, takže prežije preskladanie telefónu.
    _controller = TextEditingController(text: _state.draftFor(_email));
    _controller.addListener(() => _state.setDraft(_email, _controller.text));
    WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom());
  }

  @override
  void didUpdateWidget(covariant ThreadView old) {
    super.didUpdateWidget(old);
    if (old.conversation.messages.length !=
            widget.conversation.messages.length ||
        (old.flex == null) != (widget.flex == null)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom());
    }
  }

  void _toBottom() {
    if (_scroll.hasClients) {
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _state.reply(widget.conversation, text);
      _controller.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Odoslanie zlyhalo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _insertQuick(String text) {
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _messageList() {
    final msgs = widget.conversation.messages;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(builder: (context, c) {
      final maxBubble = (c.maxWidth * 0.74).clamp(240.0, 640.0).toDouble();
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            itemCount: msgs.length,
            itemBuilder: (context, i) {
              final m = msgs[i];
              final prev = i > 0 ? msgs[i - 1] : null;
              final newDay = prev == null || !_sameDay(prev.date, m.date);
              final newSubject =
                  prev == null || prev.subject.trim() != m.subject.trim();
              return Column(
                children: [
                  if (newDay)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        DateFormat('EEEE d. MMMM yyyy', 'sk').format(m.date),
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  if (newSubject && m.subject.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 6),
                      child: Text(
                        m.subject.trim(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey),
                      ),
                    ),
                  _Bubble(message: m, dark: dark, maxWidth: maxBubble),
                ],
              );
            },
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final conv = widget.conversation;
    final header = _Header(
      conv: conv,
      showBack: widget.showBack,
      onBack: () => _state.select(null),
    );
    final composer =
        _Composer(controller: _controller, sending: _sending, onSend: _send);

    final flex = widget.flex;
    if (flex == null) {
      return Column(
        children: [
          header,
          Expanded(child: _messageList()),
          composer,
        ],
      );
    }

    // Flex režim: horná polovica = vlákno, dolná = rýchle odpovede a písanie.
    final screenH = MediaQuery.of(context).size.height;
    final top =
        flex.top.clamp(160.0, math.max(160.0, screenH - 200)).toDouble();
    return Column(
      children: [
        SizedBox(
          height: top,
          child: Column(
            children: [header, Expanded(child: _messageList())],
          ),
        ),
        SizedBox(height: flex.gap),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: _FlexBottom(current: conv, onQuick: _insertQuick),
              ),
              composer,
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.conv,
    required this.showBack,
    required this.onBack,
  });

  final Conversation conv;
  final bool showBack;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? const Color(0xE61C1C1E) : const Color(0xE6F9F9F9),
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Row(
            children: [
              if (showBack)
                IconButton(
                  tooltip: 'Späť',
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: onBack,
                )
              else
                const SizedBox(width: 8),
              Avatar(name: conv.contactName, size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(conv.contactName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    Text(conv.contactEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.dark,
    required this.maxWidth,
  });

  final MailMessage message;
  final bool dark;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final out = message.outgoing;
    final bg = out
        ? const Color(0xFF007AFF)
        : (dark ? const Color(0xFF2C2C2E) : const Color(0xFFE9E9EB));
    final fg = out ? Colors.white : (dark ? Colors.white : Colors.black);

    final plain = stripQuoted(message.text);
    final useHtml = message.text.trim().isEmpty &&
        (message.html != null && message.html!.trim().isNotEmpty);

    return Align(
      alignment: out ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(out ? 18 : 5),
            bottomRight: Radius.circular(out ? 5 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (useHtml)
              // Základné jadro nenačítava vzdialené obrázky -> bezpečnejšie.
              HtmlWidget(message.html!,
                  textStyle: TextStyle(color: fg, fontSize: 15.5))
            else
              Align(
                alignment: Alignment.centerLeft,
                child: SelectableText(
                  plain.isEmpty ? '(bez textu)' : plain,
                  style: TextStyle(color: fg, fontSize: 15.5, height: 1.3),
                ),
              ),
            if (message.attachments.isNotEmpty) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final name in message.attachments)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: fg.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.attach_file, size: 14, color: fg),
                            const SizedBox(width: 2),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 200),
                              child: Text(name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: fg)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 3),
            Text(
              DateFormat.Hm().format(message.date),
              style: TextStyle(
                  fontSize: 11, color: fg.withOpacity(out ? 0.75 : 0.5)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide(color: Theme.of(context).dividerColor, width: 1),
    );
    return Material(
      color: dark ? const Color(0xFF1C1C1E) : const Color(0xFFF9F9F9),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            border:
                Border(top: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 6,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Odpovedať',
                        filled: true,
                        fillColor: dark ? Colors.black : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        border: border,
                        enabledBorder: border,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 38,
                    height: 38,
                    child: sending
                        ? const Padding(
                            padding: EdgeInsets.all(9),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton.filled(
                            padding: EdgeInsets.zero,
                            tooltip: 'Odoslať',
                            onPressed: onSend,
                            icon: const Icon(Icons.arrow_upward_rounded,
                                size: 22),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dolná polovica vo Flex režime: rýchle odpovede a prepínač konverzácií.
class _FlexBottom extends StatelessWidget {
  const _FlexBottom({required this.current, required this.onQuick});

  final Conversation current;
  final ValueChanged<String> onQuick;

  static const _quick = [
    'Ďakujem!',
    'OK 👍',
    'Ozvem sa neskôr.',
    'Môžeme si zavolať?',
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final others = state.conversations
        .where((c) => c.contactEmail != current.contactEmail)
        .take(12)
        .toList();

    return LayoutBuilder(builder: (context, c) {
      if (c.maxHeight < 110) return const SizedBox.shrink();
      return ClipRect(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Text('Rýchle odpovede',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey)),
            ),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _quick.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ActionChip(
                  label: Text(_quick[i]),
                  onPressed: () => onQuick(_quick[i]),
                ),
              ),
            ),
            if (c.maxHeight >= 220 && others.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Text('Ďalšie konverzácie',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey)),
              ),
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: others.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (_, i) {
                    final o = others[i];
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => state.select(o.contactEmail),
                      child: SizedBox(
                        width: 64,
                        child: Column(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Avatar(name: o.contactName, size: 46),
                                if (o.unread > 0)
                                  Positioned(
                                    right: -2,
                                    top: -2,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(o.contactName.split(' ').first,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}
