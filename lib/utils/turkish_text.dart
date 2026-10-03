/// Türkçe'ye uygun büyük harfe çevirme.
/// Dart'ın `toUpperCase()` metodu 'i' → 'I' yapar (doğrusu 'İ'),
/// bu da "kelime" gibi kelimelerin yanlış harfli oluşmasına yol açar.
String turkishUpper(String s) =>
    s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
