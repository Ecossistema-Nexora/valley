import 'dart:math' as math;

import 'package:flutter/material.dart';
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
  bool _dockExpanded = false;
  double _dockX = 0.84;
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
    if (_data.modules.isNotEmpty) {
      _selectedModuleId = _data.modules.first.id;
    }
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
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
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
        onTap: (ProductItem item) => _runItemAction(item.ctaPath),
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
                  onPrimary: () => _runItemAction(item.ctaPath),
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
          onTap: (ProductItem item) => _runItemAction(item.ctaPath),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<ProductItem> items = _filteredItems;
    final ProductModule? module = _selectedModule;
    final ProductItem? heroItem = items.isEmpty ? null : items.first;
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
                            if (heroItem != null)
                              _HeroSection(
                                item: heroItem,
                                subtitle: _data.subtitle,
                                onPrimary: _busy
                                    ? null
                                    : () => _runItemAction(heroItem.ctaPath),
                              ),
                            const SizedBox(height: 18),
                            _IndicatorGrid(
                              summary: _data.summary,
                              selectedModule: module,
                              itemCount: items.length,
                            ),
                            const SizedBox(height: 28),
                            _buildModuleSection(
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
                  setState(() {
                    _selectedModuleId = module.id;
                    _dockExpanded = false;
                  });
                },
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
            if (value == 1) {
              _selectedModuleId = 'MARKETPLACE';
            } else if (value == 2) {
              _selectedModuleId = 'STOCK';
            }
          });
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
      _BottomItem(Icons.explore_rounded, 'Explorar'),
      _BottomItem(Icons.add_circle_rounded, 'Ação'),
      _BottomItem(Icons.notifications_rounded, 'Alertas'),
      _BottomItem(Icons.segment_rounded, 'Menu'),
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
