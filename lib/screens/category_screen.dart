import 'dart:math';

import 'package:flutter/material.dart';

import '../data/word_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/ui_kit.dart';

class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key});

  static String _emojiFor(String name) {
    final n = name.toLowerCase();
    const map = {
      'hayvan': '🐾',
      'meyve': '🍎',
      'sebze': '🥕',
      'ülke': '🌍',
      'şehir': '🏙️',
      'meslek': '👷',
      'renk': '🎨',
      'yemek': '🍽️',
      'yiyecek': '🍽️',
      'içecek': '🥤',
      'spor': '⚽',
      'müzik': '🎵',
      'bitki': '🌿',
      'vücut': '🫀',
      'araç': '🚗',
      'taşıt': '🚗',
      'doğa': '🌲',
      'bilim': '🔬',
      'giy': '👕',
      'eşya': '🧰',
      'mutfak': '🍳',
      'okul': '🎒',
      'ev': '🏠',
      'film': '🎬',
      'oyun': '🎮',
      'tarih': '🏛️',
    };
    for (final e in map.entries) {
      if (n.contains(e.key)) return e.value;
    }
    return '📚';
  }

  @override
  Widget build(BuildContext context) {
    final categories = WordRepository.categories.toList()..sort();
    final maxCount = categories.isEmpty
        ? 1
        : categories.map(WordRepository.countInCategory).reduce(max).clamp(1, 1 << 30);

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 20, 8),
                child: Row(
                  children: [
                    GlassIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.maybePop(context),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Kategoriler',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    InfoPill(
                      leading: const Text('📚', style: TextStyle(fontSize: 13)),
                      text: '${WordRepository.count} kelime',
                      color: AppColors.cyan,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.25,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, i) {
                    final cat = categories[i];
                    final count = WordRepository.countInCategory(cat);
                    final color = AppColors.palette[i % AppColors.palette.length];
                    return GlassCard(
                      glow: color,
                      borderColor: color.withOpacity(0.35),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(color: color.withOpacity(0.5)),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _emojiFor(cat),
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cat,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$count kelime',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              const SizedBox(height: 7),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: count / maxCount,
                                  minHeight: 5,
                                  backgroundColor: Colors.white.withOpacity(0.08),
                                  valueColor: AlwaysStoppedAnimation(color),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
