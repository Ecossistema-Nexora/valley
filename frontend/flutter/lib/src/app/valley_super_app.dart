import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:valley_super_app/src/data/product_api_models.dart';
import 'package:valley_super_app/src/data/product_api_repository.dart';
import 'package:valley_super_app/src/ui/valley_product_shell.dart';
import 'package:valley_super_app/valley_brand_theme.dart';

class ValleySuperApp extends StatefulWidget {
  const ValleySuperApp({super.key});

  @override
  State<ValleySuperApp> createState() => _ValleySuperAppState();
}

class _ValleySuperAppState extends State<ValleySuperApp> {
  final ProductApiRepository _repository = const ProductApiRepository();
  late Future<ProductShellData> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _repository.load();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Valley',
      debugShowCheckedModeBanner: false,
      theme: ValleyBrandTheme.light(),
      darkTheme: ValleyBrandTheme.dark(),
      themeMode: ThemeMode.dark,
      home: FutureBuilder<ProductShellData>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<ProductShellData> snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _LoadingScreen();
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return _FailureScreen(
              onRetry: () {
                setState(_reload);
              },
            );
          }

          return ValleyProductShell(
            initialData: snapshot.data!,
            repository: _repository,
          );
        },
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

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
        child: const Center(
          child: CircularProgressIndicator(
            color: ValleyBrandColors.cyan,
          ),
        ),
      ),
    );
  }
}

class _FailureScreen extends StatelessWidget {
  const _FailureScreen({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ValleyBrandColors.night,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const ValleyLogoMark(size: 72, borderRadius: 22),
              const SizedBox(height: 18),
              Text(
                'Servidor indisponivel',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  FilledButton(
                    onPressed: onRetry,
                    child: const Text('Atualizar'),
                  ),
                  OutlinedButton(
                    onPressed: SystemNavigator.pop,
                    child: const Text('Fechar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
