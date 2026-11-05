import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../layout.dart';
import '../models.dart';
import '../state.dart';
import '../widgets/avatar.dart';
import '../widgets/sidebar.dart';
import 'accounts_screen.dart';
import 'compose_screen.dart';
import 'thread_screen.dart';

String shortDate(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return DateFormat.Hm().format(d);
  if (diff == 1) return 'Včera';
  if (diff < 7) return DateFormat.EEEE('sk').format(d);
  return DateFormat('d. M. yyyy').format(d);
}

/// Koreň aplikácie. Rozloženie sa riadi skutočnou veľkosťou okna a ohybom displeja:
///  • compact  (< 600 dp: vonkajší displej Foldu, zložený telefón): jeden panel
///  • medium   (600–840 dp: rozdelená obrazovka, tablet na výšku): zoznam + vlákno
///  • expanded (≥ 840 dp: vnútorný displej Foldu): bočný panel + zoznam + vlákno
///  • Flex režim (polozložený, vodorovný ohyb): vlákno hore, písanie dole
///  • režim „kniha“ (polozložený, zvislý ohyb): zoznam vľavo, vlákno vpravo od ohybu
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!state.initialised) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (state.accounts.isEmpty) {
      return const AccountsScreen(firstRun: true);
    }
    final read = context.read<AppState>();

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown, alt: true): () =>
            read.moveSelection(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp, alt: true): () =>
            read.moveSelection(-1),
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            read.select(null),
        const SingleActivator(LogicalKeyboardKey.keyR, control: true):
            read.refresh,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            read.searchFocus.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
            openCompose(context),
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(builder: (context, c) {
          final cls = windowClassOf(c.maxWidth);
          final fold = FoldInfo.of(context);
          final sel = state.selected;

          if (cls == WindowClass.compact) return _Compact(sel: sel);

          if (fold.tabletop && sel != null) {
            return Scaffold(
              body: ThreadView(
                key: ValueKey('flex-${sel.contactEmail}'),
                conversation: sel,
                flex: FlexSplit(fold.bounds.top, fold.bounds.height),
              ),
            );
          }
          return _MasterDetail(
              cls: cls, width: c.maxWidth, fold: fold, sel: sel);
        }),
      ),
    );
  }
}

class _Compact extends StatelessWidget {
  const _Compact({this.sel});

  final Conversation? sel;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final conv = sel;
    return PopScope(
      canPop: conv == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) state.select(null);
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
                    begin: const Offset(0.05, 0), end: Offset.zero)
                .animate(anim),
            child: child,
          ),
        ),
        child: conv == null
            ? const ConversationList(key: ValueKey('list'), showFilters: true)
            : Scaffold(
                key: ValueKey('thread-${conv.contactEmail}'),
                body: ThreadView(conversation: conv, showBack: true),
              ),
      ),
    );
  }
}

class _MasterDetail extends StatelessWidget {
  const _MasterDetail({
    required this.cls,
    required this.width,
    required this.fold,
    required this.sel,
  });

  final WindowClass cls;
  final double width;
  final FoldInfo fold;
  final Conversation? sel;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final hasSidebar = cls == WindowClass.expanded;
    final extended = width >= 1200;
    final sidebarW = hasSidebar ? Sidebar.widthFor(extended) : 0.0;

    double listW;
    double gap = 9;
    var resizable = true;
    if (fold.book) {
      // zoznam presne vľavo od ohybu, vlákno vpravo od neho
      listW = (fold.bounds.left - sidebarW).clamp(260.0, width).toDouble();
      gap = math.max(fold.bounds.width, 1);
      resizable = false;
    } else {
      final maxList = math.max(300.0, width - sidebarW - 380);
      listW = state.listWidth.clamp(300.0, maxList).toDouble();
    }

    return Scaffold(
      body: Row(
        children: [
          if (hasSidebar) Sidebar(extended: extended),
          SizedBox(
            width: listW,
            child: ConversationList(showFilters: !hasSidebar, embedded: true),
          ),
          if (resizable)
            _ResizeHandle(
              onDrag: (dx) =>
                  context.read<AppState>().setListWidth(state.listWidth + dx),
              onEnd: () => context.read<AppState>().saveListWidth(),
            )
          else
            SizedBox(
              width: gap,
              child: ColoredBox(color: Theme.of(context).dividerColor),
            ),
          Expanded(
            child: sel == null
                ? const _EmptyDetail()
                : ThreadView(
                    key: ValueKey(sel!.contactEmail),
                    conversation: sel!,
                  ),
          ),
        ],
      ),
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({required this.onDrag, required this.onEnd});

  final ValueChanged<double> onDrag;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (d) => onDrag(d.delta.dx),
        onHorizontalDragEnd: (_) => onEnd(),
        child: SizedBox(
          width: 9,
          child: Center(
            child: Container(width: 1, color: Theme.of(context).dividerColor),
          ),
        ),
      ),
    );
  }
}

class _EmptyDetail extends StatelessWidget {
  const _EmptyDetail();

  @override
  Widget build(BuildContext context) {
    const grey = TextStyle(color: Colors.grey, fontSize: 14);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined,
              size: 56, color: Colors.grey.withOpacity(0.6)),
          const SizedBox(height: 12),
          const Text('Vyber konverzáciu',
              style: TextStyle(color: Colors.grey, fontSize: 17)),
          const SizedBox(height: 16),
          const Text('Alt + ↑ / ↓   prepínanie konverzácií', style: grey),
          const SizedBox(height: 4),
          const Text('Ctrl + F   hľadať     Ctrl + N   nová správa', style: grey),
          const SizedBox(height: 4),
          const Text('Ctrl + R   obnoviť     Esc   zrušiť výber', style: grey),
        ],
      ),
    );
  }
}

class ConversationList extends StatelessWidget {
  const ConversationList({
    super.key,
    this.embedded = false,
    this.showFilters = true,
  });

  /// true = je vo vnútri viacpanelového rozloženia (zvýrazňuje vybraný riadok).
  final bool embedded;

  /// Riadok filtrov (Všetky / Neprečítané / účty). V rozšírenom rozložení ho
  /// nahrádza bočný panel.
  final bool showFilters;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final convs = state.conversations;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = dark ? const Color(0xFF1C1C1E) : Colors.white;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: state.refresh,
        child: CustomScrollView(
          key: const PageStorageKey('conversation-scroll'),
          slivers: [
            SliverAppBar.large(
              automaticallyImplyLeading: false,
              title: const Text('Konverzácie',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              actions: [
                if (state.loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (showFilters)
                  IconButton(
                    tooltip: 'Obnoviť',
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: state.refresh,
                  ),
                IconButton(
                  tooltip: 'Nová správa',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => openCompose(context),
                ),
                if (showFilters)
                  IconButton(
                    tooltip: 'Účty',
                    icon: const Icon(Icons.account_circle_outlined),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AccountsScreen()),
                    ),
                  ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: TextField(
                  focusNode: state.searchFocus,
                  onChanged: state.setQuery,
                  decoration: InputDecoration(
                    hintText: 'Hľadať',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: dark
                        ? const Color(0xFF1C1C1E)
                        : const Color(0xFFE3E3E8),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
            if (showFilters)
              const SliverToBoxAdapter(child: _FilterChips()),
            if (state.error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(state.error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 13)),
                ),
              ),
            if (convs.isEmpty && !state.loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                    child: Text('Žiadne konverzácie',
                        style: TextStyle(color: Colors.grey))),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (var i = 0; i < convs.length; i++) ...[
                          _Row(
                            conv: convs[i],
                            selected: embedded &&
                                state.selectedContact == convs[i].contactEmail,
                            onTap: () => state.select(convs[i].contactEmail),
                          ),
                          if (i != convs.length - 1)
                            Divider(
                                height: 1,
                                indent: 74,
                                color: Theme.of(context).dividerColor),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final chips = <Widget>[
      ChoiceChip(
        label: const Text('Všetky'),
        selected: state.accountFilter == null && !state.unreadOnly,
        onSelected: (_) => state.setFilter(),
      ),
      ChoiceChip(
        label: Text('Neprečítané (${state.unreadFor(null)})'),
        selected: state.unreadOnly,
        onSelected: (_) => state.setFilter(unread: true),
      ),
      if (state.accounts.length > 1)
        for (final a in state.accounts)
          ChoiceChip(
            label: Text(a.email.split('@').first),
            selected: state.accountFilter == a.id,
            onSelected: (_) => state.setFilter(accountId: a.id),
          ),
    ];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Center(child: chips[i]),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.conv, required this.onTap, this.selected = false});

  final Conversation conv;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final last = conv.last;
    final unread = conv.unread;
    final preview = last.text.trim().isNotEmpty
        ? last.text.trim().replaceAll(RegExp(r'\s+'), ' ')
        : last.subject;
    final accent = Theme.of(context).colorScheme.primary;

    return Material(
      color: selected ? accent.withOpacity(0.12) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 14,
                height: 46,
                child: unread > 0
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              color: accent, shape: BoxShape.circle),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 4),
              Avatar(name: conv.contactName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conv.contactName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: unread > 0
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(shortDate(last.date),
                            style: const TextStyle(
                                fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    if (last.subject.isNotEmpty)
                      Text(last.subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14)),
                    Text(
                      '${last.outgoing ? 'Ty: ' : ''}$preview',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              if (conv.messages.length > 1) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${conv.messages.length}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
