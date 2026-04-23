import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:valley_super_app/src/data/product_api_models.dart';
import 'package:valley_super_app/src/data/product_api_repository.dart';
import 'package:valley_super_app/src/ui/ui_components.dart';
import 'package:valley_super_app/valley_brand_theme.dart';

class ValleyProductShell extends StatefulWidget {
  const ValleyProductShell({
    super.key,
    required this.initialData,
    required this.repository,
  });

  final ProductShellData initialData;
  final ProductApiRepository repository;

  @override
  State<ValleyProductShell> createState() => _ValleyProductShellState();
}

class _ValleyProductShellState extends State<ValleyProductShell> {
  late ProductShellData _data;
  bool _busy = false;
  String _query = '';
  String _selectedModuleId = 'MARKETPLACE';
  String _surface = 'home';
  bool _dockExpanded = false;
  double _dockX = 0.84;
  int _navIndex = 0;
  ProductItem? _selectedItem;
  Map<String, dynamic>? _selectedConversation;
  final FlutterTts _tts = FlutterTts();
  bool _helenaMinimized = false;
  String _helenaMood = 'calm';
  String _helenaMessage = 'Helena pronta para guiar a experiencia Valley.';

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
    if (_data.modules.any((ProductModule module) => module.id == 'MARKETPLACE')) {
      _selectedModuleId = 'MARKETPLACE';
    } else if (_data.modules.isNotEmpty) {
      _selectedModuleId = _data.modules.first.id;
    }
    _setupHelena();
  }

  Future<void> _setupHelena() async {
    await _tts.setLanguage('pt-BR');
    await _tts.setPitch(1.05);
    await _tts.setSpeechRate(0.46);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speakHelena('Helena ativa. Experiencia de produto pronta para voce.');
    });
  }

  Future<void> _speakHelena(String text) async {
    _helenaMessage = text;
    if (mounted) {
      setState(() {});
    }
    await _tts.stop();
    await _tts.speak(text);
  }

  void _setHelenaMood(String mood, String message) {
    setState(() {
      _helenaMood = mood;
      _helenaMessage = message;
    });
    _speakHelena(message);
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      final ProductShellData fresh = await widget.repository.load();
      if (!mounted) {
        return;
      }
      setState(() => _data = fresh);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _runItemAction(String path) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final ProductActionResult result = await widget.repository.invokePath(
        baseUrl: _data.baseUrl,
        path: path,
      );
      if (!mounted) {
        return;
      }
      if (result.url.isNotEmpty) {
        await launchUrl(Uri.parse(result.url), mode: LaunchMode.platformDefault);
      }
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(result.message),
          backgroundColor:
              result.ok ? ValleyBrandColors.success : ValleyBrandColors.danger,
        ),
      );
      _setHelenaMood(
        result.ok ? 'happy' : 'alert',
        result.message,
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  List<Map<String, dynamic>> _rawList(String key) {
    final Object? value = _data.rawData[key];
    if (value is! List<dynamic>) {
      return const <Map<String, dynamic>>[];
    }
    return value
        .whereType<Map<dynamic, dynamic>>()
        .map((Map<dynamic, dynamic> item) => item.cast<String, dynamic>())
        .toList();
  }

  Map<String, dynamic>? _profileById(String id) {
    for (final Map<String, dynamic> profile in _rawList('profiles')) {
      if (profile['id'] == id) {
        return profile;
      }
    }
    return null;
  }

  Map<String, dynamic>? _moduleScreenById(String id) {
    for (final Map<String, dynamic> screen in _rawList('module_screens')) {
      if (screen['module_id'] == id) {
        return screen;
      }
    }
    return null;
  }

  void _openSurface(String surface) {
    setState(() {
      _surface = surface;
    });
    _setHelenaMood(
      surface == 'feed'
          ? 'happy'
          : surface == 'chat'
              ? 'focus'
              : surface == 'statement'
                  ? 'calm'
                  : 'focus',
      'Abrindo ${surface == 'home' ? 'a tela principal' : surface}.',
    );
  }

  void _openItemDetail(ProductItem item) {
    setState(() {
      _selectedItem = item;
      _surface = 'detail';
    });
    _setHelenaMood('focus', 'Abrindo ${item.title} com video e descricao completa.');
  }

  void _openCheckout(ProductItem item) {
    setState(() {
      _selectedItem = item;
      _surface = 'checkout';
    });
    _setHelenaMood('happy', 'Checkout pronto para ${item.title}.');
  }

  void _openConversation(Map<String, dynamic> conversation) {
    setState(() {
      _selectedConversation = conversation;
      _surface = 'conversation';
    });
    _setHelenaMood('focus', 'Abrindo a conversa com ${conversation['title']}.');
  }

  void _showModule(String moduleId) {
    setState(() {
      _selectedModuleId = moduleId;
      _surface = 'home';
      _selectedItem = null;
      _selectedConversation = null;
    });
    _setHelenaMood('calm', 'Modulo $moduleId ativo.');
  }

  List<ProductItem> get _filteredItems {
    return _data.items.where((ProductItem item) {
      if (_selectedModuleId.isNotEmpty && item.moduleId != _selectedModuleId) {
        return false;
      }
      if (_query.trim().isEmpty) {
        return true;
      }
      final String search = _query.toLowerCase();
      final String haystack = <String>[
        item.title,
        item.brand,
        item.category,
        item.merchantName,
        ...item.tags,
      ].join(' ').toLowerCase();
      return haystack.contains(search);
    }).toList();
  }

  ProductModule? get _selectedModule {
    for (final ProductModule module in _data.modules) {
      if (module.id == _selectedModuleId) {
        return module;
      }
    }
    return _data.modules.isEmpty ? null : _data.modules.first;
  }

  List<String> get _categoryFilters {
    final Set<String> values = <String>{'Todos os Produtos'};
    for (final ProductItem item in _filteredItems) {
      values.add(item.category);
    }
    return values.take(5).toList();
  }

  Widget _buildSurface(
    ThemeData theme,
    List<ProductItem> items,
    ProductModule? module,
    List<ProductItem> recentItems,
  ) {
    if (_surface == 'detail' && _selectedItem != null) {
      return _ProductDetailScreen(
        item: _selectedItem!,
        profile: _profileById(_selectedItem!.profileId),
        onPlay: _selectedItem!.mediaPath.isEmpty
            ? null
            : () => _runItemAction(_selectedItem!.mediaPath),
        onCheckout: () => _openCheckout(_selectedItem!),
      );
    }
    if (_surface == 'checkout' && _selectedItem != null) {
      return _CheckoutScreen(
        item: _selectedItem!,
        onConfirm: () => _runItemAction(_selectedItem!.ctaPath),
      );
    }
    if (_surface == 'feed') {
      return _FeedScreen(
        entries: _rawList('feed_entries'),
        onOpenItem: (String itemId) {
          for (final ProductItem item in _data.items) {
            if (item.id == itemId) {
              _openItemDetail(item);
              break;
            }
          }
        },
      );
    }
    if (_surface == 'chat') {
      return _ChatScreen(
        conversations: _rawList('conversations'),
        onOpenConversation: _openConversation,
      );
    }
    if (_surface == 'conversation' && _selectedConversation != null) {
      return _ConversationScreen(conversation: _selectedConversation!);
    }
    if (_surface == 'statement') {
      return _StatementScreen(entries: _rawList('statement_entries'));
    }

    final Map<String, dynamic>? moduleScreen = _moduleScreenById(module?.id ?? '');
    if ((module?.id ?? '') == 'STOCK') {
      return _StockSection(
        items: items,
        onTap: _openItemDetail,
      );
    }
    if ((module?.id ?? '') == 'FOOD') {
      return _FoodModuleScreen(
        items: items,
        onOpenItem: _openItemDetail,
      );
    }
    if ((module?.id ?? '') == 'SERVICES') {
      return _ServicesModuleScreen(
        items: items,
        onOpenItem: _openItemDetail,
      );
    }
    if ((module?.id ?? '') == 'LOG') {
      return _LogisticsModuleScreen(
        items: items,
        onOpenItem: _openItemDetail,
      );
    }
    if ((module?.id ?? '') == 'PAY') {
      return _PayModuleScreen(
        items: items,
        entries: _rawList('statement_entries'),
      );
    }
    if ((module?.id ?? '') == 'ENERGY') {
      return _EnergyModuleScreen(
        items: items,
        entries: _rawList('statement_entries'),
      );
    }
    if ((module?.id ?? '') == 'INSURANCE') {
      return _PolicyModuleScreen(
        items: items,
        onOpenItem: _openItemDetail,
      );
    }
    if ((module?.id ?? '') == 'GAMING') {
      return _GamingModuleScreen(
        items: items,
        onOpenItem: _openItemDetail,
      );
    }
    if ((module?.id ?? '') == 'MOBILITY') {
      return _MobilityModuleScreen(
        items: items,
        onOpenItem: _openItemDetail,
      );
    }
    if ((module?.id ?? '') == 'MARKETPLACE') {
      return _MarketplaceModuleScreen(
        items: items,
        onOpenItem: _openItemDetail,
      );
    }
    return _GenericModuleScreen(
      module: module,
      moduleScreen: moduleScreen,
      spotlightItems: items.take(4).toList(),
      onOpenItem: _openItemDetail,
      onOpenFeed: () => _openSurface('feed'),
      onOpenChat: () => _openSurface('chat'),
      onOpenStatement: () => _openSurface('statement'),
    );
  }

  // ignore: unused_element
  Widget _buildModuleSection(
    ThemeData theme,
    List<ProductItem> items,
    ProductModule? module,
    List<ProductItem> recentItems,
  ) {
    final String moduleId = module?.id ?? '';
    if (moduleId == 'STOCK') {
      return _StockSection(
        items: items,
        onTap: _openItemDetail,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    module?.label ?? 'Marketplace',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    module?.subtitle ??
                        'Curadoria exclusiva de hardware e wearables tecnológicos desenvolvidos no Valley.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _busy ? null : _refresh,
              child: const Text('Ver todos'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _categoryFilters
                .map(
                  (String label) => Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _FilterChip(
                      label: label,
                      active: label == 'Todos os Produtos',
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double width = constraints.maxWidth;
            int crossAxisCount = 1;
            if (width >= 1180) {
              crossAxisCount = 3;
            } else if (width >= 760) {
              crossAxisCount = 2;
            }
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.take(5).length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 18,
                crossAxisSpacing: 18,
                childAspectRatio: width >= 1180 ? 0.77 : 0.79,
              ),
              itemBuilder: (BuildContext context, int index) {
                final ProductItem item = items[index];
                return _MarketplaceCard(
                  item: item,
                  featured: index == 0 && crossAxisCount >= 2,
                  busy: _busy,
                  onPrimary: () => _openItemDetail(item),
                  onSecondary: item.mediaPath.isEmpty
                      ? null
                      : () => _runItemAction(item.mediaPath),
                );
              },
            );
          },
        ),
        const SizedBox(height: 28),
        _RecentActivityPanel(
          items: recentItems,
          onTap: _openItemDetail,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<ProductItem> items = _filteredItems;
    final ProductModule? module = _selectedModule;
    final ProductItem? heroItem = items.isEmpty
        ? (_data.items.isEmpty ? null : _data.items.first)
        : items.first;
    final List<ProductItem> recentItems = items.take(2).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF0B1020),
              Color(0xFF121A2F),
              Color(0xFF0E1323),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: <Widget>[
              const ValleyBackdrop(),
              RefreshIndicator(
                onRefresh: _refresh,
                child: CustomScrollView(
                  slivers: <Widget>[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _TopBar(
                              busy: _busy,
                              onSearchChanged: (String value) =>
                                  setState(() => _query = value),
                            ),
                            const SizedBox(height: 24),
                            if (heroItem != null && _surface == 'home')
                              _HeroSection(
                                item: heroItem,
                                subtitle: _data.subtitle,
                                onPrimary: _busy
                                    ? null
                                    : () => _openItemDetail(heroItem),
                              ),
                            if (_surface == 'home') const SizedBox(height: 18),
                            if (_surface == 'home')
                              _IndicatorGrid(
                                summary: _data.summary,
                                selectedModule: module,
                                itemCount: items.length,
                              ),
                            const SizedBox(height: 28),
                            _buildSurface(
                              theme,
                              items,
                              module,
                              recentItems,
                            ),
                            if (_data.publicUrl.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 18),
                              ValleyPanel(
                                radius: 28,
                                padding: const EdgeInsets.all(18),
                                glowColor: ValleyBrandColors.cyan,
                                child: Row(
                                  children: <Widget>[
                                    const Icon(
                                      Icons.public_rounded,
                                      color: ValleyBrandColors.cyan,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _data.publicUrl,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _FloatingDock(
                modules: _data.modules,
                expanded: _dockExpanded,
                selectedModuleId: _selectedModuleId,
                alignmentX: _dockX,
                onToggle: () => setState(() => _dockExpanded = !_dockExpanded),
                onPanUpdate: (DragUpdateDetails details) {
                  final double width = MediaQuery.sizeOf(context).width;
                  setState(() {
                    _dockX = (_dockX + (details.delta.dx / math.max(width, 1)) * 2)
                        .clamp(-0.84, 0.84);
                  });
                },
                onSelect: (ProductModule module) {
                  _showModule(module.id);
                  setState(() => _dockExpanded = false);
                },
              ),
              Positioned(
                left: 18,
                bottom: 108,
                child: _HelenaAssistant(
                  minimized: _helenaMinimized,
                  mood: _helenaMood,
                  message: _helenaMessage,
                  onToggle: () => setState(() => _helenaMinimized = !_helenaMinimized),
                  onSpeak: () => _speakHelena(_helenaMessage),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _BottomGlassNav(
        index: _navIndex,
        onChanged: (int value) {
          setState(() {
            _navIndex = value;
          });
          if (value == 0) {
            _openSurface('home');
          } else if (value == 1) {
            _showModule('MARKETPLACE');
          } else if (value == 2) {
            _showModule('STOCK');
          } else if (value == 3) {
            _showModule('PAY');
          } else if (value == 4) {
            _openSurface('chat');
          }
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.busy,
    required this.onSearchChanged,
  });

  final bool busy;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ValleyBrandColors.cyan.withValues(alpha: 0.28)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.network(
            'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=300&q=80',
            fit: BoxFit.cover,
            errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
              return const ColoredBox(color: Color(0xFF1A1F30));
            },
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Text(
            'VALLEY',
            style: TextStyle(
              color: ValleyBrandColors.cyan,
              fontWeight: FontWeight.w800,
              letterSpacing: 3.2,
              fontSize: 12,
            ),
          ),
        ),
        SizedBox(
          width: 180,
          child: TextField(
            onChanged: onSearchChanged,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Buscar',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: busy
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              filled: true,
              fillColor: const Color(0x66161B2B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.item,
    required this.subtitle,
    required this.onPrimary,
  });

  final ProductItem item;
  final String subtitle;
  final VoidCallback? onPrimary;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: SizedBox(
        height: 430,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.network(
              item.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                return const ColoredBox(color: Color(0xFF121A2F));
              },
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.12),
                    const Color(0xFF0E1323).withValues(alpha: 0.28),
                    const Color(0xFF0E1323).withValues(alpha: 0.92),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 26,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    child: const Text(
                      'SISTEMA ATIVO',
                      style: TextStyle(
                        color: Color(0xFF5CD7E9),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.02,
                          ),
                      children: <InlineSpan>[
                        const TextSpan(text: 'Bem-vindo ao\n'),
                        TextSpan(
                          text: 'Futuro, Arthur.',
                          style: const TextStyle(
                            color: Color(0xFF6EE7F9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: onPrimary,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF6EE7F9),
                      foregroundColor: const Color(0xFF001F24),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(item.ctaLabel),
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

class _IndicatorGrid extends StatelessWidget {
  const _IndicatorGrid({
    required this.summary,
    required this.selectedModule,
    required this.itemCount,
  });

  final ProductSummary summary;
  final ProductModule? selectedModule;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 860) {
          return Column(
            children: <Widget>[
              _wideCard(),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(child: _smallCard('Ativos Em Carteira', '${summary.products}')),
                  const SizedBox(width: 14),
                  Expanded(child: _energyCard()),
                ],
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(flex: 2, child: _wideCard()),
            const SizedBox(width: 14),
            Expanded(child: _smallCard('Ativos Em Carteira', '${summary.products}')),
            const SizedBox(width: 14),
            Expanded(child: _energyCard()),
          ],
        );
      },
    );
  }

  Widget _wideCard() {
    return ValleyPanel(
      radius: 24,
      padding: const EdgeInsets.all(22),
      glowColor: ValleyBrandColors.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.query_stats_rounded, color: ValleyBrandColors.cyan, size: 32),
              const Spacer(),
              Text(
                '+12.4%',
                style: const TextStyle(
                  color: Color(0xFF6EE7F9),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'PERFORMANCE GLOBAL',
            style: const TextStyle(
              color: Color(0xFFBCC9CB),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            selectedModule?.id ?? 'VALY.OS',
            style: const TextStyle(
              color: Color(0xFFDEE1F9),
              fontWeight: FontWeight.w800,
              fontSize: 30,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 54,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <double>[0.34, 0.50, 0.68, 0.54, 0.78, 1.0]
                  .map(
                    (double factor) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Container(
                          height: 54 * factor,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                            color: const Color(0xFF6EE7F9)
                                .withValues(alpha: 0.28 + (factor * 0.44)),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallCard(String label, String value) {
    return ValleyPanel(
      radius: 24,
      padding: const EdgeInsets.all(22),
      child: SizedBox(
        height: 206,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFFBCC9CB),
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                fontSize: 11,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFFDEE1F9),
                fontWeight: FontWeight.w800,
                fontSize: 30,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$itemCount sincronizados',
              style: const TextStyle(
                color: Color(0xFF6EE7F9),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _energyCard() {
    return ValleyPanel(
      radius: 24,
      padding: const EdgeInsets.all(22),
      child: SizedBox(
        height: 206,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'CONSUMO ENERGÉTICO',
              style: TextStyle(
                color: Color(0xFFBCC9CB),
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                fontSize: 11,
              ),
            ),
            const Spacer(),
            const Text(
              '14.2 kW',
              style: TextStyle(
                color: Color(0xFFDEE1F9),
                fontWeight: FontWeight.w800,
                fontSize: 30,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 8,
                child: Stack(
                  children: <Widget>[
                    Container(color: Colors.white.withValues(alpha: 0.10)),
                    FractionallySizedBox(
                      widthFactor: 0.66,
                      child: Container(color: const Color(0xFFD0BCFF)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketplaceCard extends StatelessWidget {
  const _MarketplaceCard({
    required this.item,
    required this.featured,
    required this.busy,
    required this.onPrimary,
    required this.onSecondary,
  });

  final ProductItem item;
  final bool featured;
  final bool busy;
  final VoidCallback onPrimary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return ValleyPanel(
      radius: 24,
      padding: EdgeInsets.zero,
      glowColor: ValleyBrandColors.violet,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              height: featured ? 280 : 260,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Image.network(
                    item.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (BuildContext context, Object error, StackTrace? stackTrace) {
                      return const ColoredBox(color: Color(0xFF1A1F30));
                    },
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xCC0E1323),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.videocam_rounded,
                            size: 14,
                            color: ValleyBrandColors.cyan,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            item.videoCount > 0 ? 'Preview' : 'Produto',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              item.brand.toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFF869395),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.category,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      if (featured && onSecondary != null)
                        IconButton(
                          onPressed: busy ? null : onSecondary,
                          icon: const Icon(
                            Icons.add_shopping_cart_rounded,
                            color: ValleyBrandColors.cyan,
                          ),
                        )
                      else
                        Text(
                          'R\$ ${item.priceBrl.toStringAsFixed(0)}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (featured) ...<Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          'R\$ ${item.priceBrl.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Color(0xFFDEE1F9),
                            fontWeight: FontWeight.w800,
                            fontSize: 30,
                          ),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: busy ? null : onPrimary,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF6EE7F9),
                            foregroundColor: const Color(0xFF001F24),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: Text(item.ctaLabel.toUpperCase()),
                        ),
                      ],
                    ),
                  ] else ...<Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          'R\$ ${item.priceBrl.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Color(0xFFDEE1F9),
                            fontWeight: FontWeight.w800,
                            fontSize: 24,
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: busy ? null : onPrimary,
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: const Icon(
                              Icons.add_shopping_cart_rounded,
                              color: ValleyBrandColors.cyan,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (!featured && onSecondary != null) ...<Widget>[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: busy ? null : onSecondary,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Ver Detalhes'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockSection extends StatelessWidget {
  const _StockSection({
    required this.items,
    required this.onTap,
  });

  final List<ProductItem> items;
  final ValueChanged<ProductItem> onTap;

  @override
  Widget build(BuildContext context) {
    final int lowStock = items.where((ProductItem item) => item.stock <= 5).length;
    final int inTransfer = items.where((ProductItem item) => item.stock > 5 && item.stock <= 18).length;
    final int totalUnits = items.fold<int>(0, (int sum, ProductItem item) => sum + item.stock);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Gestão de Estoque',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: ValleyBrandColors.cyan,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Monitoramento em tempo real de ativos, suprimentos e logística do hub central.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compact = constraints.maxWidth < 860;
            final List<Widget> cards = <Widget>[
              _StockStatCard(
                title: 'Total de Itens',
                value: '$totalUnits',
                accent: ValleyBrandColors.cyan,
                caption: '+${items.length} hoje',
              ),
              _StockStatCard(
                title: 'Estoque Crítico',
                value: '$lowStock',
                accent: ValleyBrandColors.danger,
                caption: 'Requer atenção',
              ),
              _StockStatCard(
                title: 'Pedidos Pendentes',
                value: '$inTransfer',
                accent: const Color(0xFFD0BCFF),
                caption: 'Em trânsito',
              ),
            ];
            if (compact) {
              return Column(
                children: cards
                    .map((Widget card) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: card,
                        ))
                    .toList(),
              );
            }
            return Row(
              children: <Widget>[
                Expanded(child: cards[0]),
                const SizedBox(width: 14),
                Expanded(child: cards[1]),
                const SizedBox(width: 14),
                Expanded(child: cards[2]),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                readOnly: true,
                decoration: InputDecoration(
                  hintText: 'Filtrar por nome, SKU ou categoria...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: const Color(0xFF161B2B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.filter_list_rounded),
              label: const Text('Filtros'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            int crossAxisCount = 1;
            if (constraints.maxWidth >= 1180) {
              crossAxisCount = 3;
            } else if (constraints.maxWidth >= 760) {
              crossAxisCount = 2;
            }
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.take(6).length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 18,
                crossAxisSpacing: 18,
                childAspectRatio: 0.86,
              ),
              itemBuilder: (BuildContext context, int index) {
                final ProductItem item = items[index];
                return _StockCard(
                  item: item,
                  onTap: () => onTap(item),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _StockStatCard extends StatelessWidget {
  const _StockStatCard({
    required this.title,
    required this.value,
    required this.accent,
    required this.caption,
  });

  final String title;
  final String value;
  final Color accent;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return ValleyPanel(
      radius: 22,
      padding: const EdgeInsets.all(20),
      glowColor: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFFBCC9CB),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w800,
              fontSize: 32,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: TextStyle(
              color: accent.withValues(alpha: 0.70),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StockCard extends StatelessWidget {
  const _StockCard({
    required this.item,
    required this.onTap,
  });

  final ProductItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool lowStock = item.stock <= 5;
    final bool inTransfer = item.stock > 5 && item.stock <= 18;
    final Color accent = lowStock
        ? ValleyBrandColors.danger
        : inTransfer
            ? const Color(0xFFD0BCFF)
            : ValleyBrandColors.cyan;
    final String status = lowStock
        ? 'Estoque Baixo'
        : inTransfer
            ? 'Em Transferência'
            : 'Disponível';
    final String location = inTransfer
        ? 'Pátio de Montagem Leste'
        : lowStock
            ? 'Armazém Logístico Sul'
            : 'Hub Metropolitano A-1';

    return ValleyPanel(
      radius: 24,
      padding: EdgeInsets.zero,
      glowColor: accent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              height: 188,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Image.network(
                    item.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (BuildContext context, Object error, StackTrace? stackTrace) {
                      return const ColoredBox(color: Color(0xFF1A1F30));
                    },
                  ),
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xCC0E1323),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Text(
                        item.category,
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'SKU: ${item.id.substring(0, 8).toUpperCase()}',
                              style: const TextStyle(
                                color: Color(0xFF869395),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Text(
                            '${item.stock}',
                            style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.w800,
                              fontSize: 28,
                            ),
                          ),
                          const Text(
                            'UNIDADES',
                            style: TextStyle(
                              color: Color(0xFF869395),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      const Icon(Icons.hub_rounded, size: 18, color: Color(0xFF869395)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          location,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Icon(
                        lowStock
                            ? Icons.warning_rounded
                            : inTransfer
                                ? Icons.sync_alt_rounded
                                : Icons.check_circle_rounded,
                        size: 18,
                        color: accent,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        status,
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      height: 6,
                      child: Stack(
                        children: <Widget>[
                          Container(color: Colors.white.withValues(alpha: 0.06)),
                          FractionallySizedBox(
                            widthFactor: (item.stock.clamp(1, 100) / 100),
                            child: Container(color: accent),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: FilledButton(
                          onPressed: onTap,
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: lowStock
                                ? const Color(0xFFFFDAD6)
                                : const Color(0xFF001F24),
                          ),
                          child: Text(
                            lowStock
                                ? 'REABASTECER'
                                : inTransfer
                                    ? 'RASTREAR'
                                    : 'MOVIMENTAR',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: OutlinedButton(
                          onPressed: onTap,
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Icon(Icons.more_vert_rounded),
                        ),
                      ),
                    ],
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
  });

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xB3121A2F),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active
              ? ValleyBrandColors.cyan.withValues(alpha: 0.50)
              : Colors.white.withValues(alpha: 0.05),
        ),
        boxShadow: active
            ? <BoxShadow>[
                BoxShadow(
                  color: ValleyBrandColors.cyan.withValues(alpha: 0.16),
                  blurRadius: 16,
                ),
              ]
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active
              ? ValleyBrandColors.cyan
              : Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RecentActivityPanel extends StatelessWidget {
  const _RecentActivityPanel({
    required this.items,
    required this.onTap,
  });

  final List<ProductItem> items;
  final ValueChanged<ProductItem> onTap;

  @override
  Widget build(BuildContext context) {
    return ValleyPanel(
      radius: 30,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Atividade Recente',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 20),
          for (int i = 0; i < items.length; i++) ...<Widget>[
            _RecentRow(
              item: items[i],
              primaryIcon: i == 0 ? Icons.account_balance_wallet_rounded : Icons.shopping_bag_rounded,
              highlight: i == 0,
              onTap: () => onTap(items[i]),
            ),
            if (i < items.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({
    required this.item,
    required this.primaryIcon,
    required this.highlight,
    required this.onTap,
  });

  final ProductItem item;
  final IconData primaryIcon;
  final bool highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (highlight
                        ? ValleyBrandColors.cyan
                        : const Color(0xFFD0BCFF))
                    .withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                primaryIcon,
                color: highlight
                    ? ValleyBrandColors.cyan
                    : const Color(0xFFD0BCFF),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    highlight ? 'Transferência Recebida' : 'Aquisição ${item.brand}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    highlight
                        ? 'Hoje, 14:22 • Wallet A7'
                        : 'Ontem, 09:15 • Marketplace',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            Text(
              highlight
                  ? '+R\$ ${(item.priceBrl / 10).toStringAsFixed(2)}'
                  : '-R\$ ${item.priceBrl.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: highlight
                        ? ValleyBrandColors.cyan
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductDetailScreen extends StatelessWidget {
  const _ProductDetailScreen({
    required this.item,
    required this.profile,
    required this.onPlay,
    required this.onCheckout,
  });

  final ProductItem item;
  final Map<String, dynamic>? profile;
  final VoidCallback? onPlay;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<dynamic> features = item.raw['features'] as List<dynamic>? ?? const <dynamic>[];
    final Map<String, dynamic> seller =
        (item.raw['seller'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{})
            .cast<String, dynamic>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Image.network(
                  item.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                    return const ColoredBox(color: Color(0xFF121A2F));
                  },
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.black.withValues(alpha: 0.08),
                        Colors.black.withValues(alpha: 0.70),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              item.brand.toUpperCase(),
                              style: const TextStyle(
                                color: ValleyBrandColors.cyan,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.title,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.description,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      FilledButton.icon(
                        onPressed: onPlay,
                        icon: const Icon(Icons.play_circle_fill_rounded),
                        label: const Text('Video'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              flex: 2,
              child: ValleyPanel(
                radius: 26,
                padding: const EdgeInsets.all(20),
                glowColor: ValleyBrandColors.cyan,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Descricao',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item.description,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: features
                          .map(
                            (dynamic feature) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(feature.toString()),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: ValleyPanel(
                radius: 26,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        CircleAvatar(
                          radius: 24,
                          backgroundImage: NetworkImage(
                            (profile?['avatar_url'] ?? seller['avatar_url'] ?? item.imageUrl)
                                .toString(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                (profile?['name'] ?? seller['name'] ?? item.merchantName).toString(),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                (profile?['headline'] ?? item.category).toString(),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'R\$ ${item.priceBrl.toStringAsFixed(2)}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: ValleyBrandColors.cyan,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Estoque ${item.stock} • ${item.status}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: onCheckout,
                      child: const Text('Ir para checkout'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CheckoutScreen extends StatelessWidget {
  const _CheckoutScreen({
    required this.item,
    required this.onConfirm,
  });

  final ProductItem item;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Map<String, dynamic> checkout =
        (item.raw['checkout'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{})
            .cast<String, dynamic>();
    final double shipping = (checkout['shipping_brl'] as num?)?.toDouble() ?? 19.9;
    final double service = (checkout['service_brl'] as num?)?.toDouble() ?? 4.9;
    final double total = item.priceBrl + shipping + service;

    return ValleyPanel(
      radius: 30,
      padding: const EdgeInsets.all(24),
      glowColor: ValleyBrandColors.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            checkout['headline']?.toString() ?? 'Checkout',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _CheckoutRow(label: item.title, value: 'R\$ ${item.priceBrl.toStringAsFixed(2)}'),
                    _CheckoutRow(label: 'Entrega', value: 'R\$ ${shipping.toStringAsFixed(2)}'),
                    _CheckoutRow(label: 'Servico', value: 'R\$ ${service.toStringAsFixed(2)}'),
                    const Divider(height: 28),
                    _CheckoutRow(
                      label: 'Total',
                      value: 'R\$ ${total.toStringAsFixed(2)}',
                      highlight: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: ValleyPanel(
                  radius: 24,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Entrega prevista',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(checkout['eta']?.toString() ?? '2 dias'),
                      const SizedBox(height: 14),
                      Text('Parcelamento em ate ${checkout['installments'] ?? 12}x sem juros'),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: onConfirm,
                        icon: const Icon(Icons.lock_rounded),
                        label: const Text('Finalizar pedido'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckoutRow extends StatelessWidget {
  const _CheckoutRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              color: highlight ? ValleyBrandColors.cyan : null,
              fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedScreen extends StatelessWidget {
  const _FeedScreen({
    required this.entries,
    required this.onOpenItem,
  });

  final List<Map<String, dynamic>> entries;
  final ValueChanged<String> onOpenItem;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Feed ativo',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        for (final Map<String, dynamic> entry in entries.take(12))
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ValleyPanel(
              radius: 24,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      CircleAvatar(backgroundImage: NetworkImage(entry['author_avatar'].toString())),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(entry['author_name'].toString()),
                            Text(
                              entry['time_label'].toString(),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Text(entry['module_id'].toString()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(entry['headline'].toString(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(entry['text'].toString()),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        entry['media_url'].toString(),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Text('❤ ${entry['likes']}'),
                      const SizedBox(width: 16),
                      Text('💬 ${entry['comments']}'),
                      const SizedBox(width: 16),
                      Text('↗ ${entry['shares']}'),
                      const Spacer(),
                      TextButton(
                        onPressed: () => onOpenItem(entry['item_id'].toString()),
                        child: const Text('Abrir item'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ChatScreen extends StatelessWidget {
  const _ChatScreen({
    required this.conversations,
    required this.onOpenConversation,
  });

  final List<Map<String, dynamic>> conversations;
  final ValueChanged<Map<String, dynamic>> onOpenConversation;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Chat',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        for (final Map<String, dynamic> conversation in conversations)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => onOpenConversation(conversation),
              child: ValleyPanel(
                radius: 22,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: <Widget>[
                    CircleAvatar(backgroundImage: NetworkImage(conversation['avatar_url'].toString())),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(conversation['title'].toString()),
                          const SizedBox(height: 4),
                          Text(
                            conversation['subtitle'].toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    if ((conversation['unread_count'] as num?)?.toInt() case final int count when count > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: ValleyBrandColors.cyan,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Color(0xFF001F24),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ConversationScreen extends StatelessWidget {
  const _ConversationScreen({required this.conversation});

  final Map<String, dynamic> conversation;

  @override
  Widget build(BuildContext context) {
    final List<dynamic> messages = conversation['messages'] as List<dynamic>? ?? const <dynamic>[];
    return ValleyPanel(
      radius: 28,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            conversation['title'].toString(),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          for (final dynamic entry in messages)
            if (entry is Map<dynamic, dynamic>)
              Align(
                alignment: entry['sender'] == 'me'
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  constraints: const BoxConstraints(maxWidth: 420),
                  decoration: BoxDecoration(
                    color: entry['sender'] == 'me'
                        ? ValleyBrandColors.cyan.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(entry['text'].toString()),
                ),
              ),
        ],
      ),
    );
  }
}

class _StatementScreen extends StatelessWidget {
  const _StatementScreen({required this.entries});

  final List<Map<String, dynamic>> entries;

  @override
  Widget build(BuildContext context) {
    return ValleyPanel(
      radius: 28,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Extrato',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          for (final Map<String, dynamic> entry in entries.take(18))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(entry['title'].toString()),
                        const SizedBox(height: 4),
                        Text(
                          entry['subtitle'].toString(),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'R\$ ${(entry['amount_brl'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                    style: TextStyle(
                      color: entry['direction'] == 'credit'
                          ? ValleyBrandColors.cyan
                          : ValleyBrandColors.danger,
                      fontWeight: FontWeight.w800,
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

class _GenericModuleScreen extends StatelessWidget {
  const _GenericModuleScreen({
    required this.module,
    required this.moduleScreen,
    required this.spotlightItems,
    required this.onOpenItem,
    required this.onOpenFeed,
    required this.onOpenChat,
    required this.onOpenStatement,
  });

  final ProductModule? module;
  final Map<String, dynamic>? moduleScreen;
  final List<ProductItem> spotlightItems;
  final ValueChanged<ProductItem> onOpenItem;
  final VoidCallback onOpenFeed;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenStatement;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<dynamic> statCards = moduleScreen?['stat_cards'] as List<dynamic>? ?? const <dynamic>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ValleyPanel(
          radius: 28,
          padding: const EdgeInsets.all(24),
          glowColor: ValleyBrandColors.cyan,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                moduleScreen?['hero_title']?.toString() ?? module?.label ?? 'Modulo',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                moduleScreen?['hero_subtitle']?.toString() ?? module?.subtitle ?? '',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  OutlinedButton(onPressed: onOpenFeed, child: const Text('Feed')),
                  OutlinedButton(onPressed: onOpenChat, child: const Text('Chat')),
                  OutlinedButton(onPressed: onOpenStatement, child: const Text('Extrato')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: statCards
              .whereType<Map<dynamic, dynamic>>()
              .map(
                (Map<dynamic, dynamic> stat) => ValleyPanel(
                  radius: 22,
                  padding: const EdgeInsets.all(18),
                  child: SizedBox(
                    width: 210,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(stat['label'].toString()),
                        const SizedBox(height: 8),
                        Text(
                          stat['value'].toString(),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: ValleyBrandColors.cyan,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(stat['trend'].toString()),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 20),
        for (final ProductItem item in spotlightItems)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => onOpenItem(item),
              child: ValleyPanel(
                radius: 24,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.network(
                        item.imageUrl,
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(item.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(
                            item.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MobilityModuleScreen extends StatelessWidget {
  const _MobilityModuleScreen({
    required this.items,
    required this.onOpenItem,
  });

  final List<ProductItem> items;
  final ValueChanged<ProductItem> onOpenItem;

  @override
  Widget build(BuildContext context) {
    final List<ProductItem> rides = items.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ValleyPanel(
          radius: 30,
          padding: const EdgeInsets.all(22),
          glowColor: ValleyBrandColors.cyan,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Chamar veiculo',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              Container(
                height: 260,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[Color(0xFF16223F), Color(0xFF0E1323)],
                  ),
                ),
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: CustomPaint(painter: _RoutePainter()),
                    ),
                    const Positioned(
                      left: 24,
                      top: 28,
                      child: _MapPin(label: 'Origem'),
                    ),
                    const Positioned(
                      right: 28,
                      bottom: 30,
                      child: _MapPin(label: 'Destino'),
                    ),
                    Positioned(
                      left: 18,
                      right: 18,
                      bottom: 16,
                      child: ValleyPanel(
                        radius: 20,
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: const <Widget>[
                            Expanded(child: Text('Rota premium • 7 min de chegada')),
                            Text('R\$ 22,40'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        for (final ProductItem ride in rides)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ValleyPanel(
              radius: 22,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.directions_car_filled_rounded, color: ValleyBrandColors.cyan),
                  const SizedBox(width: 12),
                  Expanded(child: Text('${ride.brand} • ETA ${2 + (ride.stock % 6)} min')),
                  FilledButton(
                    onPressed: () => onOpenItem(ride),
                    child: const Text('Chamar'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _FoodModuleScreen extends StatelessWidget {
  const _FoodModuleScreen({
    required this.items,
    required this.onOpenItem,
  });

  final List<ProductItem> items;
  final ValueChanged<ProductItem> onOpenItem;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Food',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final int columns = constraints.maxWidth > 900 ? 3 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.take(6).length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.88,
              ),
              itemBuilder: (BuildContext context, int index) {
                final ProductItem item = items[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => onOpenItem(item),
                  child: ValleyPanel(
                    radius: 24,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.network(item.imageUrl, fit: BoxFit.cover, width: double.infinity),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Text('Entrega em ${18 + (item.stock % 15)} min'),
                        const SizedBox(height: 10),
                        Row(
                          children: <Widget>[
                            Text(
                              'R\$ ${item.priceBrl.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: ValleyBrandColors.cyan,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Spacer(),
                            FilledButton(
                              onPressed: () => onOpenItem(item),
                              child: const Text('Pedir'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _MarketplaceModuleScreen extends StatelessWidget {
  const _MarketplaceModuleScreen({
    required this.items,
    required this.onOpenItem,
  });

  final List<ProductItem> items;
  final ValueChanged<ProductItem> onOpenItem;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<ProductItem> showcase = items.take(5).toList();
    final ProductItem? featured = showcase.isEmpty ? null : showcase.first;
    final List<ProductItem> secondary = showcase.length > 1 ? showcase.sublist(1) : const <ProductItem>[];

    if (featured == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Marketplace',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        ValleyPanel(
          radius: 32,
          padding: EdgeInsets.zero,
          glowColor: ValleyBrandColors.cyan,
          child: InkWell(
            borderRadius: BorderRadius.circular(32),
            onTap: () => onOpenItem(featured),
            child: Column(
              children: <Widget>[
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      featured.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                        return const ColoredBox(color: Color(0xFF121A2F));
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              featured.brand.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: ValleyBrandColors.cyan,
                                letterSpacing: 1.8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              featured.title,
                              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              featured.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      FilledButton.icon(
                        onPressed: () => onOpenItem(featured),
                        icon: const Icon(Icons.shopping_cart_checkout_rounded),
                        label: Text(featured.ctaLabel),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: secondary.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.92,
          ),
          itemBuilder: (BuildContext context, int index) {
            final ProductItem item = secondary[index];
            return InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () => onOpenItem(item),
              child: ValleyPanel(
                radius: 28,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(
                          item.imageUrl,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(
                      'R\$ ${item.priceBrl.toStringAsFixed(2)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: ValleyBrandColors.cyan,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => onOpenItem(item),
                      child: const Text('Quick Buy'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ServicesModuleScreen extends StatelessWidget {
  const _ServicesModuleScreen({
    required this.items,
    required this.onOpenItem,
  });

  final List<ProductItem> items;
  final ValueChanged<ProductItem> onOpenItem;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<ProductItem> categories = items.take(4).toList();
    final List<ProductItem> professionals = items.skip(4).take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ValleyPanel(
          radius: 30,
          padding: const EdgeInsets.all(24),
          glowColor: ValleyBrandColors.cyan,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: <Color>[ValleyBrandColors.cyan, Color(0xFF7C3AED)],
                  ),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Helena AI Insights',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: ValleyBrandColors.cyan,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Serviços disponíveis na sua região. Profissionais verificados prontos para agir.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.bolt_rounded),
                label: const Text('Ação rápida'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ValleyPanel(
          radius: 28,
          padding: const EdgeInsets.all(18),
          child: Row(
            children: <Widget>[
              const Expanded(
                child: _FieldChip(icon: Icons.location_on_outlined, label: 'Localização do serviço'),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: _FieldChip(icon: Icons.event_outlined, label: 'Data e horário'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () {},
                child: const Text('Agendar agora'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Categorias',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: categories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.1,
          ),
          itemBuilder: (BuildContext context, int index) {
            final ProductItem item = categories[index];
            return InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () => onOpenItem(item),
              child: ValleyPanel(
                radius: 28,
                padding: EdgeInsets.zero,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.network(item.imageUrl, fit: BoxFit.cover),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: const LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: <Color>[Color(0xCC0B1020), Color(0x110B1020)],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 18,
                      right: 18,
                      bottom: 18,
                      child: Text(
                        item.category.isEmpty ? item.title : item.category,
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        Text(
          'Profissionais em destaque',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        for (final ProductItem professional in professionals)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: InkWell(
              borderRadius: BorderRadius.circular(26),
              onTap: () => onOpenItem(professional),
              child: ValleyPanel(
                radius: 26,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(
                        professional.imageUrl,
                        width: 92,
                        height: 92,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            professional.brand,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: ValleyBrandColors.cyan,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            professional.title,
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            professional.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          'R\$ ${professional.priceBrl.toStringAsFixed(0)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: ValleyBrandColors.cyan,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: () => onOpenItem(professional),
                          child: const Text('Abrir'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LogisticsModuleScreen extends StatelessWidget {
  const _LogisticsModuleScreen({
    required this.items,
    required this.onOpenItem,
  });

  final List<ProductItem> items;
  final ValueChanged<ProductItem> onOpenItem;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<ProductItem> cards = items.take(3).toList();
    final List<ProductItem> tableRows = items.skip(3).take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ValleyPanel(
          radius: 30,
          padding: const EdgeInsets.all(22),
          glowColor: ValleyBrandColors.cyan,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: ValleyBrandColors.cyan.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.local_shipping_rounded, color: ValleyBrandColors.cyan),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Refinamento Operacional',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Hub Norte ativo. Helena já sincronizou carga, latência e movimentação recente.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const _MiniStat(label: 'Latency', value: '12ms'),
              const SizedBox(width: 10),
              const _MiniStat(label: 'Load', value: '22%'),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: cards
              .map(
                (ProductItem item) => SizedBox(
                  width: 320,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => onOpenItem(item),
                    child: ValleyPanel(
                      radius: 24,
                      padding: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          SizedBox(
                            height: 180,
                            child: Stack(
                              fit: StackFit.expand,
                              children: <Widget>[
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                                  child: Image.network(item.imageUrl, fit: BoxFit.cover),
                                ),
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.55),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      item.status.toUpperCase(),
                                      style: const TextStyle(
                                        color: ValleyBrandColors.cyan,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(item.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                Text(
                                  item.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: <Widget>[
                                    Text(
                                      'ETA ${8 + (item.stock % 15)}:${(item.stock % 6) * 10}'.padLeft(2, '0'),
                                      style: const TextStyle(
                                        color: ValleyBrandColors.cyan,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const Spacer(),
                                    OutlinedButton(
                                      onPressed: () => onOpenItem(item),
                                      child: const Text('Detalhes'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 18),
        ValleyPanel(
          radius: 28,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    'Movimentação recente',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  TextButton(onPressed: () {}, child: const Text('Ver relatório completo')),
                ],
              ),
              const SizedBox(height: 10),
              for (final ProductItem row in tableRows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(child: Text(row.title)),
                        Expanded(child: Text(row.brand)),
                        Expanded(child: Text(row.merchantName)),
                        Text(
                          row.status.toUpperCase(),
                          style: TextStyle(
                            color: row.status.toLowerCase().contains('low')
                                ? ValleyBrandColors.danger
                                : ValleyBrandColors.cyan,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PayModuleScreen extends StatelessWidget {
  const _PayModuleScreen({
    required this.items,
    required this.entries,
  });

  final List<ProductItem> items;
  final List<Map<String, dynamic>> entries;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ValleyPanel(
          radius: 32,
          padding: const EdgeInsets.all(28),
          glowColor: ValleyBrandColors.cyan,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Valley Pay',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Interface financeira neural com saldo, atalhos e atividade recente.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'R\$ 14.820,00',
                style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                '+2.4% este mês',
                style: TextStyle(color: ValleyBrandColors.cyan, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: const <Widget>[
            Expanded(child: _ActionCard(icon: Icons.qr_code_2_rounded, label: 'Pix')),
            SizedBox(width: 14),
            Expanded(child: _ActionCard(icon: Icons.send_to_mobile_rounded, label: 'Transferir')),
            SizedBox(width: 14),
            Expanded(child: _ActionCard(icon: Icons.receipt_long_rounded, label: 'Pagar')),
            SizedBox(width: 14),
            Expanded(child: _ActionCard(icon: Icons.request_quote_rounded, label: 'Receber')),
          ],
        ),
        const SizedBox(height: 18),
        ValleyPanel(
          radius: 28,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Atividade recente',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              for (final Map<String, dynamic> entry in entries.take(6))
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.payments_rounded, color: ValleyBrandColors.cyan),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(entry['title'].toString()),
                            const SizedBox(height: 4),
                            Text(
                              entry['subtitle'].toString(),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'R\$ ${(entry['amount_brl'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                        style: TextStyle(
                          color: entry['direction'] == 'credit'
                              ? ValleyBrandColors.cyan
                              : theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EnergyModuleScreen extends StatelessWidget {
  const _EnergyModuleScreen({
    required this.items,
    required this.entries,
  });

  final List<ProductItem> items;
  final List<Map<String, dynamic>> entries;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ValleyPanel(
          radius: 30,
          padding: const EdgeInsets.all(24),
          glowColor: ValleyBrandColors.cyan,
          child: Row(
            children: <Widget>[
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Extrato de troca',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Consumo vs geração com saldo acumulado e créditos de energia.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 180,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List<Widget>.generate(8, (int index) {
                          final double height = <double>[0.60, 0.45, 0.80, 0.95, 0.55, 0.70, 0.40, 0.65][index];
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: FractionallySizedBox(
                                heightFactor: height,
                                alignment: Alignment.bottomCenter,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: index == 3 ? ValleyBrandColors.cyan : ValleyBrandColors.cyan.withValues(alpha: 0.28),
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: ValleyPanel(
                  radius: 24,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Créditos',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Ξ 1.242,50',
                        style: TextStyle(
                          color: ValleyBrandColors.cyan,
                          fontWeight: FontWeight.w800,
                          fontSize: 28,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {},
                        child: const Text('Converter em Gaming'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        for (final Map<String, dynamic> entry in entries.take(3))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ValleyPanel(
              radius: 22,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.bolt_rounded, color: ValleyBrandColors.cyan),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(entry['title'].toString()),
                        Text(
                          entry['subtitle'].toString(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${((entry['amount_brl'] as num?) ?? 0).toStringAsFixed(1)} kWh',
                    style: const TextStyle(
                      color: ValleyBrandColors.cyan,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PolicyModuleScreen extends StatelessWidget {
  const _PolicyModuleScreen({
    required this.items,
    required this.onOpenItem,
  });

  final List<ProductItem> items;
  final ValueChanged<ProductItem> onOpenItem;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<ProductItem> cards = items.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ValleyPanel(
          radius: 30,
          padding: const EdgeInsets.all(24),
          glowColor: ValleyBrandColors.cyan,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Digital Shield v.24',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sua cobertura de ativos digitais e residenciais está operando em capacidade total.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              const _MiniStat(label: 'Risco', value: '9%'),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: cards
              .map(
                (ProductItem item) => SizedBox(
                  width: 320,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => onOpenItem(item),
                    child: ValleyPanel(
                      radius: 24,
                      padding: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                            child: AspectRatio(
                              aspectRatio: 16 / 10,
                              child: Image.network(item.imageUrl, fit: BoxFit.cover),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(item.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                Text(
                                  item.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                FilledButton(
                                  onPressed: () => onOpenItem(item),
                                  child: const Text('Abrir cobertura'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _GamingModuleScreen extends StatelessWidget {
  const _GamingModuleScreen({
    required this.items,
    required this.onOpenItem,
  });

  final List<ProductItem> items;
  final ValueChanged<ProductItem> onOpenItem;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<ProductItem> rewards = items.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ValleyPanel(
          radius: 32,
          padding: EdgeInsets.zero,
          glowColor: ValleyBrandColors.cyan,
          child: Stack(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: AspectRatio(
                  aspectRatio: 16 / 7,
                  child: Image.network(
                    rewards.isNotEmpty ? rewards.first.imageUrl : '',
                    fit: BoxFit.cover,
                    errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                      return const ColoredBox(color: Color(0xFF121A2F));
                    },
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: const LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: <Color>[Color(0xEE0B1020), Color(0x330B1020)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: ValleyBrandColors.cyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Lendário',
                        style: TextStyle(
                          color: ValleyBrandColors.cyan,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'PROTOCOLO NEXUS',
                      style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Neutralize as anomalias digitais e maximize recompensas de bônus com Helena em modo foco.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: rewards.isNotEmpty ? () => onOpenItem(rewards.first) : null,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Ingressar agora'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: <Widget>[
            Expanded(
              child: ValleyPanel(
                radius: 24,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Recompensas',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    for (final ProductItem reward in rewards)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: <Widget>[
                            const Icon(Icons.diamond_rounded, color: ValleyBrandColors.cyan),
                            const SizedBox(width: 10),
                            Expanded(child: Text(reward.title)),
                            Text(
                              '${reward.stock} pts',
                              style: const TextStyle(color: ValleyBrandColors.cyan),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ValleyPanel(
                radius: 24,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const <Widget>[
                    Text(
                      'Top operadores',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 12),
                    _RankingRow(position: '1', name: 'A_Ghost_X', value: '04:12s'),
                    _RankingRow(position: '2', name: 'NovaStream', value: '04:28s'),
                    _RankingRow(position: '12', name: 'Você', value: '--:--', highlight: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ValleyPanel(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      child: Column(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: ValleyBrandColors.cyan.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: ValleyBrandColors.cyan),
          ),
          const SizedBox(height: 10),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _FieldChip extends StatelessWidget {
  const _FieldChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0x55080D1D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: Colors.white54),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white54),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: ValleyBrandColors.cyan, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({
    required this.position,
    required this.name,
    required this.value,
    this.highlight = false,
  });

  final String position;
  final String name;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final Color color = highlight ? ValleyBrandColors.cyan : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 28,
            child: Text(position, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          ),
          Expanded(child: Text(name, style: TextStyle(color: color))),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const Icon(Icons.place_rounded, color: ValleyBrandColors.cyan, size: 28),
        const SizedBox(height: 4),
        Text(label),
      ],
    );
  }
}

class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 42) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 42) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final Paint route = Paint()
      ..color = ValleyBrandColors.cyan
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Path path = Path()
      ..moveTo(42, 60)
      ..quadraticBezierTo(size.width * 0.34, 96, size.width * 0.44, size.height * 0.48)
      ..quadraticBezierTo(size.width * 0.64, size.height * 0.70, size.width - 58, size.height - 58);
    canvas.drawPath(path, route);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HelenaAssistant extends StatelessWidget {
  const _HelenaAssistant({
    required this.minimized,
    required this.mood,
    required this.message,
    required this.onToggle,
    required this.onSpeak,
  });

  final bool minimized;
  final String mood;
  final String message;
  final VoidCallback onToggle;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      width: minimized ? 78 : 292,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xCC121A2F),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: ValleyBrandColors.cyan.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: minimized
          ? Center(
              child: IconButton(
                onPressed: onToggle,
                icon: const _HelenaStarBadge(),
              ),
            )
          : Row(
              children: <Widget>[
                GestureDetector(
                  onTap: onSpeak,
                  child: _HelenaFace(mood: mood),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text(
                        'Helena',
                        style: TextStyle(
                          color: ValleyBrandColors.cyan,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onSpeak,
                  icon: const Icon(Icons.graphic_eq_rounded),
                  color: ValleyBrandColors.cyan,
                ),
                IconButton(
                  onPressed: onToggle,
                  icon: const _HelenaStarBadge(size: 18),
                ),
              ],
            ),
    );
  }
}

class _HelenaFace extends StatelessWidget {
  const _HelenaFace({required this.mood});

  final String mood;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(58, 58),
      painter: _HelenaFacePainter(mood: mood),
    );
  }
}

class _HelenaFacePainter extends CustomPainter {
  const _HelenaFacePainter({required this.mood});

  final String mood;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final Paint orb = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[Color(0xFF6EE7F9), Color(0xFFD0BCFF)],
      ).createShader(Offset.zero & size);
    canvas.drawCircle(center, size.width / 2, orb);

    final Paint feature = Paint()
      ..color = const Color(0xFF001F24)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(const Offset(20, 24), 3, Paint()..color = const Color(0xFF001F24));
    canvas.drawCircle(const Offset(38, 24), 3, Paint()..color = const Color(0xFF001F24));

    final Path mouth = Path();
    if (mood == 'happy') {
      mouth.moveTo(18, 36);
      mouth.quadraticBezierTo(29, 46, 40, 36);
    } else if (mood == 'alert') {
      mouth.moveTo(18, 39);
      mouth.quadraticBezierTo(29, 33, 40, 39);
    } else if (mood == 'focus') {
      mouth.moveTo(18, 39);
      mouth.lineTo(40, 39);
    } else {
      mouth.moveTo(18, 37);
      mouth.quadraticBezierTo(29, 41, 40, 37);
    }
    canvas.drawPath(mouth, feature);
  }

  @override
  bool shouldRepaint(covariant _HelenaFacePainter oldDelegate) =>
      oldDelegate.mood != mood;
}

class _HelenaStarBadge extends StatelessWidget {
  const _HelenaStarBadge({this.size = 30});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: const _HelenaStarPainter(),
    );
  }
}

class _HelenaStarPainter extends CustomPainter {
  const _HelenaStarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final Paint glow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          Colors.white.withValues(alpha: 0.95),
          const Color(0xFFC46BFF),
          const Color(0xFF6EE7F9).withValues(alpha: 0.25),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawCircle(center, size.width / 2, glow);

    final Paint star = Paint()..color = Colors.white;
    canvas.drawRect(
      Rect.fromCenter(center: center, width: size.width * 0.16, height: size.height * 0.72),
      star,
    );
    canvas.drawRect(
      Rect.fromCenter(center: center, width: size.width * 0.72, height: size.height * 0.16),
      star,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FloatingDock extends StatelessWidget {
  const _FloatingDock({
    required this.modules,
    required this.expanded,
    required this.selectedModuleId,
    required this.alignmentX,
    required this.onToggle,
    required this.onPanUpdate,
    required this.onSelect,
  });

  final List<ProductModule> modules;
  final bool expanded;
  final String selectedModuleId;
  final double alignmentX;
  final VoidCallback onToggle;
  final GestureDragUpdateCallback onPanUpdate;
  final ValueChanged<ProductModule> onSelect;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment(alignmentX, 0.83),
      child: GestureDetector(
        onPanUpdate: onPanUpdate,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(10),
          width: expanded ? math.min(MediaQuery.sizeOf(context).width - 40, 360) : 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xFF6EE7F9),
                Color(0xFFD0BCFF),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFF6EE7F9).withValues(alpha: 0.30),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: expanded
              ? Row(
                  children: <Widget>[
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: modules
                              .map(
                                (ProductModule module) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(module.id),
                                    selected: selectedModuleId == module.id,
                                    onSelected: (_) => onSelect(module),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onToggle,
                      icon: const Icon(Icons.close_rounded),
                      color: const Color(0xFF0B1020),
                    ),
                  ],
                )
              : IconButton(
                  onPressed: onToggle,
                  icon: const Icon(
                    Icons.add_circle_rounded,
                    size: 36,
                    color: Color(0xFF0B1020),
                  ),
                ),
        ),
      ),
    );
  }
}

class _BottomGlassNav extends StatelessWidget {
  const _BottomGlassNav({
    required this.index,
    required this.onChanged,
  });

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const List<_BottomItem> items = <_BottomItem>[
      _BottomItem(Icons.home_max_rounded, 'Início'),
      _BottomItem(Icons.storefront_rounded, 'Market'),
      _BottomItem(Icons.inventory_2_rounded, 'Stock'),
      _BottomItem(Icons.account_balance_wallet_rounded, 'Pay'),
      _BottomItem(Icons.chat_bubble_rounded, 'Chat'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        height: 74,
        decoration: BoxDecoration(
          color: const Color(0x990B1020),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.34),
              blurRadius: 28,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List<Widget>.generate(items.length, (int i) {
            final bool selected = i == index;
            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onChanged(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      items[i].icon,
                      color: selected
                          ? ValleyBrandColors.cyan
                          : Colors.white.withValues(alpha: 0.44),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      items[i].label,
                      style: TextStyle(
                        color: selected
                            ? ValleyBrandColors.cyan
                            : Colors.white.withValues(alpha: 0.44),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _BottomItem {
  const _BottomItem(this.icon, this.label);

  final IconData icon;
  final String label;
}
