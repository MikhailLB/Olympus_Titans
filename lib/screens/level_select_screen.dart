import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/levels.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  Set<int> _completed = {};

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('completed_levels') ?? [];
    if (mounted) {
      setState(() => _completed = list.map(int.parse).toSet());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050E1A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0D1B2A), Color(0xFF050E1A)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // App bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      _BackButton(onTap: () => Navigator.pop(context)),
                      const Spacer(),
                      const Text(
                        'SELECT LEVEL',
                        style: TextStyle(
                          color: Color(0xFFC9A84C),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 44),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFF1E3A5F), height: 1),
                const SizedBox(height: 16),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 1,
                      ),
                      itemCount: kLevels.length,
                      itemBuilder: (ctx, i) {
                        final levelNum = i + 1;
                        final isCompleted = _completed.contains(levelNum);
                        final isUnlocked = levelNum == 1 ||
                            _completed.contains(levelNum - 1) ||
                            _completed.contains(levelNum); // also unlock if already done

                        return _LevelCard(
                          levelNum: levelNum,
                          title: kLevels[i].title,
                          isCompleted: isCompleted,
                          isUnlocked: isUnlocked,
                          gridSize: kLevels[i].gridSize,
                          onTap: isUnlocked
                              ? () => Navigator.pushNamed(
                                    context,
                                    '/game',
                                    arguments: i,
                                  ).then((_) => _loadProgress())
                              : null,
                        );
                      },
                    ),
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

class _LevelCard extends StatelessWidget {
  final int levelNum;
  final String title;
  final bool isCompleted;
  final bool isUnlocked;
  final int gridSize;
  final VoidCallback? onTap;

  const _LevelCard({
    required this.levelNum,
    required this.title,
    required this.isCompleted,
    required this.isUnlocked,
    required this.gridSize,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isCompleted
        ? const Color(0xFFC9A84C)
        : isUnlocked
            ? const Color(0xFF4FC3F7).withValues(alpha: 0.7)
            : const Color(0xFF1E3A5F);

    final textColor = isCompleted
        ? const Color(0xFFC9A84C)
        : isUnlocked
            ? Colors.white
            : Colors.white38;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isCompleted
                ? [const Color(0xFF1A1500), const Color(0xFF0D0A00)]
                : isUnlocked
                    ? [const Color(0xFF0D1B2A), const Color(0xFF050E1A)]
                    : [const Color(0xFF080D14), const Color(0xFF050810)],
          ),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: isCompleted
              ? [
                  BoxShadow(
                    color: const Color(0xFFC9A84C).withValues(alpha: 0.3),
                    blurRadius: 10,
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isCompleted)
              const Icon(Icons.star_rounded, color: Color(0xFFC9A84C), size: 22)
            else if (!isUnlocked)
              const Icon(Icons.lock_outline_rounded, color: Colors.white24, size: 22)
            else
              Text(
                '$levelNum',
                style: TextStyle(
                  color: textColor,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              isCompleted ? '$levelNum' : isUnlocked ? '$gridSize×$gridSize' : '',
              style: TextStyle(
                color: textColor.withValues(alpha: 0.7),
                fontSize: 11,
                letterSpacing: 1,
              ),
            ),
            if (isUnlocked || isCompleted)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  title,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.55),
                    fontSize: 8,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF1E3A5F),
            width: 1.5,
          ),
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF4FC3F7), size: 18),
      ),
    );
  }
}
