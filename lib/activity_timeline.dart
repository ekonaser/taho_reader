import 'package:flutter/material.dart';
import 'taho_models.dart';
import 'taho_painters.dart';
import 'dart:math';
import 'taho_pdf_generator.dart';
import 'event_model.dart';


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
  final List<PlaceRecord> places;
  final List<PlaceRecordG2> placesG2;
  final List<DriverEvent> driverEvents;
  final List<DailyVehicles> vehicles;
  final List<DailyVehiclesG2> vehiclesG2;
  final bool isGen2View;
  final int initialViewMode;
  final Function(int)? onViewModeChanged;

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
    this.places = const [],
    this.placesG2 = const [],
    this.driverEvents = const [],
    this.vehicles = const [],
    this.vehiclesG2 = const [],
    this.isGen2View = false,
    this.initialViewMode = 0,
    this.onViewModeChanged,
  });

  @override
  State<ActivityTimeline> createState() => _ActivityTimelineState();
}

enum _ViewMode { daily, period, monthly }

class _ActivityTimelineState extends State<ActivityTimeline> {
  double _hourWidth = 120.0;
  final ActivitySummary _summary = ActivitySummary();
  late _ViewMode _viewMode;
  DateTime _selectedMonth = DateTime.now();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _includeDetailedTimeline = false;

  @override
  void initState() {
    super.initState();
    _viewMode = _ViewMode.values[widget.initialViewMode];
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryGreen = theme.primaryColor;
    final double totalWidth = _hourWidth * 27;

    final bool isSmallScreen = MediaQuery.sizeOf(context).width < 360;
    final double labelFontSize = isSmallScreen ? 10 : 14;
    final EdgeInsetsGeometry segmentPadding = EdgeInsets.symmetric(horizontal: isSmallScreen ? 4 : 12, vertical: 8);

    return Column(
      children: [
        // Toggle Selector always visible
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: SegmentedButton<_ViewMode>(
            segments: [
              ButtonSegment(
                value: _ViewMode.daily,
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Daily', style: TextStyle(fontSize: labelFontSize)),
                ),
                icon: const Icon(Icons.calendar_view_day),
              ),
              ButtonSegment(
                value: _ViewMode.period,
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Period', style: TextStyle(fontSize: labelFontSize)),
                ),
                icon: const Icon(Icons.date_range),
              ),
              ButtonSegment(
                value: _ViewMode.monthly,
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Monthly', style: TextStyle(fontSize: labelFontSize)),
                ),
                icon: const Icon(Icons.calendar_month),
              ),
            ],
            selected: {_viewMode},
            onSelectionChanged: (Set<_ViewMode> newSelection) {
              setState(() {
                _viewMode = newSelection.first;
              });
              widget.onViewModeChanged?.call(_viewMode.index);
            },
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: primaryGreen,
              selectedForegroundColor: Colors.white,
              padding: segmentPadding,
            ),
          ),
        ),
        Expanded(
          child: widget.activities.isEmpty
              ? Center(
                  child: Text(
                    "No activity data found.\nUpload a file or read a card.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                )
              : _buildContent(day: _getCurrentDay()),
        ),
      ],
    );
  }

  DailyActivities _getCurrentDay() {
    if (widget.activities.isEmpty) {
      return DailyActivities(
        header: ActivityDayHeader(
          prevLength: 0,
          currLength: 0,
          time: DateTime.now(),
          noActivity: 0,
          km: 0,
        ),
        activities: [],
      );
    }
    if (widget.selectedDate != null) {
      return widget.activities.firstWhere(
        (a) =>
            a.date.year == widget.selectedDate!.year &&
            a.date.month == widget.selectedDate!.month &&
            a.date.day == widget.selectedDate!.day,
        orElse: () => widget.activities.first,
      );
    }
    return widget.activities.first;
  }

  Widget _buildContent({required DailyActivities day}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryGreen = theme.primaryColor;
    final double totalWidth = _hourWidth * 27;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                          children: [
                            ..._buildRecursiveTimeline(day, primaryGreen),
                            ..._buildPlaceMarkers(day),
                            ..._buildEventMarkers(day),
                          ],
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
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                secondary: Icon(Icons.timeline, color: primaryGreen),
                title: const Text('Include Detailed Timeline'),
                subtitle: const Text('Adds high-resolution A4 page with detailed activities'),
                value: _includeDetailedTimeline,
                activeColor: primaryGreen,
                onChanged: (bool value) {
                  setState(() => _includeDetailedTimeline = value);
                  setModalState(() {});
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.share, color: primaryGreen),
                title: const Text('Share Daily PDF'),
                onTap: () {
                  Navigator.pop(context);
                  TachoPdfGenerator.exportDailyReport(
                    day: day,
                    primaryColor: primaryGreen,
                    cardId: widget.cardId,
                    vehicles: widget.vehicles,
                    vehiclesG2: widget.vehiclesG2,
                    allEvents: widget.driverEvents,
                    places: widget.places,
                    placesG2: widget.placesG2,
                    isGen2View: widget.isGen2View,
                    utcOffset: widget.utcOffset,
                    under50km: widget.under50km,
                    includeDetailedTimeline: _includeDetailedTimeline,
                    share: true,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.open_in_new, color: Colors.blue),
                title: const Text('Open PDF'),
                onTap: () {
                  Navigator.pop(context);
                  TachoPdfGenerator.exportDailyReport(
                    day: day,
                    primaryColor: primaryGreen,
                    cardId: widget.cardId,
                    vehicles: widget.vehicles,
                    vehiclesG2: widget.vehiclesG2,
                    allEvents: widget.driverEvents,
                    places: widget.places,
                    placesG2: widget.placesG2,
                    isGen2View: widget.isGen2View,
                    utcOffset: widget.utcOffset,
                    under50km: widget.under50km,
                    includeDetailedTimeline: _includeDetailedTimeline,
                    openImmediately: true,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.save_alt, color: Colors.green),
                title: const Text('Save PDF'),
                onTap: () {
                  Navigator.pop(context);
                  TachoPdfGenerator.exportDailyReport(
                    day: day,
                    primaryColor: primaryGreen,
                    cardId: widget.cardId,
                    vehicles: widget.vehicles,
                    vehiclesG2: widget.vehiclesG2,
                    allEvents: widget.driverEvents,
                    places: widget.places,
                    placesG2: widget.placesG2,
                    isGen2View: widget.isGen2View,
                    utcOffset: widget.utcOffset,
                    under50km: widget.under50km,
                    includeDetailedTimeline: _includeDetailedTimeline,
                    openImmediately: false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDailyExportOptions(DailyActivities day, Color primaryGreen) {
    // This method is now redundant as its logic was merged into _showExportOptions
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
                TachoPdfGenerator.exportSummaryReport(
                  days: days,
                  title: title,
                  rangeStr: rangeStr,
                  primaryColor: primaryGreen,
                  cardId: widget.cardId,
                  allEvents: widget.driverEvents,
                  utcOffset: widget.utcOffset,
                  under50km: widget.under50km,
                  share: true,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new, color: Colors.blue),
              title: const Text('Open Summary PDF'),
              onTap: () {
                Navigator.pop(context);
                TachoPdfGenerator.exportSummaryReport(
                  days: days,
                  title: title,
                  rangeStr: rangeStr,
                  primaryColor: primaryGreen,
                  cardId: widget.cardId,
                  allEvents: widget.driverEvents,
                  utcOffset: widget.utcOffset,
                  under50km: widget.under50km,
                  openImmediately: true,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.save_alt, color: Colors.green),
              title: const Text('Save Summary PDF'),
              onTap: () {
                Navigator.pop(context);
                TachoPdfGenerator.exportSummaryReport(
                  days: days,
                  title: title,
                  rangeStr: rangeStr,
                  primaryColor: primaryGreen,
                  cardId: widget.cardId,
                  allEvents: widget.driverEvents,
                  utcOffset: widget.utcOffset,
                  under50km: widget.under50km,
                  openImmediately: false,
                );
              },
            ),
          ],
        ),
      ),
    );
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

  List<Widget> _buildPlaceMarkers(DailyActivities day) {
    List<Widget> markers = [];
    final targetDate = day.date.toLocal();

    // Gen 1 Places
    for (var place in widget.places) {
      final pDate = place.entryTime.toLocal();
      if (pDate.year == targetDate.year && pDate.month == targetDate.month && pDate.day == targetDate.day) {
        markers.add(_buildPlaceMarker(place.entryTime, place.entryTypeDailyWorkPeriod, place.dailyWorkPeriodCountry));
      }
    }

    // Gen 2 Places
    for (var place in widget.placesG2) {
      final pDate = place.entryTime.toLocal();
      if (pDate.year == targetDate.year && pDate.month == targetDate.month && pDate.day == targetDate.day) {
        markers.add(_buildPlaceMarker(place.entryTime, place.entryTypeDailyWorkPeriod, place.dailyWorkPeriodCountry));
      }
    }

    return markers;
  }

  List<Widget> _buildEventMarkers(DailyActivities day) {
    List<Widget> markers = [];
    final targetDate = day.date.toLocal();

    for (var event in widget.driverEvents) {
      final eDate = event.date.toLocal();
      if (eDate.year == targetDate.year && eDate.month == targetDate.month && eDate.day == targetDate.day) {
        markers.add(_buildEventMarker(event));
      }
    }

    return markers;
  }

  Widget _buildEventMarker(DriverEvent event) {
    final double hour = (event.date.millisecondsSinceEpoch / 1000 + widget.utcOffset * 3600) % 86400 / 3600.0;
    final color = _getEventColor(event.type);

    return Positioned(
      left: hour * _hourWidth - 10.0,
      top: 85, // Prikaz pod časovnico
      child: Tooltip(
        message: "${event.type}: ${event.description}",
        child: Column(
          children: [
            Container(
              width: 2,
              height: 10,
              color: color.withOpacity(0.5),
            ),
            Icon(Icons.event_note, size: 20, color: color),
          ],
        ),
      ),
    );
  }

  Color _getEventColor(String type) {
    switch (type.toLowerCase()) {
      case 'operational events': return Colors.blue;
      case 'driver observations': return Colors.teal;
      case 'compliance events': return Colors.red;
      case 'personal events': return Colors.green;
      case 'security events': return Colors.orange;
      default: return Colors.grey;
    }
  }

  String _getCountryCode(int code) {
    final String name;
    switch (code) {
      case 1: name = "A"; break;
      case 2: name = "AL"; break;
      case 3: name = "AND"; break;
      case 4: name = "ARM"; break;
      case 5: name = "AZ"; break;
      case 6: name = "B"; break;
      case 7: name = "BG"; break;
      case 8: name = "BIH"; break;
      case 9: name = "BY"; break;
      case 10: name = "CH"; break;
      case 11: name = "CY"; break;
      case 12: name = "CZ"; break;
      case 13: name = "D"; break;
      case 14: name = "DK"; break;
      case 15: name = "E"; break;
      case 16: name = "EST"; break;
      case 17: name = "F"; break;
      case 18: name = "FIN"; break;
      case 19: name = "FL"; break;
      case 20: name = "FR, FO"; break;
      case 21: name = "UK"; break;
      case 22: name = "GE"; break;
      case 23: name = "GR"; break;
      case 24: name = "H"; break;
      case 25: name = "HR"; break;
      case 26: name = "I"; break;
      case 27: name = "IRL"; break;
      case 28: name = "IS"; break;
      case 29: name = "KZ"; break;
      case 30: name = "L"; break;
      case 31: name = "LT"; break;
      case 32: name = "LV"; break;
      case 33: name = "M"; break;
      case 34: name = "MC"; break;
      case 35: name = "MD"; break;
      case 36: name = "MK"; break;
      case 37: name = "N"; break;
      case 38: name = "NL"; break;
      case 39: name = "P"; break;
      case 40: name = "PL"; break;
      case 41: name = "RO"; break;
      case 42: name = "RSM"; break;
      case 43: name = "RUS"; break;
      case 44: name = "S"; break;
      case 45: name = "SK"; break;
      case 46: name = "SLO"; break;
      case 47: name = "TM"; break;
      case 48: name = "TR"; break;
      case 49: name = "UA"; break;
      case 50: name = "V"; break;
      case 51: name = "YU"; break;
      case 52: name = "MNE"; break;
      case 53: name = "SRB"; break;
      case 54: name = "UZ"; break;
      case 253: name = "EC"; break;
      case 254: name = "EUR"; break;
      case 255: name = "WLD"; break; // apparently UNK has same value as WLD
      default:
        return "Unknown ($code)";
    }
    return "$name";
  }

  Widget _buildPlaceMarker(DateTime entryTime, int type, int countryCode) {
    // type: 0 = start (insertion), 1 = end (withdrawal)
    final double hour = (entryTime.millisecondsSinceEpoch / 1000 + widget.utcOffset * 3600) % 86400 / 3600.0;
    
    final String country = _getCountryCode(countryCode);

    return Positioned(
      left: hour * _hourWidth - 4.0, // Centrirano za širino 8px
      top: -40, // Nižje in bližje časovnici
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            country,
            style: TextStyle(
              fontSize: 7, // Še manjša pisava
              fontWeight: FontWeight.bold, 
              color: type == 0 ? Colors.green : Colors.orange,
            ),
          ),
          const SizedBox(height: 1),
          SizedBox(
            width: 8,
            height: 12,
            child: CustomPaint(
              painter: type == 0 
                ? TahoInsertionPainter(color: Colors.green) 
                : TahoWithdrawalPainter(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
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


