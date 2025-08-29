import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // kIsWeb
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'dart:async';
import 'PF.dart';





void main() {
  runApp(const MiFinanzasApp());
}

class MiFinanzasApp extends StatelessWidget {
  const MiFinanzasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi Finanzas',
      theme: ThemeData(primarySwatch: Colors.green),
      builder: (context, child) {
        return ScaffoldMessenger(child: child!); // 👈 Esto asegura que funcione bien en web
      },
      home: const PaginaInicial(),

    );
  }
}




class PreguntarSaldoPage extends StatefulWidget {
  const PreguntarSaldoPage({super.key});

  @override
  State<PreguntarSaldoPage> createState() => _PreguntarSaldoPageState();
}

class _PreguntarSaldoPageState extends State<PreguntarSaldoPage> {
  final TextEditingController _controller = TextEditingController();

  void _continuar() {
  final texto = _controller.text;
  final saldo = double.tryParse(texto);
  if (saldo != null && saldo >= 0) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DesgloseInicialPage(saldo: saldo), // Pasas saldo a la siguiente pantalla
      ),
    );
  }
}


 @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Saldo mensual'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const PaginaInicial()),
          );
        },
      ),
    ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('¿Saldo mensual?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Introduce el importe en €',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _continuar(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _continuar, child: const Text('Continuar')),
            ],
          ),
        ),
      ),
    );
  }
}

class DesgloseInicialPage extends StatefulWidget {
  final double saldo;
  const DesgloseInicialPage({super.key, required this.saldo});

  @override
  State<DesgloseInicialPage> createState() => _DesgloseInicialPageState();
}

class _DesgloseInicialPageState extends State<DesgloseInicialPage> {
  late double gastosPersonales;
  late double invertir;
  late double liquidezEmergencia;
  late double ahorroSimple;

  @override
  void initState() {
    super.initState();
    gastosPersonales = widget.saldo * 0.40;
    invertir = widget.saldo * 0.30;
    liquidezEmergencia = widget.saldo * 0.20;
    ahorroSimple = widget.saldo * 0.10;
  }

  void actualizarGastosPersonales(double nuevoValor) {
    setState(() {
      final saldoRestante = widget.saldo - nuevoValor;
      gastosPersonales = nuevoValor;

      const invertirProp = 0.5; // 30/60
      const liquidezProp = 0.3333; // 20/60
      const ahorroProp = 0.1667; // 10/60

      invertir = saldoRestante * invertirProp;
      liquidezEmergencia = saldoRestante * liquidezProp;
      ahorroSimple = saldoRestante * ahorroProp;
    });
  }

  Future<void> _mostrarDialogoFase(BuildContext context) async {
    final Map<String, String> consejosFases = {
      'Fase de acumulación': 'Comprueba que el mercado ha corregido más del 20% desde máximos o lleva más de 6 meses consolidando tras una corrección. Puedes equivocarte y que sea una redistribución, pero independientemente de eso, es la mejor fase para invertir. Actitud agresiva.',
      'Fase alcista': 'A medida que el precio se acerque a máximos o los supere, ve siendo cada vez más conservador. Consulta el histórico de tiempo y revalorización del mercado para saber cuánto margen puede quedar.',
      'Fase de distribución': 'Es el momento de ser conservador. Comprueba si el precio está consolidando; cuanto más tiempo, más se confirma la distribución. Recoge beneficios y mantén una actitud conservadora. Consulta el histórico.',
      'Fase bajista': 'Es momento de comenzar a utilizar la liquidez. En corrección simple (0-10%) comienza a usarla de forma paulatina y aumenta tu actitud agresiva a medida que estés en una corrección mayor (10-20%) y, sobre todo, si sobrepasa el 20%. Pasa de una actitud con gran liquidez a inversión significativa cuando confirmes mercado bajista (corrección >20% o más de 6 meses). Consulta el histórico.',
    };

    final resultado = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('¿En qué fase del ciclo de mercado te encuentras?'),
        children: [
          SimpleDialogOption(
            child: const Text('Fase de acumulación'),
            onPressed: () => Navigator.pop(context, 'Fase de acumulación'),
          ),
          SimpleDialogOption(
            child: const Text('Fase alcista'),
            onPressed: () => Navigator.pop(context, 'Fase alcista'),
          ),
          SimpleDialogOption(
            child: const Text('Fase de distribución'),
            onPressed: () => Navigator.pop(context, 'Fase de distribución'),
          ),
          SimpleDialogOption(
            child: const Text('Fase bajista'),
            onPressed: () => Navigator.pop(context, 'Fase bajista'),
          ),
          const Divider(),
          SimpleDialogOption(
            child: const Text('📈 Histórico mercado', style: TextStyle(color: Colors.blue)),
            onPressed: () {
              Navigator.pop(context, 'HistoricoMercado');
            },
          ),
        ],
      ),
    );

    if (resultado == 'HistoricoMercado') {
      await _mostrarCuestionarioHistorico(context);
      await _mostrarDialogoFase(context); // Vuelve a mostrar la fase después del cuestionario
    } else if (resultado != null) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(resultado),
          content: Text(consejosFases[resultado] ?? ''),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido')),
          ],
        ),
      );

      Navigator.push(context, MaterialPageRoute(builder: (_) => PaginaInversiones(saldo: invertir)));
    }
  }

  Future<void> _mostrarCuestionarioHistorico(BuildContext context) async {
    final String? posicionPrecio = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('¿Dónde está el precio respecto a máximos anteriores?'),
        children: [
          SimpleDialogOption(
            child: const Text('Por encima de máximos anteriores'),
            onPressed: () => Navigator.pop(context, 'Por encima'),
          ),
          SimpleDialogOption(
            child: const Text('Por debajo de máximos anteriores'),
            onPressed: () => Navigator.pop(context, 'Por debajo'),
          ),
        ],
      ),
    );

    if (posicionPrecio == null) return;

    final String? revalDeval = await showDialog<String>(
      context: context,
      builder: (context) {
        final TextEditingController controller = TextEditingController();
        return AlertDialog(
          title: const Text('Introduce la revalorización o devaluación (%)'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Ejemplo: 15 o -10'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Aceptar')),
          ],
        );
      },
    );

    if (revalDeval == null || revalDeval.isEmpty) return;

    final String? diasFase = await showDialog<String>(
      context: context,
      builder: (context) {
        final TextEditingController controller = TextEditingController();
        return AlertDialog(
          title: const Text('¿Cuántos días lleva esta fase?'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Número de días'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Aceptar')),
          ],
        );
      },
    );

    if (diasFase == null || diasFase.isEmpty) return;

    await _mostrarResumenHistorico(context, posicionPrecio, double.parse(revalDeval), int.parse(diasFase));
  }

  Future<void> _mostrarResumenHistorico(BuildContext context, String posicionPrecio, double revalDeval, int diasFase) async {
    final Map<String, Map<String, double>> datosHistoricos = {
  'Fase alcista': {
    'mediaReval10a': 75.42,
    'mediaDias10a': 725,
    'mediaReval25a': 109.198,
    'mediaDias25a': 1235,
  },
  'Fase consolidacion': {
    'mediaDias10a': 402.5,
    'mediaDias25a': 976.5,
  },
  'Fase bajista': {
    'mediaReval10a': 24.5,        // Caída % para 10 años
    'mediaDias10a': 169.5,        // Días de caída para 10 años
    'consolDias10a': 402.5,       // Días de consolidación para 10 años
    'mediaReval25a': 34.68,       // Caída % para 25 años
    'mediaDias25a': 353.33,       // Días de caída para 25 años
    'consolDias25a': 976.5,       // Días de consolidación para 25 años
  },
};


    String fase = '';
    if (posicionPrecio == 'Por encima') {
      if (revalDeval >= 0) {
        fase = 'Fase alcista';
      } else {
        fase = 'Fase consolidacion';
      }
    } else {
      fase = 'Fase bajista';
    }

    final datos = datosHistoricos[fase]!;

    final diffReval10a = datos['mediaReval10a']! - revalDeval;
    final diffDias10a = datos['mediaDias10a']! - diasFase;
    final diffReval25a = datos['mediaReval25a']! - revalDeval;
    final diffDias25a = datos['mediaDias25a']! - diasFase;

    final mensaje = StringBuffer();

    mensaje.writeln('Estás en la $fase del nuevo ciclo de mercado.');

    if (fase == 'Fase bajista') {
  final diffConsolDias10a = datosHistoricos['Fase consolidacion']!['mediaDias10a']! - diasFase;
  final diffConsolDias25a = datosHistoricos['Fase consolidacion']!['mediaDias25a']! - diasFase;

  mensaje.writeln('Comparación con la media de los últimos 10 años:');
  mensaje.writeln('- Caída restante aprox.: ${diffReval10a.toStringAsFixed(1)}%');
  mensaje.writeln('- Días restantes aprox. de caída: ${diffDias10a.toStringAsFixed(0)} días');
  mensaje.writeln('- Días restantes aprox. de consolidación: ${diffConsolDias10a.toStringAsFixed(0)} días');
  mensaje.writeln('');
  mensaje.writeln('Comparación con la media de los últimos 25 años:');
  mensaje.writeln('- Caída restante aprox.: ${diffReval25a.toStringAsFixed(1)}%');
  mensaje.writeln('- Días restantes aprox. de caída: ${diffDias25a.toStringAsFixed(0)} días');
  mensaje.writeln('- Días restantes aprox. de consolidación: ${diffConsolDias25a.toStringAsFixed(0)} días');
} else {


      mensaje.writeln('Comparación con la media de los últimos 10 años:');
      mensaje.writeln('- Revalorización restante aprox.: ${diffReval10a.toStringAsFixed(1)}%');
      mensaje.writeln('- Días restantes aprox.: ${diffDias10a.toStringAsFixed(0)} días');
      mensaje.writeln('');
      mensaje.writeln('Comparación con la media de los últimos 25 años:');
      mensaje.writeln('- Revalorización restante aprox.: ${diffReval25a.toStringAsFixed(1)}%');
      mensaje.writeln('- Días restantes aprox.: ${diffDias25a.toStringAsFixed(0)} días');
    }
// --- Guardar datos para el módulo macro ---
final prefs = await SharedPreferences.getInstance();

// Reval/deval actual (si revalDeval < 0, guardamos la caída en positivo)
await prefs.setDouble('spxRevalPctActual',    revalDeval >= 0 ? revalDeval : 0.0);
await prefs.setDouble('spxDevalPctActualAbs', revalDeval <  0 ? -revalDeval : 0.0);

// Medias históricas 10 años (bull y bear)
final bull10 = datosHistoricos['Fase alcista']?['mediaReval10a'] ?? 0.0;
final bear10 = datosHistoricos['Fase bajista']?['mediaReval10a'] ?? 0.0; // caída media (en positivo)

await prefs.setDouble('spxBullAvgRet10y', bull10);
await prefs.setDouble('spxBearAvgDD10y',  bear10);


    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resumen histórico del mercado'),
        content: Text(mensaje.toString()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Distribución inicial del saldo'),
      leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saldo mensual: €${widget.saldo.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Gastos personales'),
              trailing: Text('€${gastosPersonales.toStringAsFixed(2)}'),
              onTap: () async {
                final nuevoValor = await Navigator.push<double>(
                  context,
                  MaterialPageRoute(builder: (_) => PaginaGastosPersonales(saldo: gastosPersonales)),
                );
                if (nuevoValor != null) actualizarGastosPersonales(nuevoValor);
              },
            ),
            ListTile(
              leading: const Icon(Icons.trending_up),
              title: const Text('Invertir'),
              trailing: Text('€${invertir.toStringAsFixed(2)}'),
              onTap: () => _mostrarDialogoFase(context),
            ),
            ListTile(
              leading: const Icon(Icons.security),
              title: const Text('Liquidez de emergencia'),
              trailing: Text('€${liquidezEmergencia.toStringAsFixed(2)}'),
            ),
            ListTile(
              leading: const Icon(Icons.savings),
              title: const Text('Ahorro simple'),
              trailing: Text('€${ahorroSimple.toStringAsFixed(2)}'),
            ),
          ],
        ),
      ),
    );
  }
}

class PaginaGastosPersonales extends StatelessWidget {
  final double saldo;

  const PaginaGastosPersonales({super.key, required this.saldo});

  @override
  Widget build(BuildContext context) {
    final TextEditingController _controller = TextEditingController(text: saldo.toStringAsFixed(2));

    return Scaffold(
      appBar: AppBar(title: const Text('Modificar gastos personales')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text('Introduce nuevo valor (€)', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              onSubmitted: (value) {
                final nuevoValor = double.tryParse(value);
                if (nuevoValor != null && nuevoValor >= 0) {
                  Navigator.pop(context, nuevoValor);
                }
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final nuevoValor = double.tryParse(_controller.text);
                if (nuevoValor != null && nuevoValor >= 0) {
                  Navigator.pop(context, nuevoValor);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

class PaginaInversiones extends StatefulWidget {
  final double saldo;

  const PaginaInversiones({super.key, required this.saldo});

  @override
  State<PaginaInversiones> createState() => _PaginaInversionesState();
}

class _PaginaInversionesState extends State<PaginaInversiones> {
  String tickerOperar = '';

  @override
  Widget build(BuildContext context) {
    final largoPlazo = widget.saldo * 0.50;
    final cortoPlazo = widget.saldo * 0.50;
    final consolidacion = cortoPlazo * 0.50;
    final operar = cortoPlazo * 0.50;
    final fii = largoPlazo * 0.5;
    final portafolio = largoPlazo * 0.5;

    return Scaffold(
      appBar: AppBar(title: const Text('Distribución de inversiones'),
      leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Inversión a\nlargo plazo',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '€${largoPlazo.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Container(
                color: Colors.grey.shade100,
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text('Índices',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                                color: Colors.black87)),
                        const SizedBox(height: 8),
                        Text('€${fii.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PaginaPortafolio(capitalInicial: portafolio),
                          ),
                        );
                      },
                      child: Column(
                        children: [
                          Text('Portafolio',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 24,
                                  color: Colors.blue.shade700)),
                          const SizedBox(height: 8),
                          Text('€${portafolio.toStringAsFixed(2)}',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.blue.shade700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Inversión a corto plazo',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.black87)),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Total: €${cortoPlazo.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 18, color: Colors.black87)),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Cuenta de consolidación',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.black87)),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('€${consolidacion.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 18, color: Colors.black87)),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Operar',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.black87)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('€${operar.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 18)),
                trailing: const Icon(Icons.arrow_drop_down),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (_) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          title: const Text('Consumo cíclico'),
                          onTap: () {
                            setState(() {
                              tickerOperar = 'TSLA';
                            });
                            Navigator.pop(context);
                          },
                        ),
                        ListTile(
                          title: const Text('Consumo no cíclico'),
                          onTap: () {
                            setState(() {
                              tickerOperar = 'AMZN';
                            });
                            Navigator.pop(context);
                          },
                        ),
                        ListTile(
                          title: const Text('Consumo defensivo'),
                          onTap: () {
                            setState(() {
                              tickerOperar = 'GOOGL';
                            });
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              if (tickerOperar.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    tickerOperar,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class PaginaPortafolio extends StatefulWidget {
  final double capitalInicial;

  const PaginaPortafolio({super.key, required this.capitalInicial});

  @override
  State<PaginaPortafolio> createState() => _PaginaPortafolioState();
}

class _PaginaPortafolioState extends State<PaginaPortafolio> {
  String? _fmpLastError;

// === FMP ===
// === FMP (analyst estimates anual) ===
static const String _fmpKey = "T2lkYSgttcYL1QpzA5kkVWCOiOQrIVny"; // <- pon tu clave real
// usa v3 (suele estar abierta). si te da 403, ya estabas probando v4.
static const String _fmpAnalystV3 = "https://financialmodelingprep.com/api/v3/analyst-estimates";
static const String _fmpAnalystStable = "https://financialmodelingprep.com/stable/analyst-estimates";




  double _capitalActual = 0.0;

  String _formatearFecha(DateTime fecha) {
  return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
}
void _recalcularDistribucionConLimite({
  required double limite,
  required double capital,
}) {
 // Forzar que algo se vea en consola


  setState(() {
    _limiteCapital = limite;

    // 1. Calcular pesos
    double sumaPesos = 0.0;
    for (final ticker in _tickers) {
  final double jRaw = ticker['cagr'] ?? 0.0;
  final double j = jRaw > 1 ? jRaw / 100.0 : jRaw; // ✅ CAGR en decimal
  final double h = ticker['per'] ?? 15.0;
  final double k = pow((h / 20), 0.25) - 1;
  final double l = pow((h / 25), 0.25) - 1;

  // --- B4: oportunidad 10–12%
  final double eps = ticker['eps'] ?? 1.0;
  final double precio = ticker['precio'] ?? 0.0;

  final double precio12 = (eps * pow(1 + j, 4) * 20) / pow(1 + 0.12, 4);
  final double precio10 = (eps * pow(1 + j, 4) * 25) / pow(1 + 0.10, 4);

  final double den = (precio10 - precio12) / 2.0;
  final double factor6 = (den.abs() < 1e-9)
      ? 1.0
      : (() {
          final x = ((precio - precio10) / den) / 2.0; // suavizado = 2.0
          final score = 1 + 99 * (1 / (1 + exp(x)));   // 1..100
          return (0.5 + 1.5 * (score / 100)).clamp(0.5, 2.0) as double; // 0.5..2
        })();

  final peso =
      min(2, max(0.5, 1 + (j - k))) *
      min(2, max(0.5, 1 + (30 - h) / 15)) *
      min(1.2, max(0.8, 1 + min(j, 0.5) / 0.5)) *
      min(2, max(0.5, (2 * j * 100) / h)) *
      (1 + l / 0.15) *
      factor6;

  ticker['pesoFormula'] = peso;
  sumaPesos += peso;
}


    // 2. Calcular capital provisional
    for (final ticker in _tickers) {
      final peso = ticker['pesoFormula'] ?? 1.0;
      final provisional = capital * (peso / sumaPesos);
      ticker['capitalProvisional'] = provisional;
    }

    // 3. Filtrar los incluidos
    final incluidos = _tickers
        .where((t) => (t['capitalProvisional'] ?? 0.0) >= limite)
        .toList();

    // 4. Sumar total provisional solo de los incluidos
    final sumaProvisionalIncluidos = incluidos.fold<double>(
      0.0, (sum, t) => sum + (t['capitalProvisional'] ?? 0.0),
    );

   // 5. Reparto final
for (final ticker in _tickers) {
  if (incluidos.contains(ticker)) {
    final capitalProv = ticker['capitalProvisional'] ?? 0.0;
    final capitalAsignado =
        capital * (capitalProv / sumaProvisionalIncluidos);
    ticker['capitalAsignado'] = capitalAsignado.clamp(0.0, double.infinity);
  } else {
    ticker['capitalAsignado'] = 0.0;
  }
}

  });
}





  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _tickers = [];
    final ScrollController _scrollController = ScrollController();
  String? _tickerAbierto;


late TextEditingController _capitalController;
late double capitalAportar;
late TextEditingController _limiteController;
double? _limiteCapital;


// Controladores para los TextFields de CAGR
late List<TextEditingController> _cagrControllers;
late List<TextEditingController> _epsControllers;

// 🔑 Claves únicas para ExpansionTile
late List<GlobalKey> _keys;

void _actualizarCapital(double nuevoCapital) {
  setState(() {
    capitalAportar = nuevoCapital;

    final sumaFactores = _tickers.fold<double>(0.0, (suma, t) => suma + (t['factor'] ?? 0.0));

    for (var t in _tickers) {
      final factor = t['factor'] ?? 0.0;
      final porcentaje = sumaFactores > 0 ? factor / sumaFactores : 0.0;
      t['capitalAsignado'] = capitalAportar * porcentaje;
    }

    if (_limiteCapital != null) {
      final incluidos = _tickers.where((t) => (t['capitalAsignado'] ?? 0.0) >= _limiteCapital!).toList();
      final excluidos = _tickers.where((t) => !incluidos.contains(t)).toList();

      final sumaFactoresIncluidos = incluidos.fold<double>(0.0, (suma, t) => suma + (t['factor'] ?? 0.0));

      for (var t in incluidos) {
        final factor = t['factor'] ?? 0.0;
        final porcentaje = sumaFactoresIncluidos > 0 ? factor / sumaFactoresIncluidos : 0.0;
        t['capitalAsignado'] = capitalAportar * porcentaje;
      }

      for (var t in excluidos) {
        t['capitalAsignado'] = 0.0;
      }
    }

    // DEBUG
    for (var t in _tickers) {
    }
  });
}



void _ordenarTickersPorCapital() {
  setState(() {
    _tickers.sort((a, b) => (b['capitalAsignado'] as double).compareTo(a['capitalAsignado'] as double));
  });
}





  @override
  void initState() {
    super.initState();
    capitalAportar = widget.capitalInicial;
    _capitalController = TextEditingController(text: capitalAportar.toStringAsFixed(2));
    _limiteController = TextEditingController();
    _cagrControllers = [];
    _epsControllers = [];
    _keys = [];


    _cargarTickers();
  }

@override
void dispose() {
  _controller.dispose();
  _scrollController.dispose();
  _limiteController.dispose();

 
}

// 👇 Aquí va:
void _scrollHasta(GlobalKey key) {
  Future.delayed(const Duration(milliseconds: 300), () {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 400),
        alignment: 0.6,
        curve: Curves.easeInOut,
      );
    }
  });
}





 Future<void> _actualizarTodo() async {
  for (int i = 0; i < _tickers.length; i++) {
    final ticker = _tickers[i]['ticker'];
    final nuevoPrecio = await obtenerPrecio(ticker);
    final perYeps = await obtenerPERyEPS(ticker);
    if (nuevoPrecio != null && perYeps != null) {
  _tickers[i]['precio'] = nuevoPrecio;
  _tickers[i]['per'] = perYeps['per'];
  _tickers[i]['dividendYield'] = perYeps['dividendYield'] ?? 0.0; // ⬅️ NUEVO


  final epsModificado = _tickers[i]['epsModificado'] ?? false;
  if (!epsModificado) {
    _tickers[i]['eps'] = perYeps['eps'];
  }

  // Intentar calcular CAGR 5 años automáticamente
final eps5 = await obtenerEpsHace5Anios(ticker);
if (eps5 != null && eps5 > 0) {
  final epsActual = _tickers[i]['eps'] ?? 0.0;
  if (epsActual > 0) {
    final cagrCalc = pow(epsActual / eps5, 1 / 5) - 1;
    _tickers[i]['epsHistorico'] = eps5;
    _tickers[i]['cagrManual'] = cagrCalc;
    print("✅ [$ticker] CAGR5 auto = ${(cagrCalc*100).toStringAsFixed(2)}% con EPS 5y=$eps5");
  }
}


  _keys.add(GlobalKey());
final cagr5 = await calcularCAGR5Anios(_tickers[i]);
_tickers[i]['cagr5'] = cagr5 ?? 0.0;


}

  }

  // Re-crear controladores si el número no coincide
  if (_cagrControllers.length != _tickers.length || _epsControllers.length != _tickers.length) {
    for (var c in _cagrControllers) {
      c.dispose();
    }
    for (var c in _epsControllers) {
      c.dispose();
    }

    _cagrControllers = List.generate(
      _tickers.length,
      (index) => TextEditingController(
        text: (_tickers[index]['cagr'] ?? 0.0).toStringAsFixed(1),
      ),
    );

    _epsControllers = List.generate(
      _tickers.length,
      (index) => TextEditingController(
        text: (_tickers[index]['eps'] ?? 0.0).toStringAsFixed(2),
      ),
    );
  } else {
    // Si ya están bien, actualizamos los textos
    for (int i = 0; i < _tickers.length; i++) {
      _cagrControllers[i].text = (_tickers[i]['cagr'] ?? 0.0).toStringAsFixed(1);
      _epsControllers[i].text = (_tickers[i]['eps'] ?? 0.0).toStringAsFixed(2);
    }
  }

  // Actualizar EPS según los controladores antes de calcular capital
  for (int i = 0; i < _tickers.length; i++) {
    final nuevoEps = double.tryParse(_epsControllers[i].text);
    if (nuevoEps != null) {
      _tickers[i]['eps'] = nuevoEps;
    }
  }

if (_tickers.isNotEmpty) {
  double sumaFactores = 0;
  for (var t in _tickers) {
    final bool esManual = t['epsModificado'] == true;

    final double precio = t['precio'] ?? 0.0;
    final double epsTTM = t['epsTTM'] ?? 0.0;

    final double per = esManual
        ? (t['per'] ?? 15.0)                  // PER manual para manuales
        : (epsTTM > 0 ? precio / epsTTM : 15.0);  // cálculo para automáticos

    if (!esManual) {
      t['per'] = per;  // Solo sobrescribe si no es manual
    }

   final double cagr = (t['cagr'] ?? 0.0) / 100; // ✅ en decimal
final double eps = t['eps'] ?? 1.0;

// --- cálculo de precios objetivo al 12% y 10%
final double precio12 = (eps * pow(1 + cagr, 4) * 20) / pow(1 + 0.12, 4);
final double precio10 = (eps * pow(1 + cagr, 4) * 25) / pow(1 + 0.10, 4);
final double den = (precio10 - precio12) / 2.0;

// --- factor6 = B4
final double factor6 = (den.abs() < 1e-9)
    ? 1.0
    : (() {
        final x = (((t['precio'] ?? 0.0) - precio10) / den) / 2.0;
        final score = 1 + 99 * (1 / (1 + exp(x))); // 1..100
        return (0.5 + 1.5 * (score / 100)).clamp(0.5, 2.0) as double; // 0.5..2
      })();

final double crecNecesario = pow(per / 20, 0.25) - 1;
final double rentabilidadEsperada = pow((eps * pow(1 + cagr, 4) * 25) / precio, 0.25) - 1;

final double factor1 = min(2, max(0.5, 1 + (cagr - crecNecesario)));
final double factor2 = min(2, max(0.5, 1 + (30 - per) / 15));
final double factor3 = min(1.2, max(0.8, 1 + min(cagr, 0.5) / 0.5));
final double factor4 = min(2, max(0.5, (2 * cagr * 100) / per));
final double factor5 = 1 + rentabilidadEsperada / 0.15;

// ✅ ahora incluye factor6 (B4) al final
final double factor = cagr * factor1 * factor2 * factor3 * factor4 * factor5 * factor6;


t['factor'] = factor;
sumaFactores += factor;

  }



 for (var t in _tickers) {
  final bool esManual = t['epsModificado'] == true;
  final double precio = t['precio'] ?? 0.0;
  final double epsTTM = t['epsTTM'] ?? 0.0;

  final double per = esManual
      ? (t['per'] ?? 15.0)  // Usa PER manual
      : (epsTTM > 0 ? precio / epsTTM : 15.0);  // Calcula PER si no es manual

  if (!esManual) {
    t['per'] = per;  // Sobrescribe solo si no es manual
  }
}


    

  }
_tickers.sort((a, b) => (b['capitalAsignado'] as double).compareTo(a['capitalAsignado'] as double));

  setState(() {});
  await _guardarTickers();
}



  Future<void> _cargarTickers() async {
  final prefs = await SharedPreferences.getInstance();
  final listaGuardada = prefs.getStringList('tickers_guardados') ?? [];

  _tickers.clear();
  for (var item in listaGuardada) {
  final map = jsonDecode(item);
  final tickerMap = Map<String, dynamic>.from(map);
  if (!tickerMap.containsKey('epsModificado')) {
    tickerMap['epsModificado'] = false;
  }
  _tickers.add(tickerMap);
}


  for (var c in _cagrControllers) {
    c.dispose();
  }
  for (var c in _epsControllers) {
    c.dispose();
  }

  _cagrControllers = [];
  _epsControllers = [];

  for (int i = 0; i < _tickers.length; i++) {
    _cagrControllers.add(TextEditingController(
      text: (_tickers[i]['cagr'] ?? 0.0).toStringAsFixed(1),
    ));
    _epsControllers.add(TextEditingController(
      text: (_tickers[i]['eps'] ?? 0.0).toStringAsFixed(2),
    ));
  }

_keys = List.generate(_tickers.length, (_) => GlobalKey());
await _actualizarTodo();
 // Calcula capitalAsignado y ordena
  setState(() {}); // Redibuja
}


  Future<void> _guardarTickers() async {
    final prefs = await SharedPreferences.getInstance();
    final listaString = _tickers.map((e) => jsonEncode(e)).toList();
    await prefs.setStringList('tickers_guardados', listaString);
  }

  Future<double?> obtenerPrecio(String ticker) async {
    final url = Uri.parse('https://finnhub.io/api/v1/quote?symbol=$ticker&token=d1pt729r01qku4u4htj0d1pt729r01qku4u4htjg');
    try {
      final respuesta = await http.get(url);
      if (respuesta.statusCode == 200) {
        final datos = jsonDecode(respuesta.body);
        return (datos['c'] as num?)?.toDouble();
      }
    } catch (_) {}
    return null;
  }

 Future<Map<String, double>?> obtenerPERyEPS(String ticker) async {
  final url = Uri.parse('https://finnhub.io/api/v1/stock/metric?symbol=$ticker&metric=all&token=d1pt729r01qku4u4htj0d1pt729r01qku4u4htjg');
  try {
    final respuesta = await http.get(url);
    if (respuesta.statusCode == 200) {
      final datos = jsonDecode(respuesta.body);
      final metric = datos['metric'] ?? {};

      double? per     = (metric['peTTM'] as num?)?.toDouble();
      double? eps     = (metric['epsNormalizedAnnual'] as num?)?.toDouble();
      double? epsTTM  = (metric['epsTTM'] as num?)?.toDouble();
      double? dyTTM   = (metric['dividendYieldTTM'] as num?)?.toDouble();
      double? dyIndic = (metric['dividendYieldIndicatedAnnual'] as num?)?.toDouble();

      // Usa el yield disponible (TTM primero; si no, el indicado anual)
      final double? dividendYield = dyTTM ?? dyIndic;

      // Ajuste especial TSM (solo para EPS si tú lo usas así)
      if (ticker == 'TSM') {
        if (eps != null) eps /= 6.5;
        if (epsTTM != null) epsTTM /= 6.5;
      }

      if (per != null && eps != null) {
        return {
          'per': per,
          'eps': eps,
          'epsTTM': epsTTM ?? 0.0,
          'dividendYield': dividendYield ?? 0.0, // ⬅️ NUEVO
        };
      }
    }
  } catch (_) {}
  return null;
}

double? _leerEPS(Map<String, dynamic> m) {
  for (final k in const [
    'epsMean','epsEstimatedAverage','epsAverage','epsAvg','epsEstimate','eps','epsHigh','epsLow'
  ]) {
    final v = m[k];
    if (v is num) return v.toDouble();
    if (v is String) {
      final x = double.tryParse(v);
      if (x != null) return x;
    }
  }
  return null;
}


Future<double?> _epsFuturo4Y_FMP(String symbol) async {
  Future<double?> _tryEndpoint(String base) async {
   final uri = Uri.parse("$base?symbol=$symbol&period=annual&limit=10&apikey=$_fmpKey");
    final resp = await http.get(uri).timeout(const Duration(seconds: 10));
    print("🔍 FMP $base  -> ${resp.statusCode}");
    if (resp.statusCode == 401) { _fmpLastError = "FMP 401: API key inválida."; return null; }
    if (resp.statusCode == 403) { _fmpLastError = "FMP 403: Tu plan no incluye $base."; return null; }
    if (resp.statusCode != 200) { _fmpLastError = "FMP ${resp.statusCode}: error al consultar estimates."; return null; }

    final data = json.decode(resp.body);
    
final List<dynamic> list =
    data is List
        ? data
        : (data is Map ? (data['data'] as List? ?? const []) : const []);
if (list.isEmpty) { _fmpLastError = "FMP: lista vacía o formato no esperado."; return null; }



if (list.isEmpty) { _fmpLastError = "FMP: lista vacía o formato no esperado."; return null; }


    final int y0 = DateTime.now().year;
    final int target = y0 + 4;

    final Map<int, double> epsPorAnio = {};
   for (final it0 in list) {
  if (it0 is! Map) continue;
  final it = Map<String, dynamic>.from(it0);

 final dateRaw = it['date'] ?? it['calendarYear'] ?? '';
final date = dateRaw.toString();

int? year = int.tryParse(date.length >= 4 ? date.substring(0, 4) : '');
if (year == null && it['fiscalYear'] is int) {
  year = it['fiscalYear'] as int;
}

final epsRaw = (it['epsAvg'] ?? it['eps'] ?? it['estimatedEPS']);
final double? eps = epsRaw is num ? epsRaw.toDouble() : null;

if (year != null && eps != null) {
  epsPorAnio[year] = eps;
}

}


    if (epsPorAnio.isEmpty) { _fmpLastError = "FMP: sin EPS en las filas devueltas."; return null; }

    if (epsPorAnio.containsKey(target)) {
      print("✅ [$base] EPS target $target = ${epsPorAnio[target]}");
      return epsPorAnio[target];
    }
    final futuros = epsPorAnio.keys.where((y) => y >= target).toList()..sort();
    if (futuros.isNotEmpty) {
      print("ℹ️ [$base] no hay $target; uso ${futuros.first}");
      return epsPorAnio[futuros.first];
    }
    final futurosCortos = epsPorAnio.keys.where((y) => y > y0).toList()..sort();
    if (futurosCortos.isNotEmpty) {
      print("ℹ️ [$base] futuro más lejano disponible = ${futurosCortos.last}");
      return epsPorAnio[futurosCortos.last];
    }
    _fmpLastError = "FMP: solo datos pasados, sin futuro.";
    return null;
  }

  // Intenta v4 -> v3
 double? v = await _tryEndpoint(_fmpAnalystStable);

  if (v == null) v = await _tryEndpoint(_fmpAnalystV3);
  return v;
}

Future<void> _mostrarCagr4yFmpPorIndice(int index) async {
  final t = _tickers[index];
  final String symbol = (t['ticker'] ?? '').toString().trim();
  if (symbol.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sin ticker')),
    );
    return;
  }

  // EPS actual: prioriza EPS TTM si está; si no, el EPS que usas en UI
  final double epsActual = (t['epsTTM'] ?? t['eps'] ?? 0.0) * 1.0;
  if (epsActual <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No hay EPS actual válido (>0)')),
    );
    return;
  }

final eps4 = await _epsFuturo4Y_FMP(symbol);

if (eps4 == null || eps4 <= 0) {
  final msg = _fmpLastError ?? 'FMP sin EPS futuro (+4a)';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  print("❌ Motivo FMP: $msg");
  return;
}

  final cagr = math.pow(eps4 / epsActual, 1 / 4) - 1;
  final pct = (cagr * 100).toStringAsFixed(1);
  print("🧮 epsActual=${epsActual.toStringAsFixed(4)}  eps4=${eps4.toStringAsFixed(4)}");
print("🧮 CAGR=(eps4/epsActual)^(1/4)-1 => ${(cagr*100).toStringAsFixed(2)}%");


  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('FMP: $pct% (4 años)')),
  );
}


  void _agregarTicker() async {
  final texto = _controller.text.trim().toUpperCase();
  if (texto.isEmpty || _tickers.any((t) => t['ticker'] == texto)) return;

  final precio = await obtenerPrecio(texto);
  final perYeps = await obtenerPERyEPS(texto);

  if (precio != null && perYeps != null) {
    final per = perYeps['per']!;
    final eps = perYeps['eps']!;
    final epsTTM = perYeps['epsTTM'] ?? 0.0; //
    final prefs = await SharedPreferences.getInstance();
    final cagr = prefs.getDouble('cagr_$texto') ?? 0.0;

    _tickers.add({
  'ticker': texto,
  'precio': precio,
  'per': per,
  'eps': eps,
  'epsTTM': epsTTM,
  'cagr': cagr,
  'capitalAsignado': 0.0,
  'epsModificado': false,
  'epsHistorico': null,
  'cagrManual': 0.0,
  'dividendYield': perYeps['dividendYield'] ?? 0.0, // ⬅️ NUEVO
});



setState(() {
  _tickerAbierto = null;
});


_controller.clear();
await _guardarTickers();
await _actualizarTodo();


  } else {
    final confirmar = await showDialog<bool>(
  context: context,
  useRootNavigator: true, // 👈 Esto es útil para web si estás anidado
  builder: (_) => AlertDialog(
    title: const Text('Ticker no encontrado'),
    content: const Text('¿Quieres añadirlo manualmente?'),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Añadir')),
    ],
  ),
);


   if (confirmar == true) {
  final TextEditingController precioCtrl = TextEditingController();
  final TextEditingController perCtrl = TextEditingController();
  final TextEditingController epsCtrl = TextEditingController();

  // Abrimos el diálogo que devuelve un Map con los datos introducidos
  final datos = await showDialog<Map<String, double>>(
    context: context,
    builder: (_) {
     void guardar() {
  final precioManual = double.tryParse(precioCtrl.text);
  final perManual = double.tryParse(perCtrl.text);
  final epsManual = double.tryParse(epsCtrl.text);


  if (precioManual != null && perManual != null && epsManual != null) {
    Navigator.of(context).pop({
      'precio': precioManual,
      'per': perManual,
      'eps': epsManual,
    });
  } else {
 
  }
}


      return AlertDialog(
        title: Text('Introduce los datos de $texto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: precioCtrl,
              decoration: const InputDecoration(labelText: 'Precio'),
              keyboardType: TextInputType.number,
              onSubmitted: (_) => guardar(),
            ),
            TextField(
              controller: perCtrl,
              decoration: const InputDecoration(labelText: 'PER'),
              keyboardType: TextInputType.number,
              onSubmitted: (_) => guardar(),
            ),
            TextField(
              controller: epsCtrl,
              decoration: const InputDecoration(labelText: 'EPS'),
              keyboardType: TextInputType.number,
              onSubmitted: (_) => guardar(),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancelar')),
          TextButton(onPressed: guardar, child: const Text('Guardar')),
        ],
      );
    },
  );

  if (datos == null) return; // Si canceló, salimos

  // Extraemos los datos recibidos
  final precioManual = datos['precio']!;
  final perManual = datos['per']!;
  final epsManual = datos['eps']!;

  // Ahora pedimos el CAGR
  final TextEditingController cagrCtrl = TextEditingController();
  final confirmarCAGR = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('Introduce el crecimiento estimado (CAGR) de $texto'),
      content: TextField(
        controller: cagrCtrl,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Ejemplo: 0.15 para 15%'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
      ],
    ),
  );

  if (confirmarCAGR != true) return;

  final cagrManual = double.tryParse(cagrCtrl.text.trim()) ?? 0.0;

  _tickers.add({
    'ticker': texto,
    'precio': precioManual,
    'per': perManual,
    'eps': epsManual,
    'cagr': cagrManual,
    'capitalAsignado': 0.0,
    'epsModificado': true,
  });

  _controller.clear();
  await _guardarTickers();
  await _actualizarTodo();

  Future.delayed(Duration(milliseconds: 50), () {
    final capitalActual = double.tryParse(_capitalController.text) ?? 0.0;
    _recalcularDistribucionConLimite(
      limite: _limiteCapital ?? 0.0,
      capital: capitalActual,
    );
  });



    }
  }
}



  void _eliminarTicker(int index) {
    setState(() {
      _tickers.removeAt(index);
      _cagrControllers[index].dispose();
      _cagrControllers.removeAt(index);
    });
    _guardarTickers();
  }

  @override
  Widget build(BuildContext context) {
      if (_keys.length != _tickers.length) {
    _keys = List.generate(_tickers.length, (_) => GlobalKey());
  }

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Portafolio'),
      leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
    body: SingleChildScrollView(

  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(


          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Añadir empresa (ticker)',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _agregarTicker,
                ),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _agregarTicker(),
            ),
            const SizedBox(height: 16),
          TextField(
  controller: _capitalController,
  keyboardType: TextInputType.number,
  decoration: const InputDecoration(
    labelText: 'Capital a aportar (€)',
    border: OutlineInputBorder(),
  ),
  onChanged: (value) {
    final capital = double.tryParse(value) ?? 0.0;
    _capitalActual = capital;
  },
  onSubmitted: (value) async {
  final nuevoCapital = double.tryParse(value);
  if (nuevoCapital != null && nuevoCapital >= 0) {
    _actualizarCapital(nuevoCapital);
    _ordenarTickersPorCapital();
    setState(() {
      _tickerAbierto = null;
    });

    // ⬇️ GUARDA capital mensual
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('capital_mensual', nuevoCapital);
  }
},

),
const SizedBox(height: 4),
Align(
  alignment: Alignment.centerRight,
  child: TextButton(
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      minimumSize: Size(0, 0),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    onPressed: () async {
  final capital = double.tryParse(_capitalController.text);
  if (capital != null && capital >= 0) {
    _actualizarCapital(capital);
    _ordenarTickersPorCapital();
    if (_controller.text.trim().isNotEmpty) {
      _agregarTicker();
    }
    setState(() {
      _tickerAbierto = null;
    });

    // ⬇️ GUARDA capital mensual
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('capital_mensual', capital);
  }
},

    child: const Text("Aceptar", style: TextStyle(fontSize: 12)),
  ),
),



            const SizedBox(height: 16),
            Center(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      ElevatedButton.icon(
        icon: const Icon(Icons.refresh),
        label: const Text('Actualizar precios y PER'),
        onPressed: _actualizarTodo,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(220, 48),
        ),
      ),
      const SizedBox(height: 12),
ElevatedButton.icon(
  icon: const Icon(Icons.shopping_cart),
  label: const Text('Invertir'),
 onPressed: () async {
  if (_tickers.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No hay tickers para invertir')),
    );
    return;
  }

  // 🔍 POP-UP SOBREVALORADOS
  final sobrevalorados = _tickers.where(estaSobrevalorada).toList();
  final porcentaje = _tickers.isEmpty
      ? 0.0
      : (sobrevalorados.length / _tickers.length) * 100;

  String mensaje = '${sobrevalorados.length} de ${_tickers.length} acciones '
      '(${porcentaje.toStringAsFixed(1)}%) parecen estar sobrevaloradas.\n\n';

  if (porcentaje < 25) {
    mensaje += 'Podrías estar en un buen momento de mercado.';
  } else if (porcentaje < 50) {
    mensaje += 'Algunas acciones están caras, analiza con calma.';
  } else {
    mensaje += 'La mayoría parecen sobrevaloradas, cuidado al invertir.';
  }

  final continuar = await showDialog<bool>(
  context: context,
  builder: (context) {
    return AlertDialog(
      title: const Text('Antes de invertir...'),
      content: Text(mensaje),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Invertir igualmente'),
        ),
      ],
    );
  },
);

// Si quieres que Enter funcione, aquí necesitarías un TextField o RawKeyboardListener.
// Pero dado que sólo es texto, podrías envolver el AlertDialog en RawKeyboardListener si quieres capturar Enter globalmente.


  if (continuar != true) return;

  // 💼 CONTINÚA LÓGICA DE INVERSIÓN
  final prefs = await SharedPreferences.getInstance();
  final listaGuardada = prefs.getStringList('tickers_guardados') ?? [];

  Map<String, Map<String, dynamic>> guardadosMap = {};
  for (var item in listaGuardada) {
    final map = jsonDecode(item) as Map<String, dynamic>;
    guardadosMap[map['ticker']] = Map<String, dynamic>.from(map);
  }

  final tickersConAcciones = _tickers.map((t) {
    final ticker = t['ticker'];
    final precio = t['precio'] ?? 1.0;
    final capital = t['capitalAsignado'] ?? 0.0;
    final accionesNuevas = capital / precio;

    if (guardadosMap.containsKey(ticker)) {
      final guardado = guardadosMap[ticker]!;

      final accionesPrevias = (guardado['acciones'] ?? 0.0) as double;
      final accionesTotales = accionesPrevias + accionesNuevas;

      final capitalPrevio = (guardado['capitalAsignado'] ?? 0.0) as double;
      final capitalTotal = capitalPrevio + capital;

      final historialPrevio = (guardado['acciones_historial'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final nuevoHistorial = List<Map<String, dynamic>>.from(historialPrevio)
        ..add({
          'tipo': 'compra',
          'cantidad': accionesNuevas,
          'fecha': _formatearFecha(DateTime.now()),
        });

      return {
        ...t,
        'acciones': accionesTotales,
        'capitalAsignado': capitalTotal,
        'acciones_historial': nuevoHistorial,
      };
    } else {
      return {
        ...t,
        'acciones': accionesNuevas,
        'acciones_historial': [
          ...?t['acciones_historial'],
          {
            'tipo': 'compra',
            'cantidad': accionesNuevas,
            'fecha': _formatearFecha(DateTime.now()),
          }
        ],
      };
    }
  }).toList();

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PaginaDetalleTickers(
        tickersSeleccionados: tickersConAcciones,
        modoInvertir: true,
      ),
    ),
  );
},


  style: ElevatedButton.styleFrom(
    minimumSize: const Size(220, 48),
  ),
),


      const SizedBox(height: 12),
      ElevatedButton(
        onPressed: () async {
  final prefs = await SharedPreferences.getInstance();
  final listaGuardada = prefs.getStringList('tickers_guardados') ?? [];

  if (listaGuardada.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No hay tickers guardados')),
    );
    return;
  }

  final List<Map<String, dynamic>> tickersGuardados = listaGuardada
      .map((item) => Map<String, dynamic>.from(jsonDecode(item)))
      .toList();

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PaginaDetalleTickers(
        tickersSeleccionados: tickersGuardados,
        modoInvertir: false,
      ),
    ),
  );
},

        child: const Text('Ver detalle de tickers'),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(220, 48),
        ),
      ),
    ],
  ),
),


   const SizedBox(height: 16),
Align(
  alignment: Alignment.centerRight,
  child: SizedBox(
    width: 220,
    child: TextField(
      controller: _limiteController,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'Excluir < €',
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
     style: const TextStyle(fontSize: 13),
onSubmitted: (value) {
  final nuevoLimite = double.tryParse(value) ?? 0.0;

Future.delayed(Duration(milliseconds: 50), () {

  final capitalActual = double.tryParse(_capitalController.text) ?? 0.0;


  _recalcularDistribucionConLimite(
    limite: nuevoLimite,
    capital: capitalActual,
  );
});

},







    ),
  ),
),



const SizedBox(height: 16),

_tickers.isEmpty
    ? const Center(child: Text('No has añadido ninguna empresa.'))
    : ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),


          controller: _scrollController,
          itemCount: _tickers.length,
          itemBuilder: (context, index) {
            return Container(
  key: _keys[index],
  decoration: BoxDecoration(
    // Prioriza el sombreado por descuento; si no aplica, muestra gris si está sobrevalorada
    color: _colorPorDescuento(_tickers[index]) 
           ?? (estaSobrevalorada(_tickers[index]) ? Colors.grey[300] : null),
  ),

  child: ExpansionTile(
    key: ValueKey('${_tickers[index]['ticker']}_${_tickerAbierto == _tickers[index]['ticker'] ? 'open' : 'closed'}'),
    initiallyExpanded: _tickerAbierto == _tickers[index]['ticker'],
    onExpansionChanged: (expandido) {
      setState(() {
        _tickerAbierto = expandido ? _tickers[index]['ticker'] : null;
      });
      if (expandido) {
        _scrollHasta(_keys[index]);
      }
    },
   title: Row(
  children: [
    // Columna 1: Ticker
    SizedBox(
      width: 80, // ancho fijo para todos los tickers
      child: Text(
        _tickers[index]['ticker'],
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ),
// Columna 2: PEG y PEGf
Expanded(
  child: Builder(builder: (_) {
    final double per = (_tickers[index]['per'] ?? 0.0) * 1.0;
    final double cagrPct = (_tickers[index]['cagr'] ?? 0.0) * 1.0; // en %
    final double eps = (_tickers[index]['eps'] ?? 0.0) * 1.0;
    final double precio = (_tickers[index]['precio'] ?? 0.0) * 1.0;

    // EPS proyectado a 4 años
    final double eps4Anios = eps * pow(1 + (cagrPct / 100), 4);

    // Perf
    final double? perf = eps4Anios > 0 ? precio / eps4Anios : null;

    // PEG clásico
    double? pegValue;
    Color pegColor = Colors.black;
    FontWeight pegWeight = FontWeight.normal;
    if (cagrPct > 0) {
      pegValue = per / cagrPct;
      if (pegValue > 3) {
        pegColor = Colors.black;
        pegWeight = FontWeight.bold;
      } else if (pegValue > 2) {
        pegColor = Colors.pink;
      } else if (pegValue >= 1.5 && pegValue <= 2) {
        pegColor = Colors.blue;
      } else if (pegValue >= 1 && pegValue < 1.5) {
        pegColor = Colors.green;
      } else if (pegValue < 1) {
        pegColor = Colors.orange;
      }
    }

    // PEGf
    final double? pegfValue =
        (perf != null && cagrPct > 0) ? perf / cagrPct : null;

    return Wrap(
      alignment: WrapAlignment.start,
      spacing: 8,
      children: [
        Text(
          pegValue != null ? 'PEG: ${pegValue.toStringAsFixed(2)}' : 'PEG: -',
          style: TextStyle(fontSize: 14, color: pegColor, fontWeight: pegWeight),
        ),
     Text(
  pegfValue != null ? 'PEGf: ${pegfValue.toStringAsFixed(2)}' : 'PEGf: -',
  style: TextStyle(
    fontSize: 14,
    color: pegfValue == null
        ? Colors.black
        : (pegfValue < 1
            ? Colors.green
            : (pegfValue <= 2 ? Colors.blue : Colors.red)),
  ),
),


      ],
    );
  }),
),



    // Columna 3: Capital (flexible a la derecha)
    Expanded(
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          'Capital: €${(_tickers[index]['capitalAsignado'] ?? 0.0).toStringAsFixed(2)}',
        ),
      ),
    ),
  ],
),



    children: [
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Precio: €${_tickers[index]['precio'].toStringAsFixed(2)}'),
        Builder(
  builder: (_) {
    final perManual = _tickers[index]['per'] ?? 0.0;
    // Opcionalmente puedes mantener este cálculo alternativo, pero mostrando perManual si está disponible
    return Text(
      'PER: ${perManual.toStringAsFixed(2)}',
      style: const TextStyle(fontSize: 14),
    );
  },
),





            const SizedBox(height: 8),
Align(
  alignment: Alignment.centerLeft,
  child: SizedBox(
    width: 180, // Ajusta el ancho a lo que te resulte cómodo
    child: TextField(
      controller: _epsControllers[index],
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'EPS (editable)',
        border: OutlineInputBorder(),
      ),
      onSubmitted: (value) async {
        final nuevoEps = double.tryParse(value);
        if (nuevoEps == null) return;

        _tickers[index]['eps'] = nuevoEps;
        _tickers[index]['epsModificado'] = true;

        _epsControllers[index].text = nuevoEps.toStringAsFixed(2);

        await _guardarTickers();

        setState(() {
          _tickerAbierto = null;
        });

        await _actualizarTodo();
        _actualizarCapital(capitalAportar);
        _ordenarTickersPorCapital();
      },
    ),
  ),
),

const SizedBox(height: 8),
Text(
  'EPS TTM: ${_tickers[index]['epsTTM']?.toStringAsFixed(2) ?? '0.00'}',
  style: const TextStyle(fontSize: 14, color: Colors.blueGrey),
),




            const SizedBox(height: 8),
          
           const SizedBox(height: 8),
Builder(
  builder: (_) {
    final eps = _tickers[index]['eps'] as double;
    final cagr = (_tickers[index]['cagr'] ?? 0.0) / 100;

    // EPS proyectado a 4 años
    final eps4Anios = eps * pow(1 + cagr, 4);

    // Calcular Perf
    final precio = _tickers[index]['precio'] as double;
    final perf = precio / eps4Anios;

    final precioMin = eps4Anios * 20 / pow(1.12, 4);
    final precioMax = eps4Anios * 25 / pow(1.10, 4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
       Transform.translate(
  offset: const Offset(0, -4), // mueve hacia arriba (ajusta el valor si quieres)
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        perf != null ? 'Perf: ${perf.toStringAsFixed(2)}' : 'Perf: -',
        style: TextStyle(
          fontSize: 14,
          color: perf == null
              ? Colors.black
              : (perf < 20
                  ? Colors.green
                  : (perf <= 25 ? Colors.blue : Colors.red)),
        ),
      ),
      Text(
        'Precio ideal: €${precioMin.toStringAsFixed(2)} - €${precioMax.toStringAsFixed(2)}',   
      ),
Builder(
  builder: (_) {
    final dy = (_tickers[index]['dividendYield'] ?? 0.0);
    if (dy <= 0) return const SizedBox.shrink();
    return Text('Dividendo: ${dy.toStringAsFixed(2)}%');
  },
),


    ],
  ),
)


      ],
    );
  },
),

            const SizedBox(height: 8),
const SizedBox(height: 8),
Row(
  children: [
    // Campo de CAGR manual (editable)
    SizedBox(
      width: 180,
      child: TextField(
        controller: _cagrControllers[index],
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'CAGR %',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (value) async {
          
          final nuevoCagr = double.tryParse(value);
          if (nuevoCagr == null) return;

          final ticker = _tickers[index]['ticker'];
          final prefs = await SharedPreferences.getInstance();

          _tickers[index]['cagr'] = nuevoCagr;
          _cagrControllers[index].text = nuevoCagr.toStringAsFixed(1);

          await prefs.setDouble('cagr_$ticker', nuevoCagr);
          await _guardarTickers();

          setState(() {
            _tickerAbierto = null;
          });

          await _actualizarTodo();
          _actualizarCapital(capitalAportar);
          _ordenarTickersPorCapital();
        },
      ),
    ),

    const SizedBox(width: 4),
    const SizedBox(width: 8),
GestureDetector(
  onTap: () => _mostrarCagr4yFmpPorIndice(index),
  child: const Text(
    'CAGR %',
    style: TextStyle(
      decoration: TextDecoration.underline,
      fontWeight: FontWeight.w600,
    ),
  ),
),

TextButton(
  style: TextButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    minimumSize: Size(0, 0),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  ),
  onPressed: () async {
    final nuevoCagr = double.tryParse(_cagrControllers[index].text);
    if (nuevoCagr == null) return;

    final ticker = _tickers[index]['ticker'];
    final prefs = await SharedPreferences.getInstance();

    _tickers[index]['cagr'] = nuevoCagr;
    _cagrControllers[index].text = nuevoCagr.toStringAsFixed(1);

    // ✅ Ejecuta también el EPS del mismo ticker
    final nuevoEps = double.tryParse(_epsControllers[index].text);
    if (nuevoEps != null) {
      _tickers[index]['eps'] = nuevoEps;
      _tickers[index]['epsModificado'] = true;
    }

    await prefs.setDouble('cagr_$ticker', nuevoCagr);
    await _guardarTickers();

    setState(() {
      _tickerAbierto = null;
    });

    await _actualizarTodo();
    _actualizarCapital(capitalAportar);
    _ordenarTickersPorCapital();
  },
  child: const Text("Aceptar", style: TextStyle(fontSize: 12)),
),



    const SizedBox(width: 12),

    SizedBox(
      width: 160,  // ancho fijo para botón pequeño
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade100,

          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        ),
        child: Text(
          'CAGR 5 años: ${((_tickers[index]['cagrManual'] ?? 0.0) * 100).toStringAsFixed(2)} %',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      onPressed: () async {
  final epsActual = (_tickers[index]['eps'] as double?) ?? 0.0;

  // usa el EPS que se haya guardado automáticamente
  final epsAuto = _tickers[index]['epsHistorico'] as double?;
  final epsController = TextEditingController(
    text: epsAuto != null ? epsAuto.toStringAsFixed(2) : '',
  );

  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Introduce EPS hace 5 años'),
      content: TextField(
        controller: epsController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'EPS hace 5 años'),
        onSubmitted: (_) => Navigator.of(context).pop(true),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Calcular')),
      ],
    ),
  );

  if (ok == true) {
    final epsHist = double.tryParse(epsController.text.replaceAll(',', '.'));
    if (epsHist != null && epsHist > 0 && epsActual > 0) {
      final cagrCalc = pow(epsActual / epsHist, 1 / 5) - 1;
      setState(() {
        _tickers[index]['epsHistorico'] = epsHist;
        _tickers[index]['cagrManual'] = cagrCalc;
      });
      await _guardarTickers();
      await _actualizarTodo();
      _actualizarCapital(capitalAportar);
      _ordenarTickersPorCapital();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('EPS inválido.')),
      );
    }
  }
},



      ),
    ),
  ],
),

            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _eliminarTicker(index),
              ),
            ),
          ],
        ),
      ),
    ],
  ),
);
},
),

          ],
        ),
      ),
         ), // SingleChildScrollView
    ); // Scaffold
  }
}


Future<double?> obtenerEpsHace5Anios(String ticker) async {
  const apiKey = "T2lkYSgttcYL1QpzA5kkVWCOiOQrIVny";
  final url = Uri.parse(
    "https://financialmodelingprep.com/api/v3/income-statement/${ticker.toUpperCase()}?period=annual&limit=15&apikey=$apiKey"
  );

  try {
    final resp = await http.get(url).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      print("❌ FMP income-statement $ticker -> ${resp.statusCode}");
      return null;
    }

    final raw = jsonDecode(resp.body);
    if (raw is! List || raw.isEmpty) {
      print("⚠️ FMP: sin datos income-statement para $ticker");
      return null;
    }

    // Normaliza filas: (year, eps) probando varias claves
    final List<Map<String, dynamic>> filas = [];
    for (final e in raw) {
      if (e is! Map) continue;

      int? year;
      final cy = e['calendarYear']?.toString();
      if (cy != null && cy.length >= 4) year = int.tryParse(cy.substring(0, 4));
      final d = e['date']?.toString();
      year ??= (d != null && d.length >= 4) ? int.tryParse(d.substring(0, 4)) : null;

      double? eps;
      for (final k in const ['eps', 'epsdiluted', 'epsDiluted']) {
        final v = e[k];
        if (v is num) { eps = v.toDouble(); break; }
        if (v is String) { final x = double.tryParse(v); if (x != null) { eps = x; break; } }
      }

      if (year != null && eps != null) {
        filas.add({'year': year, 'eps': eps});
      }
    }

    if (filas.isEmpty) {
      print("⚠️ FMP: sin (año, eps) válidos para $ticker");
      return null;
    }

    // Ordena DESC por año
    filas.sort((a, b) => (b['year'] as int).compareTo(a['year'] as int));

    final ultimo = filas.first['year'] as int;
    final objetivo = ultimo - 5;

    // 1) Exacto
    final exacto = filas.firstWhere((f) => f['year'] == objetivo, orElse: () => {});
    if (exacto.isNotEmpty) return exacto['eps'] as double;

    // 2) Más cercano <= objetivo
    final menoresIguales = filas.where((f) => (f['year'] as int) <= objetivo).toList();
    if (menoresIguales.isNotEmpty) return (menoresIguales.first)['eps'] as double;

    // 3) 5º más reciente si existe
    if (filas.length >= 5) return (filas[4]['eps'] as double);

    // 4) Último recurso: el más antiguo
    return (filas.last['eps'] as double);
  } catch (e) {
    print("❌ Error obtenerEpsHace5Anios($ticker): $e");
    return null;
  }
}







Future<double?> calcularCAGR5Anios(Map<String, dynamic> ticker) async {
  final epsActual = ticker['eps'] as double?;
  final symbol = ticker['ticker'];
  final epsPasado = await obtenerEpsHace5Anios(symbol);


  if (epsActual != null && epsPasado != null && epsPasado > 0) {
    return pow(epsActual / epsPasado, 1 / 5) - 1;
  }
  return null;
}

Color? _colorPorDescuento(Map<String, dynamic> t) {
  final double precio = (t['precio'] ?? 0.0).toDouble();
  final double eps = (t['eps'] ?? 0.0).toDouble();
  final double cagrPct = (t['cagr'] ?? 0.0).toDouble(); // viene en %
  if (precio <= 0 || eps <= 0) return null;

  final double cagr = cagrPct > 1 ? cagrPct / 100.0 : cagrPct;

  final double precio12 = (eps * pow(1 + cagr, 4) * 20) / pow(1 + 0.12, 4);
  final double precio10 = (eps * pow(1 + cagr, 4) * 25) / pow(1 + 0.10, 4);

  if (precio <= precio12) {
    return Colors.green.withOpacity(0.25);
  } else if (precio <= precio10) {
    return Colors.blue.withOpacity(0.25);
  }
  return null;
}



  bool estaSobrevalorada(Map<String, dynamic> ticker) {
  final per = ticker['per'] ?? 0.0;

  final cagr = ticker['cagr'] ?? 0.0; // En porcentaje, ej. 10 para 10%

  if (per == 0.0 || cagr == 0.0) return false;

  return per > (2 * cagr);
}



class PaginaInicial extends StatelessWidget {
  const PaginaInicial({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Bienvenido a B&Bx',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade400,
                  fontFamily: 'Roboto',
                  letterSpacing: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Tu gestor inteligente de finanzas personales',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 50),
            ElevatedButton.icon(
  icon: const Icon(Icons.account_balance_wallet_outlined, size: 28),
  label: const Text('Portafolio', style: TextStyle(fontSize: 20)),
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PaginaPortafolio(capitalInicial: 0)),
    );
  },
  style: ElevatedButton.styleFrom(
    minimumSize: const Size(double.infinity, 56),
    backgroundColor: Colors.blue.shade200,
    foregroundColor: Colors.blue.shade900,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    elevation: 4,
    shadowColor: Colors.blue.shade100,
  ),
),


              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.repeat_outlined, size: 28),
                label: const Text('Inversión periódica', style: TextStyle(fontSize: 20)),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const PreguntarSaldoPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  backgroundColor: Colors.purple.shade200,
                  foregroundColor: Colors.purple.shade900,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                  shadowColor: Colors.purple.shade100,
                ),
              ),
                           const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.public, size: 28),
                label: const Text('Indicadores macro', style: TextStyle(fontSize: 20)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PaginaIndicadoresMacro()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  backgroundColor: Colors.orange.shade200,
                  foregroundColor: Colors.orange.shade900,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                  shadowColor: Colors.orange.shade100,
                ),
              ),

              const SizedBox(height: 20),
            ElevatedButton.icon(
  icon: const Icon(Icons.bar_chart, size: 28),
  label: const Text('Fundamental', style: TextStyle(fontSize: 20)),
  onPressed: () async {
    final prefs = await SharedPreferences.getInstance();
    final listaGuardada = prefs.getStringList('tickers_guardados') ?? [];
    if (listaGuardada.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay tickers en el portafolio. Añádelos primero.')),
        );
      }
      return;
    }
    final tickers = listaGuardada
        .map((s) => (jsonDecode(s) as Map<String, dynamic>)['ticker'] as String)
        .map((t) => t.toUpperCase())
        .toSet()
        .toList()
      ..sort();

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaginaFundamental(
            tickers: tickers,
            initialTicker: tickers.first,
          ),
        ),
      );
    }
  },
  style: ElevatedButton.styleFrom(
    minimumSize: const Size(double.infinity, 56),
    backgroundColor: Colors.green.shade200,
    foregroundColor: Colors.green.shade900,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    elevation: 4,
    shadowColor: Colors.green.shade100,
  ),
),


              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.attach_money_outlined, size: 28),
                label: const Text('Inversión puntual', style: TextStyle(fontSize: 20)),

  
  onPressed: () async {
    // 1. Pedir cantidad inversión puntual
    final TextEditingController inversionController = TextEditingController();
    final String? inversionStr = await showDialog<String>(
  context: context,
  builder: (context) {
    final TextEditingController inversionController = TextEditingController();
    return AlertDialog(
      title: const Text('Introduce la cantidad de inversión puntual'),
      content: TextField(
        controller: inversionController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(hintText: 'Ejemplo: 10000'),
        autofocus: true,
        onSubmitted: (value) => Navigator.pop(context, value.trim()), // <-- Aquí
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(context, inversionController.text.trim()), child: const Text('Aceptar')),
      ],
    );
  },
);


    if (inversionStr == null || inversionStr.isEmpty) return;

    final double? inversion = double.tryParse(inversionStr);
    if (inversion == null || inversion <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cantidad no válida')));
      return;
    }

    // 2. Pedir saldo mensual habitual
    final TextEditingController saldoController = TextEditingController();
   final String? saldoStr = await showDialog<String>(
  context: context,
  builder: (context) {
    final TextEditingController saldoController = TextEditingController();
    return AlertDialog(
      title: const Text('Introduce tu saldo mensual habitual'),
      content: TextField(
        controller: saldoController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(hintText: 'Ejemplo: 1000'),
        autofocus: true,
        onSubmitted: (value) => Navigator.pop(context, value.trim()), // <-- Aquí
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(context, saldoController.text.trim()), child: const Text('Aceptar')),
      ],
    );
  },
);


    if (saldoStr == null || saldoStr.isEmpty) return;

    final double? saldo = double.tryParse(saldoStr);
    if (saldo == null || saldo <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saldo no válido')));
      return;
    }

    // 3. Calcular número de meses para repartir la inversión
    final double saldoDisponible = saldo * 0.3;
final double meses = inversion / saldoDisponible;


    // 4. Mostrar resultado
  await showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Reparto de inversión'),
    content: Text(
      'Has indicado una inversión puntual de €${inversion.toStringAsFixed(2)} y un saldo mensual habitual de €${saldo.toStringAsFixed(2)}.\n\n'
      'Lo ideal sería que repartieses la inversión de forma mensual con €${saldoDisponible.toStringAsFixed(2)} durante ${meses.toStringAsFixed(1)} meses.\n'
'Introduce tu saldo mensual habitual, €${saldo.toStringAsFixed(2)}, en el apartado de inversión periódica. Posteriormente continuarás con la misma cantidad al finalizar tu capital puntual.',


    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
    ],
  ),
);

  },
 style: ElevatedButton.styleFrom(
    minimumSize: const Size(double.infinity, 56),
    backgroundColor: Colors.teal.shade200,
    foregroundColor: Colors.teal.shade900,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    elevation: 4,
    shadowColor: Colors.teal.shade100,
  ),
),

            ],
          ),
        ),
      ),
    );
  }
}




class PaginaDetalleTickers extends StatefulWidget {
  final List<Map<String, dynamic>> tickersSeleccionados;
  final bool modoInvertir; // <-- nuevo parámetro

  const PaginaDetalleTickers({
    super.key,
    required this.tickersSeleccionados,
    this.modoInvertir = false, // valor por defecto
  });


  @override
  State<PaginaDetalleTickers> createState() => _PaginaDetalleTickersState();
}

class _PaginaDetalleTickersState extends State<PaginaDetalleTickers> {
  String _formatearFecha(DateTime fecha) {
  return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
}

  late List<TextEditingController> _accionesControllers; 
  
  void _mostrarHistorialAcciones(int index) {
  final ticker = widget.tickersSeleccionados[index];
  List<Map<String, dynamic>> historial = List<Map<String, dynamic>>.from(ticker['acciones_historial'] ?? []);

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setStateDialog) {
          String _fmt(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

          void eliminarEntrada(int idx) {
            setStateDialog(() {
              historial.removeAt(idx);
            });
          }

          void modificarEntrada(int idx) async {
            final TextEditingController cantidadController = TextEditingController(text: historial[idx]['cantidad'].toString());
            final TextEditingController fechaController = TextEditingController(text: historial[idx]['fecha']);

            final result = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Modificar entrada'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: cantidadController,
                      decoration: const InputDecoration(labelText: 'Cantidad de acciones'),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: fechaController,
                      decoration: const InputDecoration(labelText: 'Fecha'),
                    ),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
                ],
              ),
            );

            if (result == true) {
              setStateDialog(() {
                historial[idx]['cantidad'] = double.tryParse(cantidadController.text) ?? historial[idx]['cantidad'];
                historial[idx]['fecha'] = fechaController.text;
              });
            }
          }

          return AlertDialog(
            title: Text('Historial de ${ticker['ticker']}'),
            content: SizedBox(
              width: double.maxFinite,
              child: historial.isEmpty
                  ? const Text('Sin historial')
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: historial.length,
                      itemBuilder: (context, i) {
                        final entrada = historial[i];
                        return ListTile(
                          title: Text('${entrada['cantidad']} acciones'),
                          subtitle: Text(entrada['fecha'] ?? ''),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => modificarEntrada(i),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => eliminarEntrada(i),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
           actions: [
  // ⬅️ NUEVO: botón AÑADIR
  TextButton(
    onPressed: () async {
      final TextEditingController cantidadCtrl = TextEditingController();
      DateTime fechaSel = DateTime.now();
      final TextEditingController fechaCtrl =
          TextEditingController(text: _fmt(fechaSel));

      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Añadir entrada'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: cantidadCtrl,
                decoration: const InputDecoration(labelText: 'Cantidad de acciones'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: fechaCtrl,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Fecha',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.date_range),
                    onPressed: () async {
                      final f = await showDatePicker(
                        context: context,
                        initialDate: fechaSel,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (f != null) {
                        fechaSel = f;
                        fechaCtrl.text = _fmt(f);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.pop(context, true),  child: const Text('Añadir')),
          ],
        ),
      );

      if (ok == true) {
        final cant = double.tryParse(cantidadCtrl.text.replaceAll(',', '.'));
        if (cant != null) {
          setStateDialog(() {
            historial.add({
              'cantidad': cant,
              'fecha': fechaCtrl.text, // dd/MM/yyyy
            });
          });
        }
      }
    },
    child: const Text('Añadir'),
  ),

  // Cerrar y guardar (tu lógica de siempre)
TextButton(
  onPressed: () async {
    setState(() {
      widget.tickersSeleccionados[index]['acciones_historial'] = historial;

      double totalAcciones = 0;
      for (var entrada in historial) {
        totalAcciones += (entrada['cantidad'] ?? 0.0) as double;
      }
      widget.tickersSeleccionados[index]['acciones'] = totalAcciones;

      _accionesControllers[index].text = totalAcciones.toStringAsFixed(3);
    });

    Navigator.pop(context);

    // ✅ Persistir inmediatamente
    final prefs = await SharedPreferences.getInstance();
    final listaString = widget.tickersSeleccionados.map((e) => jsonEncode(e)).toList();
    await prefs.setStringList('tickers_guardados', listaString);
  },
  child: const Text('Cerrar y guardar'),
),

],

          );
        },
      );
    },
  );
}


double _capitalMensual = 0.0;
double _multiplicadorPer = 2.0; // editable por el usuario
static const _kPerMultiplierKey = 'per_multiplier';
late TextEditingController _perMultiplierController;


@override
void initState() {
  super.initState();
  _accionesControllers = List.generate(
    widget.tickersSeleccionados.length,
    (i) => TextEditingController(
      text: (widget.tickersSeleccionados[i]['acciones']?.toDouble()?.toStringAsFixed(3) ?? '0.000'),
    ),
  );
_perMultiplierController = TextEditingController(
  text: _multiplicadorPer.toStringAsFixed(
    _multiplicadorPer.truncateToDouble() == _multiplicadorPer ? 0 : 1
  ),
);


  SharedPreferences.getInstance().then((prefs) {
    setState(() {
      _capitalMensual = prefs.getDouble('capital_mensual') ?? 0.0;
       _multiplicadorPer = prefs.getDouble(_kPerMultiplierKey) ?? 2.0;
       _perMultiplierController.text = _multiplicadorPer.toStringAsFixed(
  _multiplicadorPer.truncateToDouble() == _multiplicadorPer ? 0 : 1
);

    });
  });
}
Future<void> _aplicarPegMultiplicador() async {
  FocusScope.of(context).unfocus();
  final txt = _perMultiplierController.text.trim().replaceAll(',', '.');
  final v = double.tryParse(txt);
  if (v == null || v <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PEG inválido')),
    );
    return;
  }
  setState(() => _multiplicadorPer = v);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setDouble(_kPerMultiplierKey, _multiplicadorPer);
}


 Widget _proyeccionA4Anos(BuildContext context) {
    final int n = widget.tickersSeleccionados.length;
    final double meses = 48.0;
    final double aportePorTicker = (n > 0) ? (_capitalMensual / n) : 0.0;

    double totalProyectado = 0.0;

    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Row(
  children: [
    const Expanded(
      child: Text(
        'Proyección a 4 años',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),
    const SizedBox(width: 12),
    const Text('PEG', style: TextStyle(fontSize: 12)),
    const SizedBox(width: 6),
    SizedBox(
      width: 80,
      child: TextField(
        controller: _perMultiplierController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          isDense: true,
          hintText: '2.0',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
        onSubmitted: (_) => _aplicarPegMultiplicador(),
      ),
    ),
    const SizedBox(width: 6),
    TextButton(
      onPressed: _aplicarPegMultiplicador,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text('Aceptar'),
    ),
  ],
),



            ...widget.tickersSeleccionados.map((t) {
              final String ticker = (t['ticker'] ?? '').toString();
              final double acciones = (t['acciones'] ?? 0.0) * 1.0;
              final double precioActual = (t['precio'] ?? 0.0) * 1.0;
              final double epsAnual = (t['eps'] ?? t['epsTTM'] ?? 0.0) * 1.0;

              final double cagrRaw = (t['cagr'] ?? 0.0) * 1.0;
              final double cagr = cagrRaw > 1 ? cagrRaw / 100.0 : cagrRaw;

              final double eps4 = epsAnual * pow(1.0 + cagr, 4).toDouble();
              final double perIdeal = (cagr * 100.0) * _multiplicadorPer;
              final double precio4 = eps4 * perIdeal;

              final double accionesExtra = (precioActual > 0)
                  ? (aportePorTicker / precioActual) * meses
                  : 0.0;

              final double accionesTotales = acciones + accionesExtra;
              final double valorProyectado = accionesTotales * precio4;

              totalProyectado += valorProyectado;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(ticker)),
                    Text('${valorProyectado.toStringAsFixed(2)} €'),
                  ],
                ),
              );
            }).toList(),

            const Divider(),
          Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    const Text(
      'TOTAL',
      style: TextStyle(fontWeight: FontWeight.bold),
    ),
    Text(
      '${totalProyectado.toStringAsFixed(2)} €',
      style: const TextStyle(fontWeight: FontWeight.bold),
    ),
  ],
),
const SizedBox(height: 6),

          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (var c in _accionesControllers) {
      c.dispose();
    }
    _perMultiplierController.dispose();

    super.dispose();
  }

Future<void> _guardarAccionesActualizadas() async {
  for (int i = 0; i < widget.tickersSeleccionados.length; i++) {
    final acciones = double.tryParse(_accionesControllers[i].text) ?? 0.0;
    widget.tickersSeleccionados[i]['acciones'] = acciones;
    // Actualiza el historial también si has modificado ahí (ya lo tienes en widget)
    // Por ejemplo:
    final historialActualizado = widget.tickersSeleccionados[i]['acciones_historial'] ?? [];
    widget.tickersSeleccionados[i]['acciones_historial'] = historialActualizado;
  }

  final prefs = await SharedPreferences.getInstance();
  final listaString = widget.tickersSeleccionados.map((e) => jsonEncode(e)).toList();
  await prefs.setStringList('tickers_guardados', listaString);

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Acciones e historial guardados correctamente')),
  );
}


double calcularValor(int index) {
  final acciones = double.tryParse(_accionesControllers[index].text) ?? 0.0;
  final precio = widget.tickersSeleccionados[index]['precio']?.toDouble() ?? 0.0;
  return acciones * precio;
}




double calcularTotalCartera() {
  double total = 0;
  for (int i = 0; i < widget.tickersSeleccionados.length; i++) {
    total += calcularValor(i);
  }
  return total;
}

// ⬇️ Pega aquí
String _clasificaTicker(Map<String, dynamic> t) {
  final double per = (t['per'] ?? 0.0) * 1.0;
  final double cagrPct = (t['cagr'] ?? 0.0) * 1.0; // en %
  final double dy = (t['dividendYield'] ?? 0.0) * 1.0;

  final double? peg = (cagrPct > 0) ? (per / cagrPct) : null;

  String base;

  if (cagrPct >= 15 && (peg != null && peg < 2)) {
    // Caso especial de growth por PEG bajo
    base = 'Value/Growth';
  } else if (cagrPct >= 15) {
    base = 'Growth';
  } else if (cagrPct < 15 && (peg != null && peg > 2)) {
    base = 'OJO!';
  } else {
    base = 'Value';
  }

  // Prefijo Dividend si hay yield
  if (dy > 0) {
    return 'Dividend/$base';
  }
  return base;
}

Map<String, double> _resumenPorTipos() {
  final lista = widget.tickersSeleccionados;
  final int N = lista.length;
  if (N == 0) {
    return {
      'Growth': 0,
      'Value': 0,
      'Exposición a dividendo (% tickers)': 0,
      'Exposición a dividendo (% capital)': 0,
      'Exposición a dividendo (€)': 0,
    };
  }

  int G = 0;       // por nº de tickers (exclusivo)
  int V = 0;       // por nº de tickers (exclusivo)
  int Dcount = 0;  // nº de tickers con dividendo

  double totalValor = 0.0;      // capital total cartera
  double dividendEuros = 0.0;   // € anuales estimados por dividendos

  for (final t in lista) {
    final String tipo = _clasificaTicker(t);
    final double dy = (t['dividendYield'] ?? 0.0) * 1.0;

    // Valor del ticker
    final double acciones = (t['acciones'] ?? 0.0) * 1.0;
    final double precio   = (t['precio']   ?? 0.0) * 1.0;
    final double valor    = acciones * precio;
    totalValor += valor;                         // ✅ faltaba

    // Estilo exclusivo por tickers
    if (tipo.contains('Growth')) {
      G++;
    } else if (tipo.contains('Value')) {
      V++;
    }

    // Dividend transversal
    final bool esDividend = (dy > 0) || tipo.contains('Dividend');
    if (esDividend) {
      Dcount++;
    }

    // € de dividendos anuales estimados (yield efectivo)
    dividendEuros += valor * (dy / 100.0);       // ✅ usar dividendEuros
  }

  final int GV = G + V;
  final double pctG = GV > 0 ? (G / GV) * 100.0 : 0.0;          // Growth+Value = 100% (tickers)
  final double pctV = GV > 0 ? (V / GV) * 100.0 : 0.0;
  final double pctD_tickers = (Dcount / N) * 100.0;             // Exposición por nº de tickers
  final double pctD_capital = totalValor > 0 ? (dividendEuros / totalValor) * 100.0 : 0.0; // ✅ yield efectivo

  return {
    'Growth': pctG,
    'Value': pctV,
    'Exposición a dividendo (% tickers)': pctD_tickers,
    'Exposición a dividendo (% capital)': pctD_capital,
    'Exposición a dividendo (€)': dividendEuros, // ✅ € anuales
  };
}






Future<void> _mostrarResumenTipos() async {
  final mapa = _resumenPorTipos();

  // Estilo (por nº de tickers) y ordenado desc
  final estilo = {
    'Growth': mapa['Growth'] ?? 0.0,
    'Value': mapa['Value'] ?? 0.0,
  };
  final estiloOrdenado = estilo.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  // Exposición a dividendo (por tickers, por capital y € anuales)
  final divTickers = mapa['Exposición a dividendo (% tickers)'] ?? 0.0;
  final divCapital = mapa['Exposición a dividendo (% capital)'] ?? 0.0; // yield efectivo
  final divEuros   = mapa['Exposición a dividendo (€)'] ?? 0.0;         // € / año

  final buffer = StringBuffer();
  buffer.writeln("Distribución por estilo (por nº de tickers):");
  for (final e in estiloOrdenado) {
    buffer.writeln("${e.key}: ${e.value.toStringAsFixed(1)}%");
  }

  buffer.writeln("\nExposición a dividendo:");
  buffer.writeln("- Por nº de tickers: ${divTickers.toStringAsFixed(1)}%");
  buffer.writeln("- Por capital (yield efectivo): ${divCapital.toStringAsFixed(1)}% (${divEuros.toStringAsFixed(2)} € / año)");

  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Distribución por tipo"),
      content: Text(buffer.toString()),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cerrar"),
        ),
      ],
    ),
  );
}



  
//

Future<void> _ordenarYGuardar({bool persist = true}) async {

  // 1. Sincronizar desde controladores
  for (int i = 0; i < _accionesControllers.length; i++) {
    final acciones = double.tryParse(_accionesControllers[i].text) ?? 0.0;
    widget.tickersSeleccionados[i]['acciones'] = acciones;
  }

  // 2. Combinar con tipos correctos
  final List<Map<String, dynamic>> tickers = widget.tickersSeleccionados;
  final List<TextEditingController> controllers = _accionesControllers;

  final List<MapEntry<Map<String, dynamic>, TextEditingController>> combinados = List.generate(
    tickers.length,
    (i) => MapEntry(tickers[i], controllers[i]),
  );

  // 3. Ordenar por valor
  combinados.sort((a, b) {
    final aVal = (a.key['acciones'] ?? 0.0) * (a.key['precio'] ?? 0.0);
    final bVal = (b.key['acciones'] ?? 0.0) * (b.key['precio'] ?? 0.0);
    return bVal.compareTo(aVal);
  });

  // 4. Separar
  widget.tickersSeleccionados
    ..clear()
    ..addAll(combinados.map((e) => e.key));

  _accionesControllers = List<TextEditingController>.from(
    combinados.map((e) => e.value),
  );

  // 5. Guardar y refrescar
if (persist) {
  final prefs = await SharedPreferences.getInstance();
  final listaString = widget.tickersSeleccionados.map((e) => jsonEncode(e)).toList();
  await prefs.setStringList('tickers_guardados', listaString);
}


  setState(() {});
}

Future<void> _mostrarIdealPorEdad() async {
  // 1) Pedir edad
  final edadCtrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Tu edad'),
      content: TextField(
        controller: edadCtrl,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(hintText: 'Ejemplo: 38'),
        autofocus: true,
        onSubmitted: (_) => Navigator.pop(context, true),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(context, true),  child: const Text('Aceptar')),
      ],
    ),
  );
  if (ok != true) return;

  final edad = int.tryParse(edadCtrl.text.trim()) ?? 0;

  // 2) Tabla objetivo (Growth+Value=100%) + Exposición a dividendo (por nº de tickers)
  //    Ajusta los % si quieres afinarlos
  final ideal = <String, Map<String, int>>{
    '30–39': {'growth': 70, 'value': 30, 'divTickers': 10},
    '40–49': {'growth': 60, 'value': 40, 'divTickers': 20},
    '50–59': {'growth': 50, 'value': 50, 'divTickers': 30},
    '60–69': {'growth': 30, 'value': 70, 'divTickers': 40},
    '70+':   {'growth': 20, 'value': 80, 'divTickers': 50},
  };

  // 3) Elegir rango según edad
  String rango;
  if (edad >= 70) {
    rango = '70+';
  } else if (edad >= 60) {
    rango = '60–69';
  } else if (edad >= 50) {
    rango = '50–59';
  } else if (edad >= 40) {
    rango = '40–49';
  } else { // <40 (incluye <30)
    rango = '30–39';
  }

  String linea(String r) {
    final g = ideal[r]!['growth']!;
    final v = ideal[r]!['value']!;
    final d = ideal[r]!['divTickers']!;
    return '• $r:\n'
           '  - Growth: $g%\n'
           '  - Value: $v%\n'
           '  - Exposición a dividendo (por nº de tickers): $d%';
  }

  final bloqueTuRango = linea(rango);
  final bloqueTodo = ideal.keys.map(linea).join('\n\n');

  // 4) Mostrar pop-up
  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('Ideal por edad (${edad > 0 ? '$edad años' : 'N/D'})'),
      content: SingleChildScrollView(
        child: Text(
          'Objetivo para tu rango:\n'
          '$bloqueTuRango\n\n'
          'Tabla completa de referencia:\n'
          '$bloqueTodo',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
      ],
    ),
  );
}




@override
Widget build(BuildContext context) {
  final total = calcularTotalCartera();

 
  final List<int> indicesOrdenados = List.generate(widget.tickersSeleccionados.length, (i) => i);
indicesOrdenados.sort((a, b) {
  final aVal = calcularValor(a);
  final bVal = calcularValor(b);
  return bVal.compareTo(aVal);
});


  return Scaffold(
    appBar: AppBar(
      title: const Text('Mi Portafolio'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'Distribución del portafolio',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          Container(
  padding: const EdgeInsets.symmetric(vertical: 8),
  color: Colors.grey.shade200,
  child: Row(
   children: [

      Expanded(flex: 2, child: Text('Ticker', style: TextStyle(fontWeight: FontWeight.bold))),
      Expanded(flex: 3, child: Text('Nº acciones', style: TextStyle(fontWeight: FontWeight.bold))),
      Expanded(flex: 3, child: Text('Valor actual €', style: TextStyle(fontWeight: FontWeight.bold))),
      Expanded(flex: 2, child: Text('% cartera', style: TextStyle(fontWeight: FontWeight.bold))),
     Expanded(
  flex: 2,
  child: GestureDetector(
    onTap: _mostrarIdealPorEdad, // 👈 Llamada al pop-up
    child: const Text(
      'Tipo',
      style: TextStyle(
        fontWeight: FontWeight.bold,
        decoration: TextDecoration.underline,
      ),
    ),
  ),
),

  
  
    ],
  ),
),

          const Divider(height: 1),

          // ⬇️ ListView ordenado por valor total
         ListView.builder(
  physics: const NeverScrollableScrollPhysics(),
  shrinkWrap: true,
  itemCount: indicesOrdenados.length,
  itemBuilder: (context, i) {
    final index = indicesOrdenados[i];
    final ticker = widget.tickersSeleccionados[index]['ticker'].toString();
    final valor = calcularValor(index);
    final porcentaje = total > 0 ? (valor / total) * 100 : 0;
    final tipo = _clasificaTicker(widget.tickersSeleccionados[index]); // 👈 NUEVO

    return Column(
      children: [
        Row(
          children: [
            Expanded(flex: 2, child: Text(ticker)),
            Expanded(
              flex: 3,
              child: GestureDetector(
                onTap: () => _mostrarHistorialAcciones(index),
                child: AbsorbPointer(
                  absorbing: (double.tryParse(_accionesControllers[index].text) ?? 0.0) > 0,
                  child: TextField(
                    controller: _accionesControllers[index],
                    keyboardType: TextInputType.number,
                    onChanged: (valor) async {
                      final acciones = double.tryParse(valor) ?? 0.0;
                      final List<Map<String, dynamic>> historial =
                          (widget.tickersSeleccionados[index]['acciones_historial'] as List?)?.cast<Map<String, dynamic>>() ?? [];

                      final actualizado = [
                        ...historial.where((e) => e['tipo'] != 'manual'),
                        {
                          'tipo': 'manual',
                          'cantidad': acciones,
                          'fecha': _formatearFecha(DateTime.now()),
                        }
                      ];

                      setState(() {
                        widget.tickersSeleccionados[index]['acciones_historial'] = actualizado;
                        widget.tickersSeleccionados[index]['acciones'] = acciones;
                      });

                      await _ordenarYGuardar();

                      final prefs = await SharedPreferences.getInstance();
                      final listaString = widget.tickersSeleccionados.map((e) => jsonEncode(e)).toList();
                      await prefs.setStringList('tickers_guardados', listaString);
                    },
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(flex: 3, child: Text('€${valor.toStringAsFixed(2)}')),
            Expanded(flex: 2, child: Text('${porcentaje.toStringAsFixed(1)}%')),
            Expanded(
  flex: 2,
  child: GestureDetector(
    onTap: _mostrarResumenTipos, // 👈 Al tocar muestra el resumen
    child: Text(
      tipo,
      style: const TextStyle(
        color: Colors.blue,
        decoration: TextDecoration.underline,
      ),
    ),
  ),
),

          ],
        ),
        const Divider(height: 1),
      ],
    );
  },
),


          const SizedBox(height: 24),
          Text(
            'Total del portafolio: €${total.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          if (widget.modoInvertir) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _guardarAccionesActualizadas,
              child: const Text('Guardar'),
            ),
          ],
         const SizedBox(height: 24),
if (!widget.modoInvertir) _proyeccionA4Anos(context),

        ],
      ),
    ),
  );
}
}


// ======================
// MODELOS / CONFIG (top-level)
// ======================
class IndCfg {
  final String code;      // nombre visible (clave en "indicadores")
  final String fredKey;   // clave en _fredSeries
  final int polarity;     // +1 alto=bueno; -1 alto=malo
  final double weight;    // peso en señal final
  final bool yoy;         // pedir en YoY %
  const IndCfg(this.code, this.fredKey, this.polarity, this.weight, {this.yoy=false});
}

class Stat {
  final double last;      // último dato (nivel)
  final double z;         // z-score nivel (con signo de “riesgo”)
  final double trendZ;    // z-score de momentum 3m
  final double score;     // [-1..+1] fusión nivel+tendencia (con polaridad)
  const Stat(this.last, this.z, this.trendZ, this.score);

  Map<String, dynamic> toJson() => {
    "last": last, "z": z, "trendZ": trendZ, "score": score,
  };

  static Stat fromJson(Map<String, dynamic> j) =>
      Stat((j["last"] as num).toDouble(),
           (j["z"] as num).toDouble(),
           (j["trendZ"] as num).toDouble(),
           (j["score"] as num).toDouble());
}

// ======================
// ESCENARIOS MACRO / SPX
// ======================
const Map<String, Map<String, String>> escenariosMacroSpx = {
  "Macro alcista": {
    "Alcista en desarrollo": "Contexto favorable y en expansión. Refuerza la probabilidad de continuidad alcista.",
    "Alcista extendido": "Señal de sobreextensión, riesgo de corrección pese al apoyo macro.",
    "Bajista en desarrollo": "Divergencia: macro fuerte pero mercado débil → posible oportunidad de entrada.",
    "Bajista extendido": "Macro fuerte + mercado agotado a la baja → escenario de giro muy probable.",
  },
  "Macro neutro": {
    "Alcista en desarrollo": "Sesgo alcista técnico, sin confirmación macro. Prudencia, pero con recorrido.",
    "Alcista extendido": "Mercado sobreextendido, macro sin apoyo → techo más probable.",
    "Bajista en desarrollo": "Sesgo bajista técnico, sin confirmación macro → riesgo de continuidad.",
    "Bajista extendido": "Bajista prolongado con macro neutro → posibilidad de rebote técnico, menos claro.",
  },
  "Macro bajista": {
    "Alcista en desarrollo": "Divergencia: mercado rebota pero macro no lo apoya → riesgo de fallo alcista.",
    "Alcista extendido": "Extensión alcista con macro negativo → riesgo elevado de corrección fuerte.",
    "Bajista en desarrollo": "Macro débil + mercado en caída → continuidad bajista muy probable.",
    "Bajista extendido": "Macro en recesión y bear prolongado. Probable suelo en formación.",
  },
};

// Normaliza el texto del macro a las claves del mapa
String _macroKey(String macro) {
  switch (macro.trim().toLowerCase()) {
    case 'macro alcista':
    case 'alcista':
      return 'Macro alcista';
    case 'macro bajista':
    case 'bajista':
      return 'Macro bajista';
    default:
      return 'Macro neutro';
  }
}


// ======================
// PÁGINA
// ======================
class PaginaIndicadoresMacro extends StatefulWidget {
  const PaginaIndicadoresMacro({super.key});
  @override
  State<PaginaIndicadoresMacro> createState() => _PaginaIndicadoresMacroState();
}

class _PaginaIndicadoresMacroState extends State<PaginaIndicadoresMacro> {
  // ===== Config FRED =====
  static const String _fredBase = "https://api.stlouisfed.org/fred/series/observations";
  static const String _fredKey  = "8f79718ec2ae928538c060ca6a1e18cf";
  static const String _histStart = "2000-01-01";
  // 0 = usa todo el histórico de FRED; >0 = usa últimos X años para medias/σ del z-score
int _ventanaAniosZ = 25;  // valor inicial (25 años). 0 = todo histórico



  // ===== Cache persistente =====
  static const String _prefsKey = "macro_cache_v1";

  // ===== UI/Data =====
  final Map<String, String> indicadores = {
    "PIB (GDP)": "US.GDP",
    "Desempleo": "US.UNRATE",
    "Inflación (CPI)": "US.CPI",
    "Precios Productor (PPI)": "US.PPI",
    "Tipos interés Fed": "US.INTERESTRATE",
    "Bono 10 años": "US.Y10",
    "Bono 2 años": "US.Y2",
    "Confianza consumidor": "US.CONSUMER_CONFIDENCE",
    "Volatilidad (VIX)": "US.VIX",
    "Actividad manufacturera (Chicago Fed)": "US.CHI_MFG",
    "Spread crédito High Yield (OAS)": "US.HY_SPREAD",

  };


  final Map<String, String> _fredSeries = const {
    "US.GDP": "GDP",
    "US.UNRATE": "UNRATE",
    "US.CPI": "CPIAUCSL",
    "US.PPI": "PPIACO",
    "US.INTERESTRATE": "FEDFUNDS",
    "US.Y10": "DGS10",
    "US.Y2": "DGS2",
    "US.CONSUMER_CONFIDENCE": "UMCSENT",
    "US.VIX": "VIXCLS",
    "US.CHI_MFG": "CFSBCACTIVITYMFG",
    "US.HY_SPREAD": "BAMLH0A0HYM2",

  };

  // Series que deben pedirse en YoY % (units=pc1)
  final Set<String> _seriesYoY = const {"US.GDP", "US.CPI", "US.PPI"};

  final Map<String, String> _explicaciones = {
    "PIB (GDP)": """
📊 PIB (Producto Interior Bruto)
Mide cuánto crece o se reduce la economía.
- Si es positivo → la economía está creciendo, buen entorno para empresas.
- Si es negativo → la economía está en recesión, riesgo para los mercados.
- Cerca de 0 → señal de estancamiento (ni crece ni empeora).
""",
    "Desempleo": """
👷 Desempleo
Mide qué % de personas busca trabajo y no lo encuentra.
- < 5% → mercado laboral fuerte, estabilidad.
- 5–7% → situación intermedia.
- > 7% → mucho paro, posible enfriamiento económico.
""",
    "Inflación (CPI)": """
💸 Inflación (CPI)
Mide cuánto suben los precios de lo que compramos.
- < 3% → inflación controlada.
- 3–6% → precios suben rápido, pero aún manejable.
- > 6% → inflación muy alta, erosiona salarios y ahorros.
""",
    "Precios Productor (PPI)": """
🏭 Precios al productor (PPI)
Mide cuánto suben los precios en las fábricas.
- En aumento → los costes suben, pronto podrían subir precios al consumidor.
- En descenso → alivio, los precios finales pueden moderarse.
""",
    "Tipos interés Fed": """
🏦 Tipos de interés de la Fed
Es el tipo de referencia que marca la Fed para préstamos entre bancos.
👉 A partir de ahí, los bancos deciden hipotecas y préstamos a familias/empresas.
- < 3% → dinero barato, fomenta pedir préstamos e invertir.
- 3–5% → nivel neutral, equilibrio entre crecimiento y control de precios.
- > 5% → dinero caro, encarece los préstamos y puede frenar la economía.
""",
    "Bono 10 años": """
💵 Bono a 10 años (Treasury 10Y)
Interés que paga EE. UU. por endeudarse a largo plazo.
- Normal: entre 2% y 4%.
- > 4% → los inversores exigen más rentabilidad (riesgo/expectativa de inflación).
- < 2% → búsqueda de seguridad y/o expectativas de crecimiento débil.
👉 Compararlo con el 2 años: si el 10Y paga MENOS que el 2Y (“curva invertida”), suele anticipar recesiones.
""",
    "Bono 2 años": """
💵 Bono a 2 años (Treasury 2Y)
Interés a corto plazo muy sensible a la política de la Fed.
- Normal: entre 2% y 3%.
- > 4% → el mercado anticipa tipos altos (o más tiempo altos).
- < 2% → el mercado anticipa bajadas de tipos.
""",
    "Confianza consumidor": """
🛒 Confianza del consumidor
Mide si la gente ve el futuro económico con optimismo o pesimismo.
- > 90 → alta confianza, consumo fuerte.
- 70–90 → neutral.
- < 70 → la gente teme gastar, riesgo de recesión.
""",
    "Volatilidad (VIX)": """
📉 VIX (índice del miedo)
Mide el nivel de nerviosismo en los mercados.
- < 10 → complacencia; los inversores están muy confiados (riesgo de “techo”).
- 10–30 → rango normal.
- 30–50 → miedo alto; suelen aparecer oportunidades.
- > 50 → pánico; a menudo coincide con suelos de mercado.
""",
    "Actividad manufacturera (Chicago Fed)": """
⚙️ Actividad manufacturera (Chicago Fed)
Índice centrado en 0 que resume la actividad del sector en el Distrito 7 (Chicago).
- > 0 → expansión respecto a la tendencia.
- 0 ±5 → zona neutra/ruido.
- < 0 → contracción.
Se publica mensualmente. No es un porcentaje, es un índice.
""",
"Spread crédito High Yield (OAS)": """
💳 Spread de crédito High Yield (OAS)
Prima extra (en puntos) frente al Tesoro que exigen para prestar a empresas HY.
Cuanto más alto, más tensión financiera y peor para la renta variable.

Guía rápida:
- < 3.0  → muy bajo (condiciones holgadas, pro-riesgo)
- 3.0–6.0 → normal (equilibrio)
- > 6.0  → estrés elevado (riesgo de caídas)
- > 10.0 → crisis/tensión extrema
""",

  };

String _explicacionIndicadorConFormula(String nombre) {
  final base = _explicaciones[nombre] ?? "";
  final valor = valores[nombre];

  // ¿Este indicador usa fórmula (está en _cfg)?
  final cfg = _cfg.firstWhere(
    (c) => c.code == nombre,
    orElse: () => const IndCfg("", "", 0, 0),
  );
  final usaFormula = cfg.code.isNotEmpty;

  // Caso sin fórmula → solo valor actual
  if (!usaFormula) {
    final valTxt = valor == null ? "—" : _formateaValor(nombre, valor);
    return "$base\n\nResultado actual: $valTxt";
  }

  // Caso con fórmula → necesitamos Stat
  final st = _stats[nombre];
  if (st == null) {
    final valTxt = valor == null ? "—" : _formateaValor(nombre, valor);
    return "$base\n\nResultado actual: $valTxt\n\nInterpretación: aún sin calcular (falta histórico).";
  }

  // Valor formateado
  final valTxt = valor == null ? "—" : _formateaValor(nombre, valor);

  // Etiqueta visual (como ya hacías)
  String etiqueta;
  if (st.score > 0.25)      etiqueta = "✅ favorable";
  else if (st.score < -0.25) etiqueta = "❌ desfavorable";
  else                       etiqueta = "⚠️ neutro";

  // Texto “limpio” para la lógica SP500
  String interpretacionMacro;
  if (st.score > 0.25)      interpretacionMacro = "Favorable";
  else if (st.score < -0.25) interpretacionMacro = "Riesgo";
  else                       interpretacionMacro = "Neutro";

  // Descripciones de z y trendZ
  String descZ;
  final az = st.z.abs();
  if (az < 0.5) descZ = "similar a su media histórica";
  else if (az < 1.0) descZ = st.z > 0 ? "algo por encima de su media" : "algo por debajo de su media";
  else if (az < 2.0) descZ = st.z > 0 ? "bastante por encima de su media" : "bastante por debajo de su media";
  else descZ = st.z > 0 ? "muy por encima de su media" : "muy por debajo de su media";

  String descT;
  final at = st.trendZ.abs();
  if (at < 0.5) descT = "sin tendencia clara en los últimos 3 meses";
  else if (at < 1.0) descT = st.trendZ > 0 ? "acelerando ligeramente" : "frenando ligeramente";
  else if (at < 2.0) descT = st.trendZ > 0 ? "acelerando con fuerza" : "frenando con fuerza";
  else descT = st.trendZ > 0 ? "aceleración muy fuerte" : "desaceleración muy fuerte";

  // 🚀 Interpretación extra combinada con S&P500 (usa las 4 vars del estado)
  final extraInterpretacion = _interpretaMacroConSP500(
    interpretacionMacro,
    _spxRevalPctActual,
    _spxDevalPctActualAbs,
    _spxBullAvgRet10y,
    _spxBearAvgDD10y,
  );

  return """
$base

Resultado actual: $valTxt
Interpretación del modelo: $etiqueta
$extraInterpretacion

Motivo:
- Nivel: $descZ (z = ${st.z.toStringAsFixed(2)})
- Tendencia: $descT (trendZ = ${st.trendZ.toStringAsFixed(2)})
- Señal compuesta: ${st.score.toStringAsFixed(2)}
""";
}



  // ===== Config de señal predictiva =====
  static const double _alphaNivel = 0.7; // peso del nivel (z-score)
  static const double _alphaTrend = 0.3; // peso del momentum 3m
  static const double _pesoCurva  = 0.25;

  final List<IndCfg> _cfg = const [
  IndCfg("PIB (GDP)", "US.GDP", 1, 0.12, yoy:true),
  IndCfg("Desempleo", "US.UNRATE", -1, 0.15),
  IndCfg("Inflación (CPI)", "US.CPI", -1, 0.11, yoy:true),
  IndCfg("Precios Productor (PPI)", "US.PPI", -1, 0.02, yoy:true),
  IndCfg("Confianza consumidor", "US.CONSUMER_CONFIDENCE", 1, 0.10),
  IndCfg("Volatilidad (VIX)", "US.VIX", -1, 0.06),
  IndCfg("Actividad manufacturera (Chicago Fed)", "US.CHI_MFG", 1, 0.05),
  IndCfg("Spread crédito High Yield (OAS)", "US.HY_SPREAD", -1, 0.12),
];


  // ===== Estado =====
  Map<String, double?> valores = {};
  Map<String, String> diagnosticos = {};
  Map<String, Stat> _stats = {};
  Stat? _statCurva;
  double _scoreTotal = 0;
  int puntuacionTotal = 0;
  String? _ultimaActualizacion;
  // --- SP500 (placeholder: cámbialas por tus variables reales) ---
double _spxRevalPctActual    = 0.0; // % reval. tramo alcista actual (ej. 22.5)
double _spxDevalPctActualAbs = 0.0; // % caída tramo bajista actual en POSITIVO (ej. 28.0 = -28%)
double _spxBullAvgRet10y     = 0.0; // media reval. bull 10y
double _spxBearAvgDD10y      = 0.0; // media drawdown bear 10y

double? _ultimoSpreadPP;   // spread actual 10Y-2Y en puntos porcentuales
double _spxCurrentDays      = 0.0; // días del tramo actual
double _spxBullAvgDays10y   = 0.0; // media días bull 10y
double _spxBearAvgDays10y   = 0.0; // media días bear 10y
int _spxUseHorizon          = 10;  // 10 o 25

// (opcional si vas a usar 25 años desde aquí)
double _spxBullAvgRet25y    = 0.0;
double _spxBullAvgDays25y   = 0.0;
double _spxBearAvgDD25y     = 0.0;
double _spxBearAvgDays25y   = 0.0;

  // Convierte Favorable/Neutro/Riesgo o "Macro X" a las claves del mapa
String _macroKey(String macro) {
  final m = macro.trim().toLowerCase();
  if (m.contains('favorable') || m.contains('alcista')) return 'Macro alcista';
  if (m.contains('riesgo')    || m.contains('bajista'))  return 'Macro bajista';
  return 'Macro neutro';
}

// Normaliza el texto que devuelve _escenarioCortoSpx a una de las 4 fases de la tabla
String _normalizaFase(String raw) {
  final s = raw.trim().toLowerCase();
  final esAlcista = s.contains('alcista') || s.contains('bull');
  final esBajista = s.contains('bajista') || s.contains('bear');
  final extendido = s.contains('extend') || s.contains('techo') || s.contains('agot');

  if (esAlcista && extendido) return 'Alcista extendido';
  if (esAlcista)              return 'Alcista en desarrollo';
  if (esBajista && extendido) return 'Bajista extendido';
  if (esBajista)              return 'Bajista en desarrollo';
  // Fallback simple por estado actual:
  return (_spxDevalPctActualAbs > 0) ? 'Bajista en desarrollo' : 'Alcista en desarrollo';
}

// Devuelve el texto de la TABLA (Macro × SPX)
String _detalleEscenarioSpxTabla(String macroEntrada) {
  final macroKey = _macroKey(macroEntrada);
  final faseRaw  = _escenarioCortoSpx(macroEntrada); // ya lo usas en la Card
  final spxKey   = _normalizaFase(faseRaw);
  return escenariosMacroSpx[macroKey]?[spxKey]
      ?? 'Sin escenario definido para esta combinación.';
}


  bool _cargando = false;
  late final http.Client _client;

  // ===== Helpers de formateo =====
  bool _mostrarPorcentaje(String nombre) {
    return nombre == "PIB (GDP)" ||
        nombre == "Inflación (CPI)" ||
        nombre == "Precios Productor (PPI)" ||
        nombre == "Desempleo" ||
        nombre == "Tipos interés Fed" ||
        nombre == "Bono 10 años" ||
        nombre == "Bono 2 años";
        nombre == "Spread crédito High Yield (OAS)"; // ← añade esto
  }

String _formateaValor(String nombre, double v) {
  // HY: siempre con “%”
  if (nombre.trim() == "Spread crédito High Yield (OAS)") {
    return "${v.toStringAsFixed(2)}%";
  }
  return _mostrarPorcentaje(nombre)
      ? "${v.toStringAsFixed(2)}%"
      : v.toStringAsFixed(2);
}

  // ===== Normalización / utilidades =====
  List<double> _winsor(List<double> x) {
    if (x.length < 10) return x;
    final s = [...x]..sort();
    double q(double p) {
      final i = (p * (s.length - 1)).clamp(0, s.length - 1).toDouble();
      final lo = i.floor(), hi = i.ceil();
      if (lo == hi) return s[lo];
      final t = i - lo;
      return s[lo]*(1-t) + s[hi]*t;
    }
    final lo = q(0.01), hi = q(0.99);
    return x.map((v) => v.clamp(lo, hi)).cast<double>().toList();
  }
// Filtra la serie histórica a los últimos N años (según fecha) para calcular medias/σ.
// Si years <= 0, devuelve la serie completa.
List<Map<String, dynamic>> _filtrarVentanaAnios(
  List<Map<String, dynamic>> hist,
  int years,
) {
  if (years <= 0) return hist;
  final cutoff = DateTime.now().subtract(Duration(days: 365 * years));
  return hist.where((e) {
    final d = e["date"] as DateTime?;
    return d != null && d.isAfter(cutoff);
  }).toList();
}


  double _z(double v, double m, double sd) => sd > 0 ? (v - m) / sd : 0.0;
  double _tanh(double x) { final e2x = math.exp(2*x); return (e2x - 1)/(e2x + 1); }
String _escenarioCortoSpx(String macro) {
  // Elegimos el horizonte de comparación (por ahora 10y)
  final bullRet = (_spxUseHorizon == 25) ? (_spxBullAvgRet25y > 0 ? _spxBullAvgRet25y : _spxBullAvgRet10y)
                                         : _spxBullAvgRet10y;
  final bullDays = (_spxUseHorizon == 25) ? (_spxBullAvgDays25y > 0 ? _spxBullAvgDays25y : _spxBullAvgDays10y)
                                          : _spxBullAvgDays10y;
  final bearDD = (_spxUseHorizon == 25) ? (_spxBearAvgDD25y > 0 ? _spxBearAvgDD25y : _spxBearAvgDD10y)
                                        : _spxBearAvgDD10y;
  final bearDays = (_spxUseHorizon == 25) ? (_spxBearAvgDays25y > 0 ? _spxBearAvgDays25y : _spxBearAvgDays10y)
                                          : _spxBearAvgDays10y;

  const near = 0.9; // “cerca de la media” = 90%

  final esAlcista = _spxRevalPctActual > 0.0 && _spxDevalPctActualAbs == 0.0;
  final esBajista = _spxDevalPctActualAbs > 0.0;

  if (esAlcista) {
    final superaMedia = (_spxRevalPctActual >= bullRet) || (_spxCurrentDays >= bullDays);
    final cercaMedia  = (_spxRevalPctActual >= bullRet * near) || (_spxCurrentDays >= bullDays * near);

    if (superaMedia) return "⏳ Posible techo";
    if (cercaMedia)  return "⚠️ Alcista extendido";
    return "🚀 Tramo alcista con recorrido";
  }

  if (esBajista) {
    final alcanzaBear = (_spxDevalPctActualAbs >= bearDD) || (_spxCurrentDays >= bearDays);
    if (alcanzaBear) return "📉 Corrección en marcha";
    return "🤔 Entorno mixto";
  }

  return "🤔 Entorno mixto";
}

String _detalleEscenarioSpx(String macro) {
  final horizonTxt = "${_spxUseHorizon} años";

  final esAlcista = _spxRevalPctActual > 0.0 && _spxDevalPctActualAbs == 0.0;
  final esBajista = _spxDevalPctActualAbs > 0.0;

  if (esAlcista) {
    final bullRet  = (_spxUseHorizon == 25) ? (_spxBullAvgRet25y > 0 ? _spxBullAvgRet25y : _spxBullAvgRet10y)
                                            : _spxBullAvgRet10y;
    final bullDays = (_spxUseHorizon == 25) ? (_spxBullAvgDays25y > 0 ? _spxBullAvgDays25y : _spxBullAvgDays10y)
                                            : _spxBullAvgDays10y;

    final supera = (_spxRevalPctActual >= bullRet) || (_spxCurrentDays >= bullDays);
    final cerca  = (_spxRevalPctActual >= bullRet * 0.9) || (_spxCurrentDays >= bullDays * 0.9);

    if (supera) {
      return """



⏳ Posible techo
- Macro: $macro.
- S&P500: +${_spxRevalPctActual.toStringAsFixed(1)}% en ${_spxCurrentDays.toStringAsFixed(0)} días.
- Comparación: ya ha superado medias históricas de +${bullRet.toStringAsFixed(1)}% / ${bullDays.toStringAsFixed(0)} días ($horizonTxt).
📌 Podría estar formándose un techo de mercado.
""";
    } else if (cerca) {
      return """
⚠️ Alcista extendido
- Macro: $macro.
- S&P500: +${_spxRevalPctActual.toStringAsFixed(1)}% en ${_spxCurrentDays.toStringAsFixed(0)} días.
- Comparación: muy cerca de la media histórica de +${bullRet.toStringAsFixed(1)}% / ${bullDays.toStringAsFixed(0)} días ($horizonTxt).
📌 El ciclo está maduro, se reduce el margen de subida.
""";
    } else {
      return """
🚀 Tramo alcista con recorrido
- Macro: $macro.
- S&P500: +${_spxRevalPctActual.toStringAsFixed(1)}% en ${_spxCurrentDays.toStringAsFixed(0)} días.
- Comparación: por debajo de la media histórica de +${bullRet.toStringAsFixed(1)}% / ${bullDays.toStringAsFixed(0)} días ($horizonTxt).
📌 Aún queda recorrido potencial antes de agotarse el ciclo alcista.
""";
    }
  }

  if (esBajista) {
    final bearDD   = (_spxUseHorizon == 25) ? (_spxBearAvgDD25y > 0 ? _spxBearAvgDD25y : _spxBearAvgDD10y)
                                            : _spxBearAvgDD10y;
    final bearDays = (_spxUseHorizon == 25) ? (_spxBearAvgDays25y > 0 ? _spxBearAvgDays25y : _spxBearAvgDays10y)
                                            : _spxBearAvgDays10y;

    final alcanza = (_spxDevalPctActualAbs >= bearDD) || (_spxCurrentDays >= bearDays);

    if (alcanza) {
      return """
📉 Corrección en marcha
- Macro: $macro.
- S&P500: -${_spxDevalPctActualAbs.toStringAsFixed(1)}% en ${_spxCurrentDays.toStringAsFixed(0)} días.
- Comparación: en línea con la media histórica de caídas de ${bearDD.toStringAsFixed(1)}% en ${bearDays.toStringAsFixed(0)} días (${_spxUseHorizon} años).
📌 Escenario típico de mercado bajista en curso.
""";
    } else {
      return """
🤔 Entorno mixto
- Macro: $macro.
- S&P500: -${_spxDevalPctActualAbs.toStringAsFixed(1)}% en ${_spxCurrentDays.toStringAsFixed(0)} días.
- Comparación: por debajo de la media histórica de caídas de ${bearDD.toStringAsFixed(1)}% en ${bearDays.toStringAsFixed(0)} días (${_spxUseHorizon} años).
📌 Señales contradictorias, conviene precaución.
""";
    }
  }

  return """
🤔 Entorno mixto
- Macro: $macro.
- S&P500: 0% en ${_spxCurrentDays.toStringAsFixed(0)} días.
- Comparación: insuficiente para comparar con medias.
📌 Falta información para una lectura clara.
""";
}
Widget _escenariosSpxContenido(String macroEntrada) {
  final macroKeyActual = _macroKey(macroEntrada);
  final spxKeyActual   = _normalizaFase(_escenarioCortoSpx(macroEntrada));

  // Para mantener el orden Macro alcista → neutro → bajista
  const ordenMacro = ['Macro alcista', 'Macro neutro', 'Macro bajista'];

  // Texto del escenario ACTUAL (de tu tabla)
  final actualTxt = escenariosMacroSpx[macroKeyActual]?[spxKeyActual] ?? '';

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        "Escenario S&P 500",
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),

      const Text(
        "Guía de todos los escenarios (Macro × SPX):",
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),

      // --- Lista completa de los 12 escenarios ---
      for (final macroKey in ordenMacro) ...[
        const SizedBox(height: 8),
        Text(
          macroKey,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),

        for (final entry in (escenariosMacroSpx[macroKey] ?? const {}).entries)
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 6),
            child: Text(
              '${(macroKey == macroKeyActual && entry.key == spxKeyActual) ? "→ " : "• "}'
              '${entry.key}: ${entry.value}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: (macroKey == macroKeyActual && entry.key == spxKeyActual)
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ),
      ],
    ],
  );
}


String _progresoSpx() {
  final use25 = (_spxUseHorizon == 25);

  // Medias según horizonte seleccionado (si las de 25 no están, cae a 10)
  final bullRet = use25
      ? (_spxBullAvgRet25y > 0 ? _spxBullAvgRet25y : _spxBullAvgRet10y)
      : _spxBullAvgRet10y;
  final bullDays = use25
      ? (_spxBullAvgDays25y > 0 ? _spxBullAvgDays25y : _spxBullAvgDays10y)
      : _spxBullAvgDays10y;

  final bearDD = use25
      ? (_spxBearAvgDD25y > 0 ? _spxBearAvgDD25y : _spxBearAvgDD10y)
      : _spxBearAvgDD10y;
  final bearDays = use25
      ? (_spxBearAvgDays25y > 0 ? _spxBearAvgDays25y : _spxBearAvgDays10y)
      : _spxBearAvgDays10y;

  final esAlcista = _spxRevalPctActual > 0 && _spxDevalPctActualAbs == 0;
  final esBajista = _spxDevalPctActualAbs > 0;

  String sufijo = use25 ? "25a" : "10a";

  if (esAlcista) {
    final pctRest = (bullRet - _spxRevalPctActual).clamp(0, double.infinity);
    final daysRest = (bullDays - _spxCurrentDays).clamp(0, double.infinity);
    if (pctRest == 0 && daysRest == 0) {
      final pctOver = (_spxRevalPctActual - bullRet).clamp(0, double.infinity);
      final daysOver = (_spxCurrentDays - bullDays).clamp(0, double.infinity);
      if (pctOver > 0 || daysOver > 0) {
        return "⏳ Supera la media por +${pctOver.toStringAsFixed(1)}% y ${daysOver.toStringAsFixed(0)} días (${sufijo}).";
      }
      return "✅ En línea con la media (${sufijo}).";
    }
return "Queda ${pctRest.toStringAsFixed(1)}% de revalorización\n"
       "y ${daysRest.toStringAsFixed(0)} días para la media de ${sufijo}.";

  }

  if (esBajista) {
    final pctRest = (bearDD - _spxDevalPctActualAbs).clamp(0, double.infinity);
    final daysRest = (bearDays - _spxCurrentDays).clamp(0, double.infinity);
    if (pctRest == 0 && daysRest == 0) {
      final pctOver = (_spxDevalPctActualAbs - bearDD).clamp(0, double.infinity);
      final daysOver = (_spxCurrentDays - bearDays).clamp(0, double.infinity);
      if (pctOver > 0 || daysOver > 0) {
        return "⏳ Caída ya por debajo de la media en ${pctOver.toStringAsFixed(1)}% y ${daysOver.toStringAsFixed(0)} días (${sufijo}).";
      }
      return "✅ En línea con la media (${sufijo}).";
    }
    return "Queda ${pctRest.toStringAsFixed(1)}% de caída y ${daysRest.toStringAsFixed(0)} días para la media de ${sufijo}.";
  }

  return "—";
}


// 👉 Añádela aquí:
String _interpretaMacroConSP500(
  String macro,
  double revalPct,
  double devalAbs,
  double bullAvgRet10y,
  double bearAvgDD10y,
) {
  String cabecera = "Macro: $macro.";
  if (revalPct > 0 && devalAbs == 0) {
    return "$cabecera Alcista: +${revalPct.toStringAsFixed(1)}% vs media +${bullAvgRet10y.toStringAsFixed(1)}%.";
  }
  if (devalAbs > 0) {
    return "$cabecera Bajista: -${devalAbs.toStringAsFixed(1)}% vs media -${bearAvgDD10y.toStringAsFixed(1)}%.";
  }
  return "$cabecera S&P500 neutro.";
}


// Guardar cambios S&P en prefs
Future<void> _guardarSpxPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setDouble('spxRevalPctActual',    _spxRevalPctActual);
  await prefs.setDouble('spxDevalPctActualAbs', _spxDevalPctActualAbs);
  await prefs.setDouble('spxCurrentDays',       _spxCurrentDays);
  await prefs.setInt('spxUseHorizon',           _spxUseHorizon);

  await prefs.setDouble('spxBullAvgRet10y',     _spxBullAvgRet10y);
  await prefs.setDouble('spxBullAvgDays10y',    _spxBullAvgDays10y);
  await prefs.setDouble('spxBearAvgDD10y',      _spxBearAvgDD10y);
  await prefs.setDouble('spxBearAvgDays10y',    _spxBearAvgDays10y);

  // (opcional 25y)
  await prefs.setDouble('spxBullAvgRet25y',     _spxBullAvgRet25y);
  await prefs.setDouble('spxBullAvgDays25y',    _spxBullAvgDays25y);
  await prefs.setDouble('spxBearAvgDD25y',      _spxBearAvgDD25y);
  await prefs.setDouble('spxBearAvgDays25y',    _spxBearAvgDays25y);
}

// Formulario para editar datos S&P desde el popup
Future<void> _editarDatosSpx() async {
  final tramoInicial = (_spxDevalPctActualAbs > 0) ? 'Bajista' : 'Alcista';
  String tramo = tramoInicial;
  final revalCtl = TextEditingController(
    text: (_spxRevalPctActual > 0 ? _spxRevalPctActual : 0).toStringAsFixed(1),
  );
  final devalCtl = TextEditingController(
    text: (_spxDevalPctActualAbs > 0 ? _spxDevalPctActualAbs : 0).toStringAsFixed(1),
  );
  final diasCtl = TextEditingController(text: _spxCurrentDays.toStringAsFixed(0));
  int horizonte = _spxUseHorizon; // 10 o 25

  // Medias 10y/25y
  final bullRet10Ctl  = TextEditingController(text: _spxBullAvgRet10y.toStringAsFixed(1));
  final bullDays10Ctl = TextEditingController(text: _spxBullAvgDays10y.toStringAsFixed(0));
  final bearDD10Ctl   = TextEditingController(text: _spxBearAvgDD10y.toStringAsFixed(1));
  final bearDays10Ctl = TextEditingController(text: _spxBearAvgDays10y.toStringAsFixed(0));

  final bullRet25Ctl  = TextEditingController(text: _spxBullAvgRet25y.toStringAsFixed(1));
  final bullDays25Ctl = TextEditingController(text: _spxBullAvgDays25y.toStringAsFixed(0));
  final bearDD25Ctl   = TextEditingController(text: _spxBearAvgDD25y.toStringAsFixed(1));
  final bearDays25Ctl = TextEditingController(text: _spxBearAvgDays25y.toStringAsFixed(0));

  await showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSt) {
          final usa25 = (horizonte == 25);
          return AlertDialog(
            title: const Text("Editar datos S&P 500"),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tramo
                  const Text("Tramo actual"),
                  const SizedBox(height: 6),
                  DropdownButton<String>(
                    value: tramo,
                    items: const [
                      DropdownMenuItem(value: 'Alcista', child: Text('Alcista')),
                      DropdownMenuItem(value: 'Bajista', child: Text('Bajista')),
                    ],
                    onChanged: (v) => setSt(() => tramo = v ?? 'Alcista'),
                  ),
                  const SizedBox(height: 12),

                  // % tramo
                  if (tramo == 'Alcista') ...[
                    const Text("% revalorización actual (positivo)"),
                    TextField(
                      controller: revalCtl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(hintText: "ej. 22.5"),
                    ),
                  ] else ...[
                    const Text("% caída actual (positivo)"),
                    TextField(
                      controller: devalCtl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(hintText: "ej. 28.0"),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Días tramo
                  const Text("Días del tramo actual"),
                  TextField(
                    controller: diasCtl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: "ej. 180"),
                  ),
                  const SizedBox(height: 12),

                  // Horizonte
                  const Text("Horizonte de medias históricas"),
                  const SizedBox(height: 6),
                  DropdownButton<int>(
                    value: horizonte,
                    items: const [
                      DropdownMenuItem(value: 10, child: Text('10 años')),
                      DropdownMenuItem(value: 25, child: Text('25 años')),
                    ],
                    onChanged: (v) => setSt(() => horizonte = v ?? 10),
                  ),
                  const Divider(height: 24),

                  // Medias según horizonte
                  Text(usa25 ? "Medias históricas (25 años)" : "Medias históricas (10 años)"),
                  const SizedBox(height: 8),

                  if (!usa25) ...[
                    const Text("Bull market: reval media (%)"),
                    TextField(controller: bullRet10Ctl, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                    const SizedBox(height: 8),
                    const Text("Bull market: días medios"),
                    TextField(controller: bullDays10Ctl, keyboardType: TextInputType.number),
                    const SizedBox(height: 8),
                    const Text("Bear market: drawdown medio (%)"),
                    TextField(controller: bearDD10Ctl, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                    const SizedBox(height: 8),
                    const Text("Bear market: días medios"),
                    TextField(controller: bearDays10Ctl, keyboardType: TextInputType.number),
                  ] else ...[
                    const Text("Bull market: reval media (%)"),
                    TextField(controller: bullRet25Ctl, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                    const SizedBox(height: 8),
                    const Text("Bull market: días medios"),
                    TextField(controller: bullDays25Ctl, keyboardType: TextInputType.number),
                    const SizedBox(height: 8),
                    const Text("Bear market: drawdown medio (%)"),
                    TextField(controller: bearDD25Ctl, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                    const SizedBox(height: 8),
                    const Text("Bear market: días medios"),
                    TextField(controller: bearDays25Ctl, keyboardType: TextInputType.number),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("Cancelar"),
              ),
              TextButton(
                onPressed: () async {
                  // Parseo seguro
                  double parseD(String s) => double.tryParse(s.replaceAll(',', '.')) ?? 0.0;
                  final dias = double.tryParse(diasCtl.text) ?? 0.0;

                  double reval = 0, devalAbs = 0;
                  if (tramo == 'Alcista') {
                    reval = parseD(revalCtl.text).abs();
                    devalAbs = 0;
                  } else {
                    devalAbs = parseD(devalCtl.text).abs();
                    reval = 0;
                  }

                  setState(() {
                    _spxRevalPctActual    = reval;
                    _spxDevalPctActualAbs = devalAbs;
                    _spxCurrentDays       = dias;
                    _spxUseHorizon        = horizonte;

                    if (horizonte == 10) {
                      _spxBullAvgRet10y   = parseD(bullRet10Ctl.text);
                      _spxBullAvgDays10y  = double.tryParse(bullDays10Ctl.text) ?? 0.0;
                      _spxBearAvgDD10y    = parseD(bearDD10Ctl.text);
                      _spxBearAvgDays10y  = double.tryParse(bearDays10Ctl.text) ?? 0.0;
                    } else {
                      _spxBullAvgRet25y   = parseD(bullRet25Ctl.text);
                      _spxBullAvgDays25y  = double.tryParse(bullDays25Ctl.text) ?? 0.0;
                      _spxBearAvgDD25y    = parseD(bearDD25Ctl.text);
                      _spxBearAvgDays25y  = double.tryParse(bearDays25Ctl.text) ?? 0.0;
                    }
                  });

                  await _guardarSpxPrefs();
                  Navigator.of(ctx).pop();
                },
                child: const Text("Guardar"),
              ),
            ],
          );
        },
      );
    },
  );
}




  Stat? _buildStatFromHistory(List<double> hist, {required int polarity}) {
    if (hist.length < 6) return null;


    final clean = _winsor(hist);
    final mean = clean.reduce((a,b)=>a+b) / clean.length;
    final sd = math.sqrt(clean.map((v)=>math.pow(v-mean,2)).reduce((a,b)=>a+b) / (clean.length - 1));
    final last = hist.last;

    // Momentum 3m
    final mom = last - hist[hist.length - 4];
    final diffs = <double>[];
    for (int i=1;i<hist.length;i++) diffs.add(hist[i]-hist[i-1]);
    final diffsW = _winsor(diffs);
    final mD = diffsW.reduce((a,b)=>a+b)/diffsW.length;
    final sdD = math.sqrt(diffsW.map((v)=>math.pow(v-mD,2)).reduce((a,b)=>a+b)/(diffsW.length-1));

    final zNivel  = _z(last, mean, sd);
    final zTrend  = sdD > 0 ? mom / sdD : 0.0;

    final fused = _alphaNivel * zNivel + _alphaTrend * zTrend;
    final signed = fused * polarity.toDouble();
    final score = _tanh(signed);

    return Stat(last, zNivel*polarity, zTrend*polarity, score);
  }

  // -------- Fetch histórico robusto (con timeout interno) --------
  Future<List<Map<String, dynamic>>?> _fetchSeriesHistory(String code, {bool yoy=false}) async {
    final fredSeries = _fredSeries[code];
    if (fredSeries == null) return null;

    String baseUrl =
        "$_fredBase?series_id=$fredSeries&api_key=$_fredKey&file_type=json&sort_order=asc&observation_start=$_histStart";
    if (yoy) baseUrl += "&units=pc1"; // YoY %

    Future<Map<String,dynamic>?> intentar(Uri uri) async {
      try {
        final res = await _client
            .get(uri, headers: {"Accept-Encoding": "gzip"})
            .timeout(const Duration(seconds: 8)); // ⏱️ timeout por petición
        if (res.statusCode != 200) return null;
        final body = res.body;
        if (body.startsWith("Title:") || body.startsWith("<!DOCTYPE html")) return null;
        final data = jsonDecode(body);
        return (data is Map<String,dynamic>) ? data : null;
      } catch (_) { return null; }
    }

    final direct = Uri.parse(baseUrl);
    final viaJina = Uri.parse("https://r.jina.ai/$baseUrl");
    final encoded = Uri.encodeComponent(baseUrl);
    final viaAllOrigins = Uri.parse("https://api.allorigins.win/raw?url=$encoded");

    final uris = kIsWeb ? [viaJina, viaAllOrigins] : [direct, viaAllOrigins, viaJina];
    for (final u in uris) {
      final d = await intentar(u);
      if (d != null) {
        final List obs = (d["observations"] as List?) ?? [];
        final out = <Map<String, dynamic>>[];
        for (final o in obs) {
          final v = o["value"];
          if (v != null && v != ".") {
            out.add({"date": DateTime.tryParse(o["date"] ?? ""), "v": double.tryParse("$v")});
          }
        }
        return out.where((e) => e["date"] != null && e["v"] != null).toList();
      }
    }
    return null;
  }

  // ===== Señal compuesta / diagnóstico =====
  void _recalcularPuntuacionYDiagnosticosAvanzada() {
    final Map<String, String> diags = {};
    double sumaPesos = 0.0;
    double acumulado = 0.0;

    for (final c in _cfg) {
      final st = _stats[c.code];
      if (st == null) continue;

      if (st.score > 0.25) diags[c.code] = "✅ favorable";
      else if (st.score < -0.25) diags[c.code] = "❌ desfavorable";
      else diags[c.code] = "⚠️ neutro";

      if (c.weight > 0) {
        acumulado += c.weight * st.score;
        sumaPesos += c.weight;
      }
    }

   if (_statCurva != null) {
  // La puntuación compuesta usa el Stat histórico del spread
  acumulado += _pesoCurva * _statCurva!.score;
  sumaPesos += _pesoCurva;

  // La ETIQUETA visible se decide por el spread ACTUAL 10Y-2Y
  String extra = "—";
  const eps = 0.05; // 5 bps de tolerancia
  if (_ultimoSpreadPP != null) {
    final sp = _ultimoSpreadPP!;
    if (sp <= -eps)      extra = "❌ curva invertida";
    else if (sp >= eps)  extra = "✅ curva normal";
    else                 extra = "⚠️ curva plana";
  } else {
    // Fallback si no hay spread actual
    extra = _statCurva!.score > 0.25
        ? "✅ curva normal"
        : _statCurva!.score < -0.25
            ? "❌ curva invertida"
            : "⚠️ curva plana";
  }

  diags["Bono 10 años"] = [
    diags["Bono 10 años"] ?? "—",
    extra
  ].join(" · ");
}


    _scoreTotal = (sumaPesos > 0) ? (acumulado / sumaPesos).clamp(-1.0, 1.0) : 0.0;

    setState(() {
      diagnosticos = diags;
      puntuacionTotal = (_scoreTotal * 6).round();
    });
  }

String _prediccionCorreccion() {
  final p = puntuacionTotal; // rango -6..+6

  if (p >= 3) {
    return "📈 Entorno favorable (baja probabilidad de corrección)";
  } else if (p >= -2) {
    // -2, -1, 0, 1, 2
    return "⚖️ Entorno neutro (precaución)";
  } else if (p >= -5) {
    // -5, -4, -3
    return "🚨 Riesgo elevado (vigilar exposición)";
  } else {
    // -6
    return "🛑 Riesgo muy alto (probable corrección)";
  }
}


  // ===== Explicación detallada (popup) =====
  String _explicacionPuntuacionDetallada() {
    final scoreTxt = _scoreTotal.toStringAsFixed(2);
    final ultima = _ultimaActualizacion != null
        ? "\nÚltima actualización guardada: $_ultimaActualizacion"
        : "";

    return """
¿Cómo se calcula la puntuación?

La puntuación se obtiene combinando varios indicadores económicos (PIB, desempleo, inflación, tipos, confianza, VIX y actividad manufacturera de Chicago), más la curva de tipos (10 años – 2 años). Para cada indicador hacemos esto:

1) Nivel actual (z_nivel)
   Comparamos el valor actual con su media y desviación típica históricas.
   Así sabemos si está por encima o por debajo de lo “normal”.

2) Tendencia (trendZ)
   Medimos el cambio de los últimos 3 meses y lo estandarizamos para ver
   si acelera o frena.

3) Combinación nivel + tendencia
   Damos más peso al nivel actual (70%) y menos a la tendencia (30%).

4) Sentido económico (polaridad)
   Si “más alto es mejor” (p.ej., PIB) se mantiene el signo.
   Si “más alto es peor” (p.ej., desempleo, inflación, VIX) se invierte el signo.

5) Normalización común
   Convertimos el resultado a una escala entre –1 (muy negativo) y +1 (muy positivo)
   para que todos los indicadores sean comparables.

6) Resultado final
   Calculamos una media ponderada de todos los indicadores (cada uno tiene un peso)
   y añadimos la curva 10Y–2Y con su propio peso.
   Ese resultado (–1..+1) lo multiplicamos por 6 y lo redondeamos para mostrar
   un número entre –6 y +6.

Interpretación rápida
- Puntuación ≥ +3  → 📈 Entorno favorable (baja probabilidad de corrección)
- Entre -2 y +2   → ⚖️ Entorno neutro (precaución)
- Entre -5 y -3   → 🚨 Riesgo elevado (vigilar exposición)
- = -6            → 🛑 Riesgo muy alto (probable corrección)


Tu puntuación actual
- score_total (–1..+1) = $scoreTxt
- puntuación_total mostrada = $puntuacionTotal$ultima

Probabilidad predictiva
Este índice compuesto no da una probabilidad exacta, pero estudios comparables indican:
- Si todos los indicadores están claramente negativos → 70–80% de probabilidad de recesión en 6–12 meses.
- Si las señales son mixtas → 50–60%, similar al azar.
- Esto está en línea con indicadores profesionales como:
   • LEI del Conference Board (≈75% de precisión histórica).
   • Curva de tipos (50% con inversión leve, hasta 90% si la inversión es profunda).
""";
  }

  // ===== Ciclo de vida =====
  @override
  void initState() {
    super.initState();
    _client = http.Client();
    _cargarDesdePrefs(); // ← solo caché; no llama red al abrir
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _cargarDesdePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) {
      setState(() {});
      return;
    }
    final obj = jsonDecode(raw) as Map<String, dynamic>;
// --- S&P para escenario corto y popup ---
final spxDays     = prefs.getDouble('spxCurrentDays')      ?? 0.0;
final bullDays10  = prefs.getDouble('spxBullAvgDays10y')   ?? 0.0;
final bearDays10  = prefs.getDouble('spxBearAvgDays10y')   ?? 0.0;
final useHorizon  = prefs.getInt('spxUseHorizon')          ?? 10;

final spxReval   = prefs.getDouble('spxRevalPctActual')    ?? 0.0;
final spxDeval   = prefs.getDouble('spxDevalPctActualAbs') ?? 0.0;
final bullRet10  = prefs.getDouble('spxBullAvgRet10y')     ?? 0.0;
final bearDD10   = prefs.getDouble('spxBearAvgDD10y')      ?? 0.0;


// (opcional 25y)
final bullRet25   = prefs.getDouble('spxBullAvgRet25y')    ?? 0.0;
final bullDays25  = prefs.getDouble('spxBullAvgDays25y')   ?? 0.0;
final bearDD25    = prefs.getDouble('spxBearAvgDD25y')     ?? 0.0;
final bearDays25  = prefs.getDouble('spxBearAvgDays25y')   ?? 0.0;


    final vals = (obj["valores"] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v == null ? null : (v as num).toDouble()));
    final stats = <String, Stat>{};
    (obj["stats"] as Map<String, dynamic>).forEach((k, v) {
      stats[k] = Stat.fromJson(Map<String, dynamic>.from(v));
    });
    Stat? curva;
    if (obj["statCurva"] != null) curva = Stat.fromJson(Map<String, dynamic>.from(obj["statCurva"]));

    setState(() {
      valores = Map<String, double?>.from(vals);
      _stats = stats;
      _statCurva = curva;
      _scoreTotal = (obj["scoreTotal"] as num?)?.toDouble() ?? 0.0;
      puntuacionTotal = (obj["puntuacionTotal"] as num?)?.toInt() ?? 0;
      diagnosticos = Map<String, String>.from(obj["diagnosticos"] ?? {});
      _ultimaActualizacion = obj["ultimaActualizacion"] as String?;
   _spxCurrentDays    = spxDays;
_spxBullAvgDays10y = bullDays10;
_spxBearAvgDays10y = bearDays10;
_spxUseHorizon     = useHorizon;

// (opcional 25y)
_spxBullAvgRet25y  = bullRet25;
_spxBullAvgDays25y = bullDays25;
_spxBearAvgDD25y   = bearDD25;
_spxBearAvgDays25y = bearDays25;

_spxRevalPctActual    = spxReval;
_spxDevalPctActualAbs = spxDeval;
_spxBullAvgRet10y     = bullRet10;
_spxBearAvgDD10y      = bearDD10;


    });
  }

  Future<void> _guardarEnPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      "valores": valores.map((k, v) => MapEntry(k, v)),
      "stats": _stats.map((k, v) => MapEntry(k, v.toJson())),
      "statCurva": _statCurva?.toJson(),
      "scoreTotal": _scoreTotal,
      "puntuacionTotal": puntuacionTotal,
      "diagnosticos": diagnosticos,
      "ultimaActualizacion": DateTime.now().toIso8601String(),
    };
    await prefs.setString(_prefsKey, jsonEncode(payload));
  }

  // ===== Recarga con paralelización + timeouts =====
  Future<void> _recargarIndicadores({bool force = true}) async {
    if (_cargando) return;
    setState(() => _cargando = true);

    try {
      // 1) Prepara tareas en paralelo para cada indicador configurado
      final List<Future<MapEntry<String, dynamic>>> tasks = _cfg.map((c) async {
        try {
          final hist = await _fetchSeriesHistory(c.fredKey, yoy: c.yoy)
              .timeout(const Duration(seconds: 10)); // ⏱️ límite global por serie
          if (hist == null || hist.isEmpty) {
            return MapEntry<String, dynamic>(c.code, {"valor": null, "stat": null});
          }
          final histF = _filtrarVentanaAnios(hist, _ventanaAniosZ);
final series = histF.map((e)=> (e["v"] as double)).toList();
final st = _buildStatFromHistory(series, polarity: c.polarity);
final lastVal = series.isNotEmpty ? series.last : null;

          return MapEntry<String, dynamic>(c.code, {"valor": lastVal, "stat": st});
        } catch (_) {
          return MapEntry<String, dynamic>(c.code, {"valor": null, "stat": null});
        }
      }).toList();

      // 2) Curva 10Y-2Y también en paralelo
final curvaTask = () async {
  try {
    final res = await Future.wait<List<Map<String, dynamic>>?>([
      _fetchSeriesHistory("US.Y10").timeout(const Duration(seconds: 10)),
      _fetchSeriesHistory("US.Y2").timeout(const Duration(seconds: 10)),
    ]);
    final y10Hist = res[0], y2Hist = res[1];
if (y10Hist != null && y2Hist != null && y10Hist.isNotEmpty && y2Hist.isNotEmpty) {
  // Filtra ventana en cada pata
  final y10F = _filtrarVentanaAnios(y10Hist, _ventanaAniosZ);
  final y2F  = _filtrarVentanaAnios(y2Hist,  _ventanaAniosZ);

  if (y10F.isEmpty || y2F.isEmpty) return null;

  // Alinea por longitud mínima (mismo enfoque que ya usabas)
  final n = math.min(y10F.length, y2F.length).toInt();
  final s10 = y10F.sublist(y10F.length - n).map((e)=> e["v"] as double).toList();
  final s2  = y2F .sublist(y2F .length - n).map((e)=> e["v"] as double).toList();

  final spread = List<double>.generate(n, (i) => s10[i] - s2[i]); // 10Y - 2Y ✅
  final stat = _buildStatFromHistory(spread, polarity: 1);        // para puntuar
  final lastSpread = spread.isNotEmpty ? spread.last : null;       // para etiquetar
  return {"stat": stat, "last": lastSpread};
}

  } catch (_) {}
  return null;
}();



      // 3) Ejecuta todo en paralelo
      final results = await Future.wait(tasks);
      final curvaRes = await curvaTask;


      // 4) Aplica resultados
      final nuevosValores = <String, double?>{};
      final nuevosStats   = <String, Stat>{};

      for (final r in results) {
        final nombre = r.key;
        final obj = r.value as Map<String, dynamic>;
        final val = obj["valor"] as double?;
        final st  = obj["stat"] as Stat?;
        nuevosValores[nombre] = val;
        if (st != null) nuevosStats[nombre] = st;
      }

// === 2bis) Extras para mostrar en la UI (aunque no puntúen) ===
// (PPI ya se carga vía _cfg; aquí solo Fed, 10Y y 2Y)
try {
  final extras = await Future.wait<List<Map<String, dynamic>>?>([
    _fetchSeriesHistory("US.INTERESTRATE").timeout(const Duration(seconds: 10)),
    _fetchSeriesHistory("US.Y10").timeout(const Duration(seconds: 10)),
    _fetchSeriesHistory("US.Y2").timeout(const Duration(seconds: 10)),
  ]);

  double? lastOf(List<Map<String,dynamic>>? h) =>
      (h != null && h.isNotEmpty) ? (h.last["v"] as double?) : null;

  nuevosValores["Tipos interés Fed"] = lastOf(extras[0]);
  nuevosValores["Bono 10 años"]      = lastOf(extras[1]);
  nuevosValores["Bono 2 años"]       = lastOf(extras[2]);
} catch (_) {}


      setState(() {
        valores = {...valores, ...nuevosValores};
        _stats = nuevosStats;
        _statCurva = (curvaRes != null) ? (curvaRes["stat"] as Stat?) : null;
_ultimoSpreadPP = (curvaRes != null) ? (curvaRes["last"] as double?) : null;

      });

      _recalcularPuntuacionYDiagnosticosAvanzada();
      _ultimaActualizacion = DateTime.now().toIso8601String();
      await _guardarEnPrefs(); // guarda todo para próximo arranque
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _onRefresh() async {
    await _recargarIndicadores(force: true);
  }

  // ===== UI (idéntica + popup en Puntuación total) =====
  @override
  Widget build(BuildContext context) {
    final String macroSimple = (_scoreTotal > 0.25) ? "Favorable" : (_scoreTotal < -0.25) ? "Riesgo" : "Neutro";
final String _escenarioShort = _escenarioCortoSpx(macroSimple);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Indicadores macro"),
        actions: [
          IconButton(
            tooltip: "Actualizar ahora",
            onPressed: _cargando ? null : () => _recargarIndicadores(force: true),
            icon: _cargando
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: "Actualizar ahora",
        onPressed: _cargando ? null : () => _recargarIndicadores(force: true),
        child: _cargando
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.refresh),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
  children: [
    const Text("Ventana para z-score: "),
    const SizedBox(width: 12),
   DropdownButtonHideUnderline(
  child: DropdownButton<int>(
    value: _ventanaAniosZ,
    dropdownColor: Colors.white, // color del menú desplegado
    style: const TextStyle(
      fontSize: 14,
      color: Colors.black,
    ),
    items: const [
      DropdownMenuItem(value: 0, child: Text("Todo histórico")),
      DropdownMenuItem(value: 25, child: Text("Últimos 25 años")),
      DropdownMenuItem(value: 10, child: Text("Últimos 10 años")),
    ],
    onChanged: (val) {
      if (val != null) {
        setState(() {
          _ventanaAniosZ = val;
        });
        _recargarIndicadores();
      }
    },
    // 👇 esto quita el sombreado gris del botón
    underline: SizedBox(),
    iconEnabledColor: Colors.black,
    focusColor: Colors.transparent,
  ),
),

  ],
),


            Expanded(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: indicadores.keys.map((nombre) {
                    final valor = valores[nombre];
                    final diag = diagnosticos[nombre] ?? "";
                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        title: Text(
                          nombre,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          diag,
                          style: TextStyle(
                            color: diag.contains("✅")
                                ? Colors.green
                                : diag.contains("❌")
                                    ? Colors.red
                                    : Colors.orange,
                          ),
                        ),
                        trailing: valor == null
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                _formateaValor(nombre, valor),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(nombre),
                             content: SingleChildScrollView(
  child: SelectableText(
    _explicacionIndicadorConFormula(nombre),
    style: const TextStyle(height: 1.3),
  ),
),

                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text("Cerrar"),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
           const SizedBox(height: 16),

// === Bloques Macro + S&P 500 en paralelo (responsivo) ===
LayoutBuilder(
  builder: (context, constraints) {
    final wide = constraints.maxWidth >= 720;

    // --- Tarjeta MACRO ---
    final macroCard = GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Cómo se calcula la puntuación"),
            content: SingleChildScrollView(
              child: SelectableText(
                _explicacionPuntuacionDetallada(),
                style: const TextStyle(height: 1.3),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Cerrar"),
              ),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blueGrey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blueGrey, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text("📊 Puntuación macro (modelo)",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text("Puntuación: $puntuacionTotal",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              _prediccionCorreccion(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );

    // --- Tarjeta S&P500 ---
    final spxCard = GestureDetector(
      onTap: () {
        final String macroSimple =
            (_scoreTotal > 0.25) ? "Favorable" : (_scoreTotal < -0.25) ? "Riesgo" : "Neutro";
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Escenario S&P 500"),
            content: SingleChildScrollView(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Frase corta Macro + S&P
      Text(
        _interpretaMacroConSP500(
          macroSimple,
          _spxRevalPctActual,
          _spxDevalPctActualAbs,
          _spxBullAvgRet10y,
          _spxBearAvgDD10y,
        ),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),

      // 👇 Aquí añadimos los días
      Text(
        _progresoSpx(),
        style: const TextStyle(fontSize: 13),
      ),
      const SizedBox(height: 12),

      // Tabla de escenarios completa
      _escenariosSpxContenido(macroSimple),
    ],
  ),
),




            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Cerrar"),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _editarDatosSpx();
                },
                child: const Text("✏️ Editar datos S&P 500"),
              ),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text("📈 S&P 500 (ciclo actual)",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              _escenarioCortoSpx(
                  (_scoreTotal > 0.25) ? "Favorable" : (_scoreTotal < -0.25) ? "Riesgo" : "Neutro"),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 6),
Text(
  _progresoSpx(),
  
  textAlign: TextAlign.center,
  style: const TextStyle(fontSize: 13),
  
),




          ],
        ),
      ),
    );

final cardW = 380.0; // Tamaño fijo para tarjetas
final isWide = constraints.maxWidth >= 900;

if (isWide) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      IntrinsicHeight(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(child: macroCard, fit: FlexFit.tight),
            const SizedBox(width: 16),
            Flexible(child: spxCard, fit: FlexFit.tight),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Container(
        width: cardW * 2 + 16, // Ajustado al ancho de ambas tarjetas
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: Text(
  _detalleEscenarioSpxTabla(macroSimple), // ← mixto Macro + S&P
  textAlign: TextAlign.center,
  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
),

      ),
    ],
  );
}

// En pantallas estrechas: apiladas
return Column(
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    macroCard,
    const SizedBox(height: 12),
    spxCard,
    const SizedBox(height: 16),
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Text(
        _escenarioCortoSpx(macroSimple),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
  ],
);




  },
),

        
                   ],
        ),
      ),
    );
  }
}
