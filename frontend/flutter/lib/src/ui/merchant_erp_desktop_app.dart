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
      modules: _merchantModules,
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
  String _status = 'Sessao local pronta para o ERP Lojista.';
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
        widget.onSessionReady(
          _MerchantSession.fromApi(identifier: identifier, payload: payload),
        );
        return;
      }
      setState(() {
        _status =
            '${payload['detail'] ?? payload['message'] ?? 'Credencial recusada.'}';
        _statusDanger = true;
      });
    } on TimeoutException {
      _openLocalSession(identifier, 'API sem resposta no tempo limite');
    } on Object {
      _openLocalSession(
        identifier,
        'Sessao local criada para ambiente offline',
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _openDemoSession() {
    _openLocalSession('lojista.demo@valley.local', 'Sessao demonstracao local');
  }

  void _openLocalSession(String identifier, String reason) {
    widget.onSessionReady(
      _MerchantSession(
        displayName: 'Lojista Demo',
        merchantName: 'Loja Valley Demo',
        identifier: identifier,
        syncStatus: reason,
        token: '',
      ),
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
                        OutlinedButton.icon(
                          onPressed: _loading ? null : _openDemoSession,
                          icon: const Icon(Icons.monitor_heart_outlined),
                          label: const Text('Abrir sessao local'),
                        ),
                        const SizedBox(height: 16),
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
  String _notice = 'Pronto para operar.';

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
                    onPressed: () {
                      setState(
                        () => _notice =
                            '${widget.module.label}: alteracoes salvas.',
                      );
                    },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Salvar'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(
                        () => _notice =
                            '${widget.module.label}: sincronizacao enviada.',
                      );
                    },
                    icon: const Icon(Icons.sync_rounded),
                    label: const Text('Sincronizar'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _StatusLine(text: _notice),
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
  });

  factory _MerchantSession.fromApi({
    required String identifier,
    required Map<String, Object?> payload,
  }) {
    final Object? rawSession = payload['session'];
    final Map<String, Object?> session = rawSession is Map<String, Object?>
        ? rawSession
        : <String, Object?>{};
    final Object? rawUser = session['user'];
    final Map<String, Object?> user = rawUser is Map<String, Object?>
        ? rawUser
        : <String, Object?>{};
    return _MerchantSession(
      displayName: '${user['display_name'] ?? user['name'] ?? 'Lojista'}',
      merchantName: '${user['merchant_name'] ?? 'Loja Valley'}',
      identifier: identifier,
      syncStatus: 'Sessao online validada',
      token: '${session['token'] ?? ''}',
    );
  }

  final String displayName;
  final String merchantName;
  final String identifier;
  final String syncStatus;
  final String token;
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
}

const List<_ModuleRecord> _defaultRecords = <_ModuleRecord>[
  _ModuleRecord(
    code: 'VL-1001',
    title: 'Pedido marketplace sincronizado',
    status: 'OK',
    owner: 'Operacao',
    updatedAt: 'Hoje 09:10',
  ),
  _ModuleRecord(
    code: 'VL-1002',
    title: 'SKU aguardando imagem final',
    status: 'ATENCAO',
    owner: 'Produtos',
    updatedAt: 'Hoje 09:24',
  ),
  _ModuleRecord(
    code: 'VL-1003',
    title: 'Reposicao de estoque aprovada',
    status: 'OK',
    owner: 'Estoque',
    updatedAt: 'Hoje 10:02',
  ),
  _ModuleRecord(
    code: 'VL-1004',
    title: 'Conciliacao de fatura pendente',
    status: 'ATENCAO',
    owner: 'Financeiro',
    updatedAt: 'Hoje 10:18',
  ),
];

final List<_MerchantModule> _merchantModules = <_MerchantModule>[
  _MerchantModule(
    key: 'sales',
    label: 'Vendas',
    subtitle: 'PDV, carrinho e fechamento',
    icon: Icons.point_of_sale_rounded,
    color: const Color(0xFF0F766E),
    records: _defaultRecords,
  ),
  _MerchantModule(
    key: 'products',
    label: 'Produtos',
    subtitle: 'SKU, preco, imagens e canais',
    icon: Icons.inventory_2_outlined,
    color: const Color(0xFF2563EB),
    records: _defaultRecords,
  ),
  _MerchantModule(
    key: 'stock',
    label: 'Estoque',
    subtitle: 'Entradas, saidas e inventario',
    icon: Icons.qr_code_scanner_rounded,
    color: const Color(0xFF7C3AED),
    records: _defaultRecords,
  ),
  _MerchantModule(
    key: 'orders',
    label: 'Pedidos',
    subtitle: 'Separacao, status e entrega',
    icon: Icons.receipt_long_rounded,
    color: const Color(0xFFB45309),
    records: _defaultRecords,
  ),
  _MerchantModule(
    key: 'customers',
    label: 'Clientes',
    subtitle: 'Cadastro, historico e suporte',
    icon: Icons.groups_2_outlined,
    color: const Color(0xFF0891B2),
    records: _defaultRecords,
  ),
  _MerchantModule(
    key: 'finance',
    label: 'Financeiro',
    subtitle: 'Recebiveis, taxas e repasses',
    icon: Icons.account_balance_wallet_outlined,
    color: const Color(0xFF16A34A),
    records: _defaultRecords,
  ),
  _MerchantModule(
    key: 'checkout',
    label: 'Checkout',
    subtitle: 'Faturas, pagamento e comprovante',
    icon: Icons.payments_outlined,
    color: const Color(0xFF4F46E5),
    records: _defaultRecords,
  ),
  _MerchantModule(
    key: 'delivery',
    label: 'Entregas',
    subtitle: 'Frete, etiqueta e rastreio',
    icon: Icons.local_shipping_outlined,
    color: const Color(0xFFDC2626),
    records: _defaultRecords,
  ),
  _MerchantModule(
    key: 'marketplace',
    label: 'Marketplace',
    subtitle: 'Canais, anuncios e publicacao',
    icon: Icons.hub_outlined,
    color: const Color(0xFF9333EA),
    records: _defaultRecords,
  ),
  _MerchantModule(
    key: 'reports',
    label: 'Relatorios',
    subtitle: 'Margem, ruptura e ranking',
    icon: Icons.bar_chart_rounded,
    color: const Color(0xFF475569),
    records: _defaultRecords,
  ),
  _MerchantModule(
    key: 'settings',
    label: 'Configuracoes',
    subtitle: 'Loja, usuarios e permissoes',
    icon: Icons.admin_panel_settings_outlined,
    color: const Color(0xFF0F172A),
    records: _defaultRecords,
  ),
  _MerchantModule(
    key: 'support',
    label: 'Suporte Helena',
    subtitle: 'Atendimento e chamados',
    icon: Icons.support_agent_rounded,
    color: _valleyGreen,
    records: _defaultRecords,
  ),
];
