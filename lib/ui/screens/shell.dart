import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/theme.dart';
import '../../data/captain_state.dart';
import '../kit.dart';
import 'account.dart';
import 'earnings.dart';
import 'home.dart';
import 'rides.dart';

const kNavBarHeight = 64.0;

/// Tells the tabs how much of the bottom edge the shell's bar covers.
class ShellChrome extends InheritedWidget {
  final bool barVisible;
  final double systemBottom;
  const ShellChrome({super.key, required this.barVisible, required this.systemBottom, required super.child});

  /// Height covered at the bottom (bar + system inset).
  double get covered => barVisible ? kNavBarHeight + systemBottom : systemBottom;

  static ShellChrome? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ShellChrome>();

  @override
  bool updateShouldNotify(ShellChrome old) => old.barVisible != barVisible || old.systemBottom != systemBottom;
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => ShellState();

  static ShellState? of(BuildContext context) => context.findAncestorStateOfType<ShellState>();
}

class ShellState extends State<Shell> {
  int _index = 0;
  int get index => _index;

  void select(int i) {
    if (i != _index) setState(() => _index = i);
  }

  static const _items = [
    (Symbols.home, 'Home'),
    (Symbols.payments, 'Earnings'),
    (Symbols.receipt_long, 'Rides'),
    (Symbols.person, 'Account'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final systemBottom = MediaQuery.paddingOf(context).bottom;
    const tabs = [HomeTab(), EarningsTab(), RidesTab(), AccountTab()];
    return ListenableBuilder(
      listenable: captain,
      builder: (context, _) {
        final busy = captain.stage.busy;
        // a request or trip owns the screen: the bar slides away
        if (busy && _index != 0) WidgetsBinding.instance.addPostFrameCallback((_) => select(0));
        return PopScope(
          canPop: _index == 0 && !busy,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && _index != 0) select(0);
          },
          child: ShellChrome(
            barVisible: !busy,
            systemBottom: systemBottom,
            child: Scaffold(
              extendBody: true,
              body: IndexedStack(
                index: _index,
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    TickerMode(
                      enabled: i == _index,
                      child: AnimatedOpacity(opacity: i == _index ? 1 : 0, duration: kMedium, curve: Curves.easeOut, child: tabs[i]),
                    ),
                ],
              ),
              bottomNavigationBar: IgnorePointer(
                ignoring: busy,
                child: AnimatedSlide(
                  offset: busy ? const Offset(0, 1) : Offset.zero,
                  duration: kMedium,
                  curve: kEase,
                  child: Container(
                    decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.border))),
                    child: SafeArea(
                      top: false,
                      child: SizedBox(
                        height: kNavBarHeight,
                        child: Row(children: [
                          for (var i = 0; i < _items.length; i++)
                            Expanded(child: _NavItem(icon: _items[i].$1, label: _items[i].$2, selected: i == _index, onTap: () => select(i))),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        AnimatedContainer(
          duration: kMedium,
          curve: kEase,
          width: selected ? 56 : 40,
          height: 30,
          decoration: BoxDecoration(color: selected ? Brand.primary : Colors.transparent, borderRadius: BorderRadius.circular(15)),
          child: Icon(icon, size: 22, fill: selected ? 1 : 0, weight: selected ? 500 : 400, color: selected ? Brand.onPrimary : c.text2),
        ),
        const SizedBox(height: 4),
        AnimatedDefaultTextStyle(
          duration: kMedium,
          style: context.t.caption.copyWith(fontSize: 11.5, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? c.text : c.text2),
          child: Text(label),
        ),
      ]),
    );
  }
}

/// Bottom padding for scrolling tab content (clears the bar and system inset).
double tabBottomPadding(BuildContext context) => (ShellChrome.of(context)?.covered ?? MediaQuery.paddingOf(context).bottom) + 24;
