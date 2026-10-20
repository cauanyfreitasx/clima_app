import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const ClimaApp());

class ClimaApp extends StatelessWidget {
  const ClimaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clima',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: const TelaClima(),
    );
  }
}

// ---------------------------------------------------------------------------
// MODELOS
// ---------------------------------------------------------------------------

class DiaPrevisao {
  final DateTime data;
  final double minima;
  final double maxima;
  final int codigo;

  DiaPrevisao(this.data, this.minima, this.maxima, this.codigo);
}

class Previsao {
  final String cidade;
  final double temperatura;
  final double vento;
  final int umidade;
  final int codigo;
  final List<DiaPrevisao> dias;

  Previsao({
    required this.cidade,
    required this.temperatura,
    required this.vento,
    required this.umidade,
    required this.codigo,
    required this.dias,
  });
}

// ---------------------------------------------------------------------------
// SERVIÇO (consumo da API REST / JSON)
// ---------------------------------------------------------------------------

class ClimaService {
  Future<Previsao> buscar(String cidade) async {
    // 1) Geocodificação: nome da cidade -> latitude/longitude
    final geoUri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': cidade,
      'count': '1',
      'language': 'pt',
    });
    final geoResp = await http.get(geoUri).timeout(const Duration(seconds: 10));
    if (geoResp.statusCode != 200) {
      throw Exception('Erro ao buscar a cidade (${geoResp.statusCode}).');
    }
    final geo = jsonDecode(geoResp.body) as Map<String, dynamic>;
    final resultados = geo['results'] as List?;
    if (resultados == null || resultados.isEmpty) {
      throw Exception('Cidade não encontrada.');
    }
    final local = resultados.first as Map<String, dynamic>;
    final nome = local['name'] as String;
    final regiao = local['admin1'] as String?;

    // 2) Previsão do tempo para as coordenadas encontradas
    final climaUri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '${local['latitude']}',
      'longitude': '${local['longitude']}',
      'current': 'temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code',
      'daily': 'weather_code,temperature_2m_max,temperature_2m_min',
      'timezone': 'auto',
    });
    final climaResp =
        await http.get(climaUri).timeout(const Duration(seconds: 10));
    if (climaResp.statusCode != 200) {
      throw Exception('Erro ao buscar a previsão (${climaResp.statusCode}).');
    }
    final dados = jsonDecode(climaResp.body) as Map<String, dynamic>;
    final atual = dados['current'] as Map<String, dynamic>;
    final diario = dados['daily'] as Map<String, dynamic>;

    final datas = (diario['time'] as List).cast<String>();
    final maximas = diario['temperature_2m_max'] as List;
    final minimas = diario['temperature_2m_min'] as List;
    final codigos = diario['weather_code'] as List;

    final dias = <DiaPrevisao>[
      for (var i = 0; i < datas.length; i++)
        DiaPrevisao(
          DateTime.parse(datas[i]),
          (minimas[i] as num).toDouble(),
          (maximas[i] as num).toDouble(),
          (codigos[i] as num).toInt(),
        ),
    ];

    return Previsao(
      cidade: regiao != null ? '$nome, $regiao' : nome,
      temperatura: (atual['temperature_2m'] as num).toDouble(),
      vento: (atual['wind_speed_10m'] as num).toDouble(),
      umidade: (atual['relative_humidity_2m'] as num).toInt(),
      codigo: (atual['weather_code'] as num).toInt(),
      dias: dias,
    );
  }
}

// ---------------------------------------------------------------------------
// AUXILIARES: código WMO -> descrição e ícone
// ---------------------------------------------------------------------------

String descricaoClima(int codigo) {
  if (codigo == 0) return 'Céu limpo';
  if (codigo <= 3) return 'Parcialmente nublado';
  if (codigo == 45 || codigo == 48) return 'Neblina';
  if (codigo >= 51 && codigo <= 57) return 'Garoa';
  if (codigo >= 61 && codigo <= 67) return 'Chuva';
  if (codigo >= 71 && codigo <= 77) return 'Neve';
  if (codigo >= 80 && codigo <= 82) return 'Pancadas de chuva';
  if (codigo >= 95) return 'Tempestade';
  return 'Indefinido';
}

IconData iconeClima(int codigo) {
  if (codigo == 0) return Icons.wb_sunny;
  if (codigo <= 3) return Icons.wb_cloudy;
  if (codigo == 45 || codigo == 48) return Icons.foggy;
  if (codigo >= 51 && codigo <= 67) return Icons.grain;
  if (codigo >= 71 && codigo <= 77) return Icons.ac_unit;
  if (codigo >= 80 && codigo <= 82) return Icons.water_drop;
  if (codigo >= 95) return Icons.thunderstorm;
  return Icons.help_outline;
}

String nomeDiaSemana(DateTime d) {
  const nomes = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
  return nomes[d.weekday - 1];
}

// ---------------------------------------------------------------------------
// TELA (UI declarativa + estado)
// ---------------------------------------------------------------------------

class TelaClima extends StatefulWidget {
  const TelaClima({super.key});

  @override
  State<TelaClima> createState() => _TelaClimaState();
}

class _TelaClimaState extends State<TelaClima> {
  final _servico = ClimaService();
  final _controlador = TextEditingController();

  Previsao? _previsao;
  bool _carregando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregarUltimaCidade();
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  Future<void> _carregarUltimaCidade() async {
    const cidade = 'São Paulo';
    _controlador.text = cidade;
    await _buscar(cidade);
  }

  Future<void> _buscar(String cidade) async {
    if (cidade.trim().isEmpty) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final resultado = await _servico.buscar(cidade.trim());
      if (!mounted) return;
      setState(() => _previsao = resultado);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.toString().replaceFirst('Exception: ', '');
        _previsao = null;
      });
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clima')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controlador,
              textInputAction: TextInputAction.search,
              onSubmitted: _buscar,
              decoration: InputDecoration(
                labelText: 'Cidade',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _buscar(_controlador.text),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(child: _conteudo()),
          ],
        ),
      ),
    );
  }

  Widget _conteudo() {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erro != null) {
      return Center(
        child: Text(_erro!, textAlign: TextAlign.center),
      );
    }
    final p = _previsao;
    if (p == null) return const SizedBox.shrink();

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(p.cidade, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Icon(iconeClima(p.codigo), size: 64),
                Text(
                  '${p.temperatura.round()}°C',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                Text(descricaoClima(p.codigo)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text('Umidade: ${p.umidade}%'),
                    Text('Vento: ${p.vento.round()} km/h'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final d in p.dias)
          ListTile(
            leading: Icon(iconeClima(d.codigo)),
            title: Text('${nomeDiaSemana(d.data)}  ${d.data.day}/${d.data.month}'),
            subtitle: Text(descricaoClima(d.codigo)),
            trailing: Text('${d.minima.round()}° / ${d.maxima.round()}°'),
          ),
      ],
    );
  }
}
