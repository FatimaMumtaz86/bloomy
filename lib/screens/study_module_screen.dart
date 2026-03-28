import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class StudyModuleScreen extends StatelessWidget {
  const StudyModuleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        title: const Text(
          'Study Hub',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SoonCard(
            icon: Icons.menu_book_rounded,
            title: 'Study Hub Will Bloom Soon',
            subtitle:
                'Share notes, solve questions, and help each other with clear explanations. This module will bloom soon.',
          ),
          const SizedBox(height: 14),
          _SoonCard(
            icon: Icons.auto_awesome_rounded,
            title: 'Lily AI Assistant Will Bloom Soon',
            subtitle:
                'Your Lily AI assistant will bloom soon to guide study plans and resolve learning queries.',
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.lavenderLight),
            ),
            child: const Text(
              'MVP note: Placeholder module is active. Full Study + Lily feature implementation comes next phase.',
              style: TextStyle(color: AppColors.textMed),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoonCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SoonCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.lavender.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.lavenderLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.deepPink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textMed,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
