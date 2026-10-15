/// Número con coma decimal y sin ceros sobrantes: 17 -> "17", 2.5 -> "2,5".
String formatearNumero(double valor) {
  var texto = valor.toStringAsFixed(2);
  texto = texto.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  return texto.replaceAll('.', ',');
}

/// Rango "10–12", o un único valor si mínimo y máximo coinciden.
String rango(int? minimo, int? maximo) {
  if (minimo == null) return '';
  if (maximo == null || maximo == minimo) return '$minimo';
  return '$minimo–$maximo';
}

int? aEntero(dynamic valor) => (valor as num?)?.toInt();
double? aDecimal(dynamic valor) => (valor as num?)?.toDouble();
