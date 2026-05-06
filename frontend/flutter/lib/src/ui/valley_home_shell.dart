import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valley_super_app/src/data/product_api_models.dart';
import 'package:valley_super_app/src/data/product_api_repository.dart';
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

Color _homeMetricAccent(String accent) {
  switch (accent) {
    case 'success':
      return ValleyBrandColors.success;
    case 'warning':
      return ValleyBrandColors.warning;
    case 'violet':
      return ValleyBrandColors.violet;
    default:
      return ValleyBrandColors.cyan;
  }
}

Color _homeSignalAccent(String accent) => _homeMetricAccent(accent);

Color _journeyStageColor(String stage) {
  switch (stage) {
    case 'conversion':
      return ValleyBrandColors.success;
    case 'research':
      return ValleyBrandColors.cyan;
    case 'consideration':
      return ValleyBrandColors.violet;
    case 'failure':
      return ValleyBrandColors.warning;
    case 'discovery':
    default:
      return ValleyBrandColors.lilac;
  }
}

String _journeyStageLabel(String stage) {
  switch (stage) {
    case 'conversion':
      return 'conversao';
    case 'research':
      return 'analise';
    case 'consideration':
      return 'consideracao';
    case 'failure':
      return 'falha';
    case 'discovery':
      return 'descoberta';
    default:
      return stage.trim().isEmpty ? 'evento' : stage;
  }
}

class _JourneyGroup {
  const _JourneyGroup({required this.journeyKey, required this.trails});

  final String journeyKey;
  final List<UserModuleTrail> trails;

  UserModuleTrail get latest => trails.first;

  List<UserModuleTrail> get timeline {
    final List<UserModuleTrail> ordered = List<UserModuleTrail>.from(trails);
    ordered.sort(
      (UserModuleTrail a, UserModuleTrail b) =>
          a.createdAtUtc.compareTo(b.createdAtUtc),
    );
    return ordered;
  }

  List<String> get moduleCodes {
    final Set<String> seen = <String>{};
    final List<String> ordered = <String>[];
    for (final UserModuleTrail trail in timeline) {
      final String code = trail.moduleCode.trim().toUpperCase();
      if (code.isEmpty || !seen.add(code)) {
        continue;
      }
      ordered.add(code);
    }
    return ordered;
  }

  List<String> get stages {
    final Set<String> seen = <String>{};
    final List<String> ordered = <String>[];
    for (final UserModuleTrail trail in timeline) {
      final String stage = trail.journeyStage.trim().toLowerCase();
      if (stage.isEmpty || !seen.add(stage)) {
        continue;
      }
      ordered.add(stage);
    }
    return ordered;
  }
}

List<_JourneyGroup> _groupJourneyTrails(List<UserModuleTrail> trails) {
  final List<UserModuleTrail> sorted = List<UserModuleTrail>.from(trails)
    ..sort(
      (UserModuleTrail a, UserModuleTrail b) =>
          b.createdAtUtc.compareTo(a.createdAtUtc),
    );
  final Map<String, List<UserModuleTrail>> grouped =
      <String, List<UserModuleTrail>>{};
  for (final UserModuleTrail trail in sorted) {
    final String key = trail.journeyKey.trim().isNotEmpty
        ? trail.journeyKey.trim()
        : trail.trailId;
    grouped.putIfAbsent(key, () => <UserModuleTrail>[]).add(trail);
  }
  final List<_JourneyGroup> journeys = grouped.entries
      .map(
        (MapEntry<String, List<UserModuleTrail>> entry) =>
            _JourneyGroup(journeyKey: entry.key, trails: entry.value),
      )
      .toList(growable: false);
  journeys.sort(
    (_JourneyGroup a, _JourneyGroup b) =>
        b.latest.createdAtUtc.compareTo(a.latest.createdAtUtc),
  );
  return journeys;
}

ModuleRecord? _resolveJourneyPrimaryModule(
  _JourneyGroup journey,
  List<ModuleRecord> catalogModules,
) {
  final Map<String, ModuleRecord> modulesByCode = <String, ModuleRecord>{
    for (final ModuleRecord module in catalogModules) module.code: module,
  };
  final String latestStage = journey.latest.journeyStage.trim().toLowerCase();
  final List<String> preferredCodes;
  switch (latestStage) {
    case 'conversion':
      preferredCodes = const <String>['PAY', 'MARKETPLACE', 'STOCK'];
      break;
    case 'research':
      preferredCodes = const <String>['MARKETPLACE', 'STOCK', 'PAY'];
      break;
    case 'consideration':
      preferredCodes = const <String>['MARKETPLACE', 'STOCK', 'PAY'];
      break;
    case 'failure':
      preferredCodes = const <String>['PAY', 'STOCK', 'MARKETPLACE'];
      break;
    case 'discovery':
    default:
      preferredCodes = const <String>['STOCK', 'MARKETPLACE', 'PAY'];
      break;
  }

  for (final String code in preferredCodes) {
    if (journey.moduleCodes.contains(code) && modulesByCode.containsKey(code)) {
      return modulesByCode[code];
    }
  }

  for (final UserModuleTrail trail in journey.timeline.reversed) {
    final ModuleRecord? module = modulesByCode[trail.moduleCode];
    if (module != null) {
      return module;
    }
  }
  return null;
}

class ValleyHomeShell extends StatefulWidget {
  const ValleyHomeShell({
    super.key,
    required this.data,
    this.repository = const ProductApiRepository(),
  });

  final ValleyAppData data;
  final ProductApiRepository repository;

  @override
  State<ValleyHomeShell> createState() => _ValleyHomeShellState();
}

class _ValleyHomeShellState extends State<ValleyHomeShell> {
  int _index = 0;
  Set<String> _homeModuleCodes = <String>{};
  bool _modulePreferencesReady = false;
  String? _selectedDockModuleCode;
  late final TextEditingController _searchController;
  String _searchQuery = '';
  ProductHomeData? _remoteHomeData;
  bool _remoteHomeLoading = false;
  String _remoteHomeStatus = '';

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
    _searchController = TextEditingController();
    _homeModuleCodes = _defaultHomeModuleCodes();
    unawaited(_loadHomeModulePreferences());
    unawaited(_loadRemoteHomeData());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    try {
      final HomePreferences remotePreferences = await widget.repository
          .saveHomePreferences(
            visibleModuleCodes: sortedCodes,
            favoriteModuleCodes: sortedCodes.take(4).toList(growable: false),
          );
      if (!mounted) {
        return;
      }
      setState(() {
        final ProductHomeData? current = _remoteHomeData;
        if (current != null) {
          _remoteHomeData = ProductHomeData(
            ok: current.ok,
            anonymous: current.anonymous,
            persistable: current.persistable,
            fetchedAtUtc: current.fetchedAtUtc,
            profileContext: current.profileContext,
            preferences: remotePreferences,
            recentActions: current.recentActions,
            recommendations: current.recommendations,
            identityScore: current.identityScore,
            metrics: current.metrics,
            moduleSignals: current.moduleSignals,
            userModuleTrails: current.userModuleTrails,
          );
        }
        _remoteHomeStatus = '';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _remoteHomeStatus =
            'Persistencia remota indisponivel; fallback local mantido.';
      });
    }
  }

  Future<void> _loadRemoteHomeData() async {
    setState(() {
      _remoteHomeLoading = true;
      _remoteHomeStatus = '';
    });
    try {
      final ProductHomeData remoteHome = await widget.repository.loadHome();
      final Set<String> validCodes = widget.data.modules
          .map((ModuleRecord module) => module.code)
          .toSet();
      final Set<String> remoteCodes = remoteHome.preferences.visibleModuleCodes
          .where((String code) => validCodes.contains(code))
          .toSet();
      if (!mounted) {
        return;
      }
      setState(() {
        _remoteHomeData = remoteHome;
        if (remoteCodes.isNotEmpty) {
          _homeModuleCodes = remoteCodes;
        }
        _modulePreferencesReady = true;
        _remoteHomeLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _remoteHomeLoading = false;
        _remoteHomeStatus =
            'API /me/* indisponivel; home segue com cache local.';
      });
    }
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

  ModuleRecord? _findModuleByCode(String code) {
    for (final ModuleRecord module in widget.data.modules) {
      if (module.code == code) {
        return module;
      }
    }
    return null;
  }

  Future<void> _showJourneyRuntimeResult({
    required String title,
    required String message,
    required String url,
  }) async {
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext modalContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ValleyPanel(
              glowColor: ValleyBrandColors.success,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SignalChip(
                    label: 'acao concluida',
                    color: ValleyBrandColors.success,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: Theme.of(modalContext).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    style: Theme.of(modalContext).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(
                        modalContext,
                      ).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (url.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 14),
                    SelectableText(
                      url,
                      style: Theme.of(modalContext).textTheme.bodyMedium
                          ?.copyWith(color: ValleyBrandColors.cyan),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () => Navigator.of(modalContext).pop(),
                    child: const Text('Fechar'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showJourneyEventSheet(
    UserModuleTrail trail, {
    required ModuleRecord? primaryModule,
  }) async {
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext modalContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ValleyPanel(
              glowColor: _journeyStageColor(trail.journeyStage.toLowerCase()),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      SignalChip(
                        label: trail.moduleCode,
                        color: _journeyStageColor(
                          trail.journeyStage.toLowerCase(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SignalChip(
                        label: _journeyStageLabel(
                          trail.journeyStage.toLowerCase(),
                        ),
                        color: ValleyBrandColors.cyan,
                        outlined: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    trail.headline,
                    style: Theme.of(modalContext).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    trail.detail,
                    style: Theme.of(modalContext).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(
                        modalContext,
                      ).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (trail.itemTitle.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      'Oferta: ${trail.itemTitle}',
                      style: Theme.of(modalContext).textTheme.labelLarge
                          ?.copyWith(color: ValleyBrandColors.cyan),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      if (primaryModule != null)
                        FilledButton(
                          onPressed: () {
                            Navigator.of(modalContext).pop();
                            _openModule(primaryModule);
                          },
                          child: Text('Abrir ${primaryModule.code}'),
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

  Future<void> _handleJourneyEventTap(
    UserModuleTrail trail,
    ModuleRecord? primaryModule,
  ) async {
    final String actionPath = trail.primaryActionPath.trim();
    if (actionPath.isNotEmpty) {
      try {
        final ProductActionResult result = await widget.repository.invokePath(
          baseUrl: '',
          path: actionPath,
        );
        if (!mounted) {
          return;
        }
        if (result.ok) {
          await _showJourneyRuntimeResult(
            title: trail.headline,
            message: result.message,
            url: result.url,
          );
          return;
        }
      } catch (_) {}
    }

    final ModuleRecord? fallbackModule =
        primaryModule ??
        _findModuleByCode(trail.openModuleCode) ??
        _findModuleByCode(trail.moduleCode);
    await _showJourneyEventSheet(trail, primaryModule: fallbackModule);
  }

  Future<void> _handleHomeActionTap({
    required String title,
    required String actionPath,
    required String openModuleCode,
    required String fallbackModuleCode,
  }) async {
    final String resolvedActionPath = actionPath.trim();
    if (resolvedActionPath.isNotEmpty) {
      try {
        final ProductActionResult result = await widget.repository.invokePath(
          baseUrl: '',
          path: resolvedActionPath,
        );
        if (!mounted) {
          return;
        }
        if (result.ok) {
          await _showJourneyRuntimeResult(
            title: title,
            message: result.message,
            url: result.url,
          );
          return;
        }
      } catch (_) {}
    }

    final ModuleRecord? module =
        _findModuleByCode(openModuleCode) ??
        _findModuleByCode(fallbackModuleCode);
    if (module != null) {
      _openModule(module);
    }
  }

  void _handleSearchChanged(String value) {
    setState(() {
      _searchQuery = value.trim();
    });
  }

  List<ModuleRecord> _filteredModules() {
    final String normalizedQuery = _searchQuery.toLowerCase().trim();
    final List<ModuleRecord> sortedModules = List<ModuleRecord>.from(
      widget.data.modules,
    )..sort((ModuleRecord a, ModuleRecord b) => a.number.compareTo(b.number));

    if (normalizedQuery.isEmpty) {
      return sortedModules;
    }

    return sortedModules.where((ModuleRecord module) {
      final String haystack = <String>[
        module.code,
        module.name,
        module.subtitle,
        module.domain,
        module.description,
      ].join(' ').toLowerCase();
      return haystack.contains(normalizedQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bool wide = MediaQuery.sizeOf(context).width >= 1040;
    final List<ModuleRecord> filteredModules = _filteredModules();
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
                        _CommandTopBar(
                          title: _destinations[_index].title,
                          searchController: _searchController,
                          searchQuery: _searchQuery,
                          resultCount: filteredModules.length,
                          totalCount: widget.data.modules.length,
                          onSearchChanged: _handleSearchChanged,
                          onClearSearch: () {
                            _searchController.clear();
                            _handleSearchChanged('');
                          },
                          onNavigate: _navigate,
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
                  modules: filteredModules,
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
          catalogModules: _filteredModules(),
          searchQuery: _searchQuery,
          homeModuleCodes: _homeModuleCodes,
          preferencesReady: _modulePreferencesReady,
          remoteHomeData: _remoteHomeData,
          remoteHomeLoading: _remoteHomeLoading,
          remoteHomeStatus: _remoteHomeStatus,
          onNavigate: _navigate,
          onOpenModule: _openModule,
          onOpenJourneyEvent: _handleJourneyEventTap,
          onOpenHomeAction: _handleHomeActionTap,
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
          catalogModules: _filteredModules(),
          searchQuery: _searchQuery,
          homeModuleCodes: _homeModuleCodes,
          preferencesReady: _modulePreferencesReady,
          remoteHomeData: _remoteHomeData,
          remoteHomeLoading: _remoteHomeLoading,
          remoteHomeStatus: _remoteHomeStatus,
          onNavigate: _navigate,
          onOpenModule: _openModule,
          onOpenJourneyEvent: _handleJourneyEventTap,
          onOpenHomeAction: _handleHomeActionTap,
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

class _CommandTopBar extends StatelessWidget {
  const _CommandTopBar({
    required this.title,
    required this.searchController,
    required this.searchQuery,
    required this.resultCount,
    required this.totalCount,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onNavigate,
  });

  final String title;
  final TextEditingController searchController;
  final String searchQuery;
  final int resultCount;
  final int totalCount;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final bool compact = MediaQuery.sizeOf(context).width < 920;
    final bool searchActive = searchQuery.isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 16 : 28, 18, compact ? 16 : 28, 8),
      child: ValleyPanel(
        padding: const EdgeInsets.all(18),
        radius: 32,
        glowColor: ValleyBrandColors.cyan,
        background: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Colors.white.withValues(alpha: 0.08),
            ValleyBrandColors.panelDarkStrong.withValues(alpha: 0.90),
            ValleyBrandColors.night.withValues(alpha: 0.86),
          ],
        ),
        child: Column(
          children: <Widget>[
            _ResponsiveSplit(
              stacked: compact,
              gap: 16,
              leadingFlex: 6,
              trailingFlex: 7,
              leading: Row(
                children: <Widget>[
                  const ValleyLogoMark(size: 52, borderRadius: 16),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          searchActive
                              ? '$resultCount resultados prontos para abrir'
                              : 'Experiencia premium, modular e pronta para uso.',
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
                ],
              ),
              trailing: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      onChanged: onSearchChanged,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Buscar modulos, jornadas e recursos',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: searchActive
                            ? IconButton(
                                onPressed: onClearSearch,
                                icon: const Icon(Icons.close_rounded),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _TopBarIconButton(
                    icon: Icons.notifications_none_rounded,
                    label: 'Alertas',
                  ),
                  const SizedBox(width: 8),
                  _TopBarIconButton(icon: Icons.tune_rounded, label: 'Atalhos'),
                  const SizedBox(width: 8),
                  const _ProfileBadge(),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                SignalChip(
                  label: searchActive
                      ? '$resultCount de $totalCount visiveis'
                      : '$totalCount modulos conectados',
                  color: searchActive
                      ? ValleyBrandColors.cyan
                      : ValleyBrandColors.success,
                ),
                const SignalChip(
                  label: 'modo usuario',
                  color: ValleyBrandColors.violet,
                ),
                const SignalChip(
                  label: 'sem superficies tecnicas',
                  color: ValleyBrandColors.warning,
                ),
                _QuickActionPill(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Carteira',
                  onTap: () => onNavigate(1),
                ),
                _QuickActionPill(
                  icon: Icons.storefront_rounded,
                  label: 'Marketplace',
                  onTap: () => onNavigate(2),
                ),
                _QuickActionPill(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Helena',
                  onTap: () => onNavigate(5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBarIconButton extends StatelessWidget {
  const _TopBarIconButton({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Icon(icon, color: ValleyBrandColors.snow),
      ),
    );
  }
}

class _ProfileBadge extends StatelessWidget {
  const _ProfileBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ValleyBrandColors.violet.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ValleyBrandColors.violet.withValues(alpha: 0.34),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  ValleyBrandColors.cyan.withValues(alpha: 0.92),
                  ValleyBrandColors.violet.withValues(alpha: 0.92),
                ],
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              'AN',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: ValleyBrandColors.snow,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Anderson',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                'Produto ativo',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionPill extends StatelessWidget {
  const _QuickActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 16, color: ValleyBrandColors.cyan),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: ValleyBrandColors.snow,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewPage extends StatelessWidget {
  const _OverviewPage({
    required this.data,
    required this.catalogModules,
    required this.searchQuery,
    required this.homeModuleCodes,
    required this.preferencesReady,
    required this.remoteHomeData,
    required this.remoteHomeLoading,
    required this.remoteHomeStatus,
    required this.onNavigate,
    required this.onOpenModule,
    required this.onOpenJourneyEvent,
    required this.onOpenHomeAction,
    required this.onToggleHomeModule,
  });

  final ValleyAppData data;
  final List<ModuleRecord> catalogModules;
  final String searchQuery;
  final Set<String> homeModuleCodes;
  final bool preferencesReady;
  final ProductHomeData? remoteHomeData;
  final bool remoteHomeLoading;
  final String remoteHomeStatus;
  final ValueChanged<int> onNavigate;
  final ValueChanged<ModuleRecord> onOpenModule;
  final Future<void> Function(
    UserModuleTrail trail,
    ModuleRecord? primaryModule,
  )
  onOpenJourneyEvent;
  final Future<void> Function({
    required String title,
    required String actionPath,
    required String openModuleCode,
    required String fallbackModuleCode,
  })
  onOpenHomeAction;
  final void Function(ModuleRecord module, bool selected) onToggleHomeModule;

  @override
  Widget build(BuildContext context) {
    final bool searchActive = searchQuery.isNotEmpty;
    final List<ModuleRecord> homeModules =
        catalogModules
            .where(
              (ModuleRecord module) => homeModuleCodes.contains(module.code),
            )
            .toList()
          ..sort(
            (ModuleRecord a, ModuleRecord b) => a.number.compareTo(b.number),
          );
    final List<HomeMetricCard> metrics =
        remoteHomeData?.metrics ?? const <HomeMetricCard>[];
    final List<HomeRecommendation> recommendations =
        remoteHomeData?.recommendations ?? const <HomeRecommendation>[];
    final List<HomeRecentAction> recentActions =
        remoteHomeData?.recentActions ?? const <HomeRecentAction>[];
    final IdentityScoreData? identityScore = remoteHomeData?.identityScore;
    final HomeProfileContext? profileContext = remoteHomeData?.profileContext;
    final List<HomeModuleSignal> moduleSignals =
        remoteHomeData?.moduleSignals ?? const <HomeModuleSignal>[];
    final List<UserModuleTrail> userModuleTrails =
        remoteHomeData?.userModuleTrails ?? const <UserModuleTrail>[];
    final List<_JourneyGroup> journeyGroups = _groupJourneyTrails(
      userModuleTrails,
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
              title: searchActive
                  ? 'Resultados para "$searchQuery"'
                  : 'Escolha quais modulos aparecem na tela inicial',
              caption: searchActive
                  ? 'A busca reduz ruido visual e destaca os modulos mais relevantes para a sua proxima acao.'
                  : 'A selecao fica salva no aparelho e o dock inferior mantem acesso rapido a todo o ecossistema.',
              trailing: SignalChip(
                label:
                    '${homeModules.length}/${catalogModules.length} visiveis',
                color: preferencesReady
                    ? ValleyBrandColors.success
                    : ValleyBrandColors.warning,
              ),
            ),
            const SizedBox(height: 18),
            _HomeModuleComposer(
              allModules: catalogModules,
              homeModules: homeModules,
              visibleCodes: homeModuleCodes,
              preferencesReady: preferencesReady,
              searchQuery: searchQuery,
              onOpenModule: onOpenModule,
              onToggleHomeModule: onToggleHomeModule,
            ),
            const SizedBox(height: 32),
            SectionHeader(
              kicker: 'Home API',
              title: 'Sinais personalizados da camada /me/*',
              caption: remoteHomeLoading
                  ? 'Sincronizando score, recomendacoes e acoes recentes do backend.'
                  : remoteHomeStatus.isNotEmpty
                  ? remoteHomeStatus
                  : remoteHomeData?.persistable == true
                  ? 'Preferencias, recomendacoes e identidade agora saem da API autenticada.'
                  : 'Sem sessao autenticada, a home usa dados basicos e fallback local.',
              trailing: SignalChip(
                label: remoteHomeLoading
                    ? 'syncing'
                    : remoteHomeData?.persistable == true
                    ? 'api live'
                    : 'local fallback',
                color: remoteHomeLoading
                    ? ValleyBrandColors.warning
                    : remoteHomeData?.persistable == true
                    ? ValleyBrandColors.success
                    : ValleyBrandColors.cyan,
              ),
            ),
            const SizedBox(height: 18),
            if (profileContext != null) ...<Widget>[
              ValleyPanel(
                glowColor: ValleyBrandColors.violet,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        SignalChip(
                          label: profileContext.roleLabel,
                          color: ValleyBrandColors.violet,
                        ),
                        const SizedBox(width: 10),
                        SignalChip(
                          label: profileContext.audienceKey,
                          color: ValleyBrandColors.cyan,
                          outlined: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      profileContext.focusTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      profileContext.focusCaption,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (profileContext
                        .preferredModuleCodes
                        .isNotEmpty) ...<Widget>[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: profileContext.preferredModuleCodes
                            .take(5)
                            .map(
                              (String code) => SignalChip(
                                label: code,
                                color: ValleyBrandColors.success,
                                outlined: true,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children:
                  (metrics.isNotEmpty
                          ? metrics.take(3).toList(growable: false)
                          : <HomeMetricCard>[
                              const HomeMetricCard(
                                label: 'Modulos visiveis',
                                value: '0',
                                caption:
                                    'A home segue operacional mesmo sem API.',
                                accent: 'cyan',
                              ),
                              const HomeMetricCard(
                                label: 'Acoes recentes',
                                value: '0',
                                caption:
                                    'Eventos reais entram quando a sessao e o backend estiverem ativos.',
                                accent: 'success',
                              ),
                              const HomeMetricCard(
                                label: 'Identity score',
                                value: '58',
                                caption:
                                    'Score base local ate a autenticacao do usuario.',
                                accent: 'warning',
                              ),
                            ])
                      .map(
                        (HomeMetricCard metric) => SizedBox(
                          width: 320,
                          child: MetricTile(
                            label: metric.label,
                            value: metric.value,
                            caption: metric.caption,
                            accent: _homeMetricAccent(metric.accent),
                          ),
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 30),
            if (moduleSignals.isNotEmpty) ...<Widget>[
              SectionHeader(
                kicker: 'Por modulo',
                title: 'Sinais operacionais por superficie',
                caption:
                    'A home agora mostra o recorte do runtime por modulo e por perfil, em vez de um feed unico sem contexto.',
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: moduleSignals
                    .take(4)
                    .map(
                      (HomeModuleSignal signal) => SizedBox(
                        width: 320,
                        child: ValleyPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  SignalChip(
                                    label: signal.moduleCode,
                                    color: _homeSignalAccent(signal.accent),
                                  ),
                                  const SizedBox(width: 10),
                                  SignalChip(
                                    label: signal.status,
                                    color: signal.status == 'positive'
                                        ? ValleyBrandColors.success
                                        : signal.status == 'attention'
                                        ? ValleyBrandColors.warning
                                        : ValleyBrandColors.violet,
                                    outlined: signal.status != 'positive',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(
                                signal.headline,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                signal.detail,
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
            ],
            if (journeyGroups.isNotEmpty) ...<Widget>[
              SectionHeader(
                kicker: 'Por jornada',
                title: 'Timeline comercial por objetivo',
                caption:
                    'A home agrupa eventos reais por journey key, mostrando como STOCK, MARKETPLACE e PAY se conectam na mesma trilha do usuario.',
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: journeyGroups.take(3).map((_JourneyGroup journey) {
                  final ModuleRecord? primaryModule =
                      _resolveJourneyPrimaryModule(journey, catalogModules);
                  final String stage = journey.latest.journeyStage
                      .toLowerCase();
                  final Color stageColor = _journeyStageColor(stage);
                  return SizedBox(
                    width: 420,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(30),
                        onTap: primaryModule == null
                            ? null
                            : () => onOpenModule(primaryModule),
                        child: ValleyPanel(
                          glowColor: stageColor,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  SignalChip(
                                    label: journey.latest.moduleCode,
                                    color: stageColor,
                                  ),
                                  const SizedBox(width: 10),
                                  SignalChip(
                                    label: _journeyStageLabel(stage),
                                    color: stageColor,
                                    outlined: true,
                                  ),
                                  const Spacer(),
                                  if (primaryModule != null)
                                    SignalChip(
                                      label:
                                          'abrir ${primaryModule.code.toLowerCase()}',
                                      color: ValleyBrandColors.success,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(
                                journey.latest.itemTitle.trim().isNotEmpty
                                    ? journey.latest.itemTitle
                                    : journey.latest.headline,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                journey.latest.detail,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              if (primaryModule != null) ...<Widget>[
                                const SizedBox(height: 12),
                                Text(
                                  'Modulo dominante: ${primaryModule.name}',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: ValleyBrandColors.cyan,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: journey.moduleCodes
                                    .map(
                                      (String code) => SignalChip(
                                        label: code,
                                        color: ValleyBrandColors.cyan,
                                        outlined: true,
                                      ),
                                    )
                                    .toList(),
                              ),
                              if (journey.stages.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: journey.stages
                                      .map(
                                        (String itemStage) => SignalChip(
                                          label: _journeyStageLabel(itemStage),
                                          color: _journeyStageColor(itemStage),
                                          outlined: itemStage != stage,
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                              const SizedBox(height: 18),
                              Column(
                                children: journey.timeline.reversed
                                    .take(3)
                                    .map(
                                      (UserModuleTrail trail) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            onTap: () => unawaited(
                                              onOpenJourneyEvent(
                                                trail,
                                                primaryModule,
                                              ),
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                    vertical: 6,
                                                  ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: <Widget>[
                                                  Container(
                                                    width: 10,
                                                    height: 10,
                                                    margin:
                                                        const EdgeInsets.only(
                                                          top: 6,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: _journeyStageColor(
                                                        trail.journeyStage
                                                            .toLowerCase(),
                                                      ),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: <Widget>[
                                                        Text(
                                                          '${trail.moduleCode} • ${trail.headline}',
                                                          style: Theme.of(context)
                                                              .textTheme
                                                              .labelLarge
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Text(
                                                          trail.detail,
                                                          style: Theme.of(context)
                                                              .textTheme
                                                              .bodySmall
                                                              ?.copyWith(
                                                                color: Theme.of(context)
                                                                    .colorScheme
                                                                    .onSurfaceVariant,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Icon(
                                                    Icons.open_in_new_rounded,
                                                    size: 18,
                                                    color:
                                                        ValleyBrandColors.cyan,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 30),
            ],
            if (identityScore != null) ...<Widget>[
              ValleyPanel(
                glowColor: ValleyBrandColors.cyan,
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final bool stacked = constraints.maxWidth < 860;
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
                            '${identityScore.score}/100',
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                          const SizedBox(height: 10),
                          AnimatedReadinessBar(
                            value: identityScore.score.toDouble(),
                            color: ValleyBrandColors.cyan,
                            height: 10,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            identityScore.summary,
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
                        children: identityScore.signals
                            .take(4)
                            .map(
                              (IdentitySignal signal) => SignalChip(
                                label: signal.name,
                                color: signal.status == 'positive'
                                    ? ValleyBrandColors.success
                                    : signal.status == 'attention'
                                    ? ValleyBrandColors.warning
                                    : ValleyBrandColors.violet,
                                outlined: signal.status != 'positive',
                              ),
                            )
                            .toList(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 30),
            ],
            if (recommendations.isNotEmpty) ...<Widget>[
              SectionHeader(
                kicker: 'Recomendacoes',
                title: 'Proximas acoes sugeridas',
                caption:
                    'A home recomenda a proxima melhor acao com base em modulos visiveis, identidade e operacao recente.',
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: recommendations
                    .take(3)
                    .map(
                      (HomeRecommendation recommendation) => SizedBox(
                        width: 320,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(28),
                            onTap: () => unawaited(
                              onOpenHomeAction(
                                title: recommendation.title,
                                actionPath: recommendation.actionPath,
                                openModuleCode: recommendation.openModuleCode,
                                fallbackModuleCode: recommendation.moduleCode,
                              ),
                            ),
                            child: ValleyPanel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  SignalChip(
                                    label: recommendation.priority,
                                    color: recommendation.priority == 'high'
                                        ? ValleyBrandColors.warning
                                        : ValleyBrandColors.violet,
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    recommendation.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    recommendation.subtitle,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    '${recommendation.actionLabel} • ${recommendation.moduleCode}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: ValleyBrandColors.cyan,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 30),
            ],
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
            if (recentActions.isNotEmpty) ...<Widget>[
              SectionHeader(
                kicker: 'Recentes',
                title: 'Acoes recentes da conta',
                caption:
                    'Feed sintetizado de autenticacao, interacoes comerciais e checkpoints operacionais.',
              ),
              const SizedBox(height: 18),
              ...recentActions
                  .take(4)
                  .map(
                    (HomeRecentAction action) => _LedgerEventRow(
                      status: action.status,
                      title: action.moduleCode.trim().isEmpty
                          ? action.title
                          : '${action.moduleCode} • ${action.title}',
                      detail: action.detail,
                      amount: action.amountLabel,
                      onTap: () => unawaited(
                        onOpenHomeAction(
                          title: action.title,
                          actionPath: action.actionPath,
                          openModuleCode: action.openModuleCode,
                          fallbackModuleCode: action.moduleCode,
                        ),
                      ),
                    ),
                  ),
              const SizedBox(height: 20),
            ],
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
                                  letterSpacing: 0,
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
    required this.searchQuery,
    required this.onOpenModule,
    required this.onToggleHomeModule,
  });

  final List<ModuleRecord> allModules;
  final List<ModuleRecord> homeModules;
  final Set<String> visibleCodes;
  final bool preferencesReady;
  final String searchQuery;
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
                  searchQuery.isNotEmpty
                      ? 'A busca ativa organiza a home em torno do que voce quer resolver agora, sem esconder o restante do ecossistema.'
                      : 'Toque em um modulo para abrir a area operacional. Use o seletor ao lado para compor uma home mais enxuta ou mais completa.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                if (homeModules.isEmpty)
                  ValleyPanel(
                    padding: const EdgeInsets.all(20),
                    radius: 24,
                    glowColor: ValleyBrandColors.warning,
                    background: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        ValleyBrandColors.warning.withValues(alpha: 0.10),
                        ValleyBrandColors.panelDark.withValues(alpha: 0.88),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const SignalChip(
                          label: 'ajuste rapido',
                          color: ValleyBrandColors.warning,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Nenhum modulo selecionado corresponde a esta busca.',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Refine o termo, abra um modulo pelo dock ou marque novos modulos no seletor ao lado para trazer esse fluxo para a home.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  )
                else
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
                    searchQuery.isNotEmpty
                        ? 'O seletor acompanha a busca atual para voce editar apenas os modulos mais relevantes neste momento.'
                        : 'Todos os modulos continuam no dock; estes chips controlam apenas o que aparece no corpo da home.',
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
                      child: const Text('Entendi'),
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
    this.onTap,
  });

  final String status;
  final String title;
  final String detail;
  final String amount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
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
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
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
