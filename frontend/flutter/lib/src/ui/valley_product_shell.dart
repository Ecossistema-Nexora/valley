import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:valley_super_app/src/data/product_api_models.dart';
import 'package:valley_super_app/src/data/product_api_repository.dart';
import 'package:valley_super_app/src/ui/ui_components.dart';
import 'package:valley_super_app/valley_brand_theme.dart';

ValleySurfacePalette _surfacePalette(BuildContext context) =>
    Theme.of(context).extension<ValleySurfacePalette>()!;

bool _useLightTemplate(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light;

Color _softContainerColor(
  BuildContext context, {
  double lightAlpha = 0.94,
  double darkAlpha = 0.06,
}) {
  final ValleySurfacePalette palette = _surfacePalette(context);
  return _useLightTemplate(context)
      ? palette.panelStrong.withValues(alpha: lightAlpha)
      : Colors.white.withValues(alpha: darkAlpha);
}

Color _softBorderColor(
  BuildContext context, {
  double lightAlpha = 1,
  double darkAlpha = 0.08,
}) {
  final ValleySurfacePalette palette = _surfacePalette(context);
  return _useLightTemplate(context)
      ? palette.border.withValues(alpha: lightAlpha)
      : Colors.white.withValues(alpha: darkAlpha);
}

Color _mediaStageColor(BuildContext context) => _useLightTemplate(context)
    ? const Color(0xFFF4F7FF)
    : const Color(0xFF0E1323);

const List<_StitchP0MobileStep> _stitchP0MobileSteps = <_StitchP0MobileStep>[
  _StitchP0MobileStep(
    key: 'login',
    icon: Icons.login_rounded,
    title: 'Login',
    detail: 'sessão segura',
  ),
  _StitchP0MobileStep(
    key: 'checkout',
    icon: Icons.shopping_cart_checkout_rounded,
    title: 'Checkout',
    detail: 'frete e pagamento',
  ),
  _StitchP0MobileStep(
    key: 'purchases',
    icon: Icons.receipt_long_rounded,
    title: 'Compras',
    detail: 'pedidos salvos',
  ),
  _StitchP0MobileStep(
    key: 'tracking',
    icon: Icons.local_shipping_rounded,
    title: 'Rastreio',
    detail: 'linha da entrega',
  ),
];

class _StitchP0MobileStep {
  const _StitchP0MobileStep({
    required this.key,
    required this.icon,
    required this.title,
    required this.detail,
  });

  final String key;
  final IconData icon;
  final String title;
  final String detail;
}

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
  static bool get _helenaEnabled => false;
  static bool get _moduleDockEnabled => false;
  static const Set<String> _activeMvpModuleIds = <String>{
    'MARKETPLACE',
    'STOCK',
    'CHAT',
    'PAY',
  };

  late ProductShellData _data;
  bool _busy = false;
  String _query = '';
  String _selectedModuleId = 'STOCK';
  String _surface = 'home';
  int _navIndex = 0;
  ProductItem? _selectedItem;
  Map<String, dynamic>? _selectedConversation;
  final List<ProductItem> _cartItems = <ProductItem>[];
  ProductItem? _confirmedOrderItem;
  final List<_NavigationSnapshot> _navigationHistory = <_NavigationSnapshot>[];
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _speech = SpeechToText();
  DateTime? _lastBackPressAt;
  bool _helenaMinimized = true;
  bool _helenaListening = false;
  bool _helenaVoiceReady = false;
  Offset _helenaAlignment = const Offset(0.84, 0.60);
  String _helenaMood = 'calm';
  String _helenaMessage =
      'Helena pronta para acompanhar sua jornada com calma.';
  String _helenaTranscript = 'Toque no microfone se quiser falar comigo.';
  ProductAuthSession? _authSession;
  bool _authBusy = false;
  String _authFeedback = '';
  bool _useProfileDeliveryAddress = true;

  List<_PrimaryNavItem> get _primaryNavItems {
    final Set<String> moduleIds = _data.modules
        .map((ProductModule module) => module.id)
        .toSet();
    final List<_PrimaryNavItem> items = <_PrimaryNavItem>[];
    if (moduleIds.contains('MARKETPLACE')) {
      items.add(
        const _PrimaryNavItem(
          icon: Icons.storefront_rounded,
          label: 'Market',
          moduleId: 'MARKETPLACE',
        ),
      );
    }
    if (moduleIds.contains('STOCK')) {
      items.add(
        const _PrimaryNavItem(
          icon: Icons.inventory_2_rounded,
          label: 'Stock',
          moduleId: 'STOCK',
        ),
      );
    }
    if (moduleIds.contains('CHAT')) {
      items.add(
        const _PrimaryNavItem(
          icon: Icons.forum_rounded,
          label: 'Chat',
          moduleId: 'CHAT',
        ),
      );
    }
    items.addAll(const <_PrimaryNavItem>[
      _PrimaryNavItem(
        icon: Icons.shopping_cart_checkout_rounded,
        label: 'Checkout',
        surface: 'checkout_nav',
      ),
      _PrimaryNavItem(
        icon: Icons.person_rounded,
        label: 'Perfil',
        surface: 'profile',
      ),
    ]);
    return items;
  }

  int _navIndexForModule(String moduleId) {
    final int itemIndex = _primaryNavItems.indexWhere(
      (_PrimaryNavItem item) => item.moduleId == moduleId,
    );
    return itemIndex >= 0 ? itemIndex : 0;
  }

  int _navIndexForSurfaceItem(String surface) {
    final int itemIndex = _primaryNavItems.indexWhere(
      (_PrimaryNavItem item) => item.surface == surface,
    );
    return itemIndex >= 0 ? itemIndex : 0;
  }

  int _navIndexForSurface(String surface) {
    if (surface == 'chat') {
      return _navIndexForModule('CHAT');
    }
    if (surface == 'checkout' ||
        surface == 'confirmation' ||
        surface == 'receipt') {
      return _navIndexForSurfaceItem('checkout_nav');
    }
    if (surface == 'identity' || surface == 'client') {
      return _navIndexForSurfaceItem('profile');
    }
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
    if (_data.modules.any((ProductModule module) => module.id == 'STOCK')) {
      _selectedModuleId = 'STOCK';
    } else if (_data.modules.any(
      (ProductModule module) => module.id == 'MARKETPLACE',
    )) {
      _selectedModuleId = 'MARKETPLACE';
    } else if (_data.modules.isNotEmpty) {
      _selectedModuleId = _data.modules.first.id;
    }
    _navIndex = _navIndexForModule(_selectedModuleId);
    _restoreAuthSession();
  }

  Future<void> _restoreAuthSession() async {
    try {
      final ProductAuthResult result = await widget.repository.restoreSession(
        baseUrl: _data.baseUrl,
      );
      if (!mounted || !result.ok || result.session == null) {
        return;
      }
      setState(() {
        _authSession = result.session;
        _authFeedback = '';
      });
    } catch (_) {
      // Mantemos o shell navegável mesmo sem sessão restaurada.
    }
  }

  Future<void> _configureHelenaVoice() async {
    try {
      final dynamic availableVoices = await _tts.getVoices;
      final Map<String, String>? preferredVoice = _selectPreferredHelenaVoice(
        availableVoices,
      );
      if (preferredVoice != null) {
        await _tts.setVoice(preferredVoice);
      }
    } catch (_) {
      // O motor de TTS varia por plataforma; se a selecao falhar, mantemos pt-BR.
    }
  }

  Map<String, String>? _selectPreferredHelenaVoice(dynamic availableVoices) {
    if (availableVoices is! List<dynamic>) {
      return null;
    }

    final List<Map<String, String>> ptBrVoices = <Map<String, String>>[];
    for (final dynamic voice in availableVoices) {
      if (voice is! Map<dynamic, dynamic>) {
        continue;
      }
      final Map<String, String> entry = voice.map(
        (dynamic key, dynamic value) =>
            MapEntry(key.toString(), value.toString()),
      );
      final String locale = (entry['locale'] ?? entry['language'] ?? '')
          .toLowerCase();
      if (locale.contains('pt-br') || locale.contains('pt_br')) {
        ptBrVoices.add(entry);
      }
    }

    if (ptBrVoices.isEmpty) {
      return null;
    }

    ptBrVoices.sort(
      (Map<String, String> left, Map<String, String> right) =>
          _scoreHelenaVoice(right).compareTo(_scoreHelenaVoice(left)),
    );

    final Map<String, String> preferred = ptBrVoices.first;
    final String? name = preferred['name'];
    final String? locale = preferred['locale'] ?? preferred['language'];
    if (name == null || locale == null) {
      return null;
    }
    return <String, String>{'name': name, 'locale': locale};
  }

  int _scoreHelenaVoice(Map<String, String> voice) {
    final String fingerprint =
        '${voice['name'] ?? ''} ${voice['identifier'] ?? ''}'.toLowerCase();
    int score = 0;
    if (fingerprint.contains('female') ||
        fingerprint.contains('feminina') ||
        fingerprint.contains('woman')) {
      score += 4;
    }
    if (fingerprint.contains('brasil') ||
        fingerprint.contains('local') ||
        fingerprint.contains('pt-br')) {
      score += 2;
    }
    if (fingerprint.contains('maria') ||
        fingerprint.contains('luciana') ||
        fingerprint.contains('beatriz') ||
        fingerprint.contains('ana')) {
      score += 1;
    }
    return score;
  }

  Future<void> _speakHelena(String text) async {
    if (!_helenaEnabled) {
      return;
    }
    _helenaMessage = text;
    if (mounted) {
      setState(() {});
    }
    await _tts.stop();
    await _tts.speak(text);
  }

  void _setHelenaMood(String mood, String message) {
    if (!_helenaEnabled) {
      return;
    }
    setState(() {
      _helenaMood = mood;
      _helenaMessage = message;
    });
    _speakHelena(message);
  }

  _NavigationSnapshot _currentSnapshot() {
    return _NavigationSnapshot(
      moduleId: _selectedModuleId,
      surface: _surface,
      navIndex: _navIndex,
      selectedItem: _selectedItem,
      selectedConversation: _selectedConversation,
    );
  }

  void _rememberNavigationState() {
    final _NavigationSnapshot snapshot = _currentSnapshot();
    if (_navigationHistory.isNotEmpty &&
        _navigationHistory.last.isSameState(snapshot)) {
      return;
    }
    _navigationHistory.add(snapshot);
  }

  bool _restorePreviousNavigationState() {
    if (_navigationHistory.isEmpty) {
      return false;
    }
    final _NavigationSnapshot snapshot = _navigationHistory.removeLast();
    setState(() {
      _selectedModuleId = snapshot.moduleId;
      _surface = snapshot.surface;
      _navIndex = snapshot.navIndex;
      _selectedItem = snapshot.selectedItem;
      _selectedConversation = snapshot.selectedConversation;
    });
    return true;
  }

  Future<bool> _handleBackPressed() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    if (_restorePreviousNavigationState()) {
      _lastBackPressAt = null;
      return false;
    }

    final DateTime now = DateTime.now();
    final bool shouldMinimize =
        _lastBackPressAt != null &&
        now.difference(_lastBackPressAt!) <= const Duration(seconds: 2);

    if (shouldMinimize) {
      await SystemNavigator.pop();
      return false;
    }

    _lastBackPressAt = now;
    messenger.showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Toque voltar novamente para minimizar o app.'),
      ),
    );
    return false;
  }

  void _openModuleFromHelenaRequest(String moduleId, {String? spokenLabel}) {
    ProductModule? matchedModule;
    for (final ProductModule module in _data.modules) {
      if (module.id == moduleId) {
        matchedModule = module;
        break;
      }
    }
    if (matchedModule == null) {
      _setHelenaMood(
        'calm',
        'Esse modulo nao esta ativo nesta rodada. Posso te levar para Stock, Marketplace ou Chat.',
      );
      return;
    }

    _showModule(moduleId);
    _setHelenaMood(
      'focus',
      'Ta certo, vou abrir ${spokenLabel ?? matchedModule.label} pra voce, viu.',
    );
  }

  void _handleVoiceCommand(String transcript) {
    if (!_helenaEnabled) {
      return;
    }
    final String spoken = transcript.trim();
    if (spoken.isEmpty) {
      return;
    }
    final String normalized = spoken.toLowerCase();
    ProductModule? matchedModule;
    for (final ProductModule module in _data.modules) {
      final List<String> candidates = <String>[
        module.id,
        module.label,
        module.subtitle,
      ];
      final bool matched = candidates.any(
        (String value) =>
            value.isNotEmpty && normalized.contains(value.toLowerCase()),
      );
      if (matched) {
        matchedModule = module;
        break;
      }
    }

    if (matchedModule != null) {
      _openModuleFromHelenaRequest(
        matchedModule.id,
        spokenLabel: matchedModule.label,
      );
      return;
    }

    if (normalized.contains('chat') || normalized.contains('mensagem')) {
      _openSurface('chat');
      _setHelenaMood('focus', 'Ta certo, vou abrir o chat pra voce.');
      return;
    }

    if (normalized.contains('pag') || normalized.contains('carteira')) {
      _setHelenaMood(
        'calm',
        'O modulo Pay esta desativado nesta rodada. Posso abrir Plug, Docs ou Marketplace pra continuar o fluxo.',
      );
      return;
    }

    if (normalized.contains('estoque')) {
      _openModuleFromHelenaRequest('STOCK', spokenLabel: 'Valley Stock');
      return;
    }

    if (normalized.contains('market') || normalized.contains('mercado')) {
      _openModuleFromHelenaRequest(
        'MARKETPLACE',
        spokenLabel: 'Valley Marketplace',
      );
      return;
    }

    setState(() {
      _query = spoken;
      _surface = 'home';
      _helenaMood = 'happy';
      _helenaMessage =
          'Prontinho. A busca por voz foi aplicada ao ecossistema.';
    });
    _speakHelena('Prontinho. Apliquei a busca por voz para $spoken.');
  }

  Future<void> _toggleHelenaListening() async {
    if (!_helenaEnabled) {
      return;
    }
    if (_helenaListening) {
      await _speech.stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _helenaListening = false;
      });
      return;
    }

    if (!_helenaVoiceReady) {
      await _tts.setLanguage('pt-BR');
      await _tts.setPitch(1.12);
      await _tts.setSpeechRate(0.40);
      await _tts.setVolume(0.92);
      await _configureHelenaVoice();
      _helenaVoiceReady = await _speech.initialize();
    }

    if (!_helenaVoiceReady) {
      _setHelenaMood('alert', 'Microfone indisponivel para Helena.');
      setState(() {
        _helenaTranscript =
            'Ative a permissao de microfone para usar audio de entrada.';
      });
      return;
    }

    setState(() {
      _helenaListening = true;
      _helenaMood = 'focus';
      _helenaMessage =
          'Helena ouvindo com carinho. Pode me dizer um modulo, uma acao ou uma busca.';
      _helenaTranscript = 'Ouvindo...';
    });
    await _speech.listen(
      localeId: 'pt_BR',
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.confirmation,
        partialResults: true,
      ),
      onResult: (SpeechRecognitionResult result) {
        if (!mounted) {
          return;
        }
        setState(() {
          _helenaTranscript = result.recognizedWords.trim().isEmpty
              ? 'Ouvindo...'
              : result.recognizedWords.trim();
        });
        if (result.finalResult) {
          setState(() {
            _helenaListening = false;
          });
          _handleVoiceCommand(result.recognizedWords);
        }
      },
    );
  }

  @override
  void dispose() {
    _speech.stop();
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

  Future<void> _runItemAction(
    String path, {
    Map<String, dynamic> body = const <String, dynamic>{},
  }) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final ProductActionResult result = await widget.repository.invokePath(
        baseUrl: _data.baseUrl,
        path: path,
        body: body,
      );
      if (!mounted) {
        return;
      }
      final String checkoutMessage =
          result.ok && result.action == 'checkout' && _selectedItem != null
          ? 'Parabéns pela compra de ${_selectedItem!.titlePtBr}. ${result.message}'
          : result.message;
      if (result.url.isNotEmpty) {
        await launchUrl(
          Uri.parse(result.url),
          mode: LaunchMode.platformDefault,
        );
      }
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(checkoutMessage),
          backgroundColor: result.ok
              ? ValleyBrandColors.success
              : ValleyBrandColors.danger,
        ),
      );
      _setHelenaMood(result.ok ? 'happy' : 'alert', checkoutMessage);
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

  Widget _buildConfiguredModuleExperience({
    required ProductModule? module,
    required Map<String, dynamic>? moduleScreen,
    required List<ProductItem> items,
    required _ModuleExperienceSpec spec,
    required VoidCallback onPrimaryAction,
    required VoidCallback onSecondaryAction,
    required VoidCallback onTertiaryAction,
  }) {
    return _ConfiguredExperienceModuleScreen(
      module: module,
      moduleScreen: moduleScreen,
      items: items,
      spec: spec,
      onOpenItem: _openItemDetail,
      onPrimaryAction: onPrimaryAction,
      onSecondaryAction: onSecondaryAction,
      onTertiaryAction: onTertiaryAction,
    );
  }

  void _openSurface(
    String surface, {
    bool announce = false,
    String? message,
    String mood = 'focus',
  }) {
    if (_surface == surface &&
        _selectedItem == null &&
        _selectedConversation == null) {
      return;
    }
    _rememberNavigationState();
    setState(() {
      _surface = surface;
      _selectedItem = null;
      _selectedConversation = null;
      _navIndex = _navIndexForSurface(surface);
    });
    if (announce) {
      _setHelenaMood(
        mood,
        message ??
            'Abrindo ${surface == 'home' ? 'a tela principal' : surface}.',
      );
    }
  }

  void _openIdentity({ProductItem? returnItem}) {
    if (_surface == 'identity' && _selectedItem?.id == returnItem?.id) {
      return;
    }
    _rememberNavigationState();
    setState(() {
      _surface = 'identity';
      _selectedItem = returnItem;
      _selectedConversation = null;
      _navIndex = _navIndexForSurface('identity');
    });
    _setHelenaMood(
      'focus',
      'Abrindo a camada de confiança para validar Face ID, Voice ID e score.',
    );
  }

  void _openCheckoutFromPrimaryNav() {
    final ProductItem? item =
        _selectedItem ??
        (_cartItems.isNotEmpty ? _cartItems.first : null) ??
        _data.items.cast<ProductItem?>().firstWhere(
          (ProductItem? candidate) =>
              candidate != null &&
              (candidate.moduleId == 'MARKETPLACE' ||
                  candidate.moduleId == 'STOCK'),
          orElse: () => null,
        );
    if (item == null) {
      _openSurface('home');
      return;
    }
    _openCheckout(item);
  }

  void _openProfileFromPrimaryNav() {
    if (_authSession == null) {
      _openIdentity();
      return;
    }
    _openSurface('client');
  }

  Future<void> _submitLogin({
    required String identifier,
    required String password,
  }) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() {
      _authBusy = true;
      _authFeedback = '';
    });
    try {
      final ProductAuthResult result = await widget.repository.login(
        baseUrl: _data.baseUrl,
        identifier: identifier,
        password: password,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _authSession = result.session;
        _authFeedback = result.message;
      });
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(result.message),
          backgroundColor: result.ok
              ? ValleyBrandColors.success
              : ValleyBrandColors.danger,
        ),
      );
      if (result.ok && _selectedItem != null && _surface == 'identity') {
        _openCheckout(_selectedItem!);
      }
    } finally {
      if (mounted) {
        setState(() {
          _authBusy = false;
        });
      }
    }
  }

  Future<void> _submitRegister({required Map<String, String> values}) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() {
      _authBusy = true;
      _authFeedback = '';
    });
    try {
      final ProductAuthResult registerResult = await widget.repository.register(
        baseUrl: _data.baseUrl,
        fullName: values['full_name'] ?? '',
        displayName: values['display_name'] ?? '',
        email: values['email'] ?? '',
        password: values['password'] ?? '',
        role: values['role'] ?? 'CUSTOMER',
        cpf: values['cpf'] ?? '',
        phone: values['phone'] ?? '',
        defaultDeliveryAddress: <String, String>{
          'postal_code': values['postal_code'] ?? '',
          'street': values['street'] ?? '',
          'number': values['number'] ?? '',
          'complement': values['complement'] ?? '',
          'neighborhood': values['neighborhood'] ?? '',
          'city': values['city'] ?? '',
          'state': values['state'] ?? '',
        },
      );
      if (!mounted) {
        return;
      }
      if (!registerResult.ok) {
        setState(() {
          _authFeedback = registerResult.message;
        });
        messenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(registerResult.message),
            backgroundColor: ValleyBrandColors.danger,
          ),
        );
        return;
      }
      await _submitLogin(
        identifier: values['email'] ?? '',
        password: values['password'] ?? '',
      );
    } finally {
      if (mounted) {
        setState(() {
          _authBusy = false;
        });
      }
    }
  }

  Future<void> _logoutAuth() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() {
      _authBusy = true;
    });
    try {
      await widget.repository.logout(baseUrl: _data.baseUrl);
      if (!mounted) {
        return;
      }
      setState(() {
        _authSession = null;
        _authFeedback = 'Sessão encerrada no dispositivo.';
      });
      messenger.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Sessão encerrada.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _authBusy = false;
        });
      }
    }
  }

  void _openNotifications() {
    if (_surface == 'notifications') {
      return;
    }
    _rememberNavigationState();
    setState(() {
      _surface = 'notifications';
      _selectedItem = null;
      _selectedConversation = null;
    });
  }

  void _openItemDetail(ProductItem item) {
    if (_surface == 'detail' && _selectedItem?.id == item.id) {
      return;
    }
    _rememberNavigationState();
    setState(() {
      _selectedItem = item;
      _selectedConversation = null;
      _surface = 'detail';
    });
    _setHelenaMood(
      'focus',
      'Abrindo ${item.title} com video e descricao completa.',
    );
  }

  void _addToCart(ProductItem item) {
    final bool alreadyAdded = _cartItems.any(
      (ProductItem cartItem) => cartItem.id == item.id,
    );
    if (!alreadyAdded) {
      setState(() {
        _cartItems.add(item);
      });
    }
    _rememberNavigationState();
    setState(() {
      _selectedItem = item;
      _selectedConversation = null;
      _surface = 'cart';
    });
    _setHelenaMood('happy', '${item.title} entrou no resumo rapido do pedido.');
  }

  void _removeFromCart(ProductItem item) {
    setState(() {
      _cartItems.removeWhere((ProductItem cartItem) => cartItem.id == item.id);
      if (_cartItems.isEmpty) {
        _selectedItem = null;
      }
    });
  }

  void _openCheckout(ProductItem item) {
    if (_surface == 'checkout' && _selectedItem?.id == item.id) {
      return;
    }
    _rememberNavigationState();
    setState(() {
      _selectedItem = item;
      _selectedConversation = null;
      _surface = 'checkout';
    });
    _setHelenaMood('happy', 'Checkout pronto para ${item.title}.');
  }

  void _confirmPreparedOrder(
    ProductItem item, {
    Map<String, String> deliveryAddress = const <String, String>{},
    bool useProfileAddress = true,
  }) {
    if (_authSession == null) {
      _openIdentity(returnItem: item);
      return;
    }
    if (item.ctaPath.isNotEmpty) {
      _runItemAction(
        item.ctaPath,
        body: <String, dynamic>{
          'delivery_address_source': useProfileAddress
              ? 'customer_profile'
              : 'checkout_override',
          'delivery_address': deliveryAddress,
          'white_label': const <String, dynamic>{
            'brand_name': 'Valley',
            'shipping_label_logo': 'Valley',
            'hide_original_supplier_name': true,
          },
        },
      );
      _setHelenaMood('focus', 'Abrindo o pagamento seguro para ${item.title}.');
      return;
    }
    _rememberNavigationState();
    setState(() {
      _confirmedOrderItem = item;
      _selectedItem = item;
      _selectedConversation = null;
      _surface = 'confirmation';
      _cartItems.removeWhere((ProductItem cartItem) => cartItem.id == item.id);
    });
    _setHelenaMood(
      'happy',
      'Pedido confirmado com comprovante Valley Docs preparado.',
    );
  }

  void _openReceipt(ProductItem item) {
    _rememberNavigationState();
    setState(() {
      _confirmedOrderItem = item;
      _selectedItem = item;
      _selectedConversation = null;
      _surface = 'receipt';
    });
  }

  Future<void> _shareOffer(ProductItem item) async {
    final String offerUrl =
        '${_data.baseUrl}/product?item_id=${Uri.encodeComponent(item.id)}';
    final String description = item.descriptionPtBr.trim().isEmpty
        ? item.titlePtBr
        : item.descriptionPtBr;
    await SharePlus.instance.share(
      ShareParams(
        text:
            '${item.titlePtBr}\nR\$ ${item.priceBrl.toStringAsFixed(2)}\n$description\n$offerUrl',
        subject: item.titlePtBr,
      ),
    );
  }

  void _openConversation(Map<String, dynamic> conversation) {
    if (_surface == 'conversation' &&
        _selectedConversation?['id'] == conversation['id']) {
      return;
    }
    _rememberNavigationState();
    setState(() {
      _selectedConversation = conversation;
      _selectedItem = null;
      _surface = 'conversation';
    });
    _setHelenaMood('focus', 'Abrindo a conversa com ${conversation['title']}.');
  }

  void _showModule(
    String moduleId, {
    bool announce = false,
    String? message,
    String mood = 'calm',
  }) {
    if (!_data.modules.any((ProductModule module) => module.id == moduleId)) {
      _setHelenaMood(
        'calm',
        'Modulo $moduleId fora da vitrine ativa nesta rodada.',
      );
      return;
    }
    if (!_activeMvpModuleIds.contains(moduleId)) {
      _openPreparedModule(moduleId);
      return;
    }
    if (_selectedModuleId == moduleId &&
        _surface == 'home' &&
        _selectedItem == null &&
        _selectedConversation == null) {
      return;
    }
    _rememberNavigationState();
    setState(() {
      _selectedModuleId = moduleId;
      _surface = 'home';
      _selectedItem = null;
      _selectedConversation = null;
      _navIndex = _navIndexForModule(moduleId);
    });
    if (announce) {
      _setHelenaMood(mood, message ?? 'Módulo $moduleId ativo.');
    }
  }

  void _openPreparedModule(String moduleId) {
    _rememberNavigationState();
    setState(() {
      _selectedModuleId = moduleId;
      _surface = 'module_prepared';
      _selectedItem = null;
      _selectedConversation = null;
      _navIndex = 0;
    });
    _setHelenaMood(
      'calm',
      'Modulo $moduleId fora da sua vitrine ativa no momento.',
    );
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
        onAddToCart: () => _addToCart(_selectedItem!),
        onCheckout: () => _openCheckout(_selectedItem!),
        onShare: () => _shareOffer(_selectedItem!),
        onChat: () => _openSurface('chat'),
      );
    }
    if (_surface == 'cart') {
      return _CartScreen(
        items: _cartItems,
        fallbackItem: _selectedItem,
        onRemove: _removeFromCart,
        onBrowse: () => _showModule('MARKETPLACE'),
        onCheckout: (ProductItem item) => _openCheckout(item),
      );
    }
    if (_surface == 'checkout' && _selectedItem != null) {
      return _CheckoutScreen(
        item: _selectedItem!,
        baseUrl: _data.baseUrl,
        repository: widget.repository,
        authRequired: _authSession == null,
        authSession: _authSession,
        useProfileAddress: _useProfileDeliveryAddress,
        onUseProfileAddressChanged: (bool value) {
          setState(() => _useProfileDeliveryAddress = value);
        },
        onConfirm: (Map<String, String> deliveryAddress, bool useProfile) =>
            _confirmPreparedOrder(
              _selectedItem!,
              deliveryAddress: deliveryAddress,
              useProfileAddress: useProfile,
            ),
        onIdentity: () => _openIdentity(returnItem: _selectedItem),
        onCancel: () => _addToCart(_selectedItem!),
      );
    }
    if (_surface == 'confirmation' &&
        (_selectedItem != null || _confirmedOrderItem != null)) {
      final ProductItem item = _selectedItem ?? _confirmedOrderItem!;
      return _ConfirmationScreen(
        item: item,
        onOpenReceipt: () => _openReceipt(item),
        onOpenOrders: () => _openSurface('client'),
        onContinueShopping: () => _showModule('MARKETPLACE'),
        onSupport: () => _openSurface('chat'),
      );
    }
    if (_surface == 'receipt' &&
        (_selectedItem != null || _confirmedOrderItem != null)) {
      return _ReceiptScreen(item: _selectedItem ?? _confirmedOrderItem!);
    }
    if (_surface == 'identity') {
      return _IdentityTrustScreen(
        pendingItem: _selectedItem,
        onConfirm: _selectedItem == null
            ? null
            : () => _openCheckout(_selectedItem!),
        authSession: _authSession,
        authBusy: _authBusy,
        feedback: _authFeedback,
        onLogin: (String identifier, String password) =>
            _submitLogin(identifier: identifier, password: password),
        onRegister: (Map<String, String> values) =>
            _submitRegister(values: values),
        onLogout: _authSession == null ? null : _logoutAuth,
      );
    }
    if (_surface == 'notifications') {
      return _NotificationsScreen(
        baseUrl: _data.baseUrl,
        repository: widget.repository,
        items: _data.items,
        onOpenItem: _openItemDetail,
        onOpenStock: () => _showModule('STOCK'),
        onOpenChat: () => _openSurface('chat'),
        onOpenIdentity: () => _openIdentity(),
      );
    }
    if (_surface == 'module_prepared') {
      return _PreparedModuleScreen(
        moduleId: _selectedModuleId,
        onNotify: _openNotifications,
        onHome: () => _openSurface('home'),
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
    if (_surface == 'client') {
      return _ClientAreaScreen(
        baseUrl: _data.baseUrl,
        repository: widget.repository,
        items: _data.items,
        onOpenItem: _openItemDetail,
        onOpenChat: () => _openSurface('chat'),
      );
    }
    if (_surface == 'statement') {
      return _StatementScreen(entries: _rawList('statement_entries'));
    }

    final Map<String, dynamic>? moduleScreen = _moduleScreenById(
      module?.id ?? '',
    );
    if ((module?.id ?? '') == 'STOCK') {
      return _StockSection(
        items: items,
        onTap: _openItemDetail,
        repository: widget.repository,
        baseUrl: _data.baseUrl,
      );
    }
    if (!_activeMvpModuleIds.contains(module?.id ?? '')) {
      return _PreparedModuleScreen(
        moduleId: module?.id ?? 'VALY.OS',
        onNotify: _openNotifications,
        onHome: () => _openSurface('home'),
      );
    }
    if ((module?.id ?? '') == 'FOOD') {
      return _FoodModuleScreen(items: items, onOpenItem: _openItemDetail);
    }
    if ((module?.id ?? '') == 'SERVICES') {
      return _ServicesModuleScreen(
        items: items,
        onOpenItem: _openItemDetail,
        onOpenChat: () => _openSurface('chat'),
      );
    }
    if ((module?.id ?? '') == 'LOG') {
      return _LogisticsModuleScreen(
        items: items,
        onOpenItem: _openItemDetail,
        onOpenStatement: () => _openSurface('statement'),
      );
    }
    if ((module?.id ?? '') == 'PAY') {
      return _PayModuleScreen(
        items: items,
        entries: _rawList('statement_entries'),
        onOpenStatement: () => _openSurface('statement'),
        onOpenItem: _openItemDetail,
      );
    }
    if ((module?.id ?? '') == 'ENERGY') {
      return _EnergyModuleScreen(
        items: items,
        entries: _rawList('statement_entries'),
        onOpenItem: _openItemDetail,
      );
    }
    if ((module?.id ?? '') == 'INSURANCE') {
      return _PolicyModuleScreen(items: items, onOpenItem: _openItemDetail);
    }
    if ((module?.id ?? '') == 'GAMING') {
      return _GamingModuleScreen(items: items, onOpenItem: _openItemDetail);
    }
    if ((module?.id ?? '') == 'MOBILITY') {
      return _MobilityModuleScreen(items: items, onOpenItem: _openItemDetail);
    }
    if ((module?.id ?? '') == 'MARKETPLACE') {
      return _MarketplaceModuleScreen(
        items: items,
        onOpenItem: _openItemDetail,
      );
    }
    if ((module?.id ?? '') == 'CHAT') {
      return _buildConfiguredModuleExperience(
        module: module,
        moduleScreen: moduleScreen,
        items: items,
        spec: const _ModuleExperienceSpec(
          badge: 'Inbox premium',
          primaryLabel: 'Abrir inbox',
          primaryIcon: Icons.forum_rounded,
          secondaryLabel: 'Feed contextual',
          secondaryIcon: Icons.dynamic_feed_rounded,
          tertiaryLabel: 'Extrato',
          tertiaryIcon: Icons.receipt_long_rounded,
          insightTitle: 'Contexto Helena dual ativo',
          insightBody:
              'Inbox, conversa premium e transições suaves para mídia, produto e histórico financeiro.',
        ),
        onPrimaryAction: () => _openSurface('chat'),
        onSecondaryAction: () => _openSurface('feed'),
        onTertiaryAction: () => _openSurface('statement'),
      );
    }
    if ((module?.id ?? '') == 'DOCS') {
      return _buildConfiguredModuleExperience(
        module: module,
        moduleScreen: moduleScreen,
        items: items,
        spec: const _ModuleExperienceSpec(
          badge: 'Document flow',
          primaryLabel: 'Abrir modulo',
          primaryIcon: Icons.description_rounded,
          secondaryLabel: 'Assinatura',
          secondaryIcon: Icons.draw_rounded,
          tertiaryLabel: 'Comprovantes',
          tertiaryIcon: Icons.inventory_2_rounded,
          insightTitle: 'Recibos e assinatura',
          insightBody:
              'Fluxo pronto para pré-visualização, assinatura final e retomada de comprovantes sem sair do shell.',
        ),
        onPrimaryAction: items.isNotEmpty
            ? () => _openItemDetail(items.first)
            : () => _openSurface('feed'),
        onSecondaryAction: items.isNotEmpty
            ? () => _openCheckout(items.first)
            : () => _openSurface('chat'),
        onTertiaryAction: () => _openSurface('statement'),
      );
    }
    if ((module?.id ?? '') == 'BUSINESS') {
      return _buildConfiguredModuleExperience(
        module: module,
        moduleScreen: moduleScreen,
        items: items,
        spec: const _ModuleExperienceSpec(
          badge: 'ERP ativo',
          primaryLabel: 'Aprovações',
          primaryIcon: Icons.fact_check_rounded,
          secondaryLabel: 'Fluxo fiscal',
          secondaryIcon: Icons.account_balance_rounded,
          tertiaryLabel: 'Atendimento',
          tertiaryIcon: Icons.support_agent_rounded,
          insightTitle: 'Backoffice integrado',
          insightBody:
              'Painéis de aprovação, fiscal e atendimento ligados aos mesmos registros operacionais do catálogo.',
        ),
        onPrimaryAction: items.isNotEmpty
            ? () => _openItemDetail(items.first)
            : () => _openSurface('feed'),
        onSecondaryAction: () => _openSurface('statement'),
        onTertiaryAction: () => _openSurface('chat'),
      );
    }
    if ((module?.id ?? '') == 'HEALTH') {
      return _buildConfiguredModuleExperience(
        module: module,
        moduleScreen: moduleScreen,
        items: items,
        spec: const _ModuleExperienceSpec(
          badge: 'Predictive care',
          primaryLabel: 'Agenda clínica',
          primaryIcon: Icons.calendar_month_rounded,
          secondaryLabel: 'Histórico',
          secondaryIcon: Icons.monitor_heart_rounded,
          tertiaryLabel: 'Falar agora',
          tertiaryIcon: Icons.mic_rounded,
          insightTitle: 'Cuidado com contexto',
          insightBody:
              'A experiência une jornada clínica, histórico recente e acionamento rápido da Helena para triagem.',
        ),
        onPrimaryAction: items.isNotEmpty
            ? () => _openItemDetail(items.first)
            : () => _openSurface('feed'),
        onSecondaryAction: () => _openSurface('statement'),
        onTertiaryAction: _toggleHelenaListening,
      );
    }
    if ((module?.id ?? '') == 'SECURITY') {
      return _buildConfiguredModuleExperience(
        module: module,
        moduleScreen: moduleScreen,
        items: items,
        spec: const _ModuleExperienceSpec(
          badge: 'Guard active',
          primaryLabel: 'Alerta ativo',
          primaryIcon: Icons.warning_amber_rounded,
          secondaryLabel: 'Proteção',
          secondaryIcon: Icons.shield_rounded,
          tertiaryLabel: 'Registros',
          tertiaryIcon: Icons.policy_rounded,
          insightTitle: 'Camada de proteção',
          insightBody:
              'CTA direto para alerta, proteção pessoal e trilha de registros do ecossistema em uma única vista.',
        ),
        onPrimaryAction: items.isNotEmpty
            ? () => _openItemDetail(items.first)
            : () => _openSurface('chat'),
        onSecondaryAction: () => _openSurface('chat'),
        onTertiaryAction: () => _openSurface('statement'),
      );
    }
    if ((module?.id ?? '') == 'IOT') {
      return _buildConfiguredModuleExperience(
        module: module,
        moduleScreen: moduleScreen,
        items: items,
        spec: const _ModuleExperienceSpec(
          badge: 'Smart hub',
          primaryLabel: 'Dispositivos',
          primaryIcon: Icons.devices_rounded,
          secondaryLabel: 'Automação',
          secondaryIcon: Icons.auto_mode_rounded,
          tertiaryLabel: 'Helena Hub',
          tertiaryIcon: Icons.psychology_alt_rounded,
          insightTitle: 'Ambientes conectados',
          insightBody:
              'Dispositivos, automações e contexto conversacional da Helena reunidos para controle contínuo.',
        ),
        onPrimaryAction: items.isNotEmpty
            ? () => _openItemDetail(items.first)
            : () => _openSurface('feed'),
        onSecondaryAction: () => _openSurface('feed'),
        onTertiaryAction: () => _openSurface('chat'),
      );
    }
    if ((module?.id ?? '') == 'AGENDA') {
      return _buildConfiguredModuleExperience(
        module: module,
        moduleScreen: moduleScreen,
        items: items,
        spec: const _ModuleExperienceSpec(
          badge: 'Helena memory',
          primaryLabel: 'Criar tarefa',
          primaryIcon: Icons.add_task_rounded,
          secondaryLabel: 'Memória e listas',
          secondaryIcon: Icons.checklist_rounded,
          tertiaryLabel: 'Conversar',
          tertiaryIcon: Icons.chat_bubble_rounded,
          insightTitle: 'Memória viva',
          insightBody:
              'As telas de tarefa, memória e listas passam a ficar conectadas ao mesmo fluxo do shell principal.',
        ),
        onPrimaryAction: items.isNotEmpty
            ? () => _openItemDetail(items.first)
            : () => _openSurface('feed'),
        onSecondaryAction: () => _openSurface('feed'),
        onTertiaryAction: () => _openSurface('chat'),
      );
    }
    if ((module?.id ?? '') == 'ADVISOR') {
      return _buildConfiguredModuleExperience(
        module: module,
        moduleScreen: moduleScreen,
        items: items,
        spec: const _ModuleExperienceSpec(
          badge: 'Consultoria IA',
          primaryLabel: 'Recomendação',
          primaryIcon: Icons.tips_and_updates_rounded,
          secondaryLabel: 'Detalhes',
          secondaryIcon: Icons.insights_rounded,
          tertiaryLabel: 'Extrato',
          tertiaryIcon: Icons.stacked_line_chart_rounded,
          insightTitle: 'Recomendação acionável',
          insightBody:
              'Advisor agora abre sugestões, detalhes e desdobramentos financeiros sem cair no fallback genérico.',
        ),
        onPrimaryAction: items.isNotEmpty
            ? () => _openItemDetail(items.first)
            : () => _openSurface('feed'),
        onSecondaryAction: () => _openSurface('feed'),
        onTertiaryAction: () => _openSurface('statement'),
      );
    }
    if ((module?.id ?? '') == 'UP') {
      return _buildConfiguredModuleExperience(
        module: module,
        moduleScreen: moduleScreen,
        items: items,
        spec: const _ModuleExperienceSpec(
          badge: 'CAC zero',
          primaryLabel: 'Afiliados',
          primaryIcon: Icons.campaign_rounded,
          secondaryLabel: 'Payout',
          secondaryIcon: Icons.payments_rounded,
          tertiaryLabel: 'Contato',
          tertiaryIcon: Icons.group_rounded,
          insightTitle: 'Motor de afiliados',
          insightBody:
              'As jornadas de afiliados, comissão e payout já entram ligadas aos mesmos itens e extratos do shell.',
        ),
        onPrimaryAction: items.isNotEmpty
            ? () => _openItemDetail(items.first)
            : () => _openSurface('feed'),
        onSecondaryAction: () => _openSurface('statement'),
        onTertiaryAction: () => _openSurface('chat'),
      );
    }
    if ((module?.id ?? '') == 'MEDIA') {
      return _buildConfiguredModuleExperience(
        module: module,
        moduleScreen: moduleScreen,
        items: items,
        spec: const _ModuleExperienceSpec(
          badge: 'Creator panel',
          primaryLabel: 'Criadores',
          primaryIcon: Icons.video_camera_front_rounded,
          secondaryLabel: 'Campanhas',
          secondaryIcon: Icons.rocket_launch_rounded,
          tertiaryLabel: 'Payout',
          tertiaryIcon: Icons.account_balance_wallet_rounded,
          insightTitle: 'Operação creator',
          insightBody:
              'Media passa a abrir campanha, payout e narrativa visual sem depender só do card genérico do módulo.',
        ),
        onPrimaryAction: () => _openSurface('feed'),
        onSecondaryAction: items.isNotEmpty
            ? () => _openItemDetail(items.first)
            : () => _openSurface('feed'),
        onTertiaryAction: () => _openSurface('statement'),
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
        repository: widget.repository,
        baseUrl: _data.baseUrl,
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
                        'Vitrine de tecnologia, casa inteligente e acessórios selecionados para compra direta.',
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
        _RecentActivityPanel(items: recentItems, onTap: _openItemDetail),
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
    final double viewportWidth = MediaQuery.sizeOf(context).width;
    final bool wide = viewportWidth >= 1100;
    final bool compact = viewportWidth < 760;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _handleBackPressed();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _useLightTemplate(context)
                  ? const <Color>[
                      Color(0xFFF9F7FF),
                      Color(0xFFF2F7FF),
                      Color(0xFFF7F8FF),
                    ]
                  : const <Color>[
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
                          padding: EdgeInsets.fromLTRB(
                            wide ? 112 : 20,
                            12,
                            20,
                            compact ? 150 : 120,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              _TopBar(
                                busy: _busy,
                                cartCount: _cartItems.length,
                                accountLabel:
                                    _authSession?.user.displayName ?? '',
                                accountSigned: _authSession != null,
                                onSearchChanged: (String value) =>
                                    setState(() => _query = value),
                                onCart: () => _openSurface('cart'),
                                onNotifications: _openNotifications,
                                onIdentity: () => _openIdentity(),
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
                              if (_surface == 'home')
                                const SizedBox(height: 18),
                              if (_surface == 'home')
                                _IndicatorGrid(
                                  summary: _data.summary,
                                  selectedModule: module,
                                  itemCount: items.length,
                                ),
                              const SizedBox(height: 28),
                              _buildSurface(theme, items, module, recentItems),
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
                                                    .colorScheme
                                                    .onSurfaceVariant,
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
                if (_helenaEnabled)
                  Align(
                    alignment: Alignment(
                      _helenaAlignment.dx,
                      _helenaAlignment.dy,
                    ),
                    child: GestureDetector(
                      onPanUpdate: (DragUpdateDetails details) {
                        final Size size = MediaQuery.sizeOf(context);
                        setState(() {
                          _helenaAlignment = Offset(
                            (_helenaAlignment.dx +
                                    (details.delta.dx /
                                            math.max(size.width, 1)) *
                                        2)
                                .clamp(-0.96, 0.96),
                            (_helenaAlignment.dy +
                                    (details.delta.dy /
                                            math.max(size.height, 1)) *
                                        2)
                                .clamp(-0.90, 0.90),
                          );
                        });
                      },
                      child: _HelenaAssistant(
                        minimized: _helenaMinimized,
                        mood: _helenaMood,
                        message: _helenaMessage,
                        transcript: _helenaTranscript,
                        voiceReady: _helenaVoiceReady,
                        listening: _helenaListening,
                        onToggle: () => setState(
                          () => _helenaMinimized = !_helenaMinimized,
                        ),
                        onSpeak: () => _speakHelena(_helenaMessage),
                        onListen: _toggleHelenaListening,
                      ),
                    ),
                  ),
                if (_moduleDockEnabled)
                  Positioned(
                    left: compact ? 20 : (wide ? 112 : 18),
                    right: compact ? null : 18,
                    bottom: compact ? 18 : 14,
                    child: _FloatingModuleDock(
                      modules: _data.modules,
                      selectedModuleId: _selectedModuleId,
                      onOpenModule: _showModule,
                      onOpenIdentity: () => _openIdentity(),
                      onOpenSettings: () => _openSurface('notifications'),
                    ),
                  ),
                if (wide)
                  Positioned(
                    left: 20,
                    top: 92,
                    bottom: 24,
                    child: _DesktopSideRail(
                      items: _primaryNavItems,
                      index: _navIndex,
                      onChanged: _handlePrimaryNav,
                    ),
                  ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: wide
            ? null
            : _BottomGlassNav(
                items: _primaryNavItems,
                index: _navIndex,
                onChanged: _handlePrimaryNav,
              ),
      ),
    );
  }

  void _handlePrimaryNav(int value) {
    if (value < 0 || value >= _primaryNavItems.length) {
      return;
    }
    final _PrimaryNavItem item = _primaryNavItems[value];
    setState(() {
      _navIndex = value;
    });
    if (item.moduleId != null) {
      _showModule(item.moduleId!, announce: false);
      return;
    }
    if (item.surface == 'checkout_nav') {
      _openCheckoutFromPrimaryNav();
      return;
    }
    if (item.surface == 'profile') {
      _openProfileFromPrimaryNav();
      return;
    }
    _openSurface(item.surface, announce: false);
  }
}

class _NavigationSnapshot {
  const _NavigationSnapshot({
    required this.moduleId,
    required this.surface,
    required this.navIndex,
    required this.selectedItem,
    required this.selectedConversation,
  });

  final String moduleId;
  final String surface;
  final int navIndex;
  final ProductItem? selectedItem;
  final Map<String, dynamic>? selectedConversation;

  bool isSameState(_NavigationSnapshot other) {
    return moduleId == other.moduleId &&
        surface == other.surface &&
        navIndex == other.navIndex &&
        selectedItem?.id == other.selectedItem?.id &&
        selectedConversation?['id'] == other.selectedConversation?['id'];
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.busy,
    required this.cartCount,
    required this.accountLabel,
    required this.accountSigned,
    required this.onSearchChanged,
    required this.onCart,
    required this.onNotifications,
    required this.onIdentity,
  });

  final bool busy;
  final int cartCount;
  final String accountLabel;
  final bool accountSigned;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onCart;
  final VoidCallback onNotifications;
  final VoidCallback onIdentity;

  @override
  Widget build(BuildContext context) {
    final bool compact = MediaQuery.sizeOf(context).width < 760;
    final Color searchFill = _useLightTemplate(context)
        ? const Color(0xFFF8FBFF)
        : const Color(0x66161B2B);
    return Row(
      children: <Widget>[
        const ValleyLogoMark(size: 44, borderRadius: 14),
        const SizedBox(width: 14),
        if (!compact)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'VALLEY',
                  style: TextStyle(
                    color: ValleyBrandColors.cyan,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.4,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Marketplace, Stock, Chat, Checkout e Perfil',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        if (compact) const Spacer(),
        SizedBox(
          width: compact ? 118 : 260,
          child: TextField(
            onChanged: onSearchChanged,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: InputDecoration(
              isDense: true,
              hintText: compact ? 'Buscar' : 'Buscar produto, pedido ou chat',
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
              fillColor: searchFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _TopBarIconButton(
          icon: Icons.verified_user_rounded,
          tooltip: accountSigned
              ? 'Conta ativa: ${accountLabel.isEmpty ? "Valley" : accountLabel}'
              : 'Entrar ou criar conta',
          badge: accountSigned ? 'ON' : null,
          onTap: onIdentity,
        ),
        if (!compact)
          _TopBarIconButton(
            icon: Icons.notifications_rounded,
            tooltip: 'Notificações',
            onTap: onNotifications,
          ),
        _TopBarIconButton(
          icon: Icons.shopping_bag_rounded,
          tooltip: 'Carrinho',
          badge: cartCount == 0 ? null : cartCount.toString(),
          onTap: onCart,
        ),
      ],
    );
  }
}

class _TopBarIconButton extends StatelessWidget {
  const _TopBarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final bool light = _useLightTemplate(context);
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _softContainerColor(
                context,
                lightAlpha: 0.94,
                darkAlpha: 0.06,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _softBorderColor(
                  context,
                  lightAlpha: 1,
                  darkAlpha: 0.10,
                ),
              ),
              boxShadow: light
                  ? <BoxShadow>[
                      BoxShadow(
                        color: ValleyBrandColors.violet.withValues(alpha: 0.06),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Center(
                  child: Icon(icon, size: 21, color: ValleyBrandColors.cyan),
                ),
                if (badge != null)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: ValleyBrandColors.violet,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
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
    final bool compact = MediaQuery.sizeOf(context).width < 760;
    final bool light = _useLightTemplate(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: SizedBox(
        height: compact ? 340 : 430,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.network(
              item.imageUrl,
              fit: BoxFit.cover,
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stackTrace) {
                    return ColoredBox(
                      color: light
                          ? const Color(0xFFE8F0FF)
                          : const Color(0xFF121A2F),
                    );
                  },
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: light
                      ? <Color>[
                          Colors.white.withValues(alpha: 0.04),
                          const Color(0xFF172137).withValues(alpha: 0.28),
                          const Color(0xFF172137).withValues(alpha: 0.78),
                        ]
                      : <Color>[
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
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        height: 1.02,
                        fontSize: compact ? 34 : null,
                      ),
                      children: <InlineSpan>[
                        const TextSpan(text: 'Bem-vindo ao\n'),
                        TextSpan(
                          text: 'Futuro, Arthur.',
                          style: const TextStyle(color: Color(0xFF6EE7F9)),
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
                        color: Colors.white.withValues(alpha: 0.84),
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
              _wideCard(context),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _smallCard(
                      context,
                      'Produtos ativos',
                      '${summary.products}',
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: _mvpFlowCard(context)),
                ],
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(flex: 2, child: _wideCard(context)),
            const SizedBox(width: 14),
            Expanded(
              child: _smallCard(
                context,
                'Produtos ativos',
                '${summary.products}',
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: _mvpFlowCard(context)),
          ],
        );
      },
    );
  }

  Widget _wideCard(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ValleyPanel(
      radius: 24,
      padding: const EdgeInsets.all(22),
      glowColor: ValleyBrandColors.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.query_stats_rounded,
                color: ValleyBrandColors.cyan,
                size: 32,
              ),
              const Spacer(),
              const Text(
                'LIVE',
                style: TextStyle(
                  color: Color(0xFF6EE7F9),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'OPERAÇÃO ATIVA',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            selectedModule?.id ?? 'VALY.OS',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
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
                            color: const Color(
                              0xFF6EE7F9,
                            ).withValues(alpha: 0.28 + (factor * 0.44)),
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

  Widget _smallCard(BuildContext context, String label, String value) {
    final ThemeData theme = Theme.of(context);
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
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$itemCount sincronizados',
              style: theme.textTheme.labelLarge?.copyWith(
                color: ValleyBrandColors.cyan,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mvpFlowCard(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ValleyPanel(
      radius: 24,
      padding: const EdgeInsets.all(22),
      child: SizedBox(
        height: 206,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'FLUXOS ATIVOS',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            Text(
              '$itemCount',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'itens prontos para venda, chat ou detalhe',
              style: theme.textTheme.labelLarge?.copyWith(
                color: ValleyBrandColors.cyan,
                fontWeight: FontWeight.w700,
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
    final ThemeData theme = Theme.of(context);
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
                  _ProductGalleryCarousel(
                    imageUrls: item.mediaGallery,
                    fit: BoxFit.cover,
                    emptyColor: _mediaStageColor(context),
                    compact: true,
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
                  Positioned(
                    left: 16,
                    bottom: 16,
                    child: _MetaPill(
                      icon: Icons.storefront_rounded,
                      label: item.customerVisibleSupplierName,
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
                    item.titlePtBr,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
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
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item.category} • ${item.customerVisibleSupplierName}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
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
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _MetaPill(
                        icon: Icons.category_rounded,
                        label: item.taxonomyLeaf,
                      ),
                      if (item.shippingFree)
                        const _MetaPill(
                          icon: Icons.local_shipping_rounded,
                          label: 'Frete integrado',
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (featured) ...<Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          'R\$ ${item.priceBrl.toStringAsFixed(0)}',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: busy ? null : onPrimary,
                          style: FilledButton.styleFrom(
                            backgroundColor: ValleyBrandColors.cyan,
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
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
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
                                color: _softBorderColor(
                                  context,
                                  lightAlpha: 1,
                                  darkAlpha: 0.12,
                                ),
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
                            color: _softBorderColor(
                              context,
                              lightAlpha: 1,
                              darkAlpha: 0.12,
                            ),
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

class _StockSection extends StatefulWidget {
  const _StockSection({
    required this.items,
    required this.onTap,
    required this.repository,
    required this.baseUrl,
  });

  final List<ProductItem> items;
  final ValueChanged<ProductItem> onTap;
  final ProductApiRepository repository;
  final String baseUrl;

  @override
  State<_StockSection> createState() => _StockSectionState();
}

class _StockSectionState extends State<_StockSection> {
  static const String _allLabel = 'Todas';

  String _query = '';
  String _selectedCategory = _allLabel;
  String _selectedSupplier = _allLabel;
  String _selectedCollection = _allLabel;
  String _selectedPriceBand = _allLabel;
  late RangeValues _priceRange;
  List<ProductItem> _liveItems = <ProductItem>[];
  bool _loadingLiveCatalog = false;
  String? _catalogError;

  @override
  void initState() {
    super.initState();
    _syncPriceRange();
    _loadLiveCatalog();
  }

  @override
  void didUpdateWidget(covariant _StockSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items ||
        oldWidget.baseUrl != widget.baseUrl) {
      _syncPriceRange();
      _loadLiveCatalog();
    }
  }

  List<ProductItem> get _catalogItems =>
      _liveItems.isNotEmpty ? _liveItems : widget.items;

  bool get _usingLiveCatalog => _liveItems.isNotEmpty;

  Future<void> _loadLiveCatalog() async {
    if (_loadingLiveCatalog) {
      return;
    }

    setState(() {
      _loadingLiveCatalog = true;
      _catalogError = null;
    });

    try {
      final List<ProductItem> items = await widget.repository.loadStockCatalog(
        preferredBaseUrl: widget.baseUrl,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _liveItems = items;
        _loadingLiveCatalog = false;
        _catalogError = null;
        _syncPriceRange();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingLiveCatalog = false;
        _catalogError = error.toString();
        _syncPriceRange();
      });
    }
  }

  double get _minCatalogPrice {
    if (_catalogItems.isEmpty) {
      return 0;
    }
    return _catalogItems
        .map((ProductItem item) => item.priceBrl)
        .reduce(math.min);
  }

  double get _maxCatalogPrice {
    if (_catalogItems.isEmpty) {
      return 0;
    }
    return _catalogItems
        .map((ProductItem item) => item.priceBrl)
        .reduce(math.max);
  }

  List<String> get _categoryOptions {
    final Set<String> values = _catalogItems
        .map((ProductItem item) => item.category)
        .where((String value) => value.trim().isNotEmpty)
        .toSet();
    final List<String> ordered = values.toList()..sort();
    return <String>[_allLabel, ...ordered];
  }

  List<String> get _collectionOptions {
    final Set<String> values = _catalogItems
        .map((ProductItem item) => item.collectionLabel)
        .where((String value) => value.trim().isNotEmpty)
        .toSet();
    final List<String> ordered = values.toList()..sort();
    return <String>[_allLabel, ...ordered];
  }

  List<String> get _supplierOptions {
    final Set<String> values = _catalogItems
        .map((ProductItem item) => item.customerVisibleSupplierName)
        .where((String value) => value.trim().isNotEmpty)
        .toSet();
    final List<String> ordered = values.toList()..sort();
    return <String>[_allLabel, ...ordered];
  }

  List<String> get _priceBandOptions {
    final Set<String> values = _catalogItems
        .map((ProductItem item) => item.priceBand)
        .where((String value) => value.trim().isNotEmpty)
        .toSet();
    final List<String> ordered = values.toList()..sort();
    return <String>[_allLabel, ...ordered];
  }

  void _syncPriceRange() {
    final double minPrice = _minCatalogPrice;
    final double maxPrice = math.max(minPrice, _maxCatalogPrice).toDouble();
    _priceRange = RangeValues(minPrice, maxPrice);
  }

  String _formatCurrency(num value) {
    final String normalized = value.toStringAsFixed(2);
    final List<String> parts = normalized.split('.');
    final String whole = parts.first;
    final String cents = parts.last;
    final StringBuffer buffer = StringBuffer();
    for (int index = 0; index < whole.length; index++) {
      final int reverseIndex = whole.length - index;
      buffer.write(whole[index]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write('.');
      }
    }
    return 'R\$ ${buffer.toString()},$cents';
  }

  List<ProductItem> get _filteredItems {
    final String search = _query.trim().toLowerCase();
    final List<ProductItem> filtered = _catalogItems.where((ProductItem item) {
      if (_selectedCategory != _allLabel &&
          item.category != _selectedCategory) {
        return false;
      }
      if (_selectedSupplier != _allLabel &&
          item.customerVisibleSupplierName != _selectedSupplier) {
        return false;
      }
      if (_selectedCollection != _allLabel &&
          item.collectionLabel != _selectedCollection) {
        return false;
      }
      if (_selectedPriceBand != _allLabel &&
          item.priceBand != _selectedPriceBand) {
        return false;
      }
      if (item.priceBrl < _priceRange.start ||
          item.priceBrl > _priceRange.end) {
        return false;
      }
      if (search.isEmpty) {
        return true;
      }
      final String haystack = <String>[
        item.title,
        item.brand,
        item.collectionLabel,
        item.modelName,
        item.category,
        item.customerVisibleSupplierName,
        item.customerVisibleSupplierName,
        item.channelLabel,
        item.googleTaxonomyPath,
        item.taxonomyLeaf,
        ...item.tags,
      ].join(' ').toLowerCase();
      return haystack.contains(search);
    }).toList();
    filtered.sort((ProductItem left, ProductItem right) {
      final int categoryCompare = left.category.compareTo(right.category);
      if (categoryCompare != 0) {
        return categoryCompare;
      }
      final int relevanceCompare = right.stock.compareTo(left.stock);
      if (relevanceCompare != 0) {
        return relevanceCompare;
      }
      return left.priceBrl.compareTo(right.priceBrl);
    });
    return filtered;
  }

  Map<String, List<ProductItem>> get _groupedByTaxonomy {
    final Map<String, List<ProductItem>> grouped =
        <String, List<ProductItem>>{};
    for (final ProductItem item in _filteredItems) {
      grouped
          .putIfAbsent(item.googleTaxonomyPath, () => <ProductItem>[])
          .add(item);
    }
    final List<MapEntry<String, List<ProductItem>>>
    entries = grouped.entries.toList()
      ..sort((
        MapEntry<String, List<ProductItem>> left,
        MapEntry<String, List<ProductItem>> right,
      ) {
        final int sizeCompare = right.value.length.compareTo(left.value.length);
        if (sizeCompare != 0) {
          return sizeCompare;
        }
        return left.value.first.category.compareTo(right.value.first.category);
      });
    return <String, List<ProductItem>>{
      for (final MapEntry<String, List<ProductItem>> entry in entries)
        entry.key: entry.value,
    };
  }

  bool get _hasFocusedFilters {
    final double minPrice = _minCatalogPrice;
    final double maxPrice = math.max(minPrice, _maxCatalogPrice).toDouble();
    const double epsilon = 0.01;
    return _query.trim().isNotEmpty ||
        _selectedCategory != _allLabel ||
        _selectedSupplier != _allLabel ||
        _selectedCollection != _allLabel ||
        _selectedPriceBand != _allLabel ||
        (_priceRange.start - minPrice).abs() > epsilon ||
        (_priceRange.end - maxPrice).abs() > epsilon;
  }

  void _resetFilters() {
    setState(() {
      _query = '';
      _selectedCategory = _allLabel;
      _selectedSupplier = _allLabel;
      _selectedCollection = _allLabel;
      _selectedPriceBand = _allLabel;
      _syncPriceRange();
    });
  }

  Widget _buildStatGrid(BuildContext context) {
    final List<ProductItem> items = _filteredItems;
    final int categoryCount = _groupedByTaxonomy.length;
    final int collectionsCount = items
        .map((ProductItem item) => item.collectionLabel)
        .where((String value) => value.trim().isNotEmpty)
        .toSet()
        .length;
    final int supplierCount = items
        .map((ProductItem item) => item.customerVisibleSupplierName)
        .where((String value) => value.trim().isNotEmpty)
        .toSet()
        .length;
    final double averageTicket = items.isEmpty
        ? 0
        : items.fold<double>(
                0,
                (double sum, ProductItem item) => sum + item.priceBrl,
              ) /
              items.length;
    final List<Widget> cards = <Widget>[
      _StockStatCard(
        title: 'Itens reais',
        value: '${items.length}',
        accent: ValleyBrandColors.cyan,
        caption: _usingLiveCatalog
            ? 'Catálogo vivo sincronizado'
            : 'Catalogo preparado enquanto sincroniza',
      ),
      _StockStatCard(
        title: 'Categorias Google',
        value: '$categoryCount',
        accent: ValleyBrandColors.violet,
        caption: 'Agrupamento oficial da vitrine',
      ),
      _StockStatCard(
        title: 'Ticket medio',
        value: _formatCurrency(averageTicket),
        accent: const Color(0xFFD0BCFF),
        caption: 'Preco real dos itens exibidos',
      ),
      _StockStatCard(
        title: 'Lojas Valley',
        value: '$supplierCount',
        accent: const Color(0xFF7BE495),
        caption: '$collectionsCount coleções mapeadas na vitrine',
      ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 1160;
        if (compact) {
          return Column(
            children: cards
                .map(
                  (Widget card) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: card,
                  ),
                )
                .toList(),
          );
        }
        return Row(
          children: <Widget>[
            for (int index = 0; index < cards.length; index++) ...<Widget>[
              Expanded(child: cards[index]),
              if (index < cards.length - 1) const SizedBox(width: 14),
            ],
          ],
        );
      },
    );
  }

  Widget _buildFiltersPanel(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double maxPrice = _maxCatalogPrice;
    final double minPrice = _minCatalogPrice;

    return ValleyPanel(
      radius: 28,
      padding: const EdgeInsets.all(22),
      glowColor: ValleyBrandColors.violet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Filtros da loja',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Catálogo integrado, traduzido para português e pronto para leitura por loja, coleção, taxonomia e faixa de preço.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            onChanged: (String value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'Buscar por nome, modelo ou categoria',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: _softContainerColor(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            initialValue: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Categoria',
              filled: true,
            ),
            items: _categoryOptions
                .map(
                  (String value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  ),
                )
                .toList(),
            onChanged: (String? value) {
              if (value == null) {
                return;
              }
              setState(() => _selectedCategory = value);
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedSupplier,
            decoration: const InputDecoration(labelText: 'Loja', filled: true),
            items: _supplierOptions
                .map(
                  (String value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  ),
                )
                .toList(),
            onChanged: (String? value) {
              if (value == null) {
                return;
              }
              setState(() => _selectedSupplier = value);
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedCollection,
            decoration: const InputDecoration(
              labelText: 'Coleção / Modelo',
              filled: true,
            ),
            items: _collectionOptions
                .map(
                  (String value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  ),
                )
                .toList(),
            onChanged: (String? value) {
              if (value == null) {
                return;
              }
              setState(() => _selectedCollection = value);
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedPriceBand,
            decoration: const InputDecoration(
              labelText: 'Faixa de preço',
              filled: true,
            ),
            items: _priceBandOptions
                .map(
                  (String value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  ),
                )
                .toList(),
            onChanged: (String? value) {
              if (value == null) {
                return;
              }
              setState(() => _selectedPriceBand = value);
            },
          ),
          const SizedBox(height: 18),
          Text(
            'Recorte de preço',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _formatCurrency(_priceRange.start),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                _formatCurrency(_priceRange.end),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          RangeSlider(
            values: _priceRange,
            min: minPrice,
            max: math.max(minPrice, maxPrice).toDouble(),
            labels: RangeLabels(
              _formatCurrency(_priceRange.start),
              _formatCurrency(_priceRange.end),
            ),
            onChanged: _catalogItems.isEmpty
                ? null
                : (RangeValues values) {
                    setState(() => _priceRange = values);
                  },
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _resetFilters,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Limpar filtros'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsPanel(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Map<String, List<ProductItem>> grouped = _groupedByTaxonomy;
    final List<ProductItem> items = _filteredItems;
    final bool limitedOverview = !_hasFocusedFilters;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ValleyPanel(
          radius: 30,
          padding: const EdgeInsets.all(24),
          glowColor: ValleyBrandColors.cyan,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  SignalChip(
                    label: _loadingLiveCatalog
                        ? 'Sincronizando catálogo real'
                        : _usingLiveCatalog
                        ? '${items.length} itens reais filtrados'
                        : '${items.length} itens disponíveis offline',
                    color: _usingLiveCatalog
                        ? ValleyBrandColors.cyan
                        : const Color(0xFFF6C760),
                    outlined: !_usingLiveCatalog,
                  ),
                  const SignalChip(label: 'Catálogo traduzido pt-BR'),
                  SignalChip(
                    label: '${_supplierOptions.length - 1} lojas ativas',
                    outlined: true,
                    color: ValleyBrandColors.violet,
                  ),
                  const SignalChip(label: 'Taxonomia Google', outlined: true),
                  SignalChip(
                    label: '${grouped.length} agrupamentos ativos',
                    outlined: true,
                    color: const Color(0xFFD0BCFF),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Catálogo proprietário organizado por categoria',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _catalogError == null
                    ? 'A vitrine reúne itens reais com tradução pt-BR, carrossel de mídia e leitura por categoria, loja e coleção.'
                    : 'O catalogo externo nao respondeu nesta tentativa. A vitrine manteve os itens embarcados para compra.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (limitedOverview) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  'Sem filtro, cada bloco mostra só os itens mais relevantes. Ao escolher uma loja ou categoria, o catálogo completo daquela linha é liberado.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _supplierOptions.skip(1).map((String supplier) {
            final bool active = _selectedSupplier == supplier;
            return InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => setState(
                () => _selectedSupplier = active ? _allLabel : supplier,
              ),
              child: _FilterChip(label: supplier, active: active),
            );
          }).toList(),
        ),
        const SizedBox(height: 22),
        if (items.isEmpty)
          ValleyPanel(
            radius: 28,
            padding: const EdgeInsets.all(28),
            child: Text(
              'Nenhum item encontrado para o recorte atual. Ajuste loja, categoria, coleção ou faixa de preço.',
              style: theme.textTheme.bodyLarge,
            ),
          )
        else
          for (final MapEntry<String, List<ProductItem>> entry
              in grouped.entries) ...<Widget>[
            _StockCategoryBlock(
              taxonomyPath: entry.key,
              items: limitedOverview
                  ? entry.value.take(24).toList(growable: false)
                  : entry.value,
              totalItems: entry.value.length,
              onTap: widget.onTap,
            ),
            const SizedBox(height: 20),
          ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          kicker: 'Stock Mode',
          title: 'Valley Stock | catálogo real por categoria',
          caption:
              'Estoque em modo produto com catálogo integrado, tradução pt-BR, carrossel de mídia e filtros por loja, coleção e taxonomia.',
          trailing: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              const SignalChip(label: 'Compra protegida'),
              const SignalChip(label: 'Carrossel ativo', outlined: true),
              SignalChip(
                label: _usingLiveCatalog
                    ? '${_catalogItems.length} itens reais'
                    : 'Operacao preparada',
                outlined: !_usingLiveCatalog,
                color: _usingLiveCatalog
                    ? ValleyBrandColors.cyan
                    : const Color(0xFFF6C760),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _buildStatGrid(context),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compact = constraints.maxWidth < 1080;
            if (compact) {
              return Column(
                children: <Widget>[
                  _buildFiltersPanel(context),
                  const SizedBox(height: 18),
                  _buildResultsPanel(context),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(width: 320, child: _buildFiltersPanel(context)),
                const SizedBox(width: 18),
                Expanded(child: _buildResultsPanel(context)),
              ],
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
    final ThemeData theme = Theme.of(context);
    return ValleyPanel(
      radius: 22,
      padding: const EdgeInsets.all(20),
      glowColor: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
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

class _StockCategoryBlock extends StatelessWidget {
  const _StockCategoryBlock({
    required this.taxonomyPath,
    required this.items,
    required this.totalItems,
    required this.onTap,
  });

  final String taxonomyPath;
  final List<ProductItem> items;
  final int totalItems;
  final ValueChanged<ProductItem> onTap;

  @override
  Widget build(BuildContext context) {
    final ProductItem hero = items.first;
    final List<String> segments = taxonomyPath
        .split('>')
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList();
    final String displayTitle = hero.category;
    final String taxonomyLeaf = segments.isEmpty
        ? hero.taxonomyLeaf
        : segments.last;

    return Column(
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
                    displayTitle,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${hero.googleTaxonomyId} • $taxonomyPath',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _MetaPill(
              icon: Icons.inventory_2_rounded,
              label: items.length == totalItems
                  ? '$totalItems itens em $taxonomyLeaf'
                  : '${items.length} de $totalItems itens em $taxonomyLeaf',
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            int crossAxisCount = 1;
            if (constraints.maxWidth >= 1360) {
              crossAxisCount = 3;
            } else if (constraints.maxWidth >= 760) {
              crossAxisCount = 2;
            }
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: constraints.maxWidth >= 1180 ? 0.68 : 0.74,
              ),
              itemBuilder: (BuildContext context, int index) {
                final ProductItem item = items[index];
                return _StockCard(item: item, onTap: () => onTap(item));
              },
            );
          },
        ),
      ],
    );
  }
}

// ignore: unused_element
class _DropshipApiIntegrationPage extends StatelessWidget {
  const _DropshipApiIntegrationPage();

  static const List<_SupplierApiSpec> _suppliers = <_SupplierApiSpec>[
    _SupplierApiSpec(
      name: 'Mercado Livre',
      status: 'Fluxo OAuth preparado',
      region: 'Brasil',
      auth: 'OAuth 2.0 + offline_access',
      scope: 'Catálogo, preço, pedidos e inventário',
      steps: <String>[
        'Autorizar a conta seller com callback fixa do Valley Admin.',
        'Persistir access token e refresh token no runtime seguro do host.',
        'Sincronizar catálogo, preço e estoque antes de abrir pedidos em escala.',
        'Operar inicialmente por polling, com webhook opcional numa segunda fase.',
      ],
    ),
    _SupplierApiSpec(
      name: 'AliExpress',
      status: 'Pronto para credenciais',
      region: 'BR / Global',
      auth: 'OAuth 2.0 + App Key',
      scope: 'Catálogo, preço, pedido e tracking',
      steps: <String>[
        'Criar app no portal do fornecedor e registrar a URL de callback Valley.',
        'Salvar App Key, App Secret e Seller ID apenas como referência segura no Admin.',
        'Executar a sincronização inicial de catálogo e gravar snapshots de preço.',
        'Ativar decisão de margem append-only antes de publicar no Marketplace.',
      ],
    ),
    _SupplierApiSpec(
      name: 'Alibaba',
      status: 'Mapeamento B2B',
      region: 'Global',
      auth: 'API Key + assinatura',
      scope: 'Fornecedores, MOQ, custo e cotação',
      steps: <String>[
        'Cadastrar a conta corporativa e confirmar permissões de produto e cotação.',
        'Associar supplier_id ao provider_config no banco relacional.',
        'Importar amostras com MOQ, prazo e custo estimado por lote.',
        'Bloquear publicação automática quando margem, prazo ou estoque ficarem abaixo do piso.',
      ],
    ),
    _SupplierApiSpec(
      name: 'CJDropshipping',
      status: 'Operação automatizável',
      region: 'US / CN / BR',
      auth: 'Access Token rotativo',
      scope: 'Pedido automático, fulfillment e tracking',
      steps: <String>[
        'Gerar access token no painel CJ e armazenar somente referência criptográfica.',
        'Vincular SKU externo ao item Valley Stock com canal e margem mínima.',
        'Enviar pedido ao fornecedor somente após validação de pagamento/contrato.',
        'Consumir tracking e atualizar a fila operacional de dropshipping.',
      ],
    ),
    _SupplierApiSpec(
      name: 'Shopee / Magalu / Amazon',
      status: 'Fonte de preço',
      region: 'Brasil',
      auth: 'Seller API ou fallback controlado',
      scope: 'Benchmark competitivo e teto de preço',
      steps: <String>[
        'Configurar cada marketplace como fonte de preço, não como fornecedor primário.',
        'Definir TTL de cache e limites de chamada por canal.',
        'Comparar preço Valley contra o mercado antes de ativar oferta.',
        'Registrar cada decisão de precificação para auditoria e rollback.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ValleyPanel(
      radius: 28,
      padding: const EdgeInsets.all(24),
      glowColor: ValleyBrandColors.violet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 14,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: <Color>[
                      ValleyBrandColors.cyan,
                      ValleyBrandColors.violet,
                    ],
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: ValleyBrandColors.cyan.withValues(alpha: 0.28),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.hub_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Central de Integração Dropship',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Página operacional ligada ao blueprint de produção do Stock. Ela prepara as APIs de fornecedores, snapshots de preço, decisões append-only e fila de pedidos ao fornecedor.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.68),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const <Widget>[
              _MetaPill(
                icon: Icons.storage_rounded,
                label: 'DB: dropshipping_provider_configs',
              ),
              _MetaPill(
                icon: Icons.price_change_rounded,
                label: 'DB: dropshipping_pricing_decisions',
              ),
              _MetaPill(
                icon: Icons.receipt_long_rounded,
                label: 'DB: dropshipping_supplier_orders',
              ),
              _MetaPill(
                icon: Icons.task_alt_rounded,
                label: 'Fila: dropshipping_jobs',
              ),
            ],
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool compact = constraints.maxWidth < 900;
              final Widget pipeline = _DropshipPipeline(compact: compact);
              final Widget checklist = const _DropshipChecklist();
              if (compact) {
                return Column(
                  children: <Widget>[
                    pipeline,
                    const SizedBox(height: 16),
                    checklist,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(flex: 5, child: pipeline),
                  const SizedBox(width: 16),
                  const Expanded(flex: 4, child: _DropshipChecklist()),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final int columns = constraints.maxWidth >= 1180 ? 2 : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _suppliers.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: constraints.maxWidth >= 1180 ? 1.45 : 1.18,
                ),
                itemBuilder: (BuildContext context, int index) {
                  return _SupplierApiCard(spec: _suppliers[index]);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DropshipPipeline extends StatelessWidget {
  const _DropshipPipeline({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final List<String> stages = <String>[
      'Credencial segura',
      'Catálogo importado',
      'Preço comparado',
      'Margem validada',
      'Pedido enviado',
      'Tracking ativo',
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0x66080D1D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Fluxo vivo da integração',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: stages.asMap().entries.map((MapEntry<int, String> item) {
              return Container(
                width: compact ? double.infinity : 150,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: item.key < 3
                      ? ValleyBrandColors.cyan.withValues(alpha: 0.10)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: item.key < 3
                        ? ValleyBrandColors.cyan.withValues(alpha: 0.28)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      item.key < 3
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: item.key < 3
                          ? ValleyBrandColors.cyan
                          : Colors.white38,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.value,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _DropshipChecklist extends StatelessWidget {
  const _DropshipChecklist();

  @override
  Widget build(BuildContext context) {
    const List<String> steps = <String>[
      'Nunca gravar segredo bruto: usar secret_ref, hash ou vault externo.',
      'Cada importação deve criar snapshot de preço e custo com timestamp.',
      'Toda decisão de margem entra em ledger append-only.',
      'Pedido ao fornecedor só nasce depois de validação econômica e documental.',
      'Falha de API cria job de retentativa com backoff e motivo visível.',
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ValleyBrandColors.violet.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: ValleyBrandColors.violet.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Passo a passo obrigatório',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          for (int index = 0; index < steps.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: ValleyBrandColors.cyan,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Color(0xFF00363D),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      steps[index],
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.76),
                        height: 1.35,
                      ),
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

class _SupplierApiSpec {
  const _SupplierApiSpec({
    required this.name,
    required this.status,
    required this.region,
    required this.auth,
    required this.scope,
    required this.steps,
  });

  final String name;
  final String status;
  final String region;
  final String auth;
  final String scope;
  final List<String> steps;
}

class _SupplierApiCard extends StatelessWidget {
  const _SupplierApiCard({required this.spec});

  final _SupplierApiSpec spec;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xAA121A2F),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  spec.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              _MetaPill(icon: Icons.api_rounded, label: spec.status),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _MetaPill(icon: Icons.public_rounded, label: spec.region),
              _MetaPill(icon: Icons.key_rounded, label: spec.auth),
              _MetaPill(icon: Icons.sync_alt_rounded, label: spec.scope),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: spec.steps.length,
              itemBuilder: (BuildContext context, int index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.arrow_right_rounded,
                        color: ValleyBrandColors.cyan.withValues(alpha: 0.90),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          spec.steps[index],
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.70),
                            height: 1.28,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StockCard extends StatelessWidget {
  const _StockCard({required this.item, required this.onTap});

  final ProductItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = ValleyBrandColors.cyan;
    final ThemeData theme = Theme.of(context);
    final Color stageColor = _mediaStageColor(context);

    return ValleyPanel(
      radius: 26,
      padding: const EdgeInsets.all(16),
      glowColor: accent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: stageColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _softBorderColor(context)),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    _ProductGalleryCarousel(
                      imageUrls: item.mediaGallery,
                      fit: BoxFit.contain,
                      emptyColor: stageColor,
                      compact: true,
                      imagePadding: const EdgeInsets.all(18),
                    ),
                    Positioned(
                      top: 14,
                      left: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xCC0E1323),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.24),
                          ),
                        ),
                        child: Text(
                          item.category,
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                    if (item.hasVideo)
                      Positioned(
                        top: 14,
                        right: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xCC0E1323),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: ValleyBrandColors.violet.withValues(
                                alpha: 0.30,
                              ),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.play_circle_fill_rounded,
                                color: ValleyBrandColors.violet,
                                size: 14,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Vídeo',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
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
            ),
            const SizedBox(height: 16),
            Text(
              item.collectionLabel.toUpperCase(),
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.shortTitlePtBr,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.taxonomyLeaf,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              item.descriptionPtBr,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _MetaPill(
                  icon: Icons.storefront_rounded,
                  label: item.customerVisibleSupplierName,
                ),
                _MetaPill(
                  icon: Icons.category_rounded,
                  label: item.taxonomyLeaf,
                ),
                _MetaPill(icon: Icons.sell_rounded, label: item.priceBand),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'R\$ ${item.priceBrl.toStringAsFixed(2)}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (item.compareAtBrl > item.priceBrl)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'R\$ ${item.compareAtBrl.toStringAsFixed(2)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              decoration: TextDecoration.lineThrough,
                            ),
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
                      item.availabilityLabel,
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.status,
                      textAlign: TextAlign.right,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: ValleyBrandColors.cyan,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton(
                    onPressed: onTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: const Color(0xFF001F24),
                    ),
                    child: const Text('VER PRODUTO'),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: onTap,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Icon(Icons.arrow_outward_rounded),
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: _softContainerColor(
          context,
          lightAlpha: active ? 1 : 0.86,
          darkAlpha: active ? 0.10 : 0.05,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active
              ? ValleyBrandColors.cyan.withValues(alpha: 0.50)
              : _softBorderColor(context, darkAlpha: 0.05),
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
  const _RecentActivityPanel({required this.items, required this.onTap});

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
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          for (int i = 0; i < items.length; i++) ...<Widget>[
            _RecentRow(
              item: items[i],
              primaryIcon: i == 0
                  ? Icons.account_balance_wallet_rounded
                  : Icons.shopping_bag_rounded,
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
                color:
                    (highlight
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
                    highlight
                        ? 'Transferência Recebida'
                        : 'Aquisição ${item.brand}',
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
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    required this.onAddToCart,
    required this.onCheckout,
    required this.onShare,
    required this.onChat,
  });

  final ProductItem item;
  final Map<String, dynamic>? profile;
  final VoidCallback? onPlay;
  final VoidCallback onAddToCart;
  final VoidCallback onCheckout;
  final VoidCallback onShare;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<dynamic> features =
        item.raw['features'] as List<dynamic>? ?? const <dynamic>[];
    final Map<String, dynamic> seller =
        (item.raw['seller'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{})
            .cast<String, dynamic>();

    final Widget summaryPanel = ValleyPanel(
      radius: 28,
      padding: const EdgeInsets.all(22),
      glowColor: ValleyBrandColors.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _MetaPill(icon: Icons.category_rounded, label: item.category),
              _MetaPill(icon: Icons.hub_rounded, label: item.taxonomyLeaf),
              _MetaPill(icon: Icons.sell_rounded, label: item.priceBand),
              if (item.hasVideo)
                const _MetaPill(
                  icon: Icons.play_circle_fill_rounded,
                  label: 'Vídeo disponível',
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            item.brand.toUpperCase(),
            style: const TextStyle(
              color: ValleyBrandColors.cyan,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            item.titlePtBr,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            item.modelName,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            item.descriptionPtBr,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'R\$ ${item.priceBrl.toStringAsFixed(2)}',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: ValleyBrandColors.cyan,
            ),
          ),
          if (item.compareAtBrl > item.priceBrl) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'De R\$ ${item.compareAtBrl.toStringAsFixed(2)}',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '${item.availabilityLabel} • ${item.status}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              FilledButton.icon(
                onPressed: onCheckout,
                icon: const Icon(Icons.shopping_cart_checkout_rounded),
                label: const Text('Comprar agora'),
              ),
              OutlinedButton.icon(
                onPressed: onAddToCart,
                icon: const Icon(Icons.add_shopping_cart_rounded),
                label: const Text('Adicionar ao carrinho'),
              ),
              OutlinedButton.icon(
                onPressed: onShare,
                icon: const Icon(Icons.share_rounded),
                label: const Text('Compartilhar oferta'),
              ),
              if (item.hasVideo)
                OutlinedButton.icon(
                  onPressed: onPlay,
                  icon: const Icon(Icons.play_circle_fill_rounded),
                  label: Text(
                    onPlay == null ? 'Vídeo catalogado' : 'Assistir vídeo',
                  ),
                ),
              OutlinedButton.icon(
                onPressed: onChat,
                icon: const Icon(Icons.chat_bubble_rounded),
                label: const Text('Perguntar no chat'),
              ),
            ],
          ),
        ],
      ),
    );

    final Widget sellerPanel = ValleyPanel(
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
                  (profile?['avatar_url'] ??
                          seller['avatar_url'] ??
                          item.imageUrl)
                      .toString(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      (profile?['name'] ?? seller['name'] ?? item.merchantName)
                          .toString(),
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
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _MetaPill(
                icon: Icons.storefront_rounded,
                label: item.customerVisibleSupplierName,
              ),
              _MetaPill(icon: Icons.sync_alt_rounded, label: 'Operação Valley'),
              _MetaPill(icon: Icons.route_rounded, label: 'Envio acompanhado'),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Entrega e garantia',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'A compra mantém item, valor, entrega e rastreio vinculados à sua conta. Quando houver vídeo do produto, ele ocupa a mídia principal da ficha.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );

    final Widget descriptionPanel = ValleyPanel(
      radius: 28,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Descrição e destaques',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            item.descriptionPtBr,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: features
                .map(
                  (dynamic feature) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _softContainerColor(
                        context,
                        lightAlpha: 0.96,
                        darkAlpha: 0.05,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(feature.toString()),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 1120;
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _ProductMediaStage(item: item, onPlay: onPlay),
              const SizedBox(height: 18),
              summaryPanel,
              const SizedBox(height: 18),
              descriptionPanel,
              const SizedBox(height: 18),
              sellerPanel,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 7,
                  child: _ProductMediaStage(item: item, onPlay: onPlay),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 5,
                  child: Column(
                    children: <Widget>[
                      summaryPanel,
                      const SizedBox(height: 18),
                      sellerPanel,
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            descriptionPanel,
          ],
        );
      },
    );
  }
}

class _CheckoutScreen extends StatefulWidget {
  const _CheckoutScreen({
    required this.item,
    required this.baseUrl,
    required this.repository,
    required this.authRequired,
    required this.authSession,
    required this.useProfileAddress,
    required this.onUseProfileAddressChanged,
    required this.onConfirm,
    required this.onIdentity,
    required this.onCancel,
  });

  final ProductItem item;
  final String baseUrl;
  final ProductApiRepository repository;
  final bool authRequired;
  final ProductAuthSession? authSession;
  final bool useProfileAddress;
  final ValueChanged<bool> onUseProfileAddressChanged;
  final void Function(Map<String, String> deliveryAddress, bool useProfile)
  onConfirm;
  final VoidCallback onIdentity;
  final VoidCallback onCancel;

  @override
  State<_CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<_CheckoutScreen> {
  late bool _useProfileAddress;
  late final TextEditingController _recipientController;
  late final TextEditingController _postalCodeController;
  late final TextEditingController _streetController;
  late final TextEditingController _numberController;
  late final TextEditingController _complementController;
  late final TextEditingController _neighborhoodController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  Timer? _shippingQuoteTimer;
  bool _shippingQuoteBusy = false;
  Map<String, dynamic>? _shippingQuote;
  String _lastShippingQuoteKey = '';

  Map<String, String> get _profileAddress =>
      widget.authSession?.user.defaultDeliveryAddress ??
      const <String, String>{};

  @override
  void initState() {
    super.initState();
    _useProfileAddress = widget.useProfileAddress && _profileAddress.isNotEmpty;
    _recipientController = TextEditingController(
      text:
          _profileAddress['recipient_name'] ??
          widget.authSession?.user.fullName ??
          '',
    );
    _postalCodeController = TextEditingController(
      text: _profileAddress['postal_code'] ?? '',
    );
    _streetController = TextEditingController(
      text: _profileAddress['street'] ?? '',
    );
    _numberController = TextEditingController(
      text: _profileAddress['number'] ?? '',
    );
    _complementController = TextEditingController(
      text: _profileAddress['complement'] ?? '',
    );
    _neighborhoodController = TextEditingController(
      text: _profileAddress['neighborhood'] ?? '',
    );
    _cityController = TextEditingController(
      text: _profileAddress['city'] ?? '',
    );
    _stateController = TextEditingController(
      text: _profileAddress['state'] ?? '',
    );
    for (final TextEditingController controller in <TextEditingController>[
      _recipientController,
      _postalCodeController,
      _streetController,
      _numberController,
      _complementController,
      _neighborhoodController,
      _cityController,
      _stateController,
    ]) {
      controller.addListener(_scheduleShippingQuote);
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scheduleShippingQuote(),
    );
  }

  @override
  void dispose() {
    _shippingQuoteTimer?.cancel();
    _recipientController.dispose();
    _postalCodeController.dispose();
    _streetController.dispose();
    _numberController.dispose();
    _complementController.dispose();
    _neighborhoodController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  Map<String, String> _deliveryAddress() {
    if (_useProfileAddress && _profileAddress.isNotEmpty) {
      return Map<String, String>.from(_profileAddress);
    }
    return <String, String>{
      'recipient_name': _recipientController.text,
      'postal_code': _postalCodeController.text,
      'street': _streetController.text,
      'number': _numberController.text,
      'complement': _complementController.text,
      'neighborhood': _neighborhoodController.text,
      'city': _cityController.text,
      'state': _stateController.text,
      'country': 'BR',
    };
  }

  bool _deliveryAddressComplete(Map<String, String> address) {
    for (final String key in <String>[
      'recipient_name',
      'postal_code',
      'street',
      'number',
      'neighborhood',
      'city',
      'state',
    ]) {
      if ((address[key] ?? '').trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  void _scheduleShippingQuote() {
    _shippingQuoteTimer?.cancel();
    _shippingQuoteTimer = Timer(
      const Duration(milliseconds: 450),
      _refreshShippingQuote,
    );
  }

  Future<void> _refreshShippingQuote() async {
    final Map<String, String> address = _deliveryAddress();
    final String quoteKey =
        '${widget.item.id}|${address.entries.map((MapEntry<String, String> entry) => '${entry.key}:${entry.value.trim()}').join('|')}';
    if (!_deliveryAddressComplete(address) ||
        quoteKey == _lastShippingQuoteKey) {
      return;
    }
    _lastShippingQuoteKey = quoteKey;
    if (mounted) {
      setState(() => _shippingQuoteBusy = true);
    }
    try {
      final ProductActionResult result = await widget.repository.invokePath(
        baseUrl: widget.baseUrl,
        path:
            '/api/actions/shipping-quote?item_id=${Uri.encodeComponent(widget.item.id)}',
        body: <String, dynamic>{'delivery_address': address},
      );
      if (!mounted) {
        return;
      }
      final Map<String, dynamic> quote =
          (result.payload['shipping_quote'] as Map<dynamic, dynamic>? ??
                  <dynamic, dynamic>{})
              .cast<String, dynamic>();
      setState(() {
        _shippingQuote = result.ok ? quote : null;
        _shippingQuoteBusy = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _shippingQuoteBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Map<String, dynamic> checkout =
        (widget.item.raw['checkout'] as Map<dynamic, dynamic>? ??
                <dynamic, dynamic>{})
            .cast<String, dynamic>();
    final Map<String, dynamic> shippingQuote =
        _shippingQuote ?? const <String, dynamic>{};
    final double shipping =
        (shippingQuote['shipping_passthrough_brl'] as num?)?.toDouble() ??
        (checkout['shipping_brl'] as num?)?.toDouble() ??
        19.9;
    final double service = (checkout['service_brl'] as num?)?.toDouble() ?? 4.9;
    final double total = widget.item.priceBrl + shipping + service;
    final List<Map<String, dynamic>> shippingSuggestions =
        (shippingQuote['suggestions'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<dynamic, dynamic>>()
            .map((Map<dynamic, dynamic> item) => item.cast<String, dynamic>())
            .toList();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 900;
        final Widget totals = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _CheckoutRow(
              label: widget.item.titlePtBr,
              value: 'R\$ ${widget.item.priceBrl.toStringAsFixed(2)}',
            ),
            _CheckoutRow(
              label: _shippingQuote == null
                  ? 'Frete da entrega'
                  : 'Frete consultado',
              value: 'R\$ ${shipping.toStringAsFixed(2)}',
            ),
            if (_shippingQuoteBusy)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(minHeight: 3),
              ),
            if (_shippingQuote != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '${shippingQuote['customer_visible_supplier_name'] ?? widget.item.customerVisibleSupplierName} • ${shippingQuote['eta'] ?? checkout['eta'] ?? 'prazo de entrega'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            for (final Map<String, dynamic> suggestion in shippingSuggestions)
              _TrustSignalRow(
                icon: Icons.local_offer_rounded,
                title: suggestion['title']?.toString() ?? 'Sugestão de frete',
                body:
                    suggestion['detail']?.toString() ??
                    'A loja recomenda ajustar a compra para reduzir o frete.',
              ),
            _CheckoutRow(
              label: 'Servico Valley',
              value: 'R\$ ${service.toStringAsFixed(2)}',
            ),
            const Divider(height: 28),
            _CheckoutRow(
              label: 'Total',
              value: 'R\$ ${total.toStringAsFixed(2)}',
              highlight: true,
            ),
          ],
        );

        final Widget trustPanel = ValleyPanel(
          radius: 24,
          padding: const EdgeInsets.all(18),
          glowColor: ValleyBrandColors.violet,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Confiança da operação',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const _TrustSignalRow(
                icon: Icons.verified_user_rounded,
                title: 'Identity Score 92',
                body: 'Compra liberada com trilha antifraude explicável.',
              ),
              const _TrustSignalRow(
                icon: Icons.point_of_sale_rounded,
                title: 'Pagamento protegido',
                body:
                    'O pagamento abre em ambiente seguro com retorno ao pedido.',
              ),
              const _TrustSignalRow(
                icon: Icons.description_rounded,
                title: 'Comprovante do pedido',
                body:
                    'A confirmação mantém item, valor e entrega vinculados à conta.',
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: widget.onIdentity,
                icon: const Icon(Icons.face_retouching_natural_rounded),
                label: const Text('Ativar Face ID'),
              ),
            ],
          ),
        );

        final Widget addressPanel = ValleyPanel(
          radius: 24,
          padding: const EdgeInsets.all(18),
          glowColor: ValleyBrandColors.cyan,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Endereço de entrega',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              if (_profileAddress.isNotEmpty)
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _useProfileAddress,
                  onChanged: (bool value) {
                    setState(() => _useProfileAddress = value);
                    widget.onUseProfileAddressChanged(value);
                    _scheduleShippingQuote();
                  },
                  title: const Text('Usar endereço do cadastro'),
                  subtitle: Text(
                    '${_profileAddress['street'] ?? ''}, ${_profileAddress['number'] ?? ''} - ${_profileAddress['city'] ?? ''}/${_profileAddress['state'] ?? ''}',
                  ),
                ),
              if (!_useProfileAddress || _profileAddress.isEmpty) ...<Widget>[
                _AuthTextField(
                  controller: _recipientController,
                  label: 'Nome do destinatário',
                  hintText: 'Nome completo',
                ),
                const SizedBox(height: 10),
                _AuthTextField(
                  controller: _postalCodeController,
                  label: 'CEP',
                  hintText: '00000-000',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                _AuthTextField(
                  controller: _streetController,
                  label: 'Endereço',
                  hintText: 'Rua, avenida ou estrada',
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _AuthTextField(
                        controller: _numberController,
                        label: 'Número',
                        hintText: 'Número',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _AuthTextField(
                        controller: _complementController,
                        label: 'Complemento',
                        hintText: 'Apto, bloco',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _AuthTextField(
                  controller: _neighborhoodController,
                  label: 'Bairro',
                  hintText: 'Bairro',
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      flex: 3,
                      child: _AuthTextField(
                        controller: _cityController,
                        label: 'Cidade',
                        hintText: 'Cidade',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _AuthTextField(
                        controller: _stateController,
                        label: 'UF',
                        hintText: 'SP',
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );

        final Widget body = compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  totals,
                  const SizedBox(height: 18),
                  addressPanel,
                  const SizedBox(height: 18),
                  trustPanel,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: totals),
                  const SizedBox(width: 20),
                  Expanded(child: addressPanel),
                  const SizedBox(width: 20),
                  Expanded(child: trustPanel),
                ],
              );

        return ValleyPanel(
          radius: 30,
          padding: const EdgeInsets.all(24),
          glowColor: ValleyBrandColors.cyan,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _StitchP0MobileRail(
                activeKeys: const <String>{'checkout'},
                title: 'Checkout mobile',
                subtitle: widget.authRequired
                    ? 'Login necessário antes do pagamento seguro.'
                    : 'Sessão ativa para frete, endereço e pagamento.',
              ),
              const SizedBox(height: 20),
              Text(
                widget.item.titlePtBr,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'R\$ ${widget.item.priceBrl.toStringAsFixed(2)} • Entrega prevista em ${checkout['eta']?.toString() ?? '2 dias'}.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              body,
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: () => widget.onConfirm(
                      _deliveryAddress(),
                      _useProfileAddress && _profileAddress.isNotEmpty,
                    ),
                    icon: Icon(
                      widget.authRequired
                          ? Icons.login_rounded
                          : Icons.lock_rounded,
                    ),
                    label: Text(
                      widget.authRequired
                          ? 'Entrar para pagar'
                          : 'Ir para pagamento seguro',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.shopping_bag_rounded),
                    label: const Text('Voltar ao carrinho'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StitchP0MobileRail extends StatelessWidget {
  const _StitchP0MobileRail({
    required this.activeKeys,
    required this.title,
    required this.subtitle,
  });

  final Set<String> activeKeys;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _softContainerColor(context, lightAlpha: 0.98, darkAlpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: ValleyBrandColors.cyan.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: ValleyBrandColors.cyan.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.view_quilt_rounded,
                  color: ValleyBrandColors.cyan,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double itemWidth = constraints.maxWidth < 520 ? 132 : 152;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  for (final _StitchP0MobileStep step in _stitchP0MobileSteps)
                    SizedBox(
                      width: itemWidth,
                      child: _StitchP0MobileStage(
                        step: step,
                        active: activeKeys.contains(step.key),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StitchP0MobileStage extends StatelessWidget {
  const _StitchP0MobileStage({required this.step, required this.active});

  final _StitchP0MobileStep step;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = active
        ? ValleyBrandColors.cyan
        : theme.colorScheme.onSurfaceVariant;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active
            ? ValleyBrandColors.cyan.withValues(alpha: 0.14)
            : _softContainerColor(context, lightAlpha: 0.92, darkAlpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active
              ? ValleyBrandColors.cyan.withValues(alpha: 0.50)
              : _softBorderColor(context, lightAlpha: 0.75, darkAlpha: 0.08),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(step.icon, color: accent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  step.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  step.detail,
                  maxLines: 1,
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
    );
  }
}

class _TrustSignalRow extends StatelessWidget {
  const _TrustSignalRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: ValleyBrandColors.cyan, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.35,
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

class _CartScreen extends StatelessWidget {
  const _CartScreen({
    required this.items,
    required this.fallbackItem,
    required this.onRemove,
    required this.onBrowse,
    required this.onCheckout,
  });

  final List<ProductItem> items;
  final ProductItem? fallbackItem;
  final ValueChanged<ProductItem> onRemove;
  final VoidCallback onBrowse;
  final ValueChanged<ProductItem> onCheckout;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<ProductItem> visibleItems = items.isEmpty && fallbackItem != null
        ? <ProductItem>[fallbackItem!]
        : items;
    final double subtotal = visibleItems.fold<double>(
      0,
      (double total, ProductItem item) => total + item.priceBrl,
    );

    if (visibleItems.isEmpty) {
      return _EmptyStatePanel(
        icon: Icons.shopping_bag_rounded,
        title: 'Carrinho pronto para o primeiro item',
        body:
            'Explore o marketplace ou importe produtos no Stock para iniciar uma compra preparada.',
        primaryLabel: 'Explorar marketplace',
        onPrimary: onBrowse,
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 900;
        final Widget itemsPanel = ValleyPanel(
          radius: 30,
          padding: const EdgeInsets.all(22),
          glowColor: ValleyBrandColors.violet,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Resumo rápido',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              for (final ProductItem item in visibleItems)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.network(
                          item.imageUrl,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const ColoredBox(color: Color(0xFF171D31)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item.merchantName} • ${item.availabilityLabel}',
                              maxLines: 1,
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
                            'R\$ ${item.priceBrl.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: ValleyBrandColors.cyan,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          TextButton(
                            onPressed: () => onRemove(item),
                            child: const Text('Remover'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );

        final Widget totalsPanel = ValleyPanel(
          radius: 30,
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Checkout preparado',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              _CheckoutRow(
                label: 'Subtotal',
                value: 'R\$ ${subtotal.toStringAsFixed(2)}',
              ),
              _CheckoutRow(
                label: 'Entrega estimada',
                value: 'R\$ ${(visibleItems.length * 19.9).toStringAsFixed(2)}',
              ),
              _CheckoutRow(
                label: 'Taxa Valley',
                value: 'R\$ ${(visibleItems.length * 4.9).toStringAsFixed(2)}',
              ),
              const Divider(height: 28),
              _CheckoutRow(
                label: 'Total',
                value:
                    'R\$ ${(subtotal + visibleItems.length * 24.8).toStringAsFixed(2)}',
                highlight: true,
              ),
              const SizedBox(height: 14),
              Text(
                'A Valley valida estoque, margem e identidade antes de confirmar o pedido.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => onCheckout(visibleItems.first),
                  icon: const Icon(Icons.lock_rounded),
                  label: const Text('Finalizar compra'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onBrowse,
                  icon: const Icon(Icons.storefront_rounded),
                  label: const Text('Continuar comprando'),
                ),
              ),
            ],
          ),
        );

        if (compact) {
          return Column(
            children: <Widget>[
              itemsPanel,
              const SizedBox(height: 18),
              totalsPanel,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(flex: 7, child: itemsPanel),
            const SizedBox(width: 20),
            Expanded(flex: 4, child: totalsPanel),
          ],
        );
      },
    );
  }
}

class _ConfirmationScreen extends StatelessWidget {
  const _ConfirmationScreen({
    required this.item,
    required this.onOpenReceipt,
    required this.onOpenOrders,
    required this.onContinueShopping,
    required this.onSupport,
  });

  final ProductItem item;
  final VoidCallback onOpenReceipt;
  final VoidCallback onOpenOrders;
  final VoidCallback onContinueShopping;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double total = item.priceBrl + 24.8;
    return ValleyPanel(
      radius: 34,
      padding: const EdgeInsets.all(26),
      glowColor: ValleyBrandColors.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ValleyBrandColors.cyan.withValues(alpha: 0.16),
                  border: Border.all(
                    color: ValleyBrandColors.cyan.withValues(alpha: 0.45),
                  ),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: ValleyBrandColors.cyan,
                  size: 34,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Pedido confirmado',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'VAL-${item.id.hashCode.abs().toString().padLeft(6, '0').substring(0, 6)} • Plug e Docs preparados',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _PreparedOrderStrip(item: item, total: total),
          const SizedBox(height: 22),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              FilledButton.icon(
                onPressed: onOpenReceipt,
                icon: const Icon(Icons.description_rounded),
                label: const Text('Abrir comprovante'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenOrders,
                icon: const Icon(Icons.local_shipping_rounded),
                label: const Text('Ver pedido'),
              ),
              OutlinedButton.icon(
                onPressed: onContinueShopping,
                icon: const Icon(Icons.storefront_rounded),
                label: const Text('Continuar comprando'),
              ),
              OutlinedButton.icon(
                onPressed: onSupport,
                icon: const Icon(Icons.support_agent_rounded),
                label: const Text('Falar com suporte'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreparedOrderStrip extends StatelessWidget {
  const _PreparedOrderStrip({required this.item, required this.total});

  final ProductItem item;
  final double total;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.network(
              item.imageUrl,
              width: 76,
              height: 76,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const ColoredBox(color: Color(0xFF171D31)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${item.merchantName} • comprovante com checksum',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'R\$ ${total.toStringAsFixed(2)}',
            style: theme.textTheme.titleLarge?.copyWith(
              color: ValleyBrandColors.cyan,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptScreen extends StatelessWidget {
  const _ReceiptScreen({required this.item});

  final ProductItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String checksum =
        'VX-${item.id.hashCode.abs().toRadixString(16).padLeft(8, '0').toUpperCase()}';
    final String receiptText =
        'Comprovante Valley\nPedido VAL-${item.id}\nProduto: ${item.title}\nSeller: ${item.merchantName}\nValor: R\$ ${(item.priceBrl + 24.8).toStringAsFixed(2)}\nChecksum: $checksum';
    return ValleyPanel(
      radius: 32,
      padding: const EdgeInsets.all(24),
      glowColor: ValleyBrandColors.violet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Comprovante Valley Docs',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Prova leve da compra, preparada para documento formal e auditoria futura.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 22),
          _ReceiptLine(label: 'Pedido', value: 'VAL-${item.id}'),
          _ReceiptLine(label: 'Produto', value: item.title),
          _ReceiptLine(label: 'Seller', value: item.merchantName),
          _ReceiptLine(
            label: 'Valor',
            value: 'R\$ ${(item.priceBrl + 24.8).toStringAsFixed(2)}',
          ),
          _ReceiptLine(label: 'Metodo', value: 'Plug preparado'),
          _ReceiptLine(label: 'Checksum', value: checksum, highlight: true),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              FilledButton.icon(
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: receiptText)),
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copiar recibo'),
              ),
              OutlinedButton.icon(
                onPressed: () => SharePlus.instance.share(
                  ShareParams(
                    text: receiptText,
                    subject: 'Comprovante Valley VAL-${item.id}',
                  ),
                ),
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('Compartilhar'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: receiptText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text('Recibo preparado para documento.'),
                    ),
                  );
                },
                icon: const Icon(Icons.description_rounded),
                label: const Text('Preparar documento'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReceiptLine extends StatelessWidget {
  const _ReceiptLine({
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: highlight ? ValleyBrandColors.cyan : null,
                fontWeight: highlight ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

typedef _AuthLoginHandler =
    Future<void> Function(String identifier, String password);

typedef _AuthRegisterHandler =
    Future<void> Function(Map<String, String> values);

class _IdentityTrustScreen extends StatelessWidget {
  const _IdentityTrustScreen({
    required this.pendingItem,
    required this.onConfirm,
    required this.authSession,
    required this.authBusy,
    required this.feedback,
    required this.onLogin,
    required this.onRegister,
    required this.onLogout,
  });

  final ProductItem? pendingItem;
  final VoidCallback? onConfirm;
  final ProductAuthSession? authSession;
  final bool authBusy;
  final String feedback;
  final _AuthLoginHandler onLogin;
  final _AuthRegisterHandler onRegister;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _StitchP0MobileRail(
          activeKeys: const <String>{'login'},
          title: authSession == null ? 'Entrada Valley' : 'Sessão ativa',
          subtitle: authSession == null
              ? 'Login e cadastro liberam checkout, compras e rastreio.'
              : '${authSession!.user.displayName} pode continuar a jornada.',
        ),
        const SizedBox(height: 18),
        ValleyPanel(
          radius: 32,
          padding: const EdgeInsets.all(24),
          glowColor: ValleyBrandColors.cyan,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                authSession == null
                    ? 'Entrar ou criar conta'
                    : 'Conta e confiança',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                authSession == null
                    ? 'O mesmo fluxo serve para web e app. Faça login com email e senha para liberar checkout, área do cliente e trilha operacional.'
                    : 'Sessão ativa com identidade validada. Checkout, recibo e área do cliente passam a operar com vínculo real ao usuário.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              if (authSession == null)
                _AuthAccessPanel(
                  busy: authBusy,
                  feedback: feedback,
                  onLogin: onLogin,
                  onRegister: onRegister,
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    _IdentityMetric(
                      icon: Icons.person_rounded,
                      label: 'Conta',
                      value: authSession!.user.displayName,
                      color: ValleyBrandColors.cyan,
                    ),
                    _IdentityMetric(
                      icon: Icons.badge_rounded,
                      label: 'Perfil',
                      value: authSession!.user.primaryRole,
                      color: ValleyBrandColors.violet,
                    ),
                    _IdentityMetric(
                      icon: Icons.shield_rounded,
                      label: 'Score',
                      value: authSession!.user.isAdmin ? '99' : '92',
                      color: ValleyBrandColors.success,
                    ),
                  ],
                ),
              if (authSession != null) ...<Widget>[
                const SizedBox(height: 16),
                Text(
                  '${authSession!.user.email} • sessão ativa até ${authSession!.expiresAt.replaceFirst("T", " ").replaceFirst("Z", " UTC")}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: authBusy ? null : onLogout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Encerrar sessão'),
                ),
              ],
              if (pendingItem != null) ...<Widget>[
                const SizedBox(height: 20),
                Text(
                  authSession == null
                      ? 'Entre para continuar o checkout'
                      : 'Operação sensível',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  pendingItem!.titlePtBr,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: authSession == null ? null : onConfirm,
                  icon: const Icon(Icons.lock_open_rounded),
                  label: Text(
                    authSession == null
                        ? 'Liberado após login'
                        : 'Continuar checkout',
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AuthAccessPanel extends StatefulWidget {
  const _AuthAccessPanel({
    required this.busy,
    required this.feedback,
    required this.onLogin,
    required this.onRegister,
  });

  final bool busy;
  final String feedback;
  final _AuthLoginHandler onLogin;
  final _AuthRegisterHandler onRegister;

  @override
  State<_AuthAccessPanel> createState() => _AuthAccessPanelState();
}

class _AuthAccessPanelState extends State<_AuthAccessPanel> {
  late final TextEditingController _loginIdentifierController;
  late final TextEditingController _loginPasswordController;
  late final TextEditingController _registerFullNameController;
  late final TextEditingController _registerDisplayNameController;
  late final TextEditingController _registerEmailController;
  late final TextEditingController _registerPasswordController;
  late final TextEditingController _registerCpfController;
  late final TextEditingController _registerPhoneController;
  late final TextEditingController _registerPostalCodeController;
  late final TextEditingController _registerStreetController;
  late final TextEditingController _registerNumberController;
  late final TextEditingController _registerComplementController;
  late final TextEditingController _registerNeighborhoodController;
  late final TextEditingController _registerCityController;
  late final TextEditingController _registerStateController;
  String _role = 'CUSTOMER';

  @override
  void initState() {
    super.initState();
    _loginIdentifierController = TextEditingController();
    _loginPasswordController = TextEditingController();
    _registerFullNameController = TextEditingController();
    _registerDisplayNameController = TextEditingController();
    _registerEmailController = TextEditingController();
    _registerPasswordController = TextEditingController();
    _registerCpfController = TextEditingController();
    _registerPhoneController = TextEditingController();
    _registerPostalCodeController = TextEditingController();
    _registerStreetController = TextEditingController();
    _registerNumberController = TextEditingController();
    _registerComplementController = TextEditingController();
    _registerNeighborhoodController = TextEditingController();
    _registerCityController = TextEditingController();
    _registerStateController = TextEditingController();
  }

  @override
  void dispose() {
    _loginIdentifierController.dispose();
    _loginPasswordController.dispose();
    _registerFullNameController.dispose();
    _registerDisplayNameController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerCpfController.dispose();
    _registerPhoneController.dispose();
    _registerPostalCodeController.dispose();
    _registerStreetController.dispose();
    _registerNumberController.dispose();
    _registerComplementController.dispose();
    _registerNeighborhoodController.dispose();
    _registerCityController.dispose();
    _registerStateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              color: _softContainerColor(
                context,
                lightAlpha: 0.96,
                darkAlpha: 0.06,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const TabBar(
              tabs: <Widget>[
                Tab(text: 'Entrar'),
                Tab(text: 'Criar conta'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 760,
            child: TabBarView(
              children: <Widget>[
                SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AuthFormCard(
                    title: 'Login Valley',
                    subtitle:
                        'Use seu email e senha para liberar checkout e área do cliente.',
                    busy: widget.busy,
                    feedback: widget.feedback,
                    fields: <Widget>[
                      _AuthTextField(
                        controller: _loginIdentifierController,
                        label: 'Email',
                        hintText: 'voce@empresa.com',
                      ),
                      const SizedBox(height: 12),
                      _AuthTextField(
                        controller: _loginPasswordController,
                        label: 'Senha',
                        hintText: 'Sua senha',
                        obscureText: true,
                      ),
                    ],
                    actionLabel: 'Entrar agora',
                    onSubmit: () => widget.onLogin(
                      _loginIdentifierController.text,
                      _loginPasswordController.text,
                    ),
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AuthFormCard(
                    title: 'Nova conta',
                    subtitle:
                        'Crie uma conta de comprador ou lojista com sessão persistente.',
                    busy: widget.busy,
                    feedback: widget.feedback,
                    fields: <Widget>[
                      _AuthTextField(
                        controller: _registerFullNameController,
                        label: 'Nome completo',
                        hintText: 'Seu nome',
                      ),
                      const SizedBox(height: 12),
                      _AuthTextField(
                        controller: _registerDisplayNameController,
                        label: 'Nome público',
                        hintText: 'Como deseja aparecer',
                      ),
                      const SizedBox(height: 12),
                      _AuthTextField(
                        controller: _registerEmailController,
                        label: 'Email',
                        hintText: 'voce@empresa.com',
                      ),
                      const SizedBox(height: 12),
                      _AuthTextField(
                        controller: _registerPasswordController,
                        label: 'Senha',
                        hintText: 'Ao menos 8 caracteres',
                        obscureText: true,
                      ),
                      const SizedBox(height: 12),
                      _AuthTextField(
                        controller: _registerCpfController,
                        label: 'CPF',
                        hintText: '000.000.000-00',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      _AuthTextField(
                        controller: _registerPhoneController,
                        label: 'Telefone',
                        hintText: '(00) 00000-0000',
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      _AuthTextField(
                        controller: _registerPostalCodeController,
                        label: 'CEP',
                        hintText: '00000-000',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      _AuthTextField(
                        controller: _registerStreetController,
                        label: 'Endereço',
                        hintText: 'Rua, avenida ou estrada',
                      ),
                      const SizedBox(height: 12),
                      _AuthTextField(
                        controller: _registerNumberController,
                        label: 'Número',
                        hintText: 'Número',
                      ),
                      const SizedBox(height: 12),
                      _AuthTextField(
                        controller: _registerComplementController,
                        label: 'Complemento',
                        hintText: 'Apartamento, bloco ou referência',
                      ),
                      const SizedBox(height: 12),
                      _AuthTextField(
                        controller: _registerNeighborhoodController,
                        label: 'Bairro',
                        hintText: 'Bairro',
                      ),
                      const SizedBox(height: 12),
                      _AuthTextField(
                        controller: _registerCityController,
                        label: 'Cidade',
                        hintText: 'Cidade',
                      ),
                      const SizedBox(height: 12),
                      _AuthTextField(
                        controller: _registerStateController,
                        label: 'UF',
                        hintText: 'SP',
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _role,
                        decoration: const InputDecoration(labelText: 'Perfil'),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(
                            value: 'CUSTOMER',
                            child: Text('Comprador'),
                          ),
                          DropdownMenuItem(
                            value: 'MERCHANT',
                            child: Text('Lojista'),
                          ),
                        ],
                        onChanged: widget.busy
                            ? null
                            : (String? value) {
                                setState(() {
                                  _role = value ?? 'CUSTOMER';
                                });
                              },
                      ),
                    ],
                    actionLabel: 'Criar conta',
                    onSubmit: () => widget.onRegister(<String, String>{
                      'full_name': _registerFullNameController.text,
                      'display_name': _registerDisplayNameController.text,
                      'email': _registerEmailController.text,
                      'password': _registerPasswordController.text,
                      'role': _role,
                      'cpf': _registerCpfController.text,
                      'phone': _registerPhoneController.text,
                      'postal_code': _registerPostalCodeController.text,
                      'street': _registerStreetController.text,
                      'number': _registerNumberController.text,
                      'complement': _registerComplementController.text,
                      'neighborhood': _registerNeighborhoodController.text,
                      'city': _registerCityController.text,
                      'state': _registerStateController.text,
                    }),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Somente módulos ativos aparecem no APK. O restante continua fora da navegação até o lançamento real.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthFormCard extends StatelessWidget {
  const _AuthFormCard({
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.feedback,
    required this.fields,
    required this.actionLabel,
    required this.onSubmit,
  });

  final String title;
  final String subtitle;
  final bool busy;
  final String feedback;
  final List<Widget> fields;
  final String actionLabel;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return ValleyPanel(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          ...fields,
          if (feedback.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              feedback,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : () => onSubmit(),
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_open_rounded),
              label: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthTextField extends StatelessWidget {
  const _AuthTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    this.obscureText = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final bool obscureText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label, hintText: hintText),
    );
  }
}

class _IdentityMetric extends StatelessWidget {
  const _IdentityMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationsScreen extends StatelessWidget {
  const _NotificationsScreen({
    required this.baseUrl,
    required this.repository,
    required this.items,
    required this.onOpenItem,
    required this.onOpenStock,
    required this.onOpenChat,
    required this.onOpenIdentity,
  });

  final String baseUrl;
  final ProductApiRepository repository;
  final List<ProductItem> items;
  final ValueChanged<ProductItem> onOpenItem;
  final VoidCallback onOpenStock;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenIdentity;

  @override
  Widget build(BuildContext context) {
    final ProductItem? firstItem = items.isEmpty ? null : items.first;
    final List<_NotificationEntry> fallbackEntries = <_NotificationEntry>[
      if (firstItem != null)
        _NotificationEntry(
          icon: Icons.local_offer_rounded,
          title: 'Oferta pronta para checkout',
          body: firstItem.title,
          actionLabel: 'Abrir produto',
          onTap: () => onOpenItem(firstItem),
        ),
      _NotificationEntry(
        icon: Icons.inventory_2_rounded,
        title: 'Margem precisa de revisão',
        body: 'Revise itens pausados antes de publicar no Marketplace.',
        actionLabel: 'Abrir Stock',
        onTap: onOpenStock,
      ),
      _NotificationEntry(
        icon: Icons.verified_user_rounded,
        title: 'Identidade em ordem',
        body: 'Face ID ativo e score suficiente para operações sensíveis.',
        actionLabel: 'Ver identidade',
        onTap: onOpenIdentity,
      ),
      _NotificationEntry(
        icon: Icons.chat_bubble_rounded,
        title: 'Suporte contextual',
        body: 'Uma conversa pode ser aberta com produto ou pedido anexado.',
        actionLabel: 'Abrir chat',
        onTap: onOpenChat,
      ),
    ];

    return ValleyPanel(
      radius: 30,
      padding: const EdgeInsets.all(22),
      glowColor: ValleyBrandColors.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Notificações',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: repository.loadNotifications(baseUrl: baseUrl),
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
                ) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LinearProgressIndicator(minHeight: 3);
                  }
                  final List<_NotificationEntry> entries = <_NotificationEntry>[
                    for (final Map<String, dynamic> notification
                        in snapshot.data ?? const <Map<String, dynamic>>[])
                      _NotificationEntry(
                        icon: Icons.local_shipping_rounded,
                        title:
                            notification['title']?.toString() ??
                            'Atualização da entrega',
                        body:
                            notification['body']?.toString() ??
                            'Sua encomenda teve uma nova atualização.',
                        actionLabel: 'Ver compra',
                        onTap: onOpenIdentity,
                      ),
                    ...fallbackEntries,
                  ];
                  return Column(
                    children: <Widget>[
                      for (final _NotificationEntry entry in entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: entry.onTap,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Icon(
                                    entry.icon,
                                    color: ValleyBrandColors.cyan,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          entry.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          entry.body,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: entry.onTap,
                                    child: Text(entry.actionLabel),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
          ),
        ],
      ),
    );
  }
}

class _NotificationEntry {
  const _NotificationEntry({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onTap;
}

class _EmptyStatePanel extends StatelessWidget {
  const _EmptyStatePanel({
    required this.icon,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
  });

  final IconData icon;
  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return ValleyPanel(
      radius: 30,
      padding: const EdgeInsets.all(28),
      glowColor: ValleyBrandColors.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: ValleyBrandColors.cyan, size: 34),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: onPrimary, child: Text(primaryLabel)),
        ],
      ),
    );
  }
}

class _PreparedModuleScreen extends StatelessWidget {
  const _PreparedModuleScreen({
    required this.moduleId,
    required this.onNotify,
    required this.onHome,
  });

  final String moduleId;
  final VoidCallback onNotify;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final String label = moduleId.isEmpty ? 'Modulo' : moduleId;
    return ValleyPanel(
      radius: 30,
      padding: const EdgeInsets.all(28),
      glowColor: ValleyBrandColors.violet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: ValleyBrandColors.violet.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: ValleyBrandColors.violet.withValues(alpha: 0.28),
              ),
            ),
            child: const Icon(
              Icons.pending_rounded,
              color: ValleyBrandColors.lilac,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '$label fora da vitrine ativa',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text(
            'Sua vitrine atual está concentrada em Marketplace, Stock, Chat, identidade, checkout e comprovante.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              FilledButton(
                onPressed: onNotify,
                child: const Text('Receber aviso'),
              ),
              OutlinedButton(
                onPressed: onHome,
                child: const Text('Voltar ao inicio'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeedScreen extends StatelessWidget {
  const _FeedScreen({required this.entries, required this.onOpenItem});

  final List<Map<String, dynamic>> entries;
  final ValueChanged<String> onOpenItem;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Feed ativo',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
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
                      CircleAvatar(
                        backgroundImage: NetworkImage(
                          entry['author_avatar'].toString(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(entry['author_name'].toString()),
                            Text(
                              entry['time_label'].toString(),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Text(entry['module_id'].toString()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    entry['headline'].toString(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
                        onPressed: () =>
                            onOpenItem(entry['item_id'].toString()),
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
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
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
                    CircleAvatar(
                      backgroundImage: NetworkImage(
                        conversation['avatar_url'].toString(),
                      ),
                    ),
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
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    if ((conversation['unread_count'] as num?)?.toInt()
                        case final int count when count > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
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
    final List<dynamic> messages =
        conversation['messages'] as List<dynamic>? ?? const <dynamic>[];
    return ValleyPanel(
      radius: 28,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            conversation['title'].toString(),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
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
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
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
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
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
    final List<dynamic> statCards =
        moduleScreen?['stat_cards'] as List<dynamic>? ?? const <dynamic>[];
    final List<Map<String, dynamic>> quickActions =
        (moduleScreen?['quick_actions'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<dynamic, dynamic>>()
            .map(
              (Map<dynamic, dynamic> action) => action.cast<String, dynamic>(),
            )
            .toList();
    final List<String> highlights =
        (moduleScreen?['highlights'] as List<dynamic>? ?? const <dynamic>[])
            .map((dynamic item) => item.toString())
            .where((String item) => item.trim().isNotEmpty)
            .toList();
    final List<String> dependsOn =
        (moduleScreen?['depends_on'] as List<dynamic>? ?? const <dynamic>[])
            .map((dynamic item) => item.toString())
            .where((String item) => item.trim().isNotEmpty)
            .toList();
    final List<String> integratesWith =
        (moduleScreen?['integrates_with'] as List<dynamic>? ??
                const <dynamic>[])
            .map((dynamic item) => item.toString())
            .where((String item) => item.trim().isNotEmpty)
            .toList();
    final String accentLabel =
        moduleScreen?['accent_label']?.toString() ?? 'Experiencia ativa';
    final String description =
        moduleScreen?['description']?.toString() ?? module?.subtitle ?? '';
    final String helenaHint =
        moduleScreen?['helena_hint']?.toString() ??
        'Use os atalhos da tela para navegar, abrir contexto e revisar os dados do modulo.';
    final String operatorNote =
        moduleScreen?['operator_note']?.toString() ?? '';
    final String dataHomeLabel = _prettyDataHomeLabel(
      moduleScreen?['data_home']?.toString() ?? '',
    );
    final String tierLabel = _prettyTierLabel(
      moduleScreen?['tier']?.toString() ?? '',
    );
    final String domainLabel = _prettyDomainLabel(
      moduleScreen?['domain']?.toString() ?? '',
    );

    void runQuickAction(String target) {
      switch (target) {
        case 'detail':
          if (spotlightItems.isNotEmpty) {
            onOpenItem(spotlightItems.first);
          } else {
            onOpenFeed();
          }
          return;
        case 'chat':
          onOpenChat();
          return;
        case 'statement':
          onOpenStatement();
          return;
        case 'feed':
        default:
          onOpenFeed();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ValleyPanel(
          radius: 30,
          padding: const EdgeInsets.all(24),
          glowColor: ValleyBrandColors.cyan,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: ValleyBrandColors.cyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  accentLabel,
                  style: const TextStyle(
                    color: ValleyBrandColors.cyan,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                moduleScreen?['hero_title']?.toString() ??
                    module?.label ??
                    'Modulo',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                moduleScreen?['hero_subtitle']?.toString() ??
                    module?.subtitle ??
                    '',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: quickActions.take(2).map((
                  Map<String, dynamic> action,
                ) {
                  final String label = action['label']?.toString() ?? 'Abrir';
                  final String target = action['target']?.toString() ?? 'feed';
                  final Icon icon = Icon(_quickActionIconFor(target));
                  if (quickActions.indexOf(action) == 0) {
                    return FilledButton.icon(
                      onPressed: () => runQuickAction(target),
                      icon: icon,
                      label: Text(label),
                    );
                  }
                  return OutlinedButton.icon(
                    onPressed: () => runQuickAction(target),
                    icon: icon,
                    label: Text(label),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  if (tierLabel.isNotEmpty)
                    _MetaPill(icon: Icons.layers_rounded, label: tierLabel),
                  if (dataHomeLabel.isNotEmpty)
                    _MetaPill(
                      icon: Icons.storage_rounded,
                      label: dataHomeLabel,
                    ),
                  if (domainLabel.isNotEmpty)
                    _MetaPill(icon: Icons.hub_rounded, label: domainLabel),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (quickActions.isNotEmpty)
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: quickActions
                .take(4)
                .map(
                  (Map<String, dynamic> action) => _ActionCard(
                    icon: _quickActionIconFor(
                      action['target']?.toString() ?? 'feed',
                    ),
                    label: action['label']?.toString() ?? 'Abrir',
                    onTap: () =>
                        runQuickAction(action['target']?.toString() ?? 'feed'),
                  ),
                )
                .toList(),
          ),
        if (quickActions.isNotEmpty) const SizedBox(height: 18),
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
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double availableWidth = constraints.maxWidth;
            final bool wideLayout = availableWidth >= 1080;
            final double leftWidth = wideLayout
                ? (availableWidth - 16) * 0.58
                : availableWidth;
            final double rightWidth = wideLayout
                ? (availableWidth - 16) * 0.42
                : availableWidth;

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: <Widget>[
                SizedBox(
                  width: leftWidth,
                  child: ValleyPanel(
                    radius: 26,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Panorama do modulo',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (operatorNote.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 14),
                          Text(
                            operatorNote,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (highlights.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 18),
                          for (final String highlight in highlights)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _FieldChip(
                                icon: Icons.auto_awesome_rounded,
                                label: highlight,
                              ),
                            ),
                        ],
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: <Widget>[
                            ...dependsOn
                                .take(3)
                                .map(
                                  (String dependency) => _MetaPill(
                                    icon: Icons.account_tree_rounded,
                                    label: 'Depende de $dependency',
                                  ),
                                ),
                            ...integratesWith
                                .take(3)
                                .map(
                                  (String integration) => _MetaPill(
                                    icon: Icons.sync_alt_rounded,
                                    label: 'Integra $integration',
                                  ),
                                ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: ValleyBrandColors.lilac.withValues(
                              alpha: 0.08,
                            ),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: ValleyBrandColors.lilac.withValues(
                                alpha: 0.18,
                              ),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.psychology_alt_rounded,
                                  color: ValleyBrandColors.lilac,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  helenaHint,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: rightWidth,
                  child: ValleyPanel(
                    radius: 26,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Entradas em foco',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (spotlightItems.isEmpty)
                          Text(
                            'Sem itens em destaque agora.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        for (final ProductItem item in spotlightItems)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(22),
                              onTap: () => onOpenItem(item),
                              child: Row(
                                children: <Widget>[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.network(
                                      item.imageUrl,
                                      width: 84,
                                      height: 84,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (
                                            BuildContext context,
                                            Object error,
                                            StackTrace? stackTrace,
                                          ) {
                                            return const ColoredBox(
                                              color: Color(0xFF121A2F),
                                              child: SizedBox(
                                                width: 84,
                                                height: 84,
                                              ),
                                            );
                                          },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          item.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          item.description,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: <Widget>[
                            _MiniStat(
                              label: 'Itens',
                              value: '${spotlightItems.length}',
                            ),
                            _MiniStat(
                              label: 'Base',
                              value: _shortDataHomeLabel(
                                moduleScreen?['data_home']?.toString() ?? '',
                              ),
                            ),
                            _MiniStat(
                              label: 'Links',
                              value: '${integratesWith.length}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ModuleExperienceSpec {
  const _ModuleExperienceSpec({
    required this.badge,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.secondaryLabel,
    required this.secondaryIcon,
    required this.tertiaryLabel,
    required this.tertiaryIcon,
    required this.insightTitle,
    required this.insightBody,
  });

  final String badge;
  final String primaryLabel;
  final IconData primaryIcon;
  final String secondaryLabel;
  final IconData secondaryIcon;
  final String tertiaryLabel;
  final IconData tertiaryIcon;
  final String insightTitle;
  final String insightBody;
}

class _ConfiguredExperienceModuleScreen extends StatelessWidget {
  const _ConfiguredExperienceModuleScreen({
    required this.module,
    required this.moduleScreen,
    required this.items,
    required this.spec,
    required this.onOpenItem,
    required this.onPrimaryAction,
    required this.onSecondaryAction,
    required this.onTertiaryAction,
  });

  final ProductModule? module;
  final Map<String, dynamic>? moduleScreen;
  final List<ProductItem> items;
  final _ModuleExperienceSpec spec;
  final ValueChanged<ProductItem> onOpenItem;
  final VoidCallback onPrimaryAction;
  final VoidCallback onSecondaryAction;
  final VoidCallback onTertiaryAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ProductItem? hero = items.isNotEmpty ? items.first : null;
    final List<ProductItem> spotlightItems = items.take(3).toList();
    final List<dynamic> statCards =
        moduleScreen?['stat_cards'] as List<dynamic>? ?? const <dynamic>[];
    final Set<String> chips = <String>{};
    for (final ProductItem item in spotlightItems) {
      if (item.category.isNotEmpty) {
        chips.add(item.category);
      }
      if (item.brand.isNotEmpty) {
        chips.add(item.brand);
      }
      for (final String tag in item.tags.take(2)) {
        if (tag.isNotEmpty) {
          chips.add(tag);
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ValleyPanel(
          radius: 30,
          padding: EdgeInsets.zero,
          glowColor: ValleyBrandColors.cyan,
          child: Stack(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: AspectRatio(
                  aspectRatio: 16 / 7,
                  child: hero == null
                      ? const ColoredBox(color: Color(0xFF121A2F))
                      : Image.network(
                          hero.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (
                                BuildContext context,
                                Object error,
                                StackTrace? stackTrace,
                              ) {
                                return const ColoredBox(
                                  color: Color(0xFF121A2F),
                                );
                              },
                        ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: const LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: <Color>[Color(0xEE0B1020), Color(0x330B1020)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: ValleyBrandColors.cyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        spec.badge,
                        style: const TextStyle(
                          color: ValleyBrandColors.cyan,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      moduleScreen?['hero_title']?.toString() ??
                          module?.label ??
                          'Módulo Valley',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      moduleScreen?['hero_subtitle']?.toString() ??
                          module?.subtitle ??
                          '',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: <Widget>[
                        FilledButton.icon(
                          onPressed: onPrimaryAction,
                          icon: Icon(spec.primaryIcon),
                          label: Text(spec.primaryLabel),
                        ),
                        OutlinedButton.icon(
                          onPressed: onSecondaryAction,
                          icon: Icon(spec.secondaryIcon),
                          label: Text(spec.secondaryLabel),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: <Widget>[
            _ActionCard(
              icon: spec.primaryIcon,
              label: spec.primaryLabel,
              onTap: onPrimaryAction,
            ),
            _ActionCard(
              icon: spec.secondaryIcon,
              label: spec.secondaryLabel,
              onTap: onSecondaryAction,
            ),
            _ActionCard(
              icon: spec.tertiaryIcon,
              label: spec.tertiaryLabel,
              onTap: onTertiaryAction,
            ),
          ],
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
                    width: 180,
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
        const SizedBox(height: 18),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: <Widget>[
            SizedBox(
              width: 420,
              child: ValleyPanel(
                radius: 24,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      spec.insightTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      spec.insightBody,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...spotlightItems.map(
                      (ProductItem item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => onOpenItem(item),
                          child: Row(
                            children: <Widget>[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(
                                  item.imageUrl,
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (
                                        BuildContext context,
                                        Object error,
                                        StackTrace? stackTrace,
                                      ) {
                                        return const ColoredBox(
                                          color: Color(0xFF121A2F),
                                          child: SizedBox(
                                            width: 64,
                                            height: 64,
                                          ),
                                        );
                                      },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      item.title,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: ValleyBrandColors.cyan,
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
            SizedBox(
              width: 320,
              child: ValleyPanel(
                radius: 24,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Contexto ativo',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...chips
                        .take(6)
                        .map(
                          (String chip) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _FieldChip(
                              icon: Icons.auto_awesome_rounded,
                              label: chip,
                            ),
                          ),
                        ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: <Widget>[
                        _MiniStat(label: 'Itens', value: '${items.length}'),
                        _MiniStat(label: 'Hero', value: hero?.brand ?? '--'),
                        _MiniStat(label: 'Fluxo', value: module?.id ?? '--'),
                      ],
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

class _MobilityModuleScreen extends StatelessWidget {
  const _MobilityModuleScreen({required this.items, required this.onOpenItem});

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
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
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
                            Expanded(
                              child: Text('Rota premium • 7 min de chegada'),
                            ),
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
                  const Icon(
                    Icons.directions_car_filled_rounded,
                    color: ValleyBrandColors.cyan,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${ride.brand} • ETA ${2 + (ride.stock % 6)} min',
                    ),
                  ),
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
  const _FoodModuleScreen({required this.items, required this.onOpenItem});

  final List<ProductItem> items;
  final ValueChanged<ProductItem> onOpenItem;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Food',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
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
                            child: Image.network(
                              item.imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
    final List<ProductItem> secondary = showcase.length > 1
        ? showcase.sublist(1)
        : const <ProductItem>[];

    if (featured == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Marketplace',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
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
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      featured.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (
                            BuildContext context,
                            Object error,
                            StackTrace? stackTrace,
                          ) {
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
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
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
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
    required this.onOpenChat,
  });

  final List<ProductItem> items;
  final ValueChanged<ProductItem> onOpenItem;
  final VoidCallback onOpenChat;

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
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                ),
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
                onPressed: items.isEmpty
                    ? onOpenChat
                    : () => onOpenItem(items.first),
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
                child: _FieldChip(
                  icon: Icons.location_on_outlined,
                  label: 'Localização do serviço',
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: _FieldChip(
                  icon: Icons.event_outlined,
                  label: 'Data e horário',
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: items.isEmpty
                    ? onOpenChat
                    : () => onOpenItem(items.first),
                child: const Text('Agendar agora'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Categorias',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
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
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
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
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
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
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
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
    required this.onOpenStatement,
  });

  final List<ProductItem> items;
  final ValueChanged<ProductItem> onOpenItem;
  final VoidCallback onOpenStatement;

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
                child: const Icon(
                  Icons.local_shipping_rounded,
                  color: ValleyBrandColors.cyan,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Refinamento Operacional',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
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
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(24),
                                  ),
                                  child: Image.network(
                                    item.imageUrl,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.55,
                                      ),
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
                                Text(
                                  item.title,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
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
                                      'ETA ${8 + (item.stock % 15)}:${(item.stock % 6) * 10}'
                                          .padLeft(2, '0'),
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
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: tableRows.isEmpty
                        ? onOpenStatement
                        : () => onOpenItem(tableRows.first),
                    child: const Text('Ver relatório completo'),
                  ),
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
    required this.onOpenStatement,
    required this.onOpenItem,
  });

  final List<ProductItem> items;
  final List<Map<String, dynamic>> entries;
  final VoidCallback onOpenStatement;
  final ValueChanged<ProductItem> onOpenItem;

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
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
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
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '+2.4% este mês',
                style: TextStyle(
                  color: ValleyBrandColors.cyan,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: <Widget>[
            Expanded(
              child: _ActionCard(
                icon: Icons.qr_code_2_rounded,
                label: 'Pix',
                onTap: onOpenStatement,
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: _ActionCard(
                icon: Icons.send_to_mobile_rounded,
                label: 'Transferir',
                onTap: onOpenStatement,
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: _ActionCard(
                icon: Icons.receipt_long_rounded,
                label: 'Pagar',
                onTap: items.isEmpty
                    ? onOpenStatement
                    : () => onOpenItem(items.first),
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: _ActionCard(
                icon: Icons.request_quote_rounded,
                label: 'Receber',
                onTap: onOpenStatement,
              ),
            ),
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
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
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
                        child: const Icon(
                          Icons.payments_rounded,
                          color: ValleyBrandColors.cyan,
                        ),
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
    required this.onOpenItem,
  });

  final List<ProductItem> items;
  final List<Map<String, dynamic>> entries;
  final ValueChanged<ProductItem> onOpenItem;

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
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
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
                          final double height = <double>[
                            0.60,
                            0.45,
                            0.80,
                            0.95,
                            0.55,
                            0.70,
                            0.40,
                            0.65,
                          ][index];
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: FractionallySizedBox(
                                heightFactor: height,
                                alignment: Alignment.bottomCenter,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: index == 3
                                        ? ValleyBrandColors.cyan
                                        : ValleyBrandColors.cyan.withValues(
                                            alpha: 0.28,
                                          ),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(8),
                                    ),
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
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
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
                        onPressed: items.isEmpty
                            ? null
                            : () => onOpenItem(items.first),
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
  const _PolicyModuleScreen({required this.items, required this.onOpenItem});

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
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
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
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                            child: AspectRatio(
                              aspectRatio: 16 / 10,
                              child: Image.network(
                                item.imageUrl,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  item.title,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
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
  const _GamingModuleScreen({required this.items, required this.onOpenItem});

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
                    errorBuilder:
                        (
                          BuildContext context,
                          Object error,
                          StackTrace? stackTrace,
                        ) {
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
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
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
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
                      onPressed: rewards.isNotEmpty
                          ? () => onOpenItem(rewards.first)
                          : null,
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
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final ProductItem reward in rewards)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: <Widget>[
                            const Icon(
                              Icons.diamond_rounded,
                              color: ValleyBrandColors.cyan,
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(reward.title)),
                            Text(
                              '${reward.stock} pts',
                              style: const TextStyle(
                                color: ValleyBrandColors.cyan,
                              ),
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
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 12),
                    _RankingRow(
                      position: '1',
                      name: 'A_Ghost_X',
                      value: '04:12s',
                    ),
                    _RankingRow(
                      position: '2',
                      name: 'NovaStream',
                      value: '04:28s',
                    ),
                    _RankingRow(
                      position: '12',
                      name: 'Você',
                      value: '--:--',
                      highlight: true,
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

IconData _quickActionIconFor(String target) {
  switch (target) {
    case 'detail':
      return Icons.dashboard_customize_rounded;
    case 'chat':
      return Icons.chat_bubble_rounded;
    case 'statement':
      return Icons.receipt_long_rounded;
    case 'feed':
    default:
      return Icons.dynamic_feed_rounded;
  }
}

String _prettyDomainLabel(String value) {
  if (value.trim().isEmpty) {
    return '';
  }
  return value
      .split('_')
      .where((String item) => item.isNotEmpty)
      .map(
        (String item) =>
            '${item.substring(0, 1).toUpperCase()}${item.substring(1).toLowerCase()}',
      )
      .join(' ');
}

String _prettyDataHomeLabel(String value) {
  switch (value) {
    case 'postgres':
      return 'Postgres relacional';
    case 'postgres_mongo':
      return 'Postgres + Mongo';
    case 'mongo':
      return 'Mongo documental';
    default:
      return value;
  }
}

String _shortDataHomeLabel(String value) {
  switch (value) {
    case 'postgres':
      return 'PG';
    case 'postgres_mongo':
      return 'Hibrido';
    case 'mongo':
      return 'Mongo';
    default:
      return '--';
  }
}

String _prettyTierLabel(String value) {
  switch (value) {
    case 'foundation':
      return 'Foundation';
    case 'core':
      return 'Core';
    case 'expansion':
      return 'Expansion';
    case 'frontier':
      return 'Frontier';
    default:
      return value;
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: ValleyPanel(
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

void _openGalleryLightbox(
  BuildContext context, {
  required List<String> imageUrls,
  required int initialIndex,
}) {
  if (imageUrls.isEmpty) {
    return;
  }
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.88),
    builder: (BuildContext dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(18),
        child: _GalleryLightbox(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
        ),
      );
    },
  );
}

class _GalleryLightbox extends StatefulWidget {
  const _GalleryLightbox({required this.imageUrls, required this.initialIndex});

  final List<String> imageUrls;
  final int initialIndex;

  @override
  State<_GalleryLightbox> createState() => _GalleryLightboxState();
}

class _GalleryLightboxState extends State<_GalleryLightbox> {
  late final PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
    _controller = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: Container(
        color: const Color(0xFF07111D),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Imagem ${_currentIndex + 1}/${widget.imageUrls.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.imageUrls.length,
                onPageChanged: (int index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemBuilder: (BuildContext context, int index) {
                  return InteractiveViewer(
                    minScale: 1,
                    maxScale: 4.5,
                    child: Center(
                      child: Image.network(
                        widget.imageUrls[index],
                        fit: BoxFit.contain,
                        errorBuilder:
                            (
                              BuildContext context,
                              Object error,
                              StackTrace? stackTrace,
                            ) {
                              return const SizedBox.shrink();
                            },
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Arraste para navegar e use gesto de pinça para ampliar.',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductGalleryCarousel extends StatefulWidget {
  const _ProductGalleryCarousel({
    required this.imageUrls,
    this.fit = BoxFit.cover,
    this.emptyColor = const Color(0xFF121A2F),
    this.compact = false,
    this.imagePadding = EdgeInsets.zero,
  });

  final List<String> imageUrls;
  final BoxFit fit;
  final Color emptyColor;
  final bool compact;
  final EdgeInsets imagePadding;

  @override
  State<_ProductGalleryCarousel> createState() =>
      _ProductGalleryCarouselState();
}

class _ProductGalleryCarouselState extends State<_ProductGalleryCarousel> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> images = widget.imageUrls;
    if (images.isEmpty) {
      return ColoredBox(color: widget.emptyColor);
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        PageView.builder(
          controller: _pageController,
          itemCount: images.length,
          onPageChanged: (int index) {
            if (!mounted) {
              return;
            }
            setState(() {
              _currentIndex = index;
            });
          },
          itemBuilder: (BuildContext context, int index) {
            return GestureDetector(
              onTap: () => _openGalleryLightbox(
                context,
                imageUrls: images,
                initialIndex: index,
              ),
              child: Container(
                color: widget.emptyColor,
                alignment: Alignment.center,
                padding: widget.imagePadding,
                child: Image.network(
                  images[index],
                  fit: widget.fit,
                  errorBuilder:
                      (
                        BuildContext context,
                        Object error,
                        StackTrace? stackTrace,
                      ) {
                        return ColoredBox(color: widget.emptyColor);
                      },
                ),
              ),
            );
          },
        ),
        Positioned(
          left: widget.compact ? 12 : 18,
          bottom: widget.compact ? 12 : 18,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 8 : 10,
              vertical: widget.compact ? 5 : 6,
            ),
            decoration: BoxDecoration(
              color: const Color(0xC20E1323),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Text(
              'Toque para ampliar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: widget.compact ? 9 : 10,
              ),
            ),
          ),
        ),
        if (images.length > 1)
          Positioned(
            right: widget.compact ? 12 : 18,
            top: widget.compact ? 12 : 18,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 8 : 10,
                vertical: widget.compact ? 5 : 6,
              ),
              decoration: BoxDecoration(
                color: const Color(0xC20E1323),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: Text(
                '${_currentIndex + 1}/${images.length}',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: widget.compact ? 10 : 11,
                ),
              ),
            ),
          ),
        if (images.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: widget.compact ? 10 : 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(images.length, (int index) {
                final bool active = index == _currentIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? (widget.compact ? 18 : 22) : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active
                        ? ValleyBrandColors.cyan
                        : Colors.white.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

class _ProductMediaEntry {
  const _ProductMediaEntry._({
    required this.kind,
    required this.previewUrl,
    required this.label,
  });

  const _ProductMediaEntry.image(String url)
    : this._(kind: 'image', previewUrl: url, label: 'Imagem');

  const _ProductMediaEntry.video({required String previewUrl})
    : this._(kind: 'video', previewUrl: previewUrl, label: 'Vídeo');

  final String kind;
  final String previewUrl;
  final String label;

  bool get isVideo => kind == 'video';
}

class _ProductMediaStage extends StatefulWidget {
  const _ProductMediaStage({required this.item, this.onPlay});

  final ProductItem item;
  final VoidCallback? onPlay;

  @override
  State<_ProductMediaStage> createState() => _ProductMediaStageState();
}

class _ProductMediaStageState extends State<_ProductMediaStage> {
  int _selectedIndex = 0;

  List<_ProductMediaEntry> get _entries {
    final List<_ProductMediaEntry> entries = <_ProductMediaEntry>[];
    if (widget.item.hasVideo) {
      entries.add(
        _ProductMediaEntry.video(
          previewUrl: widget.item.imageUrl.isNotEmpty
              ? widget.item.imageUrl
              : (widget.item.mediaGallery.isNotEmpty
                    ? widget.item.mediaGallery.first
                    : ''),
        ),
      );
    }
    for (final String imageUrl in widget.item.mediaGallery) {
      if (imageUrl.trim().isEmpty) {
        continue;
      }
      entries.add(_ProductMediaEntry.image(imageUrl));
    }
    if (entries.isEmpty) {
      entries.add(const _ProductMediaEntry.image(''));
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<_ProductMediaEntry> entries = _entries;
    final int safeIndex = _selectedIndex.clamp(0, entries.length - 1);
    final _ProductMediaEntry selected = entries[safeIndex];
    final Color stageColor = _mediaStageColor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Container(
            color: stageColor,
            child: AspectRatio(
              aspectRatio: 5 / 4,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: selected.isVideo
                    ? _buildVideoStage(context, selected)
                    : _buildImageStage(context, selected),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 82,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: entries.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(width: 10),
            itemBuilder: (BuildContext context, int index) {
              final _ProductMediaEntry entry = entries[index];
              final bool active = index == safeIndex;
              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 92,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _softContainerColor(
                      context,
                      lightAlpha: 0.94,
                      darkAlpha: 0.06,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active
                          ? ValleyBrandColors.cyan
                          : _softBorderColor(context, darkAlpha: 0.08),
                    ),
                  ),
                  child: entry.isVideo
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const Icon(
                              Icons.play_circle_fill_rounded,
                              color: ValleyBrandColors.cyan,
                              size: 28,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Vídeo',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            color: stageColor,
                            alignment: Alignment.center,
                            child: entry.previewUrl.isEmpty
                                ? const SizedBox.shrink()
                                : Image.network(
                                    entry.previewUrl,
                                    fit: BoxFit.contain,
                                    errorBuilder:
                                        (
                                          BuildContext context,
                                          Object error,
                                          StackTrace? stackTrace,
                                        ) {
                                          return const SizedBox.shrink();
                                        },
                                  ),
                          ),
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildImageStage(BuildContext context, _ProductMediaEntry entry) {
    final int initialIndex = widget.item.mediaGallery.indexOf(entry.previewUrl);
    return GestureDetector(
      onTap: entry.previewUrl.isEmpty
          ? null
          : () => _openGalleryLightbox(
              context,
              imageUrls: widget.item.mediaGallery,
              initialIndex: initialIndex < 0 ? 0 : initialIndex,
            ),
      child: Container(
        key: ValueKey<String>('image:${entry.previewUrl}'),
        color: _mediaStageColor(context),
        padding: const EdgeInsets.all(28),
        alignment: Alignment.center,
        child: entry.previewUrl.isEmpty
            ? const SizedBox.shrink()
            : Image.network(
                entry.previewUrl,
                fit: BoxFit.contain,
                errorBuilder:
                    (
                      BuildContext context,
                      Object error,
                      StackTrace? stackTrace,
                    ) {
                      return const SizedBox.shrink();
                    },
              ),
      ),
    );
  }

  Widget _buildVideoStage(BuildContext context, _ProductMediaEntry entry) {
    final ThemeData theme = Theme.of(context);
    return Container(
      key: const ValueKey<String>('video-stage'),
      color: _mediaStageColor(context),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (entry.previewUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(28),
              child: Image.network(
                entry.previewUrl,
                fit: BoxFit.contain,
                errorBuilder:
                    (
                      BuildContext context,
                      Object error,
                      StackTrace? stackTrace,
                    ) {
                      return const SizedBox.shrink();
                    },
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.black.withValues(alpha: 0.10),
                  Colors.black.withValues(alpha: 0.68),
                ],
              ),
            ),
          ),
          Positioned(
            top: 18,
            left: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xCC0E1323),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: ValleyBrandColors.cyan.withValues(alpha: 0.35),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.play_circle_fill_rounded,
                    color: ValleyBrandColors.cyan,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Vídeo do produto',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Center(
            child: FilledButton.icon(
              onPressed: widget.onPlay,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                widget.onPlay == null
                    ? 'Vídeo catalogado'
                    : 'Abrir vídeo externo',
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 18,
            child: Text(
              widget.onPlay == null
                  ? 'O catálogo sinalizou vídeo, mas a origem ainda não publicou uma URL direta.'
                  : 'A mídia principal mostra o vídeo do produto quando há uma URL válida.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.86),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _softContainerColor(context, lightAlpha: 0.96, darkAlpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _softBorderColor(context, darkAlpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: ValleyBrandColors.cyan),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
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
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: Colors.white54),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: ValleyBrandColors.cyan,
            fontWeight: FontWeight.w700,
          ),
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
            child: Text(
              position,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(name, style: TextStyle(color: color)),
          ),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
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
        const Icon(
          Icons.place_rounded,
          color: ValleyBrandColors.cyan,
          size: 28,
        ),
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
      ..quadraticBezierTo(
        size.width * 0.34,
        96,
        size.width * 0.44,
        size.height * 0.48,
      )
      ..quadraticBezierTo(
        size.width * 0.64,
        size.height * 0.70,
        size.width - 58,
        size.height - 58,
      );
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
    required this.transcript,
    required this.voiceReady,
    required this.listening,
    required this.onToggle,
    required this.onSpeak,
    required this.onListen,
  });

  final bool minimized;
  final String mood;
  final String message;
  final String transcript;
  final bool voiceReady;
  final bool listening;
  final VoidCallback onToggle;
  final VoidCallback onSpeak;
  final VoidCallback onListen;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color haloColor = switch (mood) {
      'happy' => ValleyBrandColors.success,
      'alert' => ValleyBrandColors.danger,
      'focus' => ValleyBrandColors.cyan,
      _ => ValleyBrandColors.cyan,
    };
    final String statusLabel = listening
        ? 'ouvindo'
        : voiceReady
        ? 'voz pronta'
        : 'sem mic';
    final Color statusColor = listening
        ? ValleyBrandColors.success
        : voiceReady
        ? ValleyBrandColors.cyan
        : theme.colorScheme.onSurfaceVariant;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      width: minimized ? 96 : 372,
      height: minimized ? 96 : 224,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          if (!minimized)
            Positioned(
              left: 0,
              right: 76,
              top: 14,
              bottom: 18,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      const Color(0xF5171043),
                      const Color(0xF70B1020),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: haloColor.withValues(alpha: 0.18)),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: haloColor.withValues(alpha: 0.16),
                      blurRadius: 28,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Text(
                            'Helena',
                            style: TextStyle(
                              color: ValleyBrandColors.cyan,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              statusLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Spacer(),
                          _HelenaControlButton(
                            icon: listening
                                ? Icons.mic_rounded
                                : voiceReady
                                ? Icons.mic_none_rounded
                                : Icons.mic_off_rounded,
                            color: statusColor,
                            onPressed: onListen,
                          ),
                          const SizedBox(width: 8),
                          _HelenaControlButton(
                            icon: Icons.graphic_eq_rounded,
                            color: ValleyBrandColors.cyan,
                            onPressed: onSpeak,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Text(
                          transcript,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: listening
                                ? ValleyBrandColors.cyan
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Fico discreta e so anuncio navegacao quando voce pedir direto.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            right: 0,
            bottom: minimized ? 0 : 10,
            child: GestureDetector(
              onTap: onToggle,
              onDoubleTap: onSpeak,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      const Color(0xFF1A2344),
                      const Color(0xFF0A1021),
                    ],
                  ),
                  border: Border.all(
                    color: haloColor.withValues(alpha: listening ? 0.9 : 0.55),
                    width: listening ? 2.8 : 2.2,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: haloColor.withValues(
                        alpha: listening ? 0.35 : 0.22,
                      ),
                      blurRadius: listening ? 28 : 20,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Center(
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              Colors.white.withValues(alpha: 0.10),
                              haloColor.withValues(alpha: 0.08),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: const Center(child: _HelenaStarBadge(size: 34)),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: listening
                              ? ValleyBrandColors.success
                              : voiceReady
                              ? ValleyBrandColors.cyan
                              : theme.colorScheme.onSurfaceVariant,
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color:
                                  (listening
                                          ? ValleyBrandColors.success
                                          : ValleyBrandColors.cyan)
                                      .withValues(alpha: 0.35),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -2,
                      left: -2,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10182C),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Icon(
                          listening
                              ? Icons.mic_rounded
                              : voiceReady
                              ? Icons.open_with_rounded
                              : Icons.mic_off_rounded,
                          size: 15,
                          color: listening
                              ? ValleyBrandColors.success
                              : ValleyBrandColors.cyan,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelenaControlButton extends StatelessWidget {
  const _HelenaControlButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
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
      Rect.fromCenter(
        center: center,
        width: size.width * 0.16,
        height: size.height * 0.72,
      ),
      star,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: center,
        width: size.width * 0.72,
        height: size.height * 0.16,
      ),
      star,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ClientAreaScreen extends StatefulWidget {
  const _ClientAreaScreen({
    required this.baseUrl,
    required this.repository,
    required this.items,
    required this.onOpenItem,
    required this.onOpenChat,
  });

  final String baseUrl;
  final ProductApiRepository repository;
  final List<ProductItem> items;
  final ValueChanged<ProductItem> onOpenItem;
  final VoidCallback onOpenChat;

  @override
  State<_ClientAreaScreen> createState() => _ClientAreaScreenState();
}

class _ClientAreaScreenState extends State<_ClientAreaScreen> {
  late Future<List<ProductPurchase>> _purchasesFuture;

  @override
  void initState() {
    super.initState();
    _purchasesFuture = widget.repository.loadPurchases(baseUrl: widget.baseUrl);
  }

  void _refreshPurchases() {
    setState(() {
      _purchasesFuture = widget.repository.loadPurchases(
        baseUrl: widget.baseUrl,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<ProductItem> recentOrders = widget.items.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ValleyPanel(
          radius: 32,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: const LinearGradient(
                        colors: <Color>[
                          ValleyBrandColors.cyan,
                          Color(0xFF6D5DF6),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.black,
                      size: 34,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Área do Cliente',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Perfil, pedidos, validação de CNPJ e rastreio multimodal em uma única tela.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.66),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: const <Widget>[
                  _MetaPill(
                    icon: Icons.verified_user_rounded,
                    label: 'KYC validado',
                  ),
                  _MetaPill(
                    icon: Icons.business_rounded,
                    label: 'CNPJ em análise',
                  ),
                  _MetaPill(icon: Icons.stars_rounded, label: '1.840 V-Coin'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const _StitchP0MobileRail(
          activeKeys: <String>{'purchases', 'tracking'},
          title: 'Compras e rastreio',
          subtitle:
              'Pedidos confirmados, status de entrega e suporte no mesmo fluxo.',
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool wide = constraints.maxWidth > 760;
            final Widget ordersPanel = ValleyPanel(
              radius: 28,
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Minhas compras',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _refreshPurchases,
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: 'Atualizar compras',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  FutureBuilder<List<ProductPurchase>>(
                    future: _purchasesFuture,
                    builder:
                        (
                          BuildContext context,
                          AsyncSnapshot<List<ProductPurchase>> snapshot,
                        ) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const LinearProgressIndicator(minHeight: 3);
                          }
                          final List<ProductPurchase> purchases =
                              snapshot.data ?? const <ProductPurchase>[];
                          if (purchases.isEmpty) {
                            return Text(
                              'As compras confirmadas aparecerão aqui automaticamente com rastreio da entrega.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.62),
                              ),
                            );
                          }
                          return Column(
                            children: <Widget>[
                              for (final ProductPurchase purchase in purchases)
                                _PurchaseTrackingTile(purchase: purchase),
                            ],
                          );
                        },
                  ),
                  if (recentOrders.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 18),
                    Text(
                      'Ofertas recentes',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final ProductItem item in recentOrders)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            item.imageUrl,
                            width: 54,
                            height: 54,
                            fit: BoxFit.cover,
                          ),
                        ),
                        title: Text(
                          item.titlePtBr,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          'Abrir detalhes da oferta',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                        trailing: TextButton(
                          onPressed: () => widget.onOpenItem(item),
                          child: const Text('Detalhes'),
                        ),
                      ),
                  ],
                ],
              ),
            );
            final Widget trackingPanel = ValleyPanel(
              radius: 28,
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Rastreio multimodal',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ônibus estimado em 2 min. Chegada prevista 18:58, economizando R\$ 15,00 em relação ao app de transporte.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.68),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: widget.onOpenChat,
                          icon: const Icon(Icons.support_agent_rounded),
                          label: const Text('Abrir suporte'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(flex: 6, child: ordersPanel),
                  const SizedBox(width: 18),
                  Expanded(flex: 5, child: trackingPanel),
                ],
              );
            }
            return Column(
              children: <Widget>[
                ordersPanel,
                const SizedBox(height: 18),
                trackingPanel,
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PurchaseTrackingTile extends StatelessWidget {
  const _PurchaseTrackingTile({required this.purchase});

  final ProductPurchase purchase;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (purchase.imageUrl.trim().isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    purchase.imageUrl,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                  ),
                )
              else
                const Icon(
                  Icons.inventory_2_rounded,
                  color: ValleyBrandColors.cyan,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      purchase.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rastreio ${purchase.trackingCode} • ${purchase.trackingEta}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MetaPill(
            icon: Icons.local_shipping_rounded,
            label: purchase.trackingLabel,
          ),
          const SizedBox(height: 10),
          for (final Map<String, dynamic> event in purchase.trackingEvents.take(
            4,
          ))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.circle,
                    size: 8,
                    color: ValleyBrandColors.cyan,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${event['label'] ?? 'Atualização'}: ${event['detail'] ?? ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.68),
                        height: 1.35,
                      ),
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

class _DesktopSideRail extends StatelessWidget {
  const _DesktopSideRail({
    required this.items,
    required this.index,
    required this.onChanged,
  });

  final List<_PrimaryNavItem> items;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xCC0B1020),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < items.length; i++) ...<Widget>[
            _RailButton(
              icon: items[i].icon,
              label: items[i].label,
              selected: index == i,
              onTap: () => onChanged(i),
            ),
            if (i != items.length - 1) const SizedBox(height: 8),
          ],
          const Spacer(),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ValleyBrandColors.cyan.withValues(alpha: 0.12),
              border: Border.all(
                color: ValleyBrandColors.cyan.withValues(alpha: 0.35),
              ),
            ),
            child: const Center(child: _HelenaStarBadge(size: 24)),
          ),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: 52,
          height: 58,
          decoration: BoxDecoration(
            color: selected
                ? ValleyBrandColors.cyan.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? ValleyBrandColors.cyan.withValues(alpha: 0.40)
                  : Colors.transparent,
            ),
          ),
          child: Icon(
            icon,
            color: selected
                ? ValleyBrandColors.cyan
                : Colors.white.withValues(alpha: 0.48),
          ),
        ),
      ),
    );
  }
}

class _FloatingModuleDock extends StatelessWidget {
  const _FloatingModuleDock({
    required this.modules,
    required this.selectedModuleId,
    required this.onOpenModule,
    required this.onOpenIdentity,
    required this.onOpenSettings,
  });

  final List<ProductModule> modules;
  final String selectedModuleId;
  final ValueChanged<String> onOpenModule;
  final VoidCallback onOpenIdentity;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final bool compact = MediaQuery.sizeOf(context).width < 760;
    final List<ProductModule> visibleModules = modules
        .where(
          (ProductModule module) =>
              module.id == 'MARKETPLACE' ||
              module.id == 'STOCK' ||
              module.id == 'CHAT' ||
              module.id == 'PAY',
        )
        .toList();

    if (compact) {
      return Tooltip(
        message: 'Dock Valley',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onOpenSettings,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xE60D1024),
                shape: BoxShape.circle,
                border: Border.all(
                  color: ValleyBrandColors.cyan.withValues(alpha: 0.48),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: ValleyBrandColors.cyan.withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: const Icon(
                Icons.grid_view_rounded,
                color: ValleyBrandColors.cyan,
                size: 23,
              ),
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: compact ? Alignment.bottomCenter : Alignment.bottomRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: compact ? double.infinity : 740),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xD90D1024),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: ValleyBrandColors.cyan.withValues(alpha: 0.13),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                _DockPill(
                  icon: Icons.grid_view_rounded,
                  label: compact ? 'Menu' : 'Dock Valley',
                  selected: false,
                  color: ValleyBrandColors.cyan,
                  onTap: onOpenSettings,
                ),
                const SizedBox(width: 8),
                for (final ProductModule module in visibleModules) ...<Widget>[
                  _DockPill(
                    icon: _moduleIcon(module.id),
                    label: module.id == 'MARKETPLACE'
                        ? 'Market'
                        : module.id == 'PAY'
                        ? 'Checkout'
                        : module.id,
                    selected: selectedModuleId == module.id,
                    color: module.id == 'STOCK'
                        ? ValleyBrandColors.cyan
                        : ValleyBrandColors.violet,
                    onTap: () => onOpenModule(module.id),
                  ),
                  const SizedBox(width: 8),
                ],
                _DockPill(
                  icon: Icons.verified_user_rounded,
                  label: 'Identidade',
                  selected: false,
                  color: ValleyBrandColors.success,
                  onTap: onOpenIdentity,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DockPill extends StatelessWidget {
  const _DockPill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.66)
                  : Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: color, size: 17),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
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

IconData _moduleIcon(String id) {
  switch (id) {
    case 'MARKETPLACE':
      return Icons.storefront_rounded;
    case 'STOCK':
      return Icons.inventory_2_rounded;
    case 'CHAT':
      return Icons.chat_bubble_rounded;
    default:
      return Icons.hexagon_rounded;
  }
}

class _BottomGlassNav extends StatelessWidget {
  const _BottomGlassNav({
    required this.items,
    required this.index,
    required this.onChanged,
  });

  final List<_PrimaryNavItem> items;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
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

class _PrimaryNavItem extends _BottomItem {
  const _PrimaryNavItem({
    required IconData icon,
    required String label,
    this.moduleId,
    this.surface = 'home',
  }) : super(icon, label);

  final String? moduleId;
  final String surface;
}
