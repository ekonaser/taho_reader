import 'package:flutter/material.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'taho_models.dart';
import 'taho_painters.dart';
import 'dart:math';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'pdf_helper.dart';

class ActivitySummary {
  int rest = 0;
  int availability = 0;
  int work = 0;
  int driving = 0;
  int overdrive = 0;

  void reset() {
    rest = 0;
    availability = 0;
    work = 0;
    driving = 0;
    overdrive = 0;
  }
}

class ActivityTimeline extends StatefulWidget {
  final List<DailyActivities> activities;
  final CardId? cardId;
  final DateTime? selectedDate;
  final VoidCallback? onDateTap;
  final VoidCallback? onPrevDay;
  final VoidCallback? onNextDay;
  final int utcOffset;
  final ValueChanged<int> onUtcOffsetChanged;
  final bool under50km;

  const ActivityTimeline({
    super.key,
    required this.activities,
    this.cardId,
    this.selectedDate,
    this.onDateTap,
    this.onPrevDay,
    this.onNextDay,
    required this.utcOffset,
    required this.onUtcOffsetChanged,
    required this.under50km,
  });

  @override
  State<ActivityTimeline> createState() => _ActivityTimelineState();
}

enum _ViewMode { daily, period, monthly }

class _ActivityTimelineState extends State<ActivityTimeline> {
  double _hourWidth = 120.0;
  final ActivitySummary _summary = ActivitySummary();
  _ViewMode _viewMode = _ViewMode.daily;
  DateTime _selectedMonth = DateTime.now();
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    if (widget.activities.isNotEmpty) {
      _selectedMonth = DateTime(widget.activities.first.date.year, widget.activities.first.date.month);
      // Default period: last 14 days or last available
      _endDate = widget.activities.first.date;
      _startDate = _endDate!.subtract(const Duration(days: 13));
    } else {
      _endDate = DateTime.now();
      _startDate = _endDate!.subtract(const Duration(days: 13));
    }
  }

  Widget _buildToggleItem(BuildContext context, String label, bool isSelected, VoidCallback onTap, Color primaryGreen) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? primaryGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryGreen = theme.primaryColor;
    final double totalWidth = _hourWidth * 27;

    if (widget.activities.isEmpty) {
      return Center(
          child: Text("No activity data found.\nUpload a file or read a card.",
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant)));
    }

    // Find the day to display in Daily view
    DailyActivities day;
    if (widget.selectedDate != null) {
      day = widget.activities.firstWhere(
            (a) => a.date.year == widget.selectedDate!.year &&
            a.date.month == widget.selectedDate!.month &&
            a.date.day == widget.selectedDate!.day,
        orElse: () => widget.activities.first,
      );
    } else {
      day = widget.activities.first;
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toggle Selector
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildToggleItem(context, "Daily", _viewMode == _ViewMode.daily, () => setState(() => _viewMode = _ViewMode.daily), primaryGreen),
                  _buildToggleItem(context, "Periods", _viewMode == _ViewMode.period, () => setState(() => _viewMode = _ViewMode.period), primaryGreen),
                  _buildToggleItem(context, "Monthly", _viewMode == _ViewMode.monthly, () => setState(() => _viewMode = _ViewMode.monthly), primaryGreen),
                ],
              ),
            ),
          ),

          if (_viewMode == _ViewMode.daily) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "Daily Activity",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: widget.onDateTap,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_month, size: 16, color: primaryGreen),
                          const SizedBox(width: 4),
                          Text(
                            day.date.toLocal().toString().split(' ').first,
                            style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Icon(Icons.zoom_out, size: 18, color: colorScheme.onSurfaceVariant),
                  Expanded(
                    child: Slider(
                      value: _hourWidth,
                      min: 70.0,
                      max: 500.0,
                      activeColor: primaryGreen,
                      onChanged: (val) => setState(() => _hourWidth = val),
                    ),
                  ),
                  Icon(Icons.zoom_in, size: 18, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 42,
                    child: Text(
                      "${(_hourWidth / 70.0).toStringAsFixed(1)}x",
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          onPressed: () => widget.onUtcOffsetChanged(widget.utcOffset == -12 ? 14 : widget.utcOffset - 1),
                        ),
                        Text(
                          "UTC ${widget.utcOffset >= 0 ? '+' : ''}${widget.utcOffset}",
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          onPressed: () => widget.onUtcOffsetChanged(widget.utcOffset == 14 ? -12 : widget.utcOffset + 1),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.chevron_left, color: primaryGreen),
                    onPressed: widget.onPrevDay,
                    tooltip: "Previous Day",
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right, color: primaryGreen),
                    onPressed: widget.onNextDay,
                    tooltip: "Next Day",
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 200,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Container(
                  width: totalWidth + 80,
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(27, (h) => Container(
                          width: _hourWidth,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5), width: 1),
                            ),
                          ),
                          child: Stack(
                            children: [
                              ..._buildMinuteMarkers(h),
                              Align(
                                alignment: Alignment.bottomLeft,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                                  child: Text(
                                    "${(h % 24).toString().padLeft(2, '0')}:00",
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                      ),
                      Positioned(
                        top: 40,
                        left: 0,
                        right: 0,
                        height: 80,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: _buildRecursiveTimeline(day, primaryGreen),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(),
            _buildLegend(primaryGreen, _summary),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Activity Log",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                  ),
                  IconButton(
                    icon: Icon(Icons.picture_as_pdf, color: primaryGreen),
                    onPressed: () => _showExportOptions(day, primaryGreen),
                    tooltip: "Export to PDF",
                  ),
                ],
              ),
            ),
            ..._buildActivityLog(day, primaryGreen),
            const SizedBox(height: 32),
          ] else if (_viewMode == _ViewMode.period) ...[
            // Period View
            _buildSummaryHeader(
              "Custom Period",
              "Summary for the selected range",
              primaryGreen,
              onExport: () {
                final days = _getFilteredRangeDays();
                final rangeStr = _startDate != null && _endDate != null
                    ? "${_startDate!.day}.${_startDate!.month} - ${_endDate!.day}.${_endDate!.month}"
                    : "Unknown";
                _showSummaryExportOptions(days, "Period Report", rangeStr, primaryGreen);
              },
              trailing: InkWell(
                onTap: () => _selectDateRange(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryGreen.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month, size: 20, color: primaryGreen),
                      const SizedBox(width: 8),
                      Text(
                        _startDate != null && _endDate != null
                            ? "${_startDate!.day}/${_startDate!.month} - ${_endDate!.day}/${_endDate!.month}"
                            : "Select Range",
                        style: TextStyle(
                          color: primaryGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Icon(Icons.arrow_drop_down, color: primaryGreen),
                    ],
                  ),
                ),
              ),
            ),
            _buildSummaryContent(_calculateRangeSummary(), primaryGreen),
            const SizedBox(height: 32),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text("Activity Statistics", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            _buildVisualBreakdown(primaryGreen, _calculateRangeSummary()),
          ] else ...[
            // Monthly View
            _buildSummaryHeader(
              "Monthly Activity",
              "Total summary for the selected period",
              primaryGreen,
              onExport: () {
                final days = _getFilteredMonthlyDays();
                final rangeStr = "${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}";
                _showSummaryExportOptions(days, "Monthly Report", rangeStr, primaryGreen);
              },
              trailing: InkWell(
                onTap: () => _selectMonth(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryGreen.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month, size: 20, color: primaryGreen),
                      const SizedBox(width: 8),
                      Text(
                        "${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}",
                        style: TextStyle(
                          color: primaryGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Icon(Icons.arrow_drop_down, color: primaryGreen),
                    ],
                  ),
                ),
              ),
            ),
            _buildSummaryContent(_calculateMonthlySummary(), primaryGreen),
            const SizedBox(height: 32),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                "Activity Statistics",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            _buildVisualBreakdown(primaryGreen, _calculateMonthlySummary()),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(String title, String subtitle, Color primaryGreen, {Widget? trailing, VoidCallback? onExport}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          if (onExport != null)
            IconButton(
              icon: Icon(Icons.picture_as_pdf, color: primaryGreen),
              onPressed: onExport,
            ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryContent(ActivitySummary summary, Color primaryGreen) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _summaryCard(const TahoDrivePainter(color: Colors.blue), "DRIVING", summary.driving, Colors.blue)),
              const SizedBox(width: 12),
              Expanded(child: _summaryCard(const TahoWorkPainter(color: Colors.orange), "WORK", summary.work, Colors.orange)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _summaryCard(const TahoAvailabilityPainter(color: Colors.grey), "AVAILABILITY", summary.availability, Colors.grey)),
              const SizedBox(width: 12),
              Expanded(child: _summaryCard(TahoRestPainter(color: primaryGreen), "REST", summary.rest, primaryGreen)),
            ],
          ),
        ],
      ),
    );
  }

  ActivitySummary _calculateSummary(List<DailyActivities> filteredDays) {
    final summary = ActivitySummary();
    for (var day in filteredDays) {
      if (day.activities.isEmpty) continue;
      
      int accumulatedDriving = 0;
      bool hasFirstBreakPart = false;

      for (int i = 1; i < day.activities.length; i++) {
        final prev = day.activities[i - 1];
        final curr = day.activities[i];
        final duration = curr.time - prev.time;
        if (duration <= 0) continue;

        switch (prev.activity) {
          case 0: 
            summary.rest += duration;
            if (!widget.under50km) {
              if (duration >= 45) {
                accumulatedDriving = 0;
                hasFirstBreakPart = false;
              } else if (duration >= 30 && hasFirstBreakPart) {
                accumulatedDriving = 0;
                hasFirstBreakPart = false;
              } else if (duration >= 15 && !hasFirstBreakPart) {
                hasFirstBreakPart = true;
              }
            }
            break;
          case 1: 
            summary.availability += duration;
            if (!widget.under50km) {
              if (duration >= 45) {
                accumulatedDriving = 0;
                hasFirstBreakPart = false;
              } else if (duration >= 30 && hasFirstBreakPart) {
                accumulatedDriving = 0;
                hasFirstBreakPart = false;
              } else if (duration >= 15 && !hasFirstBreakPart) {
                hasFirstBreakPart = true;
              }
            }
            break;
          case 2: 
            summary.work += duration; 
            break;
          case 3: 
            summary.driving += duration;
            if (!widget.under50km) {
              accumulatedDriving += duration;
              if (accumulatedDriving > 270) {
                summary.overdrive += (accumulatedDriving - 270);
                accumulatedDriving = 270; 
              }
            }
            break;
        }

        if (curr.card == 0) i++;
      }
    }
    return summary;
  }

  ActivitySummary _calculateMonthlySummary() {
    final targetMonth = _selectedMonth.month;
    final targetYear = _selectedMonth.year;

    final filteredDays = widget.activities.where((day) =>
    day.date.year == targetYear && day.date.month == targetMonth).toList();

    return _calculateSummary(filteredDays);
  }

  List<DailyActivities> _getFilteredRangeDays() {
    if (_startDate == null || _endDate == null) return [];
    final startTs = DateTime.utc(_startDate!.year, _startDate!.month, _startDate!.day).millisecondsSinceEpoch ~/ 1000;
    final endTs = DateTime.utc(_endDate!.year, _endDate!.month, _endDate!.day).millisecondsSinceEpoch ~/ 1000;
    final Set<int> eligibleDays = {};
    for (int ts = startTs; ts <= endTs; ts += 86400) {
      eligibleDays.add(ts);
    }
    return widget.activities.where((day) {
      final dt = day.date.toUtc();
      final ts = DateTime.utc(dt.year, dt.month, dt.day).millisecondsSinceEpoch ~/ 1000;
      return eligibleDays.contains(ts);
    }).toList();
  }

  List<DailyActivities> _getFilteredMonthlyDays() {
    return widget.activities.where((day) =>
    day.date.year == _selectedMonth.year && day.date.month == _selectedMonth.month).toList();
  }

  ActivitySummary _calculateRangeSummary() {
    return _calculateSummary(_getFilteredRangeDays());
  }

  Widget _buildVisualBreakdown(Color primaryGreen, ActivitySummary summary) {
    final total = summary.driving + summary.work + summary.availability + summary.rest;
    if (total == 0) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 40,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            if (summary.driving > 0) Expanded(flex: summary.driving, child: Container(color: Colors.blue)),
            if (summary.work > 0) Expanded(flex: summary.work, child: Container(color: Colors.orange)),
            if (summary.availability > 0) Expanded(flex: summary.availability, child: Container(color: Colors.grey)),
            if (summary.rest > 0) Expanded(flex: summary.rest, child: Container(color: primaryGreen)),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: widget.activities.isEmpty ? DateTime(2000) : widget.activities.last.date,
      lastDate: widget.activities.isEmpty ? DateTime.now() : widget.activities.first.date,
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF28B52F),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _selectMonth(BuildContext context) async {
    final availableMonths = <String, DateTime>{};
    for (var act in widget.activities) {
      final date = act.date;
      final key = "${date.year}-${date.month.toString().padLeft(2, '0')}";
      if (!availableMonths.containsKey(key)) {
        availableMonths[key] = DateTime(date.year, date.month);
      }
    }

    final sortedKeys = availableMonths.keys.toList()..sort((a, b) => b.compareTo(a));

    if (sortedKeys.isEmpty) return;

    const primaryGreen = Color(0xFF28B52F);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Select Month"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: sortedKeys.length,
            itemBuilder: (context, index) {
              final key = sortedKeys[index];
              final isSelected = key == "${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}";
              return ListTile(
                title: Text(key, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                trailing: isSelected ? const Icon(Icons.check, color: primaryGreen) : null,
                onTap: () {
                  setState(() => _selectedMonth = availableMonths[key]!);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _summaryCard(CustomPainter painter, String label, int minutes, Color color) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(width: 20, height: 20, child: CustomPaint(painter: painter)),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "${h}h ${m.toString().padLeft(2, '0')}m",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  void _showExportOptions(DailyActivities day, Color primaryGreen) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.share, color: primaryGreen),
              title: const Text('Share PDF'),
              onTap: () {
                Navigator.pop(context);
                _exportToPdf(day, primaryGreen, share: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new, color: Colors.blue),
              title: const Text('Open PDF'),
              onTap: () {
                Navigator.pop(context);
                _exportToPdf(day, primaryGreen, openImmediately: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.save_alt, color: Colors.green),
              title: const Text('Save PDF'),
              onTap: () {
                Navigator.pop(context);
                _exportToPdf(day, primaryGreen, openImmediately: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportToPdf(DailyActivities day, Color primaryGreen, {bool openImmediately = false, bool share = false}) async {
    final doc = pw.Document();
    final pdfPrimaryGreen = PdfColor.fromInt(primaryGreen.toARGB32());
    final dateStr = day.date.toLocal().toString().split(' ').first;
    final utcStr = "UTC ${widget.utcOffset >= 0 ? '+' : ''}${widget.utcOffset}";

    // Calculate totals for the PDF
    final pdfSummary = _calculateDaySummary(day);
    String formatDur(int mins) {
      return "${(mins ~/ 60).toString().padLeft(2, '0')}:${(mins % 60).toString().padLeft(2, '0')}";
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("Activity Report",
                        style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: pdfPrimaryGreen)),
                    pw.Text("Date: $dateStr", style: const pw.TextStyle(fontSize: 14)),
                  ],
                ),
                pw.Text(utcStr, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 10),
          ],
        ),
        build: (pw.Context context) {
          return [
            // Driver Information Section
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("DRIVER DETAILS", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      pw.Text("${widget.cardId?.name ?? 'Unknown'} ${widget.cardId?.surname ?? ''}",
                          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      pw.Text("Card: ${widget.cardId?.cardNumber ?? 'N/A'}", style: const pw.TextStyle(fontSize: 12)),
                      pw.Text("Birthday: ${widget.cardId?.formattedBirthday ?? 'N/A'}", style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("DAILY TOTALS", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      _pdfSummaryRow("Driving:", formatDur(pdfSummary.driving), PdfColors.blue),
                      _pdfSummaryRow("Work:", formatDur(pdfSummary.work), PdfColors.orange),
                      _pdfSummaryRow("Availability:", formatDur(pdfSummary.availability), PdfColors.grey),
                      _pdfSummaryRow("Rest:", formatDur(pdfSummary.rest), pdfPrimaryGreen),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text("DETAILED ACTIVITY LOG", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: pdfPrimaryGreen)),
            pw.Divider(thickness: 0.5, color: pdfPrimaryGreen),
            pw.SizedBox(height: 5),
            ..._buildPdfActivityLog(day, pdfPrimaryGreen),
          ];
        },
      ),
    );

    // Add Detailed Landscape Page for high-detail Timeline
    // Using A3 Landscape for maximum detail as requested by user
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a3.landscape,
        build: (pw.Context context) {
          final format = PdfPageFormat.a3.landscape;
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("HIGH-DETAIL ACTIVITY TIMELINE (A3)",
                          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: pdfPrimaryGreen)),
                      pw.Text("Driver: ${widget.cardId?.name} ${widget.cardId?.surname} | Date: $dateStr | $utcStr",
                          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: pdfPrimaryGreen, width: 1.5),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Text("HIGH RESOLUTION", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: pdfPrimaryGreen)),
                  ),
                ],
              ),
              pw.Expanded(
                child: pw.Center(
                  child: _buildDetailedLandscapeTimeline(day, pdfPrimaryGreen, format),
                ),
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  _pdfLegendItem("Rest", pdfPrimaryGreen, 0),
                  pw.SizedBox(width: 30),
                  _pdfLegendItem("Work", PdfColors.orange, 2),
                  pw.SizedBox(width: 30),
                  _pdfLegendItem("Availability", PdfColors.grey, 1),
                  pw.SizedBox(width: 30),
                  _pdfLegendItem("Driving", PdfColors.blue, 3),
                  pw.SizedBox(width: 30),
                  _pdfLegendItem("Session", PdfColors.black, -1),
                  pw.SizedBox(width: 30),
                  _pdfLegendItem("Crew", PdfColors.indigo, -2),
                ],
              ),
              pw.SizedBox(height: 20),
            ],
          );
        },
      ),
    );

    final fileName = 'ActivityLog_$dateStr';
    File? file;

    if (share) {
      await SaveAndOpenDocument.sharePdf(
        name: "Daily_$dateStr",
        pdf: doc,
      );
      return;
    } else if (openImmediately) {
      file = await SaveAndOpenDocument.savePdfToCache(
        pdf: doc,
      );
    } else {
      file = await SaveAndOpenDocument.savePdfWithPicker(
        name: fileName,
        pdf: doc,
      );
    }

    if (file == null) return;

    if (openImmediately) {
      await SaveAndOpenDocument.openFile(file);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("PDF saved to ${file.path}")),
        );
      }
    }
  }

  void _showSummaryExportOptions(List<DailyActivities> days, String title, String rangeStr, Color primaryGreen) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.share, color: primaryGreen),
              title: const Text('Share Summary PDF'),
              onTap: () {
                Navigator.pop(context);
                _exportSummaryToPdf(days, title, rangeStr, primaryGreen, share: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new, color: Colors.blue),
              title: const Text('Open Summary PDF'),
              onTap: () {
                Navigator.pop(context);
                _exportSummaryToPdf(days, title, rangeStr, primaryGreen, openImmediately: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.save_alt, color: Colors.green),
              title: const Text('Save Summary PDF'),
              onTap: () {
                Navigator.pop(context);
                _exportSummaryToPdf(days, title, rangeStr, primaryGreen, openImmediately: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportSummaryToPdf(List<DailyActivities> days, String title, String rangeStr, Color primaryGreen, {bool openImmediately = false, bool share = false}) async {
    final doc = pw.Document();
    final pdfPrimaryGreen = PdfColor.fromInt(primaryGreen.toARGB32());
    final summary = _calculateSummary(days);

    String formatDur(int mins) {
      final h = mins ~/ 60;
      final m = mins % 60;
      return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: pdfPrimaryGreen)),
                    pw.Text("Period: $rangeStr", style: const pw.TextStyle(fontSize: 14)),
                  ],
                ),
                pw.Text("UTC ${widget.utcOffset >= 0 ? '+' : ''}${widget.utcOffset}",
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 10),
          ],
        ),
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("DRIVER DETAILS", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                    pw.SizedBox(height: 4),
                    pw.Text("${widget.cardId?.name ?? 'Unknown'} ${widget.cardId?.surname ?? ''}",
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Card: ${widget.cardId?.cardNumber ?? 'N/A'}", style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text("GRAND TOTALS", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                    pw.SizedBox(height: 4),
                    _pdfSummaryRow("Driving:", formatDur(summary.driving), PdfColors.blue),
                    _pdfSummaryRow("Work:", formatDur(summary.work), PdfColors.orange),
                    _pdfSummaryRow("Availability:", formatDur(summary.availability), PdfColors.grey),
                    _pdfSummaryRow("Rest:", formatDur(summary.rest), pdfPrimaryGreen),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text("DAILY BREAKDOWN", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: pdfPrimaryGreen)),
          pw.Divider(thickness: 0.5, color: pdfPrimaryGreen),
          pw.SizedBox(height: 5),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headers: ['Date', 'Driving', 'Work', 'Availability', 'Rest'],
            data: days.map((day) {
              final s = _calculateDaySummary(day);
              return [
                day.date.toLocal().toString().split(' ').first,
                formatDur(s.driving),
                formatDur(s.work),
                formatDur(s.availability),
                formatDur(s.rest),
              ];
            }).toList(),
          ),
        ],
      ),
    );

    final fileName = '${title.replaceAll(' ', '_')}_$rangeStr';
    File? file;

    if (share) {
      await SaveAndOpenDocument.sharePdf(
        name: fileName,
        pdf: doc,
      );
      return;
    } else if (openImmediately) {
      file = await SaveAndOpenDocument.savePdfToCache(
        pdf: doc,
      );
    } else {
      file = await SaveAndOpenDocument.savePdfWithPicker(
        name: fileName,
        pdf: doc,
      );
    }

    if (file == null) return;

    if (openImmediately) {
      await SaveAndOpenDocument.openFile(file);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("PDF saved to ${file.path}")),
        );
      }
    }
  }

  pw.Widget _pdfLegendItem(String label, PdfColor color, int type) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.SizedBox(
          width: 14,
          height: 14,
          child: _buildPdfIcon(type, color),
        ),
        pw.SizedBox(width: 8),
        pw.Text(label, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  pw.Widget _buildDetailedLandscapeTimeline(DailyActivities day, PdfColor primaryColor, PdfPageFormat format) {
    const double totalHours = 27.0;
    const double labelWidth = 60.0;
    
    // Dynamically calculate width based on the actual page format (A3 Landscape)
    final double timelineWidth = format.width - format.marginLeft - format.marginRight - labelWidth - 20;
    final double hourWidth = timelineWidth / totalHours;

    List<pw.Widget> blocks = [];
    List<pw.Widget> sessionLines = [];
    List<pw.Widget> markers = [];

    // Compact track heights
    const double trackHeight = 30.0; 
    const double trackGap = 10.0;
    const double slot2Top = 15.0; // Co-driver / Slot 2
    const double separatorTop = slot2Top + trackHeight + (trackGap / 2);
    const double slot1Top = slot2Top + trackHeight + trackGap; // Driver / Slot 1
    const double totalTimelineHeight = slot1Top + trackHeight + 40; 

    // Detailed minute markers (every 5 and 15 minutes)
    for (int h = 0; h < 27; h++) {
      for (int m = 5; m < 60; m += 5) {
        double left = labelWidth + (h * hourWidth) + (m / 60.0) * hourWidth;
        bool isQuarter = m % 15 == 0;
        
        markers.add(pw.Positioned(
          left: left,
          top: isQuarter ? 10 : 20,
          bottom: 35,
          child: pw.Container(
            width: isQuarter ? 0.4 : 0.2, 
            color: isQuarter ? PdfColors.grey200 : PdfColors.grey100
          ),
        ));
        
        markers.add(pw.Positioned(
          left: left,
          bottom: 35,
          child: pw.Container(
            width: isQuarter ? 0.8 : 0.4, 
            height: isQuarter ? 5 : 2.5, 
            color: PdfColors.grey400
          ),
        ));
      }
    }

    void drawBlocks(int startIndex, int counter) {
      if (counter <= 0 || startIndex >= day.activities.length) return;

      int ptr = startIndex;
      int internalCounter = counter;
      final firstAct = day.activities[ptr];
      int activityType = firstAct.activity;
      int activitySlot = firstAct.slot;
      double activityTime = (firstAct.time + widget.utcOffset * 60) / 60.0;
      double prevTime = activityTime;

      // Start session line
      sessionLines.add(pw.Positioned(
        left: labelWidth + (activityTime * hourWidth) - 0.75,
        top: (activitySlot == 1 ? slot2Top : slot1Top) - 4,
        child: pw.Container(width: 1.5, height: trackHeight + 8, color: PdfColors.black),
      ));

      ptr++;
      internalCounter -= 2;

      while (internalCounter > 0 && ptr < day.activities.length) {
        final currentAct = day.activities[ptr];
        activityTime = (currentAct.time + widget.utcOffset * 60) / 60.0;
        double duration = activityTime - prevTime;

        if (duration > 0) {
          PdfColor color = PdfColors.grey;
          if (activityType == 0) color = primaryColor;
          else if (activityType == 2) color = PdfColors.orange;
          else if (activityType == 3) color = PdfColors.blue;

          // Activity block
          blocks.add(pw.Positioned(
            left: labelWidth + (prevTime * hourWidth),
            top: activitySlot == 1 ? slot2Top : slot1Top,
            child: pw.Opacity(
              opacity: 0.8,
              child: pw.Container(
                width: max(1.0, duration * hourWidth),
                height: trackHeight,
                color: color,
              ),
            ),
          ));

          if (day.activities[ptr - 1].crew == 1) {
            // Crew indicator
            blocks.add(pw.Positioned(
              left: labelWidth + (prevTime * hourWidth),
              top: (activitySlot == 1 ? slot2Top : slot1Top) + trackHeight - 0.5,
              child: pw.Container(
                width: max(0.5, duration * hourWidth),
                height: 1.5,
                color: PdfColors.indigo,
              ),
            ));
          }
        }

        if (currentAct.slot != activitySlot) {
          sessionLines.add(pw.Positioned(
            left: labelWidth + (activityTime * hourWidth) - 0.75,
            top: (activitySlot == 1 ? slot2Top : slot1Top) - 4,
            child: pw.Container(width: 1.5, height: trackHeight + 8, color: PdfColors.black),
          ));
          sessionLines.add(pw.Positioned(
            left: labelWidth + (activityTime * hourWidth) - 0.75,
            top: (currentAct.slot == 1 ? slot2Top : slot1Top) - 4,
            child: pw.Container(width: 1.5, height: trackHeight + 8, color: PdfColors.black),
          ));
        }

        activityType = currentAct.activity;
        activitySlot = currentAct.slot;
        prevTime = activityTime;
        ptr++;
        internalCounter -= 2;

        if (currentAct.card == 0 && internalCounter > 2) {
          drawBlocks(ptr, internalCounter);
          break;
        }
      }

      // End session line
      sessionLines.add(pw.Positioned(
        left: labelWidth + (activityTime * hourWidth) - 0.75,
        top: (activitySlot == 1 ? slot2Top : slot1Top) - 4,
        child: pw.Container(width: 1.5, height: trackHeight + 8, color: PdfColors.black),
      ));
    }

    drawBlocks(0, day.activities.length * 2);

    return pw.Container(
      height: totalTimelineHeight,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        color: PdfColors.white,
      ),
      child: pw.Stack(
        children: [
          // Track Labels
          pw.Positioned(
            left: 5,
            top: slot2Top + (trackHeight / 2) - 5,
            child: pw.Text("SLOT 2", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
          ),
          pw.Positioned(
            left: 5,
            top: slot1Top + (trackHeight / 2) - 5,
            child: pw.Text("SLOT 1", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
          ),
          // Separator
          pw.Positioned(
            left: labelWidth,
            right: 0,
            top: separatorTop,
            child: pw.Container(height: 1, color: PdfColors.grey300),
          ),
          // Grid lines
          ...markers,
          // Hour markers & Labels
          for (int h = 0; h <= 27; h++) ...[
            pw.Positioned(
              left: labelWidth + (h * hourWidth),
              top: 0,
              bottom: 35,
              child: pw.Container(width: 0.8, color: PdfColors.grey300),
            ),
            pw.Positioned(
              left: labelWidth + (h * hourWidth) - 20,
              bottom: 12,
              child: pw.SizedBox(
                width: 40,
                child: pw.Text(
                  "${(h % 24).toString().padLeft(2, '0')}:00",
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ),
          ],
          ...blocks,
          ...sessionLines,
        ],
      ),
    );
  }

  pw.Widget _pdfSummaryRow(String label, String value, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(width: 10),
          pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  ActivitySummary _calculateDaySummary(DailyActivities day) {
    final summary = ActivitySummary();
    if (day.activities.isEmpty) return summary;

    int accumulatedDriving = 0;
    bool hasFirstBreakPart = false;

    void process(int startIndex, int counter) {
      if (counter <= 0) return;
      int ptr = startIndex;
      int internalCounter = counter;
      ptr++;
      internalCounter -= 2;

      while (internalCounter > 0 && ptr < day.activities.length) {
        final currentAct = day.activities[ptr];
        int durationMinutes = (currentAct.time - day.activities[ptr - 1].time);
        int type = day.activities[ptr - 1].activity;

        if (durationMinutes > 0) {
          switch (type) {
            case 0: 
              summary.rest += durationMinutes; 
              if (!widget.under50km) {
                if (durationMinutes >= 45) {
                  accumulatedDriving = 0;
                  hasFirstBreakPart = false;
                } else if (durationMinutes >= 30 && hasFirstBreakPart) {
                  accumulatedDriving = 0;
                  hasFirstBreakPart = false;
                } else if (durationMinutes >= 15 && !hasFirstBreakPart) {
                  hasFirstBreakPart = true;
                }
              }
              break;
            case 1: 
              summary.availability += durationMinutes; 
              if (!widget.under50km) {
                if (durationMinutes >= 45) {
                  accumulatedDriving = 0;
                  hasFirstBreakPart = false;
                } else if (durationMinutes >= 30 && hasFirstBreakPart) {
                  accumulatedDriving = 0;
                  hasFirstBreakPart = false;
                } else if (durationMinutes >= 15 && !hasFirstBreakPart) {
                  hasFirstBreakPart = true;
                }
              }
              break;
            case 2: summary.work += durationMinutes; break;
            case 3: 
              summary.driving += durationMinutes; 
              if (!widget.under50km) {
                accumulatedDriving += durationMinutes;
                if (accumulatedDriving > 270) {
                  summary.overdrive += (accumulatedDriving - 270);
                  accumulatedDriving = 270;
                }
              }
              break;
          }
        }
        ptr++;
        internalCounter -= 2;
        if (currentAct.card == 0 && internalCounter > 2) {
          process(ptr, internalCounter);
          break;
        }
      }
    }

    process(0, day.activities.length * 2);
    return summary;
  }

  pw.Widget _buildPdfTimeline(DailyActivities day, PdfColor primaryColor) {
    const double totalHours = 27.0;
    const double labelWidth = 25.0;
    const double timelineWidth = 480.0;
    final double hourWidth = timelineWidth / totalHours;

    List<pw.Widget> blocks = [];
    List<pw.Widget> sessionLines = [];

    void drawBlocks(int startIndex, int counter) {
      if (counter <= 0 || startIndex >= day.activities.length) return;

      int ptr = startIndex;
      int internalCounter = counter;
      final firstAct = day.activities[ptr];
      int activityType = firstAct.activity;
      int activitySlot = firstAct.slot;
      double activityTime = (firstAct.time + widget.utcOffset * 60) / 60.0;
      double prevTime = activityTime;

      // Start session line
      sessionLines.add(pw.Positioned(
        left: labelWidth + (activityTime * hourWidth) - 1.0,
        top: activitySlot == 1 ? 2 : 30,
        child: pw.Container(width: 2.0, height: 28, color: PdfColors.black),
      ));

      ptr++;
      internalCounter -= 2;

      while (internalCounter > 0 && ptr < day.activities.length) {
        final currentAct = day.activities[ptr];
        activityTime = (currentAct.time + widget.utcOffset * 60) / 60.0;
        double duration = activityTime - prevTime;

        if (duration > 0) {
          PdfColor color = PdfColors.grey;
          if (activityType == 0) color = primaryColor;
          else if (activityType == 2) color = PdfColors.orange;
          else if (activityType == 3) color = PdfColors.blue;

          blocks.add(pw.Positioned(
            left: labelWidth + (prevTime * hourWidth),
            top: activitySlot == 1 ? 4 : 32,
            child: pw.Container(
              width: max(0.5, duration * hourWidth),
              height: 24,
              color: color,
            ),
          ));

          if (day.activities[ptr - 1].crew == 1) {
            blocks.add(pw.Positioned(
              left: labelWidth + (prevTime * hourWidth),
              top: activitySlot == 1 ? 4 + 22 : 32 + 22,
              child: pw.Container(
                width: max(0.5, duration * hourWidth),
                height: 2,
                color: PdfColors.indigo,
              ),
            ));
          }
        }

        if (currentAct.slot != activitySlot) {
          sessionLines.add(pw.Positioned(
            left: labelWidth + (activityTime * hourWidth) - 1.0,
            top: activitySlot == 1 ? 2 : 30,
            child: pw.Container(width: 2.0, height: 28, color: PdfColors.black),
          ));
          sessionLines.add(pw.Positioned(
            left: labelWidth + (activityTime * hourWidth) - 1.0,
            top: currentAct.slot == 1 ? 2 : 30,
            child: pw.Container(width: 2.0, height: 28, color: PdfColors.black),
          ));
        }

        activityType = currentAct.activity;
        activitySlot = currentAct.slot;
        prevTime = activityTime;
        ptr++;
        internalCounter -= 2;

        if (currentAct.card == 0 && internalCounter > 2) {
          drawBlocks(ptr, internalCounter);
          break;
        }
      }

      // End session line
      sessionLines.add(pw.Positioned(
        left: labelWidth + (activityTime * hourWidth) - 1.0,
        top: activitySlot == 1 ? 2 : 30,
        child: pw.Container(width: 2.0, height: 28, color: PdfColors.black),
      ));
    }

    drawBlocks(0, day.activities.length * 2);

    return pw.Center(
      child: pw.Column(
        children: [
          pw.Container(
            height: 85,
            width: labelWidth + timelineWidth + 10,
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 0.5)),
            child: pw.Stack(
              children: [
                // Track Labels
                pw.Positioned(
                  left: 4,
                  top: 12,
                  child: pw.Text("S2", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                ),
                pw.Positioned(
                  left: 4,
                  top: 40,
                  child: pw.Text("S1", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                ),
                // Separator
                pw.Positioned(
                  left: labelWidth,
                  right: 0,
                  top: 30,
                  child: pw.Container(height: 0.5, color: PdfColors.grey300),
                ),
                // Hour markers & Labels
                for (int h = 0; h < 28; h++) ...[
                  pw.Positioned(
                    left: labelWidth + (h * hourWidth),
                    top: 0,
                    bottom: 25,
                    child: pw.Container(width: 0.5, color: PdfColors.grey200),
                  ),
                  if (h > 0 && h < 27 && (h % 2 == 0))
                    pw.Positioned(
                      left: labelWidth + (h * hourWidth) - 10,
                      bottom: 5,
                      child: pw.SizedBox(
                        width: 20,
                        child: pw.Text(
                          "${(h % 24).toString().padLeft(2, '0')}:00",
                          style: pw.TextStyle(fontSize: 6, color: PdfColors.grey800),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ),
                ],
                ...blocks,
                ...sessionLines,
              ],
            ),
          ),
          pw.SizedBox(height: 10),
        ],
      ),
    );
  }

  List<pw.Widget> _buildPdfActivityLog(DailyActivities day, PdfColor primaryColor) {
    List<pw.Widget> items = [];

    void process(int startIndex, int counter) {
      if (counter <= 0) return;
      int ptr = startIndex;
      int internalCounter = counter;
      final firstAct = day.activities[ptr];
      int activityType = firstAct.activity;
      int activitySlot = firstAct.slot;
      int prevTime = firstAct.time;
      ptr++;
      internalCounter -= 2;

      while (internalCounter > 0 && ptr < day.activities.length) {
        final currentAct = day.activities[ptr];
        int duration = currentAct.time - prevTime;
        if (duration > 0) {
          items.add(_pdfActivityItem(activityType, prevTime, currentAct.time, duration, activitySlot, primaryColor));
        }
        activityType = currentAct.activity;
        activitySlot = currentAct.slot;
        prevTime = currentAct.time;
        ptr++;
        internalCounter -= 2;
        if (currentAct.card == 0 && internalCounter > 2) {
          process(ptr, internalCounter);
          break;
        }
      }
    }

    process(0, day.activities.length * 2);
    return items;
  }

  pw.Widget _buildPdfIcon(int type, PdfColor color) {
    return pw.CustomPaint(
      size: const PdfPoint(12, 12),
      painter: (PdfGraphics canvas, PdfPoint size) {
        if (type == -1) { // Session: Vertical line
          canvas.setStrokeColor(color);
          canvas.setLineWidth(1.0);
          canvas.moveTo(size.x / 2, 0);
          canvas.lineTo(size.x / 2, size.y);
          canvas.strokePath();
        } else if (type == -2) { // Crew: Horizontal line
          canvas.setStrokeColor(color);
          canvas.setLineWidth(1.5);
          canvas.moveTo(0, size.y / 2);
          canvas.lineTo(size.x, size.y / 2);
          canvas.strokePath();
        } else if (type == 3) { // Driving: Circle with dot
          canvas.setStrokeColor(color);
          canvas.setLineWidth(1.2);
          canvas.drawEllipse(size.x / 2, size.y / 2, size.x * 0.4, size.y * 0.4);
          canvas.strokePath();
          canvas.setFillColor(color);
          canvas.drawEllipse(size.x / 2, size.y / 2, size.x * 0.1, size.y * 0.1);
          canvas.fillPath();
        } else if (type == 2) { // Work: Crossed hammers
          canvas.setFillColor(color);
          final double w = size.x;
          final double h = size.y;
          final double cx = w / 2;
          final double cy = h / 2;
          const double cosA = 0.7071; 
          const double sinA = -0.7071; 
          const double s = 0.7;

          void drawHammer(bool mirrored) {
            void drawPath(List<double> relCoords) {
              for (int i = 0; i < relCoords.length; i += 2) {
                final double rx = relCoords[i] * s;
                final double ry = relCoords[i + 1] * s;
                double rxRot = rx * cosA - ry * sinA;
                double ryRot = rx * sinA + ry * cosA;
                if (mirrored) rxRot = -rxRot;
                final double tx = cx + rxRot * w;
                final double ty = cy - ryRot * h;
                if (i == 0) canvas.moveTo(tx, ty);
                else canvas.lineTo(tx, ty);
              }
              canvas.closePath();
              canvas.fillPath();
            }
            drawPath([-0.06, -0.4, 0.06, -0.4, 0.06, 0.5, -0.06, 0.5]);
            drawPath([-0.3, -0.5, 0.3, -0.5, 0.3, -0.3, -0.3, -0.3]);
          }
          drawHammer(false);
          drawHammer(true);
        } else if (type == 1) { // Availability: Box with diagonal
          canvas.setStrokeColor(color);
          canvas.setLineWidth(1.5);
          canvas.drawRect(size.x * 0.1, size.y * 0.1, size.x * 0.8, size.y * 0.8);
          canvas.strokePath();
          canvas.moveTo(size.x * 0.1, size.y * 0.1);
          canvas.lineTo(size.x * 0.9, size.y * 0.9);
          canvas.strokePath();
        } else if (type == 0) { // Rest: Bed icon
          canvas.setStrokeColor(color);
          canvas.setLineWidth(1.5);
          canvas.moveTo(size.x * 0.2, size.y * 0.2);
          canvas.lineTo(size.x * 0.2, size.y * 0.8);
          canvas.moveTo(size.x * 0.2, size.y * 0.5);
          canvas.lineTo(size.x * 0.8, size.y * 0.5);
          canvas.lineTo(size.x * 0.8, size.y * 0.2);
          canvas.strokePath();
        }
      },
    );
  }

  pw.Widget _pdfActivityItem(int type, int start, int end, int duration, int slot, PdfColor primaryColor) {
    String label = "Unknown";
    PdfColor color = PdfColors.grey;
    if (type == 0) { label = "Rest"; color = primaryColor; }
    else if (type == 1) { label = "Availability"; color = PdfColors.grey; }
    else if (type == 2) { label = "Work"; color = PdfColors.orange; }
    else if (type == 3) { label = "Driving"; color = PdfColors.blue; }

    final slotStr = slot == 1 ? " (Slot 2)" : " (Slot 1)";
    final startStr = _formatPdfTime(start);
    final endStr = _formatPdfTime(end);
    final durStr = _formatPdfDuration(duration);

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey100))),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 12, height: 12, child: _buildPdfIcon(type, color)),
          pw.SizedBox(width: 10),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label + slotStr, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.Text("$startStr - $endStr", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            ],
          ),
          pw.Spacer(),
          pw.Text(durStr, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: color)),
        ],
      ),
    );
  }

  String _formatPdfTime(int minutes) {
    int h = ((minutes + widget.utcOffset * 60) ~/ 60) % 24;
    if (h < 0) h += 24;
    int m = (minutes + widget.utcOffset * 60) % 60;
    if (m < 0) m += 60;
    return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";
  }

  String _formatPdfDuration(int minutes) {
    return "[${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}]";
  }


  List<Widget> _buildActivityLog(DailyActivities day, Color primaryGreen) {
    List<Widget> items = [];
    if (day.activities.isEmpty) return items;

    void processLog(int startIndex, int counter) {
      if (counter <= 0) return;
      int ptr = startIndex;
      int internalCounter = counter;

      final firstAct = day.activities[ptr];
      int activityType = firstAct.activity;
      int activitySlot = firstAct.slot;
      int prevTime = firstAct.time;

      ptr++;
      internalCounter -= 2;

      while (internalCounter > 0 && ptr < day.activities.length) {
        final currentAct = day.activities[ptr];
        int duration = currentAct.time - prevTime;

        if (duration > 0) {
          items.add(_activityLogItem(activityType, prevTime, currentAct.time, duration, primaryGreen, activitySlot));
        }

        activityType = currentAct.activity;
        activitySlot = currentAct.slot;
        prevTime = currentAct.time;

        ptr++;
        internalCounter -= 2;

        if (currentAct.card == 0 && internalCounter > 2) {
          processLog(ptr, internalCounter);
          break;
        }
      }
    }

    processLog(0, day.activities.length * 2);
    return items;
  }

  Widget _activityLogItem(int type, int start, int end, int duration, Color primaryGreen, int slot) {
    String label;
    CustomPainter painter;
    Color color;

    switch (type) {
      case 0:
        label = "Rest";
        painter = TahoRestPainter(color: primaryGreen);
        color = primaryGreen;
        break;
      case 1:
        label = "Availability";
        painter = const TahoAvailabilityPainter(color: Colors.grey);
        color = Colors.grey;
        break;
      case 2:
        label = "Work";
        painter = const TahoWorkPainter(color: Colors.orange);
        color = Colors.orange;
        break;
      case 3:
        label = "Driving";
        painter = const TahoDrivePainter(color: Colors.blue);
        color = Colors.blue;
        break;
      default:
        label = "Unknown";
        painter = const TahoAvailabilityPainter(color: Colors.grey);
        color = Colors.grey;
    }

    String formatTime(int totalMinutes) {
      int h = ((totalMinutes ~/ 60) % 24);
      if (h < 0) h += 24;
      int m = totalMinutes % 60;
      if (m < 0) m += 60;
      return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";
    }

    final startStr = formatTime(start + widget.utcOffset * 60);
    final endStr = formatTime(end + widget.utcOffset * 60);
    final durStr = "${(duration ~/ 60).toString().padLeft(2, '0')}:${(duration % 60).toString().padLeft(2, '0')}";

    final String slotStr = slot == 1 ? " (Slot 2)" : " (Slot 1)";

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5), width: 1)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CustomPaint(painter: painter),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label + slotStr, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colorScheme.onSurface)),
              Text("$startStr - $endStr", style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
            ],
          ),
          const Spacer(),
          Text(
            durStr,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 15,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(Color primaryGreen, ActivitySummary summary) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Wrap(
        spacing: 20,
        runSpacing: 10,
        children: [
          _legendItem(const TahoDrivePainter(color: Colors.blue), "Drive", summary.driving),
          _legendItem(const TahoWorkPainter(color: Colors.orange), "Work", summary.work),
          _legendItem(const TahoAvailabilityPainter(color: Colors.grey), "Availability", summary.availability),
          _legendItem(TahoRestPainter(color: primaryGreen), "Rest", summary.rest),
          if (summary.overdrive > 0)
            _legendItem(const Icon(Icons.warning, color: Colors.red, size: 18), "Overdrive", summary.overdrive),
          _legendItem(TahoSessionPainter(color: colorScheme.onSurface), "Session", -1),
          _legendItem(const TahoCrewPainter(color: Colors.indigo), "Crew", -1),
        ],
      ),
    );
  }

  Widget _legendItem(dynamic iconOrPainter, String label, int minutes) {
    final colorScheme = Theme.of(context).colorScheme;
    final timeStr = minutes >= 0 ? " ${minutes ~/ 60}h ${(minutes % 60).toString().padLeft(2, '0')}m" : "";

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (iconOrPainter is CustomPainter)
          CustomPaint(
            size: const Size(18, 18),
            painter: iconOrPainter,
          )
        else
          iconOrPainter as Widget,
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
            ),
            if (timeStr.isNotEmpty)
              Text(
                timeStr,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
              ),
          ],
        ),
      ],
    );
  }

  // Natančen prevod C++ metode DrawOneDay(BYTE* ptr, int counter, ActivityData& pData)
  List<Widget> _buildRecursiveTimeline(DailyActivities day, Color primaryGreen) {
    final colorScheme = Theme.of(context).colorScheme;
    List<Widget> widgets = [];
    _summary.reset();
    if (day.activities.isEmpty) return widgets;

    int accumulatedDriving = 0;
    bool hasFirstBreakPart = false;

    void drawOneDay(int startIndex, int counter) {
      if (counter <= 0) return;

      // Reset accumulated driving for each new session (e.g. after card is re-inserted)
      accumulatedDriving = 0;
      hasFirstBreakPart = false;

      int ptr = startIndex;
      int internalCounter = counter;

      // --- HEADER ---
      final firstAct = day.activities[ptr];
      int activityType = firstAct.activity;
      int activitySlot = firstAct.slot;
      double activityTime = (firstAct.time + widget.utcOffset * 60) / 60.0;
      double prevTime = activityTime;

      // MoveToEx / LineTo (Začetna črta seje)
      widgets.add(_buildSessionLine(activityTime, activitySlot));

      ptr++;
      internalCounter -= 2;

      // --- WHILE (counter > 0) ---
      while (internalCounter > 0 && ptr < day.activities.length) {
        final currentAct = day.activities[ptr];
        activityTime = (currentAct.time + widget.utcOffset * 60) / 60.0;
        double duration = activityTime - prevTime;
        int durationMinutes = (currentAct.time - day.activities[ptr - 1].time);

        // Reset if no card inserted (New session or card removed)
        // card == 0 means "No card inserted" based on bit 13 in the parser
        if (day.activities[ptr - 1].card == 0) {
          accumulatedDriving = 0;
          hasFirstBreakPart = false;
        }

        // switch (activityType) { ... FillRect ... }
        if (duration > 0) {
          Color color;
          switch (activityType) {
            case 0:
              color = primaryGreen;
              _summary.rest += durationMinutes;
              if (!widget.under50km) {
                if (durationMinutes >= 45) {
                  accumulatedDriving = 0;
                  hasFirstBreakPart = false;
                } else if (durationMinutes >= 30 && hasFirstBreakPart) {
                  accumulatedDriving = 0;
                  hasFirstBreakPart = false;
                } else if (durationMinutes >= 15 && !hasFirstBreakPart) {
                  hasFirstBreakPart = true;
                }
              }
              break; // REST
            case 1:
              color = Colors.grey;
              _summary.availability += durationMinutes;
              if (!widget.under50km) {
                if (durationMinutes >= 45) {
                  accumulatedDriving = 0;
                  hasFirstBreakPart = false;
                } else if (durationMinutes >= 30 && hasFirstBreakPart) {
                  accumulatedDriving = 0;
                  hasFirstBreakPart = false;
                } else if (durationMinutes >= 15 && !hasFirstBreakPart) {
                  hasFirstBreakPart = true;
                }
              }
              break; // ADMIN/AVAIL
            case 2:
              color = Colors.orange;
              _summary.work += durationMinutes;
              break; // WORK
            case 3:
              color = Colors.blue;
              _summary.driving += durationMinutes;
              if (!widget.under50km) {
                accumulatedDriving += durationMinutes;
                if (accumulatedDriving > 270) {
                  _summary.overdrive += (accumulatedDriving - 270);
                  // Draw regular part in blue
                  double regularDuration = (270 - (accumulatedDriving - durationMinutes)) / 60.0;
                  if (regularDuration > 0) {
                    widgets.add(_buildActivityBlock(prevTime, regularDuration, Colors.blue, activitySlot));
                  }
                  // Draw overdrive part in red
                  double overdriveDuration = (accumulatedDriving - 270) / 60.0;
                  widgets.add(_buildActivityBlock(prevTime + max(0, regularDuration), overdriveDuration, Colors.red, activitySlot));
                  
                  accumulatedDriving = 270;
                  // Skip standard draw below
                  color = Colors.transparent; 
                } else {
                  color = Colors.blue;
                }
              } else {
                color = Colors.blue;
              }
              break; // DRIVING
            default:
              color = Colors.grey;
              break;
          }
          if (color != Colors.transparent) {
            widgets.add(_buildActivityBlock(prevTime, duration, color, activitySlot));
          }

          if (day.activities[ptr - 1].crew == 1) {
            widgets.add(_buildCrewLine(prevTime, duration, activitySlot));
          }
        }

        // Draw session line if slot changes
        if (currentAct.slot != activitySlot) {
          widgets.add(_buildSessionLine(activityTime, activitySlot));
          widgets.add(_buildSessionLine(activityTime, currentAct.slot));
        }

        activityType = currentAct.activity;
        activitySlot = currentAct.slot;
        prevTime = activityTime;

        ptr++;
        internalCounter -= 2;

        if (currentAct.card == 0 && internalCounter > 2) {
          drawOneDay(ptr, internalCounter);
          break;
        }
      }

      widgets.add(_buildSessionLine(activityTime, activitySlot));
    }

    // Add slot labels and separator
    widgets.add(Positioned(
      left: -38,
      top: 5,
      height: 32,
      child: Center(
        child: RotatedBox(
          quarterTurns: 3,
          child: Text("SLOT 2",
              style: TextStyle(fontSize: 7, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
        ),
      ),
    ));
    widgets.add(Positioned(
      left: -38,
      top: 43,
      height: 32,
      child: Center(
        child: RotatedBox(
          quarterTurns: 3,
          child: Text("SLOT 1",
              style: TextStyle(fontSize: 7, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
        ),
      ),
    ));
    widgets.add(Positioned(
      left: 0,
      right: 0,
      top: 39.5,
      child: Container(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
    ));

    // Pokličemo s številom bajtov (2 bajta na zapis)
    drawOneDay(0, day.activities.length * 2);
    return widgets;
  }

  Widget _buildActivityBlock(double startHour, double durationHours, Color color, int slot) {
    final double blockWidth = max(2.0, durationHours * _hourWidth);
    // slot == 0 -> Driver (Bottom), slot == 1 -> Co-driver (Top)
    final double top = slot == 1 ? 5 : 43;
    const double height = 32;

    return Positioned(
      left: startHour * _hourWidth,
      width: blockWidth,
      top: top,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.black12, width: 0.5),
        ),
      ),
    );
  }

  Widget _buildCrewLine(double startHour, double durationHours, int slot) {
    final double blockWidth = max(2.0, durationHours * _hourWidth);
    final double top = slot == 1 ? 5 + 30 : 43 + 30;
    return Positioned(
      left: startHour * _hourWidth,
      width: blockWidth,
      top: top,
      height: 2,
      child: Container(
        color: Colors.indigo,
      ),
    );
  }

  // Pomožna funkcija za risanje navpične črte ob vstavljanju/izvleku kartice (kot LineTo v C++)
  Widget _buildSessionLine(double hour, int slot) {
    final colorScheme = Theme.of(context).colorScheme;
    // Further increased height to 40 (from 36) and adjusted top to protrude 4px above/below track
    // This makes the session boundaries much more prominent.
    final double top = slot == 1 ? 1 : 39;
    const double height = 40;
    return Positioned(
      left: hour * _hourWidth - 1,
      top: top,
      height: height,
      child: Container(
        width: 1.5,
        decoration: BoxDecoration(
          color: colorScheme.onSurface,
          boxShadow: [
            BoxShadow(
              color: colorScheme.surface.withValues(alpha: 0.5),
              spreadRadius: 0.5,
              blurRadius: 0.5,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMinuteMarkers(int hour) {
    final colorScheme = Theme.of(context).colorScheme;
    List<Widget> markers = [];
    int interval;

    if (_hourWidth > 420) {
      interval = 5;
    } else if (_hourWidth > 250) {
      interval = 15;
    } else if (_hourWidth > 120) {
      interval = 30;
    } else {
      return markers;
    }

    for (int m = interval; m < 60; m += interval) {
      double left = (m / 60.0) * _hourWidth;
      markers.add(
        Positioned(
          left: left,
          top: 0,
          bottom: 0,
          child: Container(
            width: 0.5,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
          ),
        ),
      );

      // Show text label (:15, :30, :45) only if there is enough space
      if (_hourWidth > 220 && (m % 15 == 0)) {
        markers.add(
          Positioned(
            left: left + 2,
            bottom: 8,
            child: Text(
              m.toString().padLeft(2, '0'),
              style: TextStyle(
                fontSize: 8,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
        );
      }
    }
    return markers;
  }
}


