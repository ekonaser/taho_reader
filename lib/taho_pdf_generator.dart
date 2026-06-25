import 'package:flutter/material.dart' show Color;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'taho_models.dart';
import 'pdf_helper.dart';
import 'event_model.dart';

class TachoPdfGenerator {
  static Future<void> exportSummaryReport({
    required List<DailyActivities> days,
    required String title,
    required String rangeStr,
    required Color primaryColor,
    required CardId? cardId,
    required List<DriverEvent> allEvents,
    required int utcOffset,
    bool under50km = false,
    bool openImmediately = false,
    bool share = false,
    bool includeDetailedTimeline = false,
  }) async {
    final doc = pw.Document();
    final pdfPrimaryGreen = PdfColor.fromInt(primaryColor.toARGB32());
    final utcStr = "UTC ${utcOffset >= 0 ? '+' : ''}$utcOffset";

    final summary = ActivitySummary();
    for (var day in days) {
      final s = calculateDaySummary(day, utcOffset, under50km);
      summary.rest += s.rest;
      summary.availability += s.availability;
      summary.work += s.work;
      summary.driving += s.driving;
    }

    String formatDur(int mins) {
      final h = mins ~/ 60;
      final m = mins % 60;
      return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";
    }

    final eventsInPeriod = allEvents.where((e) {
      return days.any(
        (d) =>
            e.date.year == d.date.year &&
            e.date.month == d.date.month &&
            e.date.day == d.date.day,
      );
    }).toList();
    eventsInPeriod.sort((a, b) => b.date.compareTo(a.date));

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) =>
            _buildHeader(title, "Period: $rangeStr", utcStr, pdfPrimaryGreen),
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "DRIVER DETAILS",
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      "${cardId?.name ?? 'Unknown'} ${cardId?.surname ?? ''}",
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      "Card: ${cardId?.cardNumber ?? 'N/A'}",
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                    pw.Text(
                      "Birthday: ${cardId?.formattedBirthday ?? 'N/A'}",
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(4),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      "GRAND TOTALS",
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    _pdfSummaryRow(
                      "Driving:",
                      formatDur(summary.driving),
                      PdfColors.blue,
                    ),
                    _pdfSummaryRow(
                      "Work:",
                      formatDur(summary.work),
                      PdfColors.orange,
                    ),
                    _pdfSummaryRow(
                      "Availability:",
                      formatDur(summary.availability),
                      PdfColors.grey700,
                    ),
                    _pdfSummaryRow(
                      "Rest:",
                      formatDur(summary.rest),
                      pdfPrimaryGreen,
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            "DAILY BREAKDOWN",
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: pdfPrimaryGreen,
            ),
          ),
          pw.Divider(thickness: 0.5, color: pdfPrimaryGreen),
          pw.SizedBox(height: 5),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headers: ['Date', 'Driving', 'Work', 'Availability', 'Rest'],
            data: days.map((day) {
              final s = calculateDaySummary(day, utcOffset, under50km);
              return [
                day.date.toLocal().toString().split(' ').first,
                formatDur(s.driving),
                formatDur(s.work),
                formatDur(s.availability),
                formatDur(s.rest),
              ];
            }).toList(),
          ),
          if (eventsInPeriod.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _buildEventsSection(eventsInPeriod, pdfPrimaryGreen),
          ],
        ],
      ),
    );

    await _finalizePdf(
      doc,
      "${title.replaceAll(' ', '_')}_$rangeStr",
      share,
      openImmediately,
    );
  }

  static Future<void> exportDailyReport({
    required DailyActivities day,
    required Color primaryColor,
    required CardId? cardId,
    required List<DailyVehicles> vehicles,
    required List<DailyVehiclesG2> vehiclesG2,
    required List<DriverEvent> allEvents,
    required bool isGen2View,
    required int utcOffset,
    bool under50km = false,
    bool openImmediately = false,
    bool share = false,
    bool includeDetailedTimeline = false,
  }) async {
    final doc = pw.Document();
    final pdfPrimaryGreen = PdfColor.fromInt(primaryColor.toARGB32());
    final dateStr = day.date.toLocal().toString().split(' ').first;
    final utcStr = "UTC ${utcOffset >= 0 ? '+' : ''}$utcOffset";

    final dayEvents = allEvents
        .where(
          (e) =>
              e.date.year == day.date.year &&
              e.date.month == day.date.month &&
              e.date.day == day.date.day,
        )
        .toList();
    dayEvents.sort((a, b) => b.date.compareTo(a.date));

    final pdfSummary = calculateDaySummary(day, utcOffset, under50km);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) =>
            _buildHeader("Activity Report", dateStr, utcStr, pdfPrimaryGreen),
        build: (pw.Context context) {
          // Pridobivanje vseh vozil za ta dan
          List<pw.Widget> vehicleWidgets = [];
          try {
            if (isGen2View) {
              final vDay = vehiclesG2.firstWhere(
                (v) =>
                    v.date.year == day.date.year &&
                    v.date.month == day.date.month &&
                    v.date.day == day.date.day,
              );
              for (var v in vDay.vehicles) {
                vehicleWidgets.add(
                  _vehicleInfoRow(
                    v.registrationNumber,
                    v.odometerBegin,
                    v.odometerEnd,
                  ),
                );
              }
            } else {
              final vDay = vehicles.firstWhere(
                (v) =>
                    v.date.year == day.date.year &&
                    v.date.month == day.date.month &&
                    v.date.day == day.date.day,
              );
              for (var v in vDay.vehicles) {
                vehicleWidgets.add(
                  _vehicleInfoRow(v.registration, v.startKm, v.endKm),
                );
              }
            }
          } catch (_) {}

          if (vehicleWidgets.isEmpty) {
            vehicleWidgets.add(
              pw.Text(
                "No vehicle data available",
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
              ),
            );
          }

          return [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "DRIVER DETAILS",
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        "${cardId?.name ?? 'Unknown'} ${cardId?.surname ?? ''}",
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        "Card: ${cardId?.cardNumber ?? 'N/A'}",
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        "Birthday: ${cardId?.formattedBirthday ?? 'N/A'}",
                        style: const pw.TextStyle(fontSize: 10),
                      ),

                      pw.SizedBox(height: 12),

                      pw.Text(
                        "VEHICLE DETAILS",
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      ...vehicleWidgets,
                    ],
                  ),
                ),
                _buildTotalsBox(pdfSummary, pdfPrimaryGreen),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              "ACTIVITY TIMELINE",
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: pdfPrimaryGreen,
              ),
            ),
            pw.Divider(thickness: 1, color: pdfPrimaryGreen),
            pw.SizedBox(height: 10),
            _buildVerticalPdfTimeline(day, pdfPrimaryGreen, utcOffset),
            if (dayEvents.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              _buildEventsSection(dayEvents, pdfPrimaryGreen),
            ],
          ];
        },
      ),
    );

    if (includeDetailedTimeline) {
      final title = "DETAILED ACTIVITY TIMELINE - $dateStr";
      const int detailedTimelinePageCount = 9;
      for (int pageIdx = 0; pageIdx < detailedTimelinePageCount; pageIdx++) {
        final startHour = pageIdx * 3;
        final displayedStartHour = startHour % 24;
        final displayedEndHour = (startHour + 3) % 24;
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(40),
            build: (context) {
              const double detailedTimelineHeight = 650;
              const double timelineLabelPadding = 5;
              return pw.Align(
                alignment: pw.Alignment.topLeft,
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              title,
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                                color: pdfPrimaryGreen,
                              ),
                            ),
                            pw.Text(
                              "Driver: ${cardId?.name ?? 'Unknown'} ${cardId?.surname ?? ''} | Date: $dateStr | UTC ${utcOffset >= 0 ? '+' : ''}$utcOffset",
                              style: const pw.TextStyle(
                                fontSize: 8,
                                color: PdfColors.grey700,
                              ),
                            ),
                          ],
                        ),
                        pw.Text(
                          "Page ${pageIdx + 1} of $detailedTimelinePageCount (${displayedStartHour.toString().padLeft(2, '0')}:00 - ${displayedEndHour.toString().padLeft(2, '0')}:00)",
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 50),
                    pw.SizedBox(
                      height: detailedTimelineHeight + timelineLabelPadding * 2,
                      child: pw.Stack(
                        children: [
                          // Track and Ticks
                          pw.Positioned.fill(
                            child: pw.CustomPaint(
                              painter: (canvas, size) {
                                final double contentHeight =
                                    size.y - timelineLabelPadding * 2;
                                final double hourHeight = contentHeight / 3;
                                final double minuteHeight = hourHeight / 60;
                                const double trackLeft = 80;
                                const double topPadding = timelineLabelPadding;

                                // Vertical Axis Line (strictly 3 hours) - Positioned at the end of labels
                                canvas.setLineWidth(0.5);
                                canvas.setStrokeColor(PdfColors.grey700);
                                canvas.moveTo(trackLeft - 35, topPadding);
                                canvas.lineTo(
                                  trackLeft - 35,
                                  size.y - topPadding,
                                );
                                canvas.strokePath();

                                // Minute Ticks (Top-down alignment)
                                for (int totalM = 0; totalM <= 180; totalM++) {
                                  double y = topPadding + totalM * minuteHeight;

                                  if (totalM % 10 == 0) {
                                    canvas.setLineWidth(0.8);
                                    canvas.setStrokeColor(PdfColors.grey700);
                                    canvas.moveTo(trackLeft - 35, y);
                                    canvas.lineTo(trackLeft - 5, y);
                                  } else if (totalM % 5 == 0) {
                                    canvas.setLineWidth(0.4);
                                    canvas.setStrokeColor(PdfColors.grey500);
                                    canvas.moveTo(trackLeft - 35, y);
                                    canvas.lineTo(trackLeft - 20, y);
                                  } else {
                                    canvas.setLineWidth(0.2);
                                    canvas.setStrokeColor(PdfColors.grey400);
                                    canvas.moveTo(trackLeft - 35, y);
                                    canvas.lineTo(trackLeft - 23, y);
                                  }
                                  canvas.strokePath();
                                }

                                // TODO: Implement activity block rendering here
                              },
                            ),
                          ),

                          // Time Labels
                          ...List.generate(19, (index) {
                            final totalMinutesInPage = index * 10;
                            final totalMinutesInDay =
                                (startHour * 60) + totalMinutesInPage;
                            final totalWithOffset =
                                totalMinutesInDay + utcOffset * 60;

                            int h = (totalWithOffset ~/ 60) % 24;
                            if (h < 0) h += 24;
                            int m = totalWithOffset % 60;
                            if (m < 0) m += 60;

                            final double minuteHeight =
                                detailedTimelineHeight / 3 / 60;
                            final double topOffset =
                                totalMinutesInPage * minuteHeight +
                                timelineLabelPadding;

                            return pw.Positioned(
                              left: -5,
                              top: topOffset - 5,
                              child: pw.Container(
                                width: 45,
                                height: 10,
                                alignment: pw.Alignment.centerRight,
                                child: pw.Text(
                                  "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}",
                                  style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.grey900,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      }
    }

    await _finalizePdf(doc, "ActivityLog_$dateStr", share, openImmediately);
  }

  static pw.Widget _vehicleInfoRow(String reg, int start, int end) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "Registration: $reg",
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            "Odometer: $start - $end: ${end - start} km",
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildHeader(
    String title,
    String date,
    String utc,
    PdfColor color,
  ) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: color,
                  ),
                ),
                pw.Text("Date: $date", style: const pw.TextStyle(fontSize: 14)),
              ],
            ),
            pw.Text(
              utc,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(thickness: 0.5),
        pw.SizedBox(height: 10),
      ],
    );
  }

  static pw.Widget _buildTotalsBox(ActivitySummary summary, PdfColor color) {
    String format(int mins) =>
        "${(mins ~/ 60).toString().padLeft(2, '0')}:${(mins % 60).toString().padLeft(2, '0')}";
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            "DAILY TOTALS",
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 4),
          _pdfSummaryRow("Driving:", format(summary.driving), PdfColors.blue),
          _pdfSummaryRow("Work:", format(summary.work), PdfColors.orange),
          _pdfSummaryRow(
            "Availability:",
            format(summary.availability),
            PdfColors.grey700,
          ),
          _pdfSummaryRow("Rest:", format(summary.rest), color),
        ],
      ),
    );
  }

  static pw.Widget _pdfSummaryRow(String label, String value, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(width: 10),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildVerticalPdfTimeline(
    DailyActivities day,
    PdfColor primary,
    int utcOffset,
  ) {
    List<pw.Widget> rows = [];
    if (day.activities.isEmpty) return pw.Text("No activities recorded");

    int prevTime = day.activities.first.time;
    for (int i = 1; i < day.activities.length; i++) {
      final activity = day.activities[i - 1];
      final nextActivity = day.activities[i];
      int duration = nextActivity.time - prevTime;

      if (duration > 0) {
        rows.add(
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(
              children: [
                pw.SizedBox(
                  width: 60,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        formatPdfTime(prevTime, utcOffset),
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        formatPdfTime(nextActivity.time, utcOffset),
                        style: pw.TextStyle(
                          fontSize: 7,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Column(
                  children: [
                    pw.Container(width: 1, height: 6, color: PdfColors.grey300),
                    _buildPdfIcon(
                      activity.activity,
                      _getActivityPdfColor(activity.activity, primary),
                    ),
                    pw.Container(width: 1, height: 6, color: PdfColors.grey300),
                  ],
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        _getActivityName(activity.activity),
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        "${duration ~/ 60}h ${duration % 60}m",
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: _getActivityPdfColor(
                            activity.activity,
                            primary,
                          ),
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
      prevTime = nextActivity.time;
    }
    return pw.Column(children: rows);
  }

  static pw.Widget _buildEventsSection(
    List<DriverEvent> events,
    PdfColor color,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          "DRIVER EVENTS & OBSERVATIONS",
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
        pw.Divider(thickness: 0.5, color: color),
        pw.SizedBox(height: 5),
        ...events.map(
          (event) => pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey100),
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      event.type.toUpperCase(),
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                        color: _getPdfEventColor(event.type),
                      ),
                    ),
                    pw.Text(
                      event.date.toLocal().toString().split('.')[0],
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  event.description,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static PdfColor _getActivityPdfColor(int type, PdfColor primary) {
    if (type == 3) return PdfColors.blue;
    if (type == 2) return PdfColors.orange;
    if (type == 1) return PdfColors.grey700;
    return primary;
  }

  static String _getActivityName(int type) {
    if (type == 3) return "DRIVING";
    if (type == 2) return "WORK";
    if (type == 1) return "AVAILABILITY";
    return "REST";
  }

  static pw.Widget _buildPdfIcon(int type, PdfColor color) {
    return pw.CustomPaint(
      size: const PdfPoint(10, 10),
      painter: (canvas, size) {
        canvas.setStrokeColor(color);
        canvas.setFillColor(color);
        if (type == 3) {
          // Driving
          canvas.setLineWidth(size.x * 0.125);
          canvas.drawEllipse(
            size.x / 2,
            size.y / 2,
            size.x * 0.4,
            size.y * 0.4,
          );
          canvas.strokePath();
          canvas.drawEllipse(
            size.x / 2,
            size.y / 2,
            size.x * 0.1,
            size.y * 0.1,
          );
          canvas.fillPath();
        } else if (type == 2) {
          // Work (Hammers)
          final w = size.x;
          final h = size.y;
          void drawHammer(bool mirrored) {
            canvas.saveContext();
            // Rotation for 45 degrees
            // pdf coordinate system is bottom-left (0,0)
            const double cosA = 0.7071;
            const double sinA = 0.7071;
            void drawRotatedRect(double rx, double ry, double rw, double rh) {
              final points = [
                [rx, ry],
                [rx + rw, ry],
                [rx + rw, ry + rh],
                [rx, ry + rh],
              ];
              for (int i = 0; i < 4; i++) {
                double x = points[i][0];
                double y = points[i][1];
                double tx = x * cosA - y * sinA;
                double ty = x * sinA + y * cosA;
                if (mirrored) tx = -tx;
                if (i == 0) {
                  canvas.moveTo(w / 2 + tx, h / 2 + ty);
                } else {
                  canvas.lineTo(w / 2 + tx, h / 2 + ty);
                }
              }
              canvas.closePath();
              canvas.fillPath();
            }

            // Put head at the top (positive Y)
            drawRotatedRect(-w * 0.06, -h * 0.5, w * 0.12, h * 0.9);
            drawRotatedRect(-w * 0.3, h * 0.3, w * 0.6, h * 0.2);
            canvas.restoreContext();
          }

          drawHammer(false);
          drawHammer(true);
        } else if (type == 1) {
          // Avail
          canvas.setLineWidth(size.x * 0.15);
          canvas.drawRect(
            size.x * 0.1,
            size.y * 0.1,
            size.x * 0.8,
            size.y * 0.8,
          );
          // Standard slash for availability icon is / (bottom-left to top-right)
          canvas.moveTo(size.x * 0.1, size.y * 0.1);
          canvas.lineTo(size.x * 0.9, size.y * 0.9);
          canvas.strokePath();
        } else {
          // Rest (Bed)
          canvas.setLineWidth(size.x * 0.15);
          // Left post (Headboard)
          canvas.moveTo(size.x * 0.2, size.y * 0.2);
          canvas.lineTo(size.x * 0.2, size.y * 0.8);
          // Mattress
          canvas.moveTo(size.x * 0.2, size.y * 0.5);
          canvas.lineTo(size.x * 0.8, size.y * 0.5);
          // Right leg (Footboard)
          canvas.lineTo(size.x * 0.8, size.y * 0.2);
          canvas.strokePath();
        }
      },
    );
  }

  static PdfColor _getPdfEventColor(String type) {
    if (type.toLowerCase().contains('compliance')) return PdfColors.red;
    if (type.toLowerCase().contains('security')) return PdfColors.orange;
    return PdfColors.blue;
  }

  static String formatPdfTime(int minutes, int utcOffset) {
    int h = ((minutes + utcOffset * 60) ~/ 60) % 24;
    if (h < 0) h += 24;
    int m = (minutes + utcOffset * 60) % 60;
    if (m < 0) m += 60;
    return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";
  }

  static ActivitySummary calculateDaySummary(
    DailyActivities day,
    int utcOffset,
    bool under50km,
  ) {
    final s = ActivitySummary();
    for (int i = 1; i < day.activities.length; i++) {
      int dur = day.activities[i].time - day.activities[i - 1].time;
      if (dur <= 0) continue;
      switch (day.activities[i - 1].activity) {
        case 0:
          s.rest += dur;
          break;
        case 1:
          s.availability += dur;
          break;
        case 2:
          s.work += dur;
          break;
        case 3:
          s.driving += dur;
          break;
      }
    }
    return s;
  }

  static Future<void> _finalizePdf(
    pw.Document doc,
    String name,
    bool share,
    bool open,
  ) async {
    if (share) {
      await SaveAndOpenDocument.sharePdf(name: name, pdf: doc);
    } else {
      final file = open
          ? await SaveAndOpenDocument.savePdfToCache(pdf: doc)
          : await SaveAndOpenDocument.savePdfWithPicker(name: name, pdf: doc);
      if (file != null && open) await SaveAndOpenDocument.openFile(file);
    }
  }
}
