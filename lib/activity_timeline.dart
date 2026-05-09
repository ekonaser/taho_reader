import 'package:flutter/material.dart';
import 'taho_models.dart';
import 'dart:math';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ActivitySummary {
  int rest = 0;
  int availability = 0;
  int work = 0;
  int driving = 0;

  void reset() {
    rest = 0;
    availability = 0;
    work = 0;
    driving = 0;
  }
}

class ActivityTimeline extends StatefulWidget {
  final List<DailyActivities> activities;
  final DateTime? selectedDate;
  final VoidCallback? onDateTap;
  final int utcOffset;
  final ValueChanged<int> onUtcOffsetChanged;

  const ActivityTimeline({
    super.key,
    required this.activities,
    this.selectedDate,
    this.onDateTap,
    required this.utcOffset,
    required this.onUtcOffsetChanged,
  });

  @override
  State<ActivityTimeline> createState() => _ActivityTimelineState();
}

enum _ViewMode { daily, last14Days, monthly }

class _ActivityTimelineState extends State<ActivityTimeline> {
  double _hourWidth = 120.0;
  final ActivitySummary _summary = ActivitySummary();
  _ViewMode _viewMode = _ViewMode.daily;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.activities.isNotEmpty) {
      _selectedMonth = DateTime(widget.activities.first.date.year, widget.activities.first.date.month);
    }
  }

  Widget _buildToggleItem(String label, bool isSelected, VoidCallback onTap, Color primaryGreen) {
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
              color: isSelected ? Colors.white : Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF28B52F);
    final double totalWidth = _hourWidth * 27;

    if (widget.activities.isEmpty) {
      return const Center(
          child: Text("No activity data found.\nUpload a file or read a card.",
              textAlign: TextAlign.center));
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
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildToggleItem("Daily", _viewMode == _ViewMode.daily, () => setState(() => _viewMode = _ViewMode.daily), primaryGreen),
                  _buildToggleItem("14 Days", _viewMode == _ViewMode.last14Days, () => setState(() => _viewMode = _ViewMode.last14Days), primaryGreen),
                  _buildToggleItem("Monthly", _viewMode == _ViewMode.monthly, () => setState(() => _viewMode = _ViewMode.monthly), primaryGreen),
                ],
              ),
            ),
          ),

          if (_viewMode == _ViewMode.daily) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Daily Activity",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                          const Icon(Icons.calendar_month, size: 16, color: primaryGreen),
                          const SizedBox(width: 4),
                          Text(
                            day.date.toLocal().toString().split(' ').first,
                            style: const TextStyle(color: primaryGreen, fontWeight: FontWeight.bold),
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
                  const Icon(Icons.zoom_out, size: 18, color: Colors.grey),
                  Expanded(
                    child: Slider(
                      value: _hourWidth,
                      min: 70.0,
                      max: 500.0,
                      activeColor: primaryGreen,
                      onChanged: (val) => setState(() => _hourWidth = val),
                    ),
                  ),
                  const Icon(Icons.zoom_in, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 42,
                    child: Text(
                      "${(_hourWidth / 70.0).toStringAsFixed(1)}x",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
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
                              left: BorderSide(color: Colors.grey.withValues(alpha: 0.3), width: 1),
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
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
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
                  const Text(
                    "Activity Log",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf, color: primaryGreen),
                    onPressed: () => _exportToPdf(day, primaryGreen),
                    tooltip: "Export to PDF",
                  ),
                ],
              ),
            ),
            ..._buildActivityLog(day, primaryGreen),
            const SizedBox(height: 32),
          ] else if (_viewMode == _ViewMode.last14Days) ...[
            // Last 14 Days View
            _buildSummaryHeader("Last 14 Days", "Summary for the most recent 14 days of activity", primaryGreen),
            _buildSummaryContent(_calculate14DaySummary(), primaryGreen),
            const SizedBox(height: 32),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text("Activity Statistics", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            _buildVisualBreakdown(primaryGreen, _calculate14DaySummary()),
          ] else ...[
            // Monthly View
            _buildSummaryHeader(
              "Monthly Activity",
              "Total summary for the selected period",
              primaryGreen,
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
                      const Icon(Icons.calendar_month, size: 20, color: primaryGreen),
                      const SizedBox(width: 8),
                      Text(
                        "${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}",
                        style: const TextStyle(
                          color: primaryGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, color: primaryGreen),
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

  Widget _buildSummaryHeader(String title, String subtitle, Color primaryGreen, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          if (trailing != null) trailing,
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
      for (int i = 1; i < day.activities.length; i++) {
        final prev = day.activities[i - 1];
        final curr = day.activities[i];
        final duration = curr.time - prev.time;
        if (duration <= 0) continue;

        switch (prev.activity) {
          case 0: summary.rest += duration; break;
          case 1: summary.availability += duration; break;
          case 2: summary.work += duration; break;
          case 3: summary.driving += duration; break;
        }

        // If this record indicates card extraction, skip the interval to the next insertion
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

  ActivitySummary _calculate14DaySummary() {
    // 1. Calculate the 14 eligible UTC midnight timestamps (mimicking Python logic)
    final double now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final int todayMidnight = (now - (now % 86400)).toInt();

    final Set<int> eligibleDays = {};
    for (int i = 0; i < 14; i++) {
      eligibleDays.add(todayMidnight - (i * 86400));
    }

    final summary = ActivitySummary();

    // 2. Iterate through activities and check against eligibleDays
    for (var day in widget.activities) {
      final dt = day.date.toUtc();
      final ts = DateTime.utc(dt.year, dt.month, dt.day).millisecondsSinceEpoch ~/ 1000;

      if (eligibleDays.contains(ts)) {
        // Sum activities exactly like in the Daily View (handling session gaps)
        for (int i = 1; i < day.activities.length; i++) {
          final prev = day.activities[i - 1];
          final curr = day.activities[i];

          final duration = curr.time - prev.time;
          if (duration > 0) {
            switch (prev.activity) {
              case 0: summary.rest += duration; break;
              case 1: summary.availability += duration; break;
              case 2: summary.work += duration; break;
              case 3: summary.driving += duration; break;
            }
          }

          // If this record indicates card extraction, skip the interval to the next insertion
          if (curr.card == 0) i++;
        }
      }
    }
    return summary;
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
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(width: 20, height: 20, child: CustomPaint(painter: painter)),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
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

  Future<void> _exportToPdf(DailyActivities day, Color primaryGreen) async {
    final doc = pw.Document();
    final pdfPrimaryGreen = PdfColor.fromInt(primaryGreen.toARGB32());
    final dateStr = day.date.toLocal().toString().split(' ').first;
    final utcStr = "UTC ${widget.utcOffset >= 0 ? '+' : ''}${widget.utcOffset}";

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("Tacho Activity Report", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: pdfPrimaryGreen)),
                    pw.Text("Date: $dateStr", style: const pw.TextStyle(fontSize: 14)),
                  ],
                ),
                pw.Text(utcStr, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text("Timeline (27h View)", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            _buildPdfTimeline(day, pdfPrimaryGreen),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Text("Detailed Activity Log", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            ..._buildPdfActivityLog(day, pdfPrimaryGreen),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) => doc.save(),
      name: 'ActivityLog_$dateStr.pdf',
    );
  }

  pw.Widget _buildPdfTimeline(DailyActivities day, PdfColor primaryColor) {
    const double totalHours = 27.0;
    final double pageWidth = 500.0; // Standard usable width on A4
    final double hourWidth = pageWidth / totalHours;

    List<pw.Widget> blocks = [];

    void drawBlocks(int startIndex, int counter) {
      if (counter <= 0) return;
      int ptr = startIndex;
      int internalCounter = counter;
      final firstAct = day.activities[ptr];
      int activityType = firstAct.activity;
      int activitySlot = firstAct.slot;
      double activityTime = (firstAct.time + widget.utcOffset * 60) / 60.0;
      double prevTime = activityTime;

      // Start session line
      blocks.add(pw.Positioned(
        left: activityTime * hourWidth - 0.5,
        top: activitySlot == 1 ? 4 : 32,
        child: pw.Container(width: 1, height: 24, color: PdfColors.black),
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
          if (activityType == 2) color = PdfColors.orange;
          if (activityType == 3) color = PdfColors.blue;

          blocks.add(pw.Positioned(
            left: prevTime * hourWidth,
            top: activitySlot == 1 ? 4 : 32,
            child: pw.Container(
              width: max(1.0, duration * hourWidth),
              height: 24,
              color: color,
            ),
          ));
        }

        if (currentAct.slot != activitySlot) {
          blocks.add(pw.Positioned(
            left: activityTime * hourWidth - 0.5,
            top: activitySlot == 1 ? 4 : 32,
            child: pw.Container(width: 1, height: 24, color: PdfColors.black),
          ));
          blocks.add(pw.Positioned(
            left: activityTime * hourWidth - 0.5,
            top: currentAct.slot == 1 ? 4 : 32,
            child: pw.Container(width: 1, height: 24, color: PdfColors.black),
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
      blocks.add(pw.Positioned(
        left: activityTime * hourWidth - 0.5,
        top: activitySlot == 1 ? 4 : 32,
        child: pw.Container(width: 1, height: 24, color: PdfColors.black),
      ));
    }

    drawBlocks(0, day.activities.length * 2);

    return pw.Container(
      height: 60,
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
      child: pw.Stack(
        children: [
          pw.Positioned(
            left: 0,
            right: 0,
            top: 30,
            child: pw.Container(height: 0.5, color: PdfColors.grey200),
          ),
          // Hour markers
          ...List.generate(28, (h) => pw.Positioned(
            left: h * hourWidth,
            top: 0,
            bottom: 0,
            child: pw.Container(width: 0.5, color: PdfColors.grey300),
          )),
          ...blocks,
          pw.Positioned(
            left: 2,
            top: 10,
            child: pw.Text("S2", style: pw.TextStyle(fontSize: 6, color: PdfColors.grey400)),
          ),
          pw.Positioned(
            left: 2,
            top: 42,
            child: pw.Text("S1", style: pw.TextStyle(fontSize: 6, color: PdfColors.grey400)),
          ),
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
        if (type == 3) { // Driving: Circle with dot
          canvas.setStrokeColor(color);
          canvas.setLineWidth(1.0);
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
          // Rotation angle -45 degrees (matching TahoWorkPainter's -0.785 rad)
          const double cosA = 0.7071; // cos(-45deg)
          const double sinA = -0.7071; // sin(-45deg)
          // Scale down to fit within the PDF icon box (12x12)
          const double s = 0.7;

          void drawHammer(bool mirrored) {
            void drawPath(List<double> relCoords) {
              for (int i = 0; i < relCoords.length; i += 2) {
                final double rx = relCoords[i] * s;
                final double ry = relCoords[i + 1] * s;

                // 1. Rotate -45 degrees (around center 0,0)
                double rxRot = rx * cosA - ry * sinA;
                double ryRot = rx * sinA + ry * cosA;

                // 2. Mirror across Y-axis AFTER rotation to create the "X" shape
                if (mirrored) rxRot = -rxRot;

                // 3. Map to PDF coordinates (origin bottom-left, size 12x12)
                final double tx = cx + rxRot * w;
                final double ty = cy - ryRot * h;

                if (i == 0) {
                  canvas.moveTo(tx, ty);
                } else {
                  canvas.lineTo(tx, ty);
                }
              }
              canvas.closePath();
              canvas.fillPath();
            }

            // Handle: Rect(-0.06, -0.4, 0.12, 0.9) -> relative Y from -0.4 to 0.5
            drawPath([-0.06, -0.4, 0.06, -0.4, 0.06, 0.5, -0.06, 0.5]);
            // Head: Rect(-0.3, -0.5, 0.6, 0.2) -> relative Y from -0.5 to -0.3
            drawPath([-0.3, -0.5, 0.3, -0.5, 0.3, -0.3, -0.3, -0.3]);
          }

          drawHammer(false);
          drawHammer(true);
        } else if (type == 1) { // Availability: Box with diagonal
          canvas.setStrokeColor(color);
          canvas.setLineWidth(1.0);
          canvas.drawRect(size.x * 0.1, size.y * 0.1, size.x * 0.8, size.y * 0.8);
          canvas.strokePath();
          canvas.moveTo(size.x * 0.1, size.y * 0.1);
          canvas.lineTo(size.x * 0.9, size.y * 0.9);
          canvas.strokePath();
        } else if (type == 0) { // Rest: Bed icon
          canvas.setStrokeColor(color);
          canvas.setLineWidth(1.0);
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
    return "${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}";
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1), width: 1)),
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
              Text(label + slotStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text("$startStr - $endStr", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
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
        ],
      ),
    );
  }

  Widget _legendItem(CustomPainter painter, String label, int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final timeStr = "${h}h ${m.toString().padLeft(2, '0')}m";

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(18, 18),
          painter: painter,
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            Text(
              timeStr,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  // Natančen prevod C++ metode DrawOneDay(BYTE* ptr, int counter, ActivityData& pData)
  List<Widget> _buildRecursiveTimeline(DailyActivities day, Color primaryGreen) {
    List<Widget> widgets = [];
    if (day.activities.isEmpty) return widgets;

    _summary.reset();

    void drawOneDay(int startIndex, int counter) {
      if (counter <= 0) return;

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

        // switch (activityType) { ... FillRect ... }
        if (duration > 0) {
          Color color;
          switch (activityType) {
            case 0:
              color = primaryGreen;
              _summary.rest += durationMinutes;
              break; // REST (0x1FFF1F v C++)
            case 1:
              color = Colors.grey;
              _summary.availability += durationMinutes;
              break; // ADMIN/AVAIL (0x6B6B6B)
            case 2:
              color = Colors.orange;
              _summary.work += durationMinutes;
              break; // WORK (0xFF9D00)
            case 3:
              color = Colors.blue;
              _summary.driving += durationMinutes;
              break; // DRIVING (0x00A5FF)
            default:
              color = Colors.grey;
              break;
          }
          widgets.add(_buildActivityBlock(prevTime, duration, color, activitySlot));
        }

        // Draw session line if slot changes
        if (currentAct.slot != activitySlot) {
          widgets.add(_buildSessionLine(activityTime, activitySlot));
          widgets.add(_buildSessionLine(activityTime, currentAct.slot));
        }

        // activityType = (activity >> 11) & 0b11; (Update za naslednji interval)
        activityType = currentAct.activity;
        activitySlot = currentAct.slot;
        prevTime = activityTime;

        ptr++;
        internalCounter -= 2;

        // Natančen pogoj iz C++: if (((activity >> 13) & 0b1) && (counter > 2))
        if (currentAct.card == 0 && internalCounter > 2) {
          drawOneDay(ptr, internalCounter);
          break; // Izhod iz zanke v trenutni rekurzivni stopnji
        }
      }

      // MoveToEx / LineTo (Zaključna črta na koncu funkcije)
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
              style: TextStyle(fontSize: 7, color: Colors.grey[700], fontWeight: FontWeight.bold)),
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
              style: TextStyle(fontSize: 7, color: Colors.grey[700], fontWeight: FontWeight.bold)),
        ),
      ),
    ));
    widgets.add(Positioned(
      left: 0,
      right: 0,
      top: 39.5,
      child: Container(height: 1, color: Colors.grey.withValues(alpha: 0.2)),
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

  // Pomožna funkcija za risanje navpične črte ob vstavljanju/izvleku kartice (kot LineTo v C++)
  Widget _buildSessionLine(double hour, int slot) {
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
          color: Colors.black,
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.5),
              spreadRadius: 0.5,
              blurRadius: 0.5,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMinuteMarkers(int hour) {
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
            color: Colors.grey.withValues(alpha: 0.15),
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
                color: Colors.grey.withValues(alpha: 0.5),
              ),
            ),
          ),
        );
      }
    }
    return markers;
  }
}

class TahoDrivePainter extends CustomPainter {
  final Color color;
  const TahoDrivePainter({this.color = Colors.black});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.125;
    canvas.drawCircle(size.center(Offset.zero), size.width * 0.4, paint);
    final fillPaint = Paint()..color = color;
    canvas.drawCircle(size.center(Offset.zero), size.width * 0.1, fillPaint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TahoWorkPainter extends CustomPainter {
  final Color color;
  const TahoWorkPainter({this.color = Colors.black});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final double w = size.width;
    final double h = size.height;

    // Funkcija za risanje enega kladiva, ki ga bomo nato zrcalili
    void drawHammer(Canvas canvas, bool mirrored) {
      canvas.save();
      canvas.translate(w / 2, h / 2);
      if (mirrored) canvas.scale(-1, 1);
      canvas.rotate(-0.785); // 45 stopinj v radianih

      // Ročaj (handle)
      canvas.drawRect(
        Rect.fromLTWH(-w * 0.06, -h * 0.4, w * 0.12, h * 0.9),
        paint,
      );

      // Glava kladiva (head)
      // Narišemo glavo, ki je pravokotna na ročaj
      canvas.drawRect(
        Rect.fromLTWH(-w * 0.3, -h * 0.5, w * 0.6, h * 0.2),
        paint,
      );

      canvas.restore();
    }

    drawHammer(canvas, false);
    drawHammer(canvas, true);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TahoAvailabilityPainter extends CustomPainter {
  final Color color;
  const TahoAvailabilityPainter({this.color = Colors.black});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.15;
    final rect = Rect.fromLTWH(size.width * 0.1, size.height * 0.1, size.width * 0.8, size.height * 0.8);
    canvas.drawRect(rect, paint);
    canvas.drawLine(rect.bottomLeft, rect.topRight, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TahoRestPainter extends CustomPainter {
  final Color color;
  const TahoRestPainter({this.color = Colors.black});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square
      ..strokeWidth = size.width * 0.15;
    final path = Path();
    path.moveTo(size.width * 0.2, size.height * 0.8);
    path.lineTo(size.width * 0.2, size.height * 0.2);
    path.moveTo(size.width * 0.2, size.height * 0.5);
    path.lineTo(size.width * 0.8, size.height * 0.5);
    path.lineTo(size.width * 0.8, size.height * 0.8);
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}