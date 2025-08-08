import 'dart:async';
import 'package:flutter/material.dart';

class CustomBarChart<T> extends StatefulWidget {
  final List<T> data;
  final dynamic Function(T chartDataType) xValueMapper;
  final num? Function(T chartDataType) yValueMapper;
  final Function(int? selectedIndex)? onSelectionChanged;
  final String Function(dynamic xValue)? xAxisLabelFormatter;
  final String Function(num yValue)? yAxisLabelFormatter;
  final String Function(T dataItem)? tooltipDataFormatter;

  const CustomBarChart({
    super.key,
    required this.data,
    required this.xValueMapper,
    required this.yValueMapper,
    this.onSelectionChanged,
    this.xAxisLabelFormatter,
    this.yAxisLabelFormatter,
    this.tooltipDataFormatter,
  });

  @override
  State<CustomBarChart<T>> createState() => _CustomBarChartState<T>();
}

class _CustomBarChartState<T> extends State<CustomBarChart<T>> {
  int? _selectedBar;
  Timer? _autoCloseTimer;

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  double _calculateLeftMargin() {
    if (widget.data.isEmpty) return 40.0; // Default minimum margin

    // Calculate y-axis range and labels
    final maxY = widget.data
        .map((entry) => widget.yValueMapper(entry) ?? 0)
        .reduce((a, b) => a > b ? a : b);
    final minY = widget.data
        .map((entry) => widget.yValueMapper(entry) ?? 0)
        .reduce((a, b) => a < b ? a : b);
    final yRange = (maxY - minY).abs() == 0 ? 1 : (maxY - minY).abs();

    const num yLabelCount = 5;
    final num yLabelInterval = yRange / (yLabelCount - 1);

    double maxLabelWidth = 0;

    for (int i = 0; i < yLabelCount; i++) {
      final yValue = minY + i * yLabelInterval;

      // Use formatter if provided, otherwise use default formatting
      final labelText =
          widget.yAxisLabelFormatter != null
              ? widget.yAxisLabelFormatter!(yValue)
              : yValue.toStringAsFixed(0);

      final textSpan = TextSpan(
        text: labelText,
        style: TextStyle(color: Colors.black, fontSize: 12),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.right,
        textDirection: TextDirection.ltr,
      )..layout();

      maxLabelWidth =
          maxLabelWidth < textPainter.width ? textPainter.width : maxLabelWidth;
    }

    // Add some padding (8px on each side)
    return maxLabelWidth + 16.0;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        _updateSelection(details.globalPosition, context, isTap: true);
      },
      onPanUpdate: (details) {
        _updateSelection(details.globalPosition, context, isTap: false);
      },
      child: CustomPaint(
        painter: BarChartPainter<T>(
          data: widget.data,
          selectedBar: _selectedBar,
          xValueMapper: widget.xValueMapper,
          yValueMapper: widget.yValueMapper,
          xAxisLabelFormatter: widget.xAxisLabelFormatter,
          yAxisLabelFormatter: widget.yAxisLabelFormatter,
          tooltipDataFormatter: widget.tooltipDataFormatter,
          leftMargin: _calculateLeftMargin(),
        ),
        child: Container(),
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
    final double leftMargin =
        _calculateLeftMargin(); // Dynamic left margin for y-axis labels
    const double rightMargin = 20; // Smaller right margin
    const double topMargin = 20;
    const double bottomMargin = 20;
    // Make spacing proportional to chart height instead of fixed values
    final double topBarGap =
        box.size.height * 0.15; // 15% of height for tooltip space
    final double bottomBarGap =
        box.size.height * 0.12; // 12% of height for space below negative bars
    const double xAxisLabelHeight = 20; // Space reserved for x-axis labels
    const double bottomSpacing =
        10; // Additional space between negative bars and x-axis labels
    final double chartWidth = box.size.width - leftMargin - rightMargin;
    final double chartHeight =
        box.size.height -
        topMargin -
        bottomMargin -
        topBarGap -
        bottomBarGap -
        xAxisLabelHeight -
        bottomSpacing;
    final double barWidth = chartWidth / widget.data.length;

    // Add left and right margins for bars (each margin = width of one bar)
    final double barsMargin = barWidth;
    final double barsAreaWidth = chartWidth - 2 * barsMargin;
    final double adjustedBarWidth = barsAreaWidth / widget.data.length;

    final maxY = widget.data
        .map((e) => widget.yValueMapper(e) ?? 0)
        .reduce((a, b) => a > b ? a : b);
    final minY = widget.data
        .map((e) => widget.yValueMapper(e) ?? 0)
        .reduce((a, b) => a < b ? a : b);
    final yRange = (maxY - minY).abs() == 0 ? 1 : (maxY - minY).abs();
    final double sepY =
        topMargin + topBarGap + (chartHeight * (maxY - 0) / yRange);

    int? tappedIndex;
    for (int i = 0; i < widget.data.length; i++) {
      final barLeft =
          leftMargin +
          barsMargin +
          i * adjustedBarWidth +
          adjustedBarWidth * 0.1;
      final barRight = barLeft + adjustedBarWidth * 0.8;
      const tapBuffer = 10.0;
      bool isHit;

      if (isTap) {
        // For initial tap, check both x and y coordinates
        final value = widget.yValueMapper(widget.data[i]);
        double barTop, barBottom;
        if (value == null) {
          // For null values, use a fixed-height grey bar
          const nullBarHeight = 6.0;
          barTop = sepY - nullBarHeight / 2;
          barBottom = sepY + nullBarHeight / 2;
        } else if (value >= 0) {
          // For positive values: bar goes from zero line up
          barTop = sepY - ((value - 0) / yRange) * chartHeight;
          barBottom = sepY;
        } else {
          // For negative values: bar goes from zero line down
          barTop = sepY;
          barBottom = sepY + ((0 - value) / yRange) * chartHeight;
        }

        // Ensure bars stay within chart bounds for hit detection
        barTop = barTop.clamp(
          topMargin + topBarGap,
          topMargin + topBarGap + chartHeight,
        );
        barBottom = barBottom.clamp(
          topMargin + topBarGap,
          topMargin + topBarGap + chartHeight,
        );
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
          'Selected bar $i: value=${widget.yValueMapper(widget.data[i]) ?? 'null'}, '
          'left=$barLeft, right=$barRight, tap=(${local.dx}, ${local.dy}), isTap=$isTap',
        );
        tappedIndex = i;
        break;
      }
    }
    print('Selected bar index: $tappedIndex');

    setState(() {
      _selectedBar = tappedIndex;
      // Call the callback if provided
      widget.onSelectionChanged?.call(tappedIndex);

      // Start timer only if a bar is selected
      if (tappedIndex != null) {
        _autoCloseTimer = Timer(const Duration(seconds: 3), () {
          setState(() {
            _selectedBar = null;
            widget.onSelectionChanged?.call(null);
            print('Auto-closed selection after 3 seconds');
          });
        });
      }
    });
  }
}

class BarChartPainter<T> extends CustomPainter {
  final List<T> data;
  final int? selectedBar;
  final dynamic Function(T chartDataType) xValueMapper;
  final num? Function(T chartDataType) yValueMapper;
  final String Function(dynamic xValue)? xAxisLabelFormatter;
  final String Function(num yValue)? yAxisLabelFormatter;
  final String Function(T dataItem)? tooltipDataFormatter;
  final double leftMargin;

  BarChartPainter({
    required this.data,
    this.selectedBar,
    required this.xValueMapper,
    required this.yValueMapper,
    this.xAxisLabelFormatter,
    this.yAxisLabelFormatter,
    this.tooltipDataFormatter,
    required this.leftMargin,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Use the dynamic left margin passed from the parent widget
    const double rightMargin = 20; // Smaller right margin
    const double topMargin = 20;
    const double bottomMargin = 20;
    // Make spacing proportional to chart height instead of fixed values
    final double topBarGap =
        size.height * 0.15; // 15% of height for tooltip space
    final double bottomBarGap =
        size.height * 0.12; // 12% of height for space below negative bars
    const double xAxisLabelHeight = 20; // Space reserved for x-axis labels
    const double bottomSpacing =
        10; // Additional space between negative bars and x-axis labels
    final double chartHeight =
        size.height -
        topMargin -
        bottomMargin -
        topBarGap -
        bottomBarGap -
        xAxisLabelHeight -
        bottomSpacing;
    double chartWidth = size.width - leftMargin - rightMargin;
    double barWidth = chartWidth / data.length;

    // Add left and right margins for bars (each margin = width of one bar)
    final double barsMargin = barWidth;
    final double barsAreaWidth = chartWidth - 2 * barsMargin;
    final double adjustedBarWidth = barsAreaWidth / data.length;

    final maxY = data
        .map((entry) => yValueMapper(entry) ?? 0)
        .reduce((a, b) => a > b ? a : b);
    final minY = data
        .map((entry) => yValueMapper(entry) ?? 0)
        .reduce((a, b) => a < b ? a : b);
    final yRange = (maxY - minY).abs() == 0 ? 1 : (maxY - minY).abs();

    // Calculate zero line position to properly distribute positive and negative values
    // Zero line should be positioned proportionally based on where 0 falls in the range
    final double sepY =
        topMargin + topBarGap + (chartHeight * (maxY - 0) / yRange);
    // Draw y-axis labels
    final textStyle = TextStyle(color: Colors.black, fontSize: 12);
    final num yLabelCount = 5;
    final num yLabelInterval = yRange / (yLabelCount - 1);
    for (int i = 0; i < yLabelCount; i++) {
      final yValue = minY + i * yLabelInterval;
      // Calculate position based on the value's position relative to zero
      final yPos = sepY - ((yValue - 0) / yRange) * chartHeight;

      // Ensure y position is within chart bounds
      if (yPos >= topMargin + topBarGap &&
          yPos <= topMargin + topBarGap + chartHeight) {
        // Use formatter if provided, otherwise use default formatting
        final labelText =
            yAxisLabelFormatter != null
                ? yAxisLabelFormatter!(yValue)
                : yValue.toStringAsFixed(0);

        final textSpan = TextSpan(text: labelText, style: textStyle);

        final textPainter = TextPainter(
          text: textSpan,
          textAlign: TextAlign.right,
          textDirection: TextDirection.ltr,
        )..layout(
          maxWidth: leftMargin - 8,
        ); // Ensure labels fit within left margin
        textPainter.paint(
          canvas,
          Offset(
            4,
            yPos - textPainter.height / 2,
          ), // Position labels within left margin
        );
      }
    }

    // Draw x-axis labels with dynamic spacing to prevent overlap
    if (data.isNotEmpty) {
      // Calculate how many labels can fit without overlapping
      final sampleXValue = xValueMapper(data[0]);
      final sampleLabelText =
          xAxisLabelFormatter != null
              ? xAxisLabelFormatter!(sampleXValue)
              : '$sampleXValue';

      // Estimate label width (approximate: character count * 7 + padding)
      final estimatedLabelWidth =
          sampleLabelText.length * 7.0 + 16; // 8px padding on each side
      final maxLabelsToFit = (chartWidth / estimatedLabelWidth).floor();
      final totalDataPoints = data.length;

      // Calculate step size to fit labels without overlap
      final stepSize = (totalDataPoints / maxLabelsToFit).ceil().clamp(
        1,
        totalDataPoints,
      );

      for (int i = 0; i < data.length; i += stepSize) {
        final xPos =
            leftMargin +
            barsMargin +
            i * adjustedBarWidth +
            adjustedBarWidth / 2;
        final xValue = xValueMapper(data[i]);

        // Use formatter if provided, otherwise use default formatting
        final labelText =
            xAxisLabelFormatter != null
                ? xAxisLabelFormatter!(xValue)
                : '$xValue';

        // make text take width of content
        final textSpan = TextSpan(text: labelText, style: textStyle);
        final xAxisLabelWidth =
            textSpan.toPlainText().length * 7.0; // Approximate width
        final textPainter = TextPainter(
          text: textSpan,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: adjustedBarWidth + xAxisLabelWidth);
        textPainter.paint(
          canvas,
          Offset(
            xPos - textPainter.width / 2,
            topMargin + topBarGap + chartHeight + bottomSpacing + 4,
          ),
        );
      }
    }
    // Draw X-axis line at zero value (separator line)
    final axisPaint =
        Paint()
          ..color = const Color(0xFFE4E4E7)
          ..strokeWidth = 1;
    canvas.drawLine(
      Offset(leftMargin + barsMargin, sepY),
      Offset(size.width - rightMargin - barsMargin, sepY),
      axisPaint,
    );

    // Draw bars
    for (int i = 0; i < data.length; i++) {
      final value = yValueMapper(data[i]);
      final barLeft =
          leftMargin +
          barsMargin +
          i * adjustedBarWidth +
          adjustedBarWidth * 0.1;
      final barRight = barLeft + adjustedBarWidth * 0.8;
      double barTop, barBottom;
      if (value == null) {
        // Draw small grey bar for null values
        const nullBarHeight = 6.0;
        barTop = sepY - nullBarHeight / 2;
        barBottom = sepY + nullBarHeight / 2;
      } else if (value >= 0) {
        // For positive values: bar goes from zero line up
        barTop = sepY - ((value - 0) / yRange) * chartHeight;
        barBottom = sepY;
      } else {
        // For negative values: bar goes from zero line down
        barTop = sepY;
        barBottom = sepY + ((0 - value) / yRange) * chartHeight;
      }

      // Ensure bars stay within chart bounds
      barTop = barTop.clamp(
        topMargin + topBarGap,
        topMargin + topBarGap + chartHeight,
      );
      barBottom = barBottom.clamp(
        topMargin + topBarGap,
        topMargin + topBarGap + chartHeight,
      );

      if (barBottom < barTop) {
        final tmp = barTop;
        barTop = barBottom;
        barBottom = tmp;
      }
      final barRect = Rect.fromLTRB(barLeft, barTop, barRight, barBottom);
      final barPaint =
          Paint()
            ..color =
                value == null
                    ? Color(0xFFE4E4E7)
                    : value >= 0
                    ? const Color(0xFF13861D)
                    : const Color(0xFFDF130C);
      final r = Radius.circular(6);
      final borderRadius =
          value == null
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
      final barLeft =
          leftMargin +
          barsMargin +
          i * adjustedBarWidth +
          adjustedBarWidth * 0.1;
      final barRight = barLeft + adjustedBarWidth * 0.8;
      final barCenter = barLeft + (barRight - barLeft) / 2;

      // Draw dotted vertical line
      final linePaint =
          Paint()
            ..color = Color(0xff0C0C0D)
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round;

      // Calculate the end position of the vertical line based on bar type
      final selectedBarValue = yValueMapper(data[i]);
      double lineStartY;
      double lineEndY;

      if (selectedBarValue != null && selectedBarValue >= 0) {
        // For positive bars: line goes from tooltip arrow to x-axis (zero line)
        // Calculate tooltip position to connect the line
        final barValue = yValueMapper(data[i]);
        final extraSpaceForPositiveBars =
            (barValue != null && barValue >= 0) ? 20.0 : 0.0;
        final tooltipY = topMargin - 4 - extraSpaceForPositiveBars;
        // Use estimated tooltip height (text height + padding + arrow height)
        final estimatedTooltipHeight = 50.0; // Approximate height
        lineStartY =
            tooltipY + estimatedTooltipHeight + 10; // Start from arrow tip
        lineEndY = sepY;
      } else if (selectedBarValue != null && selectedBarValue < 0) {
        // For negative bars: line goes from chart top till the end of negative bar
        lineStartY = topMargin + topBarGap; // Start from chart area top
        double negativeBarBottom =
            sepY + ((0 - selectedBarValue) / yRange) * chartHeight;
        // Ensure it stays within chart bounds
        negativeBarBottom = negativeBarBottom.clamp(
          topMargin + topBarGap,
          topMargin + topBarGap + chartHeight,
        );
        lineEndY = negativeBarBottom;
      } else {
        // For null values: line goes from chart top till x-axis
        lineStartY = topMargin + topBarGap; // Start from chart area top
        lineEndY = sepY;
      }

      // Draw dashes from calculated start to end position
      final dashHeight = 5;
      final dashSpace = 5;
      double currentY = lineStartY;

      while (currentY < lineEndY) {
        final remainingHeight = lineEndY - currentY;
        final actualDashHeight =
            remainingHeight < dashHeight ? remainingHeight : dashHeight;

        canvas.drawLine(
          Offset(barCenter, currentY),
          Offset(barCenter, currentY + actualDashHeight),
          linePaint,
        );
        currentY += dashHeight + dashSpace;
      }

      // Draw tooltip
      final dataItem = data[i];

      // Use tooltip formatter if provided, otherwise use default formatting
      final tooltipText =
          tooltipDataFormatter != null
              ? tooltipDataFormatter!(dataItem)
              : _getDefaultTooltipText(
                dataItem,
                xValueMapper,
                yValueMapper,
                xAxisLabelFormatter,
                yAxisLabelFormatter,
              );

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

      // Calculate initial tooltip position (try to align arrow at 25% with bar center)
      double tooltipX = barCenter - tooltipWidth * 0.25;

      // Clamp tooltip to stay within screen bounds
      double originalTooltipX = tooltipX;
      tooltipX = tooltipX.clamp(
        leftMargin,
        size.width - rightMargin - tooltipWidth,
      );

      // Add extra space between positive bars and tooltip
      final barValue = yValueMapper(data[i]);
      final extraSpaceForPositiveBars =
          (barValue != null && barValue >= 0) ? 20.0 : 0.0;
      final tooltipY = topMargin - 4 - extraSpaceForPositiveBars;

      // Check if tooltip was clamped (moved from original position)
      bool tooltipWasClamped = tooltipX != originalTooltipX;

      // Calculate arrow position
      final arrowXOffsetFinal =
          tooltipWasClamped
              ? (barCenter - tooltipX).clamp(
                15.0,
                tooltipWidth - 15.0,
              ) // Move arrow with dotted line if clamped
              : tooltipWidth * 0.25; // Use default 25% position if not clamped

      final tooltipRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(tooltipX, tooltipY, tooltipWidth, tooltipHeight),
        const Radius.circular(8),
      );

      // Draw tooltip background first
      final tooltipPaint =
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill;
      canvas.drawShadow(
        Path()..addRRect(tooltipRect),
        Colors.black.withOpacity(0.1),
        4,
        false,
      );
      canvas.drawRRect(tooltipRect, tooltipPaint);

      // add border to tooltip
      final tooltipBorderPaint =
          Paint()
            ..color = Color(0xFFE4E4E7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1;
      canvas.drawRRect(tooltipRect, tooltipBorderPaint);

      // add arrow to tooltip - use calculated position
      final arrowPath =
          Path()
            ..moveTo(
              tooltipX + arrowXOffsetFinal - 10,
              tooltipY + tooltipHeight,
            )
            ..lineTo(
              tooltipX + arrowXOffsetFinal,
              tooltipY + tooltipHeight + 10,
            )
            ..lineTo(
              tooltipX + arrowXOffsetFinal + 10,
              tooltipY + tooltipHeight,
            )
            ..close();

      // add background to arrow
      final arrowPaint =
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill;
      canvas.drawPath(arrowPath, arrowPaint);

      // add border to arrow only left and right sides
      final arrowBorderPaint =
          Paint()
            ..color = Color(0xFFE4E4E7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1;
      canvas.drawLine(
        Offset(tooltipX + arrowXOffsetFinal - 10, tooltipY + tooltipHeight),
        Offset(tooltipX + arrowXOffsetFinal, tooltipY + tooltipHeight + 10),
        arrowBorderPaint,
      );
      canvas.drawLine(
        Offset(tooltipX + arrowXOffsetFinal + 10, tooltipY + tooltipHeight),
        Offset(tooltipX + arrowXOffsetFinal, tooltipY + tooltipHeight + 10),
        arrowBorderPaint,
      );

      // Draw text on top
      textPainter.paint(
        canvas,
        Offset(tooltipX + (tooltipWidth - textPainter.width) / 2, tooltipY + 8),
      );

      // Draw dot indicator on selected bar
      final selectedValue = yValueMapper(data[i]);
      if (selectedValue != null) {
        // Calculate bar dimensions for the selected bar
        final selectedBarLeft =
            leftMargin +
            barsMargin +
            i * adjustedBarWidth +
            adjustedBarWidth * 0.1;
        final selectedBarRight = selectedBarLeft + adjustedBarWidth * 0.8;
        final selectedBarCenter =
            selectedBarLeft + (selectedBarRight - selectedBarLeft) / 2;

        double selectedBarTop, selectedBarBottom;
        if (selectedValue >= 0) {
          // For positive values: bar goes from zero line up
          selectedBarTop = sepY - ((selectedValue - 0) / yRange) * chartHeight;
          selectedBarBottom = sepY;
        } else {
          // For negative values: bar goes from zero line down
          selectedBarTop = sepY;
          selectedBarBottom =
              sepY + ((0 - selectedValue) / yRange) * chartHeight;
        }

        // Ensure bars stay within chart bounds
        selectedBarTop = selectedBarTop.clamp(
          topMargin + topBarGap,
          topMargin + topBarGap + chartHeight,
        );
        selectedBarBottom = selectedBarBottom.clamp(
          topMargin + topBarGap,
          topMargin + topBarGap + chartHeight,
        );

        if (selectedBarBottom < selectedBarTop) {
          final tmp = selectedBarTop;
          selectedBarTop = selectedBarBottom;
          selectedBarBottom = tmp;
        }

        // Determine dot position based on bar value
        final dotY = selectedValue >= 0 ? selectedBarTop : selectedBarBottom;
        final dotCenter = Offset(selectedBarCenter, dotY);

        // Get bar color for the dot shadow
        final barColor =
            selectedValue >= 0
                ? const Color(0xFF13861D)
                : const Color(0xFFDF130C);

        // Draw shadow (spread effect with 25% opacity)
        final shadowPaint =
            Paint()
              ..color = barColor.withOpacity(0.25)
              ..style = PaintingStyle.fill;
        canvas.drawCircle(
          dotCenter,
          6.0,
          shadowPaint,
        ); // 4px radius + 2px spread = 6px total

        // Draw main dot (4px diameter = 2px radius)
        final dotPaint =
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.fill;
        canvas.drawCircle(dotCenter, 2.0, dotPaint);

        // Draw border (0.4px black)
        final borderPaint =
            Paint()
              ..color = Colors.black
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.4;
        canvas.drawCircle(dotCenter, 2.0, borderPaint);
      }
    }
  }

  String _getDefaultTooltipText(
    T dataItem,
    dynamic Function(T) xValueMapper,
    num? Function(T) yValueMapper,
    String Function(dynamic)? xAxisLabelFormatter,
    String Function(num)? yAxisLabelFormatter,
  ) {
    final xValue = xValueMapper(dataItem);
    final yValue = yValueMapper(dataItem);

    final xLabelText =
        xAxisLabelFormatter != null
            ? xAxisLabelFormatter!(xValue)
            : 'Day $xValue';
    final yLabelText =
        yValue == null
            ? 'No Data'
            : (yAxisLabelFormatter != null
                ? yAxisLabelFormatter!(yValue)
                : '$yValue');

    return '$xLabelText\n$yLabelText';
  }

  @override
  bool shouldRepaint(covariant BarChartPainter<T> oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.selectedBar != selectedBar ||
        oldDelegate.xValueMapper != xValueMapper ||
        oldDelegate.yValueMapper != yValueMapper ||
        oldDelegate.xAxisLabelFormatter != xAxisLabelFormatter ||
        oldDelegate.yAxisLabelFormatter != yAxisLabelFormatter ||
        oldDelegate.tooltipDataFormatter != tooltipDataFormatter ||
        oldDelegate.leftMargin != leftMargin;
  }
}
