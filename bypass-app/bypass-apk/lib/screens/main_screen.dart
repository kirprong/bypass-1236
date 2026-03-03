import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/timer_provider.dart';
import '../utils/constants.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Создаем контроллер для пульсации (медленная, плавная)
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      body: SafeArea(
        child: Consumer<TimerProvider>(
          builder: (context, timerProvider, child) {
            final color = timerProvider.currentPhaseColor;

            return Stack(
              children: [
                // Фоновый градиент (эффект свечения)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          color.withValues(alpha: 0.15),
                          AppConstants.backgroundColor,
                        ],
                        center: const Alignment(0, -0.2),
                        radius: 1.2,
                      ),
                    ),
                  ),
                ),

                // Верхняя индикаторная линия
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(height: 2, color: color),
                ),

                Column(
                  children: [
                    const SizedBox(height: 60),

                    // Название фазы (ФАЗА X. НАЗВАНИЕ)
                    _buildPhaseLabel(timerProvider),

                    const SizedBox(height: 20),

                    // Текст фазы
                    _buildPhaseText(timerProvider),

                    const Spacer(),

                    // Таймер
                    _buildTimerDisplay(timerProvider),

                    const Spacer(),

                    // Прогресс бар
                    _buildSegmentedProgress(timerProvider),

                    const SizedBox(height: 60),

                    // Управление
                    _buildControls(context, timerProvider),

                    const SizedBox(height: 40),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPhaseLabel(TimerProvider timer) {
    return Text(
      timer.isInertiaMode
          ? 'РЕЖИМ ИНЕРЦИИ'
          : timer.isWaitingForChoice
              ? 'МОМЕНТ ИСТИНЫ'
              : 'ФАЗА ${timer.currentPhaseIndex + 1}. ${timer.currentPhaseName}',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: timer.currentPhaseColor,
        letterSpacing: 4,
      ),
    );
  }

  Widget _buildPhaseText(TimerProvider timer) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Text(
        timer.currentPhaseText,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: timer.isWaitingForChoice ? 20 : 28,
          fontWeight: FontWeight.w900,
          color: AppConstants.textPrimaryColor,
          letterSpacing: 2,
          height: 1.2,
        ),
      ),
    );
  }

  Widget _buildTimerDisplay(TimerProvider timer) {
    final color = timer.currentPhaseColor;
    
    // Если фаза RECOVERY (фаза 3) - показываем пульсирующую анимацию вместо таймера
    if (timer.currentPhaseIndex == 3 && !timer.isInertiaMode) {
      return _buildRecoveryAnimation(color);
    }
    
    final displayTime = timer.isInertiaMode
        ? timer.inertiaSeconds
        : timer.remainingSeconds;
    final prefix = timer.isInertiaMode ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        '$prefix${timer.formatTime(displayTime)}',
        style: TextStyle(
          fontSize: timer.isInertiaMode ? 82 : 96,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
          color: color,
          letterSpacing: timer.isInertiaMode ? 4 : 8,
          shadows: [Shadow(color: color.withValues(alpha: 0.5), blurRadius: 30)],
        ),
        maxLines: 1,
      ),
    );
  }

  Widget _buildControls(BuildContext context, TimerProvider timer) {
    final color = timer.currentPhaseColor;

    // Если ожидается выбор после фазы 3
    if (timer.isWaitingForChoice) {
      return Column(
        children: [
          // Кнопка ИНЕРЦИЯ (только для премиум)
          if (timer.isPremium) ...[
            _buildMainButton(
              text: '⚡ ИНЕРЦИЯ',
              color: AppConstants.inertiaColor,
              onTap: () => timer.activateInertia(),
              glow: true,
            ),
            const SizedBox(height: 15),
          ],
          
          // Кнопка ОТДЫХ (доступна всем)
          _buildMainButton(
            text: '🧠 ОТДЫХ',
            color: AppConstants.phase4Color,
            onTap: () => timer.startRecovery(),
            textColor: Colors.black,
          ),
          
          const SizedBox(height: 10),
          
          // Подсказка для бесплатных пользователей
          if (!timer.isPremium)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Режим ИНЕРЦИЯ доступен только в премиум',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppConstants.textSecondaryColor,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ),
        ],
      );
    }

    // Обычное управление
    return Column(
      children: [
        // Основная кнопка СТАРТ / ПАУЗА (скрываем в режиме инерции)
        if (!timer.isInertiaMode)
          _buildMainButton(
            text: timer.isRunning ? 'ПАУЗА' : 'СТАРТ',
            color: color,
            onTap: () => timer.toggle(),
          ),

        // Кнопка СТОП (в инерции)
        if (timer.isInertiaMode) ...[
          _buildMainButton(
            text: 'ЗАВЕРШИТЬ ИНЕРЦИЮ',
            color: AppConstants.phase4Color,
            textColor: Colors.black,
            onTap: () => timer.stopInertia(),
          ),
        ],

        // Кнопка СБРОС (когда на паузе и не в инерции и не ожидаем выбор)
        if (!timer.isRunning && !timer.isInertiaMode && !timer.isWaitingForChoice) ...[
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => timer.reset(),
            child: Text(
              'СБРОС',
              style: TextStyle(
                color: AppConstants.textSecondaryColor,
                letterSpacing: 2,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMainButton({
    required String text,
    required Color color,
    required VoidCallback onTap,
    Color textColor = Colors.black,
    bool glow = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        height: 70,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: glow ? 0.8 : 0.4),
              blurRadius: glow ? 20 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: textColor,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentedProgress(TimerProvider timer) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: List.generate(4, (index) {
          final isCompleted = index < timer.currentPhaseIndex;
          final isActive = index == timer.currentPhaseIndex;
          final color = isActive || isCompleted
              ? timer.currentPhaseColor
              : const Color(0xFF333333);

          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 6,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
                boxShadow: isActive
                    ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8)]
                    : [],
              ),
            ),
          );
        }),
      ),
    );
  }

  /// Пульсирующая анимация для фазы RECOVERY
  Widget _buildRecoveryAnimation(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: _pulseAnimation.value * 0.3),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: _pulseAnimation.value * 0.5),
                  blurRadius: 40 * _pulseAnimation.value,
                  spreadRadius: 10 * _pulseAnimation.value,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.autorenew,
                size: 80,
                color: color.withValues(alpha: _pulseAnimation.value),
              ),
            ),
          );
        },
      ),
    );
  }
}
