import 'package:flutter/material.dart';
import 'package:valley_super_app/src/data/valley_models.dart';
import 'package:valley_super_app/src/data/valley_repository.dart';
import 'package:valley_super_app/src/ui/valley_home_shell.dart';
import 'package:valley_super_app/valley_brand_theme.dart';

class ValleySuperApp extends StatefulWidget {
  const ValleySuperApp({super.key});

  @override
  State<ValleySuperApp> createState() => _ValleySuperAppState();
}

class _ValleySuperAppState extends State<ValleySuperApp> {
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
            return const _ValleyFailureScreen();
          }

          return ValleyHomeShell(data: snapshot.data!);
        },
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
                  'Preparando sua experiencia premium.',
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
  const _ValleyFailureScreen();

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
                  'Nao foi possivel iniciar o Valley.',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Tente novamente em alguns instantes. A experiencia sera carregada automaticamente quando os dados estiverem disponiveis.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
