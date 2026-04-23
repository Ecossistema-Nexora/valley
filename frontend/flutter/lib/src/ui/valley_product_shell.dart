import 'package:flutter/material.dart';
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
  String? _activeActionId;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
  }

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _activeActionId = 'refresh';
    });
    try {
      final ProductShellData fresh = await widget.repository.load();
      if (!mounted) {
        return;
      }
      setState(() => _data = fresh);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _activeActionId = null;
        });
      }
    }
  }

  Future<void> _runAction(ProductAction action) async {
    setState(() {
      _busy = true;
      _activeActionId = action.id;
    });
    try {
      final ProductActionResult result = await widget.repository.invoke(
        baseUrl: _data.baseUrl,
        action: action,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(result.message),
          backgroundColor: result.ok
              ? ValleyBrandColors.success
              : ValleyBrandColors.danger,
        ),
      );
      final ProductShellData fresh = await widget.repository.load();
      if (!mounted) {
        return;
      }
      setState(() => _data = fresh);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _activeActionId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: <Widget>[
                    ValleyPanel(
                      padding: const EdgeInsets.all(20),
                      radius: 30,
                      glowColor: ValleyBrandColors.cyan,
                      background: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          Colors.white.withValues(alpha: 0.08),
                          ValleyBrandColors.panelDarkStrong.withValues(alpha: 0.88),
                          ValleyBrandColors.night.withValues(alpha: 0.88),
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
                                child: Text(
                                  'Valley',
                                  style: Theme.of(context).textTheme.headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                              ),
                              _StatusDot(active: _data.serverOk),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: <Widget>[
                              SignalChip(
                                label: _data.serverOk ? 'Servidor' : 'Offline',
                                color: _data.serverOk
                                    ? ValleyBrandColors.success
                                    : ValleyBrandColors.danger,
                              ),
                              SignalChip(
                                label: _data.telegramReady ? 'Telegram' : 'Telegram off',
                                color: _data.telegramReady
                                    ? ValleyBrandColors.cyan
                                    : ValleyBrandColors.danger,
                              ),
                              SignalChip(
                                label: _data.whatsappReady ? 'WhatsApp' : 'WhatsApp off',
                                color: _data.whatsappReady
                                    ? ValleyBrandColors.success
                                    : ValleyBrandColors.warning,
                              ),
                              if (_data.publicUrl.isNotEmpty)
                                const SignalChip(
                                  label: 'Externo',
                                  color: ValleyBrandColors.violet,
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
                      crossAxisCount: MediaQuery.sizeOf(context).width >= 900 ? 3 : 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 1.2,
                      children: <Widget>[
                        _MetricCard(label: 'Atividade', value: _data.activityName),
                        _MetricCard(
                          label: 'Progresso',
                          value: '${_data.progressPercent}%',
                        ),
                        _MetricCard(label: 'Base', value: _data.service),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ValleyPanel(
                      padding: const EdgeInsets.all(18),
                      radius: 28,
                      glowColor: ValleyBrandColors.violet,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Acoes',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: <Widget>[
                              FilledButton(
                                onPressed: _busy ? null : _refresh,
                                child: _activeActionId == 'refresh'
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text('Atualizar'),
                              ),
                              for (final ProductAction action in _data.actions)
                                FilledButton(
                                  onPressed: _busy ? null : () => _runAction(action),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: action.id == 'pulse-telegram'
                                        ? ValleyBrandColors.cyan
                                        : action.id == 'whatsapp-status'
                                            ? ValleyBrandColors.success
                                            : ValleyBrandColors.violet,
                                  ),
                                  child: _activeActionId == action.id
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : Text(action.label),
                                ),
                            ],
                          ),
                        ],
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ValleyPanel(
      padding: const EdgeInsets.all(18),
      radius: 24,
      glowColor: ValleyBrandColors.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? ValleyBrandColors.success : ValleyBrandColors.danger,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: (active ? ValleyBrandColors.success : ValleyBrandColors.danger)
                .withValues(alpha: 0.32),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}
