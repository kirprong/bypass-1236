import 'package:flutter/material.dart';
import '../utils/constants.dart';

class MethodologyScreen extends StatelessWidget {
  const MethodologyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppConstants.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: AppConstants.textPrimaryColor,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'МЕТОДИКА 1234',
          style: TextStyle(
            color: AppConstants.textPrimaryColor,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroSection(),
            const SizedBox(height: 30),
            _buildPhaseSection(
              num: '1',
              title: '1 МИНУТА (АНАЛИЗ)',
              color: AppConstants.phase1Color,
              content:
                  'Это «холодный расчет». За 60 секунд ты успеваешь исключить сложности. Ты просто видишь суть задачи. Мозг начинает работать на сухую, отбрасывая всё лишнее дерьмо.',
            ),
            _buildPhaseSection(
              num: '2',
              title: '2 МИНУТЫ (ПОДГОТОВКА)',
              color: AppConstants.phase2Color,
              content:
                  'Это создание «Боевой зоны». Ты не просто открываешь вкладки, ты убираешь всё, что может тебя отвлечь. Это ритуал. За 2 минуты ты входишь в состояние, когда тебе уже тупо жалко времени на фигню. Все инструменты уже разложены.',
            ),
            _buildPhaseSection(
              num: '3',
              title: '3 МИНУТЫ (БЛИЦКРИГ)',
              color: AppConstants.phase3Color,
              content:
                  'Это самый важный момент. 3 минуты — это нихера не долго, любой дебил выдержит. Но фокус в том, что через 3 минуты мозг уже не хочет останавливаться. Мозгу уже проще продолжать, чем останавливаться. Это чистый взлом дофаминовой системы.',
            ),
            _buildPhaseSection(
              num: '?',
              title: 'ПЕРЕЗАГРУЗКА (1-4 МИН)',
              color: AppConstants.phase4Color,
              content:
                  'Стратегическая пауза случайной длины. Ты не знаешь, сколько времени на отдых — это держит тебя в готовности. Мозг отдыхает, но не расслабляется. После паузы система АВТОМАТИЧЕСКИ запускает новый цикл. Будь готов всегда.',
            ),
            const Divider(color: Color(0xFF333333), height: 60),
            _buildNarrativeSection(
              'ПРИНЦИП «ПЕРВОЙ КРОВИ»',
              'В эти 3 минуты делай самое неприятное или самое конкретное. Никакого планирования внутри процесса! Только чистое действие. Если пишешь код — пиши код. Если звонишь клиенту — набирай номер сразу. Не дай мозгу опомниться и начать сомневаться.',
            ),
            const SizedBox(height: 20),
            _buildNarrativeSection(
              'ИДЕАЛЬНАЯ ИЗОЛЯЦИЯ',
              'На время выполнения «1-2-3» ты должен исчезнуть для мира. Телефон экраном вниз, уведомления в пизду. Только ты и таймер.',
            ),
            const SizedBox(height: 20),
            _buildNarrativeSection(
              'НЕПРЕДСКАЗУЕМОСТЬ — ТВОЁ ОРУЖИЕ',
              'Отдых длится от 1 до 4 минут, и ты не видишь таймер. Это убирает привычку «досидеть последние секунды». Мозг не может расслабиться полностью — он знает, что в любой момент снова начнется работа. После паузы система сама запускает новый цикл. Никаких оправданий.',
            ),
            const SizedBox(height: 20),
            _buildNarrativeSection(
              'ЭФФЕКТ ИНЕРЦИИ (GOD MODE)',
              'Если после 3 минут ты чувствуешь, что «поперло» — не вздумай останавливаться! Твои 3 минуты — это просто входной билет в состояние потока. Нажимай кнопку INERTIA и доминируй. Но помни: за каждые 10 минут переработки добавляется 1 минута отдыха.',
            ),
            const SizedBox(height: 40),
            _buildQuote('Перестань планировать. Начни доминировать.'),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: AppConstants.inertiaColor, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          Text(
            'БЫТЬ БОЛЕЕ ИСПОЛНИТЕЛЬНЫМ И ЭФФЕКТИВНЫМ',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppConstants.inertiaColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Твоя техника 1-2-3 — это идеальный способ обмануть свою биологическую лень. Непредсказуемый отдых и автоматический перезапуск держат тебя в тонусе.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppConstants.textPrimaryColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseSection({
    required String num,
    required String title,
    required Color color,
    required String content,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    num,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              color: AppConstants.textPrimaryColor,
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrativeSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppConstants.textSecondaryColor,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          content,
          style: const TextStyle(
            color: AppConstants.textPrimaryColor,
            fontSize: 15,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildQuote(String text) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: AppConstants.phase3Color, width: 4),
          ),
        ),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: AppConstants.phase3Color,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}
