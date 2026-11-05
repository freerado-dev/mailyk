import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/accounts_screen.dart';
import '../screens/compose_screen.dart';
import '../state.dart';
import 'avatar.dart';

/// Bočný panel pre veľkú plochu (vnútorný displej Foldu):
/// úzka lišta na šírke < 1200 dp, rozšírený panel s popiskami nad tým.
class Sidebar extends StatelessWidget {
  const Sidebar({super.key, required this.extended});

  final bool extended;

  static double widthFor(bool extended) => extended ? 232.0 : 76.0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final allSelected = state.accountFilter == null && !state.unreadOnly;

    return Container(
      width: widthFor(extended),
      color: dark ? const Color(0xFF0B0B0D) : const Color(0xFFE8E8ED),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(extended ? 12 : 10, 14, extended ? 12 : 10, 10),
              child: extended
                  ? SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Nová správa'),
                        onPressed: () => openCompose(context),
                      ),
                    )
                  : Tooltip(
                      message: 'Nová správa',
                      child: IconButton.filled(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => openCompose(context),
                      ),
                    ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: extended ? 10 : 8),
                children: [
                  _SideItem(
                    extended: extended,
                    icon: Icons.all_inbox_rounded,
                    label: 'Všetky schránky',
                    count: state.unreadFor(null),
                    selected: allSelected,
                    onTap: () => state.setFilter(),
                  ),
                  _SideItem(
                    extended: extended,
                    icon: Icons.mark_email_unread_outlined,
                    label: 'Neprečítané',
                    count: 0,
                    selected: state.unreadOnly && state.accountFilter == null,
                    onTap: () => state.setFilter(unread: true),
                  ),
                  const Divider(height: 20),
                  if (extended)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(12, 0, 12, 6),
                      child: Text('ÚČTY',
                          style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey)),
                    ),
                  for (final a in state.accounts)
                    _SideItem(
                      extended: extended,
                      icon: Icons.mail_outline,
                      leading: Avatar(name: a.name, size: 26),
                      label: a.email,
                      count: state.unreadFor(a.id),
                      selected: state.accountFilter == a.id,
                      onTap: () => state.setFilter(accountId: a.id),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: extended ? 10 : 8, vertical: 8),
              child: Column(
                children: [
                  _SideItem(
                    extended: extended,
                    icon: state.loading ? Icons.sync : Icons.refresh_rounded,
                    label: state.loading ? 'Synchronizujem…' : 'Obnoviť',
                    count: 0,
                    selected: false,
                    onTap: state.refresh,
                  ),
                  _SideItem(
                    extended: extended,
                    icon: Icons.settings_outlined,
                    label: 'Účty',
                    count: 0,
                    selected: false,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AccountsScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  const _SideItem({
    required this.extended,
    required this.icon,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.leading,
  });

  final bool extended;
  final IconData icon;
  final Widget? leading;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final iconWidget = leading ??
        Icon(icon, size: 22, color: selected ? accent : null);

    if (extended) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Material(
          color: selected ? accent.withOpacity(0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  iconWidget,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected ? accent : null,
                      ),
                    ),
                  ),
                  if (count > 0)
                    Text('$count',
                        style: const TextStyle(
                            fontSize: 13, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Tooltip(
      message: label,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Material(
          color: selected ? accent.withOpacity(0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: SizedBox(
              height: 50,
              child: Center(
                child: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  child: iconWidget,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
