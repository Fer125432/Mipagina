// === Utilidades de cálculo: márgenes, FCF, ratios, CAGR, medias, scoring ===
import 'dart:math';
import 'fundamental_models.dart';

double? _safeDiv(num? a, num? b) {
  if (a == null || b == null) return null;
  if (b == 0) return null;
  return a.toDouble() / b.toDouble();
}

double? grossMarginPct(double? revenue, double? cogs) {
  final r = revenue; final c = cogs;
  if (r == null || r == 0 || c == null) return null;
  return ((r - c) / r) * 100.0;
}

double? netMarginPct(double? netIncome, double? revenue) {
  final r = revenue; final n = netIncome;
  if (r == null || r == 0 || n == null) return null;
  return (n / r) * 100.0;
}

double? computeFcf(double? cfo, double? capex) {
  if (cfo == null || capex == null) return null;
  // En FMP, capex suele venir NEGATIVO. Esta fórmula ya lo maneja bien:
  //   FCF = CFO - Capex  -> ej: 5_000 - (-2_000) = 7_000
  return cfo - capex;
}


double? fcfPerShare(double? fcf, double? sharesDiluted) => _safeDiv(fcf, sharesDiluted);

double? netDebt(double? shortDebt, double? longDebt, double? cash) {
  if (shortDebt == null && longDebt == null && cash == null) return null;
  final s = shortDebt ?? 0.0;
  final l = longDebt ?? 0.0;
  final c = cash ?? 0.0;
  return (s + l) - c;
}

double? cagrFromSeries(List<double?> series) {
  // Espera serie cronológica (2020..2024). Devuelve CAGR sobre N-1 periodos.
  final vals = series.whereType<double>().toList();
  if (vals.length < 2) return null;
  final first = vals.first;
  final last = vals.last;
  final periods = vals.length - 1;
  if (first <= 0 || last <= 0) return null; // indefinido si <= 0
  return pow(last / first, 1.0 / periods) - 1.0;
}

double? averageOf(List<double?> series) {
  final vals = series.whereType<double>().toList();
  if (vals.isEmpty) return null;
  final sum = vals.fold<double>(0.0, (a, b) => a + b);
  return sum / vals.length;
}

CapClass classifyCap(double? mktCapUsd) {
  final v = (mktCapUsd ?? 0).toDouble();
  if (v >= 200e9) return CapClass.mega;
  if (v >= 10e9)  return CapClass.large;
  if (v >= 2e9)   return CapClass.mid;
  if (v >= 300e6) return CapClass.small;
  if (v >= 50e6)  return CapClass.micro;
  return CapClass.nano;
}

String capClassLabel(CapClass c) {
  switch (c) {
    case CapClass.mega: return "Mega Cap";
    case CapClass.large: return "Large Cap";
    case CapClass.mid: return "Mid Cap";
    case CapClass.small: return "Small Cap";
    case CapClass.micro: return "Micro Cap";
    case CapClass.nano: return "Nano Cap";
  }
}

RatioSnapshot buildRatiosYear({
  required YearlyFundamentals y,
  double? taxRate, // opcional para ROIC (si no, aprox con 25%)
}) {
  final assetsLiab = _safeDiv(y.totalAssets, y.totalLiabilities);
  final ltdebtEq   = _safeDiv(y.longTermDebt, y.equity);
  final capexAbs   = y.capex == null ? null : (y.capex!.abs());
  final roe        = _safeDiv(y.netIncome, y.equity);
  final roa        = _safeDiv(y.netIncome, y.totalAssets);
  final assetTurn  = _safeDiv(y.revenue, y.totalAssets);

  final tr = (taxRate ?? 0.25).clamp(0.0, 0.6);
  final nopat = (y.netIncome == null) ? null : y.netIncome! * (1 - tr);
  final investedCapital = ((y.longTermDebt ?? 0) + (y.shortTermDebt ?? 0) + (y.equity ?? 0)) - (y.cash ?? 0);
  final roic = investedCapital == 0 ? null : (nopat == null ? null : nopat / investedCapital);

  // Retención: 1 - (DPS / EPS). Si no tenemos DPS, aproximable con (NI - Dividends)/NI
  double? retention;
  if (y.epsDiluted != null && y.epsDiluted! != 0 && y.sharesDiluted != null) {
    // Si más adelante inyectas DPS por año, cámbialo aquí.
    retention = null; // se calculará más tarde si hay DPS.
  }

  final netDebtFcf = _safeDiv(y.netDebt, y.fcf);
  final capexFcf   = _safeDiv(y.capex == null ? null : y.capex!.abs(), y.fcf);

  return RatioSnapshot(
    assetsToLiabilities: assetsLiab,
    ltDebtToEquity: ltdebtEq,
    capexAbs: capexAbs,
    roe: roe,
    roa: roa,
    roic: roic,
    assetTurnover: assetTurn,
    retention: retention,
    netDebtToFcf: netDebtFcf,
    capexToFcf: capexFcf,
  );
}

RatioAverages averageRatios(List<YearlyFundamentals> ys) {
  double? avg(List<double?> s) => averageOf(s);

  return RatioAverages(
    assetsToLiabilities: avg(ys.map((e) => e.ratios.assetsToLiabilities).toList()),
    ltDebtToEquity:      avg(ys.map((e) => e.ratios.ltDebtToEquity).toList()),
    capexAbs:            avg(ys.map((e) => e.ratios.capexAbs).toList()),
    roe:                 avg(ys.map((e) => e.ratios.roe).toList()),
    roa:                 avg(ys.map((e) => e.ratios.roa).toList()),
    roic:                avg(ys.map((e) => e.ratios.roic).toList()),
    assetTurnover:       avg(ys.map((e) => e.ratios.assetTurnover).toList()),
    retention:           avg(ys.map((e) => e.ratios.retention).toList()),
    netDebtToFcf:        avg(ys.map((e) => e.ratios.netDebtToFcf).toList()),
    capexToFcf:          avg(ys.map((e) => e.ratios.capexToFcf).toList()),
  );
}

Map<String, String> trafficFromAverages(RatioAverages a) {
  String tri({required double? v, required double okLo, double? okHi, required double warnLo, double? warnHi, bool lowerIsBetter = false}) {
    if (v == null) return "warn"; // sin dato: neutral
    if (!lowerIsBetter) {
      // mayor es mejor
      if (v >= okLo && (okHi == null || v <= okHi)) return "ok";
      if (v >= warnLo && (warnHi == null || v <= warnHi)) return "warn";
      return "bad";
    } else {
      // menor es mejor
      if (v <= okLo) return "ok";
      if (v <= warnLo) return "warn";
      return "bad";
    }
  }

  return {
    "assets_liabilities": tri(v: a.assetsToLiabilities, okLo: 1.0, okHi: null, warnLo: 0.9, warnHi: null),
    "ltdebt_equity":     tri(v: a.ltDebtToEquity,       okLo: 0.5, warnLo: 1.0, lowerIsBetter: true),
    "roe":               tri(v: a.roe,                  okLo: 0.15, warnLo: 0.10),
    "roa":               tri(v: a.roa,                  okLo: 0.07, warnLo: 0.03),
    "roic":              tri(v: a.roic,                 okLo: 0.10, warnLo: 0.06),
    "asset_turnover":    tri(v: a.assetTurnover,        okLo: 1.0, warnLo: 0.5),
    "retention":         (() {
                           final v = a.retention;
                           if (v == null) return "warn";
                           // ideal 30–70%
                           if (v >= 0.30 && v <= 0.70) return "ok";
                           if ((v >= 0.15 && v < 0.30) || (v > 0.70 && v <= 0.85)) return "warn";
                           return "bad";
                         })(),
    "netdebt_fcf":       tri(v: a.netDebtToFcf,         okLo: 3.0, warnLo: 5.0, lowerIsBetter: true),
    "capex_fcf":         tri(v: a.capexToFcf,           okLo: 0.5, warnLo: 1.0, lowerIsBetter: true),
    // capexAbs no puntúa; se interpreta vía capex/FCF
  };
}

double scoreOver10(Map<String, String> traffic) {
  double sum = 0.0;
  for (final v in traffic.values) {
    if (v == "ok") sum += 1.0;
    else if (v == "warn") sum += 0.5;
  }
  // 9 ratios puntuados (capexAbs no entra) => normalizar a /10
  // Nota: para una escala /10 exacta, escalamos: (sum / 9) * 10
  return (sum / 9.0) * 10.0;
}
