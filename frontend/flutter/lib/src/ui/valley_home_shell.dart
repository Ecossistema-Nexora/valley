import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valley_super_app/src/data/valley_models.dart';
import 'package:valley_super_app/src/ui/ui_components.dart';
import 'package:valley_super_app/valley_brand_theme.dart';

const String _homeModulePrefsKey = 'valley.home.visible_modules.v1';

int _destinationIndexForModule(String code) {
  if (<String>{
    'PAY',
    'PLUG',
    'DOCS',
    'FINANCAS',
    'UP',
    'DIGITAL',
  }.contains(code)) {
    return 1;
  }
  if (<String>{
    'STOCK',
    'WMS',
    'MARKETPLACE',
    'FOOD',
    'DELIVERY',
    'LOG',
  }.contains(code)) {
    return 2;
  }
  if (<String>{
    'BUSINESS',
    'REPLY',
    'SERVICES',
    'JOBS',
    'TECH',
  }.contains(code)) {
    return 3;
  }
  if (<String>{'SECURITY', 'LEGAL', 'GOV', 'HEALTH', 'MENTE'}.contains(code)) {
    return 4;
  }
  if (<String>{'CHAT', 'ADVISOR', 'AGENDA', 'SOCIAL', 'MEDIA'}.contains(code)) {
    return 5;
  }
  return 0;
}

IconData _moduleIconFor(ModuleRecord module) {
  switch (module.code) {
    case 'PAY':
    case 'PLUG':
    case 'FINANCAS':
      return Icons.account_balance_wallet_rounded;
    case 'MARKETPLACE':
    case 'STOCK':
      return Icons.storefront_rounded;
    case 'WMS':
    case 'LOG':
    case 'DELIVERY':
      return Icons.local_shipping_rounded;
    case 'BUSINESS':
    case 'REPLY':
      return Icons.apartment_rounded;
    case 'CHAT':
    case 'ADVISOR':
    case 'AGENDA':
      return Icons.auto_awesome_rounded;
    case 'SOCIAL':
    case 'INFLUENCERS':
    case 'MEDIA':
      return Icons.groups_2_rounded;
    case 'SECURITY':
    case 'LEGAL':
    case 'GOV':
      return Icons.verified_user_rounded;
    case 'HEALTH':
    case 'MENTE':
    case 'FITNESS':
    case 'PHARMACY':
      return Icons.health_and_safety_rounded;
    case 'IOT':
    case 'HOME':
    case 'ENERGY':
      return Icons.sensors_rounded;
    default:
      return Icons.hexagon_rounded;
  }
}

Color _moduleAccentFor(ModuleRecord module) {
  switch (module.tier) {
    case 'foundation':
      return ValleyBrandColors.cyan;
    case 'core':
      return ValleyBrandColors.violet;
    case 'frontier':
      return ValleyBrandColors.lilac;
    default:
      return ValleyBrandColors.success;
  }
}

class ValleyHomeShell extends StatefulWidget {
  const ValleyHomeShell({super.key, required this.data});

  final ValleyAppData data;

  @override
  State<ValleyHomeShell> createState() => _ValleyHomeShellState();
}

class _ValleyHomeShellState extends State<ValleyHomeShell> {
  int _index = 0;
  Set<String> _homeModuleCodes = <String>{};
  bool _modulePreferencesReady = false;
  String? _selectedDockModuleCode;

  static const List<_Destination> _destinations = <_Destination>[
    _Destination(
      label: 'Inicio',
      title: 'Valley Premium',
      icon: Icons.dashboard_customize_rounded,
    ),
    _Destination(
      label: 'Carteira',
      title: 'Pay + Plug + Docs',
      icon: Icons.account_balance_wallet_rounded,
    ),
    _Destination(
      label: 'Marketplace',
      title: 'Stock + WMS + Marketplace',
      icon: Icons.storefront_rounded,
    ),
    _Destination(
      label: 'Negocios',
      title: 'Business + Reply',
      icon: Icons.apartment_rounded,
    ),
    _Destination(
      label: 'Identidade',
      title: 'Face ID + Voice ID + Score',
      icon: Icons.verified_user_rounded,
    ),
    _Destination(
      label: 'Helena',
      title: 'Chat + Advisor + Agenda',
      icon: Icons.auto_awesome_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _homeModuleCodes = _defaultHomeModuleCodes();
    unawaited(_loadHomeModulePreferences());
  }

  Set<String> _defaultHomeModuleCodes() {
    final Set<String> included = widget.data.includedModuleRecords
        .map((ModuleRecord module) => module.code)
        .toSet();
    if (included.isNotEmpty) {
      return included;
    }

    return widget.data.modules
        .take(12)
        .map((ModuleRecord module) => module.code)
        .toSet();
  }

  Future<void> _loadHomeModulePreferences() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final List<String>? storedCodes = preferences.getStringList(
      _homeModulePrefsKey,
    );
    final Set<String> validCodes = widget.data.modules
        .map((ModuleRecord module) => module.code)
        .toSet();

    if (!mounted) {
      return;
    }

    setState(() {
      if (storedCodes != null && storedCodes.isNotEmpty) {
        _homeModuleCodes = storedCodes
            .where((String code) => validCodes.contains(code))
            .toSet();
        if (_homeModuleCodes.isEmpty) {
          _homeModuleCodes = _defaultHomeModuleCodes();
        }
      }
      _modulePreferencesReady = true;
    });
  }

  Future<void> _saveHomeModulePreferences() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final List<String> sortedCodes = _homeModuleCodes.toList()..sort();
    await preferences.setStringList(_homeModulePrefsKey, sortedCodes);
  }

  void _toggleHomeModule(ModuleRecord module, bool selected) {
    setState(() {
      if (selected) {
        _homeModuleCodes.add(module.code);
      } else if (_homeModuleCodes.length > 1) {
        _homeModuleCodes.remove(module.code);
      }
    });
    unawaited(_saveHomeModulePreferences());
  }

  void _navigate(int index) {
    setState(() {
      _index = index;
      _selectedDockModuleCode = null;
    });
  }

  void _openModule(ModuleRecord module) {
    final int destinationIndex = _destinationIndexForModule(module.code);
    setState(() {
      _index = destinationIndex;
      _selectedDockModuleCode = module.code;
    });

    if (destinationIndex == 0) {
      unawaited(
        _showModuleActionSheet(
          context,
          code: module.code,
          title: module.name,
          subtitle: module.subtitle,
          caption: module.description,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool wide = MediaQuery.sizeOf(context).width >= 1040;
    final Widget currentPage = _buildPage();

    return Scaffold(
      backgroundColor: ValleyBrandColors.night,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _navigate,
              destinations: _destinations
                  .map(
                    (_Destination destination) => NavigationDestination(
                      icon: Icon(destination.icon),
                      label: destination.label,
                    ),
                  )
                  .toList(),
            ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              ValleyBrandColors.night,
              ValleyBrandColors.cosmic,
              Color(0xFF09071E),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: <Widget>[
              const ValleyBackdrop(),
              Row(
                children: <Widget>[
                  if (wide)
                    _DesktopSidebar(
                      data: widget.data,
                      currentIndex: _index,
                      destinations: _destinations,
                      onNavigate: _navigate,
                    ),
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        if (!wide)
                          _MobileTopBar(
                            title: _destinations[_index].title,
                            data: widget.data,
                          ),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 320),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: KeyedSubtree(
                              key: ValueKey<int>(_index),
                              child: currentPage,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                left: wide ? 316 : 14,
                right: 14,
                bottom: wide ? 18 : 88,
                child: _ModuleAccessDock(
                  modules: widget.data.modules,
                  selectedCode: _selectedDockModuleCode,
                  onOpenModule: _openModule,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage() {
    switch (_index) {
      case 0:
        return _OverviewPage(
          data: widget.data,
          homeModuleCodes: _homeModuleCodes,
          preferencesReady: _modulePreferencesReady,
          onNavigate: _navigate,
          onOpenModule: _openModule,
          onToggleHomeModule: _toggleHomeModule,
        );
      case 1:
        return _WalletPage(data: widget.data);
      case 2:
        return _MarketplacePage(data: widget.data);
      case 3:
        return _BusinessPage(data: widget.data);
      case 4:
        return _IdentityPage(data: widget.data);
      case 5:
        return _HelenaPage(data: widget.data);
      default:
        return _OverviewPage(
          data: widget.data,
          homeModuleCodes: _homeModuleCodes,
          preferencesReady: _modulePreferencesReady,
          onNavigate: _navigate,
          onOpenModule: _openModule,
          onToggleHomeModule: _toggleHomeModule,
        );
    }
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.data,
    required this.currentIndex,
    required this.destinations,
    required this.onNavigate,
  });

  final ValleyAppData data;
  final int currentIndex;
  final List<_Destination> destinations;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 292,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        children: <Widget>[
          ValleyPanel(
            padding: const EdgeInsets.all(20),
            glowColor: ValleyBrandColors.violet,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const ValleyLogoMark(size: 60, borderRadius: 18),
                const SizedBox(height: 20),
                Text(
                  'Valley Super App',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Pagamentos, comercio, identidade e Helena no mesmo ecossistema premium.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    SignalChip(
                      label: '${data.modules.length} modulos',
                      color: ValleyBrandColors.cyan,
                    ),
                    SignalChip(
                      label: 'modo premium',
                      color: ValleyBrandColors.violet,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ValleyPanel(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < destinations.length; i++) ...<Widget>[
                    _SidebarButton(
                      destination: destinations[i],
                      selected: i == currentIndex,
                      onTap: () => onNavigate(i),
                    ),
                    if (i != destinations.length - 1) const SizedBox(height: 8),
                  ],
                  const Spacer(),
                  ValleyPanel(
                    padding: const EdgeInsets.all(16),
                    glowColor: ValleyBrandColors.cyan,
                    background: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        ValleyBrandColors.cyan.withValues(alpha: 0.10),
                        ValleyBrandColors.cosmic.withValues(alpha: 0.82),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Experiencia ativa',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'A mesma experiencia final em Android e Web.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 14),
                        const SignalChip(
                          label: 'android + web',
                          color: ValleyBrandColors.success,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarButton extends StatelessWidget {
  const _SidebarButton({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: selected
                ? ValleyBrandColors.violet.withValues(alpha: 0.18)
                : Colors.transparent,
            border: Border.all(
              color: selected
                  ? ValleyBrandColors.violet.withValues(alpha: 0.44)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                destination.icon,
                color: selected
                    ? ValleyBrandColors.snow
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      destination.label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected ? ValleyBrandColors.snow : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      destination.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: selected
                            ? ValleyBrandColors.snow.withValues(alpha: 0.72)
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
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

class _MobileTopBar extends StatelessWidget {
  const _MobileTopBar({required this.title, required this.data});

  final String title;
  final ValleyAppData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: ValleyPanel(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: <Widget>[
            const ValleyLogoMark(size: 44, borderRadius: 14),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  Text(
                    '${data.modules.length} modulos conectados',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SignalChip(
              label: 'premium',
              color: ValleyBrandColors.success,
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewPage extends StatelessWidget {
  const _OverviewPage({
    required this.data,
    required this.homeModuleCodes,
    required this.preferencesReady,
    required this.onNavigate,
    required this.onOpenModule,
    required this.onToggleHomeModule,
  });

  final ValleyAppData data;
  final Set<String> homeModuleCodes;
  final bool preferencesReady;
  final ValueChanged<int> onNavigate;
  final ValueChanged<ModuleRecord> onOpenModule;
  final void Function(ModuleRecord module, bool selected) onToggleHomeModule;

  @override
  Widget build(BuildContext context) {
    final List<ModuleRecord> homeModules =
        data.modules
            .where(
              (ModuleRecord module) => homeModuleCodes.contains(module.code),
            )
            .toList()
          ..sort(
            (ModuleRecord a, ModuleRecord b) => a.number.compareTo(b.number),
          );
    return _PageFrame(
      child: FadeSlideIn(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _OrbitalCommandHero(
              data: data,
              homeModules: homeModules,
              onNavigate: onNavigate,
              onOpenModule: onOpenModule,
            ),
            const SizedBox(height: 20),
            _PremiumSignalRibbon(data: data),
            const SizedBox(height: 32),
            SectionHeader(
              kicker: 'Home Modular',
              title: 'Escolha quais modulos aparecem na tela inicial',
              caption:
                  'A selecao fica salva no aparelho e o dock inferior mantem acesso rapido a todo o ecossistema.',
              trailing: SignalChip(
                label: '${homeModules.length}/${data.modules.length} visiveis',
                color: preferencesReady
                    ? ValleyBrandColors.success
                    : ValleyBrandColors.warning,
              ),
            ),
            const SizedBox(height: 18),
            _HomeModuleComposer(
              allModules: data.modules,
              homeModules: homeModules,
              visibleCodes: homeModuleCodes,
              preferencesReady: preferencesReady,
              onOpenModule: onOpenModule,
              onToggleHomeModule: onToggleHomeModule,
            ),
            const SizedBox(height: 32),
            SectionHeader(
              kicker: 'Jornadas',
              title: 'Servicos conectados por objetivo',
              caption:
                  'Cada jornada concentra modulos, acoes e regras de confianca em uma superficie direta.',
            ),
            const SizedBox(height: 18),
            Column(
              children: data.manifest.phases.map((PhaseRecord phase) {
                final List<ModuleRecord> phaseModules = data.recordsForCodes(
                  phase.modules,
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ValleyPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            SignalChip(
                              label: phase.label,
                              color: ValleyBrandColors.violet,
                            ),
                            const Spacer(),
                            Text(
                              '${phase.successGates.length} etapas',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          phase.goal,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: phaseModules
                              .map(
                                (ModuleRecord module) => SignalChip(
                                  label: module.code,
                                  color: ValleyBrandColors.cyan,
                                  outlined: true,
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: phase.successGates
                              .take(4)
                              .map(
                                (String gate) => SizedBox(
                                  width: 280,
                                  child: Text(
                                    '• $gate',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            SectionHeader(
              kicker: 'Essenciais',
              title: 'Atalhos comerciais',
              caption:
                  'Modulos centrais para pagamentos, documentos, operacao empresarial, comercio e Helena.',
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: data.includedModuleRecords
                  .map(
                    (ModuleRecord module) => SizedBox(
                      width: 280,
                      child: HoverModuleTile(
                        code: module.code,
                        title: module.name,
                        subtitle: '${module.subtitle} • ${module.tier}',
                        caption: module.description,
                        onTap: () => onOpenModule(module),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletPage extends StatelessWidget {
  const _WalletPage({required this.data});

  final ValleyAppData data;

  @override
  Widget build(BuildContext context) {
    final List<ModuleRecord> modules = data.recordsForCodes(<String>[
      'PAY',
      'PLUG',
      'DOCS',
    ]);

    return _PageFrame(
      child: FadeSlideIn(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SectionHeader(
              kicker: 'Carteira',
              title: 'Wallet, Plug e prova documental no mesmo fluxo',
              caption:
                  'Controle saldo, pagamentos, comprovantes e identidade financeira em uma jornada unica.',
              trailing: const SignalChip(
                label: 'seguro',
                color: ValleyBrandColors.success,
              ),
            ),
            const SizedBox(height: 18),
            ValleyPanel(
              glowColor: ValleyBrandColors.violet,
              background: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  ValleyBrandColors.violet.withValues(alpha: 0.22),
                  ValleyBrandColors.cosmic,
                  ValleyBrandColors.night,
                ],
              ),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool stacked = constraints.maxWidth < 760;
                  return _ResponsiveSplit(
                    stacked: stacked,
                    gap: 24,
                    leading: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Saldo Valley',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: ValleyBrandColors.cyan),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'R\$ 128.540,32',
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(color: ValleyBrandColors.snow),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Carteira premium com trilha de pagamento, comprovante e conciliacao no mesmo fluxo.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: ValleyBrandColors.snow.withValues(
                                  alpha: 0.76,
                                ),
                              ),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: const <Widget>[
                            SignalChip(
                              label: 'brl',
                              color: ValleyBrandColors.success,
                            ),
                            SignalChip(
                              label: 'nex equity',
                              color: ValleyBrandColors.cyan,
                              outlined: true,
                            ),
                            SignalChip(
                              label: 'p2p + split',
                              color: ValleyBrandColors.violet,
                              outlined: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        for (final Map<String, String> item
                            in const <Map<String, String>>[
                             <String, String>{
                                'label': 'Transacoes',
                                'value':
                                    'P2P, purchase, fee, refund, split, escrow',
                              },
                              <String, String>{
                                'label': 'Comprovantes',
                                'value':
                                    'Docs com checksum e recibo versionado',
                              },
                              <String, String>{
                                'label': 'Experiencia unica',
                                'value':
                                    'Android e Web com a mesma navegacao premium',
                              },
                            ]) ...<Widget>[
                          Text(
                            item['label']!,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item['value']!,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 14),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: <Widget>[
                SizedBox(
                  width: 320,
                  child: MetricTile(
                    label: 'Core modules',
                    value: '${modules.length}',
                    caption: modules
                        .map((ModuleRecord module) => module.code)
                        .join(' • '),
                    accent: ValleyBrandColors.cyan,
                  ),
                ),
                const SizedBox(
                  width: 320,
                  child: MetricTile(
                    label: 'Settlement posture',
                    value: 'D+0 / D+1',
                    caption:
                        'Plug, wallet limits e comprovacao por Docs na mesma trilha.',
                    accent: ValleyBrandColors.success,
                  ),
                ),
                const SizedBox(
                  width: 320,
                  child: MetricTile(
                    label: 'Risk posture',
                    value: 'KYC + score',
                    caption:
                        'Users, wallets e identidade forte controlando operacoes sensiveis.',
                    accent: ValleyBrandColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            SectionHeader(
              kicker: 'Fluxos',
              title: 'Pagamentos com prova ponta a ponta',
              caption:
                  'A interface mostra captura, saldo, comprovante e fechamento sem separar a jornada.',
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: const <Widget>[
                _TimelineTile(
                  step: '01',
                  title: 'Capture',
                  body:
                      'Valley Plug captura transacao presencial, Tap-to-Pay ou checkout integrado.',
                ),
                _TimelineTile(
                  step: '02',
                  title: 'Ledger',
                  body:
                      'Transactions e wallets consolidam BRL/NEX com regra append-only.',
                ),
                _TimelineTile(
                  step: '03',
                  title: 'Proof',
                  body:
                      'Valley Docs gera comprovante, checksum e trilha juridica para o evento.',
                ),
              ],
            ),
            const SizedBox(height: 30),
            SectionHeader(
              kicker: 'Historico',
              title: 'Movimentacoes recentes',
              caption:
                  'Resumo claro das operacoes financeiras mais importantes.',
            ),
            const SizedBox(height: 18),
            ...const <Widget>[
              _LedgerEventRow(
                status: 'SETTLED',
                title: 'Pagamento marketplace + split seller',
                detail:
                    'PAY + PLUG + DOCS | order_id ready | comprovante emitido',
                amount: 'R\$ 2.980,00',
              ),
              _LedgerEventRow(
                status: 'AUTHORIZED',
                title: 'P2P wallet transfer',
                detail:
                    'wallet_id source -> wallet_id target | antifraude em score moderado',
                amount: 'R\$ 450,00',
              ),
              _LedgerEventRow(
                status: 'ESCROW_HOLD',
                title: 'Reserva para ordem de fornecedor',
                detail:
                    'STOCK + MARKETPLACE | decisao de pricing e prova documental pendente',
                amount: 'R\$ 8.320,40',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MarketplacePage extends StatelessWidget {
  const _MarketplacePage({required this.data});

  final ValleyAppData data;

  @override
  Widget build(BuildContext context) {
    final PhaseRecord commercePhase =
        data.phaseByKey('phase_2_commerce') ?? data.manifest.phases[1];
    final StockMarketplaceModel model = commercePhase.stockMarketplaceModel!;
    final DropshippingBlueprint blueprint = model.blueprint;

    return _PageFrame(
      child: FadeSlideIn(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SectionHeader(
              kicker: 'Marketplace',
              title: 'Marketplace Valley com STOCK, WMS e pricing controlado',
              caption:
                  'Busca, ofertas, checkout e reputacao de seller em uma vitrine direta para compra.',
              trailing: const SignalChip(
                label: 'commerce',
                color: ValleyBrandColors.success,
              ),
            ),
            const SizedBox(height: 18),
            ValleyPanel(
              glowColor: ValleyBrandColors.cyan,
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool stacked = constraints.maxWidth < 900;
                  return _ResponsiveSplit(
                    stacked: stacked,
                    leadingFlex: 7,
                    trailingFlex: 4,
                    gap: 24,
                    leading: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Busca, vitrine e seller score ja entram no primeiro corte.',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search_rounded),
                            hintText:
                                'Buscar produtos, sellers ou integracoes...',
                          ),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: model.mustHaveSurfaces
                              .map(
                                (String item) => SignalChip(
                                  label: item,
                                  color: ValleyBrandColors.violet,
                                  outlined: true,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                    trailing: ValleyPanel(
                      padding: const EdgeInsets.all(18),
                      background: LinearGradient(
                        colors: <Color>[
                          ValleyBrandColors.success.withValues(alpha: 0.10),
                          ValleyBrandColors.night.withValues(alpha: 0.86),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Regras da compra',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          ...<String>[
                            'Sem prejuizo',
                            'Seller score visivel',
                            'Estoque e custo conferidos',
                            'Comprovante Valley Docs',
                          ].map(
                            (String item) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                '• $item',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            SectionHeader(
              kicker: 'Ofertas',
              title: 'Vitrine de ofertas',
              caption:
                  'Produtos, fornecedores e checkout aparecem com linguagem clara para o usuario final.',
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: <Widget>[
                SizedBox(
                  width: 300,
                  child: HoverModuleTile(
                    code: 'STOCK',
                    title: 'Central de Dropshipping',
                    subtitle: 'Fornecedor, custo, estoque e tracking',
                    caption:
                        'Vincula item Valley a AliExpress, Alibaba e CJDropshipping sem improviso.',
                    onTap: () => _showModuleActionSheet(
                      context,
                      code: 'STOCK',
                      title: 'Central de Dropshipping',
                      subtitle: 'Fornecedor, custo, estoque e tracking',
                      caption:
                          'Centraliza custo, estoque, fornecedor e rastreio em uma unica experiencia.',
                    ),
                  ),
                ),
                SizedBox(
                  width: 300,
                  child: HoverModuleTile(
                    code: 'WMS',
                    title: 'Endereco e variancia',
                    subtitle: 'Disponibilidade logica e prova operacional',
                    caption:
                        'Preparado para estoque proprio e oferta sem CAPEX na mesma experiencia.',
                    onTap: () => _showModuleActionSheet(
                      context,
                      code: 'WMS',
                      title: 'Endereco e variancia',
                      subtitle: 'Disponibilidade logica e prova operacional',
                      caption:
                          'Organiza disponibilidade, endereco e variancia para uma operacao mais confiavel.',
                    ),
                  ),
                ),
                SizedBox(
                  width: 300,
                  child: HoverModuleTile(
                    code: 'MARKETPLACE',
                    title: 'Checkout Valley',
                    subtitle: 'Seller score + Plug + Docs',
                    caption:
                        'Cada oferta fecha com comprovante, controle de margem e identidade Valley.',
                    onTap: () => _showModuleActionSheet(
                      context,
                      code: 'MARKETPLACE',
                      title: 'Checkout Valley',
                      subtitle: 'Seller score + Plug + Docs',
                      caption:
                          'Fecha compra com seller score, pagamento Valley e comprovante documental.',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            SectionHeader(
              kicker: 'Fontes',
              title: 'Provedores e referencias de preco',
              caption:
                  'Referencias comerciais ajudam a manter oferta, margem e disponibilidade mais consistentes.',
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: model.adminApiIntegrations
                  .map(
                    (String provider) => SizedBox(
                      width: 220,
                      child: ValleyPanel(
                        padding: const EdgeInsets.all(18),
                        glowColor: blueprint.supplierApis.contains(provider)
                            ? ValleyBrandColors.success
                            : ValleyBrandColors.cyan,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            SignalChip(
                              label: provider,
                              color: blueprint.supplierApis.contains(provider)
                                  ? ValleyBrandColors.success
                                  : ValleyBrandColors.cyan,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              blueprint.supplierApis.contains(provider)
                                  ? 'Fornecedor API'
                                  : 'Fonte de preco',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              blueprint.supplierApis.contains(provider)
                                  ? 'Importacao, custo, pedido e tracking.'
                                  : 'Benchmark competitivo para repricing e auto-pause.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 30),
            SectionHeader(
              kicker: 'Preco',
              title: 'Ciclo de decisao do pricing engine',
              caption:
                  'Cada ajuste protege margem, estoque e experiencia de compra.',
            ),
            const SizedBox(height: 18),
            Column(
              children: blueprint.requiredCapabilities
                  .map(
                    (String item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ValleyPanel(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: ValleyBrandColors.violet.withValues(
                                  alpha: 0.18,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: ValleyBrandColors.cyan,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _BusinessPage extends StatelessWidget {
  const _BusinessPage({required this.data});

  final ValleyAppData data;

  @override
  Widget build(BuildContext context) {
    final List<ModuleRecord> modules = data.recordsForCodes(<String>[
      'BUSINESS',
      'REPLY',
      'DOCS',
      'PLUG',
    ]);
    final PhaseRecord phase =
        data.phaseByKey('phase_1_core_activation') ??
        data.manifest.phases.first;

    return _PageFrame(
      child: FadeSlideIn(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SectionHeader(
              kicker: 'Negocios',
              title:
                  'ERP leve, compras, comprovacao e captura no mesmo backoffice',
              caption:
                  'Compras, estoque, documentos e pagamento aparecem em uma rotina empresarial simples.',
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: modules
                  .map(
                    (ModuleRecord module) => SizedBox(
                      width: 280,
                      child: HoverModuleTile(
                        code: module.code,
                        title: module.name,
                        subtitle: module.subtitle,
                        caption: module.description,
                        onTap: () => _showModuleActionSheet(
                          context,
                          code: module.code,
                          title: module.name,
                          subtitle: module.subtitle,
                          caption: module.description,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 30),
            ValleyPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    phase.goal,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 18,
                    runSpacing: 18,
                    children: phase.successGates
                        .map(
                          (String item) => SizedBox(
                            width: 260,
                            child: Text(
                              '• $item',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            SectionHeader(
              kicker: 'Rotinas',
              title: 'Fluxos empresariais que a interface prioriza',
              caption:
                  'Compras, fiscal, servicos e comprovantes ficam agrupados para decisao rapida.',
            ),
            const SizedBox(height: 18),
            const Wrap(
              spacing: 16,
              runSpacing: 16,
              children: <Widget>[
                SizedBox(
                  width: 320,
                  child: _TimelineTile(
                    step: '01',
                    title: 'Onboarding PJ',
                    body:
                        'Cadastro empresarial, documento, representacao legal e trilha minima para faturar.',
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: _TimelineTile(
                    step: '02',
                    title: 'Compra e estoque',
                    body:
                        'Reply fecha compras, Business consolida operacao e WMS recebe disponibilidade.',
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: _TimelineTile(
                    step: '03',
                    title: 'Fechamento e prova',
                    body:
                        'Plug captura, Docs prova e o core financeiro fecha o evento ponta a ponta.',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IdentityPage extends StatelessWidget {
  const _IdentityPage({required this.data});

  final ValleyAppData data;

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
      child: FadeSlideIn(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SectionHeader(
              kicker: 'Trust fabric',
              title:
                  'Face ID, Voice ID e Identity Score como camada transversal',
              caption:
                  'O Valley nao trata identidade como tela promocional. Aqui ela aparece como motor de confianca operacional.',
            ),
            const SizedBox(height: 18),
            ValleyPanel(
              glowColor: ValleyBrandColors.cyan,
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool stacked = constraints.maxWidth < 820;
                  return _ResponsiveSplit(
                    stacked: stacked,
                    gap: 24,
                    leading: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Identity score',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: ValleyBrandColors.cyan),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '92/100',
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                        const SizedBox(height: 10),
                        AnimatedReadinessBar(
                          value: 92,
                          color: ValleyBrandColors.cyan,
                          height: 10,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Score para onboarding de seller, pagamentos sensiveis e protecao antifraude.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                    trailing: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: const <Widget>[
                        SignalChip(
                          label: 'face id',
                          color: ValleyBrandColors.success,
                        ),
                        SignalChip(
                          label: 'voice id',
                          color: ValleyBrandColors.warning,
                        ),
                        SignalChip(
                          label: 'led card',
                          color: ValleyBrandColors.cyan,
                        ),
                        SignalChip(
                          label: 'risk aware',
                          color: ValleyBrandColors.violet,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 30),
            SectionHeader(
              kicker: 'Protecao',
              title: 'Identidade forte em cada jornada',
              caption:
                  'Biometria, reputacao e comprovacao ajudam a proteger pagamentos, vendedores e acessos.',
            ),
            const SizedBox(height: 18),
            Column(
              children: data.manifest.identityComponents
                  .map(
                    (IdentityComponent component) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: ValleyPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                SignalChip(
                                  label: component.label,
                                  color: ValleyBrandColors.violet,
                                ),
                                const SizedBox(width: 10),
                                const SignalChip(
                                  label: 'protegido',
                                  color: ValleyBrandColors.success,
                                  outlined: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              component.objective,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Usado em pagamentos, marketplace, documentos e acessos sensiveis.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelenaPage extends StatelessWidget {
  const _HelenaPage({required this.data});

  final ValleyAppData data;

  @override
  Widget build(BuildContext context) {
    final PhaseRecord phase =
        data.phaseByKey('phase_4_light_ai') ?? data.manifest.phases.last;
    final List<ModuleRecord> modules = data.recordsForCodes(<String>[
      'CHAT',
      'ADVISOR',
      'AGENDA',
    ]);

    return _PageFrame(
      child: FadeSlideIn(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SectionHeader(
              kicker: 'Helena',
              title:
                  'IA utilitaria, limitada por plano e orientada a produtividade',
              caption:
                  'Helena organiza contexto, agenda e recomendacoes para facilitar decisoes do dia a dia.',
              trailing: const SignalChip(
                label: 'assistente',
                color: ValleyBrandColors.success,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: modules
                  .map(
                    (ModuleRecord module) => SizedBox(
                      width: 300,
                      child: HoverModuleTile(
                        code: module.code,
                        title: module.name,
                        subtitle: module.subtitle,
                        caption: module.description,
                        onTap: () => _showModuleActionSheet(
                          context,
                          code: module.code,
                          title: module.name,
                          subtitle: module.subtitle,
                          caption: module.description,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 30),
            ValleyPanel(
              glowColor: ValleyBrandColors.violet,
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool stacked = constraints.maxWidth < 820;
                  return _ResponsiveSplit(
                    stacked: stacked,
                    gap: 24,
                    leading: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Exemplo de acao Helena',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '“Sua carteira empresarial ja tem PIX P2P, comprovante Docs e seller score. A proxima acao recomendada e ativar o marketplace com fornecedores confiaveis e preco protegido.”',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                height: 1.5,
                              ),
                        ),
                      ],
                    ),
                    trailing: ValleyPanel(
                      padding: const EdgeInsets.all(18),
                      background: LinearGradient(
                        colors: <Color>[
                          ValleyBrandColors.violet.withValues(alpha: 0.16),
                          ValleyBrandColors.night.withValues(alpha: 0.82),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Preferencias',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          ...phase.runtimeRules.map(
                            (String item) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                '• $item',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 30),
            SectionHeader(
              kicker: 'Agenda',
              title: 'Memoria util e recorrencia acionavel',
              caption:
                  'Compromissos, lembretes e acoes aparecem de forma simples para acompanhar a rotina.',
            ),
            const SizedBox(height: 18),
            const Wrap(
              spacing: 16,
              runSpacing: 16,
              children: <Widget>[
                SizedBox(
                  width: 320,
                  child: _AgendaTile(
                    title: '09:00 • Conferir fornecedores',
                    body:
                        'Revisar fornecedores principais e confirmar disponibilidade para ofertas ativas.',
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: _AgendaTile(
                    title: '11:30 • Verificar score',
                    body:
                        'Acompanhar identidade e reputacao para operacoes de seller e pagamentos.',
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: _AgendaTile(
                    title: '14:00 • Abrir commerce',
                    body:
                        'Organizar STOCK, WMS e MARKETPLACE para vendas com preco protegido.',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OrbitalCommandHero extends StatelessWidget {
  const _OrbitalCommandHero({
    required this.data,
    required this.homeModules,
    required this.onNavigate,
    required this.onOpenModule,
  });

  final ValleyAppData data;
  final List<ModuleRecord> homeModules;
  final ValueChanged<int> onNavigate;
  final ValueChanged<ModuleRecord> onOpenModule;

  @override
  Widget build(BuildContext context) {
    return ValleyPanel(
      padding: EdgeInsets.zero,
      radius: 34,
      glowColor: ValleyBrandColors.cyan,
      background: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xFF050414),
          Color(0xFF111044),
          Color(0xFF061B2A),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: Stack(
          children: <Widget>[
            Positioned.fill(child: CustomPaint(painter: _HeroOrbitPainter())),
            Positioned(
              right: -120,
              top: -120,
              child: _SoftOrb(
                color: ValleyBrandColors.cyan.withValues(alpha: 0.24),
                size: 320,
              ),
            ),
            Positioned(
              left: -140,
              bottom: -130,
              child: _SoftOrb(
                color: ValleyBrandColors.violet.withValues(alpha: 0.28),
                size: 360,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(26),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool stacked = constraints.maxWidth < 900;
                  return _ResponsiveSplit(
                    stacked: stacked,
                    leadingFlex: 6,
                    trailingFlex: 5,
                    gap: 28,
                    leading: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            const SignalChip(
                              label: 'modo premium',
                              color: ValleyBrandColors.cyan,
                            ),
                            SignalChip(
                              label: '${homeModules.length} modulos na home',
                              color: ValleyBrandColors.success,
                              outlined: true,
                            ),
                            SignalChip(
                              label: '${data.modules.length} no dock',
                              color: ValleyBrandColors.lilac,
                              outlined: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 700),
                          child: Text(
                            'Valley Orbit centraliza pagamentos, comercio e IA em uma experiencia premium.',
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(
                                  color: ValleyBrandColors.snow,
                                  fontSize: stacked ? 36 : 48,
                                  height: 0.98,
                                  letterSpacing: -1.6,
                                ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 620),
                          child: Text(
                            'Acesse carteira, marketplace, identidade e Helena com navegacao fluida no Android e na Web.',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: ValleyBrandColors.snow.withValues(
                                    alpha: 0.76,
                                  ),
                                ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: <Widget>[
                            FilledButton.icon(
                              onPressed: () => onNavigate(2),
                              icon: const Icon(Icons.storefront_rounded),
                              label: const Text('Abrir comercio'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => onNavigate(5),
                              icon: const Icon(Icons.auto_awesome_rounded),
                              label: const Text('Abrir Helena'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _HeroBriefingStrip(
                          principle:
                              'Seu ecossistema fica organizado em modulos claros, com acesso rapido e superficie unica.',
                          focus:
                              'Commerce, Pay, Docs, Business e Helena trabalham juntos para simplificar rotina, compra e operacao.',
                        ),
                      ],
                    ),
                    trailing: _OrbitModuleVisual(
                      modules: homeModules.isEmpty
                          ? data.includedModuleRecords
                          : homeModules,
                      onOpenModule: onOpenModule,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroBriefingStrip extends StatelessWidget {
  const _HeroBriefingStrip({required this.principle, required this.focus});

  final String principle;
  final String focus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Experiencia integrada',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: ValleyBrandColors.cyan,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            principle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: ValleyBrandColors.snow.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            focus,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: ValleyBrandColors.snow.withValues(alpha: 0.64),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrbitModuleVisual extends StatelessWidget {
  const _OrbitModuleVisual({required this.modules, required this.onOpenModule});

  final List<ModuleRecord> modules;
  final ValueChanged<ModuleRecord> onOpenModule;

  @override
  Widget build(BuildContext context) {
    final List<ModuleRecord> visibleModules = modules.take(8).toList();
    return AspectRatio(
      aspectRatio: 1.05,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double size = math.min(
            constraints.maxWidth,
            constraints.maxHeight,
          );
          final double radius = size * 0.34;
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Positioned.fill(
                child: CustomPaint(
                  painter: _OrbitDialPainter(count: visibleModules.length),
                ),
              ),
              Container(
                width: size * 0.42,
                height: size * 0.42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      ValleyBrandColors.cyan.withValues(alpha: 0.36),
                      ValleyBrandColors.violet.withValues(alpha: 0.18),
                      Colors.white.withValues(alpha: 0.04),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const ValleyLogoMark(size: 64, borderRadius: 20),
                    const SizedBox(height: 10),
                    Text(
                      'ORBIT',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: ValleyBrandColors.snow,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              for (int index = 0; index < visibleModules.length; index++)
                _OrbitModuleNode(
                  module: visibleModules[index],
                  angle:
                      (-math.pi / 2) +
                      (index * 2 * math.pi / visibleModules.length),
                  radius: radius,
                  onOpenModule: onOpenModule,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _OrbitModuleNode extends StatelessWidget {
  const _OrbitModuleNode({
    required this.module,
    required this.angle,
    required this.radius,
    required this.onOpenModule,
  });

  final ModuleRecord module;
  final double angle;
  final double radius;
  final ValueChanged<ModuleRecord> onOpenModule;

  @override
  Widget build(BuildContext context) {
    final Color accent = _moduleAccentFor(module);
    final Offset offset = Offset(
      math.cos(angle) * radius,
      math.sin(angle) * radius,
    );
    return Transform.translate(
      offset: offset,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => onOpenModule(module),
          child: Container(
            width: 78,
            height: 78,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ValleyBrandColors.night.withValues(alpha: 0.78),
              border: Border.all(color: accent.withValues(alpha: 0.72)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(alpha: 0.20),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(_moduleIconFor(module), color: accent, size: 22),
                const SizedBox(height: 5),
                Text(
                  module.code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: ValleyBrandColors.snow,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumSignalRibbon extends StatelessWidget {
  const _PremiumSignalRibbon({required this.data});

  final ValleyAppData data;

  @override
  Widget build(BuildContext context) {
    return ValleyPanel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      radius: 28,
      glowColor: ValleyBrandColors.violet,
      background: LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: <Color>[
          ValleyBrandColors.panelDarkStrong.withValues(alpha: 0.90),
          ValleyBrandColors.cosmic.withValues(alpha: 0.76),
          ValleyBrandColors.night.withValues(alpha: 0.92),
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: <Widget>[
          _RibbonMetric(
            label: 'Modulos',
            value: '${data.modules.length}',
            accent: ValleyBrandColors.violet,
          ),
          const _RibbonMetric(
            label: 'Carteira',
            value: 'Pay',
            accent: ValleyBrandColors.cyan,
          ),
          const _RibbonMetric(
            label: 'Helena',
            value: 'IA',
            accent: ValleyBrandColors.lilac,
          ),
          const _RibbonMetric(
            label: 'Plataforma',
            value: 'Web + APK',
            accent: ValleyBrandColors.success,
          ),
        ],
      ),
    );
  }
}

class _RibbonMetric extends StatelessWidget {
  const _RibbonMetric({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 9,
            height: 42,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.9,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: ValleyBrandColors.snow,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftOrb extends StatelessWidget {
  const _SoftOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

class _HeroOrbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (double y = size.height * 0.12; y < size.height; y += 42) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y - 36), linePaint);
    }

    final Paint arcPaint = Paint()
      ..color = ValleyBrandColors.cyan.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final Rect rect = Rect.fromCircle(
      center: Offset(size.width * 0.78, size.height * 0.46),
      radius: size.shortestSide * 0.44,
    );
    canvas.drawArc(rect, -0.9, 4.8, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OrbitDialPainter extends CustomPainter {
  const _OrbitDialPainter({required this.count});

  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double outerRadius = size.shortestSide * 0.38;
    final Paint ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final Paint activePaint = Paint()
      ..color = ValleyBrandColors.cyan.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, outerRadius, ringPaint);
    canvas.drawCircle(center, outerRadius * 0.62, ringPaint);

    final int safeCount = math.max(count, 1);
    for (int i = 0; i < safeCount; i++) {
      final double angle = -math.pi / 2 + (i * 2 * math.pi / safeCount);
      final Offset end = Offset(
        center.dx + math.cos(angle) * outerRadius,
        center.dy + math.sin(angle) * outerRadius,
      );
      canvas.drawLine(center, end, i.isEven ? activePaint : ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitDialPainter oldDelegate) {
    return oldDelegate.count != count;
  }
}

class _HomeModuleComposer extends StatelessWidget {
  const _HomeModuleComposer({
    required this.allModules,
    required this.homeModules,
    required this.visibleCodes,
    required this.preferencesReady,
    required this.onOpenModule,
    required this.onToggleHomeModule,
  });

  final List<ModuleRecord> allModules;
  final List<ModuleRecord> homeModules;
  final Set<String> visibleCodes;
  final bool preferencesReady;
  final ValueChanged<ModuleRecord> onOpenModule;
  final void Function(ModuleRecord module, bool selected) onToggleHomeModule;

  @override
  Widget build(BuildContext context) {
    return ValleyPanel(
      glowColor: ValleyBrandColors.cyan,
      background: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          ValleyBrandColors.cyan.withValues(alpha: 0.12),
          ValleyBrandColors.panelDarkStrong.withValues(alpha: 0.90),
          ValleyBrandColors.night.withValues(alpha: 0.96),
        ],
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool stacked = constraints.maxWidth < 900;
          return _ResponsiveSplit(
            stacked: stacked,
            leadingFlex: 7,
            trailingFlex: 5,
            gap: 22,
            leading: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                  Text(
                    'Na tela inicial',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    SignalChip(
                      label: preferencesReady ? 'salvo' : 'sincronizando',
                      color: preferencesReady
                          ? ValleyBrandColors.success
                          : ValleyBrandColors.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Toque em um modulo para abrir a area operacional. Use o seletor ao lado para compor uma home mais enxuta ou mais completa.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: homeModules
                      .map(
                        (ModuleRecord module) => SizedBox(
                          width: stacked ? double.infinity : 290,
                          child: _LaunchModuleTile(
                            module: module,
                            onOpenModule: onOpenModule,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
            trailing: ValleyPanel(
              padding: const EdgeInsets.all(18),
              radius: 22,
              glowColor: ValleyBrandColors.violet,
              background: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  ValleyBrandColors.violet.withValues(alpha: 0.14),
                  ValleyBrandColors.panelDark.withValues(alpha: 0.86),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Personalizar home',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Todos os modulos continuam no dock; estes chips controlam apenas o que aparece no corpo da home.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allModules.map((ModuleRecord module) {
                      final bool selected = visibleCodes.contains(module.code);
                      final Color accent = _moduleAccentFor(module);
                      return FilterChip(
                        selected: selected,
                        showCheckmark: true,
                        avatar: Icon(_moduleIconFor(module), size: 18),
                        label: Text(module.code),
                        onSelected: (bool value) =>
                            onToggleHomeModule(module, value),
                        selectedColor: accent.withValues(alpha: 0.24),
                        backgroundColor: ValleyBrandColors.night.withValues(
                          alpha: 0.42,
                        ),
                        checkmarkColor: ValleyBrandColors.snow,
                        side: BorderSide(
                          color: selected
                              ? accent.withValues(alpha: 0.66)
                              : Colors.white.withValues(alpha: 0.12),
                        ),
                        labelStyle: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: selected
                                  ? ValleyBrandColors.snow
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w800,
                            ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LaunchModuleTile extends StatefulWidget {
  const _LaunchModuleTile({required this.module, required this.onOpenModule});

  final ModuleRecord module;
  final ValueChanged<ModuleRecord> onOpenModule;

  @override
  State<_LaunchModuleTile> createState() => _LaunchModuleTileState();
}

class _LaunchModuleTileState extends State<_LaunchModuleTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color accent = _moduleAccentFor(widget.module);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.012 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: () => widget.onOpenModule(widget.module),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    accent.withValues(alpha: _hovered ? 0.20 : 0.12),
                    Colors.white.withValues(alpha: 0.045),
                    ValleyBrandColors.night.withValues(alpha: 0.54),
                  ],
                ),
                border: Border.all(
                  color: accent.withValues(alpha: _hovered ? 0.66 : 0.26),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent.withValues(alpha: 0.16),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.44),
                          ),
                        ),
                        child: Icon(
                          _moduleIconFor(widget.module),
                          color: accent,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        widget.module.code,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.module.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.module.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.module.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class _ModuleAccessDock extends StatelessWidget {
  const _ModuleAccessDock({
    required this.modules,
    required this.selectedCode,
    required this.onOpenModule,
  });

  final List<ModuleRecord> modules;
  final String? selectedCode;
  final ValueChanged<ModuleRecord> onOpenModule;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Colors.white.withValues(alpha: 0.10),
                ValleyBrandColors.panelDarkStrong.withValues(alpha: 0.82),
                ValleyBrandColors.night.withValues(alpha: 0.76),
              ],
            ),
            borderRadius: BorderRadius.circular(34),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: ValleyBrandColors.cyan.withValues(alpha: 0.13),
                blurRadius: 38,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.grid_view_rounded,
                color: ValleyBrandColors.cyan,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Dock',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: ValleyBrandColors.snow,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 1,
                height: 28,
                color: Colors.white.withValues(alpha: 0.16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: modules
                        .map(
                          (ModuleRecord module) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _ModuleDockPill(
                              module: module,
                              selected: selectedCode == module.code,
                              onOpenModule: onOpenModule,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleDockPill extends StatelessWidget {
  const _ModuleDockPill({
    required this.module,
    required this.selected,
    required this.onOpenModule,
  });

  final ModuleRecord module;
  final bool selected;
  final ValueChanged<ModuleRecord> onOpenModule;

  @override
  Widget build(BuildContext context) {
    final Color accent = _moduleAccentFor(module);
    return Tooltip(
      message: '${module.name}\n${module.description}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => onOpenModule(module),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: selected
                  ? accent.withValues(alpha: 0.24)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? accent.withValues(alpha: 0.72)
                    : Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  _moduleIconFor(module),
                  color: selected
                      ? ValleyBrandColors.snow
                      : accent.withValues(alpha: 0.92),
                  size: 16,
                ),
                const SizedBox(width: 7),
                Text(
                  module.code,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected
                        ? ValleyBrandColors.snow
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool compact = MediaQuery.sizeOf(context).width < 1040;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        compact ? 16 : 28,
        12,
        compact ? 16 : 28,
        compact ? 164 : 124,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1220),
          child: child,
        ),
      ),
    );
  }
}

class _ResponsiveSplit extends StatelessWidget {
  const _ResponsiveSplit({
    required this.stacked,
    required this.leading,
    required this.trailing,
    this.leadingFlex = 1,
    this.trailingFlex = 1,
    this.gap = 24,
  });

  final bool stacked;
  final Widget leading;
  final Widget trailing;
  final int leadingFlex;
  final int trailingFlex;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          leading,
          SizedBox(height: gap),
          trailing,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(flex: leadingFlex, child: leading),
        SizedBox(width: gap),
        Expanded(flex: trailingFlex, child: trailing),
      ],
    );
  }
}

Future<void> _showModuleActionSheet(
  BuildContext context, {
  required String code,
  required String title,
  required String subtitle,
  required String caption,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext modalContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ValleyPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    SignalChip(label: code, color: ValleyBrandColors.cyan),
                    const SizedBox(width: 10),
                    const SignalChip(
                      label: 'disponivel',
                      color: ValleyBrandColors.success,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: Theme.of(modalContext).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: Theme.of(modalContext).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  caption,
                  style: Theme.of(modalContext).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(modalContext).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Este modulo faz parte da experiencia Valley Premium para Android e Web.',
                  style: Theme.of(modalContext).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(modalContext).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    FilledButton(
                      onPressed: () => Navigator.of(modalContext).pop(),
                      child: const Text('Continuar'),
                    ),
                    OutlinedButton(
                      onPressed: () => Navigator.of(modalContext).pop(),
                      child: const Text('Fechar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.step,
    required this.title,
    required this.body,
  });

  final String step;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ValleyPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SignalChip(label: step, color: ValleyBrandColors.cyan),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerEventRow extends StatelessWidget {
  const _LedgerEventRow({
    required this.status,
    required this.title,
    required this.detail,
    required this.amount,
  });

  final String status;
  final String title;
  final String detail;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ValleyPanel(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SignalChip(
              label: status,
              color: status == 'SETTLED'
                  ? ValleyBrandColors.success
                  : status == 'AUTHORIZED'
                  ? ValleyBrandColors.cyan
                  : ValleyBrandColors.warning,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    detail,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              amount,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgendaTile extends StatelessWidget {
  const _AgendaTile({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ValleyPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Destination {
  const _Destination({
    required this.label,
    required this.title,
    required this.icon,
  });

  final String label;
  final String title;
  final IconData icon;
}
