import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/levels.dart';
import '../widgets/game_board.dart';

class GameScreen extends StatefulWidget {
  final int levelIndex;
  const GameScreen({super.key, required this.levelIndex});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late int _currentIndex;
  bool _showWin = false;

  // Incremented only when we want to actually RESET the board
  // (restart or move to next level). NOT changed when win overlay appears.
  int _resetKey = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.levelIndex;
  }

  Future<void> _onWin() async {
    final levelNum = _currentIndex + 1;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('completed_levels') ?? [];
    if (!list.contains('$levelNum')) {
      list.add('$levelNum');
      await prefs.setStringList('completed_levels', list);
    }
    if (mounted) setState(() => _showWin = true);
    // NOTE: _resetKey is NOT incremented here → board stays intact under overlay
  }

  void _nextLevel() {
    if (_currentIndex + 1 < kLevels.length) {
      setState(() {
        _currentIndex++;
        _showWin = false;
        _resetKey++;  // new level → rebuild board
      });
    } else {
      Navigator.popUntil(context, ModalRoute.withName('/menu'));
    }
  }

  void _restart() {
    setState(() {
      _showWin = false;
      _resetKey++;  // force full board reset
    });
  }

  @override
  Widget build(BuildContext context) {
    final level = kLevels[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF050E1A),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  levelNum: _currentIndex + 1,
                  title: level.title,
                  onBack: () => Navigator.pop(context),
                  onRestart: _restart,
                ),
                const SizedBox(height: 8),
                Text(
                  '${level.gridSize} × ${level.gridSize}  •  ${level.pairs.length} RUNES',
                  style: const TextStyle(
                    color: Color(0xFF4FC3F7),
                    fontSize: 11,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: GameBoard(
                          // Key changes ONLY on actual reset, not on win-overlay show
                          key: ValueKey('$_currentIndex-$_resetKey'),
                          level: level,
                          onWin: _onWin,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _RuneLegend(level: level),
                const SizedBox(height: 20),
              ],
            ),
          ),
          if (_showWin)
            _WinOverlay(
              levelNum: _currentIndex + 1,
              title: level.title,
              isLastLevel: _currentIndex + 1 >= kLevels.length,
              onNext: _nextLevel,
              onRetry: _restart,
              onMenu: () =>
                  Navigator.popUntil(context, ModalRoute.withName('/menu')),
            ),
        ],
      ),
    );
  }
}

// ─── Top Bar ────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final int levelNum;
  final String title;
  final VoidCallback onBack;
  final VoidCallback onRestart;

  const _TopBar({
    required this.levelNum,
    required this.title,
    required this.onBack,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _IconBtn(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
          const Spacer(),
          Column(
            children: [
              Text(
                'LEVEL $levelNum',
                style: const TextStyle(
                  color: Color(0xFFC9A84C),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                ),
              ),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          _IconBtn(icon: Icons.refresh_rounded, onTap: onRestart),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF1E3A5F), width: 1.5),
        ),
        child: Icon(icon, color: const Color(0xFF4FC3F7), size: 18),
      ),
    );
  }
}

// ─── Rune Legend ────────────────────────────────────────────────────────────

class _RuneLegend extends StatelessWidget {
  final dynamic level;
  const _RuneLegend({required this.level});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: level.pairs.map<Widget>((pair) {
          final color = kRuneColors[pair.colorIndex] ?? Colors.white;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.2),
                border: Border.all(color: color, width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Image.asset(runeAsset(pair.colorIndex), fit: BoxFit.contain),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Win Overlay ────────────────────────────────────────────────────────────

class _WinOverlay extends StatelessWidget {
  final int levelNum;
  final String title;
  final bool isLastLevel;
  final VoidCallback onNext;
  final VoidCallback onRetry;
  final VoidCallback onMenu;

  const _WinOverlay({
    required this.levelNum,
    required this.title,
    required this.isLastLevel,
    required this.onNext,
    required this.onRetry,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.88),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0D1B2A), Color(0xFF050E1A)],
            ),
            border: Border.all(
              color: const Color(0xFFC9A84C).withValues(alpha: 0.7),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFC9A84C).withValues(alpha: 0.25),
                blurRadius: 30,
                spreadRadius: 4,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded, color: Color(0xFFC9A84C), size: 56),
              const SizedBox(height: 12),
              const Text(
                'OLYMPUS REACHED',
                style: TextStyle(
                  color: Color(0xFFC9A84C),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Level $levelNum • $title',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 24),
              if (!isLastLevel) ...[
                _WinBtn(
                  label: 'NEXT LEVEL',
                  icon: Icons.arrow_forward_rounded,
                  color: const Color(0xFFC9A84C),
                  onTap: onNext,
                ),
                const SizedBox(height: 10),
              ],
              _WinBtn(
                label: 'RETRY',
                icon: Icons.refresh_rounded,
                color: const Color(0xFF66BB6A),
                onTap: onRetry,
              ),
              const SizedBox(height: 10),
              _WinBtn(
                label: isLastLevel ? 'BACK TO MENU' : 'MENU',
                icon: Icons.home_rounded,
                color: const Color(0xFF4FC3F7),
                onTap: onMenu,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WinBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _WinBtn({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.07)],
          ),
          border: Border.all(color: color.withValues(alpha: 0.7), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
