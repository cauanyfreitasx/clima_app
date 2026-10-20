import 'package:flutter_test/flutter_test.dart';
import 'package:clima_app/main.dart';

void main() {
  test('descricaoClima converte códigos WMO', () {
    expect(descricaoClima(0), 'Céu limpo');
    expect(descricaoClima(61), 'Chuva');
    expect(descricaoClima(95), 'Tempestade');
  });

  test('nomeDiaSemana devolve a abreviação correta', () {
    expect(nomeDiaSemana(DateTime(2026, 10, 19)), 'Seg');
  });
}
