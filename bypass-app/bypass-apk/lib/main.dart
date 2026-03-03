import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'providers/timer_provider.dart';
import 'providers/stats_provider.dart';
import 'screens/main_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/paywall_screen.dart';
import 'screens/loading_screen.dart';
import 'utils/constants.dart';
import 'services/notification_service.dart';
import 'services/audio_service.dart';

void main() async {
  // ⚠️ КРИТИЧНО: Обработка ошибок
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // КРИТИЧНО: Инициализация аудио в main() перед всем остальным
    try {
      debugPrint('🔊 Initializing AudioService in main()...');
      await AudioService().initialize();
      debugPrint('✅ AudioService initialized in main()');
    } catch (e) {
      debugPrint('⚠️ AudioService init failed: $e');
      // Продолжаем работу без звука
    }

    // Безопасная инициализация уведомлений
    try {
      await NotificationService().initialize();
      debugPrint('✅ NotificationService initialized');
    } catch (e) {
      debugPrint('⚠️ NotificationService init failed: $e');
      // Продолжаем работу без уведомлений
    }

    // Безопасная установка ориентации
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      debugPrint('✅ Orientation set');
    } catch (e) {
      debugPrint('⚠️ Orientation setup failed: $e');
    }

    // Безопасная настройка UI
    try {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: [SystemUiOverlay.top],
      );
      debugPrint('✅ SystemUI configured');
    } catch (e) {
      debugPrint('⚠️ SystemUI setup failed: $e');
    }

    runApp(const BypassApp());
  }, (error, stack) {
    debugPrint('💥 CRITICAL ERROR: $error');
    debugPrint('Stack: $stack');
  });
}

class BypassApp extends StatelessWidget {
  const BypassApp({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('🎨 Building BypassApp');
    
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => StatsProvider()),
        ChangeNotifierProxyProvider<StatsProvider, TimerProvider>(
          create: (_) => TimerProvider(),
          update: (_, statsProvider, timerProvider) {
            timerProvider!.setStatsProvider(statsProvider);
            return timerProvider;
          },
        ),
      ],
      child: MaterialApp(
        title: '1234',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppConstants.backgroundColor,
          primaryColor: AppConstants.phase3Color,
          fontFamily: 'Roboto',
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: Colors.white),
            bodyMedium: TextStyle(color: Colors.white),
          ),
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const SafeHomePage(),
          '/paywall': (context) => const PaywallScreen(),
        },
      ),
    );
  }
}

/// Безопасная обёртка HomePage с обработкой ошибок
class SafeHomePage extends StatefulWidget {
  const SafeHomePage({super.key});

  @override
  State<SafeHomePage> createState() => _SafeHomePageState();
}

class _SafeHomePageState extends State<SafeHomePage> {
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _safeInitialize();
  }

  Future<void> _safeInitialize() async {
    debugPrint('🔧 Starting safe initialization...');
    
    try {
      // Включаем wakelock
      try {
        await WakelockPlus.enable();
        debugPrint('✅ Wakelock enabled');
      } catch (e) {
        debugPrint('⚠️ Wakelock failed: $e');
      }

      // Ждём следующий фрейм перед использованием context
      await Future.delayed(Duration.zero);
      
      if (!mounted) {
        debugPrint('⚠️ Widget unmounted during init');
        return;
      }

      final statsProvider = context.read<StatsProvider>();
      final timerProvider = context.read<TimerProvider>();

      // Инициализируем провайдеры с таймаутом
      debugPrint('📊 Initializing StatsProvider...');
      await statsProvider.initialize().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('⚠️ StatsProvider init timeout');
          throw TimeoutException('Stats initialization timeout');
        },
      );
      debugPrint('✅ StatsProvider initialized');

      debugPrint('⏱️ Initializing TimerProvider...');
      await timerProvider.initialize().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('⚠️ TimerProvider init timeout');
          throw TimeoutException('Timer initialization timeout');
        },
      );
      debugPrint('✅ TimerProvider initialized');

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        debugPrint('🎉 Initialization complete!');
      }
    } catch (e, stack) {
      debugPrint('💥 Initialization error: $e');
      debugPrint('Stack: $stack');
      
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable().catchError((e) {
      debugPrint('⚠️ Wakelock disable failed: $e');
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return LoadingScreen(
        hasError: true,
        errorMessage: _errorMessage,
      );
    }

    if (!_isInitialized) {
      return const LoadingScreen(
        message: 'Инициализация...',
      );
    }

    return const HomePage();
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const MainScreen(),
    const StatsScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Включаем wakelock чтобы экран не гас во время работы
    WakelockPlus.enable();

    // Инициализируем провайдеры БЕЗ использования context после async
    if (!mounted) return;
    final statsProvider = context.read<StatsProvider>();
    final timerProvider = context.read<TimerProvider>();

    await statsProvider.initialize();
    await timerProvider.initialize();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      body: _screens[_currentIndex],
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(color: const Color(0xFF333333), width: 1),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: AppConstants.textPrimaryColor,
        unselectedItemColor: AppConstants.textSecondaryColor,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text('⚡', style: TextStyle(fontSize: 24)),
            ),
            label: 'ТАЙМЕР',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text('📊', style: TextStyle(fontSize: 24)),
            ),
            label: 'СТАТИСТИКА',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text('⚙️', style: TextStyle(fontSize: 24)),
            ),
            label: 'НАСТРОЙКИ',
          ),
        ],
      ),
    );
  }
}
