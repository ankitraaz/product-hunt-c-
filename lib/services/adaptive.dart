import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:product_hunt/Pages/product_page.dart';

/// Phone => Bottom Navigation
/// Web/Tablet/Desktop => NavigationRail (side)
class PHNavShell extends StatefulWidget {
  const PHNavShell({super.key});

  @override
  State<PHNavShell> createState() => _PHNavShellState();
}

class _PHNavShellState extends State<PHNavShell> {
  int index = 0;

  // TODO: apne real pages import karke yahan plug-in karo
  final List<Widget> pages = [
    const Center(child: Text('Today')),
    const Center(child: Text('Explore')),
    ProductPage(),
    const Center(child: Text('Notifications')),
    const Center(child: Text('Profile')),
  ];

  final List<_Dest> _items = const [
    _Dest('Today', Icons.today_outlined, Icons.today),
    _Dest('Explore', Icons.explore_outlined, Icons.explore),
    _Dest('Submit', Icons.add_circle_outline, Icons.add_circle),
    _Dest('Alerts', Icons.notifications_none, Icons.notifications),
    _Dest('Profile', Icons.person_outline, Icons.person),
  ];

  @override
  Widget build(BuildContext context) {
    // Handset detection (reliable): not web AND shortestSide < 600
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    final bool isPhone = !kIsWeb && shortest < 600;
    final bool useRail = !isPhone; // tablet/web/desktop => rail

    if (useRail) {
      // -------- WEB/TABLET/DESKTOP: NavigationRail on the left --------
      return Scaffold(
        appBar: AppBar(
          title: const Text('ProductHunt-ish'),
          actions: [
            IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          ],
        ),
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: (i) => setState(() => index = i),
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.rocket_launch),
              ),
              destinations: _items
                  .map(
                    (d) => NavigationRailDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: Text(d.label),
                    ),
                  )
                  .toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: pages[index]),
          ],
        ),
        floatingActionButton: index != 2
            ? FloatingActionButton.extended(
                onPressed: () => setState(() => index = 2),
                icon: const Icon(Icons.rocket_launch),
                label: const Text('Launch'),
              )
            : null,
      );
    }

    // -------- PHONE: Bottom Navigation --------
    return Scaffold(
      appBar: AppBar(
        title: Text(_items[index].label),
        actions: [IconButton(icon: const Icon(Icons.search), onPressed: () {})],
      ),
      body: pages[index],
      // Material 3 bottom nav
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: _items
            .map(
              (d) => NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              ),
            )
            .toList(),
      ),
      floatingActionButton: index != 2
          ? FloatingActionButton.extended(
              onPressed: () => setState(() => index = 2),
              icon: const Icon(Icons.rocket_launch),
              label: const Text('Launch'),
            )
          : null,
    );
  }
}

class _Dest {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const _Dest(this.label, this.icon, this.selectedIcon);
}
