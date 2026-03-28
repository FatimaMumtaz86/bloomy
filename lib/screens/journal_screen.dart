import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/search_utils.dart';

const _uuid = Uuid();

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      final userId = context.read<AuthProvider>().user?.id;
      if (userId != null && userId.isNotEmpty) {
        await context.read<JournalProvider>().init(userId);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final journal = context.watch<JournalProvider>();
    final auth = context.watch<AuthProvider>();
    final searchTerms = searchTokens(_searchQuery);
    final filteredEntries = searchTerms.isEmpty
        ? journal.entries
        : journal.entries.where((entry) {
            return matchesAnySearchField(
              fields: <String>[
                entry.title,
                entry.content,
                entry.tags.join(' ')
              ],
              tokens: searchTerms,
            );
          }).toList();

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        title: const Text(
          'My Journal',
          style:
              TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: Icon(
              journal.biometricLockEnabled
                  ? (journal.isLocked
                      ? Icons.lock_outline_rounded
                      : Icons.lock_open_rounded)
                  : Icons.fingerprint_rounded,
              color: AppColors.textDark,
            ),
            onPressed: auth.user == null
                ? null
                : () => _toggleJournalLock(context, journal),
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded, color: AppColors.textDark),
            onPressed: _showSearchDialog,
          ),
          if (_searchQuery.trim().isNotEmpty)
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: AppColors.textDark),
              onPressed: () => setState(() => _searchQuery = ''),
            ),
        ],
      ),
      body: journal.isLocked
          ? _LockedJournal(onUnlock: () => journal.unlockWithBiometric())
          : journal.entries.isEmpty
              ? _EmptyJournal(
                  onAdd: () => _showAddEntry(context),
                  streak: journal.currentStreak,
                )
              : Column(
                  children: [
                    _JournalInsights(streak: journal.currentStreak),
                    Expanded(
                      child: filteredEntries.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.search_off_rounded,
                                      size: 46, color: AppColors.textLight),
                                  const SizedBox(height: 10),
                                  const Text('No journal entries found'),
                                  const SizedBox(height: 10),
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        setState(() => _searchQuery = ''),
                                    icon: const Icon(Icons.arrow_back_rounded),
                                    label: const Text('Back to all entries'),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredEntries.length,
                              itemBuilder: (_, index) =>
                                  _JournalCard(entry: filteredEntries[index]),
                            ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'journal_fab',
        onPressed: () => _showAddEntry(context),
        backgroundColor: AppColors.deepPink,
        icon: const Icon(Icons.edit_rounded, color: Colors.white),
        label: const Text(
          'Write',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Future<void> _toggleJournalLock(
    BuildContext context,
    JournalProvider journal,
  ) async {
    final shouldEnable = !journal.biometricLockEnabled;
    bool updated = false;
    try {
      updated = await journal.setBiometricLockEnabled(shouldEnable);
    } catch (_) {
      updated = false;
    }
    if (!context.mounted) {
      return;
    }

    if (!updated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Biometric/device authentication is unavailable. Please enable phone lock and try again.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          shouldEnable
              ? 'Journal biometric lock enabled.'
              : 'Journal biometric lock disabled.',
        ),
      ),
    );
  }

  void _showAddEntry(BuildContext context) {
    final journal = context.read<JournalProvider>();
    if (journal.isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unlock your journal before writing.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _WriteEntryScreen()),
    );
  }

  void _showSearchDialog() {
    _searchController.text = _searchQuery;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Search journal'),
        content: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search by title or content...',
            prefixIcon: Icon(Icons.search_rounded),
          ),
          onSubmitted: (_) {
            setState(() => _searchQuery = _searchController.text);
            Navigator.pop(dialogContext);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _searchQuery = _searchController.text);
              Navigator.pop(dialogContext);
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }
}

class _LockedJournal extends StatelessWidget {
  final Future<bool> Function() onUnlock;

  const _LockedJournal({required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_rounded, size: 56, color: AppColors.deepPink),
            const SizedBox(height: 12),
            Text(
              'Journal is locked',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Authenticate with biometrics to open your private entries.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMed),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                final unlocked = await onUnlock();
                if (!context.mounted || unlocked) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Unable to unlock journal.')),
                );
              },
              icon: const Icon(Icons.fingerprint_rounded),
              label: const Text('Unlock Journal'),
            ),
          ],
        ),
      ),
    );
  }
}

class _JournalInsights extends StatelessWidget {
  final int streak;

  const _JournalInsights({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department_rounded,
              color: AppColors.deepPink),
          const SizedBox(width: 8),
          Text(
            'Current streak: $streak day${streak == 1 ? '' : 's'}',
            style: const TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyJournal extends StatelessWidget {
  final VoidCallback onAdd;
  final int streak;

  const _EmptyJournal({required this.onAdd, required this.streak});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.menu_book_rounded,
              size: 64, color: AppColors.deepPink),
          const SizedBox(height: 16),
          Text('Your journal is empty',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Start writing your story',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'Streak: $streak day${streak == 1 ? '' : 's'}',
            style: const TextStyle(color: AppColors.textMed),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
              onPressed: onAdd, child: const Text('Write first entry')),
        ],
      ),
    );
  }
}

class _JournalCard extends StatelessWidget {
  final JournalEntry entry;
  const _JournalCard({required this.entry});

  static const _moodEmojis = {
    'happy': 'H',
    'sad': 'S',
    'calm': 'C',
    'anxious': 'X',
    'angry': 'A',
    'tired': 'T',
    'grateful': 'G',
    'excited': 'E',
  };

  Future<void> _confirmDeleteEntry(BuildContext context) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete journal entry?'),
        content: const Text('This entry will be removed permanently.'),
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
      await context.read<JournalProvider>().deleteEntry(entry.id);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Journal entry deleted.')),
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete entry: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final emoji = _moodEmojis[entry.mood] ?? '·';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.lavender.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.lavenderLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child:
              Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
        ),
        title: Text(
          entry.title,
          style: const TextStyle(
              fontWeight: FontWeight.w700, color: AppColors.textDark),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              entry.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textMed),
            ),
            const SizedBox(height: 6),
            Text(
              DateFormat('MMM d, yyyy').format(entry.date),
              style: const TextStyle(fontSize: 11, color: AppColors.textLight),
            ),
          ],
        ),
        trailing: IconButton(
          onPressed: () => _confirmDeleteEntry(context),
          icon: const Icon(Icons.delete_outline_rounded,
              color: AppColors.deepPink),
          tooltip: 'Delete entry',
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => _EntryDetailScreen(entry: entry)),
        ),
      ),
    );
  }
}

class _WriteEntryScreen extends StatefulWidget {
  const _WriteEntryScreen();

  @override
  State<_WriteEntryScreen> createState() => _WriteEntryScreenState();
}

class _WriteEntryScreenState extends State<_WriteEntryScreen> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  String _mood = 'calm';
  bool _isPrivate = true;

  final _moods = const [
    ('happy', 'H'),
    ('sad', 'S'),
    ('calm', 'C'),
    ('anxious', 'X'),
    ('angry', 'A'),
    ('tired', 'T'),
    ('grateful', 'G'),
    ('excited', 'E'),
  ];

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty || _contentCtrl.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Title and content are required.')),
        );
      }
      return;
    }

    try {
      final now = DateTime.now();
      await context.read<JournalProvider>().addEntry(
            JournalEntry(
              id: _uuid.v4(),
              title: _titleCtrl.text.trim(),
              content: _contentCtrl.text.trim(),
              mood: _mood,
              date: now,
              createdAt: now,
              updatedAt: now,
              isPrivate: _isPrivate,
            ),
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save journal entry: $e')),
        );
      }
      return;
    }

    if (!mounted) {
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        title: const Text(
          'New Entry',
          style:
              TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              'Save',
              style: TextStyle(
                  color: AppColors.deepPink,
                  fontWeight: FontWeight.w700,
                  fontSize: 16),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How are you feeling?',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 60,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _moods.map((mood) {
                  final selected = _mood == mood.$1;
                  return GestureDetector(
                    onTap: () => setState(() => _mood = mood.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.deepPink : AppColors.white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: selected
                              ? AppColors.deepPink
                              : AppColors.softPink,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(mood.$2, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 6),
                          Text(
                            mood.$1,
                            style: TextStyle(
                              color: selected
                                  ? AppColors.white
                                  : AppColors.textMed,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              value: _isPrivate,
              onChanged: (value) => setState(() => _isPrivate = value),
              title: const Text('Keep this entry private'),
              activeColor: AppColors.deepPink,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleCtrl,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark),
              decoration: const InputDecoration(
                hintText: 'Title your day',
                border: InputBorder.none,
              ),
            ),
            const Divider(color: AppColors.softPink),
            const SizedBox(height: 8),
            TextField(
              controller: _contentCtrl,
              maxLines: null,
              minLines: 12,
              style: const TextStyle(
                  fontSize: 16, color: AppColors.textDark, height: 1.6),
              decoration: const InputDecoration(
                hintText: 'Write freely here',
                border: InputBorder.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryDetailScreen extends StatelessWidget {
  final JournalEntry entry;
  const _EntryDetailScreen({required this.entry});

  static const _moodEmojis = {
    'happy': 'H',
    'sad': 'S',
    'calm': 'C',
    'anxious': 'X',
    'angry': 'A',
    'tired': 'T',
    'grateful': 'G',
    'excited': 'E',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        leading: const BackButton(color: AppColors.textDark),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.deepPink),
            onPressed: () async {
              await context.read<JournalProvider>().deleteEntry(entry.id);
              if (!context.mounted) {
                return;
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(_moodEmojis[entry.mood] ?? '·',
                    style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Text(
                  DateFormat('MMMM d, yyyy').format(entry.date),
                  style: const TextStyle(
                      color: AppColors.textLight, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(entry.title, style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 24),
            Text(
              entry.content,
              style: const TextStyle(
                  fontSize: 16, color: AppColors.textDark, height: 1.8),
            ),
          ],
        ),
      ),
    );
  }
}
