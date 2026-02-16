import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';

/// Navigation item definition for the sidebar.
class _NavItem {
  final String label;
  final IconData icon;
  final String path;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.path,
  });
}

const _navItems = [
  _NavItem(
      label: 'Dashboard', icon: Icons.dashboard, path: RoutePaths.dashboard,),
  _NavItem(label: 'Rangers', icon: Icons.person, path: RoutePaths.rangers,),
  _NavItem(label: 'Segments', icon: Icons.route, path: RoutePaths.segments,),
  _NavItem(
      label: 'Passages', icon: Icons.directions_car, path: RoutePaths.passages,),
  _NavItem(
      label: 'Violations',
      icon: Icons.warning_amber,
      path: RoutePaths.violations,),
  _NavItem(
      label: 'Unmatched', icon: Icons.help_outline, path: RoutePaths.unmatched,),
];

/// Responsive admin shell layout with a persistent sidebar on desktop
/// and a collapsible sidebar on smaller screens.
class AdminShell extends ConsumerStatefulWidget {
  final Widget child;

  const AdminShell({super.key, required this.child});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  bool _sidebarCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 1024;
    final isTablet = width > 600 && width <= 1024;

    if (isDesktop) {
      return _buildDesktopLayout();
    } else if (isTablet) {
      return _buildTabletLayout();
    } else {
      return _buildMobileLayout();
    }
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        _buildSidebar(collapsed: false),
        Expanded(
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return Row(
      children: [
        _buildSidebar(collapsed: _sidebarCollapsed),
        Expanded(
          child: _buildContent(
            showMenuButton: true,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Tracker'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: Drawer(
        child: _buildSidebarContent(collapsed: false),
      ),
      body: widget.child,
    );
  }

  Widget _buildSidebar({required bool collapsed}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: collapsed ? 72 : 260,
      child: _buildSidebarContent(collapsed: collapsed),
    );
  }

  Widget _buildSidebarContent({required bool collapsed}) {
    final authState = ref.watch(authStateProvider);
    final currentUser = authState.valueOrNull;
    final currentPath = GoRouterState.of(context).matchedLocation;

    return Container(
      color: AppTheme.sidebarBackground,
      child: Column(
        children: [
          // Header / Brand.
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 12 : 20,
              vertical: 24,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.sidebarActive,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.shield,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Vehicle Tracker',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),

          // Navigation items.
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: _navItems.map((item) {
                final isActive = currentPath == item.path ||
                    (item.path != '/' && currentPath.startsWith(item.path));
                return _buildNavItem(
                  item: item,
                  isActive: isActive,
                  collapsed: collapsed,
                  onTap: () {
                    context.go(item.path);
                    // Close drawer on mobile.
                    if (MediaQuery.of(context).size.width <= 600) {
                      Navigator.of(context).pop();
                    }
                  },
                );
              }).toList(),
            ),
          ),

          // Footer with user info and logout.
          const Divider(color: Colors.white12, height: 1),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 8 : 16,
              vertical: 12,
            ),
            child: collapsed
                ? IconButton(
                    onPressed: _handleLogout,
                    icon: const Icon(Icons.logout, color: Colors.white70),
                    tooltip: 'Logout',
                  )
                : Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppTheme.sidebarActive,
                        child: Text(
                          currentUser?.fullName.isNotEmpty == true
                              ? currentUser!.fullName[0].toUpperCase()
                              : 'A',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentUser?.fullName ?? 'Admin',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(
                              'Administrator',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _handleLogout,
                        icon: const Icon(
                          Icons.logout,
                          color: Colors.white70,
                          size: 20,
                        ),
                        tooltip: 'Logout',
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required _NavItem item,
    required bool isActive,
    required bool collapsed,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isActive ? AppTheme.sidebarActive : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: Colors.white10,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 0 : 12,
              vertical: 10,
            ),
            child: collapsed
                ? Tooltip(
                    message: item.label,
                    child: Center(
                      child: Icon(
                        item.icon,
                        color: isActive ? Colors.white : Colors.white70,
                        size: 22,
                      ),
                    ),
                  )
                : Row(
                    children: [
                      Icon(
                        item.icon,
                        color: isActive ? Colors.white : Colors.white70,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        item.label,
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.white70,
                          fontSize: 14,
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent({bool showMenuButton = false}) {
    return Column(
      children: [
        if (showMenuButton)
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _sidebarCollapsed = !_sidebarCollapsed;
                    });
                  },
                  icon: Icon(
                    _sidebarCollapsed ? Icons.menu : Icons.menu_open,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: widget.child,
          ),
        ),
      ],
    );
  }

  Future<void> _handleLogout() async {
    await ref.read(authStateProvider.notifier).logout();
    if (mounted) {
      context.go(RoutePaths.login);
    }
  }
}
