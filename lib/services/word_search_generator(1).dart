import 'dart:math';
import '../models/word.dart';

class WordPosition {
  final int row;
  final int col;
  const WordPosition(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      other is WordPosition && other.row == row && other.col == col;

  @override
  int get hashCode => row * 10000 + col;
}

class PlacedWord {
  final String text;
  List<WordPosition> positions;
  bool found;

  PlacedWord({
    required this.text,
    required this.positions,
    this.found = false,
  });
}

class WordSearchPuzzle {
  final int size;
  final List<List<String>> grid;
  final List<PlacedWord> words;

  WordSearchPuzzle({
    required this.size,
    required this.grid,
    required this.words,
  });

  int get totalWords => words.length;
  int get foundWords => words.where((w) => w.found).length;
  bool get isComplete => words.isNotEmpty && words.every((w) => w.found);
}

class WordSearchGenerator {
  static const String _alphabet = 'ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ';

  /// Kaç kez yeniden üretim denenecek (tüm kelimeler yerleşene kadar).
  static const int _maxAttempts = 8;

  /// `directions` parametresi hangi yönlerin kullanılacağını belirler.
  /// Örn: [[0,1],[1,0]] → sadece sağ ve aşağı.
  ///
  /// Tüm kelimeler yerleşene kadar birden fazla kez dener.
  /// Hâlâ başarısız olursa en çok kelime yerleştiren denemeyi döndürür.
  static WordSearchPuzzle generate({
    required List<Word> words,
    required int gridSize,
    required List<List<int>> directions,
    Random? random,
  }) {
    if (words.isEmpty) {
      return WordSearchPuzzle(
        size: gridSize,
        grid: List.generate(
          gridSize,
          (_) => List<String>.filled(gridSize, ''),
        ),
        words: const [],
      );
    }

    final rnd = random ?? Random();
    WordSearchPuzzle? best;

    for (int attempt = 0; attempt < _maxAttempts; attempt++) {
      final result = _attemptGenerate(
        words: words,
        gridSize: gridSize,
        directions: directions,
        rnd: rnd,
      );

      // Tüm kelimeler yerleştiyse direkt dön
      if (result.words.length == words.length) return result;

      // En iyi (en çok kelime yerleştiren) denemeyi sakla
      if (best == null || result.words.length > best.words.length) {
        best = result;
      }
    }

    return best!;
  }

  static WordSearchPuzzle _attemptGenerate({
    required List<Word> words,
    required int gridSize,
    required List<List<int>> directions,
    required Random rnd,
  }) {
    final grid = List.generate(
      gridSize,
      (_) => List<String>.filled(gridSize, ''),
    );
    final placed = <PlacedWord>[];

    // Uzun kelimeleri önce yerleştir
    final sorted = [...words]
      ..sort((a, b) => b.text.length.compareTo(a.text.length));

    for (final word in sorted) {
      final positions = _tryPlace(grid, word.text, directions, rnd);
      if (positions != null) {
        for (int i = 0; i < word.text.length; i++) {
          grid[positions[i].row][positions[i].col] = word.text[i];
        }
        placed.add(PlacedWord(text: word.text, positions: positions));
      }
    }

    // Boş kalan hücreleri rastgele harflerle doldur
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (grid[r][c].isEmpty) {
          grid[r][c] = _alphabet[rnd.nextInt(_alphabet.length)];
        }
      }
    }

    return WordSearchPuzzle(
      size: gridSize,
      grid: grid,
      words: placed,
    );
  }

  static List<WordPosition>? _tryPlace(
    List<List<String>> grid,
    String word,
    List<List<int>> directions,
    Random rnd,
  ) {
    final n = grid.length;
    if (word.length > n) return null;
    if (directions.isEmpty) return null;

    for (int attempt = 0; attempt < 300; attempt++) {
      final dir = directions[rnd.nextInt(directions.length)];
      final startRow = rnd.nextInt(n);
      final startCol = rnd.nextInt(n);

      final endRow = startRow + dir[0] * (word.length - 1);
      final endCol = startCol + dir[1] * (word.length - 1);
      if (endRow < 0 || endRow >= n || endCol < 0 || endCol >= n) {
        continue;
      }

      final positions = <WordPosition>[];
      bool ok = true;
      for (int i = 0; i < word.length; i++) {
        final r = startRow + dir[0] * i;
        final c = startCol + dir[1] * i;
        final existing = grid[r][c];
        if (existing.isNotEmpty && existing != word[i]) {
          ok = false;
          break;
        }
        positions.add(WordPosition(r, c));
      }
      if (ok) return positions;
    }
    return null;
  }
}
