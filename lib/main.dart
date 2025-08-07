import 'dart:async';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Custom Bar Chart Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Custom Bar Chart'),
    );
  }
}

class ChartData {
  final int day;
  final num? value;
  ChartData(this.day, this.value);
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int? _selectedBar;
  Timer? _autoCloseTimer;

  List<ChartData> get chartData => [
    for (int i = 0; i < 28; i++)
      ChartData(
        i + 1,
        i % 7 ==
                6 // Set value to null for every 7th day (e.g., Day 7, 14, 21, 28)
            ? null
            : i % 5 == 0
            ? 5000
            : (i % 2 == 0 ? 20000000 : -20000000) * (i % 3 + 1) / 3,
      ),
  ];

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Profit/Loss Chart',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 400,
              child: GestureDetector(
                onPanStart: (details) {
                  _updateSelection(
                    details.globalPosition,
                    context,
                    isTap: true,
                  );
                },
                onPanUpdate: (details) {
                  _updateSelection(
                    details.globalPosition,
                    context,
                    isTap: false,
                  );
                },
                child: CustomBarChart(
                  data: chartData,
                  selectedBar: _selectedBar,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateSelection(
    Offset globalPosition,
    BuildContext context, {
    required bool isTap,
  }) {
    // Cancel existing timer
    _autoCloseTimer?.cancel();

    RenderBox box = context.findRenderObject() as RenderBox;
    final local = box.globalToLocal(globalPosition);
    const double margin = 20;
    const double topBarGap = 48;
    final double chartWidth = box.size.width - 2 * margin;
    final double chartHeight = box.size.height - 2 * margin - topBarGap;
    final double barWidth = chartWidth / chartData.length;
    final maxY = chartData
        .map((e) => e.value ?? 0)
        .reduce((a, b) => a > b ? a : b);
    final minY = chartData
        .map((e) => e.value ?? 0)
        .reduce((a, b) => a < b ? a : b);
    final yRange = (maxY - minY).abs() == 0 ? 1 : (maxY - minY).abs();
    final double sepY = margin + topBarGap + chartHeight * (maxY / yRange);

    int? tappedIndex;
    for (int i = 0; i < chartData.length; i++) {
      final barLeft = margin + i * barWidth + barWidth * 0.1;
      final barRight = barLeft + barWidth * 0.8;
      const tapBuffer = 10.0;
      bool isHit;

      if (isTap) {
        // For initial tap, check both x and y coordinates
        final value = chartData[i].value;
        double barTop, barBottom;
        if (value == null) {
          // For null values, use a fixed-height grey bar
          const nullBarHeight = 6.0; // 5 pixels above and below zero line
          barTop = sepY - nullBarHeight / 2;
          barBottom = sepY + nullBarHeight / 2;
        } else if (value >= 0) {
          barTop = sepY - (value / yRange) * chartHeight;
          barBottom = sepY;
        } else {
          barTop = sepY;
          barBottom = sepY + (value.abs() / yRange) * chartHeight;
        }
        if (barBottom < barTop) {
          final tmp = barTop;
          barTop = barBottom;
          barBottom = tmp;
        }
        isHit =
            local.dx >= barLeft - tapBuffer &&
            local.dx <= barRight + tapBuffer &&
            local.dy >= barTop - tapBuffer &&
            local.dy <= barBottom + tapBuffer;
      } else {
        // For swipe, check only x-coordinate
        isHit =
            local.dx >= barLeft - tapBuffer && local.dx <= barRight + tapBuffer;
      }

      if (isHit) {
        print(
          'Selected bar $i: value=${chartData[i].value ?? 'null'}, '
          'left=$barLeft, right=$barRight, tap=(${local.dx}, ${local.dy}), isTap=$isTap',
        );
        tappedIndex = i;
        break;
      }
    }
    print('Selected bar index: $tappedIndex');

    setState(() {
      _selectedBar = tappedIndex;
      // Start timer only if a bar is selected
      if (tappedIndex != null) {
        _autoCloseTimer = Timer(const Duration(seconds: 3), () {
          setState(() {
            _selectedBar = null;
            print('Auto-closed selection after 3 seconds');
          });
        });
      }
    });
  }
}

class CustomBarChart extends StatelessWidget {
  final List<ChartData> data;
  final int? selectedBar;

  const CustomBarChart({super.key, required this.data, this.selectedBar});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: BarChartPainter(data: data, selectedBar: selectedBar),
      child: Container(),
    );
  }
}

class BarChartPainter extends CustomPainter {
  final List<ChartData> data;
  final int? selectedBar;

  BarChartPainter({required this.data, this.selectedBar});

  @override
  void paint(Canvas canvas, Size size) {
    const double margin = 20;
    const double topBarGap = 48;
    final double chartHeight = size.height - 2 * margin - topBarGap;
    double chartWidth = size.width - 2 * margin;
    double barWidth = chartWidth / data.length;
    final maxY = data.map((e) => e.value ?? 0).reduce((a, b) => a > b ? a : b);
    final minY = data.map((e) => e.value ?? 0).reduce((a, b) => a < b ? a : b);
    final yRange = (maxY - minY).abs() == 0 ? 1 : (maxY - minY).abs();
    final double sepY = margin + topBarGap + chartHeight * (maxY / yRange);
    // Draw y-axis labels
    final yLabelPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    final textStyle = TextStyle(color: Colors.black, fontSize: 12);
    final num yLabelCount = 5;
    final num yLabelInterval = yRange / (yLabelCount - 1);
    for (int i = 0; i < yLabelCount; i++) {
      final yValue = minY + i * yLabelInterval;
      final yPos = sepY - (yValue / yRange) * chartHeight;
      final textSpan = TextSpan(
        text: yValue.toStringAsFixed(0),
        style: textStyle,
      );

      // calculate width of text
      final yAxisLabelWidth =
          textSpan.toPlainText().length * 7.0; // Approximate width

      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.right,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: margin + yAxisLabelWidth);
      textPainter.paint(
        canvas,
        Offset(margin - textPainter.width - 4, yPos - textPainter.height / 2),
      );
    }

    // Draw x-axis labels
    for (int i = 0; i < data.length; i += 2) {
      final xPos = margin + i * barWidth + barWidth / 2;
      // make text take width of content
      final textSpan = TextSpan(text: '${data[i].day}', style: textStyle);
      final xAxisLabelWidth =
          textSpan.toPlainText().length * 7.0; // Approximate width
      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: barWidth + xAxisLabelWidth);
      textPainter.paint(
        canvas,
        Offset(xPos - textPainter.width / 2, size.height - margin + 4),
      );
    }
    // Draw X-axis line at zero value (separator line)
    final axisPaint = Paint()
      ..color = const Color(0xFFE4E4E7)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(margin, sepY),
      Offset(size.width - margin, sepY),
      axisPaint,
    );

    // Draw bars
    for (int i = 0; i < data.length; i++) {
      final value = data[i].value;
      final barLeft = margin + i * barWidth + barWidth * 0.1;
      final barRight = barLeft + barWidth * 0.8;
      double barTop, barBottom;
      if (value == null) {
        // Draw small grey bar for null values
        const nullBarHeight = 6.0; // 5 pixels above and below zero line
        barTop = sepY - nullBarHeight / 2;
        barBottom = sepY + nullBarHeight / 2;
      } else if (value >= 0) {
        barTop = sepY - (value / yRange) * chartHeight;
        barBottom = sepY;
      } else {
        barTop = sepY;
        barBottom = sepY + (value.abs() / yRange) * chartHeight;
      }
      if (barBottom < barTop) {
        final tmp = barTop;
        barTop = barBottom;
        barBottom = tmp;
      }
      final barRect = Rect.fromLTRB(barLeft, barTop, barRight, barBottom);
      final barPaint = Paint()
        ..color = value == null
            ? Color(0xFFE4E4E7)
            : value >= 0
            ? const Color(0xFF13861D)
            : const Color(0xFFDF130C);
      final r = Radius.circular(6);
      final borderRadius = value == null
          ? BorderRadius.all(
              Radius.circular(0),
            ) // Rounded on all sides for null bars
          : value >= 0
          ? BorderRadius.only(topLeft: r, topRight: r)
          : BorderRadius.only(bottomLeft: r, bottomRight: r);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          barRect,
          topLeft: borderRadius.topLeft,
          topRight: borderRadius.topRight,
          bottomLeft: borderRadius.bottomLeft,
          bottomRight: borderRadius.bottomRight,
        ),
        barPaint,
      );
    }

    // Draw dotted vertical line and tooltip for selected bar
    if (selectedBar != null) {
      final i = selectedBar!;
      final barLeft = margin + i * barWidth + barWidth * 0.1;
      final barRight = barLeft + barWidth * 0.8;
      final barCenter = barLeft + (barRight - barLeft) / 2;

      // Draw dotted vertical line
      final linePaint = Paint()
        ..color = Color(0xff0C0C0D)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      // make dashes round
      final dashHeight = 5;
      final dashSpace = 5;
      double currentY = margin;
      // if bar is green then dotted line will start from chart top to green bar's bottom else it will start from top of chart to bottom of chart
      // if (data[i].value != null && data[i].value! >= 0) {
      //   currentY = sepY - (data[i].value! / yRange) * chartHeight;
      // } else {
      //   currentY = sepY;
      // }
      // Draw dashes from top to bottom of chart
      while (currentY < size.height - margin) {
        canvas.drawLine(
          Offset(barCenter, currentY),
          Offset(barCenter, currentY + dashHeight),
          linePaint,
        );
        currentY += dashHeight + dashSpace;
      }

      // Draw tooltip
      final tooltipText = data[i].value == null
          ? 'Day ${data[i].day}\nNo Data'
          : 'Day ${data[i].day}\n${data[i].value}';
      final textSpan = TextSpan(
        text: tooltipText,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 150.0); // Adjusted to fixed width
      final tooltipWidth = 150.0; // Fixed width of 150.0 pixels
      final tooltipHeight = textPainter.height + 16;
      // make tooltip align from left only 25%
      double tooltipX = barCenter - tooltipWidth * 0.25;
      tooltipX = tooltipX.clamp(margin, size.width - margin - tooltipWidth);
      final tooltipY = margin - 4;
      final tooltipRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(tooltipX, tooltipY, tooltipWidth, tooltipHeight),
        const Radius.circular(8),
      );
      // add border to tooltip
      final tooltipBorderPaint = Paint()
        ..color = Color(0xFFE4E4E7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawRRect(tooltipRect, tooltipBorderPaint);
      // add arrow to tooltip from left 25%
      final arrowPath = Path()
        ..moveTo(tooltipX + tooltipWidth * 0.25 - 10, tooltipY + tooltipHeight)
        ..lineTo(tooltipX + tooltipWidth * 0.25, tooltipY + tooltipHeight + 10)
        ..lineTo(tooltipX + tooltipWidth * 0.25 + 10, tooltipY + tooltipHeight)
        ..close();
      canvas.drawPath(arrowPath, tooltipBorderPaint);

      // add background to arrow
      final arrowPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawPath(arrowPath, arrowPaint);

      // add border to arrow only left and right
      final arrowBorderPaint = Paint()
        ..color = Color(0xFFE4E4E7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(tooltipX + tooltipWidth * 0.25 - 10, tooltipY + tooltipHeight),
        Offset(tooltipX + tooltipWidth * 0.25, tooltipY + tooltipHeight + 10),
        arrowBorderPaint,
      );
      canvas.drawLine(
        Offset(tooltipX + tooltipWidth * 0.25 + 10, tooltipY + tooltipHeight),
        Offset(tooltipX + tooltipWidth * 0.25, tooltipY + tooltipHeight + 10),
        arrowBorderPaint,
      );

      // move arror to where dotted line moves
      if (i > 0) {
        final prevBarLeft = margin + (i - 1) * barWidth + barWidth * 0.1;
        final prevBarRight = prevBarLeft + barWidth * 0.8;
        final prevBarCenter = prevBarLeft + (prevBarRight - prevBarLeft) / 2;
        tooltipX = prevBarCenter - tooltipWidth * 0.25;
        tooltipX = tooltipX.clamp(margin, size.width - margin - tooltipWidth);
      }

      final tooltipPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawShadow(
        Path()..addRRect(tooltipRect),
        Colors.black.withOpacity(0.1),
        4,
        false,
      );
      canvas.drawRRect(tooltipRect, tooltipPaint);
      textPainter.paint(
        canvas,
        Offset(tooltipX + (tooltipWidth - textPainter.width) / 2, tooltipY + 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant BarChartPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.selectedBar != selectedBar;
  }
}
