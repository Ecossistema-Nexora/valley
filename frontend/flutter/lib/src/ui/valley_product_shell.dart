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
  double _dockX = 0.78;

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
        final Uri uri = Uri.parse(result.url);
        await launchUrl(uri, mode: LaunchMode.platformDefault);
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

  @override
  Widget build(BuildContext context) {
    final List<ProductItem> filtered = _filteredItems;
    ProductModule? selectedModule;
    for (final ProductModule module in _data.modules) {
      if (module.id == _selectedModuleId) {
        selectedModule = module;
        break;
      }
    }
    selectedModule ??= _data.modules.isEmpty ? null : _data.modules.first;

    return Scaffold(
      backgroundColor: ValleyBrandColors.night,
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
              RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  children: <Widget>[
                    ValleyPanel(
                      padding: const EdgeInsets.all(22),
                      radius: 30,
                      glowColor: ValleyBrandColors.cyan,
                      background: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          Colors.white.withValues(alpha: 0.08),
                          ValleyBrandColors.panelDarkStrong.withValues(alpha: 0.92),
                          ValleyBrandColors.night.withValues(alpha: 0.96),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              const ValleyLogoMark(size: 56, borderRadius: 18),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      _data.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(fontWeight: FontWeight.w900),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _data.subtitle,
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
                              FilledButton(
                                onPressed: _busy ? null : _refresh,
                                child: _busy
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Atualizar'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          TextField(
                            onChanged: (String value) => setState(() => _query = value),
                            style: Theme.of(context).textTheme.bodyLarge,
                            decoration: InputDecoration(
                              hintText: 'Buscar produtos, marcas e categorias',
                              prefixIcon: const Icon(Icons.search_rounded),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.06),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: <Widget>[
                              SignalChip(
                                label: '${_data.summary.products} produtos',
                                color: ValleyBrandColors.cyan,
                              ),
                              SignalChip(
                                label: '${_data.summary.videos} videos',
                                color: ValleyBrandColors.violet,
                              ),
                              SignalChip(
                                label: '${_data.summary.merchants} lojas',
                                color: ValleyBrandColors.success,
                              ),
                              SignalChip(
                                label: '${_data.summary.warehouses} hubs',
                                color: ValleyBrandColors.warning,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: MediaQuery.sizeOf(context).width >= 1100 ? 4 : 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 1.08,
                      children: <Widget>[
                        _SummaryCard(
                          label: 'Modulo',
                          value: selectedModule?.label ?? 'Valley',
                          accent: ValleyBrandColors.cyan,
                        ),
                        _SummaryCard(
                          label: 'Itens ativos',
                          value: '${filtered.length}',
                          accent: ValleyBrandColors.violet,
                        ),
                        _SummaryCard(
                          label: 'Videos',
                          value: '${filtered.fold<int>(0, (int sum, ProductItem item) => sum + item.videoCount)}',
                          accent: ValleyBrandColors.success,
                        ),
                        _SummaryCard(
                          label: 'Link externo',
                          value: _data.publicUrl.isEmpty ? 'Local' : 'Publico',
                          accent: ValleyBrandColors.warning,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (selectedModule != null)
                      SectionHeader(
                        kicker: selectedModule.id,
                        title: selectedModule.label,
                        caption: selectedModule.subtitle,
                      ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) {
                        final double width = constraints.maxWidth;
                        int crossAxisCount = 1;
                        if (width >= 1200) {
                          crossAxisCount = 3;
                        } else if (width >= 700) {
                          crossAxisCount = 2;
                        }
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filtered.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: width >= 1200 ? 0.84 : 0.80,
                          ),
                          itemBuilder: (BuildContext context, int index) {
                            final ProductItem item = filtered[index];
                            return _ProductCard(
                              item: item,
                              busy: _busy,
                              onPrimary: () => _runItemAction(item.ctaPath),
                              onMedia: item.mediaPath.isEmpty
                                  ? null
                                  : () => _runItemAction(item.mediaPath),
                            );
                          },
                        );
                      },
                    ),
                    if (filtered.isEmpty) ...<Widget>[
                      const SizedBox(height: 18),
                      ValleyPanel(
                        child: Center(
                          child: Text(
                            'Nenhum resultado encontrado.',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _FloatingModuleDock(
                modules: _data.modules,
                expanded: _dockExpanded,
                selectedModuleId: _selectedModuleId,
                alignmentX: _dockX,
                onToggle: () => setState(() => _dockExpanded = !_dockExpanded),
                onPanUpdate: (DragUpdateDetails details) {
                  final double width = MediaQuery.sizeOf(context).width;
                  setState(() {
                    _dockX = (_dockX + (details.delta.dx / math.max(width, 1)) * 2)
                        .clamp(-0.82, 0.82);
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
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ValleyPanel(
      padding: const EdgeInsets.all(18),
      glowColor: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.item,
    required this.busy,
    required this.onPrimary,
    required this.onMedia,
  });

  final ProductItem item;
  final bool busy;
  final VoidCallback onPrimary;
  final VoidCallback? onMedia;

  @override
  Widget build(BuildContext context) {
    return ValleyPanel(
      padding: EdgeInsets.zero,
      radius: 30,
      glowColor: ValleyBrandColors.violet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Image.network(
                    item.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: ValleyBrandColors.panelDarkStrong,
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.black.withValues(alpha: 0.04),
                          Colors.black.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    left: 14,
                    child: SignalChip(
                      label: item.status,
                      color: item.stock > 15
                          ? ValleyBrandColors.success
                          : ValleyBrandColors.warning,
                    ),
                  ),
                  Positioned(
                    top: 14,
                    right: 14,
                    child: SignalChip(
                      label: '${item.videoCount} video',
                      color: ValleyBrandColors.cyan,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.brand,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: ValleyBrandColors.cyan,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  item.merchantName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: item.tags
                      .map(
                        (String tag) => SignalChip(
                          label: tag,
                          color: ValleyBrandColors.violet,
                          outlined: true,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Text(
                      'R\$ ${item.priceBrl.toStringAsFixed(2)}',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(width: 10),
                    if (item.compareAtBrl > item.priceBrl)
                      Text(
                        'R\$ ${item.compareAtBrl.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              decoration: TextDecoration.lineThrough,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    const Spacer(),
                    Text(
                      '${item.stock} un.',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: ValleyBrandColors.success,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton(
                        onPressed: busy ? null : onPrimary,
                        child: Text(item.ctaLabel),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (onMedia != null)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: busy ? null : onMedia,
                          child: const Text('Video'),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingModuleDock extends StatelessWidget {
  const _FloatingModuleDock({
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
      alignment: Alignment(alignmentX, 0.88),
      child: GestureDetector(
        onPanUpdate: onPanUpdate,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: expanded ? 280 : 76,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: ValleyBrandColors.panelDarkStrong.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: ValleyBrandColors.cyan.withValues(alpha: 0.32),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: ValleyBrandColors.cyan.withValues(alpha: 0.12),
                blurRadius: 30,
                offset: const Offset(0, 16),
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
                    ),
                  ],
                )
              : IconButton(
                  onPressed: onToggle,
                  icon: const Icon(Icons.apps_rounded),
                  color: ValleyBrandColors.snow,
                ),
        ),
      ),
    );
  }
}
