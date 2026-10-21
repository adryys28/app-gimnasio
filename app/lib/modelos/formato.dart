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

/// 2340 -> "2.340"
String formatearMiles(int valor) {
  final texto = valor.abs().toString();
  final grupos = <String>[];
  for (var i = texto.length; i > 0; i -= 3) {
    grupos.insert(0, texto.substring(i - 3 < 0 ? 0 : i - 3, i));
  }
  return '${valor < 0 ? '−' : ''}${grupos.join('.')}';
}

/// Segundos -> "48:12" o "1:05:30"
String formatearDuracion(int segundos) {
  final h = segundos ~/ 3600, m = (segundos % 3600) ~/ 60, s = segundos % 60;
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$ss' : '$m:$ss';
}

/// Volumen en kg: "850 kg" o "4,8 t"
String formatearVolumen(double kg) =>
    kg >= 1000 ? '${formatearNumero((kg / 100).round() / 10)} t' : '${formatearMiles(kg.round())} kg';

/// Diferencia con signo: "+1 kg", "−5 s"
String conSigno(double valor, String unidad) =>
    '${valor >= 0 ? '+' : '−'}${formatearNumero(valor.abs())}${unidad.isEmpty ? '' : ' $unidad'}';

/// "Pecho · también Tríceps y Hombros"
String textoMusculos(List<String> principales, List<String> secundarios) {
  if (principales.isEmpty) return '';
  final p = principales.join(', ');
  if (secundarios.isEmpty) return p;
  final s = secundarios.length == 1
      ? secundarios.first
      : '${secundarios.sublist(0, secundarios.length - 1).join(', ')} y ${secundarios.last}';
  return '$p · también $s';
}
