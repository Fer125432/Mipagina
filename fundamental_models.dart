// === Modelos base para la página Fundamental ===
import 'package:meta/meta.dart';

enum CapClass { nano, micro, small, mid, large, mega }

@immutable
class RatioSnapshot {
  final double? assetsToLiabilities; // Assets / Liabilities
  final double? ltDebtToEquity;      // LT Debt / Equity
  final double? capexAbs;            // |CapEx|
  final double? roe;                 // Net Income / Equity
  final double? roa;                 // Net Income / Assets
  final double? roic;                // aprox: NOPAT / (Debt + Equity - Cash)
  final double? assetTurnover;       // Revenue / Assets
  final double? retention;           // 1 - (DPS / EPS)
  final double? netDebtToFcf;        // Net Debt / FCF
  final double? capexToFcf;          // CapEx / FCF

  const RatioSnapshot({
    this.assetsToLiabilities,
    this.ltDebtToEquity,
    this.capexAbs,
    this.roe,
    this.roa,
    this.roic,
    this.assetTurnover,
    this.retention,
    this.netDebtToFcf,
    this.capexToFcf,
  });
}

@immutable
class YearlyFundamentals {
  final int year;

  // Income
  final double? revenue;
  final double? cogs;
  final double? netIncome;
  final double? epsDiluted;
  final double? sharesDiluted;

  // Balance
  final double? totalAssets;
  final double? totalLiabilities;
  final double? longTermDebt;
  final double? equity;
  final double? cash;
  final double? shortTermDebt;

  // Cash Flow
  final double? cfo;   // netCashProvidedByOperatingActivities
  final double? capex; // capitalExpenditure (signo negativo en FMP)

  // Derivados por año
  final double? grossMarginPct; // (rev - cogs)/rev
  final double? netMarginPct;   // netIncome/rev
  final double? fcf;            // cfo - capex
  final double? fcfPerShare;    // fcf / sharesDiluted
  final double? netDebt;        // (short + long) - cash

  // Market Cap (histórico por año, de key-metrics)
  final double? marketCap;

  // Ratios por año
  final RatioSnapshot ratios;

  const YearlyFundamentals({
    required this.year,
    this.revenue,
    this.cogs,
    this.netIncome,
    this.epsDiluted,
    this.sharesDiluted,
    this.totalAssets,
    this.totalLiabilities,
    this.longTermDebt,
    this.equity,
    this.cash,
    this.shortTermDebt,
    this.cfo,
    this.capex,
    this.grossMarginPct,
    this.netMarginPct,
    this.fcf,
    this.fcfPerShare,
    this.netDebt,
    this.marketCap,
    this.ratios = const RatioSnapshot(),
  });

  YearlyFundamentals copyWith({
    double? revenue,
    double? cogs,
    double? netIncome,
    double? epsDiluted,
    double? sharesDiluted,
    double? totalAssets,
    double? totalLiabilities,
    double? longTermDebt,
    double? equity,
    double? cash,
    double? shortTermDebt,
    double? cfo,
    double? capex,
    double? grossMarginPct,
    double? netMarginPct,
    double? fcf,
    double? fcfPerShare,
    double? netDebt,
    double? marketCap,
    RatioSnapshot? ratios,
  }) {
    return YearlyFundamentals(
      year: year,
      revenue: revenue ?? this.revenue,
      cogs: cogs ?? this.cogs,
      netIncome: netIncome ?? this.netIncome,
      epsDiluted: epsDiluted ?? this.epsDiluted,
      sharesDiluted: sharesDiluted ?? this.sharesDiluted,
      totalAssets: totalAssets ?? this.totalAssets,
      totalLiabilities: totalLiabilities ?? this.totalLiabilities,
      longTermDebt: longTermDebt ?? this.longTermDebt,
      equity: equity ?? this.equity,
      cash: cash ?? this.cash,
      shortTermDebt: shortTermDebt ?? this.shortTermDebt,
      cfo: cfo ?? this.cfo,
      capex: capex ?? this.capex,
      grossMarginPct: grossMarginPct ?? this.grossMarginPct,
      netMarginPct: netMarginPct ?? this.netMarginPct,
      fcf: fcf ?? this.fcf,
      fcfPerShare: fcfPerShare ?? this.fcfPerShare,
      netDebt: netDebt ?? this.netDebt,
      marketCap: marketCap ?? this.marketCap,
      ratios: ratios ?? this.ratios,
    );
    }
}

@immutable
class RatioAverages {
  final double? assetsToLiabilities;
  final double? ltDebtToEquity;
  final double? capexAbs;
  final double? roe;
  final double? roa;
  final double? roic;
  final double? assetTurnover;
  final double? retention;
  final double? netDebtToFcf;
  final double? capexToFcf;

  const RatioAverages({
    this.assetsToLiabilities,
    this.ltDebtToEquity,
    this.capexAbs,
    this.roe,
    this.roa,
    this.roic,
    this.assetTurnover,
    this.retention,
    this.netDebtToFcf,
    this.capexToFcf,
  });
}

@immutable
class FundamentalAggregates {
  // CAGR (4 periodos: 2020→2024)
  final double? revenueCagr;
  final double? cogsCagr;
  final double? netIncomeCagr;
  final double? epsCagr;
  final double? assetsCagr;
  final double? liabilitiesCagr;
  final double? ltDebtCagr;
  final double? equityCagr;
  final double? fcfCagr;
  final double? fcfPerShareCagr;
  final double? netDebtCagr;
  final double? sharesCagr;
  final double? mktCapCagr;

  // Medias (5 años)
  final double? grossMarginAvg;
  final double? netMarginAvg;
  final RatioAverages ratioAvgs;

  // Clasificación cap (por 2024)
  final CapClass? marketCapClass2024;

  // Evaluación (semáforos y score /10)
  final Map<String, String> ratioTraffic; // key->"ok|warn|bad"
  final double scoreOver10;

  const FundamentalAggregates({
    this.revenueCagr,
    this.cogsCagr,
    this.netIncomeCagr,
    this.epsCagr,
    this.assetsCagr,
    this.liabilitiesCagr,
    this.ltDebtCagr,
    this.equityCagr,
    this.fcfCagr,
    this.fcfPerShareCagr,
    this.netDebtCagr,
    this.sharesCagr,
    this.mktCapCagr,
    this.grossMarginAvg,
    this.netMarginAvg,
    this.ratioAvgs = const RatioAverages(),
    this.marketCapClass2024,
    this.ratioTraffic = const {},
    this.scoreOver10 = 0.0,
  });
}

@immutable
class FundamentalSeries {
  final String ticker;
  final List<YearlyFundamentals> years; // orden cronológico: 2020..2024
  final FundamentalAggregates agg;

  const FundamentalSeries({
    required this.ticker,
    required this.years,
    required this.agg,
  });
}
