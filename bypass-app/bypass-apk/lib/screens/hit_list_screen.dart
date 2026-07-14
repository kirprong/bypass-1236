import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/hit_list_provider.dart';
import '../utils/constants.dart';

/// Экран планировщика "THE HIT-LIST" (V1.3 / TASK-V1.3-004).
class HitListScreen extends StatelessWidget {
  const HitListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'THE HIT-LIST',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
      ),
      body: SafeArea(
        child: Consumer<HitListProvider>(
          builder: (context, hitList, child) {
            return Column(
              children: [
                _buildStatusBanner(hitList),
                Expanded(
                  child: hitList.slots.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: hitList.slots.length,
                          itemBuilder: (context, index) =>
                              _buildSlotCard(context, hitList, hitList.slots[index]),
                        ),
                ),
                _buildAddButton(hitList),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusBanner(HitListProvider hitList) {
    final active = hitList.isActive;
    final canAdd = hitList.slots.length < AppConstants.hitListMaxSlots;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? AppConstants.phase1Color : const Color(0xFF333333),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            active ? Icons.alarm_on : Icons.alarm_off,
            color: active ? AppConstants.phase1Color : AppConstants.textSecondaryColor,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active ? 'РАСПИСАНИЕ АКТИВНО' : 'РАСПИСАНИЕ НЕАКТИВНО',
                  style: TextStyle(
                    color: active
                        ? AppConstants.phase1Color
                        : AppConstants.textSecondaryColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  canAdd
                      ? 'Слотов: ${hitList.slots.length}/${AppConstants.hitListMaxSlots}'
                      : 'Достигнут лимит слотов (${AppConstants.hitListMaxSlots})',
                  style: TextStyle(
                    color: AppConstants.textSecondaryColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.playlist_add, size: 64, color: Color(0xFF333333)),
            const SizedBox(height: 16),
            Text(
              'НЕТ ЗАПЛАНИРОВАННЫХ ЦЕЛЕЙ',
              style: TextStyle(
                color: AppConstants.textSecondaryColor,
                fontSize: 16,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Добавьте слот, чтобы таймер запускался автоматически каждый день в выбранное время.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppConstants.textSecondaryColor,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotCard(
    BuildContext context,
    HitListProvider hitList,
    HitListSlot slot,
  ) {
    final isLastWindow = hitList.lastExecutedWindow ==
        AppConstants.hitListWindowKey(
          DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
            slot.hour,
            slot.minute,
          ).millisecondsSinceEpoch,
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: slot.enabled
              ? AppConstants.phase1Color.withValues(alpha: 0.5)
              : const Color(0xFF222222),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${slot.hour.toString().padLeft(2, '0')}:'
                  '${slot.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    letterSpacing: 2,
                  ),
                ),
              ),
              if (isLastWindow)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppConstants.phase1Color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'ВЫПОЛНЕНО',
                    style: TextStyle(
                      color: AppConstants.phase1Color,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Color(0xFF666666)),
                onPressed: () => hitList.removeSlot(slot.slotId),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildTimeSlider(
            label: 'ЧАС',
            value: slot.hour,
            min: 0,
            max: 23,
            onChanged: (v) => hitList.setSlotTime(slot.slotId, v, slot.minute),
          ),
          _buildTimeSlider(
            label: 'МИН',
            value: slot.minute,
            min: 0,
            max: 59,
            onChanged: (v) => hitList.setSlotTime(slot.slotId, slot.hour, v),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ВКЛЮЧЁН',
                style: TextStyle(
                  color: AppConstants.textSecondaryColor,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
              Switch(
                value: slot.enabled,
                activeThumbColor: AppConstants.phase1Color,
                onChanged: (v) => hitList.toggleSlot(slot.slotId, v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSlider({
    required String label,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(
            label,
            style: TextStyle(
              color: AppConstants.textSecondaryColor,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppConstants.phase1Color,
              inactiveTrackColor: const Color(0xFF333333),
              thumbColor: AppConstants.phase1Color,
              overlayColor: AppConstants.phase1Color.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: value.toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: max - min,
              label: value.toString().padLeft(2, '0'),
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
        ),
        SizedBox(
          width: 34,
          child: Text(
            value.toString().padLeft(2, '0'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddButton(HitListProvider hitList) {
    final canAdd = hitList.slots.length < AppConstants.hitListMaxSlots;
    return Opacity(
      opacity: canAdd ? 1.0 : 0.4,
      child: GestureDetector(
        onTap: canAdd ? () => hitList.addSlot() : null,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          height: 56,
          decoration: BoxDecoration(
            color: AppConstants.phase1Color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Text(
              '+ ДОБАВИТЬ СЛОТ',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
