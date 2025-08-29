import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mi_finanzas_reset/fundamental_controller.dart';
import 'package:mi_finanzas_reset/fundamental_repository.dart';
import 'package:mi_finanzas_reset/fundamental_models.dart';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';

// ====================================================
//   Evaluación (tipos y utilidades generales)
// ====================================================
enum _Rating { bueno, neutro, malo, na }

class _EvalRow {
  final String indicador;
  final String valor;      // texto ya formateado
  final _Rating rating;
  final String baremo;     // texto de umbrales
  final String motivo;     // explicación breve
  _EvalRow({
    required this.indicador,
    required this.valor,
    required this.rating,
    required this.baremo,
    required this.motivo,
  });
}

int _pointsFor(_Rating r) {
  switch (r) {
    case _Rating.bueno: return 2;
    case _Rating.neutro: return 1;
    case _Rating.malo:  return 0;
    case _Rating.na:    return 0;
  }
}

Icon _iconFor(_Rating r) {
  switch (r) {
    case _Rating.bueno: return const Icon(Icons.check_circle, color: Colors.green);
    case _Rating.neutro: return const Icon(Icons.warning_amber, color: Colors.orange);
    case _Rating.malo:  return const Icon(Icons.cancel, color: Colors.red);
    case _Rating.na:    return const Icon(Icons.help_outline, color: Colors.grey);
  }
}

enum _Unit { money, percent, number }

class PaginaFundamental extends StatefulWidget {
  final List<String> tickers;
  final String initialTicker;
  const PaginaFundamental({
    super.key,
    required this.tickers,
    required this.initialTicker,
  });

  @override
  State<PaginaFundamental> createState() => _PaginaFundamentalState();
}

class _PaginaFundamentalState extends State<PaginaFundamental> {
  late final FundamentalController ctrl;
  late final FmpRepository repo;
  late String _selectedTicker;
  bool _mostrarDiagnostico = false;


  // ===================== Evaluación (helpers dentro del State) =====================
  YearlyFundamentals? _lastYear(FundamentalSeries s) =>
      s.years.isEmpty ? null : s.years.last;

  String _pct(num? v) => v == null ? 'N/A' : _fmtPercentSmart(v);

  _Rating _ratePct(double? p, {required double good, required double mid}) {
    if (p == null) return _Rating.na;
    if (p > good) return _Rating.bueno;
    if (p >= mid) return _Rating.neutro;
    return _Rating.malo;
  }
  _Rating _rateNumber(double? v, {required double good, required double mid}) {
    if (v == null) return _Rating.na;
    if (v > good) return _Rating.bueno;
    if (v >= mid) return _Rating.neutro;
    return _Rating.malo;
  }
  _Rating _rateLowerIsBetter(double? v, {required double good, required double mid}) {
    if (v == null) return _Rating.na;
    if (v < good) return _Rating.bueno;
    if (v <= mid) return _Rating.neutro;
    return _Rating.malo;
  }

  // ---------- Operativa (crecimientos + márgenes) ----------
  List<_EvalRow> _evalOperativa(FundamentalSeries s) {
    final ys = s.years;
    double? cagr(List<double?> xs) => _cagrRaw(xs);

    final revenueCagr = cagr(ys.map((y) => y.revenue).toList());
    final netIncCagr  = cagr(ys.map((y) => y.netIncome).toList());
    final gbAvg       = _avgRaw(ys.map((y) => y.grossMarginPct).toList());
    final nmAvg       = _avgRaw(ys.map((y) => y.netMarginPct).toList());

    return [
      _EvalRow(
        indicador: 'Revenue CAGR (5y)',
        valor: _pct(revenueCagr),
        rating: _ratePct(revenueCagr, good: 0.10, mid: 0.05),
        baremo: '>10% = Bueno, 5–10% = Neutro, <5% = Malo',
        motivo: 'Crecimiento de ventas sostenido.',
      ),
      _EvalRow(
        indicador: 'Net Income CAGR (5y)',
        valor: _pct(netIncCagr),
        rating: _ratePct(netIncCagr, good: 0.15, mid: 0.10),
        baremo: '>15% = Bueno, 10–15% = Neutro, <10% = Malo',
        motivo: 'Crecimiento de beneficios netos.',
      ),
      _EvalRow(
        indicador: 'Margen bruto % (media)',
        valor: _pct(gbAvg),
        rating: _ratePct(gbAvg, good: 0.40, mid: 0.25),
        baremo: '>40% = Bueno, 25–40% = Neutro, <25% = Malo',
        motivo: 'Eficiencia operativa a nivel bruto.',
      ),
      _EvalRow(
        indicador: 'Margen neto % (media)',
        valor: _pct(nmAvg),
        rating: _ratePct(nmAvg, good: 0.15, mid: 0.05),
        baremo: '>15% = Bueno, 5–15% = Neutro, <5% = Malo',
        motivo: 'Rentabilidad final.',
      ),
    ];
  }

  // ---------- Rentabilidad (accionista/retornos) ----------
  List<_EvalRow> _evalRentabilidad(FundamentalSeries s) {
    final ys = s.years;
    final last = _lastYear(s);

    final epsCagr   = _cagrRaw(ys.map((y) => y.epsDiluted).toList());
    final fcfCagr   = _cagrRaw(ys.map((y) => y.fcf).toList());
    final fpsCagr   = _cagrRaw(ys.map((y) => y.fcfPerShare).toList());
    final roe       = (last?.netIncome != null && last?.equity != null && (last!.equity ?? 0) != 0)
        ? (last.netIncome! / last.equity!)
        : null;
    final roa       = (last?.netIncome != null && last?.totalAssets != null && (last!.totalAssets ?? 0) != 0)
        ? (last.netIncome! / last.totalAssets!)
        : null;
    final fcfMargin = (last?.fcf != null && last?.revenue != null && (last!.revenue ?? 0) != 0)
        ? (last.fcf! / last.revenue!)
        : null;

    return [
      _EvalRow(
        indicador: 'EPS CAGR (5y)',
        valor: _pct(epsCagr),
        rating: _ratePct(epsCagr, good: 0.15, mid: 0.10),
        baremo: '>15% = Bueno, 10–15% = Neutro, <10% = Malo',
        motivo: 'Crecimiento del BPA.',
      ),
      _EvalRow(
        indicador: 'FCF CAGR (5y)',
        valor: _pct(fcfCagr),
        rating: _ratePct(fcfCagr, good: 0.15, mid: 0.10),
        baremo: '>15% = Bueno, 10–15% = Neutro, <10% = Malo',
        motivo: 'Crecimiento de caja libre.',
      ),
      _EvalRow(
        indicador: 'FCF/acción CAGR (5y)',
        valor: _pct(fpsCagr),
        rating: _ratePct(fpsCagr, good: 0.15, mid: 0.10),
        baremo: '>15% = Bueno, 10–15% = Neutro, <10% = Malo',
        motivo: 'Caja por acción.',
      ),
      _EvalRow(
        indicador: 'ROE',
        valor: _pct(roe),
        rating: _ratePct(roe, good: 0.15, mid: 0.10),
        baremo: '>15% = Bueno, 10–15% = Neutro, <10% = Malo',
        motivo: 'Retorno sobre equity.',
      ),
      _EvalRow(
        indicador: 'ROA',
        valor: _pct(roa),
        rating: _ratePct(roa, good: 0.08, mid: 0.04),
        baremo: '>8% = Bueno, 4–8% = Neutro, <4% = Malo',
        motivo: 'Retorno sobre activos.',
      ),
      _EvalRow(
        indicador: 'FCF margin',
        valor: _pct(fcfMargin),
        rating: _ratePct(fcfMargin, good: 0.10, mid: 0.05),
        baremo: '>10% = Bueno, 5–10% = Neutro, <5% = Malo',
        motivo: 'Conversión de ventas en caja.',
      ),
    ];
  }

  // ---------- Estructura / Solvencia / Caja ----------
  List<_EvalRow> _evalEstructura(FundamentalSeries s) {
    final ys = s.years;
    final last = _lastYear(s);

    final debtEq = (last?.longTermDebt != null && last?.equity != null && (last!.equity ?? 0) != 0)
        ? (last.longTermDebt! / last.equity!)
        : null;
    final assetsLiab = (last?.totalAssets != null && last?.totalLiabilities != null && (last!.totalLiabilities ?? 0) != 0)
        ? (last.totalAssets! / last.totalLiabilities!)
        : null;
    final netDebtFcf = (last?.netDebt != null && last?.fcf != null && (last!.fcf ?? 0) > 0)
        ? (last.netDebt! / last.fcf!)
        : null;
    final capexFcf = (last?.capex != null && last?.fcf != null && (last!.fcf ?? 0) != 0)
        ? (last.capex!.abs() / last.fcf!.abs())
        : null;
    final fcfNi = (last?.fcf != null && last?.netIncome != null && (last!.netIncome ?? 0) != 0)
        ? (last.fcf! / last.netIncome!)
        : null;

    final debtCagr = _cagrRaw(ys.map((y) => y.longTermDebt).toList());
    final revCagr  = _cagrRaw(ys.map((y) => y.revenue).toList());
    final equityCagr  = _cagrRaw(ys.map((y) => y.equity).toList());
    final assetsCagr  = _cagrRaw(ys.map((y) => y.totalAssets).toList());
    final ltDebtCagr  = _cagrRaw(ys.map((y) => y.longTermDebt).toList());
    final netDebtVal  = last?.netDebt;

    final deudaVsVentas = (debtCagr != null && revCagr != null) ? (debtCagr - revCagr) : null;

    return [
      _EvalRow(
        indicador: 'Debt/Equity (LP)',
        valor: debtEq == null ? 'N/A' : debtEq.toStringAsFixed(2),
        rating: _rateLowerIsBetter(debtEq, good: 0.5, mid: 1.0),
        baremo: '<0.5 = Bueno, 0.5–1.0 = Neutro, >1.0 = Malo',
        motivo: 'Apalancamiento.',
      ),
      _EvalRow(
        indicador: 'Assets/Liabilities',
        valor: assetsLiab == null ? 'N/A' : assetsLiab.toStringAsFixed(2),
        rating: _rateNumber(assetsLiab, good: 2.0, mid: 1.5),
        baremo: '>2.0 = Bueno, 1.5–2.0 = Neutro, <1.5 = Malo',
        motivo: 'Cobertura de pasivos.',
      ),
   _EvalRow(
  indicador: 'Net Debt / FCF (años)',
  valor: () {
    final nd = last?.netDebt;
    final f  = last?.fcf;
    if (nd == null || f == null) return 'N/A';
    if (!f.isFinite) return 'N/A';
    if (f <= 0) return 'N/A (FCF ≤ 0)';  // 👈 explica por qué
    final ratio = nd / f;
    return '${ratio.toStringAsFixed(1)}x';
  }(),
  rating: () {
    final nd = last?.netDebt;
    final f  = last?.fcf;
    if (nd == null || f == null || !f.isFinite || f <= 0) return _Rating.na;
    final ratio = nd / f;
    return _rateLowerIsBetter(ratio, good: 2.0, mid: 4.0);
  }(),
  baremo: '<2x = Bueno, 2–4x = Neutro, >4x = Malo',
  motivo: 'Años de FCF necesarios para amortizar la deuda neta (si FCF ≤ 0 → no aplica).',
),

      _EvalRow(
        indicador: 'Capex/FCF',
        valor: _pct(capexFcf),
        rating: _rateLowerIsBetter(capexFcf, good: 0.40, mid: 0.70),
        baremo: '<40% = Bueno, 40–70% = Neutro, >70% = Malo',
        motivo: 'Intensidad de inversión.',
      ),
      _EvalRow(
        indicador: 'FCF/Net Income',
        valor: _pct(fcfNi),
        rating: _rateNumber(fcfNi, good: 1.0, mid: 0.70),
        baremo: '≥100% = Bueno, 70–100% = Neutro, <70% = Malo',
        motivo: 'Calidad del beneficio.',
      ),
      _EvalRow(
        indicador: 'CAGR Deuda – CAGR Ventas',
        valor: _pct(deudaVsVentas),
        rating: _rateLowerIsBetter(deudaVsVentas, good: 0.00, mid: 0.05),
        baremo: '≤0% = Bueno, 0–5% = Neutro, >5% = Malo',
        motivo: 'Deuda creciendo vs ventas.',
      ),
      _EvalRow(
        indicador: 'Equity CAGR (5y)',
        valor: _fmtPercentSmart(equityCagr),
        rating: _ratePct(equityCagr, good: 0.08, mid: 0.03),
        baremo: '>8% = Bueno, 3–8% = Neutro, <3% = Malo',
        motivo: 'Crecimiento del patrimonio neto.',
      ),
      _EvalRow(
        indicador: 'Activos CAGR (5y)',
        valor: _fmtPercentSmart(assetsCagr),
        rating: _ratePct(assetsCagr, good: 0.06, mid: 0.03),
        baremo: '>6% = Bueno, 3–6% = Neutro, <3% = Malo',
        motivo: 'Crecimiento del balance de activos.',
      ),
      _EvalRow(
        indicador: 'LT Debt CAGR (5y)',
        valor: _fmtPercentSmart(ltDebtCagr),
        rating: _rateLowerIsBetter(ltDebtCagr, good: 0.00, mid: 0.05),
        baremo: '≤0% = Bueno, 0–5% = Neutro, >5% = Malo',
        motivo: 'Ritmo de crecimiento de la deuda a largo plazo.',
      ),
      _EvalRow(
        indicador: 'Net Debt',
        valor: netDebtVal == null ? 'N/A' : _fmtMoney(netDebtVal),
        rating: _Rating.na,
        baremo: 'Informativo (mejor si es bajo o negativo).',
        motivo: 'Deuda neta del último año; mejor baja o negativa.',
      ),
    ];
  }

  Widget _cardEvaluacion({
    required String titulo,
    required List<_EvalRow> rows,
  }) {
    final totalPts = rows.fold<int>(0, (sum, r) => sum + _pointsFor(r.rating));
    final maxPts   = rows.fold<int>(0, (sum, r) => sum + (r.rating == _Rating.na ? 0 : 2));
    final pct = maxPts == 0 ? 0 : ((totalPts / maxPts) * 100).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8), // compacto
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$titulo — Puntuación: $totalPts/$maxPts ($pct%)',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 12,
                horizontalMargin: 8,
                headingRowHeight: 32,
                dataRowMinHeight: 32,
                dataRowMaxHeight: 36,
                columns: const [
                  DataColumn(label: Text('Indicador')),
                  DataColumn(label: Text('Valor')),
                  DataColumn(label: Text('Eval')),
                ],
                rows: rows.map((r) {
                  return DataRow(cells: [
                    DataCell(Text(r.indicador, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    DataCell(Align(
                      alignment: Alignment.centerRight,
                      child: Text(r.valor, maxLines: 1, overflow: TextOverflow.ellipsis),
                    )),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _iconFor(r.rating),
                        const SizedBox(width: 4),
                        Text(
                          switch (r.rating) {
                            _Rating.bueno => 'Bueno',
                            _Rating.neutro => 'Neutro',
                            _Rating.malo => 'Malo',
                            _Rating.na => 'N/A',
                          },
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text(r.indicador),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Valor usado: ${r.valor}'),
                                    const SizedBox(height: 8),
                                    Text('Baremo: ${r.baremo}'),
                                    const SizedBox(height: 8),
                                    Text(r.motivo),
                                  ],
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
                                ],
                              ),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(4.0),
                            child: Icon(Icons.info_outline, size: 18),
                          ),
                        ),
                      ],
                    )),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Ranking ----
  String _selectedMetric = 'Revenue';
  bool _rankLoading = false;
  bool _logScale = false;
  bool _rankRefreshingAll = false;
  String? _rankError;
  List<_RankRow> _rankRows = [];

  final List<String> _metrics = const [
    // Operativa
    'Revenue',
    'COGS',
    'Margen bruto %',
    'Net income',
    'Margen neto %',

    // Rentabilidad
    'EPS diluido',
    'FCF',
    'FCF/acción',

    // Estructura / Inversión
    'Acciones en circulación',
    'Activos',
    'Pasivos',
    'Deuda LP',
    'Equity',
    'Capex',
    'Deuda Neta',
  ];

  final Set<String> _activeSeries = {};

  @override
  void initState() {
    super.initState();
    _selectedTicker = widget.initialTicker;
    repo = FmpRepository(apiKey: "T2lkYSgttcYL1QpzA5kkVWCOiOQrIVny");
    ctrl = FundamentalController(repo);
    Future.microtask(() {
      ctrl.load(_selectedTicker);
      _cargarRanking(forceRefreshAll: false);
    });
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  Future<void> _recargarDesdeRed() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Actualizando desde red...')),
    );
    try {
      await repo.refreshFundamentals(_selectedTicker);
      await ctrl.load(_selectedTicker);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datos actualizados.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ctrl,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Fundamental'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Ticker'),
                Tab(text: 'Ranking'),
              ],
            ),
          ),
          body: Padding(
  padding: EdgeInsets.zero, // 👈 elimina cualquier margen
  child: TabBarView(
    children: [
      _buildTickerTab(context),
      _buildRankingTab(context),
    ],
  ),
),

        ),
      ),
    );
  }

  // ==========================
  // TAB 1 — Vista por Ticker
  // ==========================
  Widget _buildTickerTab(BuildContext context) {
    return Column(
      children: [
        // --- Selector de ticker + recarga ---
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: [
              const Text('Ticker:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _selectedTicker,
                items: widget.tickers
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedTicker = value);
                  ctrl.load(_selectedTicker);
                },
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Recargar desde red (ignorar caché)',
                icon: const Icon(Icons.cloud_download),
                onPressed: () => _recargarDesdeRed(),
              ),
            ],
          ),
        ),

        // --- Contenido ---
        Expanded(
          child: Consumer<FundamentalController>(
            builder: (context, c, _) {
              switch (c.state) {
                case FundState.loading: {
                  final now = DateTime.now().year;
                  final years = List.generate(5, (i) => now - 4 + i);
                  return _seccionesTickerSkeleton(years, mensaje: 'Cargando datos…');
                }
                case FundState.error: {
                  final now = DateTime.now().year;
                  final years = List.generate(5, (i) => now - 4 + i);
                  return _seccionesTickerSkeleton(
                    years,
                    mensaje: 'Sin datos en caché o límite/endpoint FMP. Prueba con el botón de la nube.',
                    colorMensaje: Colors.red,
                  );
                }
                case FundState.ready: {
                  final s = c.series!;
                  if (s.years.isEmpty) {
                    final now = DateTime.now().year;
                    final years = List.generate(5, (i) => now - 4 + i);
                    return _seccionesTickerSkeleton(years, mensaje: 'Sin años disponibles.');
                  }
                 return ListView(
  padding: const EdgeInsets.only(left: 0, right: 0, top: 12, bottom: 16),




                    children: [
                      // FILA PRINCIPAL con scroll horizontal
                    // --- Operativa ---
Stack(
  children: [
    // contenido centrado
    Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: Column(
          children: [
            _cardTabla(titulo: 'Operativa', tabla: _tablaOperativa(s)),
            const SizedBox(height: 12),
            _cardTabla(titulo: 'Rentabilidad', tabla: _tablaRentabilidad(s)),
            const SizedBox(height: 12),
            _cardTabla(titulo: 'Estructura / Inversión', tabla: _tablaEstructuraInversion(s)),
          ],
        ),
      ),
    ),

    // evaluación flotante
    Positioned(
      right: 0,
      top: 0,
      width: 360,
      child: _cardEvaluacionGlobal(
        evalOp: _evalOperativa(s),
        evalRent: _evalRentabilidad(s),
        evalEstr: _evalEstructura(s),
        onToggleDiagnostico: () => setState(() => _mostrarDiagnostico = !_mostrarDiagnostico),
      ),
    ),
  ],
),

// 👇 después del Stack ya puedes seguir con lo demás
const SizedBox(height: 12),

if (_mostrarDiagnostico)
  Consumer<FundamentalController>(

    builder: (_, ctrl, __) {
      if (ctrl.diagnostico.isEmpty) return const SizedBox.shrink();
      return Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            ctrl.diagnostico,
            style: const TextStyle(fontSize: 14, height: 1.35),
          ),
        ),
      );
    },
  ),



                      // Gráfica
                      _chartCard(s),
                    ],
                  );
                }
                case FundState.idle:
                default:
                  return const SizedBox.shrink();
              }
            },
          ),
        ),
      ],
    );
  }

  // === Chips de series activas ===
  Widget _chipsActivos() {
    if (_activeSeries.isEmpty) {
      return const Text('Selecciona indicadores en el menú para ver la gráfica.');
    }
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: _activeSeries.map((name) {
        final idx = _activeSeries.toList().indexOf(name);
        final color = _colorFor(idx);
        return InputChip(
          label: Text(name, style: TextStyle(color: color)),
          selected: true,
          selectedColor: color.withOpacity(0.15),
          checkmarkColor: color,
          onSelected: (_) => _toggleIndicator(name),
          deleteIcon: Icon(Icons.close, color: color),
          onDeleted: () => _toggleIndicator(name),
        );
      }).toList(),
    );
  }

  Widget _chartCard(FundamentalSeries s) {
    final String indicator = _activeSeries.isNotEmpty ? _activeSeries.first : 'Revenue';
    return Card(
  margin: EdgeInsets.zero,
  child: Padding(

        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Gráfica', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                const Text('• toca filas para alternar indicadores'),
                const Spacer(),
                PopupMenuButton<String>(
                  tooltip: 'Añadir/quitar indicador',
                  onSelected: (String metric) {
                    if (_activeSeries.contains(metric)) {
                      _toggleIndicator(metric);
                    } else {
                      _addIndicator(metric);
                    }
                  },
                  itemBuilder: (_) => _metrics
                      .map((m) => CheckedPopupMenuItem<String>(
                            value: m,
                            checked: _activeSeries.contains(m),
                            child: Text(m),
                          ))
                      .toList(),
                  child: Row(
                    children: [
                      Text(
                        _activeSeries.isNotEmpty ? _activeSeries.join(', ') : 'Selecciona indicadores',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const Icon(Icons.expand_more),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    const Text('Log'),
                    Switch(
                      value: _logScale,
                      onChanged: (v) => setState(() => _logScale = v),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            _chipsActivos(),
            const SizedBox(height: 8),
            SizedBox(height: 260, child: _buildLineChart(s, indicator)),
          ],
        ),
      ),
    );
  }

  // === Cards reutilizables ===
  Widget _cardTabla({required String titulo, required Widget tabla}) {
    return Card(
  margin: EdgeInsets.zero,
  child: Padding(

        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            tabla,
          ],
        ),
      ),
    );
  }

  // === DataTable renderer ===
  Widget _renderDataTable({
    required List<int> years,
    required List<MapEntry<String, List<String>>> rows,
    bool includeSummary = true,
    void Function(String indicador)? onRowTap,
  }) {
    final columns = <DataColumn>[
      const DataColumn(label: Text('Indicador')),
      ...years.map((y) => DataColumn(label: Text('$y'))),
      if (includeSummary) const DataColumn(label: Text('CAGR')),
    ];

    final dataRows = rows.map((r) {
      final isActive = _activeSeries.contains(r.key);
      final idx = _activeSeries.toList().indexOf(r.key);
      final color = idx >= 0 ? _colorFor(idx) : Colors.grey;

      return DataRow(
        onSelectChanged: onRowTap == null ? null : (_) => onRowTap(r.key),
        cells: [
          DataCell(
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: isActive,
                    onChanged: onRowTap == null ? null : (_) => onRowTap(r.key),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                    side: BorderSide(width: 1.6, color: color),
                    activeColor: color,
                    checkColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Text(r.key),
              ],
            ),
          ),
          ...r.value.map(
            (v) => DataCell(
              Align(alignment: Alignment.centerRight, child: Text(v)),
            ),
          ),
        ],
      );
    }).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: columns,
        rows: dataRows,
        showCheckboxColumn: false,
        columnSpacing: 24,
        headingRowHeight: 36,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 40,
      ),
    );
  }

  // === Skeleton de las 3 secciones ===
  Widget _seccionesTickerSkeleton(List<int> years, {String? mensaje, Color? colorMensaje}) {
   return ListView(
  padding: const EdgeInsets.only(left: 0, right: 16, top: 12, bottom: 16),


      children: [
        if (mensaje != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(mensaje, style: TextStyle(color: colorMensaje ?? Colors.black87)),
            ),
          ),
        if (mensaje != null) const SizedBox(height: 12),
        _cardTabla(titulo: 'Operativa', tabla: _tablaOperativaSkeleton(years)),
        const SizedBox(height: 12),
        _cardTabla(titulo: 'Rentabilidad', tabla: _tablaRentabilidadSkeleton(years)),
        const SizedBox(height: 12),
        _cardTabla(titulo: 'Estructura / Inversión', tabla: _tablaEstructuraInversionSkeleton(years)),
      ],
    );
  }

  // ==========================
  // TAB 2 — Ranking por métrica
  // ==========================
  Widget _buildRankingTab(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: [
              const Text('Indicador:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _selectedMetric,
                items: _metrics.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _selectedMetric = v);
                  _cargarRanking(forceRefreshAll: false);
                },
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Actualizar todo (forzar red)',
                onPressed: _rankLoading || _rankRefreshingAll
                    ? null
                    : () => _cargarRanking(forceRefreshAll: true),
                icon: const Icon(Icons.cloud_sync),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Reordenar (usar caché)',
                onPressed: _rankLoading ? null : () => _cargarRanking(forceRefreshAll: false),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        if (_rankRefreshingAll)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: LinearProgressIndicator(),
          ),
        Expanded(
          child: _rankLoading
              ? const Center(child: CircularProgressIndicator())
              : _rankError != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 16, 16, 16),

                        child: Text(_rankError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                      ),
                    )
                  : _rankRows.isEmpty
                      ? const Center(child: Text('Sin datos para ordenar.'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _rankRows.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final r = _rankRows[i];
                            return ListTile(
                              leading: Text('${i + 1}'),
                              title: Text(r.ticker),
                              subtitle: Text('Año ${r.year ?? "—"}'),
                              trailing: Text(
                                _fmtMetricValue(r.value, _selectedMetric),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              onTap: () {
                                setState(() => _selectedTicker = r.ticker);
                                ctrl.load(r.ticker);
                                DefaultTabController.of(context).animateTo(0);
                              },
                            );
                          },
                        ),
        ),
      ],
    );
  }

  Future<void> _cargarRanking({required bool forceRefreshAll}) async {
    setState(() {
      _rankLoading = true;
      _rankError = null;
      if (forceRefreshAll) _rankRefreshingAll = true;
      _rankRows = [];
    });

    try {
      final rows = <_RankRow>[];

      for (final t in widget.tickers) {
        final FundamentalSeries s = forceRefreshAll
            ? await repo.refreshFundamentals(t)
            : await repo.fetchFundamentals(t);

        if (s.years.isEmpty) continue;
        final last = s.years.last;
        final val = _pickMetric(last, _selectedMetric);
        if (val == null) continue;

        rows.add(_RankRow(ticker: t, value: val, year: last.year));
      }

      rows.sort((a, b) => (b.value).compareTo(a.value));
      setState(() => _rankRows = rows);
    } catch (e) {
      setState(() => _rankError = 'Error al cargar ranking: $e');
    } finally {
      if (mounted) {
        setState(() {
          _rankLoading = false;
          _rankRefreshingAll = false;
        });
      }
    }
  }

  // ======= Helpers de formato =======
  String _fmtMoney(num? v) {
    if (v == null) return '—';
    final a = v.abs();
    if (a >= 1e12) return '${(v/1e12).toStringAsFixed(2)}T';
    if (a >= 1e9)  return '${(v/1e9).toStringAsFixed(2)}B';
    if (a >= 1e6)  return '${(v/1e6).toStringAsFixed(2)}M';
    if (a >= 1e3)  return '${(v/1e3).toStringAsFixed(1)}K';
    return v.toStringAsFixed(2);
  }

  String _fmtNumber(num? v) => v == null ? '—' : v.toStringAsFixed(2);

  String _fmtPercentSmart(num? v) {
    if (v == null) return '—';
    final p = (v.abs() <= 2) ? v * 100 : v;
    return '${p.toStringAsFixed(2)}%';
  }

  String _fmtMetricValue(double v, String metric) {
    final isPercent = metric.contains('%');
    if (isPercent) return _fmtPercentSmart(v);
    if (v.abs() >= 1e12) return '${(v / 1e12).toStringAsFixed(2)} T';
    if (v.abs() >= 1e9)  return '${(v / 1e9).toStringAsFixed(2)} B';
    if (v.abs() >= 1e6)  return '${(v / 1e6).toStringAsFixed(2)} M';
    if (v.abs() >= 1e3)  return '${(v / 1e3).toStringAsFixed(2)} K';
    return v.toStringAsFixed(2);
  }

  String _fmtBillions(num? v) => v == null ? '—' : (v / 1e9).toStringAsFixed(2);

  double? _cagrRaw(List<double?> series) {
    final clean = series.whereType<double>().toList();
    if (clean.length < 2) return null;
    final first = clean.first;
    final last  = clean.last;
    if (first <= 0 || last <= 0) return null;
    final n = clean.length - 1;
    return (pow(last / first, 1 / n) - 1);
  }

  double? _avgRaw(List<double?> series) {
    final clean = series.whereType<double>().toList();
    if (clean.isEmpty) return null;
    return clean.reduce((a, b) => a + b) / clean.length;
  }

  // ======= Tablas por sección (READY) =======
  Widget _tablaOperativa(FundamentalSeries s) {
    final ys = s.years;
    final years = ys.map((e) => e.year).toList();

    List<double?> take(double? Function(YearlyFundamentals y) pick) => ys.map(pick).toList();

    List<String> moneyCol(double? Function(YearlyFundamentals y) pick) =>
        ys.map((y) => _fmtMoney(pick(y))).toList();

    List<String> pctCol(double? Function(YearlyFundamentals y) pick) =>
        ys.map((y) => _fmtPercentSmart(pick(y))).toList();

    final revenue = take((y) => y.revenue);
    final cogs    = take((y) => y.cogs);
    final netInc  = take((y) => y.netIncome);
    final gb      = take((y) => y.grossMarginPct);
    final nm      = take((y) => y.netMarginPct);

    final rows = <MapEntry<String, List<String>>>[
      MapEntry('Revenue',        [...moneyCol((y) => y.revenue),        _fmtPercentSmart(_cagrRaw(revenue))]),
      MapEntry('COGS',           [...moneyCol((y) => y.cogs),           _fmtPercentSmart(_cagrRaw(cogs))]),
      MapEntry('Margen bruto %', [...pctCol  ((y) => y.grossMarginPct), _fmtPercentSmart(_avgRaw(gb))]),
      MapEntry('Net income',     [...moneyCol((y) => y.netIncome),      _fmtPercentSmart(_cagrRaw(netInc))]),
      MapEntry('Margen neto %',  [...pctCol  ((y) => y.netMarginPct),   _fmtPercentSmart(_avgRaw(nm))]),
    ];

    return _renderDataTable(years: years, rows: rows, includeSummary: true, onRowTap: _toggleIndicator);
  }

  Widget _tablaRentabilidad(FundamentalSeries s) {
    final ys = s.years;
    final years = ys.map((e) => e.year).toList();

    List<double?> take(double? Function(YearlyFundamentals y) pick) => ys.map(pick).toList();

    final eps  = take((y) => y.epsDiluted);
    final fcf  = take((y) => y.fcf);
    final fps  = take((y) => y.fcfPerShare);

    List<String> numCol(double? Function(YearlyFundamentals y) pick) =>
        ys.map((y) => _fmtNumber(pick(y))).toList();
    List<String> moneyCol(double? Function(YearlyFundamentals y) pick) =>
        ys.map((y) => _fmtMoney(pick(y))).toList();

    final rows = <MapEntry<String, List<String>>>[
      MapEntry('EPS diluido', [...numCol((y) => y.epsDiluted), _fmtPercentSmart(_cagrRaw(eps))]),
      MapEntry('FCF',         [...moneyCol((y) => y.fcf),      _fmtPercentSmart(_cagrRaw(fcf))]),
      MapEntry('FCF/acción',  [...numCol((y) => y.fcfPerShare),_fmtPercentSmart(_cagrRaw(fps))]),
    ];

    return _renderDataTable(years: years, rows: rows, includeSummary: true, onRowTap: _toggleIndicator);
  }

  Widget _tablaEstructuraInversion(FundamentalSeries s) {
    final ys = s.years;
    final years = ys.map((e) => e.year).toList();

    List<double?> take(double? Function(YearlyFundamentals y) pick) => ys.map(pick).toList();

    final activos = take((y) => y.totalAssets);
    final pasivos = take((y) => y.totalLiabilities);

    List<String> moneyCol(double? Function(YearlyFundamentals y) pick) =>
        ys.map((y) => _fmtMoney(pick(y))).toList();
    List<String> numBillCol(double? Function(YearlyFundamentals y) pick) =>
        ys.map((y) => _fmtBillions(pick(y))).toList();

    final rows = <MapEntry<String, List<String>>>[
      MapEntry('Acciones en circulación', [...numBillCol((y) => y.sharesDiluted), '—']),
      MapEntry('Activos',                 [...moneyCol((y) => y.totalAssets),     _fmtPercentSmart(_cagrRaw(activos))]),
      MapEntry('Pasivos',                 [...moneyCol((y) => y.totalLiabilities),_fmtPercentSmart(_cagrRaw(pasivos))]),
      MapEntry('Deuda LP',                [...moneyCol((y) => y.longTermDebt),    '—']),
      MapEntry('Equity',                  [...moneyCol((y) => y.equity),          '—']),
      MapEntry('Capex',                   [...moneyCol((y) => y.capex),           '—']),
      MapEntry('Deuda Neta',              [...moneyCol((y) => y.netDebt),         '—']),
    ];

    return _renderDataTable(years: years, rows: rows, includeSummary: true, onRowTap: _toggleIndicator);
  }

  // ======= Tablas por sección (SKELETON) =======
  Widget _tablaSkeletonYears(List<int> years, List<String> indicadores) {
    final rows = indicadores
        .map((name) => MapEntry(name, [
              ...List.generate(years.length, (_) => '—'),
              '—',
            ]))
        .toList();
    return _renderDataTable(years: years, rows: rows, includeSummary: true, onRowTap: _toggleIndicator);
  }

  Widget _tablaOperativaSkeleton(List<int> years) =>
      _tablaSkeletonYears(years, ['Revenue','COGS','Margen bruto %','Net income','Margen neto %']);

  Widget _tablaRentabilidadSkeleton(List<int> years) =>
      _tablaSkeletonYears(years, ['EPS diluido','FCF','FCF/acción']);

  Widget _tablaEstructuraInversionSkeleton(List<int> years) =>
      _tablaSkeletonYears(years, ['Acciones en circulación','Activos','Pasivos','Deuda LP','Equity','Capex','Deuda Neta']);

  // ======= Ranking helpers =======
  double? _pickMetric(YearlyFundamentals y, String metric) {
    switch (metric) {
      // Operativa
      case 'Revenue': return y.revenue;
      case 'COGS': return y.cogs;
      case 'Margen bruto %': return y.grossMarginPct;
      case 'Net income': return y.netIncome;
      case 'Margen neto %': return y.netMarginPct;

      // Rentabilidad
      case 'EPS diluido': return y.epsDiluted;
      case 'FCF': return y.fcf;
      case 'FCF/acción': return y.fcfPerShare;

      // Estructura / Inversión
      case 'Acciones en circulación': return y.sharesDiluted;
      case 'Activos': return y.totalAssets;
      case 'Pasivos': return y.totalLiabilities;
      case 'Deuda LP': return y.longTermDebt;
      case 'Equity': return y.equity;
      case 'Capex': return y.capex;
      case 'Deuda Neta': return y.netDebt;

      // extras
      case 'Caja': return y.cash;
      case 'Deuda CP': return y.shortTermDebt;

      default: return null;
    }
  }

  // ======== GRÁFICA ========
  _Unit _unitOf(String metric) {
    if (metric.contains('%')) return _Unit.percent;
    switch (metric) {
      case 'EPS diluido':
      case 'FCF/acción':
      case 'Acciones en circulación':
        return _Unit.number;
      default:
        return _Unit.money;
    }
  }

  void _addIndicator(String metric) {
    setState(() => _activeSeries.add(metric));
  }

  Color _colorFor(int idx) {
    const palette = [
      Colors.teal, Colors.deepOrange, Colors.purple,
      Colors.blue, Colors.red, Colors.green,
      Colors.brown, Colors.pink,
    ];
    return palette[idx % palette.length];
  }

  List<double?> _seriesForIndicator(FundamentalSeries s, String metric) {
    final ys = s.years;
    switch (metric) {
      // Operativa
      case 'Revenue':        return ys.map((y) => y.revenue).toList();
      case 'COGS':           return ys.map((y) => y.cogs).toList();
      case 'Margen bruto %': return ys.map((y) => y.grossMarginPct).toList();
      case 'Net income':     return ys.map((y) => y.netIncome).toList();
      case 'Margen neto %':  return ys.map((y) => y.netMarginPct).toList();

      // Rentabilidad
      case 'EPS diluido':    return ys.map((y) => y.epsDiluted).toList();
      case 'FCF':            return ys.map((y) => y.fcf).toList();
      case 'FCF/acción':     return ys.map((y) => y.fcfPerShare).toList();

      // Estructura / Inversión
      case 'Acciones en circulación': return ys.map((y) => y.sharesDiluted).toList();
      case 'Activos':                 return ys.map((y) => y.totalAssets).toList();
      case 'Pasivos':                 return ys.map((y) => y.totalLiabilities).toList();
      case 'Deuda LP':                return ys.map((y) => y.longTermDebt).toList();
      case 'Equity':                  return ys.map((y) => y.equity).toList();
      case 'Capex':                   return ys.map((y) => y.capex).toList();
      case 'Deuda Neta':              return ys.map((y) => y.netDebt).toList();

      case 'Caja':                    return ys.map((y) => y.cash).toList();
      case 'Deuda CP':                return ys.map((y) => y.shortTermDebt).toList();
    }
    return const [];
  }

  Widget _buildLineChart(FundamentalSeries s, String _) {
    if (_activeSeries.isEmpty) {
      return const Center(child: Text('Selecciona uno o más indicadores para graficar.'));
    }

    final years = s.years.map((e) => e.year).toList();
    final active = _activeSeries.toList();

    final seriesSpots = <List<FlSpot>>[];
    for (final name in active) {
      final raw = _seriesForIndicator(s, name);
      final spots = <FlSpot>[];
      for (int i = 0; i < years.length; i++) {
        final v = raw[i];
        if (v != null && v.isFinite) {
          if (_logScale) {
            if (v > 0) {
              spots.add(FlSpot(i.toDouble(), log(v) / ln10));
            }
          } else {
            spots.add(FlSpot(i.toDouble(), v.toDouble()));
          }
        }
      }
      seriesSpots.add(spots);
    }

    if (seriesSpots.every((sp) => sp.isEmpty)) {
      return const Center(child: Text('Sin datos para la gráfica.'));
    }

    final allY = seriesSpots.expand((sp) => sp.map((p) => p.y)).toList();
    double minY = allY.reduce(min);
    double maxY = allY.reduce(max);

    if (_logScale) {
      minY = minY.floorToDouble();
      maxY = maxY.ceilToDouble();
    } else {
      if (minY == maxY) {
        minY = minY - (minY.abs() * 0.1 + 1);
        maxY = maxY + (maxY.abs() * 0.1 + 1);
      } else {
        final pad = (maxY - minY) * 0.1;
        minY -= pad;
        maxY += pad;
      }
    }

    final units = active.map(_unitOf).toSet();
    final mixedUnits = units.length > 1;
    final singleUnit = mixedUnits ? null : units.first;

    String _formatY(double v) {
      if (_logScale) {
        final n = v.round();
        final real = pow(10.0, n);
        return _fmtMoney(real);
      }

      if (mixedUnits) {
        final a = v.abs();
        final sign = v < 0 ? '-' : '';
        if (a >= 1e12) return '$sign${(a/1e12).toStringAsFixed(0)}T';
        if (a >= 1e9)  return '$sign${(a/1e9).toStringAsFixed(0)}B';
        if (a >= 1e6)  return '$sign${(a/1e6).toStringAsFixed(0)}M';
        if (a >= 1e3)  return '$sign${(a/1e3).toStringAsFixed(0)}K';
        return '$sign${a.toStringAsFixed(0)}';
      }

      switch (singleUnit!) {
        case _Unit.percent:
          final p = (v.abs() <= 2) ? v * 100 : v;
          return '${p.toStringAsFixed(0)}%';
        case _Unit.money:
          final a = v.abs(); final sign = v < 0 ? '-' : '';
          if (a >= 1e12) return '$sign${(a/1e12).toStringAsFixed(1)}T';
          if (a >= 1e9)  return '$sign${(a/1e9).toStringAsFixed(1)}B';
          if (a >= 1e6)  return '$sign${(a/1e6).toStringAsFixed(1)}M';
          if (a >= 1e3)  return '$sign${(a/1e3).toStringAsFixed(0)}K';
          return '$sign${a.toStringAsFixed(0)}';
        case _Unit.number:
          final a = v.abs(); final sign = v < 0 ? '-' : '';
          if (a >= 1e9)  return '$sign${(a/1e9).toStringAsFixed(1)}B';
          if (a >= 1e6)  return '$sign${(a/1e6).toStringAsFixed(1)}M';
          if (a >= 1e3)  return '$sign${(a/1e3).toStringAsFixed(0)}K';
          return '$sign${a.toStringAsFixed(0)}';
      }
    }

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(show: true),
        borderData: FlBorderData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= years.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('${years[idx]}', style: const TextStyle(fontSize: 11)),
                );
              },
              interval: 1,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              interval: _logScale ? 1 : null,
              getTitlesWidget: (value, meta) =>
                  Text(_formatY(value), style: const TextStyle(fontSize: 11)),
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: List.generate(seriesSpots.length, (i) {
          return LineChartBarData(
            spots: seriesSpots[i],
            isCurved: false,
            barWidth: 2.5,
            color: _colorFor(i),
            dotData: FlDotData(show: true),
          );
        }),
      ),
    );
  }

  void _toggleIndicator(String indicador) {
    setState(() {
      if (_activeSeries.contains(indicador)) {
        _activeSeries.remove(indicador);
      } else {
        _activeSeries.add(indicador);
      }
    });
  }

Widget _cardEvaluacionGlobal({
  required List<_EvalRow> evalOp,
  required List<_EvalRow> evalRent,
  required List<_EvalRow> evalEstr,
  VoidCallback? onToggleDiagnostico,
}) {

    return Card(
  margin: EdgeInsets.zero,
  child: Padding(

        padding: const EdgeInsets.all(8), // compacto
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Evaluación Global", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
Builder(builder: (_) {
  final allRows = [...evalOp, ...evalRent, ...evalEstr];
  final totalPts = allRows.fold<int>(0, (s, r) => s + _pointsFor(r.rating));
  final maxPts   = allRows.fold<int>(0, (s, r) => s + (r.rating == _Rating.na ? 0 : 2));

  final score10Num = maxPts == 0 ? 0.0 : (totalPts / maxPts * 10);
  final score10 = score10Num.toStringAsFixed(1);

  final resumen = _buildResumenEmpresa(
    op: evalOp,
    rent: evalRent,
    estr: evalEstr,
    score10Num: score10Num,
  );

  return InkWell(
    onTap: () {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Resumen — $score10/10'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(resumen.comentario),
                const SizedBox(height: 12),
                if (resumen.fortalezas.isNotEmpty) ...[
                  const Text('Fortalezas', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  ...resumen.fortalezas.map((t) => Text('• $t')),
                  const SizedBox(height: 12),
                ],
                if (resumen.mejoras.isNotEmpty) ...[
                  const Text('A mejorar', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  ...resumen.mejoras.map((t) => Text('• $t')),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
          ],
        ),
      );
    },
    child: Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Puntuación total: $score10/10',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            resumen.comentario,
            style: TextStyle(color: Colors.grey[700], fontSize: 13),
          ),
          Row(
  children: [
    TextButton.icon(
      onPressed: onToggleDiagnostico,
      icon: const Icon(Icons.stacked_line_chart),
      label: Text(_mostrarDiagnostico ? 'Ocultar diagnóstico' : 'Ver diagnóstico'),
    ),
  ],
),

        ],
      ),
    ),
  );
}),

            
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: const Text("Operativa"),
              children: [_buildEvalTable("Operativa", evalOp)],
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: const Text("Rentabilidad"),
              children: [_buildEvalTable("Rentabilidad", evalRent)],
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: const Text("Solvencia y Caja"),
              children: [_buildEvalTable("Solvencia y Caja", evalEstr)],
            ),
          ],
        ),
      ),
    );
  }

String _labelDeRating(_Rating r) {
  switch (r) {
    case _Rating.bueno: return 'Bueno';
    case _Rating.neutro: return 'Neutro';
    case _Rating.malo:  return 'Malo';
    case _Rating.na:    return 'N/A';
  }
}



/// Genera listas de fortalezas y mejoras a partir de las filas evaluadas



  Widget _buildEvalTable(String titulo, List<_EvalRow> rows) {
    final totalPts = rows.fold<int>(0, (sum, r) => sum + _pointsFor(r.rating));
    final maxPts   = rows.fold<int>(0, (sum, r) => sum + (r.rating == _Rating.na ? 0 : 2));
    final pct = maxPts == 0 ? 0 : ((totalPts / maxPts) * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$titulo — Puntuación: $totalPts/$maxPts ($pct%)',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 12,
            horizontalMargin: 8,
            headingRowHeight: 32,
            dataRowMinHeight: 32,
            dataRowMaxHeight: 36,
            columns: const [
              DataColumn(label: Text('Indicador')),
              DataColumn(label: Text('Valor')),
              DataColumn(label: Text('Eval')),
            ],
            rows: rows.map((r) {
              return DataRow(cells: [
                DataCell(Text(r.indicador, maxLines: 1, overflow: TextOverflow.ellipsis)),
                DataCell(Align(
                  alignment: Alignment.centerRight,
                  child: Text(r.valor, maxLines: 1, overflow: TextOverflow.ellipsis),
                )),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _iconFor(r.rating),
                    const SizedBox(width: 4),
                    Text(
                      switch (r.rating) {
                        _Rating.bueno => 'Bueno',
                        _Rating.neutro => 'Neutro',
                        _Rating.malo => 'Malo',
                        _Rating.na => 'N/A',
                      },
                    ),
                  ],
                )),
              ]);
            }).toList(),
          ),
        ),
      ],
    );
  }
} // ← cierra _PaginaFundamentalState
// ===== Resumen (top-level, fuera de la clase) =====
class _ResumenEmpresa {
  final List<String> fortalezas;
  final List<String> mejoras;
  final String comentario;
  _ResumenEmpresa(this.fortalezas, this.mejoras, this.comentario);
}

_ResumenEmpresa _buildResumenEmpresa({
  required List<_EvalRow> op,
  required List<_EvalRow> rent,
  required List<_EvalRow> estr,
  required double score10Num,
}) {
  final todas = [...op, ...rent, ...estr];

  final fortalezas = todas
      .where((r) => r.rating == _Rating.bueno)
      .map((r) => '${r.indicador} (${r.valor})')
      .toList();

final peores = todas
    .where((r) => r.rating == _Rating.malo)
    .map((r) => '${r.indicador} (${r.valor}) — ${r.baremo}')
    .toList();

final neutros = todas
    .where((r) => r.rating == _Rating.neutro)
    .map((r) => '${r.indicador} (${r.valor}) — ${r.baremo}')
    .toList();


  final mejoras = [...peores, ...neutros];

  String comentario;
  if (score10Num >= 8) {
    comentario =
        'Empresa fuerte: márgenes y crecimiento en buena forma. Vigilar que los indicadores en “Mejoras” no se deterioren.';
  } else if (score10Num >= 6) {
    comentario =
        'Empresa razonable: base aceptable, pero hay áreas claras de mejora. Prioriza atacar los puntos con “Malo”.';
  } else {
    comentario =
        'Perfil de riesgo elevado: fundamentales flojos. Requiere mejoras significativas antes de considerarla una inversión core.';
  }

  List<String> top5(List<String> xs) => xs.length > 5 ? xs.take(5).toList() : xs;

  return _ResumenEmpresa(top5(fortalezas), top5(mejoras), comentario);
}

// ↓↓↓ Fuera de la clase ↓↓↓
class _RankRow {
  final String ticker;
  final double value;
  final int? year;
  _RankRow({required this.ticker, required this.value, required this.year});
}
