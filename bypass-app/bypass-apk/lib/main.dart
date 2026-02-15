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
import 'utils/constants.dart';
import 'package:just_audio_background/just_audio_background.dart';

void main() async {
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.bypass_1236.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
  );
  WidgetsFlutterBinding.ensureInitialized();

  // Портретная ориентация
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Скрываем системные панели для полного погружения
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: [SystemUiOverlay.top],
  );

  runApp(const BypassApp());
}

class BypassApp extends StatelessWidget {
  const BypassApp({super.key});

  @override
  Widget build(BuildContext context) {
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
        title: 'BYPASS-1236',
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
          '/': (context) => const HomePage(),
          '/paywall': (context) => const PaywallScreen(),
        },
      ),
    );
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
          top: BorderSide(
            color: const Color(0xFF333333),
            width: 1,
          ),
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
