import 'package:flutter/material.dart';
import 'taho_models.dart';
import 'dart:math';

class ActivityTimeline extends StatefulWidget {
  final List<DailyActivities> activities;
  final VoidCallback? onDateTap;
  final int utcOffset;
  final ValueChanged<int> onUtcOffsetChanged;

  const ActivityTimeline({
    super.key,
    required this.activities,
    this.onDateTap,
    required this.utcOffset,
    required this.onUtcOffsetChanged,
  });

  @override
  State<ActivityTimeline> createState() => _ActivityTimelineState();
}

class _ActivityTimelineState extends State<ActivityTimeline> {
  double _hourWidth = 120.0;

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF28B52F);
    final double totalWidth = _hourWidth * 24;

    if (widget.activities.isEmpty) {
      return const Center(
          child: Text("No activity data found.\nUpload a file or read a card.",
              textAlign: TextAlign.center));
    }

    final day = widget.activities.first;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    color: Colors.grey.withOpacity(0.1),
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
                width: totalWidth + 45,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Stack(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(24, (h) => Container(
                        width: _hourWidth,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(color: Colors.grey.withOpacity(0.3), width: 1),
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
                                  "${h.toString().padLeft(2, '0')}:00",
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
                        children: _buildRecursiveTimeline(day, primaryGreen),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(),
          _buildLegend(primaryGreen),
        ],
      ),
    );
  }

  Widget _buildLegend(Color primaryGreen) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Wrap(
        spacing: 20,
        runSpacing: 10,
        children: [
          _legendItem(const TahoDrivePainter(color: Colors.blue), "Drive"),
          _legendItem(const TahoWorkPainter(color: Colors.orange), "Work"),
          _legendItem(const TahoAvailabilityPainter(color: Colors.grey), "Availability"),
          _legendItem(TahoRestPainter(color: primaryGreen), "Rest"),
        ],
      ),
    );
  }

  Widget _legendItem(CustomPainter painter, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(18, 18),
          painter: painter,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  // Natančen prevod C++ metode DrawOneDay(BYTE* ptr, int counter, ActivityData& pData)
  List<Widget> _buildRecursiveTimeline(DailyActivities day, Color primaryGreen) {
    List<Widget> widgets = [];
    if (day.activities.isEmpty) return widgets;

    void drawOneDay(int startIndex, int counter) {
      if (counter <= 0) return;

      int ptr = startIndex;
      int internalCounter = counter;

      // --- HEADER ---
      final firstAct = day.activities[ptr];
      int activityType = firstAct.activity;
      double activityTime = (firstAct.time + widget.utcOffset * 60) / 60.0;
      double prevTime = activityTime;

      // MoveToEx / LineTo (Začetna črta seje)
      widgets.add(_buildSessionLine(activityTime));

      ptr++;
      internalCounter -= 2;

      // --- WHILE (counter > 0) ---
      while (internalCounter > 0 && ptr < day.activities.length) {
        final currentAct = day.activities[ptr];
        activityTime = (currentAct.time + widget.utcOffset * 60) / 60.0;
        double duration = activityTime - prevTime;

        // switch (activityType) { ... FillRect ... }
        if (duration > 0) {
          Color color;
          switch (activityType) {
            case 0: color = primaryGreen; break;   // REST (0x1FFF1F v C++)
            case 1: color = Colors.grey; break;     // ADMIN/AVAIL (0x6B6B6B)
            case 2: color = Colors.orange; break;   // WORK (0xFF9D00)
            case 3: color = Colors.blue; break;     // DRIVING (0x00A5FF)
            default: color = Colors.grey; break;
          }
          widgets.add(_buildActivityBlock(prevTime, duration, color));
        }

        // activityType = (activity >> 11) & 0b11; (Update za naslednji interval)
        activityType = currentAct.activity;
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
      widgets.add(_buildSessionLine(activityTime));
    }

    // Pokličemo s številom bajtov (2 bajta na zapis)
    drawOneDay(0, day.activities.length * 2);
    return widgets;
  }

  Widget _buildActivityBlock(double startHour, double durationHours, Color color) {
    final double blockWidth = max(2.0, durationHours * _hourWidth);

    return Positioned(
      left: startHour * _hourWidth,
      width: blockWidth,
      top: 10,
      bottom: 10,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.8),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.black12, width: 0.5),
        ),
      ),
    );
  }

  // Pomožna funkcija za risanje navpične črte ob vstavljanju/izvleku kartice (kot LineTo v C++)
  Widget _buildSessionLine(double hour) {
    return Positioned(
      left: hour * _hourWidth - 1,
      top: 0,
      bottom: 0,
      child: Container(
        width: 2,
        color: Colors.black87,
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
            color: Colors.grey.withOpacity(0.15),
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
                color: Colors.grey.withOpacity(0.5),
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