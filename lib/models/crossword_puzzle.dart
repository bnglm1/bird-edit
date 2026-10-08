import 'dart:math';

class CrosswordCell {
  final int row;
  final int col;
  const CrosswordCell(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      other is CrosswordCell && other.row == row && other.col == col;

  @override
  int get hashCode => row * 10000 + col;
}

class CrosswordWord {
  final String text;
  final List<CrosswordCell> positions;
  bool found;

  CrosswordWord({
    required this.text,
    required this.positions,
    this.found = false,
  });
}

class CrosswordPuzzle {
  final int id;
  final String title;
  final int rows;
  final int cols;
  final Set<CrosswordCell> activeCells;
  final Map<CrosswordCell, String> solution;
  final List<CrosswordWord> words;
  final List<String> circle;

  CrosswordPuzzle({
    required this.id,
    required this.title,
    required this.rows,
    required this.cols,
    required this.activeCells,
    required this.solution,
    required this.words,
    required this.circle,
  });

  int get totalWords => words.length;
  int get foundWords => words.where((w) => w.found).length;
  bool get isComplete => words.isNotEmpty && words.every((w) => w.found);

  bool isActive(int r, int c) => activeCells.contains(CrosswordCell(r, c));

  bool isRevealed(int r, int c) {
    final cell = CrosswordCell(r, c);
    for (final w in words) {
      if (w.found && w.positions.contains(cell)) return true;
    }
    return false;
  }

  String? letterAt(int r, int c) => solution[CrosswordCell(r, c)];

  CrosswordPuzzle clone() {
    return CrosswordPuzzle(
      id: id,
      title: title,
      rows: rows,
      cols: cols,
      activeCells: activeCells,
      solution: solution,
      words: words
          .map((w) => CrosswordWord(
                text: w.text,
                positions: w.positions,
              ))
          .toList(),
      circle: circle,
    );
  }
}
