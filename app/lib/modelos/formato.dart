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

final _zonaHoraria = RegExp(r'(Z|[+-]\d{2}:\d{2})$');

/// La API devuelve fechas UTC sin indicador de zona: se interpretan como UTC y se pasan a hora local.
DateTime? aFechaLocal(dynamic valor) {
  if (valor is! String || valor.isEmpty) return null;
  final texto = _zonaHoraria.hasMatch(valor) ? valor : '${valor}Z';
  return DateTime.tryParse(texto)?.toLocal();
}

String _dos(int n) => n.toString().padLeft(2, '0');

String formatearFecha(DateTime f) => '${_dos(f.day)}/${_dos(f.month)}/${f.year}';

String formatearFechaHora(DateTime f) => '${formatearFecha(f)} ${_dos(f.hour)}:${_dos(f.minute)}';

/// 2277 -> "2,28 km"; 850 -> "850 m"
String formatearDistancia(double metros) =>
    metros >= 1000 ? '${formatearNumero((metros / 1000 * 100).round() / 100)} km' : '${metros.round()} m';
