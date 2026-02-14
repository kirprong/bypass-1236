import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stats_provider.dart';
import '../utils/constants.dart';

/// Экран paywall для премиум подписки
class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Кнопка закрытия
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: Icon(
                    Icons.close,
                    color: AppConstants.textSecondaryColor,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Заголовок
              Center(
                child: Text(
                  'ВЫБОР СДЕЛАН',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 6,
                    color: AppConstants.phase3Color,
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Основной текст
              _buildMainText(),
              
              const SizedBox(height: 40),
              
              // Преимущества премиум
              _buildFeaturesList(),
              
              const SizedBox(height: 40),
              
              // Цена и кнопка
              _buildPricingSection(context),
              
              const SizedBox(height: 30),
              
              // Сравнение с кофе
              _buildComparisonText(),
              
              const SizedBox(height: 40),
              
              // Финальный удар
              _buildFinalPush(),
            ],
          ),
        ),
      ),
    );
  }

  /// Основной текст
  Widget _buildMainText() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppConstants.phase3Color.withValues(alpha: 0.2),
            AppConstants.backgroundColor,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppConstants.phase3Color.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Text(
        'Большинство людей проживают жизнь в режиме автопилота. '
        'Они планируют, откладывают, мечтают... но не делают.\n\n'
        'Ты уже сделал первый шаг. Ты попробовал BYPASS-1236.\n\n'
        'Теперь вопрос: готов ли ты перейти на следующий уровень?',
        style: TextStyle(
          fontSize: 16,
          color: AppConstants.textPrimaryColor,
          height: 1.8,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Список преимуществ
  Widget _buildFeaturesList() {
    final features = [
      {
        'icon': Icons.all_inclusive,
        'title': 'БЕЗЛИМИТНЫЕ ЦИКЛЫ',
        'desc': 'Никаких ограничений на количество сессий в день',
        'color': AppConstants.inertiaColor,
      },
      {
        'icon': Icons.bolt,
        'title': 'РЕЖИМ ИНЕРЦИИ',
        'desc': 'Продолжай работать когда поймал поток',
        'color': AppConstants.phase3Color,
      },
      {
        'icon': Icons.assessment,
        'title': 'ПОЛНАЯ СТАТИСТИКА',
        'desc': 'Экспорт данных, графики, аналитика прогресса',
        'color': AppConstants.phase1Color,
      },
      {
        'icon': Icons.headphones,
        'title': 'ПРЕМИУМ ЗВУКИ',
        'desc': 'Эксклюзивные бинауральные ритмы для фокуса',
        'color': AppConstants.phase2Color,
      },
    ];

    return Column(
      children: features.map((feature) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: (feature['color'] as Color).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (feature['color'] as Color).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: feature['color'] as Color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  feature['icon'] as IconData,
                  color: Colors.black,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feature['title'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: feature['color'] as Color,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      feature['desc'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppConstants.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Секция с ценой
  Widget _buildPricingSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppConstants.inertiaColor.withValues(alpha: 0.3),
            AppConstants.backgroundColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppConstants.inertiaColor,
          width: 3,
        ),
      ),
      child: Column(
        children: [
          Text(
            'ПРЕМИУМ ДОСТУП',
            style: TextStyle(
              fontSize: 12,
              color: AppConstants.textSecondaryColor,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '\$',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppConstants.inertiaColor,
                ),
              ),
              Text(
                '5',
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: AppConstants.inertiaColor,
                  height: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '/месяц',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppConstants.textSecondaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Кнопка подписки
          GestureDetector(
            onTap: () {
              // Для демо - просто активируем премиум
              final statsProvider = context.read<StatsProvider>();
              statsProvider.activatePremium();
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('ПРЕМИУМ АКТИВИРОВАН! Теперь ты ХИЩНИК.'),
                  backgroundColor: AppConstants.inertiaColor,
                  duration: const Duration(seconds: 2),
                ),
              );
              
              Navigator.pop(context);
            },
            child: Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                color: AppConstants.inertiaColor,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppConstants.inertiaColor.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  'СТАТЬ ХИЩНИКОМ',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    letterSpacing: 4,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Сравнение с кофе
  Widget _buildComparisonText() {
    return Text(
      'Это меньше, чем одна чашка помойного кофе в Starbucks.\n'
      'Но кофе даст тебе 2 часа бодрости.\n'
      'BYPASS-1236 даст тебе контроль над всей жизнью.',
      style: TextStyle(
        fontSize: 14,
        color: AppConstants.textSecondaryColor,
        fontStyle: FontStyle.italic,
        height: 1.6,
      ),
      textAlign: TextAlign.center,
    );
  }

  /// Финальный удар
  Widget _buildFinalPush() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: AppConstants.phase3Color,
            width: 4,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ПОСЛЕДНИЙ ВОПРОС:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppConstants.phase3Color,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Ты машина или ты планктон?\n\n'
            'Машина платит \$5 и берет жизнь за яйца.\n'
            'Планктон нажимает "назад" и возвращается в болото.',
            style: TextStyle(
              fontSize: 14,
              color: AppConstants.textPrimaryColor,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
