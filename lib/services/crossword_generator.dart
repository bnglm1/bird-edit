import 'dart:math';

import '../models/crossword_puzzle.dart';

/// Kelime listesinden otomatik bulmaca üretir.
///
/// Algoritma (HTML versiyonundan uyarlanmıştır):
///  1. Kelimeleri uzunluklarına göre büyükten küçüğe sırala
///  2. İlk kelimeyi grid'in ortasına YATAY yerleştir
///  3. Sonraki her kelime için:
///     a. Yerleşik bir kelimeyle KESİŞECEK şekilde konum ara
///     b. Kesişim geçerliyse yerleştir (dikey veya yatay)
///     c. Kesişim yoksa grid'de herhangi bir boş yere koy
///  4. Kullanılmayan hücreleri temizle (null bırak)
///  5. Circle harflerini kelimelerden otomatik hesapla (max multiplicity)
class CrosswordGenerator {
  CrosswordGenerator._();

  static const int _defaultGridSize = 15;
  static const int _maxPlacementAttempts = 200;

  static CrosswordPuzzle? generate({
    required int id,
    required String title,
    required List<String> words,
    int gridSize = _defaultGridSize,
    Random? random,
  }) {
    if (words.isEmpty) return null;

    final rnd = random ?? Random();
    final grid = List.generate(
      gridSize,
      (_) => List<String?>.filled(gridSize, null),
    );

    final sorted = [...words]..sort((a, b) => b.length.compareTo(a.length));
    final placed = <_PlacedWord>[];

    // 1) İlk kelime — ortaya yatay
    final first = sorted[0];
    if (first.length > gridSize) return null;
    final startRow = gridSize ~/ 2;
    final startCol = (gridSize - first.length) ~/ 2;
    _placeWord(grid, first, startRow, startCol, 'H');
    placed.add(_PlacedWord(first, startRow, startCol, 'H'));

    // 2) Sonraki kelimeler
    for (int w = 1; w < sorted.length; w++) {
      final word = sorted[w];
      if (word.length > gridSize) continue;

      bool ok = false;

      // 2a) Kesişim ara
      final shuffledPlaced = [...placed]..shuffle(rnd);
      for (final existing in shuffledPlaced) {
        if (ok) break;
        for (int i = 0; i < word.length && !ok; i++) {
          for (int j = 0; j < existing.word.length && !ok; j++) {
            if (word[i] != existing.word[j]) continue;

            // Kesişim noktası
            final int interRow;
            final int interCol;
            if (existing.dir == 'H') {
              interRow = existing.row;
              interCol = existing.col + j;
            } else {
              interRow = existing.row + j;
              interCol = existing.col;
            }

            final newDir = existing.dir == 'H' ? 'V' : 'H';
            final int newRow;
            final int newCol;
            if (newDir == 'V') {
              newRow = interRow - i;
              newCol = interCol;
            } else {
              newRow = interRow;
              newCol = interCol - i;
            }

            if (_canPlace(grid, word, newRow, newCol, newDir)) {
              _placeWord(grid, word, newRow, newCol, newDir);
              placed.add(_PlacedWord(word, newRow, newCol, newDir));
              ok = true;
            }
          }
        }
      }

      // 2b) Kesişim yoksa rastgele dene
      if (!ok) {
        for (int attempt = 0;
            attempt < _maxPlacementAttempts && !ok;
            attempt++) {
          final dir = rnd.nextBool() ? 'H' : 'V';
          final r = rnd.nextInt(gridSize);
          final c = rnd.nextInt(gridSize);
          if (_canPlace(grid, word, r, c, dir)) {
            _placeWord(grid, word, r, c, dir);
            placed.add(_PlacedWord(word, r, c, dir));
            ok = true;
          }
        }
      }
    }

    if (placed.isEmpty) return null;

    // 3) Kenar boşluklarını kırp
    int minR = gridSize, maxR = -1, minC = gridSize, maxC = -1;
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (grid[r][c] != null) {
          if (r < minR) minR = r;
          if (r > maxR) maxR = r;
          if (c < minC) minC = c;
          if (c > maxC) maxC = c;
        }
      }
    }

    final rows = maxR - minR + 1;
    final cols = maxC - minC + 1;

    final activeCells = <CrosswordCell>{};
    final solution = <CrosswordCell, String>{};

    for (int r = minR; r <= maxR; r++) {
      for (int c = minC; c <= maxC; c++) {
        final ch = grid[r][c];
        if (ch != null) {
          final cell = CrosswordCell(r - minR, c - minC);
          activeCells.add(cell);
          solution[cell] = ch;
        }
      }
    }

    // 4) CrosswordWord'leri oluştur
    final puzzleWords = <CrosswordWord>[];
    for (final p in placed) {
      final positions = <CrosswordCell>[];
      for (int i = 0; i < p.word.length; i++) {
        if (p.dir == 'H') {
          positions.add(CrosswordCell(p.row - minR, p.col + i - minC));
        } else {
          positions.add(CrosswordCell(p.row + i - minR, p.col - minC));
        }
      }
      puzzleWords.add(
        CrosswordWord(text: p.word, positions: positions),
      );
    }

    // 5) Circle harfleri — her harfin maksimum gereksinim sayısı
    final required = <String, int>{};
    for (final w in words) {
      final counts = <String, int>{};
      for (final ch in w.split('')) {
        counts[ch] = (counts[ch] ?? 0) + 1;
      }
      counts.forEach((ch, cnt) {
        if (cnt > (required[ch] ?? 0)) required[ch] = cnt;
      });
    }

    final circle = <String>[];
    required.forEach((ch, cnt) {
      for (int i = 0; i < cnt; i++) {
        circle.add(ch);
      }
    });

    // Challenge için 2 ekstra harf ekle
    const extras = 'AEİLRSK';
    for (int i = 0; i < 2; i++) {
      circle.add(extras[rnd.nextInt(extras.length)]);
    }

    // Harfleri karıştır (sabit pozisyonlarda aynı görünmesin)
    circle.shuffle(rnd);

    return CrosswordPuzzle(
      id: id,
      title: title,
      rows: rows,
      cols: cols,
      activeCells: activeCells,
      solution: solution,
      words: puzzleWords,
      circle: circle,
    );
  }

  static bool _canPlace(
    List<List<String?>> grid,
    String word,
    int row,
    int col,
    String dir,
  ) {
    final n = grid.length;
    final len = word.length;

    if (dir == 'H') {
      if (row < 0 || row >= n) return false;
      if (col < 0 || col + len > n) return false;
      if (col > 0 && grid[row][col - 1] != null) return false;
      if (col + len < n && grid[row][col + len] != null) return false;

      for (int i = 0; i < len; i++) {
        final c = grid[row][col + i];
        if (c != null && c != word[i]) return false;
        if (c == null) {
          if (row > 0 && grid[row - 1][col + i] != null) return false;
          if (row < n - 1 && grid[row + 1][col + i] != null) return false;
        }
      }
    } else {
      if (col < 0 || col >= n) return false;
      if (row < 0 || row + len > n) return false;
      if (row > 0 && grid[row - 1][col] != null) return false;
      if (row + len < n && grid[row + len][col] != null) return false;

      for (int i = 0; i < len; i++) {
        final c = grid[row + i][col];
        if (c != null && c != word[i]) return false;
        if (c == null) {
          if (col > 0 && grid[row + i][col - 1] != null) return false;
          if (col < n - 1 && grid[row + i][col + 1] != null) return false;
        }
      }
    }
    return true;
  }

  static void _placeWord(
    List<List<String?>> grid,
    String word,
    int row,
    int col,
    String dir,
  ) {
    for (int i = 0; i < word.length; i++) {
      if (dir == 'H') {
        grid[row][col + i] = word[i];
      } else {
        grid[row + i][col] = word[i];
      }
    }
  }
}

class _PlacedWord {
  final String word;
  final int row;
  final int col;
  final String dir; // 'H' | 'V'
  _PlacedWord(this.word, this.row, this.col, this.dir);
}
