import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/app_controller.dart';
import 'core/local_store.dart';
import 'core/session_store.dart';
import 'core/settings_store.dart';
import 'features/main_shell.dart';
import 'l10n/app_localizations.dart';
import 'platform/deep_links.dart';
import 'platform/theme_backdrop.dart';

class TiebaLiteApp extends StatefulWidget {
  const TiebaLiteApp({super.key});
  @override
  State<TiebaLiteApp> createState() => _TiebaLiteAppState();
}

class _TiebaLiteAppState extends State<TiebaLiteApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _links = <TiebaLink>[];
  StreamSubscription<TiebaLink>? _linkSubscription;
  AppController? _controller;
  final _bootstrapNotifier = ChangeNotifier();
  bool _failed = false;
  bool _initializing = false;
  bool _linksDispatchScheduled = false;
  bool _showingRecoveryNotice = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _linkSubscription = DeepLinks().links.listen((link) {
        _links.add(link);
        _dispatchLinks();
      }, onError: (Object _) {});
    }
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    if (_initializing || !mounted) return;
    _initializing = true;
    setState(() => _failed = false);
    final sessions = SessionStore();
    final settings = SettingsStore();
    final local = LocalStore();
    try {
      await sessions.init();
      await settings.init();
      var recoveredLocalData = false;
      try {
        await local.init(accountId: sessions.currentAccount?.id);
      } on FormatException {
        recoveredLocalData = true;
        if (sessions.currentAccount != null) {
          await sessions.activate(null);
          try {
            await local.activateAccount(null);
          } on FormatException {
            // The failed namespace remains empty and read-only; preserve it.
          }
        }
      }
      final controller = AppController(
        sessions: sessions,
        settings: settings,
        local: local,
        onAccountChanged: () {
          _navigatorKey.currentState?.popUntil((route) => route.isFirst);
        },
      );
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      controller.addListener(_dispatchLinks);
      if (recoveredLocalData) {
        _showingRecoveryNotice = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          final navigatorContext = _navigatorKey.currentContext;
          if (navigatorContext != null) {
            final labels = AppLocalizations.of(navigatorContext);
            await showDialog<void>(
              context: navigatorContext,
              builder: (context) => AlertDialog(
                content: Text(labels.localDataRecoveryNotice),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(labels.done),
                  ),
                ],
              ),
            );
          }
          _showingRecoveryNotice = false;
          _dispatchLinks();
        });
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) => _dispatchLinks());
      }
    } catch (_) {
      sessions.dispose();
      settings.dispose();
      local.dispose();
      if (mounted) setState(() => _failed = true);
    } finally {
      _initializing = false;
    }
  }

  void _dispatchLinks() {
    if (!mounted ||
        _controller == null ||
        _controller!.defersIncomingLinks ||
        _showingRecoveryNotice ||
        _linksDispatchScheduled ||
        _navigatorKey.currentContext == null ||
        _links.isEmpty) {
      return;
    }
    _linksDispatchScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _linksDispatchScheduled = false;
      if (!mounted ||
          _controller?.defersIncomingLinks != false ||
          _showingRecoveryNotice) {
        return;
      }
      final context = _navigatorKey.currentContext;
      if (context == null) return;
      for (final link in List<TiebaLink>.of(_links)) {
        _links.remove(link);
        openIncomingLink(context, link);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  ThemeData _theme(Brightness brightness) {
    final preferences = _controller?.settings;
    final seed = Color(
      preferences?.getInt('customPrimaryColor', fallback: 0xFF167D8D) ??
          0xFF167D8D,
    );
    final radius = (preferences?.getDouble('radius', fallback: 20) ?? 20).clamp(
      0.0,
      32.0,
    );
    var colors = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    var canvas = const Color(0xFFF7F9FA);
    if (brightness == Brightness.dark) {
      final (base, card) = switch (preferences?.getString(
        'darkPalette',
        fallback: 'grey_dark',
      )) {
        'blue_dark' => (const Color(0xFF17212B), const Color(0xFF202B37)),
        'amoled_dark' => (const Color(0xFF000000), const Color(0xFF101010)),
        _ => (const Color(0xFF202020), const Color(0xFF2A2A2A)),
      };
      canvas = base;
      colors = colors.copyWith(
        surface: base,
        surfaceContainerLowest: base,
        surfaceContainerLow: card,
        surfaceContainer: Color.alphaBlend(
          Colors.white.withValues(alpha: .03),
          card,
        ),
        surfaceContainerHigh: Color.alphaBlend(
          Colors.white.withValues(alpha: .06),
          card,
        ),
        surfaceContainerHighest: Color.alphaBlend(
          Colors.white.withValues(alpha: .09),
          card,
        ),
      );
    }
    final background =
        preferences?.getString('themeBackground').isNotEmpty == true;
    if (background) {
      final opacity =
          preferences
              ?.getDouble('themeSurfaceOpacity', fallback: .85)
              .clamp(.2, 1.0) ??
          .85;
      colors = colors.copyWith(
        surfaceContainer: colors.surfaceContainer.withValues(alpha: opacity),
        surfaceContainerLow: colors.surfaceContainerLow.withValues(
          alpha: opacity,
        ),
      );
    }
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'NotoSansCJKsc',
      brightness: brightness,
      colorScheme: colors,
      canvasColor: canvas,
      scaffoldBackgroundColor: background ? Colors.transparent : canvas,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: preferences?.getBool('toolbarPrimaryColor') == true
            ? colors.primaryContainer
            : null,
        foregroundColor: preferences?.getBool('toolbarPrimaryColor') == true
            ? colors.onPrimaryContainer
            : null,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      dividerTheme: const DividerThemeData(space: 1, thickness: 0.5),
    );
  }

  Widget _materialApp(BuildContext context, AppController? app) => MaterialApp(
    navigatorKey: _navigatorKey,
    debugShowCheckedModeBanner: false,
    onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: _theme(Brightness.light),
    darkTheme: _theme(Brightness.dark),
    themeMode: switch (app?.settings.themeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    },
    builder: (context, child) {
      final media = MediaQuery.of(context);
      return MediaQuery(
        data: media.copyWith(
          textScaler: TextScaler.linear(
            media.textScaler.scale(1) * (app?.settings.fontScale ?? 1),
          ),
        ),
        child: Stack(
          children: [
            if (app != null && child != null)
              ThemeBackdrop(settings: app.settings, child: child)
            else
              ?child,
            if (app?.changingAccount == true)
              const Positioned.fill(
                child: AbsorbPointer(
                  child: ColoredBox(
                    color: Color(0x55000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              ),
          ],
        ),
      );
    },
    home: app == null
        ? Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: _failed
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_outline, size: 48),
                            const SizedBox(height: 16),
                            Text(
                              AppLocalizations.of(context).initializationFailed,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: _initialize,
                              child: Text(AppLocalizations.of(context).retry),
                            ),
                          ],
                        ),
                      )
                    : const CircularProgressIndicator(),
              ),
            ),
          )
        : MainShell(key: ValueKey(app.session?.userId ?? 'guest')),
  );

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: _controller,
      child: ListenableBuilder(
        listenable: _controller ?? _bootstrapNotifier,
        builder: (context, _) => _materialApp(context, _controller),
      ),
    );
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _controller?.removeListener(_dispatchLinks);
    _controller?.dispose();
    _bootstrapNotifier.dispose();
    super.dispose();
  }
}
