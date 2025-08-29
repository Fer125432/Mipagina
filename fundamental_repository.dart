// === Repositorio FMP: endpoints nuevos "stable" + caché en memoria ===
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:mi_finanzas_reset/fundamental_models.dart';
import 'package:mi_finanzas_reset/fundamental_calcs.dart';

class FmpRepository {
  final String apiKey;

  /// Base actual de FMP (sustituye a /api/v3)
  /// Ej: https://financialmodelingprep.com/stable/income-statement?symbol=AAPL&apikey=...
  final String baseUrl;

  /// Caché en memoria por ticker (evita repetir llamadas)
  final Map<String, FundamentalSeries> _cache = {};

  FmpRepository({
    required this.apiKey,
    this.baseUrl = "https://financialmodelingprep.com/stable",
  });

  /// Devuelve la serie desde caché si existe; si no, descarga y cachea.
  Future<FundamentalSeries> fetchFundamentals(String ticker) async {
    final hit = _cache[ticker];
    if (hit != null) return hit;

    final inc = await _get("$baseUrl/income-statement?symbol=$ticker&period=annual&limit=5&apikey=$apiKey");
    final bal = await _get("$baseUrl/balance-sheet-statement?symbol=$ticker&period=annual&limit=5&apikey=$apiKey");
    final cfs = await _get("$baseUrl/cash-flow-statement?symbol=$ticker&period=annual&limit=5&apikey=$apiKey");
    final kms = await _get("$baseUrl/key-metrics?symbol=$ticker&period=annual&limit=5&apikey=$apiKey");

    final series = _buildSeriesFromRaw(ticker, inc: inc, bal: bal, cfs: cfs, kms: kms);
    _cache[ticker] = series;
    return series;
  }

  /// Fuerza recarga desde red (ignora caché) y actualiza el caché.
  Future<FundamentalSeries> refreshFundamentals(String ticker) async {
    _cache.remove(ticker);
    return fetchFundamentals(ticker);
  }

  /// (Opcional) Limpia todo el caché
  void clearCache() => _cache.clear();

  // ----------------- Helpers -----------------

  FundamentalSeries _buildSeriesFromRaw(
    String ticker, {
    required dynamic inc,
    required dynamic bal,
    required dynamic cfs,
    required dynamic kms,
  }) {
    // FMP devuelve más reciente primero. Pasamos a cronológico.
    List<Map<String, dynamic>> incL = _asList(inc).reversed.toList();
    List<Map<String, dynamic>> balL = _asList(bal).reversed.toList();
    List<Map<String, dynamic>> cfsL = _asList(cfs).reversed.toList();
    List<Map<String, dynamic>> kmsL = _asList(kms).reversed.toList();

    // Unimos por año
    final Map<int, YearlyFundamentals> byYear = {};

    void mergeIncome(Map<String, dynamic> m) {
      final y = _yearOf(m);
      if (y == null) return;
      final prev = byYear[y];
      byYear[y] = (prev ?? YearlyFundamentals(year: y)).copyWith(
        revenue: _d(m['revenue']),
        cogs: _d(m['costOfRevenue']),
        netIncome: _d(m['netIncome']),
        epsDiluted: _d(m['epsdiluted'] ?? m['epsDiluted'] ?? m['eps']),
        sharesDiluted: _d(m['weightedAverageShsOutDil'] ?? m['weightedAverageShsOutDiluted']),
      );
    }

    void mergeBalance(Map<String, dynamic> m) {
      final y = _yearOf(m);
      if (y == null) return;
      final prev = byYear[y];
      byYear[y] = (prev ?? YearlyFundamentals(year: y)).copyWith(
        totalAssets: _d(m['totalAssets']),
        totalLiabilities: _d(m['totalLiabilities']),
        longTermDebt: _d(m['longTermDebt'] ?? m['longTermDebtNoncurrent']),
        equity: _d(m['totalStockholdersEquity'] ?? m['totalEquity']),
        cash: _d(m['cashAndCashEquivalents'] ?? m['cashAndShortTermInvestments']),
        shortTermDebt: _d(m['shortTermDebt'] ?? m['currentDebt']),
      );
    }

    void mergeCashFlow(Map<String, dynamic> m) {
      final y = _yearOf(m);
      if (y == null) return;
      final prev = byYear[y];
      byYear[y] = (prev ?? YearlyFundamentals(year: y)).copyWith(
        cfo: _d(m['netCashProvidedByOperatingActivities'] ?? m['operatingCashFlow']),
        capex: _d(m['capitalExpenditure']),
      );
    }

    void mergeKeyMetrics(Map<String, dynamic> m) {
      final y = _yearOf(m);
      if (y == null) return;
      final prev = byYear[y];
      byYear[y] = (prev ?? YearlyFundamentals(year: y)).copyWith(
        marketCap: _d(m['marketCap'] ?? m['marketCapTTM']),
      );
    }

    for (final m in incL) mergeIncome(m);
    for (final m in balL) mergeBalance(m);
    for (final m in cfsL) mergeCashFlow(m);
    for (final m in kmsL) mergeKeyMetrics(m);

    // Calculados por año
    final List<int> years = byYear.keys.toList()..sort();
    final List<YearlyFundamentals> rows = [];

    for (final y in years) {
      final r0 = byYear[y]!;
      final gm = grossMarginPct(r0.revenue, r0.cogs);
      final nm = netMarginPct(r0.netIncome, r0.revenue);
      final fcf = computeFcf(r0.cfo, r0.capex);
      final fps = fcfPerShare(fcf, r0.sharesDiluted);
      final nd  = netDebt(r0.shortTermDebt, r0.longTermDebt, r0.cash);

      final tmp = r0.copyWith(
        grossMarginPct: gm,
        netMarginPct: nm,
        fcf: fcf,
        fcfPerShare: fps,
        netDebt: nd,
      );

      final ratios = buildRatiosYear(y: tmp);
      rows.add(tmp.copyWith(ratios: ratios));
    }

    // Podar a 5 años (por si vienen más)
    final pruned = rows.where((e) => e.year >= 2000).toList();
    final ys = pruned.length <= 5 ? pruned : pruned.sublist(pruned.length - 5);

    // Agregados
    double? c(List<double?> s) => cagrFromSeries(s);
    double? avg(List<double?> s) => averageOf(s);

    final agg = FundamentalAggregates(
      revenueCagr:     c(ys.map((e) => e.revenue).toList()),
      cogsCagr:        c(ys.map((e) => e.cogs).toList()),
      netIncomeCagr:   c(ys.map((e) => e.netIncome).toList()),
      epsCagr:         c(ys.map((e) => e.epsDiluted).toList()),
      assetsCagr:      c(ys.map((e) => e.totalAssets).toList()),
      liabilitiesCagr: c(ys.map((e) => e.totalLiabilities).toList()),
      ltDebtCagr:      c(ys.map((e) => e.longTermDebt).toList()),
      equityCagr:      c(ys.map((e) => e.equity).toList()),
      fcfCagr:         c(ys.map((e) => e.fcf).toList()),
      fcfPerShareCagr: c(ys.map((e) => e.fcfPerShare).toList()),
      netDebtCagr:     c(ys.map((e) => e.netDebt).toList()),
      sharesCagr:      c(ys.map((e) => e.sharesDiluted).toList()),
      mktCapCagr:      c(ys.map((e) => e.marketCap).toList()),
      grossMarginAvg:  avg(ys.map((e) => e.grossMarginPct).toList()),
      netMarginAvg:    avg(ys.map((e) => e.netMarginPct).toList()),
      ratioAvgs:       averageRatios(ys),
      marketCapClass2024: ys.isEmpty ? null : classifyCap(ys.last.marketCap),
      ratioTraffic:    const {},
      scoreOver10:     0.0,
    );

    final traffic = trafficFromAverages(agg.ratioAvgs);
    final score = scoreOver10(traffic);

    final agg2 = FundamentalAggregates(
      revenueCagr: agg.revenueCagr,
      cogsCagr: agg.cogsCagr,
      netIncomeCagr: agg.netIncomeCagr,
      epsCagr: agg.epsCagr,
      assetsCagr: agg.assetsCagr,
      liabilitiesCagr: agg.liabilitiesCagr,
      ltDebtCagr: agg.ltDebtCagr,
      equityCagr: agg.equityCagr,
      fcfCagr: agg.fcfCagr,
      fcfPerShareCagr: agg.fcfPerShareCagr,
      netDebtCagr: agg.netDebtCagr,
      sharesCagr: agg.sharesCagr,
      mktCapCagr: agg.mktCapCagr,
      grossMarginAvg: agg.grossMarginAvg,
      netMarginAvg: agg.netMarginAvg,
      ratioAvgs: agg.ratioAvgs,
      marketCapClass2024: agg.marketCapClass2024,
      ratioTraffic: traffic,
      scoreOver10: score,
    );

    return FundamentalSeries(ticker: ticker, years: ys, agg: agg2);
  }

  // ---- HTTP helper con manejo 403/429 legible
  Future<dynamic> _get(String url) async {
    final r = await http.get(Uri.parse(url));
    if (r.statusCode == 403) {
      throw Exception(
        'FMP 403: Endpoint no disponible en el plan actual. Usa endpoints "stable" y verifica tu plan.',
      );
    }
    if (r.statusCode == 429) {
      throw Exception('FMP 429: Límite de peticiones alcanzado.');
    }
    if (r.statusCode != 200) {
      throw Exception("FMP ${r.statusCode}: ${r.body}");
    }
    return json.decode(r.body);
  }

  List<Map<String, dynamic>> _asList(dynamic body) {
    if (body is List) {
      return body.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  int? _yearOf(Map<String, dynamic> m) {
    if (m['calendarYear'] != null) {
      final y = int.tryParse(m['calendarYear'].toString());
      if (y != null) return y;
    }
    if (m['date'] != null) {
      final s = m['date'].toString();
      if (s.length >= 4) return int.tryParse(s.substring(0, 4));
    }
    return null;
  }

  double? _d(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }
}
