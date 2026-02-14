import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stats_provider.dart';
import '../utils/constants.dart';
import 'paywall_screen.dart';
import 'methodology_screen.dart';

/// Экран настроек (как в React версии)
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      body: SafeArea(
        child: Consumer<StatsProvider>(
          builder: (context, statsProvider, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Заголовок
                  Center(
                    child: Text(
                      'НАСТРОЙКИ',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppConstants.textPrimaryColor,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Статус подписки
                  _buildSection('Статус', [
                    _buildStatusCard(statsProvider.isPremium),
                    const SizedBox(height: 15),

                    if (!statsProvider.isPremium) _buildUpgradeButton(context),

                    const SizedBox(height: 15),

                    // Тестовая кнопка переключения премиум
                    _buildTestButton(context, statsProvider),
                  ]),

                  const SizedBox(height: 30),

                  // О приложении
                  _buildSection('О приложении', [
                    _buildInfoText('BYPASS-1236', isPrimary: true),
                    const SizedBox(height: 5),
                    _buildInfoText(
                      'Техника 1-2-3-6 для максимальной продуктивности',
                    ),
                    const SizedBox(height: 3),
                    _buildInfoText('Версия 1.0.0'),
                  ]),

                  const SizedBox(height: 30),

                  // Информация о технике
                  _buildSection('Как это работает', [
                    _buildPhaseInfo(),
                    const SizedBox(height: 20),
                    _buildMethodologyButton(context),
                  ]),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppConstants.textPrimaryColor,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 15),
        ...children,
      ],
    );
  }

  Widget _buildStatusCard(bool isPremium) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Версия:',
            style: TextStyle(
              fontSize: 14,
              color: AppConstants.textSecondaryColor,
            ),
          ),
          Text(
            isPremium ? 'ПРЕМИУМ ХИЩНИК' : 'Бесплатная',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isPremium
                  ? AppConstants.inertiaColor
                  : AppConstants.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PaywallScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFFF0000),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            '⚡ СТАТЬ ХИЩНИКОМ',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTestButton(BuildContext context, StatsProvider statsProvider) {
    return GestureDetector(
      onTap: () async {
        if (statsProvider.isPremium) {
          // Деактивация премиум
          final prefs = await statsProvider.initialize();
          statsProvider.resetAll();
        } else {
          statsProvider.activatePremium();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF333333),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            statsProvider.isPremium
                ? 'Отключить премиум (тест)'
                : 'Включить премиум (тест)',
            style: TextStyle(
              fontSize: 14,
              color: AppConstants.textSecondaryColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoText(String text, {bool isPrimary = false}) {
    return Text(
      text,
      style: TextStyle(
        fontSize: isPrimary ? 16 : 14,
        color: isPrimary
            ? AppConstants.textPrimaryColor
            : AppConstants.textSecondaryColor,
        fontWeight: isPrimary ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildPhaseInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPhaseInfoItem('⏱️ 1 минута — Анализ задачи'),
          const SizedBox(height: 10),
          _buildPhaseInfoItem('🔧 2 минуты — Подготовка'),
          const SizedBox(height: 10),
          _buildPhaseInfoItem('⚡ 3 минуты — Выполнение'),
          const SizedBox(height: 10),
          _buildPhaseInfoItem('🧠 6 минут — Стратегический отдых'),
        ],
      ),
    );
  }

  Widget _buildPhaseInfoItem(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        color: AppConstants.textSecondaryColor,
        height: 1.5,
      ),
    );
  }

  Widget _buildMethodologyButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MethodologyScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: AppConstants.phase1Color, width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.menu_book,
              color: AppConstants.phase1Color,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              'ПОЛНАЯ МЕТОДИКА',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppConstants.phase1Color,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
