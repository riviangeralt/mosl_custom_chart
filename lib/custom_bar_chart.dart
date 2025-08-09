import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

/// Controller for MoCustomBarChart to programmatically control chart interactions
class MoCustomBarChartController {
  _MoCustomBarChartState? _state;

  /// Show tooltip at the specified index
  /// Returns true if successful, false if index is invalid
  bool showTooltipAtIndex(int index) {
    if (_state == null) return false;
    return _state!._showTooltipAtIndex(index);
  }

  /// Hide the currently visible tooltip
  void hideTooltip() {
    _state?._hideTooltip();
  }

  /// Get the currently selected bar index, returns null if no bar is selected
  int? get selectedIndex => _state?._selectedBar;

  void _attach(_MoCustomBarChartState state) {
    _state = state;
  }

  void _detach() {
    _state = null;
  }
}

// Custom gesture recognizer that has priority over other gestures
class _CustomPanGestureRecognizer extends OneSequenceGestureRecognizer {
  final Function(Offset)? onPointerDown;
  final Function(Offset)? onPointerMove;
  final Function()? onPointerUp;

  _CustomPanGestureRecognizer({
    this.onPointerDown,
    this.onPointerMove,
    this.onPointerUp,
  });

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    // Immediately resolve to win the gesture arena
    resolve(GestureDisposition.accepted);
    onPointerDown?.call(event.position);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      onPointerMove?.call(event.position);
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      onPointerUp?.call();
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    // Always accept the gesture to prevent other recognizers from handling it
    resolve(GestureDisposition.accepted);
  }

  @override
  String get debugDescription => 'CustomPanGestureRecognizer';

  @override
  void rejectGesture(int pointer) {
    // Override to prevent rejection - we always want to win
    acceptGesture(pointer);
  }
}

class MoCustomBarChart<T> extends StatefulWidget {
  final List<T> data;
  final dynamic Function(T chartDataType) xValueMapper;
  final num? Function(T chartDataType) yValueMapper;
  final Function(int? selectedIndex)? onSelectionChanged;
  final Function(T dataItem)? onBarTap;
  final String Function(dynamic xValue)? xAxisLabelFormatter;
  final String Function(num yValue)? yAxisLabelFormatter;
  final String Function(T dataItem)? tooltipDataFormatter;
  final double? barWidth;
  final int? maxXLabels; // Maximum number of x-axis labels to display
  final MoCustomBarChartController?
  controller; // Controller for programmatic control

  const MoCustomBarChart({
    super.key,
    required this.data,
    required this.xValueMapper,
    required this.yValueMapper,
    this.onSelectionChanged,
    this.onBarTap,
    this.xAxisLabelFormatter,
    this.yAxisLabelFormatter,
    this.tooltipDataFormatter,
    this.barWidth,
    this.maxXLabels,
    this.controller,
  });

  @override
  State<MoCustomBarChart<T>> createState() => _MoCustomBarChartState<T>();
}

class _MoCustomBarChartState<T> extends State<MoCustomBarChart<T>> {
  int? _selectedBar;
  Timer? _autoCloseTimer;
  bool _isInteracting = false;

  @override
  void initState() {
    super.initState();
    // Attach controller if provided
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(MoCustomBarChart<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Handle controller changes
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach();
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    // Detach controller
    widget.controller?._detach();
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  // Controller methods for programmatic tooltip control
  bool _showTooltipAtIndex(int index) {
    if (index < 0 || index >= widget.data.length) {
      return false;
    }

    setState(() {
      _selectedBar = index;
    });

    // Call the selection callback if provided
    widget.onSelectionChanged?.call(_selectedBar);

    return true;
  }

  void _hideTooltip() {
    setState(() {
      _selectedBar = null;
    });

    // Call the selection callback if provided
    widget.onSelectionChanged?.call(_selectedBar);
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

    // Generate exactly 5 y-axis labels with 0 always included
    List<num> yLabels = [];

    if (minY >= 0) {
      // Only positive values: create 5 evenly spaced labels from 0 to maxY
      final step = maxY / 4;
      for (int i = 0; i < 5; i++) {
        yLabels.add(step * i);
      }
    } else if (maxY <= 0) {
      // Only negative values: create 5 evenly spaced labels from minY to 0
      final step = minY / 4;
      for (int i = 4; i >= 0; i--) {
        yLabels.add(step * i);
      }
    } else {
      // Mixed positive and negative: distribute labels based on data proportion
      final positiveRange = maxY;
      final negativeRange = minY.abs();
      final totalRange = positiveRange + negativeRange;

      // Calculate how many labels to allocate to each side (excluding 0)
      final positiveLabels = ((positiveRange / totalRange) * 4).round().clamp(
        1,
        3,
      );
      final negativeLabels = 4 - positiveLabels;

      yLabels = [];

      // Add negative labels
      if (negativeLabels > 0) {
        final negativeStep = minY / negativeLabels;
        for (int i = negativeLabels; i >= 1; i--) {
          yLabels.add(negativeStep * i);
        }
      }

      // Add zero
      yLabels.add(0);

      // Add positive labels
      if (positiveLabels > 0) {
        final positiveStep = maxY / positiveLabels;
        for (int i = 1; i <= positiveLabels; i++) {
          yLabels.add(positiveStep * i);
        }
      }
    }

    // Filter out labels that are too close to zero to prevent overlap
    const double minDistanceFromZero =
        0.1; // Minimum relative distance from zero
    final double yRange =
        ((maxY - minY).abs() == 0 ? 1 : (maxY - minY).abs()).toDouble();
    final double rangeThreshold = yRange * minDistanceFromZero;

    yLabels =
        yLabels.where((label) {
          // Always keep zero
          if (label == 0) return true;
          // Remove labels too close to zero
          return label.abs() >= rangeThreshold;
        }).toList();

    double maxLabelWidth = 0;

    for (final yValue in yLabels) {
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

    // Add minimal padding (2px on each side)
    return maxLabelWidth + 4.0;
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: <Type, GestureRecognizerFactory>{
        // Custom pan recognizer that wins over TabBar and other gesture recognizers
        _CustomPanGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<_CustomPanGestureRecognizer>(
              () => _CustomPanGestureRecognizer(
                onPointerDown: (offset) {
                  _isInteracting = true; // Don't use setState here
                  _updateSelection(offset, context, isTap: true);
                },
                onPointerMove: (offset) {
                  if (_isInteracting) {
                    _updateSelection(offset, context, isTap: false);
                  }
                },
                onPointerUp: () {
                  _isInteracting = false; // Don't use setState here
                },
              ),
              (_CustomPanGestureRecognizer instance) {},
            ),
      },
      child: CustomPaint(
        size: Size.infinite,
        painter: BarChartPainter<T>(
          data: widget.data,
          selectedBar: _selectedBar,
          xValueMapper: widget.xValueMapper,
          yValueMapper: widget.yValueMapper,
          xAxisLabelFormatter: widget.xAxisLabelFormatter,
          yAxisLabelFormatter: widget.yAxisLabelFormatter,
          tooltipDataFormatter: widget.tooltipDataFormatter,
          leftMargin: _calculateLeftMargin(),
          barWidth: widget.barWidth,
          maxXLabels: widget.maxXLabels,
        ),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.transparent,
        ),
      ),
    );
  }

  void _updateSelection(
    Offset globalPosition,
    BuildContext context, {
    required bool isTap,
  }) {
    // Only cancel existing timer for initial taps, not for pan gestures
    if (isTap) {
      _autoCloseTimer?.cancel();
    }

    RenderBox box = context.findRenderObject() as RenderBox;
    final local = box.globalToLocal(globalPosition);

    final double leftMargin =
        _calculateLeftMargin(); // Dynamic left margin for y-axis labels
    const double rightMargin = 10; // Add some right margin for padding
    const double topMargin = 30; // Increased top margin for more space
    const double bottomMargin = 30; // Increased bottom margin for more space
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

    // Use fixed bar width if provided, otherwise calculate dynamically
    final double fixedBarWidth = widget.barWidth ?? 6.0;
    final double totalBarsWidth = widget.data.length * fixedBarWidth;

    // Add horizontal padding to bars area (10px on each side)
    const double barsAreaPadding = 10.0;
    final double adjustedChartWidth = chartWidth - (barsAreaPadding * 2);
    final double adjustedTotalSpacing = adjustedChartWidth - totalBarsWidth;

    final double barSpacing =
        widget.data.length > 1
            ? adjustedTotalSpacing /
                (widget.data.length + 1) // Space between bars and margins
            : adjustedTotalSpacing / 2; // Center single bar
    final double adjustedBarWidth = fixedBarWidth;

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
      // Add horizontal padding to bars area (10px on each side)
      const double barsAreaPadding = 10.0;

      final barLeft =
          leftMargin +
          barsAreaPadding +
          barSpacing +
          (i * (fixedBarWidth + barSpacing));
      final barRight = barLeft + adjustedBarWidth;
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
        // For pan gestures, use more lenient x-coordinate based detection
        // and allow the entire chart height for easier gesture handling
        isHit =
            local.dx >= barLeft - tapBuffer &&
            local.dx <= barRight + tapBuffer &&
            local.dy >= topMargin + topBarGap &&
            local.dy <= topMargin + topBarGap + chartHeight;
      }

      if (isHit) {
        tappedIndex = i;
        break;
      }
    }

    // For pan gestures, avoid setState to prevent blinking
    // For taps, use setState for proper timer and callback handling
    if (!isTap && _selectedBar != tappedIndex) {
      // For pan gestures: use setState but avoid unnecessary timer operations
      setState(() {
        _selectedBar = tappedIndex;
      });
      widget.onSelectionChanged?.call(tappedIndex);

      // Start/restart timer for pan gestures too
      _autoCloseTimer?.cancel();
      if (tappedIndex != null) {
        _autoCloseTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _selectedBar = null;
              widget.onSelectionChanged?.call(null);
            });
          }
        });
      }
    } else if (isTap) {
      // For taps: use setState for proper state management
      setState(() {
        _selectedBar = tappedIndex;

        // Call the callback if provided
        widget.onSelectionChanged?.call(tappedIndex);

        // Call onBarTap for initial tap only
        if (tappedIndex != null) {
          widget.onBarTap?.call(widget.data[tappedIndex]);
        }

        // Start timer only for initial taps and if a bar is selected
        if (tappedIndex != null) {
          _autoCloseTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _selectedBar = null;
                widget.onSelectionChanged?.call(null);
              });
            }
          });
        }

        // Close tooltip if tapping outside the chart area
        if (tappedIndex == null && _selectedBar != null) {
          _selectedBar = null;
          widget.onSelectionChanged?.call(null);
          _autoCloseTimer?.cancel();
        }
      });
    }
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
  final double? barWidth;
  final int? maxXLabels;

  BarChartPainter({
    required this.data,
    this.selectedBar,
    required this.xValueMapper,
    required this.yValueMapper,
    this.xAxisLabelFormatter,
    this.yAxisLabelFormatter,
    this.tooltipDataFormatter,
    required this.leftMargin,
    this.barWidth,
    this.maxXLabels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Use the dynamic left margin passed from the parent widget
    const double rightMargin = 10; // Add some right margin for padding
    const double topMargin = 30; // Increased top margin for more space
    const double bottomMargin = 30; // Increased bottom margin for more space
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

    // Use fixed bar width if provided, otherwise calculate dynamically
    final double fixedBarWidth = barWidth ?? 6.0;
    final double totalBarsWidth = data.length * fixedBarWidth;

    // Add horizontal padding to bars area (10px on each side)
    const double barsAreaPadding = 10.0;
    final double adjustedChartWidth = chartWidth - (barsAreaPadding * 2);
    final double adjustedTotalSpacing = adjustedChartWidth - totalBarsWidth;

    final double barSpacing =
        data.length > 1
            ? adjustedTotalSpacing /
                (data.length + 1) // Space between bars and margins
            : adjustedTotalSpacing / 2; // Center single bar
    final double adjustedBarWidth = fixedBarWidth;

    final maxY = data
        .map((entry) => yValueMapper(entry) ?? 0)
        .reduce((a, b) => a > b ? a : b);
    final minY = data
        .map((entry) => yValueMapper(entry) ?? 0)
        .reduce((a, b) => a < b ? a : b);
    final yRange = (maxY - minY).abs() == 0 ? 1 : (maxY - minY).abs();

    // Draw y-axis labels
    final textStyle = TextStyle(color: Colors.black, fontSize: 12);

    // Generate exactly 5 y-axis labels with 0 always included - same logic as _calculateLeftMargin
    List<num> yLabels = [];

    if (minY >= 0) {
      // Only positive values: create 5 evenly spaced labels from 0 to maxY
      final step = maxY / 4;
      for (int i = 0; i < 5; i++) {
        yLabels.add(step * i);
      }
    } else if (maxY <= 0) {
      // Only negative values: create 5 evenly spaced labels from minY to 0
      final step = minY / 4;
      for (int i = 4; i >= 0; i--) {
        yLabels.add(step * i);
      }
    } else {
      // Mixed positive and negative: distribute labels based on data proportion
      final positiveRange = maxY;
      final negativeRange = minY.abs();
      final totalRange = positiveRange + negativeRange;

      // Calculate how many labels to allocate to each side (excluding 0)
      final positiveLabels = ((positiveRange / totalRange) * 4).round().clamp(
        1,
        3,
      );
      final negativeLabels = 4 - positiveLabels;

      yLabels = [];

      // Add negative labels
      if (negativeLabels > 0) {
        final negativeStep = minY / negativeLabels;
        for (int i = negativeLabels; i >= 1; i--) {
          yLabels.add(negativeStep * i);
        }
      }

      // Add zero
      yLabels.add(0);

      // Add positive labels
      if (positiveLabels > 0) {
        final positiveStep = maxY / positiveLabels;
        for (int i = 1; i <= positiveLabels; i++) {
          yLabels.add(positiveStep * i);
        }
      }
    }

    // Filter out labels that are too close to zero to prevent overlap
    const double minDistanceFromZero =
        0.1; // Minimum relative distance from zero
    final double rangeThreshold = yRange * minDistanceFromZero;

    yLabels =
        yLabels.where((label) {
          // Always keep zero
          if (label == 0) return true;
          // Remove labels too close to zero
          return label.abs() >= rangeThreshold;
        }).toList();

    // Calculate zero line position based on actual data range (for both bars and labels)
    final double sepY =
        topMargin + topBarGap + (chartHeight * (maxY - 0) / yRange);

    for (final yValue in yLabels) {
      // Calculate position based on the actual data range (same as bars)
      final yPos =
          topMargin + topBarGap + (chartHeight * (maxY - yValue) / yRange);

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
        )..layout(maxWidth: leftMargin - 2); // Minimal right margin for labels
        textPainter.paint(
          canvas,
          Offset(
            1,
            yPos - textPainter.height / 2,
          ), // Minimal left padding for labels
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
      final maxLabelsToFit = (adjustedChartWidth / estimatedLabelWidth).floor();
      final totalDataPoints = data.length;

      // Use maxXLabels if provided, otherwise calculate based on available space
      final effectiveMaxLabels =
          maxXLabels != null
              ? maxXLabels!.clamp(1, totalDataPoints)
              : maxLabelsToFit.clamp(1, totalDataPoints);

      // Calculate step size to fit labels without overlap
      final stepSize = (totalDataPoints / effectiveMaxLabels).ceil().clamp(
        1,
        totalDataPoints,
      );

      for (int i = 0; i < data.length; i += stepSize) {
        // Add horizontal padding to bars area (10px on each side)
        const double barsAreaPadding = 10.0;
        final xPos =
            leftMargin +
            barsAreaPadding +
            barSpacing +
            (i * (fixedBarWidth + barSpacing)) +
            fixedBarWidth / 2;
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
      Offset(leftMargin + barsAreaPadding, sepY),
      Offset(leftMargin + chartWidth - barsAreaPadding, sepY),
      axisPaint,
    );

    // Draw bars
    for (int i = 0; i < data.length; i++) {
      final value = yValueMapper(data[i]);

      // Add horizontal padding to bars area (10px on each side)
      const double barsAreaPadding = 10.0;
      final barLeft =
          leftMargin +
          barsAreaPadding +
          barSpacing +
          (i * (fixedBarWidth + barSpacing));
      final barRight = barLeft + adjustedBarWidth;
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

      // Add horizontal padding to bars area (10px on each side)
      const double barsAreaPadding = 10.0;
      final barLeft =
          leftMargin +
          barsAreaPadding +
          barSpacing +
          (i * (fixedBarWidth + barSpacing));
      final barRight = barLeft + adjustedBarWidth;
      final barCenter = barLeft + (barRight - barLeft) / 2;

      // Draw dotted vertical line
      final linePaint =
          Paint()
            ..color = Color(0xff0C0C0D)
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round;

      // Calculate tooltip content and height first (needed for dotted line positioning)
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
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 200.0);
      final actualTooltipHeight = textPainter.height + 16; // Dynamic height
      final actualTooltipWidth = (textPainter.width + 16).clamp(
        150.0,
        200.0,
      ); // Dynamic width with limits

      // Calculate the end position of the vertical line based on bar type
      final selectedBarValue = yValueMapper(data[i]);
      double lineStartY;
      double lineEndY;
      double tooltipY;

      if (selectedBarValue != null && selectedBarValue >= 0) {
        // For positive bars: line goes from tooltip arrow to x-axis (zero line)
        final extraSpaceForPositiveBars = 20.0;
        tooltipY = topMargin - 4 - extraSpaceForPositiveBars;
        lineStartY =
            tooltipY + actualTooltipHeight + 10; // Start from arrow tip
        lineEndY = sepY;
      } else if (selectedBarValue != null && selectedBarValue < 0) {
        // For negative bars: line goes from tooltip arrow to end of negative bar
        tooltipY = topMargin - 4; // No extra space for negative bars
        lineStartY =
            tooltipY + actualTooltipHeight + 10; // Start from arrow tip
        double negativeBarBottom =
            sepY + ((0 - selectedBarValue) / yRange) * chartHeight;
        // Ensure it stays within chart bounds
        negativeBarBottom = negativeBarBottom.clamp(
          topMargin + topBarGap,
          topMargin + topBarGap + chartHeight,
        );
        lineEndY = negativeBarBottom;
      } else {
        // For null values: line goes from tooltip arrow to x-axis (zero line)
        tooltipY = topMargin - 4; // No extra space for null values
        lineStartY =
            tooltipY + actualTooltipHeight + 10; // Start from arrow tip
        lineEndY = sepY; // End at zero line for null values
      }

      // Ensure tooltip doesn't go above the widget bounds
      tooltipY = tooltipY.clamp(0.0, double.infinity);

      // Draw tooltip using already calculated values
      final tooltipWidth =
          actualTooltipWidth; // Use the dynamically calculated width
      final tooltipHeight =
          actualTooltipHeight; // Use the already calculated height

      // Calculate initial tooltip position (try to align arrow at 25% with bar center)
      double tooltipX = barCenter - tooltipWidth * 0.25;

      // Clamp tooltip to stay within widget bounds
      tooltipX = tooltipX.clamp(
        leftMargin,
        leftMargin + chartWidth - tooltipWidth,
      );

      // Calculate the final arrow X position for dotted line alignment
      // Always align with bar center, regardless of tooltip position
      final arrowXPosition = barCenter;

      // Draw dashes from calculated start to end position - aligned with arrow position
      final dashHeight = 5;
      final dashSpace = 5;
      double currentY = lineStartY;

      while (currentY < lineEndY) {
        final remainingHeight = lineEndY - currentY;
        final actualDashHeight =
            remainingHeight < dashHeight ? remainingHeight : dashHeight;

        canvas.drawLine(
          Offset(
            arrowXPosition,
            currentY,
          ), // Use arrow position instead of barCenter
          Offset(arrowXPosition, currentY + actualDashHeight),
          linePaint,
        );
        currentY += dashHeight + dashSpace;
      }

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

      // add arrow to tooltip - use calculated position aligned with bar center
      final actualArrowXOffset = (barCenter - tooltipX).clamp(
        15.0, // Minimum 15px from left edge of tooltip
        tooltipWidth - 15.0, // Maximum 15px from right edge of tooltip
      );
      final arrowPath =
          Path()
            ..moveTo(
              tooltipX + actualArrowXOffset - 10,
              tooltipY + tooltipHeight,
            )
            ..lineTo(
              tooltipX + actualArrowXOffset,
              tooltipY + tooltipHeight + 10,
            )
            ..lineTo(
              tooltipX + actualArrowXOffset + 10,
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
        Offset(tooltipX + actualArrowXOffset - 10, tooltipY + tooltipHeight),
        Offset(tooltipX + actualArrowXOffset, tooltipY + tooltipHeight + 10),
        arrowBorderPaint,
      );
      canvas.drawLine(
        Offset(tooltipX + actualArrowXOffset + 10, tooltipY + tooltipHeight),
        Offset(tooltipX + actualArrowXOffset, tooltipY + tooltipHeight + 10),
        arrowBorderPaint,
      );

      // Draw text on top (left-aligned)
      textPainter.paint(
        canvas,
        Offset(tooltipX + 8, tooltipY + 8), // Left-aligned with 8px padding
      );

      // Draw dot indicator on selected bar
      final selectedValue = yValueMapper(data[i]);
      if (selectedValue != null) {
        // Calculate bar dimensions for the selected bar
        // Add horizontal padding to bars area (10px on each side)
        const double barsAreaPadding = 10.0;
        final selectedBarLeft =
            leftMargin +
            barsAreaPadding +
            barSpacing +
            (i * (fixedBarWidth + barSpacing));
        final selectedBarRight = selectedBarLeft + adjustedBarWidth;
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
            ? xAxisLabelFormatter(xValue)
            : 'Day $xValue';
    final yLabelText =
        yValue == null
            ? 'No Data'
            : (yAxisLabelFormatter != null
                ? yAxisLabelFormatter(yValue)
                : '$yValue');

    return '$xLabelText\n$yLabelText';
  }

  @override
  bool shouldRepaint(covariant BarChartPainter<T> oldDelegate) {
    // Only repaint if something meaningful has changed
    final bool dataChanged = oldDelegate.data != data;
    final bool selectionChanged = oldDelegate.selectedBar != selectedBar;
    final bool mappersChanged =
        oldDelegate.xValueMapper != xValueMapper ||
        oldDelegate.yValueMapper != yValueMapper;
    final bool formattersChanged =
        oldDelegate.xAxisLabelFormatter != xAxisLabelFormatter ||
        oldDelegate.yAxisLabelFormatter != yAxisLabelFormatter ||
        oldDelegate.tooltipDataFormatter != tooltipDataFormatter;
    final bool layoutChanged =
        oldDelegate.leftMargin != leftMargin ||
        oldDelegate.barWidth != barWidth ||
        oldDelegate.maxXLabels != maxXLabels;

    return dataChanged ||
        selectionChanged ||
        mappersChanged ||
        formattersChanged ||
        layoutChanged;
  }
}
