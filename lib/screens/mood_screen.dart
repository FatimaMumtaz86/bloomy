import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

const _uuid = Uuid();
const _replacementChar = '\uFFFD';

String _fallbackMoodSymbol(String mood) {
  switch (mood.toLowerCase()) {
    case 'happy':
      return 'H';
    case 'calm':
      return 'C';
    case 'sad':
      return 'S';
    case 'anxious':
      return 'X';
    case 'angry':
      return 'A';
    case 'tired':
      return 'T';
    default:
      return '·';
  }
}

String _safeMoodSymbol(MoodEntry? entry) {
  if (entry == null) {
    return '·';
  }
  final raw = entry.emoji.trim();
  if (raw.isNotEmpty && !raw.contains('?') && raw != _replacementChar) {
    return raw;
  }
  return _fallbackMoodSymbol(entry.mood);
}

class MoodScreen extends StatefulWidget {
  const MoodScreen({super.key});

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  DateTime _focused = DateTime.now();
  DateTime? _selected;

  static const _moods = [
    ('Happy', 'H', AppColors.moodHappy),
    ('Calm', 'C', AppColors.moodCalm),
    ('Sad', 'S', AppColors.moodSad),
    ('Anxious', 'X', AppColors.moodAnxious),
    ('Angry', 'A', AppColors.moodAngry),
    ('Tired', 'T', AppColors.moodTired),
  ];

  @override
  Widget build(BuildContext context) {
    final moodProvider = context.watch<MoodProvider>();
    final todayEntry = moodProvider.getEntryForDate(DateTime.now());
    final selectedEntry =
        _selected == null ? null : moodProvider.getEntryForDate(_selected!);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        title: const Text(
          'Mood and Cycle',
          style:
              TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (todayEntry == null)
              _LogMoodBanner(
                moods: _moods,
                onLog: (entry) => moodProvider.logMood(entry),
              )
            else
              _TodayMoodCard(
                entry: todayEntry,
                onDelete: () => _confirmDeleteMood(todayEntry),
              ),
            _MoodCalendar(
              focused: _focused,
              selected: _selected,
              moodProvider: moodProvider,
              onFocused: (value) => setState(() => _focused = value),
              onSelected: (value) => setState(() => _selected = value),
            ),
            if (selectedEntry != null)
              _DayDetail(
                entry: selectedEntry,
                onDelete: () => _confirmDeleteMood(selectedEntry),
              ),
            _CyclePredictionCard(prediction: moodProvider.cyclePrediction),
            _WeeklySummary(moodProvider: moodProvider),
            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteMood(MoodEntry entry) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete mood entry?'),
        content: const Text('This mood log will be removed permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await context.read<MoodProvider>().deleteEntry(entry.id);
      if (!mounted) {
        return;
      }
      setState(() => _selected = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mood entry deleted.')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete mood entry: $e')),
      );
    }
  }
}

class _LogMoodBanner extends StatelessWidget {
  final List<(String, String, Color)> moods;
  final Future<void> Function(MoodEntry entry) onLog;

  const _LogMoodBanner({required this.moods, required this.onLog});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppColors.softPink, AppColors.lavenderLight]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How are you feeling today?',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          const Text('Tap a mood to log your day',
              style: TextStyle(color: AppColors.textMed)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: moods
                .map(
                  (mood) => GestureDetector(
                    onTap: () => _showLogDialog(context, mood),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: mood.$3.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: mood.$3.withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(mood.$2, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 6),
                          Text(
                            mood.$1,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  void _showLogDialog(BuildContext context, (String, String, Color) mood) {
    bool isPeriodDay = false;
    int? painLevel;
    String? flow;
    final noteController = TextEditingController();

    const symptomOptions = [
      'Cramps',
      'Headache',
      'Bloating',
      'Fatigue',
      'Acne',
      'Back Pain',
      'Cravings',
      'Irritability',
    ];

    final selectedSymptoms = <String>{};

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text('${mood.$2} ${mood.$1}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Period day',
                          style: TextStyle(color: AppColors.textMed)),
                      const Spacer(),
                      Switch(
                        value: isPeriodDay,
                        onChanged: (value) =>
                            setDialogState(() => isPeriodDay = value),
                        activeThumbColor: AppColors.deepPink,
                      ),
                    ],
                  ),
                  if (isPeriodDay) ...[
                    const SizedBox(height: 8),
                    const Text('Pain level (1-10)',
                        style: TextStyle(color: AppColors.textMed)),
                    Slider(
                      value: (painLevel ?? 5).toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      activeColor: AppColors.deepPink,
                      onChanged: (value) =>
                          setDialogState(() => painLevel = value.round()),
                      label: '${painLevel ?? 5}',
                    ),
                    DropdownButtonFormField<String>(
                      value: flow,
                      decoration: const InputDecoration(labelText: 'Flow'),
                      items: const [
                        DropdownMenuItem(value: 'light', child: Text('Light')),
                        DropdownMenuItem(
                            value: 'medium', child: Text('Medium')),
                        DropdownMenuItem(value: 'heavy', child: Text('Heavy')),
                      ],
                      onChanged: (value) => setDialogState(() => flow = value),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Text('Symptoms',
                      style: TextStyle(color: AppColors.textMed)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: symptomOptions
                        .map(
                          (symptom) => FilterChip(
                            selected: selectedSymptoms.contains(symptom),
                            label: Text(symptom),
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
                                  selectedSymptoms.add(symptom);
                                } else {
                                  selectedSymptoms.remove(symptom);
                                }
                              });
                            },
                            selectedColor: AppColors.softPink,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final now = DateTime.now();
                  await onLog(
                    MoodEntry(
                      id: _uuid.v4(),
                      mood: mood.$1,
                      emoji: mood.$2,
                      note: noteController.text.trim().isEmpty
                          ? null
                          : noteController.text.trim(),
                      date: now,
                      createdAt: now,
                      updatedAt: now,
                      isPeriodDay: isPeriodDay,
                      painLevel: painLevel,
                      symptoms: selectedSymptoms.toList(),
                      flow: flow,
                    ),
                  );
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                },
                child: const Text('Log Mood'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TodayMoodCard extends StatelessWidget {
  final MoodEntry entry;
  final VoidCallback onDelete;

  const _TodayMoodCard({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.lavender.withOpacity(0.2), blurRadius: 15)
        ],
      ),
      child: Row(
        children: [
          Text(_safeMoodSymbol(entry), style: const TextStyle(fontSize: 40)),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Today\'s mood',
                  style: TextStyle(color: AppColors.textLight, fontSize: 12)),
              Text(
                entry.mood,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark),
              ),
              if (entry.isPeriodDay)
                const Text('Period day',
                    style: TextStyle(color: AppColors.deepPink, fontSize: 12)),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.deepPink),
            tooltip: 'Delete mood entry',
          ),
        ],
      ),
    );
  }
}

class _MoodCalendar extends StatelessWidget {
  final DateTime focused;
  final DateTime? selected;
  final MoodProvider moodProvider;
  final ValueChanged<DateTime> onFocused;
  final ValueChanged<DateTime> onSelected;

  const _MoodCalendar({
    required this.focused,
    required this.selected,
    required this.moodProvider,
    required this.onFocused,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.lavender.withOpacity(0.15), blurRadius: 12)
        ],
      ),
      child: TableCalendar(
        firstDay: DateTime.now().subtract(const Duration(days: 365)),
        lastDay: DateTime.now().add(const Duration(days: 120)),
        focusedDay: focused,
        selectedDayPredicate: (day) =>
            selected != null && isSameDay(day, selected!),
        onDaySelected: (selectedDay, focusedDay) {
          onSelected(selectedDay);
          onFocused(focusedDay);
        },
        onPageChanged: onFocused,
        calendarStyle: const CalendarStyle(
          todayDecoration:
              BoxDecoration(color: AppColors.softPink, shape: BoxShape.circle),
          selectedDecoration:
              BoxDecoration(color: AppColors.deepPink, shape: BoxShape.circle),
          weekendTextStyle: TextStyle(color: AppColors.lavenderDeep),
          markerDecoration:
              BoxDecoration(color: AppColors.deepPink, shape: BoxShape.circle),
        ),
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
              fontSize: 16),
        ),
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, day, events) {
            final entry = moodProvider.getEntryForDate(day);
            if (entry == null) {
              return null;
            }
            return Positioned(
              bottom: 1,
              child: Text(
                _safeMoodSymbol(entry),
                style: const TextStyle(fontSize: 10),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DayDetail extends StatelessWidget {
  final MoodEntry entry;
  final VoidCallback onDelete;

  const _DayDetail({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppColors.lavenderLight,
          borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_safeMoodSymbol(entry), style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.mood,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                          fontSize: 16)),
                  Text(DateFormat('MMMM d, yyyy').format(entry.date),
                      style: const TextStyle(
                          color: AppColors.textMed, fontSize: 12)),
                  if (entry.isPeriodDay)
                    Text('Period - Pain: ${entry.painLevel ?? '-'} / 10',
                        style: const TextStyle(
                            color: AppColors.deepPink, fontSize: 12)),
                ],
              ),
              const Spacer(),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.deepPink),
                tooltip: 'Delete mood entry',
              ),
            ],
          ),
          if (entry.symptoms.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Symptoms', style: TextStyle(color: AppColors.textMed)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: entry.symptoms
                  .map(
                    (symptom) => Chip(
                      label: Text(symptom),
                      backgroundColor: AppColors.white,
                    ),
                  )
                  .toList(),
            ),
          ],
          if (entry.note != null && entry.note!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(entry.note!,
                style: const TextStyle(color: AppColors.textDark)),
          ],
        ],
      ),
    );
  }
}

class _CyclePredictionCard extends StatelessWidget {
  final CyclePrediction? prediction;

  const _CyclePredictionCard({required this.prediction});

  @override
  Widget build(BuildContext context) {
    if (prediction == null) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'Add period logs to unlock cycle prediction insights.',
          style: TextStyle(color: AppColors.textMed),
        ),
      );
    }

    final model = prediction!;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cycle prediction',
            style: TextStyle(
                fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
          const SizedBox(height: 8),
          Text(
            'Next period: ${DateFormat('MMM d').format(model.predictedNextPeriodStart)}',
            style: const TextStyle(color: AppColors.textDark),
          ),
          Text(
            'Fertile window: ${DateFormat('MMM d').format(model.fertileWindowStart)} - ${DateFormat('MMM d').format(model.fertileWindowEnd)}',
            style: const TextStyle(color: AppColors.textDark),
          ),
          Text(
            'Average cycle: ${model.averageCycleLengthDays} days',
            style: const TextStyle(color: AppColors.textMed),
          ),
          Text(
            'Confidence: ${(model.confidence * 100).round()}%',
            style: const TextStyle(color: AppColors.textMed),
          ),
        ],
      ),
    );
  }
}

class _WeeklySummary extends StatelessWidget {
  final MoodProvider moodProvider;

  const _WeeklySummary({required this.moodProvider});

  @override
  Widget build(BuildContext context) {
    final lastSevenDays = List.generate(
        7, (index) => DateTime.now().subtract(Duration(days: 6 - index)));
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Last 7 days',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: lastSevenDays.map((day) {
              final entry = moodProvider.getEntryForDate(day);
              final isToday = isSameDay(day, DateTime.now());
              return Column(
                children: [
                  Text(
                    DateFormat('E').format(day),
                    style: TextStyle(
                      fontSize: 11,
                      color: isToday ? AppColors.deepPink : AppColors.textLight,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isToday
                          ? AppColors.softPink.withOpacity(0.3)
                          : AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isToday ? AppColors.deepPink : AppColors.softPink,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                        child: Text(_safeMoodSymbol(entry),
                            style: const TextStyle(fontSize: 18))),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
