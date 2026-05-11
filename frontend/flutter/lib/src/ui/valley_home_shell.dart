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

/// Retorna o índice de destino da navegação inferior para um determinado código de módulo.
///
/// Este método mapeia códigos de módulos específicos para índices de destino
/// na barra de navegação inferior, agrupando módulos relacionados sob um único destino.
/// Se o código do módulo não corresponder a nenhum grupo predefinido, retorna 0 (Início).
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

/// Retorna o ícone apropriado para um módulo com base em seu código.
///
/// Este método associa um [IconData] a cada módulo, utilizando ícones
/// que representam visualmente a funcionalidade principal do módulo.
/// Para módulos sem um ícone específico, um ícone padrão é retornado.
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

/// Retorna a cor de destaque para um módulo com base em seu nível (tier).
///
/// As cores são definidas para diferenciar visualmente os módulos por sua importância
/// ou fase no ecossistema Valley (foundation, core, frontier).
/// Módulos sem um tier específico recebem uma cor de sucesso padrão.
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

/// Retorna a cor de destaque para uma métrica da home com base em seu tipo.
///
/// Este método padroniza as cores de destaque para métricas,
/// associando 'success', 'warning' e 'violet' a cores específicas da marca Valley.
/// Qualquer outra string de destaque resulta na cor ciano padrão.
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

/// Retorna a cor de destaque para um sinal da home, delegando para [_homeMetricAccent].
///
/// Garante consistência na aplicação de cores para sinais e métricas.
Color _homeSignalAccent(String accent) => _homeMetricAccent(accent);

/// Retorna a cor de destaque para um estágio de jornada do usuário.
///
/// Cores são atribuídas a diferentes estágios da jornada (conversão, pesquisa, etc.)
/// para facilitar a identificação visual do progresso ou estado de uma jornada.
/// Estágios não mapeados recebem uma cor lilás padrão.
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

/// Retorna um rótulo legível para um estágio de jornada do usuário.
///
/// Converte os códigos internos dos estágios da jornada em termos mais amigáveis
/// para exibição na interface do usuário.
/// Estágios vazios ou não reconhecidos são rotulados como 'evento'.
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

/// Representa um grupo de trilhas de usuário relacionadas a uma jornada específica.
///
/// Agrupa múltiplas [UserModuleTrail] sob uma única chave de jornada,
/// fornecendo acesso fácil à trilha mais recente, à linha do tempo completa,
/// aos códigos de módulos envolvidos e aos estágios da jornada.
class _JourneyGroup {
  const _JourneyGroup({required this.journeyKey, required this.trails});

  /// A chave única que identifica esta jornada.
  final String journeyKey;

  /// A lista de trilhas de módulos de usuário associadas a esta jornada.
  final List<UserModuleTrail> trails;

  /// Retorna a trilha de módulo mais recente neste grupo.
  UserModuleTrail get latest => trails.first;

  List<UserModuleTrail> get timeline {
    final List<UserModuleTrail> ordered = List<UserModuleTrail>.from(trails);
    ordered.sort(
      (UserModuleTrail a, UserModuleTrail b) =>
          a.createdAtUtc.compareTo(b.createdAtUtc),
    );
    return ordered;
  }

  /// Retorna uma lista ordenada dos códigos de módulos únicos envolvidos nesta jornada.
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

  /// Retorna uma lista ordenada dos estágios únicos da jornada presentes nas trilhas.
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

/// Agrupa uma lista de [UserModuleTrail] em [List<_JourneyGroup>].
///
/// As trilhas são agrupadas por sua [UserModuleTrail.journeyKey] e, em seguida,
/// cada grupo é ordenado pela data de criação da trilha mais recente.
/// Isso permite visualizar jornadas completas e seu progresso.
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

/// Resolve o módulo primário para uma [_JourneyGroup] com base no estágio mais recente.
///
/// Este método tenta identificar o módulo mais relevante para uma jornada,
/// priorizando módulos específicos para cada estágio (conversão, pesquisa, etc.).
/// Se nenhum módulo preferencial for encontrado, ele retorna o módulo da trilha
/// mais antiga na linha do tempo da jornada.
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

/// O shell principal da aplicação Valley Home, responsável pela navegação e
/// exibição do conteúdo da home.
///
/// Gerencia o estado da navegação, preferências de módulos visíveis,
/// e a carga de dados remotos da API de produto.
class ValleyHomeShell extends StatefulWidget {
  const ValleyHomeShell({
    super.key,
    required this.data,
    // O repositório de API para carregar e persistir dados da home.
    // Pode ser substituído para testes.
    this.repository = const ProductApiRepository(),
  });

  final ValleyAppData data;
  final ProductApiRepository repository;

  @override
  State<ValleyHomeShell> createState() => _ValleyHomeShellState();
}

class _ValleyHomeShellState extends State<ValleyHomeShell> {
  /// Índice da aba de navegação atualmente selecionada.
  int _index = 0;

  /// Conjunto de códigos de módulos visíveis na tela inicial.
  Set<String> _homeModuleCodes = <String>{};

  /// Indica se as preferências de módulos foram carregadas.
  bool _modulePreferencesReady = false;

  /// O código do módulo selecionado no dock de acesso rápido.
  String? _selectedDockModuleCode;

  /// Controlador para o campo de busca.
  late final TextEditingController _searchController;
  String _searchQuery = '';
  ProductHomeData? _remoteHomeData;
  bool _remoteHomeLoading = false;
  String _remoteHomeStatus = '';

  static const List<_Destination> _destinations = <_Destination>[
    /// Define os destinos da barra de navegação inferior.
    /// Cada destino representa uma seção principal da aplicação, agrupando
    /// módulos relacionados e fornecendo um título e ícone.
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

  /// Retorna o conjunto padrão de códigos de módulos para a tela inicial.
  ///
  /// Se houver módulos incluídos explicitamente nos dados da aplicação,
  /// eles são usados. Caso contrário, os primeiros 12 módulos do catálogo
  /// são selecionados como padrão.
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

  /// Carrega as preferências de módulos visíveis da tela inicial.
  ///
  /// Tenta carregar as preferências salvas localmente via [SharedPreferences].
  /// Se não houver preferências salvas ou se as salvas forem inválidas,
  /// as preferências padrão são aplicadas.
  /// Atualiza o estado da UI para refletir as preferências carregadas.
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

  /// Salva as preferências de módulos visíveis da tela inicial.
  ///
  /// Persiste as preferências localmente via [SharedPreferences] e tenta
  /// sincronizá-las com o backend através do [ProductApiRepository].
  /// Em caso de falha na sincronização remota, um status de erro é exibido,
  /// mas as preferências locais são mantidas.
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

  /// Carrega dados remotos para a tela inicial.
  ///
  /// Faz uma chamada à API para obter dados personalizados da home,
  /// incluindo preferências de módulos, recomendações e ações recentes.
  /// Se a API estiver disponível e retornar dados, as preferências locais
  /// podem ser sobrescritas pelas remotas.
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

  /// Alterna a visibilidade de um módulo na tela inicial.
  ///
  /// Adiciona ou remove o código do módulo do conjunto [_homeModuleCodes].
  /// Garante que pelo menos um módulo esteja sempre visível.
  /// Salva as preferências após a alteração.
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

  /// Navega para um novo destino na barra de navegação inferior.
  ///
  /// Atualiza o índice de navegação e limpa o módulo selecionado no dock.
  /// [index] O índice do destino a ser navegado.
  ///
  void _navigate(int index) {
    setState(() {
      _index = index;
      _selectedDockModuleCode = null;
    });
  }

  /// Abre a tela de detalhes de um módulo.
  ///
  /// Navega para o destino apropriado com base no código do módulo.
  /// Se o destino for a página inicial (índice 0), exibe um `BottomSheet`
  /// com os detalhes do módulo.
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

  /// Encontra um [ModuleRecord] pelo seu código.
  ///
  /// [code] O código do módulo a ser procurado.
  /// Retorna o [ModuleRecord] correspondente ou `null` se não for encontrado.
  ModuleRecord? _findModuleByCode(String code) {
    for (final ModuleRecord module in widget.data.modules) {
      if (module.code == code) {
        return module;
      }
    }
    return null;
  }

  /// Exibe um `BottomSheet` com o resultado de uma ação de runtime de jornada.
  ///
  /// Utilizado para mostrar feedback ao usuário após a execução de uma ação,
  /// incluindo um título, mensagem e, opcionalmente, uma URL.
  /// [title] O título do resultado.
  /// [message] A mensagem detalhada do resultado.
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

  /// Exibe um `BottomSheet` com os detalhes de um evento de jornada do usuário.
  ///
  /// Apresenta informações sobre uma [UserModuleTrail], incluindo o módulo,
  /// estágio, título, detalhes e, opcionalmente, um módulo primário associado.
  /// [trail] A trilha do módulo de usuário a ser exibida.
  /// [primaryModule] O módulo principal associado à jornada, se houver.
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

  /// Lida com o toque em um evento de jornada do usuário.
  ///
  /// Tenta invocar uma ação primária se [UserModuleTrail.primaryActionPath] estiver presente.
  /// Se a ação for bem-sucedida, exibe o resultado. Caso contrário, ou se não houver
  /// ação primária, exibe os detalhes do evento em um `BottomSheet`.
  /// [trail] A trilha do módulo de usuário que foi tocada.
  /// [primaryModule] O módulo principal associado à jornada.
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

  /// Lida com o toque em uma ação da home.
  ///
  /// Tenta invocar uma ação através do [ProductApiRepository] usando [actionPath].
  /// Se bem-sucedido, exibe o resultado. Caso contrário, ou se não houver
  /// [actionPath], abre o módulo especificado por [openModuleCode] ou [fallbackModuleCode].
  /// [title] O título da ação.
  /// [actionPath] O caminho da API a ser invocado.
  /// [openModuleCode] O código do módulo a ser aberto se a ação for bem-sucedida ou não houver actionPath.
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

  /// Atualiza a query de busca e o estado da UI.
  ///
  /// [value] O novo valor da query de busca.
  void _handleSearchChanged(String value) {
    setState(() {
      _searchQuery = value.trim();
    });
  }

  /// Filtra a lista de módulos com base na query de busca atual.
  ///
  /// Retorna uma lista de [ModuleRecord] que correspondem à query de busca,
  /// ordenados pelo número do módulo. Se a query estiver vazia, retorna todos os módulos.
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
    // Determina se a tela é larga o suficiente para exibir a barra lateral do desktop.
    final bool wide = MediaQuery.sizeOf(context).width >= 1040;

    // Filtra os módulos com base na query de busca.
    final List<ModuleRecord> filteredModules = _filteredModules();
    final Widget currentPage = _buildPage();

    return Scaffold(
      backgroundColor: ValleyBrandColors.night,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              // Barra de navegação inferior para telas compactas.
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
                      // Barra lateral para telas largas.
                      data: widget.data,
                      currentIndex: _index,
                      destinations: _destinations,
                      onNavigate: _navigate,
                    ),
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        // Barra superior de comandos e busca.
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
                            // Animação de transição entre as páginas.
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
                // Dock de acesso rápido aos módulos.
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

  /// Constrói a página atual com base no índice de navegação selecionado.
  ///
  /// Retorna um widget diferente para cada destino da navegação,
  /// passando os dados necessários e callbacks para interações.
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

/// Sidebar do desktop, exibida em telas largas.
///
/// Contém informações da marca Valley, um resumo da aplicação e os botões
/// de navegação para as diferentes seções.
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
      // Define a largura da sidebar.
      width: 292,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        children: <Widget>[
          ValleyPanel(
            padding: const EdgeInsets.all(20),
            // Painel com informações da marca e descrição.
            glowColor: ValleyBrandColors.violet,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Logomarca do Valley.
                const ValleyLogoMark(size: 60, borderRadius: 18),
                const SizedBox(height: 20),
                Text(
                  'Valley Super App',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                // Descrição da aplicação.
                Text(
                  'Pagamentos, comercio, identidade e Helena no mesmo ecossistema premium.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                // Chips de sinalização de status.
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
              // Painel para os botões de navegação.
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
                  // Painel de "Experiência ativa".
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

/// Botão de navegação para a sidebar do desktop.
///
/// Exibe um ícone, rótulo e título do destino.
/// O estilo muda quando o botão está selecionado para indicar o destino atual.
/// [destination] O destino da navegação.
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

/// Barra superior de comandos da aplicação.
///
/// Contém o título da página atual, um campo de busca, botões de ação rápida
/// e um badge de perfil do usuário. Adapta seu layout para telas compactas.
/// [title] O título da página atual.
/// [searchController] Controlador para o campo de busca.
/// [onSearchChanged] Callback para quando o texto da busca muda.
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
    // Verifica se a busca está ativa para ajustar o texto de status.
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
              // Layout responsivo para o cabeçalho.
              gap: 16,
              leadingFlex: 6,
              trailingFlex: 7,
              leading: Row(
                children: <Widget>[
                  const ValleyLogoMark(size: 52, borderRadius: 16),
                  const SizedBox(width: 14),
                  // Título da página e descrição da busca.
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
                        // Mensagem de status da busca ou descrição padrão.
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
                // Campo de busca e botões de ação.
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
                  // Botão de atalhos.
                  _TopBarIconButton(icon: Icons.tune_rounded, label: 'Atalhos'),
                  const SizedBox(width: 8),
                  const _ProfileBadge(),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Chips de sinalização de status e ações rápidas.
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

/// Botão de ícone para a barra superior.
///
/// Exibe um ícone e um rótulo em um tooltip.
/// [icon] O ícone a ser exibido.
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

/// Badge de perfil do usuário na barra superior.
///
/// Exibe as iniciais do usuário e seu status de produto.
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

/// Pill de ação rápida na barra superior.
///
/// Exibe um ícone e um rótulo, e executa um callback [onTap] quando tocado.
/// [icon] O ícone a ser exibido.
/// [label] O rótulo da ação.
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

/// Página de visão geral (Overview) da aplicação.
///
/// Exibe um hero com informações da marca, módulos da home, métricas,
/// recomendações, sinais operacionais e jornadas do usuário.
/// Permite a personalização dos módulos visíveis na home.
/// [data] Os dados gerais da aplicação.
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
    // Filtra e ordena os módulos que devem aparecer na home.
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
    // Lista de recomendações da API remota.
    final List<HomeRecommendation> recommendations =
        remoteHomeData?.recommendations ?? const <HomeRecommendation>[];
    // Lista de ações recentes da API remota.
    final List<HomeRecentAction> recentActions =
        remoteHomeData?.recentActions ?? const <HomeRecentAction>[];
    // Dados do score de identidade da API remota.
    final IdentityScoreData? identityScore = remoteHomeData?.identityScore;
    // Contexto do perfil do usuário da API remota.
    final HomeProfileContext? profileContext = remoteHomeData?.profileContext;
    // Sinais de módulos da API remota.
    final List<HomeModuleSignal> moduleSignals =
        remoteHomeData?.moduleSignals ?? const <HomeModuleSignal>[];
    // Trilhas de jornada do usuário da API remota, agrupadas.
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
              // Seção de destaque com informações da marca e módulos principais.
              homeModules: homeModules,
              onNavigate: onNavigate,
              onOpenModule: onOpenModule,
            ),
            const SizedBox(height: 20),
            _PremiumSignalRibbon(data: data),
            const SizedBox(height: 32),
            // Cabeçalho da seção de módulos da home.
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
            // Componente para compor e exibir os módulos na home.
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
            // Cabeçalho da seção de API da home.
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
            // Exibe o contexto do perfil do usuário se disponível.
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
            // Exibe sinais operacionais por módulo, se disponíveis.
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
              // Exibe a timeline comercial por objetivo (jornadas).
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
              // Exibe o score de identidade do usuário.
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
              // Exibe recomendações personalizadas.
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
                  // Exibe as ações recentes do usuário.
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
              // Cabeçalho da seção de atalhos comerciais.
              kicker: 'Essenciais',
              title: 'Atalhos comerciais',
              caption:
                  'Modulos centrais para pagamentos, documentos, operacao empresarial, comercio e Helena.',
            ),
            const SizedBox(height: 18),
            Wrap(
              // Exibe os módulos essenciais para acesso rápido.
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

/// Página da carteira, exibindo informações financeiras e módulos relacionados.
///
/// Detalha o saldo Valley, fluxos de pagamento, métricas financeiras
/// e um histórico de movimentações recentes.
class _WalletPage extends StatelessWidget {
  const _WalletPage({required this.data});

  final ValleyAppData data;

  @override
  Widget build(BuildContext context) {
    final List<ModuleRecord> modules = data.recordsForCodes(<String>[
      // Módulos diretamente relacionados à funcionalidade da carteira.
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
              // Cabeçalho da seção da carteira.
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
            // Painel principal com o saldo e descrição da carteira.
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
                          // Saldo fictício da carteira.
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
                        // Chips de sinalização de funcionalidades da carteira.
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
                      // Detalhes adicionais sobre a carteira.
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
            // Métricas relacionadas à carteira.
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
              // Cabeçalho da seção de fluxos de pagamento.
              kicker: 'Fluxos',
              title: 'Pagamentos com prova ponta a ponta',
              caption:
                  'A interface mostra captura, saldo, comprovante e fechamento sem separar a jornada.',
            ),
            const SizedBox(height: 18),
            Wrap(
              // Tiles de linha do tempo para os fluxos de pagamento.
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
              // Cabeçalho da seção de movimentações recentes.
              kicker: 'Historico',
              title: 'Movimentacoes recentes',
              caption:
                  'Resumo claro das operacoes financeiras mais importantes.',
            ),
            const SizedBox(height: 18),
            ...const <Widget>[
              // Linhas de eventos do ledger.
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
                title: 'Reserva para pedido de entrega',
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

/// Página do Marketplace, exibindo produtos, lojas e regras de pricing.
///
/// Detalha a experiência de compra, integrações comerciais e o ciclo
/// de decisão do motor de pricing.
class _MarketplacePage extends StatelessWidget {
  const _MarketplacePage({required this.data});

  final ValleyAppData data;

  @override
  Widget build(BuildContext context) {
    final PhaseRecord commercePhase =
        // Obtém a fase de comércio do manifesto.
        data.phaseByKey('phase_2_commerce') ?? data.manifest.phases[1];
    final StockMarketplaceModel model = commercePhase.stockMarketplaceModel!;
    final DropshippingBlueprint blueprint = model.blueprint;

    return _PageFrame(
      child: FadeSlideIn(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SectionHeader(
              // Cabeçalho da seção do Marketplace.
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
            // Painel principal com busca e regras de compra.
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
                      // Seção de busca e descrição do marketplace.
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
                        // Chips de superfícies essenciais.
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
                      // Painel com as regras de runtime da Helena.
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
                          // Título das regras de compra.
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
            // Cabeçalho da seção de ofertas.
            SectionHeader(
              kicker: 'Ofertas',
              title: 'Vitrine de ofertas',
              caption:
                  'Produtos, lojas e checkout aparecem com linguagem clara para o usuario final.',
            ),
            const SizedBox(height: 18),
            Wrap(
              // Tiles de módulos relacionados a ofertas.
              spacing: 16,
              runSpacing: 16,
              children: <Widget>[
                SizedBox(
                  width: 300,
                  child: HoverModuleTile(
                    code: 'STOCK',
                    title: 'Central de Dropshipping',
                    subtitle: 'Loja, estoque e rastreio',
                    caption:
                        'Vincula item Valley a canais comerciais homologados sem expor a origem operacional ao cliente.',
                    onTap: () => _showModuleActionSheet(
                      context,
                      code: 'STOCK',
                      title: 'Central de Dropshipping',
                      subtitle: 'Loja, estoque e rastreio',
                      caption:
                          'Centraliza disponibilidade, entrega e rastreio em uma unica experiencia.',
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
              // Cabeçalho da seção de fontes e referências de preço.
              kicker: 'Fontes',
              title: 'Fontes comerciais e referencias de preco',
              caption:
                  'Referencias comerciais ajudam a manter oferta, margem e disponibilidade mais consistentes.',
            ),
            const SizedBox(height: 18),
            Wrap(
              // Exibe os provedores de API e fontes de preço.
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
                                  ? 'Loja API'
                                  : 'Fonte de preco',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              blueprint.supplierApis.contains(provider)
                                  ? 'Importacao, disponibilidade, pedido e rastreio.'
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
              // Cabeçalho da seção de pricing.
              kicker: 'Preco',
              title: 'Ciclo de decisao do pricing engine',
              caption:
                  'Cada ajuste protege margem, estoque e experiencia de compra.',
            ),
            const SizedBox(height: 18),
            Column(
              // Lista de capacidades requeridas pelo blueprint de dropshipping.
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

/// Página de Negócios, focada em ERP, compras e comprovantes.
///
/// Apresenta os módulos relacionados a operações empresariais,
/// os objetivos da fase de ativação do core e os fluxos empresariais priorizados.
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
              // Cabeçalho da seção de Negócios.
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
            // Cabeçalho da seção de rotinas empresariais.
            SectionHeader(
              kicker: 'Rotinas',
              title: 'Fluxos empresariais que a interface prioriza',
              caption:
                  'Compras, fiscal, servicos e comprovantes ficam agrupados para decisao rapida.',
            ),
            const SizedBox(height: 18),
            const Wrap(
              // Tiles de agenda com tarefas e lembretes.
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

/// Página de Identidade, focada em segurança e autenticação.
///
/// Detalha o Identity Score, biometria (Face ID, Voice ID) e a importância
/// da identidade forte em diversas jornadas.
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
              // Cabeçalho da seção de Identidade.
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
                      // Exibição do score e sua descrição.
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
                      // Chips de sinalização de componentes de identidade.
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
            // Cabeçalho da seção de proteção.
            SectionHeader(
              kicker: 'Protecao',
              title: 'Identidade forte em cada jornada',
              caption:
                  'Biometria, reputacao e comprovacao ajudam a proteger pagamentos, vendedores e acessos.',
            ),
            const SizedBox(height: 18),
            Column(
              // Lista de componentes de identidade transversal.
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

/// Página da Helena (IA), exibindo funcionalidades de assistente, chat e agenda.
///
/// Detalha como a IA é utilizada de forma utilitária, com regras de uso
/// e exemplos de interação.
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
              // Cabeçalho da seção da Helena.
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
              // Tiles dos módulos relacionados a negócios.
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
                    // Seção principal com o saldo e descrição.
                    leading: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Exemplo de acao Helena',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '“Sua carteira empresarial ja tem PIX P2P, comprovante Docs e seller score. A proxima acao recomendada e ativar o marketplace com lojas confiaveis e preco protegido.”',
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
                      // Painel com regras de compra.
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
                          // Título das preferências.
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
            // Cabeçalho da seção de agenda.
            SectionHeader(
              kicker: 'Agenda',
              title: 'Memoria util e recorrencia acionavel',
              caption:
                  'Compromissos, lembretes e acoes aparecem de forma simples para acompanhar a rotina.',
            ),
            const SizedBox(height: 18),
            const Wrap(
              // Tiles de linha do tempo para os fluxos empresariais.
              spacing: 16,
              runSpacing: 16,
              children: <Widget>[
                SizedBox(
                  width: 320,
                  child: _AgendaTile(
                    title: '09:00 • Conferir lojas',
                    body:
                        'Revisar lojas principais e confirmar disponibilidade para ofertas ativas.',
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

/// Seção de destaque (hero) na página de visão geral.
///
/// Apresenta um título impactante, descrição, botões de ação rápida
/// e uma visualização orbital dos módulos principais.
/// [data] Os dados gerais da aplicação.
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
      // Painel com estilo visual diferenciado para o hero.
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
            // Desenha o fundo orbital do hero.
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
                      // Conteúdo textual do hero.
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            const SignalChip(
                              label: 'modo premium',
                              color: ValleyBrandColors.cyan,
                              // Sinaliza o modo premium da aplicação.
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
                          // Chips de status e contagem de módulos.
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
                        // Título principal do hero.
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
                        // Descrição do hero.
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: <Widget>[
                            FilledButton.icon(
                              onPressed: () => onNavigate(2),
                              // Botão para abrir a seção de comércio.
                              icon: const Icon(Icons.storefront_rounded),
                              label: const Text('Abrir comercio'),
                            ),
                            OutlinedButton.icon(
                              // Botão para abrir a seção da Helena.
                              onPressed: () => onNavigate(5),
                              icon: const Icon(Icons.auto_awesome_rounded),
                              label: const Text('Abrir Helena'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Faixa de briefing com princípios e foco.
                        _HeroBriefingStrip(
                          principle:
                              'Seu ecossistema fica organizado em modulos claros, com acesso rapido e superficie unica.',
                          focus:
                              'Commerce, Pay, Docs, Business e Helena trabalham juntos para simplificar rotina, compra e operacao.',
                        ),
                      ],
                    ),
                    trailing: _OrbitModuleVisual(
                      // Visualização orbital dos módulos.
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

/// Faixa de briefing exibida no hero da página inicial.
///
/// Contém informações sobre os princípios e o foco da experiência Valley.
/// [principle] O princípio central da experiência.
/// [focus] O foco principal da aplicação.
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

/// Visualização orbital dos módulos na seção hero da página inicial.
///
/// Exibe os módulos em um layout circular, com o logo do Valley no centro.
/// [modules] A lista de módulos a serem exibidos.
/// [onOpenModule] Callback para abrir um módulo quando tocado.
class _OrbitModuleVisual extends StatelessWidget {
  const _OrbitModuleVisual({required this.modules, required this.onOpenModule});

  final List<ModuleRecord> modules;
  final ValueChanged<ModuleRecord> onOpenModule;

  @override
  Widget build(BuildContext context) {
    final List<ModuleRecord> visibleModules = modules.take(8).toList();
    // Limita o número de módulos visíveis na órbita.
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
                  // Exibe o logo e o texto "ORBIT" no centro.
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
              // Posiciona cada módulo na órbita.
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

/// Representa um nó de módulo na visualização orbital.
///
/// Exibe o ícone e o código de um módulo em uma posição específica na órbita.
/// [module] O registro do módulo a ser exibido.
/// [angle] O ângulo em que o módulo deve ser posicionado.
/// [radius] O raio da órbita.
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

/// Faixa de sinalização premium exibida na página inicial.
///
/// Destaca métricas importantes da aplicação em um formato de "ribbon".
/// [data] Os dados gerais da aplicação.
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
          // Métricas individuais exibidas na faixa.
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

/// Um tile de métrica individual para a faixa de sinalização premium.
///
/// Exibe um rótulo, valor e uma cor de destaque.
/// [label] O rótulo da métrica.
/// [value] O valor da métrica.
/// [accent] A cor de destaque da métrica.
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

/// Custom painter para desenhar o fundo orbital do hero.
///
/// Cria um efeito visual de linhas diagonais e um arco.
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
  /// Retorna `false` pois o desenho não muda.
  ///
  /// [oldDelegate] O delegate anterior.
  /// Retorna `true` se o delegate anterior era diferente e o desenho precisa ser refeito.
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OrbitDialPainter extends CustomPainter {
  const _OrbitDialPainter({required this.count});

  final int count;

  /// Custom painter para desenhar os anéis e linhas radiais da visualização orbital.
  ///
  /// [count] O número de linhas radiais a serem desenhadas.

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
  /// Retorna `true` se o número de módulos mudou, indicando que o desenho precisa ser refeito.
  ///
  /// [oldDelegate] O delegate anterior.
  /// Retorna `true` se o delegate anterior era diferente e o desenho precisa ser refeito.
  bool shouldRepaint(covariant _OrbitDialPainter oldDelegate) {
    return oldDelegate.count != count;
  }
}

class _HomeModuleComposer extends StatelessWidget {
  const _HomeModuleComposer({
    // Lista de todos os módulos disponíveis.
    // [homeModules] A lista de módulos atualmente selecionados para a home.
    // [visibleCodes] O conjunto de códigos dos módulos visíveis.
    // [preferencesReady] Indica se as preferências foram carregadas.
    // [searchQuery] A query de busca atual.
    // [onOpenModule] Callback para abrir um módulo.
    // [onToggleHomeModule] Callback para alternar a visibilidade de um módulo.
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
            // Layout responsivo para a composição de módulos.
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
                    // Título da seção "Na tela inicial".
                    const Spacer(),
                    SignalChip(
                      label: preferencesReady ? 'salvo' : 'sincronizando',
                      color: preferencesReady
                          ? ValleyBrandColors.success
                          : ValleyBrandColors.warning,
                    ),
                  ],
                  // Chip de status das preferências.
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
                // Exibe uma mensagem de aviso se nenhum módulo corresponder à busca.
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
                // Exibe os módulos selecionados para a home.
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
              // Painel para personalizar os módulos da home.
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
                // Título e descrição da personalização da home.
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
                  // Chips de filtro para selecionar/desselecionar módulos.
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

/// Tile para lançar um módulo diretamente da home.
///
/// Exibe informações detalhadas do módulo e permite abri-lo com um toque.
/// [module] O registro do módulo a ser exibido.
class _LaunchModuleTile extends StatefulWidget {
  const _LaunchModuleTile({required this.module, required this.onOpenModule});

  final ModuleRecord module;
  final ValueChanged<ModuleRecord> onOpenModule;

  @override
  State<_LaunchModuleTile> createState() => _LaunchModuleTileState();
}

class _LaunchModuleTileState extends State<_LaunchModuleTile> {
  bool _hovered = false;
  // Estado de hover para animação visual.

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
                // Estilo visual do tile, com gradiente e borda que reagem ao hover.
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
                    // Ícone e código do módulo.
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
                  // Nome e subtítulo do módulo.
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
                  // Descrição do módulo.
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

/// Dock de acesso rápido aos módulos, flutuante na parte inferior da tela.
///
/// Exibe uma lista horizontal de pílulas de módulos, permitindo acesso rápido.
/// [modules] A lista de módulos a serem exibidos no dock.
/// [selectedCode] O código do módulo atualmente selecionado, para destaque visual.
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
        // Efeito de desfoque para o dock.
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
              // Ícone e rótulo do dock.
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
              // Separador visual.
              Container(
                width: 1,
                height: 28,
                color: Colors.white.withValues(alpha: 0.16),
              ),
              // Lista horizontal de pílulas de módulos.
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

/// Pílula de módulo individual para o dock de acesso rápido.
///
/// Exibe o ícone e o código do módulo. O estilo muda quando o módulo está selecionado.
/// [module] O registro do módulo a ser exibido.
/// [selected] Indica se o módulo está atualmente selecionado.
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

/// Estrutura de layout para as páginas da aplicação.
///
/// Garante que o conteúdo seja rolavel e centralizado, com padding adequado.
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

/// Widget que alterna entre layout de linha e coluna com base na largura disponível.
///
/// [stacked] Se `true`, os widgets `leading` e `trailing` são empilhados verticalmente.
/// [leading] O widget principal.
/// [trailing] O widget secundário.
/// [gap] O espaçamento entre os widgets.
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

/// Exibe um `BottomSheet` com informações detalhadas de um módulo.
///
/// Utilizado para apresentar o título, subtítulo e descrição de um módulo
/// quando ele é aberto a partir da home ou do dock.
/// [context] O contexto de construção.
/// [code] O código do módulo.
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
                // Tiles dos módulos relacionados à Helena.
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

/// Tile de linha do tempo para exibir etapas de um processo.
///
/// [step] O número ou identificador da etapa.
/// [title] O título da etapa.
/// [body] A descrição detalhada da etapa.
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

/// Linha de evento do ledger, exibindo uma transação ou ação recente.
///
/// [status] O status do evento (SETTLED, AUTHORIZED, ESCROW_HOLD).
/// [title] O título do evento.
/// [detail] Detalhes adicionais do evento.
/// [amount] O valor monetário associado ao evento.
/// [onTap] Callback opcional para quando o evento é tocado.
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

/// Tile de agenda, exibindo um compromisso ou lembrete.
///
/// [title] O título do item da agenda.
/// [body] A descrição detalhada do item da agenda.
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

/// Classe auxiliar que representa um destino de navegação.
///
/// Usada para definir os itens da barra de navegação inferior,
/// incluindo um rótulo, título e ícone.
/// [label] O rótulo curto para exibição na barra de navegação.
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
