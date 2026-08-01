import 'package:flutter/material.dart';
import 'taho_models.dart';
import 'taho_painters.dart';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'taho_pdf_generator.dart';
import 'event_model.dart';

class _TimelineBlock {
  final double left;
  final double top;
  final double width;
  final double height;
  final Color color;
  final bool isCrewLine;
  final int? durationMinutes;

  const _TimelineBlock({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.color,
    this.isCrewLine = false,
    this.durationMinutes,
  });
}

class _TimelinePlaceMarker {
  final double left;
  final double top;
  final String country;
  final Color color;
  final int type;

  const _TimelinePlaceMarker({
    required this.left,
    required this.top,
    required this.country,
    required this.color,
    required this.type,
  });
}

class _TimelineEventMarker {
  final double left;
  final double top;
  final Color color;

  const _TimelineEventMarker({
    required this.left,
    required this.top,
    required this.color,
  });
}

class _TimelineMinuteMarker {
  final double left;
  final bool showLabel;
  final String label;

  const _TimelineMinuteMarker({
    required this.left,
    required this.showLabel,
    required this.label,
  });
}

class _TimelineRenderData {
  final ActivitySummary summary;
  final List<_TimelineBlock> blocks;
  final List<_TimelineBlock> crewLines;
  final List<_TimelinePlaceMarker> placeMarkers;
  final List<_TimelineEventMarker> eventMarkers;
  final List<_TimelineMinuteMarker> minuteMarkers;
  final double separatorY;
  final double slot2LabelY;
  final double slot1LabelY;

  const _TimelineRenderData({
    required this.summary,
    required this.blocks,
    required this.crewLines,
    required this.placeMarkers,
    required this.eventMarkers,
    required this.minuteMarkers,
    required this.separatorY,
    required this.slot2LabelY,
    required this.slot1LabelY,
  });
}

void _paintTimeline({
  required Canvas canvas,
  required Size size,
  required double hourWidth,
  required double contentStartX,
  required ColorScheme colorScheme,
  required Color primaryGreen,
  required _TimelineRenderData renderData,
}) {
  final gridPaint = Paint()
    ..color = colorScheme.outlineVariant.withValues(alpha: 0.5)
    ..strokeWidth = 1;
  final minutePaint = Paint()
    ..color = colorScheme.onSurfaceVariant.withValues(alpha: 0.15)
    ..strokeWidth = 0.5;
  final separatorPaint = Paint()
    ..color = colorScheme.outlineVariant.withValues(alpha: 0.3)
    ..strokeWidth = 1;

  // Določi korak glede na širino za oznake ur (thinning logic)
  final int labelStep;
  if (hourWidth > 60) {
    labelStep = 1; // vsaka ura
  } else if (hourWidth > 30) {
    labelStep = 3; // vsaka 3. ura
  } else if (hourWidth > 15) {
    labelStep = 6; // vsaka 6. ura
  } else {
    labelStep = 12; // samo 00, 12, 24
  }

  for (int h = 0; h <= 24; h++) {
    final x = contentStartX + h * hourWidth;
    
    // Riši grid črto samo če rišemo labelo ali če je dovolj prostora
    if (hourWidth > 20 || h % labelStep == 0) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    if (h <= 24 && h % labelStep == 0) {
      final labelPainter = TextPainter(
        text: TextSpan(
          text: '${(h % 24).toString().padLeft(2, '0')}:00',
          style: TextStyle(
            fontSize: 10,
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      
      // Centriraj labelo na črti, če ni na koncu
      double labelX = x;
      if (h == 24) {
        labelX -= labelPainter.width;
      } else if (h > 0) {
        labelX -= labelPainter.width / 2;
      } else {
        labelX += 2;
      }
      
      labelPainter.paint(canvas, Offset(labelX, size.height - 24));
    }
  }

  for (final marker in renderData.minuteMarkers) {
    canvas.drawLine(
      Offset(contentStartX + marker.left, 0),
      Offset(contentStartX + marker.left, size.height),
      minutePaint,
    );
    if (marker.showLabel) {
      final labelPainter = TextPainter(
        text: TextSpan(
          text: marker.label,
          style: TextStyle(
            fontSize: 8,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(
        canvas,
        Offset(contentStartX + marker.left + 2, size.height - 24),
      );
    }
  }

  for (final block in renderData.blocks) {
    final rect = Rect.fromLTWH(
      block.left,
      block.top,
      block.width,
      block.height,
    );
    final fillPaint = Paint()..color = block.color.withValues(alpha: 0.8);
    canvas.drawRect(rect, fillPaint);

    if (block.durationMinutes != null && block.width > 18) {
      final int mins = block.durationMinutes!;
      final String durationText = mins >= 60
          ? "${mins ~/ 60}h ${mins % 60}m"
          : "${mins}m";

      final textPainter = TextPainter(
        text: TextSpan(
          text: durationText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      if (textPainter.width < block.width - 4) {
        final textOffset = Offset(
          block.left + (block.width - textPainter.width) / 2,
          block.top + (block.height - textPainter.height) / 2,
        );
        textPainter.paint(canvas, textOffset);
      }
    }
  }

  for (final line in renderData.crewLines) {
    canvas.drawRect(
      Rect.fromLTWH(line.left, line.top, line.width, line.height),
      Paint()..color = Colors.indigo,
    );
  }

  canvas.drawLine(
    Offset(contentStartX, renderData.separatorY),
    Offset(contentStartX + (24 * hourWidth), renderData.separatorY),
    separatorPaint,
  );

  for (final marker in renderData.placeMarkers) {
    final markerLinePaint = Paint()
      ..color = Colors.redAccent.withValues(alpha: 0.75)
      ..strokeWidth = 0.8;
    canvas.drawLine(
      Offset(marker.left, 0),
      Offset(marker.left, size.height),
      markerLinePaint,
    );

    final labelPainter = TextPainter(
      text: TextSpan(
        text: marker.country,
        style: TextStyle(
          fontSize: 7,
          fontWeight: FontWeight.bold,
          color: marker.color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    labelPainter.paint(canvas, Offset(marker.left + 6, marker.top + 14));

    final iconPainter = marker.type == 0
        ? TahoInsertionPainter(color: marker.color)
        : TahoWithdrawalPainter(color: marker.color);
    canvas.save();
    canvas.translate(marker.left + 6, marker.top);
    iconPainter.paint(canvas, const Size(8, 12));
    canvas.restore();
  }

  for (final marker in renderData.eventMarkers) {
    canvas.drawLine(
      Offset(marker.left, 120),
      Offset(marker.left, 130),
      Paint()
        ..color = marker.color.withValues(alpha: 0.5)
        ..strokeWidth = 2,
    );
    final iconPainter = IconPainter(color: marker.color);
    canvas.save();
    canvas.translate(marker.left - 10, 130);
    iconPainter.paint(canvas, const Size(20, 20));
    canvas.restore();
  }
}

class _TimelinePainter extends CustomPainter {
  final double hourWidth;
  final double contentStartX;
  final ColorScheme colorScheme;
  final Color primaryGreen;
  final _TimelineRenderData renderData;
  final ui.Picture? cachedPicture;
  final Size? cachedSize;

  _TimelinePainter({
    required this.hourWidth,
    required this.contentStartX,
    required this.colorScheme,
    required this.primaryGreen,
    required this.renderData,
    this.cachedPicture,
    this.cachedSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (cachedPicture != null && cachedSize != null && cachedSize == size) {
      canvas.drawPicture(cachedPicture!);
      return;
    }

    _paintTimeline(
      canvas: canvas,
      size: size,
      hourWidth: hourWidth,
      contentStartX: contentStartX,
      colorScheme: colorScheme,
      primaryGreen: primaryGreen,
      renderData: renderData,
    );
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) {
    return oldDelegate.hourWidth != hourWidth ||
        oldDelegate.contentStartX != contentStartX ||
        oldDelegate.colorScheme != colorScheme ||
        oldDelegate.primaryGreen != primaryGreen ||
        oldDelegate.renderData != renderData ||
        oldDelegate.cachedPicture != cachedPicture ||
        oldDelegate.cachedSize != cachedSize;
  }
}

class IconPainter extends CustomPainter {
  final Color color;
  const IconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * 0.35,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
  double _baseHourWidth = 120.0;
  final ActivitySummary _summary = ActivitySummary();
  late _ViewMode _viewMode;
  DateTime _selectedMonth = DateTime.now();
  ui.Picture? _cachedTimelinePicture;
  String? _cachedTimelineKey;
  Size? _cachedTimelineSize;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isManualZoom = false;

  @override
  void initState() {
    super.initState();
    _viewMode = _ViewMode.values[widget.initialViewMode];
    if (widget.activities.isNotEmpty) {
      _selectedMonth = DateTime(
        widget.activities.first.date.year,
        widget.activities.first.date.month,
      );
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
    final double totalWidth = _hourWidth * 24;

    final bool isSmallScreen = MediaQuery.sizeOf(context).width < 360;
    final double labelFontSize = isSmallScreen ? 10 : 14;
    final EdgeInsetsGeometry segmentPadding = EdgeInsets.symmetric(
      horizontal: isSmallScreen ? 4 : 12,
      vertical: 8,
    );

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
                  child: Text(
                    'Daily',
                    style: TextStyle(fontSize: labelFontSize),
                  ),
                ),
                icon: const Icon(Icons.calendar_view_day),
              ),
              ButtonSegment(
                value: _ViewMode.period,
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Period',
                    style: TextStyle(fontSize: labelFontSize),
                  ),
                ),
                icon: const Icon(Icons.date_range),
              ),
              ButtonSegment(
                value: _ViewMode.monthly,
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Monthly',
                    style: TextStyle(fontSize: labelFontSize),
                  ),
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

    return Builder(
      builder: (context) {
        final viewPadding = MediaQuery.paddingOf(context);
        final screenWidth = MediaQuery.sizeOf(context).width;
        final screenHeight = MediaQuery.sizeOf(context).height;
        final safeHorizontalInset =
            viewPadding.left + viewPadding.right + 24.0;
        final safeVerticalInset =
            viewPadding.top + viewPadding.bottom + 24.0;
        final maxTimelineWidth = screenWidth - safeHorizontalInset;
        final maxTimelineHeight =
            screenHeight - safeVerticalInset - 260.0;
        final timelineWidth = maxTimelineWidth.clamp(
          280.0,
          double.infinity,
        );
        final timelineHeight = max(
          160.0,
          min(200.0, maxTimelineHeight.clamp(160.0, 200.0)),
        );

        const double contentStartX = 0.0;
        final double availableWidth = timelineWidth - 32;
        final double fitWidth = availableWidth / 24.0;

        // Use fitWidth as default if not manually zoomed.
        // Also ensure we never go below fitWidth (e.g. after screen rotation).
        final double effectiveHourWidth =
            _isManualZoom ? max(_hourWidth, fitWidth) : fitWidth;

        // CRITICAL: Re-calculate render data based on the effective scale
        final renderData = _buildTimelineRenderData(
          day: day,
          primaryGreen: primaryGreen,
          colorScheme: colorScheme,
          hourWidth: effectiveHourWidth,
        );

        // Update summary for legend
        _summary.reset();
        _summary.rest = renderData.summary.rest;
        _summary.availability = renderData.summary.availability;
        _summary.work = renderData.summary.work;
        _summary.driving = renderData.summary.driving;
        _summary.overdrive = renderData.summary.overdrive;
        _summary.totalKm = renderData.summary.totalKm;

        final separatorY = renderData.separatorY;
        final labelOffset = 18.0;
        final slot2Top = separatorY - labelOffset - 8 * 2;
        final slot1Top = separatorY + labelOffset - 8;
        final pictureSize = Size(
          max(effectiveHourWidth * 24, timelineWidth - 32),
          timelineHeight,
        );

        final timelineCacheKey =
            '${day.date.toIso8601String()}-${widget.utcOffset}-${effectiveHourWidth.toStringAsFixed(2)}-${pictureSize.width.toStringAsFixed(2)}-${pictureSize.height.toStringAsFixed(2)}-${renderData.blocks.length}-${renderData.placeMarkers.length}-${renderData.minuteMarkers.length}';
        
        if (_cachedTimelinePicture == null ||
            _cachedTimelineKey != timelineCacheKey ||
            _cachedTimelineSize != pictureSize) {
          final recorder = ui.PictureRecorder();
          final pictureCanvas = Canvas(
            recorder,
            Rect.fromLTWH(0, 0, pictureSize.width, pictureSize.height),
          );
          _paintTimeline(
            canvas: pictureCanvas,
            size: pictureSize,
            hourWidth: effectiveHourWidth,
            contentStartX: contentStartX,
            colorScheme: colorScheme,
            primaryGreen: primaryGreen,
            renderData: renderData,
          );
          _cachedTimelinePicture = recorder.endRecording();
          _cachedTimelineKey = timelineCacheKey;
          _cachedTimelineSize = pictureSize;
        }

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
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: widget.onDateTap,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_month,
                                size: 16,
                                color: primaryGreen,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                day.date.toLocal().toString().split(' ').first,
                                style: TextStyle(
                                  color: primaryGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: SizedBox(
                    width: timelineWidth,
                    height: timelineHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 26,
                          height: timelineHeight,
                          child: Stack(
                            children: [
                              Positioned(
                                top: slot2Top,
                                child: RotatedBox(
                                  quarterTurns: 3,
                                  child: Text(
                                    'SLOT 2',
                                    style: TextStyle(
                                      fontSize: 7,
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: slot1Top,
                                child: RotatedBox(
                                  quarterTurns: 3,
                                  child: Text(
                                    'SLOT 1',
                                    style: TextStyle(
                                      fontSize: 7,
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const ClampingScrollPhysics(),
                            child: Container(
                              width: max(
                                effectiveHourWidth * 24,
                                timelineWidth - 32,
                              ),
                              height: timelineHeight,
                              color: Colors.transparent,
                              child: CustomPaint(
                                size: pictureSize,
                                painter: _TimelinePainter(
                                  hourWidth: effectiveHourWidth,
                                  contentStartX: contentStartX,
                                  colorScheme: colorScheme,
                                  primaryGreen: primaryGreen,
                                  renderData: renderData,
                                  cachedPicture: _cachedTimelinePicture,
                                  cachedSize: pictureSize,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        color: primaryGreen,
                        onPressed: widget.onPrevDay,
                        tooltip: "Prejšnji dan",
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.zoom_out, size: 18, color: colorScheme.onSurfaceVariant),
                            Expanded(
                              child: Slider(
                                value: effectiveHourWidth,
                                min: fitWidth,
                                max: 500.0,
                                activeColor: primaryGreen,
                                onChanged: (value) {
                                  setState(() {
                                    _isManualZoom = true;
                                    _hourWidth = value;
                                  });
                                },
                              ),
                            ),
                            Icon(Icons.zoom_in, size: 18, color: colorScheme.onSurfaceVariant),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        color: primaryGreen,
                        onPressed: widget.onNextDay,
                        tooltip: "Naslednji dan",
                      ),
                    ],
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
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
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
                    _showSummaryExportOptions(
                      days,
                      "Period Report",
                      rangeStr,
                      primaryGreen,
                    );
                  },
                  trailing: InkWell(
                    onTap: () => _selectDateRange(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: primaryGreen.withValues(alpha: 0.2),
                        ),
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
                  child: Text(
                    "Activity Statistics",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
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
                    final rangeStr =
                        "${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}";
                    _showSummaryExportOptions(
                      days,
                      "Monthly Report",
                      rangeStr,
                      primaryGreen,
                    );
                  },
                  trailing: InkWell(
                    onTap: () => _selectMonth(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: primaryGreen.withValues(alpha: 0.2),
                        ),
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
      },
    );
  }

  Widget _buildSummaryHeader(
    String title,
    String subtitle,
    Color primaryGreen, {
    Widget? trailing,
    VoidCallback? onExport,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (onExport != null)
            IconButton(
              icon: Icon(Icons.picture_as_pdf, color: primaryGreen),
              onPressed: onExport,
            ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
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
              Expanded(
                child: _summaryCard(
                  const TahoDrivePainter(color: Colors.blue),
                  "DRIVING",
                  summary.driving,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _summaryCard(
                  const TahoWorkPainter(color: Colors.orange),
                  "WORK",
                  summary.work,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _summaryCard(
                  const TahoAvailabilityPainter(color: Colors.grey),
                  "AVAILABILITY",
                  summary.availability,
                  Colors.grey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _summaryCard(
                  TahoRestPainter(color: primaryGreen),
                  "REST",
                  summary.rest,
                  primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _summaryCard(
            const Icon(Icons.speed, color: Colors.teal, size: 20),
            "TOTAL DISTANCE",
            0,
            Colors.teal,
            valueOverride: "${summary.totalKm} km",
          ),
        ],
      ),
    );
  }

  ActivitySummary _calculateSummary(List<DailyActivities> filteredDays) {
    final summary = ActivitySummary();
    if (filteredDays.isEmpty) return summary;

    // 1. Calculate total KM from the filtered days
    for (var day in filteredDays) {
      summary.totalKm += day.header.km;
    }

    // 2. Flatten all activities from all days for context
    List<({DateTime time, ActivityRecord rec})> allFlat = [];
    for (var day in widget.activities) {
      for (var act in day.activities) {
        final absTime = day.header.time.add(Duration(minutes: act.time));
        allFlat.add((time: absTime, rec: act));
      }
    }

    if (allFlat.isEmpty) return summary;

    // Sort by absolute time
    allFlat.sort((a, b) {
      int cmp = a.time.compareTo(b.time);
      if (cmp != 0) return cmp;
      if (a.rec.card != b.rec.card) return a.rec.card.compareTo(b.rec.card);
      if (a.rec.crew != b.rec.crew) return a.rec.crew.compareTo(b.rec.crew);
      return b.rec.slot.compareTo(a.rec.slot);
    });

    // 3. Define the period boundaries in Local Time
    var sortedFiltered = List<DailyActivities>.from(filteredDays);
    sortedFiltered.sort((a, b) => a.header.time.compareTo(b.header.time));

    final DateTime periodStart = sortedFiltered.first.header.time.subtract(
      Duration(hours: widget.utcOffset),
    );
    final DateTime periodEnd = sortedFiltered.last.header.time
        .subtract(Duration(hours: widget.utcOffset))
        .add(const Duration(days: 1));

    // 4. Create the timeline for the period
    ActivityRecord? activeRec;
    int startIndex = allFlat.lastIndexWhere(
      (e) => !e.time.isAfter(periodStart),
    );
    if (startIndex != -1) {
      activeRec = allFlat[startIndex].rec;
    }

    List<({DateTime time, ActivityRecord? rec})> timeline = [];
    timeline.add((time: periodStart, rec: activeRec));

    for (var entry in allFlat) {
      if (entry.time.isAfter(periodStart) && entry.time.isBefore(periodEnd)) {
        timeline.add((time: entry.time, rec: entry.rec));
      }
    }

    timeline.add((time: periodEnd, rec: null));

    // 5. Process the timeline
    int accumulatedDriving = 0;
    bool hasFirstBreakPart = false;

    for (int i = 0; i < timeline.length - 1; i++) {
      final curr = timeline[i];
      final next = timeline[i + 1];
      final rec = curr.rec;

      if (rec == null) continue;

      // Only count activities recorded under card == 1 in Period/Monthly summaries.
      // Activities with card == 0 and crew == 1 will be added later.
      if (rec.card != 1) continue;

      final duration = next.time.difference(curr.time).inMinutes;
      if (duration <= 0) continue;

      switch (rec.activity) {
        case 0: // Rest
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
        case 1: // Availability
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
        case 2: // Work
          summary.work += duration;
          break;
        case 3: // Driving
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
    }

    return summary;
  }

  ActivitySummary _calculateMonthlySummary() {
    final targetMonth = _selectedMonth.month;
    final targetYear = _selectedMonth.year;

    final filteredDays = widget.activities
        .where(
          (day) => day.date.year == targetYear && day.date.month == targetMonth,
        )
        .toList();

    return _calculateSummary(filteredDays);
  }

  List<DailyActivities> _getFilteredRangeDays() {
    if (_startDate == null || _endDate == null) return [];
    final startTs =
        DateTime.utc(
          _startDate!.year,
          _startDate!.month,
          _startDate!.day,
        ).millisecondsSinceEpoch ~/
        1000;
    final endTs =
        DateTime.utc(
          _endDate!.year,
          _endDate!.month,
          _endDate!.day,
        ).millisecondsSinceEpoch ~/
        1000;
    final Set<int> eligibleDays = {};
    for (int ts = startTs; ts <= endTs; ts += 86400) {
      eligibleDays.add(ts);
    }
    return widget.activities.where((day) {
      final dt = day.date.toUtc();
      final ts =
          DateTime.utc(dt.year, dt.month, dt.day).millisecondsSinceEpoch ~/
          1000;
      return eligibleDays.contains(ts);
    }).toList();
  }

  List<DailyActivities> _getFilteredMonthlyDays() {
    return widget.activities
        .where(
          (day) =>
              day.date.year == _selectedMonth.year &&
              day.date.month == _selectedMonth.month,
        )
        .toList();
  }

  ActivitySummary _calculateRangeSummary() {
    return _calculateSummary(_getFilteredRangeDays());
  }

  Widget _buildVisualBreakdown(Color primaryGreen, ActivitySummary summary) {
    final total =
        summary.driving + summary.work + summary.availability + summary.rest;
    if (total == 0) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Container(
            height: 40,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                if (summary.driving > 0)
                  Expanded(
                    flex: summary.driving,
                    child: Container(color: Colors.blue),
                  ),
                if (summary.work > 0)
                  Expanded(
                    flex: summary.work,
                    child: Container(color: Colors.orange),
                  ),
                if (summary.availability > 0)
                  Expanded(
                    flex: summary.availability,
                    child: Container(color: Colors.grey),
                  ),
                if (summary.rest > 0)
                  Expanded(
                    flex: summary.rest,
                    child: Container(color: primaryGreen),
                  ),
              ],
            ),
          ),
          if (summary.overdrive > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  "Overdrive: ${summary.overdrive ~/ 60}h ${summary.overdrive % 60}m",
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: widget.activities.isEmpty
          ? DateTime(2000)
          : widget.activities.last.date,
      lastDate: widget.activities.isEmpty
          ? DateTime.now()
          : widget.activities.first.date,
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

    final sortedKeys = availableMonths.keys.toList()
      ..sort((a, b) => b.compareTo(a));

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
              final isSelected =
                  key ==
                  "${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}";
              return ListTile(
                title: Text(
                  key,
                  style: TextStyle(
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check, color: primaryGreen)
                    : null,
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

  Widget _summaryCard(
    dynamic iconOrPainter,
    String label,
    int minutes,
    Color color, {
    String? valueOverride,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.2 : 0.05,
            ),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (iconOrPainter is CustomPainter)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CustomPaint(painter: iconOrPainter),
                )
              else
                iconOrPainter as Widget,
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            valueOverride ?? "${h}h ${m.toString().padLeft(2, '0')}m",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<Uint8List> _captureTimelineImage(DailyActivities day) async {
    final theme = Theme.of(context);
    final primaryGreen = theme.primaryColor;

    // Force light color scheme for PDF export
    final pdfColorScheme = ColorScheme.fromSeed(
      seedColor: primaryGreen,
      brightness: Brightness.light,
    );

    // Target a high width for PDF clarity (e.g. 2400px for 24h)
    const double targetHourWidth = 100.0;
    const double targetWidth = targetHourWidth * 24.0;
    const double targetHeight = 160.0;

    final renderData = _buildTimelineRenderData(
      day: day,
      primaryGreen: primaryGreen,
      colorScheme: pdfColorScheme,
      hourWidth: targetHourWidth,
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, targetWidth, targetHeight),
    );

    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, targetWidth, targetHeight),
      Paint()..color = Colors.white,
    );

    _paintTimeline(
      canvas: canvas,
      size: Size(targetWidth, targetHeight),
      hourWidth: targetHourWidth,
      contentStartX: 0.0,
      colorScheme: pdfColorScheme,
      primaryGreen: primaryGreen,
      renderData: renderData,
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(targetWidth.toInt(), targetHeight.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  void _showExportOptions(DailyActivities day, Color primaryGreen) async {
    // Capture the timeline image first
    final bytes = await _captureTimelineImage(day);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                  share: true,
                  allActivities: widget.activities,
                  timelineImageBytes: bytes,
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
                  openImmediately: true,
                  allActivities: widget.activities,
                  timelineImageBytes: bytes,
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
                  allActivities: widget.activities,
                  timelineImageBytes: bytes,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDailyExportOptions(DailyActivities day, Color primaryGreen) {
    // This method is now redundant as its logic was merged into _showExportOptions
  }

  void _showSummaryExportOptions(
    List<DailyActivities> days,
    String title,
    String rangeStr,
    Color primaryGreen,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.share, color: primaryGreen),
              title: const Text('Share Summary PDF'),
              onTap: () async {
                Navigator.pop(context);
                final images = <DateTime, Uint8List>{};
                for (var day in days) {
                  final bytes = await _captureTimelineImage(day);
                  images[day.date] = bytes;
                }
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
                  dailyTimelineImages: images,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new, color: Colors.blue),
              title: const Text('Open Summary PDF'),
              onTap: () async {
                Navigator.pop(context);
                final images = <DateTime, Uint8List>{};
                for (var day in days) {
                  final bytes = await _captureTimelineImage(day);
                  images[day.date] = bytes;
                }
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
                  dailyTimelineImages: images,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.save_alt, color: Colors.green),
              title: const Text('Save Summary PDF'),
              onTap: () async {
                Navigator.pop(context);
                final images = <DateTime, Uint8List>{};
                for (var day in days) {
                  final bytes = await _captureTimelineImage(day);
                  images[day.date] = bytes;
                }
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
                  dailyTimelineImages: images,
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

    // 1. Flatten all activities from all days for context
    List<({DateTime time, ActivityRecord rec})> allFlat = [];
    for (var d in widget.activities) {
      for (var act in d.activities) {
        allFlat.add((
          time: d.header.time.add(Duration(minutes: act.time)),
          rec: act,
        ));
      }
    }
    allFlat.sort((a, b) {
      int cmp = a.time.compareTo(b.time);
      if (cmp != 0) return cmp;
      if (a.rec.card != b.rec.card) return a.rec.card.compareTo(b.rec.card);
      if (a.rec.crew != b.rec.crew) return a.rec.crew.compareTo(b.rec.crew);
      return b.rec.slot.compareTo(a.rec.slot);
    });

    // 2. Define the window boundaries in UTC based on the local offset
    final DateTime windowStart = day.header.time.subtract(
      Duration(hours: widget.utcOffset),
    );
    final DateTime windowEnd = windowStart.add(const Duration(days: 1));

    // 3. Find the active record at the very start of this local day
    ActivityRecord? lastRec;
    int startIdx = allFlat.lastIndexWhere((e) => !e.time.isAfter(windowStart));
    if (startIdx != -1) {
      lastRec = allFlat[startIdx].rec;
    }

    DateTime currentDayPtr = windowStart;

    void addLogItem(ActivityRecord rec, DateTime start, DateTime end) {
      final durationMinutes = end.difference(start).inMinutes;
      if (durationMinutes <= 0) return;

      // Skip gaps (no card and no crew manual entry)
      if (rec.card == 0 && rec.crew == 0) return;

      // Minutes from start of the local day for the _activityLogItem helper
      final startOffset = start.difference(windowStart).inMinutes;
      final endOffset = end.difference(windowStart).inMinutes;

      items.add(
        _activityLogItem(
          rec.activity,
          startOffset,
          endOffset,
          durationMinutes,
          primaryGreen,
          rec.slot,
          rec.crew == 1,
        ),
      );
    }

    // 4. Iterate through activities within the local window
    for (var entry in allFlat) {
      if (entry.time.isAfter(windowEnd)) break;
      if (entry.time.isAfter(windowStart)) {
        if (lastRec != null) {
          addLogItem(lastRec, currentDayPtr, entry.time);
        }
        currentDayPtr = entry.time;
        lastRec = entry.rec;
      }
    }

    // 5. Final segment to end of local day
    if (lastRec != null && currentDayPtr.isBefore(windowEnd)) {
      addLogItem(lastRec, currentDayPtr, windowEnd);
    }

    return items;
  }

  Widget _activityLogItem(
    int type,
    int start,
    int end,
    int duration,
    Color primaryGreen,
    int slot,
    bool isCrew,
  ) {
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
      int h = (totalMinutes ~/ 60);
      int m = totalMinutes % 60;
      return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";
    }

    final startStr = formatTime(start);
    final endStr = formatTime(end);
    final durStr =
        "${(duration ~/ 60).toString().padLeft(2, '0')}:${(duration % 60).toString().padLeft(2, '0')}";

    String displayLabel = label;
    if (isCrew) displayLabel += " (Crew)";
    displayLabel += slot == 1 ? " (Slot 2)" : " (Slot 1)";

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: 24, height: 24, child: CustomPaint(painter: painter)),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayLabel,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                "$startStr - $endStr",
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
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
          _legendItem(
            const TahoDrivePainter(color: Colors.blue),
            "Drive",
            summary.driving,
          ),
          _legendItem(
            const TahoWorkPainter(color: Colors.orange),
            "Work",
            summary.work,
          ),
          _legendItem(
            const TahoAvailabilityPainter(color: Colors.grey),
            "Availability",
            summary.availability,
          ),
          _legendItem(
            TahoRestPainter(color: primaryGreen),
            "Rest",
            summary.rest,
          ),
          if (summary.overdrive > 0)
            _legendItem(
              const Icon(Icons.warning, color: Colors.red, size: 18),
              "Overdrive",
              summary.overdrive,
            ),
          _legendItem(const TahoCrewPainter(color: Colors.indigo), "Crew", -1),
        ],
      ),
    );
  }

  Widget _legendItem(dynamic iconOrPainter, String label, int minutes) {
    final colorScheme = Theme.of(context).colorScheme;
    final timeStr = minutes >= 0
        ? " ${minutes ~/ 60}h ${(minutes % 60).toString().padLeft(2, '0')}m"
        : "";

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (iconOrPainter is CustomPainter)
          CustomPaint(size: const Size(18, 18), painter: iconOrPainter)
        else
          iconOrPainter as Widget,
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (timeStr.isNotEmpty)
              Text(
                timeStr,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
          ],
        ),
      ],
    );
  }

  _TimelineRenderData _buildTimelineRenderData({
    required DailyActivities day,
    required Color primaryGreen,
    required ColorScheme colorScheme,
    required double hourWidth,
  }) {
    final summary = ActivitySummary();
    final blocks = <_TimelineBlock>[];
    final crewLines = <_TimelineBlock>[];
    final placeMarkers = <_TimelinePlaceMarker>[];
    final eventMarkers = <_TimelineEventMarker>[];
    final minuteMarkers = <_TimelineMinuteMarker>[];

    List<({DateTime time, ActivityRecord rec})> allFlat = [];
    for (var d in widget.activities) {
      for (var act in d.activities) {
        allFlat.add((
          time: d.header.time.add(Duration(minutes: act.time)),
          rec: act,
        ));
      }
    }
    allFlat.sort((a, b) {
      int cmp = a.time.compareTo(b.time);
      if (cmp != 0) return cmp;
      if (a.rec.card != b.rec.card) return a.rec.card.compareTo(b.rec.card);
      if (a.rec.crew != b.rec.crew) return a.rec.crew.compareTo(b.rec.crew);
      return b.rec.slot.compareTo(a.rec.slot);
    });

    final DateTime windowStart = day.header.time.subtract(
      Duration(hours: widget.utcOffset),
    );
    final DateTime windowEnd = windowStart.add(const Duration(days: 1));

    ActivityRecord? lastRec;
    int startIdx = allFlat.lastIndexWhere((e) => !e.time.isAfter(windowStart));
    if (startIdx != -1) {
      lastRec = allFlat[startIdx].rec;
    }

    int accumulatedDriving = 0;
    bool hasFirstBreakPart = false;
    double currentHour = 0.0;

    void processSegment(ActivityRecord rec, double startH, double endH) {
      if (endH <= startH) return;

      if (rec.card == 0 && rec.crew == 0) {
        accumulatedDriving = 0;
        hasFirstBreakPart = false;
        return;
      }

      final durationMinutes = ((endH - startH) * 60).round();
      if (durationMinutes <= 0) return;

      double blockHeight;
      switch (rec.activity) {
        case 3: // Driving
          blockHeight = 48.0;
          break;
        case 1: // Availability
          blockHeight = 38.4;
          break;
        case 2: // Work
          blockHeight = 30.72;
          break;
        case 0: // Rest
          blockHeight = 19.2;
          break;
        default:
          blockHeight = 32.0;
      }

      const double separatorY = 79.5;
      final double blockTop = rec.slot == 1 
          ? separatorY - blockHeight // SLOT 2 (zgoraj) raste navzgor
          : separatorY;              // SLOT 1 (spodaj) raste navzdol

      Color color;
      switch (rec.activity) {
        case 0:
          color = primaryGreen;
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
          color = Colors.grey;
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
        case 2:
          color = Colors.orange;
          summary.work += durationMinutes;
          break;
        case 3:
          color = Colors.blue;
          summary.driving += durationMinutes;
          if (!widget.under50km) {
            accumulatedDriving += durationMinutes;
            if (accumulatedDriving > 270) {
              summary.overdrive += (accumulatedDriving - 270);
              final regularDuration =
                  (270 - (accumulatedDriving - durationMinutes)) / 60.0;
              if (regularDuration > 0) {
                blocks.add(
                  _TimelineBlock(
                    left: startH * hourWidth,
                    top: blockTop,
                    width: max(2.0, regularDuration * hourWidth),
                    height: blockHeight,
                    color: Colors.blue,
                    durationMinutes: (regularDuration * 60).round(),
                  ),
                );
              }
              final overdriveDuration = (accumulatedDriving - 270) / 60.0;
              blocks.add(
                _TimelineBlock(
                  left: (startH + max(0, regularDuration)) * hourWidth,
                  top: blockTop,
                  width: max(2.0, overdriveDuration * hourWidth),
                  height: blockHeight,
                  color: Colors.red,
                  durationMinutes: (overdriveDuration * 60).round(),
                ),
              );
              accumulatedDriving = 270;
              color = Colors.transparent;
            } else {
              color = Colors.blue;
            }
          }
          break;
        default:
          color = Colors.grey;
          break;
      }

      if (color != Colors.transparent) {
        blocks.add(
          _TimelineBlock(
            left: startH * hourWidth,
            top: blockTop,
            width: max(2.0, (endH - startH) * hourWidth),
            height: blockHeight,
            color: color,
            durationMinutes: durationMinutes,
          ),
        );
      }

      if (rec.crew == 1) {
        crewLines.add(
          _TimelineBlock(
            left: startH * hourWidth,
            top: separatorY, // Oba se stikata na ločilni črti
            width: max(2.0, (endH - startH) * hourWidth),
            height: 2,
            color: Colors.indigo,
            isCrewLine: true,
          ),
        );
      }
    }

    for (var entry in allFlat) {
      if (entry.time.isAfter(windowEnd)) break;
      if (entry.time.isAfter(windowStart)) {
        final entryHour = entry.time.difference(windowStart).inSeconds / 3600.0;

        if (lastRec != null) {
          processSegment(lastRec, currentHour, entryHour);
        }

        currentHour = entryHour;
        lastRec = entry.rec;
      }
    }

    if (lastRec != null && currentHour < 24.0) {
      processSegment(lastRec, currentHour, 24.0);
    }

    int interval;
    if (hourWidth > 420) {
      interval = 5;
    } else if (hourWidth > 250) {
      interval = 15;
    } else if (hourWidth > 120) {
      interval = 30;
    } else {
      interval = 0;
    }

    if (interval > 0) {
      for (int hour = 0; hour < 24; hour++) {
        for (int m = interval; m < 60; m += interval) {
          minuteMarkers.add(
            _TimelineMinuteMarker(
              left: hour * hourWidth + (m / 60.0) * hourWidth,
              showLabel: hourWidth > 220 && (m % 5 == 0),
              label: m.toString().padLeft(2, '0'),
            ),
          );
        }
      }
    }

    final List<dynamic> allPlaces = [];
    allPlaces.addAll(widget.places);
    allPlaces.addAll(widget.placesG2);

    for (var place in allPlaces) {
      if (place.entryTime.isAfter(windowStart) &&
          place.entryTime.isBefore(windowEnd)) {
        final hour = place.entryTime.difference(windowStart).inSeconds / 3600.0;
        placeMarkers.add(
          _TimelinePlaceMarker(
            left: hour * hourWidth,
            top: 0,
            country: _getCountryCode(place.dailyWorkPeriodCountry),
            color: place.entryTypeDailyWorkPeriod == 0
                ? Colors.green
                : Colors.orange,
            type: place.entryTypeDailyWorkPeriod,
          ),
        );
      }
    }

    for (var event in widget.driverEvents) {
      if (event.date.isAfter(windowStart) && event.date.isBefore(windowEnd)) {
        final hour = event.date.difference(windowStart).inSeconds / 3600.0;
        eventMarkers.add(
          _TimelineEventMarker(
            left: hour * hourWidth,
            top: 125,
            color: _getEventColor(event.type),
          ),
        );
      }
    }

    return _TimelineRenderData(
      summary: summary,
      blocks: blocks,
      crewLines: crewLines,
      placeMarkers: placeMarkers,
      eventMarkers: eventMarkers,
      minuteMarkers: minuteMarkers,
      separatorY: 79.5,
      slot2LabelY: 45,
      slot1LabelY: 83,
    );
  }

  Color _getEventColor(String type) {
    switch (type.toLowerCase()) {
      case 'operational events':
        return Colors.blue;
      case 'driver observations':
        return Colors.teal;
      case 'compliance events':
        return Colors.red;
      case 'personal events':
        return Colors.green;
      case 'security events':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getCountryCode(int code) {
    final String name;
    switch (code) {
      case 1:
        name = "A";
        break;
      case 2:
        name = "AL";
        break;
      case 3:
        name = "AND";
        break;
      case 4:
        name = "ARM";
        break;
      case 5:
        name = "AZ";
        break;
      case 6:
        name = "B";
        break;
      case 7:
        name = "BG";
        break;
      case 8:
        name = "BIH";
        break;
      case 9:
        name = "BY";
        break;
      case 10:
        name = "CH";
        break;
      case 11:
        name = "CY";
        break;
      case 12:
        name = "CZ";
        break;
      case 13:
        name = "D";
        break;
      case 14:
        name = "DK";
        break;
      case 15:
        name = "E";
        break;
      case 16:
        name = "EST";
        break;
      case 17:
        name = "F";
        break;
      case 18:
        name = "FIN";
        break;
      case 19:
        name = "FL";
        break;
      case 20:
        name = "FR, FO";
        break;
      case 21:
        name = "UK";
        break;
      case 22:
        name = "GE";
        break;
      case 23:
        name = "GR";
        break;
      case 24:
        name = "H";
        break;
      case 25:
        name = "HR";
        break;
      case 26:
        name = "I";
        break;
      case 27:
        name = "IRL";
        break;
      case 28:
        name = "IS";
        break;
      case 29:
        name = "KZ";
        break;
      case 30:
        name = "L";
        break;
      case 31:
        name = "LT";
        break;
      case 32:
        name = "LV";
        break;
      case 33:
        name = "M";
        break;
      case 34:
        name = "MC";
        break;
      case 35:
        name = "MD";
        break;
      case 36:
        name = "MK";
        break;
      case 37:
        name = "N";
        break;
      case 38:
        name = "NL";
        break;
      case 39:
        name = "P";
        break;
      case 40:
        name = "PL";
        break;
      case 41:
        name = "RO";
        break;
      case 42:
        name = "RSM";
        break;
      case 43:
        name = "RUS";
        break;
      case 44:
        name = "S";
        break;
      case 45:
        name = "SK";
        break;
      case 46:
        name = "SLO";
        break;
      case 47:
        name = "TM";
        break;
      case 48:
        name = "TR";
        break;
      case 49:
        name = "UA";
        break;
      case 50:
        name = "V";
        break;
      case 51:
        name = "YU";
        break;
      case 52:
        name = "MNE";
        break;
      case 53:
        name = "SRB";
        break;
      case 54:
        name = "UZ";
        break;
      case 253:
        name = "EC";
        break;
      case 254:
        name = "EUR";
        break;
      case 255:
        name = "WLD";
        break; // apparently UNK has same value as WLD
      default:
        return "Unknown ($code)";
    }
    return "$name";
  }
}
