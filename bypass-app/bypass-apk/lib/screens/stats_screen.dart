import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stats_provider.dart';
import '../utils/constants.dart';

/// Экран статистики "Боевых заслуг"
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      body: SafeArea(
        child: Consumer<StatsProvider>(
          builder: (context, statsProvider, child) {
            final currentRank = statsProvider.currentRank;
            final nextRank = statsProvider.nextRank;
            
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Заголовок
                  Center(
                    child: Text(
                      'БОЕВЫЕ ЗАСЛУГИ',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 8,
                        color: AppConstants.textPrimaryColor,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Текущий ранг
                  _buildRankCard(currentRank, statsProvider.totalStrikes),
                  const SizedBox(height: 30),
                  
                  // Прогресс до следующего ранга
                  if (nextRank != null)
                    _buildProgressToNextRank(
                      currentRank,
                      nextRank,
                      statsProvider.strikesToNextRank,
                    ),
                  
                  const SizedBox(height: 40),
                  
                  // Статистика
                  _buildStatCard(
                    'УДАРОВ НАНЕСЕНО',
                    '${statsProvider.totalStrikes}',
                    AppConstants.phase3Color,
                    'Завершенных циклов работы',
                  ),
                  const SizedBox(height: 20),
                  
                  _buildStatCard(
                    'ВРЕМЯ ДОМИНИРОВАНИЯ',
                    '${statsProvider.totalDominationHours.toStringAsFixed(1)} ч',
                    AppConstants.inertiaColor,
                    'Общее время в продуктивной работе',
                  ),
                  const SizedBox(height: 20),
                  
                  _buildStatCard(
                    'ВРЕМЯ ИНЕРЦИИ',
                    '${(statsProvider.totalInertiaTime / 60).toStringAsFixed(0)} мин',
                    AppConstants.phase2Color,
                    'Дополнительное время в потоке',
                  ),
                  const SizedBox(height: 20),
                  
                  if (!statsProvider.isPremium)
                    _buildStatCard(
                      'ЦИКЛЫ СЕГОДНЯ',
                      '${statsProvider.todayCycles} / ${AppConstants.freeCyclesPerDay}',
                      AppConstants.phase1Color,
                      'Лимит для бесплатной версии',
                    ),
                  
                  const SizedBox(height: 40),
                  
                  // Мотивационный текст
                  _buildMotivationalText(currentRank['name']),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Карточка текущего ранга
  Widget _buildRankCard(Map<String, dynamic> rank, int strikes) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            rank['color'].withOpacity(0.3),
            AppConstants.backgroundColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: rank['color'].withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Text(
            'ТЕКУЩИЙ РАНГ',
            style: TextStyle(
              fontSize: 14,
              color: AppConstants.textSecondaryColor,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            rank['name'],
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: rank['color'],
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$strikes STRIKES',
            style: TextStyle(
              fontSize: 18,
              color: AppConstants.textSecondaryColor,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  /// Прогресс до следующего ранга
  Widget _buildProgressToNextRank(
    Map<String, dynamic> currentRank,
    Map<String, dynamic> nextRank,
    int strikesToNext,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppConstants.textSecondaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'СЛЕДУЮЩИЙ РАНГ',
                style: TextStyle(
                  fontSize: 12,
                  color: AppConstants.textSecondaryColor,
                  letterSpacing: 2,
                ),
              ),
              Text(
                nextRank['name'],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: nextRank['color'],
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: 1.0 - (strikesToNext / (nextRank['strikes'] - currentRank['strikes'])),
              minHeight: 8,
              backgroundColor: AppConstants.textSecondaryColor.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(nextRank['color']),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Осталось: $strikesToNext strikes',
            style: TextStyle(
              fontSize: 12,
              color: AppConstants.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Карточка статистики
  Widget _buildStatCard(String title, String value, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.2),
            AppConstants.backgroundColor,
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppConstants.textSecondaryColor,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppConstants.textSecondaryColor.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: color,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  /// Мотивационный текст
  Widget _buildMotivationalText(String rank) {
    String text;
    switch (rank) {
      case 'ПЛАНКТОН':
        text = 'Ты в самом начале пути. Каждый удар приближает тебя к вершине.';
        break;
      case 'БОЕЦ':
        text = 'Ты начал двигаться. Продолжай атаковать свои цели.';
        break;
      case 'ВОИН':
        text = 'Твоя дисциплина растет. Ты уже не тот, кем был вчера.';
        break;
      case 'ХИЩНИК':
        text = 'Ты в топе. Твоя эффективность - это оружие массового поражения.';
        break;
      case 'APEX PREDATOR':
        text = 'Ты достиг вершины пищевой цепи. Ты - машина доминирования.';
        break;
      default:
        text = 'Продолжай работать. Результат неизбежен.';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: AppConstants.inertiaColor,
            width: 4,
          ),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: AppConstants.textSecondaryColor,
          fontStyle: FontStyle.italic,
          height: 1.6,
        ),
      ),
    );
  }
}
