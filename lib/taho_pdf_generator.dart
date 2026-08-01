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
  }) async {
    final doc = pw.Document();
    final pdfPrimaryGreen = PdfColor.fromInt(primaryColor.toARGB32());

    final summary = ActivitySummary();
    for (var day in days) {
      final s = calculateDaySummary(day, utcOffset, under50km, days, onlyCard: true);
      summary.rest += s.rest;
      summary.availability += s.availability;
      summary.work += s.work;
      summary.driving += s.driving;
      summary.totalKm += s.totalKm;
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
            _buildHeader(title, "Period: $rangeStr", "", pdfPrimaryGreen),
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
                width: 130,
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
                    _pdfSummaryRow(
                      "Distance:",
                      "${summary.totalKm} km",
                      PdfColors.teal,
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
              final s = calculateDaySummary(day, utcOffset, under50km, days);
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
    required List<PlaceRecord> places,
    required List<PlaceRecordG2> placesG2,
    required bool isGen2View,
    required int utcOffset,
    bool under50km = false,
    bool openImmediately = false,
    bool share = false,
    required List<DailyActivities> allActivities,
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

    final pdfSummary = calculateDaySummary(day, utcOffset, under50km, allActivities);

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
            _buildVerticalPdfTimeline(day, pdfPrimaryGreen, utcOffset, allActivities),
            if (dayEvents.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              _buildEventsSection(dayEvents, pdfPrimaryGreen),
            ],
          ];
        },
      ),
    );

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
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
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
    List<DailyActivities> allActivities,
  ) {
    List<pw.Widget> rows = [];

    // 1. Flatten all activities from all days for context
    List<({DateTime time, ActivityRecord rec})> allFlat = [];
    for (var d in allActivities) {
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
    final DateTime windowStart = day.header.time.subtract(Duration(hours: utcOffset));
    final DateTime windowEnd = windowStart.add(const Duration(days: 1));

    // 3. Find the active record at the very start of this day
    ActivityRecord? lastRec;
    int startIdx = allFlat.lastIndexWhere((e) => !e.time.isAfter(windowStart));
    if (startIdx != -1) {
      lastRec = allFlat[startIdx].rec;
    }

    DateTime currentDayPtr = windowStart;

    void addRow(ActivityRecord rec, DateTime start, DateTime end) {
      final duration = end.difference(start).inMinutes;
      if (duration <= 0) return;

      // Skip gaps (no card and no crew manual entry)
      if (rec.card == 0 && rec.crew == 0) return;

      final startOffset = start.difference(windowStart).inMinutes;
      final endOffset = end.difference(windowStart).inMinutes;

      String label = _getActivityName(rec.activity);
      if (rec.crew == 1) label += " (Crew)";
      label += rec.slot == 1 ? " (Slot 2)" : " (Slot 1)";

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
                      formatPdfTime(startOffset),
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      formatPdfTime(endOffset),
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
                    rec.activity,
                    _getActivityPdfColor(rec.activity, primary),
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
                      label,
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
                          rec.activity,
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

    // 4. Iterate through activities within the local window
    for (var entry in allFlat) {
      if (entry.time.isAfter(windowEnd)) break;
      if (entry.time.isAfter(windowStart)) {
        if (lastRec != null) {
          addRow(lastRec, currentDayPtr, entry.time);
        }
        currentDayPtr = entry.time;
        lastRec = entry.rec;
      }
    }

    // 5. Final segment to end of local day
    if (lastRec != null && currentDayPtr.isBefore(windowEnd)) {
      addRow(lastRec, currentDayPtr, windowEnd);
    }

    if (rows.isEmpty) return pw.Text("No activities recorded");
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

  static String _getCountryCode(int code) {
    switch (code) {
      case 1: return "A";
      case 2: return "AL";
      case 3: return "AND";
      case 4: return "ARM";
      case 5: return "AZ";
      case 6: return "B";
      case 7: return "BG";
      case 8: return "BIH";
      case 9: return "BY";
      case 10: return "CH";
      case 11: return "CY";
      case 12: return "CZ";
      case 13: return "D";
      case 14: return "DK";
      case 15: return "E";
      case 16: return "EST";
      case 17: return "F";
      case 18: return "FIN";
      case 19: return "FL";
      case 20: return "FR";
      case 21: return "UK";
      case 22: return "GE";
      case 23: return "GR";
      case 24: return "H";
      case 25: return "HR";
      case 26: return "I";
      case 27: return "IRL";
      case 28: return "IS";
      case 29: return "KZ";
      case 30: return "L";
      case 31: return "LT";
      case 32: return "LV";
      case 33: return "M";
      case 34: return "MC";
      case 35: return "MD";
      case 36: return "MK";
      case 37: return "N";
      case 38: return "NL";
      case 39: return "P";
      case 40: return "PL";
      case 41: return "RO";
      case 42: return "RSM";
      case 43: return "RUS";
      case 44: return "S";
      case 45: return "SK";
      case 46: return "SLO";
      case 47: return "TM";
      case 48: return "TR";
      case 49: return "UA";
      case 50: return "V";
      case 51: return "YU";
      case 52: return "MNE";
      case 53: return "SRB";
      case 54: return "UZ";
      case 253: return "EC";
      case 254: return "EUR";
      default: return "??";
    }
  }

  static String formatPdfTime(int minutes) {
    int h = (minutes ~/ 60);
    int m = minutes % 60;
    return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";
  }

  static ActivitySummary calculateDaySummary(
    DailyActivities day,
    int utcOffset,
    bool under50km,
    List<DailyActivities> allActivities, {
    bool onlyCard = false,
  }) {
    final summary = ActivitySummary();
    summary.totalKm = day.header.km;

    // 1. Flatten all activities for context
    List<({DateTime time, ActivityRecord rec})> allFlat = [];
    for (var d in allActivities) {
      for (var act in d.activities) {
        allFlat.add((
          time: d.header.time.add(Duration(minutes: act.time)),
          rec: act
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
    final DateTime windowStart = day.header.time.subtract(Duration(hours: utcOffset));
    final DateTime windowEnd = windowStart.add(const Duration(days: 1));

    // 3. Find starting record
    ActivityRecord? lastRec;
    int startIdx = allFlat.lastIndexWhere((e) => !e.time.isAfter(windowStart));
    if (startIdx != -1) {
      lastRec = allFlat[startIdx].rec;
    }

    DateTime currentDayPtr = windowStart;

    void process(ActivityRecord rec, DateTime start, DateTime end) {
      final duration = end.difference(start).inMinutes;
      if (duration <= 0) return;

      // Skip gaps: for Period/Monthly we count only card == 1.
      // For Daily we count card == 1 OR crew == 1.
      if (onlyCard) {
        if (rec.card != 1) return;
      } else {
        if (rec.card == 0 && rec.crew == 0) return;
      }

      switch (rec.activity) {
        case 0: summary.rest += duration; break;
        case 1: summary.availability += duration; break;
        case 2: summary.work += duration; break;
        case 3: summary.driving += duration; break;
      }
    }

    // 4. Iterate through activities within the local window
    for (var entry in allFlat) {
      if (entry.time.isAfter(windowEnd)) break;
      if (entry.time.isAfter(windowStart)) {
        if (lastRec != null) {
          process(lastRec, currentDayPtr, entry.time);
        }
        currentDayPtr = entry.time;
        lastRec = entry.rec;
      }
    }

    // 5. Final segment to end of local day
    if (lastRec != null && currentDayPtr.isBefore(windowEnd)) {
      process(lastRec, currentDayPtr, windowEnd);
    }

    return summary;
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
