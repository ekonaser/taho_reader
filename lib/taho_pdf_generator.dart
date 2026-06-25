import 'dart:math';
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
      const int timelineMinutes = 27 * 60;
      const double minuteHeight = 8.0;
      const double timelineLabelPadding = 20;
      final double timelineHeight = timelineMinutes * minuteHeight;
      final pageFormat = PdfPageFormat(
        PdfPageFormat.a4.width,
        timelineHeight + 180,
      );

      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(40),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
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
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: pdfPrimaryGreen,
                          ),
                        ),
                        pw.Text(
                          "Driver: ${cardId?.name ?? 'Unknown'} ${cardId?.surname ?? ''} | Date: $dateStr | UTC ${utcOffset >= 0 ? '+' : ''}$utcOffset",
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                    pw.Text(
                      "27h timeline",
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 30),
                pw.Container(
                  width: double.infinity,
                  height: timelineHeight + timelineLabelPadding * 2,
                  child: pw.Stack(
                    children: [
                      pw.Positioned.fill(
                        child: pw.CustomPaint(
                          painter: (canvas, size) {
                            const double trackLeft = 100;
                            final double topPadding = timelineLabelPadding;
                            final double axisTop = topPadding;
                            final double axisBottom =
                                topPadding + timelineHeight;
                            const double slotLabelLeft = 110.0;
                            const double slotLabelSpacing = 24.0;
                            const double slotBlockWidth = 44.0;
                            final double slot1X = slotLabelLeft;
                            final double slot2X =
                                slotLabelLeft +
                                slotBlockWidth +
                                slotLabelSpacing;

                            void drawBlock(
                              double x,
                              double y,
                              double w,
                              double h,
                              PdfColor fill,
                            ) {
                              canvas.setFillColor(fill);
                              const double radius = 4.0;
                              try {
                                canvas.drawRRect(x, y, w, h, radius, radius);
                                canvas.fillPath();
                                canvas.setLineWidth(0.5);
                                canvas.setStrokeColor(PdfColors.black);
                                canvas.drawRRect(x, y, w, h, radius, radius);
                                canvas.strokePath();
                              } catch (_) {
                                canvas.drawRect(x, y, w, h);
                                canvas.fillPath();
                              }
                            }

                            canvas.setLineWidth(0.5);
                            canvas.setStrokeColor(PdfColors.grey700);
                            canvas.moveTo(trackLeft, axisTop);
                            canvas.lineTo(trackLeft, axisBottom);
                            canvas.strokePath();

                            final activities = day.activities;
                            int accumulatedDriving = 0;
                            bool hasFirstBreakPart = false;

                            if (activities.length == 1) {
                              final prev = activities.first;
                              if (prev.card != 0) {
                                int rawStart = prev.time;
                                int rawEnd = rawStart + 1440;
                                final int localStart =
                                    rawStart + utcOffset * 60;
                                final int localEnd = rawEnd + utcOffset * 60;
                                final int clipStart = localStart.clamp(
                                  0,
                                  timelineMinutes,
                                );
                                final int clipEnd = localEnd.clamp(
                                  0,
                                  timelineMinutes,
                                );
                                if (clipEnd > clipStart) {
                                  final double y =
                                      axisBottom - clipEnd * minuteHeight;
                                  final double hRect = max(
                                    2.0,
                                    (clipEnd - clipStart) * minuteHeight,
                                  );
                                  final double x = prev.slot == 1
                                      ? slot2X
                                      : slot1X;
                                  final double w = slotBlockWidth;
                                  final PdfColor fillColor =
                                      _getActivityPdfColor(
                                        prev.activity,
                                        pdfPrimaryGreen,
                                      );
                                  drawBlock(x, y, w, hRect, fillColor);
                                }
                              }
                            }

                            for (int i = 1; i < activities.length; i++) {
                              final prev = activities[i - 1];
                              final curr = activities[i];
                              int rawStart = prev.time;
                              int rawEnd = curr.time;
                              if (rawEnd < rawStart) rawEnd += 1440;

                              if (prev.card == 0) {
                                accumulatedDriving = 0;
                                hasFirstBreakPart = false;
                                continue;
                              }

                              final int durationMinutes = rawEnd - rawStart;
                              if (durationMinutes <= 0) continue;

                              final int localStart = rawStart + utcOffset * 60;
                              final int localEnd = rawEnd + utcOffset * 60;
                              final int clipStart = localStart.clamp(
                                0,
                                timelineMinutes,
                              );
                              final int clipEnd = localEnd.clamp(
                                0,
                                timelineMinutes,
                              );
                              if (clipEnd <= clipStart) continue;

                              final double y =
                                  axisBottom - clipEnd * minuteHeight;
                              final double hRect = max(
                                2.0,
                                (clipEnd - clipStart) * minuteHeight,
                              );
                              final double x = prev.slot == 1 ? slot2X : slot1X;
                              final double w = slotBlockWidth;

                              PdfColor fillColor = _getActivityPdfColor(
                                prev.activity,
                                pdfPrimaryGreen,
                              );
                              if (!under50km) {
                                if (prev.activity == 0 || prev.activity == 1) {
                                  if (durationMinutes >= 45) {
                                    accumulatedDriving = 0;
                                    hasFirstBreakPart = false;
                                  } else if (durationMinutes >= 30 &&
                                      hasFirstBreakPart) {
                                    accumulatedDriving = 0;
                                    hasFirstBreakPart = false;
                                  } else if (durationMinutes >= 15 &&
                                      !hasFirstBreakPart) {
                                    hasFirstBreakPart = true;
                                  }
                                } else if (prev.activity == 3) {
                                  accumulatedDriving += durationMinutes;
                                  if (accumulatedDriving > 270) {
                                    final int overMinutes =
                                        accumulatedDriving - 270;
                                    final int regularMinutes =
                                        durationMinutes - overMinutes;
                                    final double regularHeight =
                                        regularMinutes * minuteHeight;
                                    final double drawnBlueHeight =
                                        regularMinutes > 0
                                        ? max(2.0, regularHeight)
                                        : 0.0;
                                    if (regularMinutes > 0) {
                                      drawBlock(
                                        x,
                                        y,
                                        w,
                                        drawnBlueHeight,
                                        PdfColors.blue,
                                      );
                                    }
                                    final double overHeight = max(
                                      2.0,
                                      overMinutes * minuteHeight,
                                    );
                                    final double overY = y + drawnBlueHeight;
                                    drawBlock(
                                      x,
                                      overY,
                                      w,
                                      overHeight,
                                      PdfColors.red,
                                    );
                                    accumulatedDriving = 270;
                                    continue;
                                  }
                                }
                              }

                              if (durationMinutes > 0) {
                                drawBlock(x, y, w, hRect, fillColor);
                              }
                            }

                            for (
                              int totalM = 0;
                              totalM <= timelineMinutes;
                              totalM++
                            ) {
                              final double y =
                                  axisBottom - totalM * minuteHeight;

                              if (totalM % 60 == 0) {
                                canvas.setLineWidth(0.8);
                                canvas.setStrokeColor(PdfColors.grey700);
                                canvas.moveTo(trackLeft - 12, y);
                                canvas.lineTo(trackLeft, y);
                              } else if (totalM % 10 == 0) {
                                canvas.setLineWidth(0.5);
                                canvas.setStrokeColor(PdfColors.grey500);
                                canvas.moveTo(trackLeft - 8, y);
                                canvas.lineTo(trackLeft, y);
                              } else if (totalM % 5 == 0) {
                                canvas.setLineWidth(0.2);
                                canvas.setStrokeColor(PdfColors.grey400);
                                canvas.moveTo(trackLeft - 5, y);
                                canvas.lineTo(trackLeft, y);
                              } else {
                                continue;
                              }
                              canvas.strokePath();
                            }
                            canvas.restoreContext();
                          },
                        ),
                      ),
                      pw.Positioned(
                        left: 115,
                        top: timelineLabelPadding - 14,
                        child: pw.Row(
                          children: [
                            pw.Text(
                              'SLOT 1',
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.grey900,
                              ),
                            ),
                            pw.SizedBox(width: 32),
                            pw.Text(
                              'SLOT 2',
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.grey900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...List.generate(28, (index) {
                        final int totalMinutes = index * 60;
                        final int labelHour = index % 24;
                        final double topOffset =
                            timelineLabelPadding +
                            totalMinutes * minuteHeight -
                            6;
                        return pw.Positioned(
                          left: 0,
                          top: topOffset,
                          child: pw.Container(
                            width: 80,
                            alignment: pw.Alignment.centerRight,
                            child: pw.Text(
                              "${labelHour.toString().padLeft(2, '0')}:00",
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
            );
          },
        ),
      );
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
