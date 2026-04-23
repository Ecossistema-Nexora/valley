import 'package:flutter/material.dart';
import 'package:valley_super_app/src/data/valley_models.dart';
import 'package:valley_super_app/src/data/valley_repository.dart';
import 'package:valley_super_app/src/ui/ui_components.dart';
import 'package:valley_super_app/src/ui/valley_home_shell.dart';
import 'package:valley_super_app/valley_brand_theme.dart';

class ValleySuperApp extends StatefulWidget {
  const ValleySuperApp({super.key});

  @override
  State<ValleySuperApp> createState() => _ValleySuperAppState();
}

class _ValleySuperAppState extends State<ValleySuperApp> {
  static const String _demoUsername = '@anderson';
  static const String _demoPassword = '@Aa35930253';
  static const String _demoRole = 'admin';
  late final Future<ValleyAppData> _future;

  @override
  void initState() {
    super.initState();
    _future = const ValleyRepository().load();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Valley Super App',
      debugShowCheckedModeBanner: false,
      theme: ValleyBrandTheme.light(),
      darkTheme: ValleyBrandTheme.dark(),
      themeMode: ThemeMode.dark,
      home: FutureBuilder<ValleyAppData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _ValleyLoadingScreen();
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return _ValleyFailureScreen(error: snapshot.error);
          }

          return _ValleyAccessGate(
            data: snapshot.data!,
            username: _demoUsername,
            password: _demoPassword,
            role: _demoRole,
          );
        },
      ),
    );
  }
}

class _ValleyAccessGate extends StatefulWidget {
  const _ValleyAccessGate({
    required this.data,
    required this.username,
    required this.password,
    required this.role,
  });

  final ValleyAppData data;
  final String username;
  final String password;
  final String role;

  @override
  State<_ValleyAccessGate> createState() => _ValleyAccessGateState();
}

class _ValleyAccessGateState extends State<_ValleyAccessGate> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _authenticated = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final String username = _usernameController.text.trim();
    final String password = _passwordController.text;
    final bool ok = username == widget.username && password == widget.password;

    setState(() {
      _authenticated = ok;
      _error = ok ? null : 'Credenciais invalidas para o ambiente de teste.';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_authenticated) {
      return ValleyHomeShell(data: widget.data);
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              ValleyBrandColors.night,
              ValleyBrandColors.cosmic,
              Color(0xFF120C39),
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const ValleyLogoMark(size: 72, borderRadius: 22),
                      const SizedBox(height: 20),
                      Text(
                        'Acesso de teste Valley',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          SignalChip(
                            label: 'perfil ${widget.role}',
                            color: ValleyBrandColors.success,
                          ),
                          const SignalChip(
                            label: 'build release',
                            color: ValleyBrandColors.cyan,
                            outlined: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Ambiente publicado para validacao controlada do MVP. Entre com as credenciais recebidas para liberar o shell Web e Android.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _usernameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Usuario',
                          prefixIcon: Icon(Icons.person_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _passwordController,
                        obscureText: _hidePassword,
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: const Icon(Icons.lock_rounded),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() => _hidePassword = !_hidePassword);
                            },
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                            ),
                          ),
                        ),
                      ),
                      if (_error != null) ...<Widget>[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: ValleyBrandColors.warning),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _submit,
                          child: const Text('Entrar no ambiente'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ValleyLoadingScreen extends StatelessWidget {
  const _ValleyLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              ValleyBrandColors.night,
              ValleyBrandColors.cosmic,
              Color(0xFF120C39),
            ],
          ),
        ),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.6, end: 1),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.scale(scale: value, child: child),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const ValleyLogoMark(size: 96, borderRadius: 28),
                const SizedBox(height: 24),
                Text(
                  'Valley Super App',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: ValleyBrandColors.snow,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Carregando o cockpit do MVP e os 47 modulos.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: ValleyBrandColors.snow.withValues(alpha: 0.76),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const SizedBox(
                  width: 220,
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                    backgroundColor: Color(0x3320C8F3),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      ValleyBrandColors.cyan,
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

class _ValleyFailureScreen extends StatelessWidget {
  const _ValleyFailureScreen({this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const ValleyLogoMark(size: 72, borderRadius: 22),
                const SizedBox(height: 24),
                Text(
                  'Nao foi possivel iniciar o release shell.',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Verifique os assets JSON do MVP e dos modulos. O app depende deles para montar as superficies reais do Valley.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                if (error != null) ...<Widget>[
                  const SizedBox(height: 16),
                  Text(
                    '$error',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ValleyBrandColors.warning,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
