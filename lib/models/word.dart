class Word {
  final String text;
  final String category;
  final String? hint;

  const Word({
    required this.text,
    required this.category,
    this.hint,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'category': category,
        if (hint != null) 'hint': hint,
      };
}
