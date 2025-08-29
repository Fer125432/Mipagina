import 'package:flutter/foundation.dart';

import 'package:mi_finanzas_reset/fundamental_models.dart';
import 'package:mi_finanzas_reset/fundamental_calcs.dart';
import 'package:mi_finanzas_reset/fundamental_repository.dart';

enum FundState { idle, loading, ready, error }

class FundamentalController extends ChangeNotifier {
  final FmpRepository repo;

  FundState state = FundState.idle;
  String? errorMsg;

  // ==== Diagnóstico automático ====
  String _diagnostico = '';
  String get diagnostico => _diagnostico;

  // Datos del ticker activo
  FundamentalSeries? series;

  // Selección para la gráfica (claves de parámetros)
  final Set<String> selectedParams = {"revenue"}; // por defecto una línea

  FundamentalController(this.repo);

  // === Cargar datos de un ticker ===
  Future<void> load(String ticker) async {
    state = FundState.loading;
    errorMsg = null;
    series = null;
    notifyListeners();

    try {
      final s = await repo.fetchFundamentals(ticker);
      series = s;

      // Generar diagnóstico en base a la serie cargada
      _actualizarDiagnosticoDesdeSerie(s);


      state = FundState.ready;
      notifyListeners();
    } catch (e) {
      state = FundState.error;
      errorMsg = e.toString();
      notifyListeners();
    }
  }

  // === Helpers de UI ===

  /// Años disponibles (2020..2024 en orden)
  List<int> get years {
    final ys = series?.years.map((e) => e.year).toList() ?? const [];
    return ys;
  }

  /// Texto de clase de Market Cap 2024 para poner en el encabezado
  String get marketCapClassLabel {
    final c = series?.agg.marketCapClass2024;
    return c == null ? "" : capClassLabel(c);
  }

  /// Puntuación final /10 (ya calculada en el repo)
  double get scoreOver10 => series?.agg.scoreOver10 ?? 0.0;

  /// Devuelve un mapa {paramKey: valores por año} para la gráfica multi-línea.
  /// Claves soportadas (por ahora): revenue, netIncome, eps, fcf, fcfPerShare,
  /// totalAssets, totalLiabilities, longTermDebt, equity, netDebt, marketCap,
  /// grossMarginPct, netMarginPct.
  Map<String, List<double?>> chartSeries() {
    final res = <String, List<double?>>{};
    final ys = series?.years ?? const [];

    List<double?> pick(double? Function(YearlyFundamentals y) f) =>
        ys.map((y) => f(y)).toList();

    for (final key in selectedParams) {
      switch (key) {
        case "revenue":
          res[key] = pick((y) => y.revenue);
          break;
        case "cogs":
          res[key] = pick((y) => y.cogs);
          break;
        case "netIncome":
          res[key] = pick((y) => y.netIncome);
          break;
        case "eps":
          res[key] = pick((y) => y.epsDiluted);
          break;
        case "totalAssets":
          res[key] = pick((y) => y.totalAssets);
          break;
        case "totalLiabilities":
          res[key] = pick((y) => y.totalLiabilities);
          break;
        case "longTermDebt":
          res[key] = pick((y) => y.longTermDebt);
          break;
        case "equity":
          res[key] = pick((y) => y.equity);
          break;
        case "fcf":
          res[key] = pick((y) => y.fcf);
          break;
        case "fcfPerShare":
          res[key] = pick((y) => y.fcfPerShare);
          break;
        case "netDebt":
          res[key] = pick((y) => y.netDebt);
          break;
        case "marketCap":
          res[key] = pick((y) => y.marketCap);
          break;
        case "grossMarginPct":
          res[key] = pick((y) => y.grossMarginPct);
          break;
        case "netMarginPct":
          res[key] = pick((y) => y.netMarginPct);
          break;
        default:
          res[key] = const [];
      }
    }
    return res;
  }

  /// Añadir/Quitar un parámetro de la gráfica
  void toggleParam(String key) {
    if (selectedParams.contains(key)) {
      selectedParams.remove(key);
    } else {
      selectedParams.add(key);
    }
    notifyListeners();
  }

  /// Valor “resumen” para el parámetro seleccionado (para mostrar bajo la gráfica):
  /// - Absolutos → CAGR 5y
  /// - Márgenes (%) → media 5y
  double? summaryFor(String key) {
    final a = series?.agg;
    if (a == null) return null;
    switch (key) {
      case "revenue":
        return a.revenueCagr;
      case "cogs":
        return a.cogsCagr;
      case "netIncome":
        return a.netIncomeCagr;
      case "eps":
        return a.epsCagr;
      case "totalAssets":
        return a.assetsCagr;
      case "totalLiabilities":
        return a.liabilitiesCagr;
      case "longTermDebt":
        return a.ltDebtCagr;
      case "equity":
        return a.equityCagr;
      case "fcf":
        return a.fcfCagr;
      case "fcfPerShare":
        return a.fcfPerShareCagr;
      case "netDebt":
        return a.netDebtCagr;
      case "marketCap":
        return a.mktCapCagr;
      case "grossMarginPct":
        return a.grossMarginAvg; // media
      case "netMarginPct":
        return a.netMarginAvg; // media
      default:
        return null;
    }
  }

  /// Semáforos de ratios (media 5 años): key -> "ok" | "warn" | "bad"
  Map<String, String> get ratioTraffic => series?.agg.ratioTraffic ?? const {};

  // ====== NUEVO: construir diagnóstico desde la serie cargada ======
void _actualizarDiagnosticoDesdeSerie(FundamentalSeries fs) {
  final last = (fs.years.isNotEmpty) ? fs.years.last : null;

  final double? capexToRevenuePct =
      (last?.capex != null && last?.revenue != null && (last!.revenue!).abs() > 1e-9)
          ? (last.capex!.abs() / last.revenue!) * 100.0
          : null;

  _diagnostico = generarDiagnostico(
    // Crecimiento
    revenueCagr: fs.agg.revenueCagr,
    epsCagr: fs.agg.epsCagr,

    // Márgenes (medias 5 años)
    grossMarginPct: fs.agg.grossMarginAvg,
    netMarginPct: fs.agg.netMarginAvg,

    // Caja / resultado (último año)
    fcf: last?.fcf,
    cfo: last?.cfo,
    netIncome: last?.netIncome,

    // Balance / apalancamiento
    netDebt: last?.netDebt,
    longTermDebtToEquity: fs.agg.ratioAvgs.ltDebtToEquity,
    assetsToLiabilities: fs.agg.ratioAvgs.assetsToLiabilities, // 👈 añade esto

    // Inversión
    capexToRevenuePct: capexToRevenuePct,
  );
}
}

// ====== FUNCIÓN GENERADORA DEL DIAGNÓSTICO (fuera de la clase) ======
String generarDiagnostico({
  // Crecimiento
  double? revenueCagr,           // CAGR ventas
  double? epsCagr,               // CAGR BPA

  // Márgenes (medias 5y)
  double? grossMarginPct,        // %
  double? netMarginPct,          // %

  // Caja (último año)
  double? fcf,                   // Free Cash Flow
  double? cfo,                   // Cash From Operations
  double? netIncome,             // Beneficio neto

  // Deuda / estructura (último año o media 5y)
  double? netDebt,               // Deuda neta (<0 = caja neta)
  double? longTermDebtToEquity,  // Debt/Equity
  double? assetsToLiabilities,   // Assets/Liabilities (opcional si lo tienes)

  // Inversión (último año)
  double? capexToRevenuePct,     // Capex / Revenue %
}) {
  // ---------- Helpers de formato (robustos) ----------
  String _fmtPct(num? v) {
    if (v == null) return "—";
    final x = v.toDouble();
    final asPct = (x.abs() <= 1.0) ? x * 100.0 : x; // admite 0.24 ó 24
    return "${asPct.toStringAsFixed(1)}%";
  }

  String _fmtMoney(num? v) {
    if (v == null) return "—";
    final x = v.toDouble();
    final s = x < 0 ? "-" : "";
    final a = x.abs();
    if (a >= 1e12) return "${s}${(a/1e12).toStringAsFixed(2)}T";
    if (a >= 1e9)  return "${s}${(a/1e9).toStringAsFixed(2)}B";
    if (a >= 1e6)  return "${s}${(a/1e6).toStringAsFixed(2)}M";
    if (a >= 1e3)  return "${s}${(a/1e3).toStringAsFixed(1)}K";
    return "${s}${a.toStringAsFixed(0)}";
  }

  String _fmtNum(num? v, {int dec = 2}) => v == null ? "—" : v.toStringAsFixed(dec);

  String _joinSentences(List<String> parts) {
    final s = parts.where((e) => e.isNotEmpty).join('. ');
    return s.isEmpty ? '' : (s.endsWith('.') ? s : '$s.');
  }

  // ---------- Titular (claro) ----------
  String _titular() {
    final cre =
        (revenueCagr != null && revenueCagr! >= 0.15) || (epsCagr != null && epsCagr! >= 0.20)
            ? "Crecimiento alto"
            : (revenueCagr != null && revenueCagr! >= 0.10) || (epsCagr != null && epsCagr! >= 0.10)
                ? "Crecimiento moderado"
                : "Crecimiento débil";

    final mar =
        (netMarginPct != null && ((netMarginPct!.abs() <= 1 ? netMarginPct!*100 : netMarginPct!) >= 10))
            ? "márgenes sólidos"
            : (netMarginPct != null && ((netMarginPct!.abs() <= 1 ? netMarginPct!*100 : netMarginPct!) >= 0))
                ? "márgenes contenidos"
                : "márgenes negativos";

    final deuda =
        ((longTermDebtToEquity != null && longTermDebtToEquity! > 1.0) || (netDebt != null && netDebt! > 0))
            ? "nivel de deuda elevado"
            : ((longTermDebtToEquity != null && longTermDebtToEquity! <= 0.5) || (netDebt != null && netDebt! <= 0))
                ? "deuda contenida"
                : "deuda moderada";

    return "$cre, $mar y $deuda.";
  }

  // ---------- Bloque narrativo 1: Operativa (ventas, BPA, márgenes) ----------
  String _bloqueOperativa() {
    final l = <String>[];

    // Ventas y BPA
    if (revenueCagr != null || epsCagr != null) {
      final vs = (revenueCagr != null)
          ? "ventas (CAGR ${_fmtPct(revenueCagr)})"
          : "ventas";
      final bpa = (epsCagr != null)
          ? "BPA (CAGR ${_fmtPct(epsCagr)})"
          : "BPA";
      String juicio;
      final rc = revenueCagr ?? 0;
      if (rc >= 0.15 || (epsCagr ?? 0) >= 0.20) juicio = "un crecimiento fuerte";
      else if (rc >= 0.10 || (epsCagr ?? 0) >= 0.10) juicio = "un avance moderado";
      else juicio = "un avance limitado";
      l.add("La empresa muestra $juicio en $vs y en $bpa");
    }

    // Márgenes
    if (grossMarginPct != null || netMarginPct != null) {
      final gb = grossMarginPct != null ? "margen bruto ${_fmtPct(grossMarginPct)}" : null;
      final nm = netMarginPct   != null ? "margen neto ${_fmtPct(netMarginPct)}"   : null;

      String juicioMargen = "";
      final nmVal = (netMarginPct == null) ? null : (netMarginPct!.abs() <= 1 ? netMarginPct!*100 : netMarginPct!);
      if (nmVal != null) {
        if (nmVal >= 10) juicioMargen = "lo que sostiene una rentabilidad final saludable";
        else if (nmVal >= 0) juicioMargen = "con una rentabilidad final ajustada";
        else juicioMargen = "pero todavía sin rentabilidad a nivel neto";
      }

      final mediciones = [gb, nm].whereType<String>().join(" y ");
      if (mediciones.isNotEmpty) {
        l.add("Opera con $mediciones, $juicioMargen".trim());
      }
    }

    return _joinSentences(l);
  }

  // ---------- Bloque narrativo 2: Caja y calidad del beneficio ----------
  String _bloqueCaja() {
    final l = <String>[];

    if (fcf != null) {
      if (fcf! > 0) l.add("Genera caja libre positiva (FCF ${_fmtMoney(fcf)})");
      else l.add("Presenta caja libre negativa (FCF ${_fmtMoney(fcf)})");
    }

    if (cfo != null && netIncome != null) {
      if (cfo! > netIncome!) {
        l.add("La calidad de los resultados es buena (CFO ${_fmtMoney(cfo)} > Beneficio neto ${_fmtMoney(netIncome)})");
      } else {
        l.add("La calidad de los resultados es más débil (CFO ${_fmtMoney(cfo)} ≤ Beneficio neto ${_fmtMoney(netIncome)})");
      }
    }

    return _joinSentences(l);
  }

  // ---------- Bloque narrativo 3: Estructura financiera (deuda, cobertura) ----------
  String _bloqueEstructura() {
    final l = <String>[];

    if (netDebt != null) {
      if (netDebt! <= 0) l.add("Cuenta con caja neta (Deuda neta ${_fmtMoney(netDebt)})");
      else l.add("Mantiene deuda neta (Deuda neta ${_fmtMoney(netDebt)})");
    }

    if (longTermDebtToEquity != null) {
      final d = longTermDebtToEquity!;
      String calif = d <= 0.5 ? "bajo" : (d <= 1.0 ? "medio" : "alto");
      l.add("El apalancamiento es $calif (Debt/Equity ${_fmtNum(d)})");
    }

    if (assetsToLiabilities != null) {
      final aL = assetsToLiabilities!;
      String cobertura = aL >= 2.0 ? "amplia" : (aL >= 1.5 ? "razonable" : "ajustada");
      l.add("La cobertura de pasivos es $cobertura (Assets/Liabilities ${_fmtNum(aL)})");
    }

    return _joinSentences(l);
  }

  // ---------- Bloque narrativo 4: Inversión / Intensidad de capital + riesgos ----------
  String _bloqueInversionYRiesgos() {
    final l = <String>[];

    if (capexToRevenuePct != null) {
      final crPct = (capexToRevenuePct!.abs() <= 1) ? capexToRevenuePct!*100 : capexToRevenuePct!;
      final etiqueta = crPct > 100
          ? "muy alta"
          : (crPct > 10 ? "alta" : (crPct > 5 ? "equilibrada" : "baja"));
      String notaExtra = crPct > 100 ? ": invierte más de lo que factura este año" : "";
      l.add("La intensidad de capital es $etiqueta (Capex/Revenue ${_fmtPct(capexToRevenuePct)})$notaExtra");
    }

    // Riesgos principales breves
    final riesgos = <String>[];
    final nmVal = (netMarginPct == null) ? null : (netMarginPct!.abs() <= 1 ? netMarginPct!*100 : netMarginPct!);
    if (nmVal != null && nmVal < 0) riesgos.add("rentabilidad neta negativa");
    if (fcf != null && fcf! < 0) riesgos.add("FCF negativo");
    if (longTermDebtToEquity != null && longTermDebtToEquity! > 1.0) riesgos.add("apalancamiento elevado");
    if (riesgos.isNotEmpty) l.add("Riesgos: ${riesgos.join(", ")}");

    return _joinSentences(l);
  }

  // ---------- Bloque final: Sugerencias accionables ----------
  String _bloqueSugerencias() {
    final recs = <String>[];

    // 1) Endeudamiento
    if (longTermDebtToEquity != null && longTermDebtToEquity! > 1.0) {
      recs.add("Priorizar desapalancamiento: reducir deuda o alargar vencimientos "
               "(Debt/Equity ${_fmtNum(longTermDebtToEquity)}) para disminuir sensibilidad a tipos");
    } else if (longTermDebtToEquity != null && longTermDebtToEquity! > 0.5) {
      recs.add("Optimizar estructura de capital: mantener deuda bajo control y negociar coste financiero "
               "(Debt/Equity ${_fmtNum(longTermDebtToEquity)})");
    }

    // 2) Cobertura de pasivos / liquidez
    if (assetsToLiabilities != null && assetsToLiabilities! < 1.5) {
      recs.add("Reforzar liquidez: aumentar caja o reducir pasivos de corto plazo "
               "(Assets/Liabilities ${_fmtNum(assetsToLiabilities)})");
    }

    // 3) Caja libre y calidad
    if (fcf != null && fcf! < 0) {
      recs.add("Volver a FCF positivo: recortar capex no imprescindible y enfocar proyectos con mayor retorno "
               "(FCF ${_fmtMoney(fcf)})");
    }
    if (cfo != null && netIncome != null && cfo! <= netIncome!) {
      recs.add("Mejorar calidad de beneficios: acelerar cobros, gestionar inventario y provisiones "
               "(CFO ${_fmtMoney(cfo)} ≤ NI ${_fmtMoney(netIncome)})");
    }

    // 4) Inversión (Capex/Revenue)
    if (capexToRevenuePct != null) {
      final crPct = (capexToRevenuePct!.abs() <= 1) ? capexToRevenuePct! * 100 : capexToRevenuePct!;
      if (crPct > 10) {
        recs.add("Asegurar retorno del capex: fijar hitos de ROIC y payback antes de seguir escalando "
                 "(Capex/Revenue ${_fmtPct(capexToRevenuePct)})");
      } else if (crPct <= 5 && (revenueCagr != null && revenueCagr! >= 0.15)) {
        recs.add("Aprovechar ventaja de baja intensidad: acelerar crecimiento orgánico/comercial "
                 "(Capex/Revenue ${_fmtPct(capexToRevenuePct)})");
      }
    }

    // 5) Márgenes
    final nm = (netMarginPct == null) ? null : (netMarginPct!.abs() <= 1 ? netMarginPct! * 100 : netMarginPct!);
    if (nm != null && nm < 10 && nm >= 0) {
      recs.add("Potenciar margen neto: mezcla de precios/producto y eficiencia operativa "
               "(margen neto ${_fmtPct(netMarginPct)})");
    }
    if (nm != null && nm < 0) {
      recs.add("Volver a rentabilidad neta: foco en precios, costes y disciplina de gasto "
               "(margen neto ${_fmtPct(netMarginPct)})");
    }

    // 6) Crecimiento
    if ((revenueCagr ?? 0) < 0.10 && (epsCagr ?? 0) < 0.10) {
      recs.add("Impulsar crecimiento rentable: priorizar segmentos con unit economics positivos "
               "(CAGR ventas ${_fmtPct(revenueCagr)}, BPA ${_fmtPct(epsCagr)})");
    }

    if (recs.isEmpty) return ""; // nada que sugerir
    // Deja 3–5 puntos como máximo
    final top = recs.length > 5 ? recs.take(5).toList() : recs;
    return "**Sugerencias para mejorar**:\n• " + top.join("\n• ");
  }

// ---------- Conclusión breve (foto + acción) ----------
String _conclusionFinal() {
  // --- Foto (estado actual) ---
  String cre;
  if ((revenueCagr ?? 0) >= 0.15 || (epsCagr ?? 0) >= 0.15) cre = "crecimiento sólido";
  else if ((revenueCagr ?? 0) >= 0.08 || (epsCagr ?? 0) >= 0.08) cre = "crecimiento moderado";
  else cre = "crecimiento limitado";

  final nmVal = (netMarginPct == null) ? null : (netMarginPct!.abs() <= 1 ? netMarginPct!*100 : netMarginPct!);
  String mar;
  if (nmVal != null && nmVal >= 15) mar = "márgenes fuertes";
  else if (nmVal != null && nmVal >= 5) mar = "márgenes aceptables";
  else if (nmVal != null && nmVal >= 0) mar = "márgenes muy ajustados";
  else mar = "márgenes negativos";

  String deudaFoto;
  if (longTermDebtToEquity != null && longTermDebtToEquity! > 1.0) deudaFoto = "balance tensionado por la deuda";
  else if (longTermDebtToEquity != null && longTermDebtToEquity! > 0.5) deudaFoto = "apalancamiento moderado";
  else deudaFoto = "deuda contenida";

  String cajaFoto;
  if (fcf != null && fcf! > 0) cajaFoto = "generación de caja positiva";
  else if (fcf != null && fcf! < 0) cajaFoto = "consumo de caja libre";
  else cajaFoto = "flujo de caja neutro";

  final foto = "En conjunto, la compañía combina $cre, $mar y $deudaFoto, con $cajaFoto.";

  // --- Acción (qué hacer para mejorar) ---
  final acciones = <String>[];

  // 1) Deuda alta o liquidez justa
  if (longTermDebtToEquity != null && longTermDebtToEquity! > 1.0) {
    acciones.add("reducir deuda para ganar flexibilidad (Debt/Equity ${_fmtNum(longTermDebtToEquity)})");
  } else if (assetsToLiabilities != null && assetsToLiabilities! < 1.5) {
    acciones.add("reforzar liquidez para cubrir mejor obligaciones (Assets/Liabilities ${_fmtNum(assetsToLiabilities)})");
  }

  // 2) Márgenes bajos/negativos
  if (nmVal != null && nmVal < 5 && nmVal >= 0) {
    acciones.add("mejorar eficiencia y mix de precios para elevar rentabilidad (margen neto ${_fmtPct(netMarginPct)})");
  }
  if (nmVal != null && nmVal < 0) {
    acciones.add("volver a rentabilidad neta ajustando costes y precios (margen neto ${_fmtPct(netMarginPct)})");
  }

  // 3) Caja/Calidad de resultados
  if (fcf != null && fcf! < 0) {
    acciones.add("recuperar FCF positivo priorizando proyectos con mayor retorno (FCF ${_fmtMoney(fcf)})");
  }
  if (cfo != null && netIncome != null && cfo! <= netIncome!) {
    acciones.add("mejorar la calidad del beneficio (CFO ${_fmtMoney(cfo)} ≤ NI ${_fmtMoney(netIncome)})");
  }

  // 4) Inversión alta
  if (capexToRevenuePct != null) {
    final crPct = (capexToRevenuePct!.abs() <= 1) ? capexToRevenuePct!*100 : capexToRevenuePct!;
    if (crPct > 10) {
      acciones.add("asegurar que la inversión se traduzca en beneficios claros y se recupere en pocos años (Capex/Revenue ${_fmtPct(capexToRevenuePct)})");
    }
  }

  // 5) Crecimiento flojo
  if ((revenueCagr ?? 0) < 0.08 && (epsCagr ?? 0) < 0.08) {
    acciones.add("impulsar crecimiento rentable enfocando segmentos con mejores unit economics (CAGR ventas ${_fmtPct(revenueCagr)}, BPA ${_fmtPct(epsCagr)})");
  }

  String accionLinea;
  if (acciones.isEmpty) {
    // Caso sano: mantener disciplina
    accionLinea = "Para seguir mejorando, conviene mantener disciplina de inversión y proteger márgenes.";
  } else {
    // Selecciona 1–2 acciones más relevantes
    final top = acciones.take(2).toList();
    accionLinea = "Para mejorar, lo ideal sería " + top.join("; ") + ".";
  }

  return "$foto $accionLinea";
}


  // ---------- Ensamblado final ----------
  final sb = StringBuffer();
sb.writeln("**${_titular()}**");
final op  = _bloqueOperativa();
final caj = _bloqueCaja();
final est = _bloqueEstructura();
final inv = _bloqueInversionYRiesgos();
if (op.isNotEmpty)  sb.writeln(op);
if (caj.isNotEmpty) sb.writeln(caj);
if (est.isNotEmpty) sb.writeln(est);
if (inv.isNotEmpty) sb.writeln(inv);

// 👇 Añadimos la conclusión como guinda final
final concl = _conclusionFinal();
if (concl.isNotEmpty) {
  sb.writeln();
  sb.writeln("**Conclusión**: $concl");
}

return sb.toString().trim();

}