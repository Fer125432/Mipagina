import 'dart:convert';
import 'package:http/http.dart' as http;

class EpsEstimate {
  final int year;
  final double eps;
  EpsEstimate(this.year, this.eps);
}

void printEpsList(String source, List<EpsEstimate> rows) {
  print('--- $source ---');
  if (rows.isEmpty) {
    print('(sin datos)');
    return;
  }
  for (final r in rows) {
    print('${r.year}: ${r.eps}');
  }
}

/// ====== FMP directo ======
Future<List<EpsEstimate>> fetchFmpEpsAnnual(String symbol, String apiKey) async {
  final url = Uri.parse(
    'https://financialmodelingprep.com/stable/analyst-estimates'
    '?symbol=$symbol&period=annual&limit=10&apikey=$apiKey',
  );
  final res = await http.get(url);
  print('FMP status: ${res.statusCode}');
  if (res.statusCode != 200) {
    print(res.body);
    return [];
  }

  final data = json.decode(res.body);
  final list = (data is List) ? data : (data['data'] ?? []);
  final out = <EpsEstimate>[];

  for (final row in list) {
    final date = (row['date'] ?? row['calendarYear'] ?? '').toString();
    if (date.length < 4) continue;
    final year = int.tryParse(date.substring(0, 4));
    final epsRaw = (row['epsAvg'] ?? row['eps'] ?? row['estimatedEPS']);
    final eps = (epsRaw is num) ? epsRaw.toDouble() : null;
    if (year != null && eps != null) out.add(EpsEstimate(year, eps));
  }
  out.sort((a, b) => a.year.compareTo(b.year));
  return out;
}

/// ====== Finnhub vía proxy (Web OK) ======
Future<List<EpsEstimate>> fetchFinnhubEpsAnnualViaProxy(String symbol) async {
  final url = Uri.parse(
    'http://localhost:8787/finnhub/eps-estimates?symbol=$symbol&freq=annual',
  );
  final res = await http.get(url);
  print('Finnhub via proxy status: ${res.statusCode}');
  if (res.statusCode != 200) {
    print(res.body);
    return [];
  }

  final data = json.decode(res.body);
  final list = (data is Map && data['data'] != null) ? data['data'] : (data as List? ?? []);
  final out = <EpsEstimate>[];

  for (final row in list) {
    final year = int.tryParse(row['period']?.toString() ?? '');
    final epsRaw = (row['epsAvg'] ?? row['eps']);
    final eps = (epsRaw is num) ? epsRaw.toDouble() : null;
    if (year != null && eps != null) out.add(EpsEstimate(year, eps));
  }
  out.sort((a, b) => a.year.compareTo(b.year));
  return out;
}

/// ===== MAIN =====
Future<void> main() async {
  const symbol = 'META';
  const fmpKey = 'T2lkYSgttcYL1QpzA5kkVWCOiOQrIVny';

  // FMP
  final fmp = await fetchFmpEpsAnnual(symbol, fmpKey);
  printEpsList('FMP', fmp);

  // Finnhub vía proxy
  final fh = await fetchFinnhubEpsAnnualViaProxy(symbol);
  printEpsList('Finnhub', fh);

  print('=== Fin de pruebas ===');
}
