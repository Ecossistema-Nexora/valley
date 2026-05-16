import 'package:flutter/material.dart';

enum ValleyPersona { admin, merchant, customer, courier }

class ValleyPersonaTheme {
  const ValleyPersonaTheme({
    required this.persona,
    required this.label,
    required this.background,
    required this.surface,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.text,
    required this.mutedText,
    required this.line,
  });

  final ValleyPersona persona;
  final String label;
  final Color background;
  final Color surface;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color text;
  final Color mutedText;
  final Color line;

  static const Map<ValleyPersona, ValleyPersonaTheme> values =
      <ValleyPersona, ValleyPersonaTheme>{
        ValleyPersona.admin: ValleyPersonaTheme(
          persona: ValleyPersona.admin,
          label: 'Admin',
          background: Color(0xFF05050A),
          surface: Color(0xFF0B1020),
          primary: Color(0xFF7C3AED),
          secondary: Color(0xFF00E5FF),
          accent: Color(0xFFB8FF4D),
          text: Color(0xFFF8FAFC),
          mutedText: Color(0xFFA7B0C2),
          line: Color(0xFF263044),
        ),
        ValleyPersona.merchant: ValleyPersonaTheme(
          persona: ValleyPersona.merchant,
          label: 'Lojista / ERP',
          background: Color(0xFFE9FBFF),
          surface: Color(0xFFFFFFFF),
          primary: Color(0xFF027C92),
          secondary: Color(0xFF10B6D0),
          accent: Color(0xFF14532D),
          text: Color(0xFF082F49),
          mutedText: Color(0xFF486878),
          line: Color(0xFFBEEAF2),
        ),
        ValleyPersona.customer: ValleyPersonaTheme(
          persona: ValleyPersona.customer,
          label: 'Usuario',
          background: Color(0xFFF8FAFC),
          surface: Color(0xFFFFFFFF),
          primary: Color(0xFF5B21B6),
          secondary: Color(0xFF0EA5E9),
          accent: Color(0xFF14B8A6),
          text: Color(0xFF111827),
          mutedText: Color(0xFF667085),
          line: Color(0xFFE5E7EB),
        ),
        ValleyPersona.courier: ValleyPersonaTheme(
          persona: ValleyPersona.courier,
          label: 'Entregador',
          background: Color(0xFF171C1B),
          surface: Color(0xFF232B29),
          primary: Color(0xFF22C55E),
          secondary: Color(0xFF86EFAC),
          accent: Color(0xFFFACC15),
          text: Color(0xFFF8FAFC),
          mutedText: Color(0xFFB7C8C0),
          line: Color(0xFF3C4A45),
        ),
      };

  static ValleyPersonaTheme of(ValleyPersona persona) => values[persona]!;
}

class ValleyTopAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ValleyTopAppBar({
    super.key,
    required this.persona,
    required this.title,
    this.subtitle,
    this.actions = const <Widget>[],
  });

  final ValleyPersona persona;
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final ValleyPersonaTheme theme = ValleyPersonaTheme.of(persona);
    return AppBar(
      backgroundColor: theme.surface,
      foregroundColor: theme.text,
      elevation: 0,
      titleSpacing: 16,
      shape: Border(bottom: BorderSide(color: theme.line)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.mutedText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
      actions: actions,
    );
  }
}

class ValleyBottomNavBar extends StatelessWidget {
  const ValleyBottomNavBar({
    super.key,
    required this.persona,
    required this.currentIndex,
    required this.onTap,
  });

  final ValleyPersona persona;
  final int currentIndex;
  final ValueChanged<int> onTap;

  static const List<NavigationDestination> destinations =
      <NavigationDestination>[
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Inicio',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: 'Pedidos',
        ),
        NavigationDestination(
          icon: Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: Icon(Icons.account_balance_wallet),
          label: 'Carteira',
        ),
        NavigationDestination(
          icon: Icon(Icons.auto_awesome_outlined),
          selectedIcon: Icon(Icons.auto_awesome),
          label: 'Helena',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Perfil',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final ValleyPersonaTheme theme = ValleyPersonaTheme.of(persona);
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      backgroundColor: theme.surface,
      indicatorColor: theme.primary.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
      destinations: destinations,
    );
  }
}

class ValleyNavigationDrawer extends StatelessWidget {
  const ValleyNavigationDrawer({
    super.key,
    required this.persona,
    required this.selectedIndex,
    required this.destinations,
    required this.onDestinationSelected,
  });

  final ValleyPersona persona;
  final int selectedIndex;
  final List<NavigationDrawerDestination> destinations;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final ValleyPersonaTheme theme = ValleyPersonaTheme.of(persona);
    return NavigationDrawer(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      backgroundColor: theme.surface,
      indicatorColor: theme.primary.withValues(alpha: 0.14),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Valley',
                style: TextStyle(
                  color: theme.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                theme.label,
                style: TextStyle(
                  color: theme.mutedText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        ...destinations,
      ],
    );
  }
}
