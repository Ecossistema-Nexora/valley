import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String _apiBaseUrl = String.fromEnvironment(
  'VALLEY_PRODUCT_API_BASE_URL',
  defaultValue: 'https://admin.brasildesconto.com.br',
);

const Color _valleyGreen = Color(0xFF0B6B4B);
const Color _valleyGreenSoft = Color(0xFFE5F4EC);
const Color _ink = Color(0xFF111827);
const Color _muted = Color(0xFF64748B);
const Color _surface = Color(0xFFF7F9FB);
const Color _line = Color(0xFFE2E8F0);

class MerchantErpDesktopApp extends StatelessWidget {
  const MerchantErpDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Valley ERP Lojista',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _surface,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _valleyGreen,
          primary: _valleyGreen,
          secondary: const Color(0xFF0F766E),
          surface: Colors.white,
        ),
        textTheme: Typography.blackMountainView.apply(
          bodyColor: _ink,
          displayColor: _ink,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _valleyGreen, width: 1.4),
          ),
        ),
      ),
      home: const MerchantErpDesktopShell(),
    );
  }
}

class MerchantErpDesktopShell extends StatefulWidget {
  const MerchantErpDesktopShell({super.key});

  @override
  State<MerchantErpDesktopShell> createState() =>
      _MerchantErpDesktopShellState();
}

class _MerchantErpDesktopShellState extends State<MerchantErpDesktopShell> {
  _MerchantSession? _session;
  _MerchantModule? _activeModule;

  void _openSession(_MerchantSession session) {
    setState(() {
      _session = session;
      _activeModule = null;
    });
  }

  void _logout() {
    setState(() {
      _session = null;
      _activeModule = null;
    });
  }

  void _openModule(_MerchantModule module) {
    setState(() => _activeModule = module);
  }

  void _backToMenu() {
    setState(() => _activeModule = null);
  }

  @override
  Widget build(BuildContext context) {
    final _MerchantSession? session = _session;
    if (session == null) {
      return _MerchantLoginScreen(onSessionReady: _openSession);
    }
    if (_activeModule != null) {
      return _MerchantModuleScreen(
        session: session,
        module: _activeModule!,
        onBackToMenu: _backToMenu,
      );
    }
    return _MerchantMenuScreen(
      session: session,
      modules: session.modules,
      onOpenModule: _openModule,
      onLogout: _logout,
    );
  }
}

class _MerchantLoginScreen extends StatefulWidget {
  const _MerchantLoginScreen({required this.onSessionReady});

  final ValueChanged<_MerchantSession> onSessionReady;

  @override
  State<_MerchantLoginScreen> createState() => _MerchantLoginScreenState();
}

class _MerchantLoginScreenState extends State<_MerchantLoginScreen> {
  final TextEditingController _identifier = TextEditingController(
    text: 'lojista.demo@valley.local',
  );
  final TextEditingController _password = TextEditingController();
  bool _rememberDevice = true;
  bool _loading = false;
  String _status =
      'Informe as credenciais do lojista para carregar o release online.';
  bool _statusDanger = false;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String identifier = _identifier.text.trim();
    final String password = _password.text;
    if (identifier.isEmpty || password.isEmpty) {
      setState(() {
        _status = 'Informe login e senha do lojista.';
        _statusDanger = true;
      });
      return;
    }

    setState(() {
      _loading = true;
      _status = 'Validando acesso do lojista...';
      _statusDanger = false;
    });

    try {
      final http.Response response = await http
          .post(
            Uri.parse('$_apiBaseUrl/api/auth/login'),
            headers: const <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(<String, String>{
              'identifier': identifier,
              'password': password,
              'scope': 'merchant',
            }),
          )
          .timeout(const Duration(seconds: 8));
      final Object? decoded = jsonDecode(response.body);
      final Map<String, Object?> payload = decoded is Map<String, Object?>
          ? decoded
          : <String, Object?>{};
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          payload['status'] == 'ok') {
        setState(() {
          _status = 'Carregando release blueprint online...';
          _statusDanger = false;
        });
        final _MerchantSession session = await _loadReleaseBlueprint(
          _MerchantSession.fromApi(identifier: identifier, payload: payload),
        );
        widget.onSessionReady(session);
        return;
      }
      setState(() {
        _status =
            '${payload['detail'] ?? payload['message'] ?? 'Credencial recusada.'}';
        _statusDanger = true;
      });
    } on TimeoutException {
      setState(() {
        _status =
            'Servidor online nao respondeu no tempo limite. O ERP nao abre em modo demo.';
        _statusDanger = true;
      });
    } on Object catch (error) {
      setState(() {
        _status = 'Falha ao abrir o release online: $error';
        _statusDanger = true;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<_MerchantSession> _loadReleaseBlueprint(
    _MerchantSession session,
  ) async {
    final http.Response response = await http
        .get(
          Uri.parse('$_apiBaseUrl/api/merchant-erp/blueprint'),
          headers: <String, String>{
            'Accept': 'application/json',
            'Authorization': 'Bearer ${session.token}',
          },
        )
        .timeout(const Duration(seconds: 8));
    final Object? decoded = jsonDecode(response.body);
    final Map<String, Object?> payload = _asMap(decoded);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        payload['status'] != 'ok') {
      throw StateError(
        '${payload['detail'] ?? payload['message'] ?? 'Blueprint indisponivel.'}',
      );
    }
    final List<_MerchantModule> modules = _parseMerchantModules(
      payload['modules'],
    );
    if (modules.isEmpty) {
      throw StateError('Blueprint online sem modulos operacionais.');
    }
    return session.copyWith(
      syncStatus:
          'Release ${payload['release_version'] ?? 'online'} validado em ${payload['generated_at_utc'] ?? 'runtime'}',
      modules: modules,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _LoginBrandPanel(
                    title: 'Valley ERP Lojista',
                    subtitle: 'Operacao de produtos, pedidos, estoque e caixa.',
                  ),
                ),
                const SizedBox(width: 28),
                SizedBox(
                  width: 420,
                  child: _Panel(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          'Login do lojista',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Acesso da empresa para abrir o menu operacional.',
                          style: TextStyle(color: _muted),
                        ),
                        const SizedBox(height: 22),
                        TextField(
                          controller: _identifier,
                          decoration: const InputDecoration(
                            labelText: 'E-mail, CNPJ ou usuario',
                            prefixIcon: Icon(Icons.storefront_outlined),
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _password,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Senha',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          onSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 10),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _rememberDevice,
                          title: const Text('Manter dispositivo autorizado'),
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (bool? value) {
                            setState(() => _rememberDevice = value ?? false);
                          },
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _loading ? null : _submit,
                          icon: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.login_rounded),
                          label: Text(_loading ? 'Validando' : 'Entrar no ERP'),
                        ),
                        const SizedBox(height: 10),
                        _StatusLine(text: _status, danger: _statusDanger),
                      ],
                    ),
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

class _MerchantMenuScreen extends StatelessWidget {
  const _MerchantMenuScreen({
    required this.session,
    required this.modules,
    required this.onOpenModule,
    required this.onLogout,
  });

  final _MerchantSession session;
  final List<_MerchantModule> modules;
  final ValueChanged<_MerchantModule> onOpenModule;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _MerchantStatusBar(session: session, onLogout: onLogout),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Menu principal',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  _Pill(
                    label: 'Sync ativo',
                    icon: Icons.cloud_done_outlined,
                    color: _valleyGreen,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final int columns = constraints.maxWidth > 1280
                        ? 5
                        : constraints.maxWidth > 980
                        ? 4
                        : 3;
                    return GridView.builder(
                      itemCount: modules.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 1.35,
                      ),
                      itemBuilder: (BuildContext context, int index) {
                        final _MerchantModule module = modules[index];
                        return _ModuleButton(
                          module: module,
                          onPressed: () => onOpenModule(module),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MerchantModuleScreen extends StatefulWidget {
  const _MerchantModuleScreen({
    required this.session,
    required this.module,
    required this.onBackToMenu,
  });

  final _MerchantSession session;
  final _MerchantModule module;
  final VoidCallback onBackToMenu;

  @override
  State<_MerchantModuleScreen> createState() => _MerchantModuleScreenState();
}

class _MerchantModuleScreenState extends State<_MerchantModuleScreen> {
  String _filter = '';
  String _notice = 'Modulo online pronto para operar.';
  bool _noticeDanger = false;
  bool _submitting = false;

  Future<void> _submitModuleAction(String action) async {
    setState(() {
      _submitting = true;
      _notice = action == 'sync'
          ? 'Sincronizando modulo no servidor...'
          : 'Salvando evento operacional no servidor...';
      _noticeDanger = false;
    });
    try {
      final http.Response response = await http
          .post(
            Uri.parse('$_apiBaseUrl/api/merchant-erp/action'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer ${widget.session.token}',
            },
            body: jsonEncode(<String, Object?>{
              'module_key': widget.module.key,
              'module_label': widget.module.label,
              'action': action,
              'filter': _filter,
              'record_count': widget.module.records.length,
              'record_codes': widget.module.records
                  .map((_ModuleRecord record) => record.code)
                  .take(50)
                  .toList(),
            }),
          )
          .timeout(const Duration(seconds: 8));
      final Map<String, Object?> payload = _asMap(jsonDecode(response.body));
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          payload['status'] == 'ok') {
        setState(() {
          _notice =
              '${payload['message'] ?? 'Acao registrada no servidor.'} (${payload['event_id'] ?? 'sem-id'})';
          _noticeDanger = false;
        });
        return;
      }
      setState(() {
        _notice =
            '${payload['detail'] ?? payload['message'] ?? 'Acao recusada pelo servidor.'}';
        _noticeDanger = true;
      });
    } on TimeoutException {
      setState(() {
        _notice = 'Servidor nao confirmou a acao no tempo limite.';
        _noticeDanger = true;
      });
    } on Object catch (error) {
      setState(() {
        _notice = 'Falha ao registrar acao: $error';
        _noticeDanger = true;
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<_ModuleRecord> records = widget.module.records
        .where(
          (_ModuleRecord record) =>
              _filter.trim().isEmpty ||
              record.title.toLowerCase().contains(_filter.toLowerCase()) ||
              record.code.toLowerCase().contains(_filter.toLowerCase()),
        )
        .toList();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  IconButton.filledTonal(
                    tooltip: 'Menu principal',
                    onPressed: widget.onBackToMenu,
                    icon: const Icon(Icons.grid_view_rounded),
                  ),
                  const SizedBox(width: 12),
                  Icon(widget.module.icon, color: _valleyGreen, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.module.label,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          widget.module.subtitle,
                          style: const TextStyle(color: _muted),
                        ),
                      ],
                    ),
                  ),
                  _Pill(
                    label: widget.session.merchantName,
                    icon: Icons.verified_outlined,
                    color: _valleyGreen,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      onChanged: (String value) =>
                          setState(() => _filter = value),
                      decoration: const InputDecoration(
                        labelText: 'Buscar',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _submitting
                        ? null
                        : () => _submitModuleAction('save'),
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_submitting ? 'Enviando' : 'Salvar'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _submitting
                        ? null
                        : () => _submitModuleAction('sync'),
                    icon: const Icon(Icons.sync_rounded),
                    label: const Text('Sincronizar'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _StatusLine(text: _notice, danger: _noticeDanger),
              const SizedBox(height: 14),
              Expanded(
                child: _Panel(
                  padding: EdgeInsets.zero,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        _valleyGreenSoft,
                      ),
                      columns: const <DataColumn>[
                        DataColumn(label: Text('Codigo')),
                        DataColumn(label: Text('Registro')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Responsavel')),
                        DataColumn(label: Text('Atualizacao')),
                      ],
                      rows: <DataRow>[
                        for (final _ModuleRecord record in records)
                          DataRow(
                            cells: <DataCell>[
                              DataCell(Text(record.code)),
                              DataCell(Text(record.title)),
                              DataCell(
                                _RecordStatusBadge(status: record.status),
                              ),
                              DataCell(Text(record.owner)),
                              DataCell(Text(record.updatedAt)),
                            ],
                          ),
                      ],
                    ),
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

class _LoginBrandPanel extends StatelessWidget {
  const _LoginBrandPanel({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(30),
      color: const Color(0xFF0F172A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: _valleyGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            title,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: const Color(0xFFCBD5E1)),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const <Widget>[
              _DarkPill(label: 'PDV'),
              _DarkPill(label: 'Estoque'),
              _DarkPill(label: 'Pedidos'),
              _DarkPill(label: 'Financeiro'),
              _DarkPill(label: 'Marketplace'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MerchantStatusBar extends StatelessWidget {
  const _MerchantStatusBar({required this.session, required this.onLogout});

  final _MerchantSession session;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: <Widget>[
          const Icon(Icons.store_mall_directory_outlined, color: _valleyGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  session.merchantName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  session.syncStatus,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            session.displayName,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sair'),
          ),
        ],
      ),
    );
  }
}

class _ModuleButton extends StatelessWidget {
  const _ModuleButton({required this.module, required this.onPressed});

  final _MerchantModule module;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: _line),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: module.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(module.icon, color: module.color),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_rounded, color: _muted),
                ],
              ),
              const Spacer(),
              Text(
                module.label,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              Text(
                module.subtitle,
                maxLines: 2,
                style: const TextStyle(color: _muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color == null ? _line : Colors.transparent),
      ),
      child: child,
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.text, this.danger = false});

  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Color color = danger ? const Color(0xFFB91C1C) : _valleyGreen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            danger ? Icons.error_outline : Icons.check_circle_outline,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.icon, required this.color});

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _DarkPill extends StatelessWidget {
  const _DarkPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RecordStatusBadge extends StatelessWidget {
  const _RecordStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (status) {
      'OK' => _valleyGreen,
      'ATIVO' => _valleyGreen,
      'ATENCAO' => const Color(0xFFB45309),
      _ => const Color(0xFF334155),
    };
    return _Pill(label: status, icon: Icons.circle, color: color);
  }
}

class _MerchantSession {
  const _MerchantSession({
    required this.displayName,
    required this.merchantName,
    required this.identifier,
    required this.syncStatus,
    required this.token,
    required this.modules,
  });

  factory _MerchantSession.fromApi({
    required String identifier,
    required Map<String, Object?> payload,
  }) {
    final Object? rawSession = payload['session'];
    final Map<String, Object?> session = _asMap(rawSession);
    final Map<String, Object?> user = _asMap(session['user']);
    final String merchantCode = '${user['merchant_code'] ?? ''}'.trim();
    final String merchantSlug = '${user['merchant_slug'] ?? ''}'.trim();
    return _MerchantSession(
      displayName: '${user['display_name'] ?? user['name'] ?? 'Lojista'}',
      merchantName: merchantCode.isNotEmpty
          ? merchantCode
          : merchantSlug.isNotEmpty
          ? merchantSlug
          : 'Loja Valley',
      identifier: identifier,
      syncStatus: 'Sessao online validada',
      token: '${session['token'] ?? ''}',
      modules: const <_MerchantModule>[],
    );
  }

  final String displayName;
  final String merchantName;
  final String identifier;
  final String syncStatus;
  final String token;
  final List<_MerchantModule> modules;

  _MerchantSession copyWith({
    String? displayName,
    String? merchantName,
    String? identifier,
    String? syncStatus,
    String? token,
    List<_MerchantModule>? modules,
  }) {
    return _MerchantSession(
      displayName: displayName ?? this.displayName,
      merchantName: merchantName ?? this.merchantName,
      identifier: identifier ?? this.identifier,
      syncStatus: syncStatus ?? this.syncStatus,
      token: token ?? this.token,
      modules: modules ?? this.modules,
    );
  }
}

class _MerchantModule {
  const _MerchantModule({
    required this.key,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.records,
  });

  final String key;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<_ModuleRecord> records;

  factory _MerchantModule.fromMap(Map<String, Object?> map) {
    final String key = _text(map['key'], 'module');
    final List<_ModuleRecord> records = _asList(map['records'])
        .map((Object? value) => _ModuleRecord.fromMap(_asMap(value)))
        .where((_ModuleRecord record) => record.code.isNotEmpty)
        .toList();
    return _MerchantModule(
      key: key,
      label: _text(map['label'], key.toUpperCase()),
      subtitle: _text(map['subtitle'], 'Modulo online do ERP Lojista'),
      icon: _iconFor(_text(map['icon'], ''), key),
      color: _colorFromHex(map['color'], _valleyGreen),
      records: records.isNotEmpty
          ? records
          : <_ModuleRecord>[
              _ModuleRecord(
                code: '${key.toUpperCase()}-ONLINE',
                title: 'Modulo online sem pendencias registradas',
                status: 'OK',
                owner: 'Valley Runtime',
                updatedAt: 'agora',
              ),
            ],
    );
  }
}

class _ModuleRecord {
  const _ModuleRecord({
    required this.code,
    required this.title,
    required this.status,
    required this.owner,
    required this.updatedAt,
  });

  final String code;
  final String title;
  final String status;
  final String owner;
  final String updatedAt;

  factory _ModuleRecord.fromMap(Map<String, Object?> map) {
    return _ModuleRecord(
      code: _text(map['code'], ''),
      title: _text(map['title'], 'Registro operacional'),
      status: _text(map['status'], 'OK').toUpperCase(),
      owner: _text(map['owner'], 'Valley Runtime'),
      updatedAt: _text(map['updated_at'] ?? map['updatedAt'], 'agora'),
    );
  }
}

Map<String, Object?> _asMap(Object? value) {
  if (value is Map) {
    return <String, Object?>{
      for (final MapEntry<dynamic, dynamic> entry in value.entries)
        '${entry.key}': entry.value,
    };
  }
  return <String, Object?>{};
}

List<Object?> _asList(Object? value) {
  if (value is List) {
    return value.cast<Object?>();
  }
  return const <Object?>[];
}

String _text(Object? value, String fallback) {
  final String text = '${value ?? ''}'.trim();
  return text.isEmpty ? fallback : text;
}

List<_MerchantModule> _parseMerchantModules(Object? value) {
  return _asList(value)
      .map((Object? item) => _MerchantModule.fromMap(_asMap(item)))
      .where((_MerchantModule module) => module.key.isNotEmpty)
      .toList(growable: false);
}

Color _colorFromHex(Object? value, Color fallback) {
  String hex = _text(value, '').replaceAll('#', '').trim();
  if (hex.length == 6) {
    hex = 'FF$hex';
  }
  final int? parsed = int.tryParse(hex, radix: 16);
  return parsed == null ? fallback : Color(parsed);
}

IconData _iconFor(String icon, String key) {
  final String normalized = icon.isEmpty ? key : icon;
  return switch (normalized) {
    'point_of_sale' || 'sales' => Icons.point_of_sale_rounded,
    'inventory' || 'products' => Icons.inventory_2_outlined,
    'qr_code' || 'stock' => Icons.qr_code_scanner_rounded,
    'receipt' || 'orders' => Icons.receipt_long_rounded,
    'groups' || 'customers' => Icons.groups_2_outlined,
    'wallet' || 'finance' => Icons.account_balance_wallet_outlined,
    'payments' || 'checkout' => Icons.payments_outlined,
    'local_shipping' || 'delivery' => Icons.local_shipping_outlined,
    'hub' || 'marketplace' => Icons.hub_outlined,
    'bar_chart' || 'reports' => Icons.bar_chart_rounded,
    'admin_panel' || 'settings' => Icons.admin_panel_settings_outlined,
    'support_agent' || 'support' => Icons.support_agent_rounded,
    _ => Icons.apps_rounded,
  };
}
