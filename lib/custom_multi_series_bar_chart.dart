import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

/// Data class to hold a single series of chart data
class ChartData<T> {
  final List<T> data;
  final Color Function(num? yValue) barColorMapper; // Function to determine bar color based on y-value
  final String? seriesName; // Optional name for the series (for tooltip)

  ChartData({
    required this.data,
    required this.barColorMapper,
    this.seriesName,
  });
}

/// Controller for MoCustomMultiSeriesBarChart to programmatically control chart interactions
class MoCustomMultiSeriesBarChartController {
  _MoCustomMultiSeriesBarChartState? _state;

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

  void _attach(_MoCustomMultiSeriesBarChartState state) {
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
    resolve(GestureDisposition.accepted);
  }

  @override
  String get debugDescription => 'CustomPanGestureRecognizer';

  @override
  void rejectGesture(int pointer) {
    acceptGesture(pointer);
  }
}

/// Style configuration for tooltip appearance
class TooltipStyle {
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final Color shadowColor;
  final double shadowBlurRadius;
  final double shadowOpacity;

  const TooltipStyle({
    this.backgroundColor = Colors.white,
    this.borderColor = const Color(0xFFE4E4E7),
    this.borderWidth = 1.0,
    this.borderRadius = 4.0,
    this.shadowColor = Colors.black,
    this.shadowBlurRadius = 20.0,
    this.shadowOpacity = 0.102,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TooltipStyle &&
        other.backgroundColor == backgroundColor &&
        other.borderColor == borderColor &&
        other.borderWidth == borderWidth &&
        other.borderRadius == borderRadius &&
        other.shadowColor == shadowColor &&
        other.shadowBlurRadius == shadowBlurRadius &&
        other.shadowOpacity == shadowOpacity;
  }

  @override
  int get hashCode {
    return backgroundColor.hashCode ^
        borderColor.hashCode ^
        borderWidth.hashCode ^
        borderRadius.hashCode ^
        shadowColor.hashCode ^
        shadowBlurRadius.hashCode ^
        shadowOpacity.hashCode;
  }
}

/// Style configuration for dotted line appearance
class LineStyle {
  final Color color;
  final double strokeWidth;
  final double dashHeight;
  final double dashSpace;

  const LineStyle({
    this.color = const Color(0xff0C0C0D),
    this.strokeWidth = 2.0,
    this.dashHeight = 5.0,
    this.dashSpace = 5.0,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LineStyle &&
        other.color == color &&
        other.strokeWidth == strokeWidth &&
        other.dashHeight == dashHeight &&
        other.dashSpace == dashSpace;
  }

  @override
  int get hashCode {
    return color.hashCode ^
        strokeWidth.hashCode ^
        dashHeight.hashCode ^
        dashSpace.hashCode;
  }
}

class MoCustomMultiSeriesBarChart<T> extends StatefulWidget {
  final List<ChartData<T>> series; // List of series, each with its own data
  final dynamic Function(T chartDataType) xValueMapper;
  final num? Function(T chartDataType) yValueMapper;
  final Function(int? selectedIndex)? onSelectionChanged;
  final Function(T dataItem, int seriesIndex)? onBarTap;
  final TextSpan Function(dynamic xValue)? xAxisLabelStyleFormatter;
  final TextSpan Function(dynamic yValue)? yAxisLabelStyleFormatter;
  final List<TextSpan> Function(T dataItem, int seriesIndex)? tooltipDataFormatter;
  final double? barWidth;
  final double? seriesSpacing; // Spacing between bars of different series
  final int? maxXLabels;
  final MoCustomMultiSeriesBarChartController? controller;
  final num? minY;
  final num? maxY;
  final TooltipStyle? tooltipStyle;
  final LineStyle? lineStyle;
  final Duration animationDuration; // Duration for bar height animations

  const MoCustomMultiSeriesBarChart({
    super.key,
    required this.series,
    required this.xValueMapper,
    required this.yValueMapper,
    this.onSelectionChanged,
    this.onBarTap,
    this.xAxisLabelStyleFormatter,
    this.yAxisLabelStyleFormatter,
    this.tooltipDataFormatter,
    this.barWidth,
    this.seriesSpacing = 2.0,
    this.maxXLabels,
    this.controller,
    this.minY,
    this.maxY,
    this.tooltipStyle,
    this.lineStyle,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  State<MoCustomMultiSeriesBarChart<T>> createState() => _MoCustomMultiSeriesBarChartState<T>();
}

class _MoCustomMultiSeriesBarChartState<T> extends State<MoCustomMultiSeriesBarChart<T>> with SingleTickerProviderStateMixin {
  int? _selectedBar;
  int? _selectedSeries; // Track the selected series index
  Timer? _autoCloseTimer;
  bool _isInteracting = false;
  late AnimationController _animationController;
  late Animation<double> _animation;
  List<List<num?>>? _previousYValues; // Store previous y-values for animation

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    _animationController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    // Store initial y-values
    _previousYValues = widget.series.map((s) => s.data.map((e) => widget.yValueMapper(e)).toList()).toList();
    _animationController.forward(from: 1.0); // Start at full height
  }

  @override
  void didUpdateWidget(MoCustomMultiSeriesBarChart<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach();
      widget.controller?._attach(this);
    }
    // Check if series data has changed
    bool seriesChanged = oldWidget.series.length != widget.series.length ||
        oldWidget.series.asMap().entries.any((entry) {
          int i = entry.key;
          var oldSeries = entry.value;
          if (i >= widget.series.length) return true;
          var newSeries = widget.series[i];
          if (oldSeries.data.length != newSeries.data.length) return true;
          return oldSeries.data.asMap().entries.any((e) {
            int j = e.key;
            var oldData = e.value;
            if (j >= newSeries.data.length) return true;
            var newData = newSeries.data[j];
            return widget.yValueMapper(oldData) != widget.yValueMapper(newData) ||
                widget.xValueMapper(oldData) != widget.xValueMapper(newData);
          });
        });

    if (seriesChanged) {
      // Store current y-values as previous for animation
      _previousYValues = oldWidget.series.map((s) => s.data.map((e) => widget.yValueMapper(e)).toList()).toList();
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _autoCloseTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  bool _showTooltipAtIndex(int index) {
    if (index < 0 || widget.series.isEmpty || index >= widget.series[0].data.length) {
      return false;
    }

    setState(() {
      _selectedBar = index;
      _selectedSeries = 0; // Default to first series
    });

    widget.onSelectionChanged?.call(_selectedBar);
    return true;
  }

  void _hideTooltip() {
    setState(() {
      _selectedBar = null;
      _selectedSeries = null;
    });

    widget.onSelectionChanged?.call(_selectedBar);
  }

  double _calculateLeftMargin() {
    if (widget.series.isEmpty || widget.series[0].data.isEmpty) return 40.0;

    // Calculate y-axis range across all series
    num dataMaxY = double.negativeInfinity;
    num dataMinY = double.infinity;

    for (var series in widget.series) {
      for (var entry in series.data) {
        final yValue = widget.yValueMapper(entry) ?? 0;
        dataMaxY = dataMaxY > yValue ? dataMaxY : yValue;
        dataMinY = dataMinY < yValue ? dataMinY : yValue;
      }
    }

    final maxY = widget.maxY ?? (dataMaxY < 0 ? 0 : dataMaxY);
    final minY = widget.minY ?? (dataMinY > 0 ? 0 : dataMinY);
    final includeZero = minY <= 0 && maxY >= 0;

    List<num> yLabels = [];
    final num effectiveMaxY = maxY;
    final num effectiveMinY = minY;
    final step = (effectiveMaxY - effectiveMinY) / 4;

    for (int i = 0; i <= 4; i++) {
      final label = effectiveMinY + (step * i);
      yLabels.add(label);
    }
    if (includeZero && !yLabels.contains(0)) {
      yLabels.add(0);
    }
    yLabels.sort();

    final double yRange = ((effectiveMaxY - effectiveMinY).abs() == 0 ? 1 : (effectiveMaxY - effectiveMinY).abs()).toDouble();
    final double boundaryThreshold = yRange * 0.05;

    yLabels = yLabels.where((label) {
      if (label == effectiveMinY || label == effectiveMaxY || label == 0) return true;
      if ((label - effectiveMinY).abs() < boundaryThreshold && label != effectiveMinY) return false;
      if ((label - effectiveMaxY).abs() < boundaryThreshold && label != effectiveMaxY) return false;
      return true;
    }).toList();

    double maxLabelWidth = 0;

    for (final yValue in yLabels) {
      TextSpan textSpan;
      if (widget.yAxisLabelStyleFormatter != null) {
        textSpan = widget.yAxisLabelStyleFormatter!(yValue);
      } else {
        textSpan = TextSpan(
          text: yValue.toStringAsFixed(0),
          style: TextStyle(
            color: Color(0xFF909094),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        );
      }

      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.right,
        textDirection: TextDirection.ltr,
      )..layout();

      maxLabelWidth = maxLabelWidth < textPainter.width ? textPainter.width : maxLabelWidth;
    }

    return maxLabelWidth + 4.0;
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: <Type, GestureRecognizerFactory>{
        _CustomPanGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<_CustomPanGestureRecognizer>(
              () => _CustomPanGestureRecognizer(
                onPointerDown: (offset) {
                  _isInteracting = true;
                  _updateSelection(offset, context, isTap: true);
                },
                onPointerMove: (offset) {
                  if (_isInteracting) {
                    _updateSelection(offset, context, isTap: false);
                  }
                },
                onPointerUp: () {
                  _isInteracting = false;
                },
              ),
              (_CustomPanGestureRecognizer instance) {},
            ),
      },
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return CustomPaint(
            size: Size.infinite,
            painter: BarChartPainter<T>(
              series: widget.series,
              selectedBar: _selectedBar,
              selectedSeries: _selectedSeries,
              xValueMapper: widget.xValueMapper,
              yValueMapper: widget.yValueMapper,
              xAxisLabelStyleFormatter: widget.xAxisLabelStyleFormatter,
              yAxisLabelStyleFormatter: widget.yAxisLabelStyleFormatter,
              tooltipDataFormatter: widget.tooltipDataFormatter,
              leftMargin: _calculateLeftMargin(),
              barWidth: widget.barWidth,
              seriesSpacing: widget.seriesSpacing,
              maxXLabels: widget.maxXLabels,
              minY: widget.minY,
              maxY: widget.maxY,
              tooltipStyle: widget.tooltipStyle ?? const TooltipStyle(),
              lineStyle: widget.lineStyle ?? const LineStyle(),
              animationValue: _animation.value,
              previousYValues: _previousYValues,
            ),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.transparent,
            ),
          );
        },
      ),
    );
  }

  void _updateSelection(
    Offset globalPosition,
    BuildContext context, {
    required bool isTap,
  }) {
    if (isTap) {
      _autoCloseTimer?.cancel();
    }

    RenderBox box = context.findRenderObject() as RenderBox;
    final local = box.globalToLocal(globalPosition);

    final double leftMargin = _calculateLeftMargin();
    const double rightMargin = 10;
    const double topMargin = 30;
    const double bottomMargin = 10;
    final double topBarGap = box.size.height * 0.15;
    final double bottomBarGap = box.size.height * 0.03;
    const double xAxisLabelHeight = 15;
    const double bottomSpacing = 2;
    final double chartWidth = box.size.width - leftMargin - rightMargin;
    final double chartHeight =
        box.size.height - topMargin - bottomMargin - topBarGap - bottomBarGap - xAxisLabelHeight - bottomSpacing;

    final double fixedBarWidth = widget.barWidth ?? 6.0;
    final double seriesSpacing = widget.seriesSpacing ?? 2.0;
    final int maxDataLength = widget.series.isNotEmpty
        ? widget.series.map((s) => s.data.length).reduce((a, b) => a > b ? a : b)
        : 0;
    final double totalBarsWidth = maxDataLength * (fixedBarWidth * widget.series.length + seriesSpacing * (widget.series.length - 1));
    const double barsAreaPadding = 10.0;
    final double adjustedChartWidth = chartWidth - (barsAreaPadding * 2);
    final double adjustedTotalSpacing = adjustedChartWidth - totalBarsWidth;

    final double barSpacing = maxDataLength > 1
        ? adjustedTotalSpacing / (maxDataLength + 1)
        : adjustedTotalSpacing / 2;
    final double adjustedBarWidth = fixedBarWidth;

    // Calculate y-axis range across all series
    num dataMaxY = double.negativeInfinity;
    num dataMinY = double.infinity;
    for (var series in widget.series) {
      for (var entry in series.data) {
        final yValue = widget.yValueMapper(entry) ?? 0;
        dataMaxY = dataMaxY > yValue ? dataMaxY : yValue;
        dataMinY = dataMinY < yValue ? dataMinY : yValue;
      }
    }
    final maxY = widget.maxY ?? (dataMaxY < 0 ? 0 : dataMaxY);
    final minY = widget.minY ?? (dataMinY > 0 ? 0 : dataMinY);
    final yRange = (maxY - minY).abs() == 0 ? 1 : (maxY - minY).abs();
    final double sepY = topMargin + topBarGap + (chartHeight * (maxY - 0) / yRange);

    int? tappedIndex;
    int? tappedSeriesIndex;

    for (int i = 0; i < maxDataLength; i++) {
      for (int s = 0; s < widget.series.length; s++) {
        if (i >= widget.series[s].data.length) continue; // Skip if no data for this index
        final barLeft = leftMargin +
            barsAreaPadding +
            barSpacing +
            (i * (fixedBarWidth * widget.series.length + seriesSpacing * (widget.series.length - 1) + barSpacing)) +
            (s * (fixedBarWidth + seriesSpacing));
        final barRight = barLeft + adjustedBarWidth;
        const tapBuffer = 10.0;
        bool isHit;

        if (isTap) {
          final value = widget.yValueMapper(widget.series[s].data[i]);
          final previousValue = _previousYValues != null && s < _previousYValues!.length && i < _previousYValues![s].length
              ? _previousYValues![s][i]
              : value;
          final interpolatedValue = previousValue != null && value != null
              ? previousValue + (value - previousValue) * _animation.value
              : value;
          double barTop, barBottom;
          if (interpolatedValue == null) {
            const nullBarHeight = 6.0;
            barTop = sepY - nullBarHeight / 2;
            barBottom = sepY + nullBarHeight / 2;
          } else if (interpolatedValue >= 0) {
            barTop = sepY - ((interpolatedValue - 0) / yRange) * chartHeight;
            barBottom = sepY;
          } else {
            barTop = sepY;
            barBottom = sepY + ((0 - interpolatedValue) / yRange) * chartHeight;
          }

          barTop = barTop.clamp(topMargin + topBarGap, topMargin + topBarGap + chartHeight);
          barBottom = barBottom.clamp(topMargin + topBarGap, topMargin + topBarGap + chartHeight);
          if (barBottom < barTop) {
            final tmp = barTop;
            barTop = barBottom;
            barBottom = tmp;
          }
          isHit = local.dx >= barLeft - tapBuffer &&
              local.dx <= barRight + tapBuffer &&
              local.dy >= barTop - tapBuffer &&
              local.dy <= barBottom + tapBuffer;
        } else {
          isHit = local.dx >= barLeft - tapBuffer &&
              local.dx <= barRight + tapBuffer &&
              local.dy >= topMargin + topBarGap &&
              local.dy <= topMargin + topBarGap + chartHeight;
        }

        if (isHit) {
          tappedIndex = i;
          tappedSeriesIndex = s;
          break;
        }
      }
      if (tappedIndex != null) break;
    }

    if (!isTap && (_selectedBar != tappedIndex || _selectedSeries != tappedSeriesIndex)) {
      setState(() {
        _selectedBar = tappedIndex;
        _selectedSeries = tappedSeriesIndex;
      });
      widget.onSelectionChanged?.call(tappedIndex);

      _autoCloseTimer?.cancel();
      if (tappedIndex != null) {
        _autoCloseTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _selectedBar = null;
              _selectedSeries = null;
              widget.onSelectionChanged?.call(null);
            });
          }
        });
      }
    } else if (isTap) {
      setState(() {
        _selectedBar = tappedIndex;
        _selectedSeries = tappedSeriesIndex;

        widget.onSelectionChanged?.call(tappedIndex);

        if (tappedIndex != null && tappedSeriesIndex != null) {
          widget.onBarTap?.call(widget.series[tappedSeriesIndex].data[tappedIndex], tappedSeriesIndex);
        }

        if (tappedIndex != null) {
          _autoCloseTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _selectedBar = null;
                _selectedSeries = null;
                widget.onSelectionChanged?.call(null);
              });
            }
          });
        }

        if (tappedIndex == null && _selectedBar != null) {
          _selectedBar = null;
          _selectedSeries = null;
          widget.onSelectionChanged?.call(null);
          _autoCloseTimer?.cancel();
        }
      });
    }
  }
}

class BarChartPainter<T> extends CustomPainter {
  final List<ChartData<T>> series;
  final int? selectedBar;
  final int? selectedSeries;
  final dynamic Function(T chartDataType) xValueMapper;
  final num? Function(T chartDataType) yValueMapper;
  final TextSpan Function(dynamic xValue)? xAxisLabelStyleFormatter;
  final TextSpan Function(dynamic yValue)? yAxisLabelStyleFormatter;
  final List<TextSpan> Function(T dataItem, int seriesIndex)? tooltipDataFormatter;
  final double leftMargin;
  final double? barWidth;
  final double? seriesSpacing;
  final int? maxXLabels;
  final num? minY;
  final num? maxY;
  final TooltipStyle tooltipStyle;
  final LineStyle lineStyle;
  final double animationValue;
  final List<List<num?>>? previousYValues;

  BarChartPainter({
    required this.series,
    this.selectedBar,
    this.selectedSeries,
    required this.xValueMapper,
    required this.yValueMapper,
    this.xAxisLabelStyleFormatter,
    this.yAxisLabelStyleFormatter,
    this.tooltipDataFormatter,
    required this.leftMargin,
    this.barWidth,
    this.seriesSpacing,
    this.maxXLabels,
    this.minY,
    this.maxY,
    required this.tooltipStyle,
    required this.lineStyle,
    required this.animationValue,
    this.previousYValues,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double rightMargin = 10;
    const double topMargin = 30;
    const double bottomMargin = 10;
    final double topBarGap = size.height * 0.15;
    final double bottomBarGap = size.height * 0.03;
    const double xAxisLabelHeight = 15;
    const double bottomSpacing = 2;
    final double chartHeight =
        size.height - topMargin - bottomMargin - topBarGap - bottomBarGap - xAxisLabelHeight - bottomSpacing;
    double chartWidth = size.width - leftMargin - rightMargin;

    final double fixedBarWidth = barWidth ?? 6.0;
    final double seriesSpacing = this.seriesSpacing ?? 2.0;
    final int maxDataLength = series.isNotEmpty
        ? series.map((s) => s.data.length).reduce((a, b) => a > b ? a : b)
        : 0;
    final double totalBarsWidth = maxDataLength * (fixedBarWidth * series.length + seriesSpacing * (series.length - 1));
    const double barsAreaPadding = 10.0;
    final double adjustedChartWidth = chartWidth - (barsAreaPadding * 2);
    final double adjustedTotalSpacing = adjustedChartWidth - totalBarsWidth;

    final double barSpacing = maxDataLength > 1
        ? adjustedTotalSpacing / (maxDataLength + 1)
        : adjustedTotalSpacing / 2;
    final double adjustedBarWidth = fixedBarWidth;

    // Calculate y-axis range across all series
    num dataMaxY = double.negativeInfinity;
    num dataMinY = double.infinity;
    for (var series in this.series) {
      for (var entry in series.data) {
        final yValue = yValueMapper(entry) ?? 0;
        dataMaxY = dataMaxY > yValue ? dataMaxY : yValue;
        dataMinY = dataMinY < yValue ? dataMinY : yValue;
      }
    }
    final chartMaxY = maxY ?? (dataMaxY < 0 ? 0 : dataMaxY);
    final chartMinY = minY ?? (dataMinY > 0 ? 0 : dataMinY);
    final yRange = (chartMaxY - chartMinY).abs() == 0 ? 1 : (chartMaxY - chartMinY).abs();

    // Draw y-axis labels
    final textStyle = TextStyle(
      color: Color(0xFF909094),
      fontSize: 10,
      fontWeight: FontWeight.bold,
    );

    List<num> yLabels = [];
    final includeZero = chartMinY <= 0 && chartMaxY >= 0;
    final num effectiveMaxY = chartMaxY;
    final num effectiveMinY = chartMinY;
    final step = (effectiveMaxY - effectiveMinY) / 4;

    for (int i = 0; i <= 4; i++) {
      final label = effectiveMinY + (step * i);
      yLabels.add(label);
    }
    if (includeZero && !yLabels.contains(0)) {
      yLabels.add(0);
    }
    yLabels.sort();

    final double boundaryThreshold = yRange * 0.05;
    yLabels = yLabels.where((label) {
      if (label == effectiveMinY || label == effectiveMaxY || label == 0) return true;
      if ((label - effectiveMinY).abs() < boundaryThreshold && label != effectiveMinY) return false;
      if ((label - effectiveMaxY).abs() < boundaryThreshold && label != effectiveMaxY) return false;
      return true;
    }).toList();

    final double sepY = topMargin + topBarGap + (chartHeight * (chartMaxY - 0) / yRange);

    for (final yValue in yLabels) {
      final yPos = topMargin + topBarGap + (chartHeight * (chartMaxY - yValue) / yRange);
      if (yPos >= topMargin + topBarGap && yPos <= topMargin + topBarGap + chartHeight) {
        TextSpan textSpan;
        if (yAxisLabelStyleFormatter != null) {
          textSpan = yAxisLabelStyleFormatter!(yValue);
        } else {
          textSpan = TextSpan(
            text: yValue.toStringAsFixed(0),
            style: textStyle,
          );
        }

        final textPainter = TextPainter(
          text: textSpan,
          textAlign: TextAlign.right,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: leftMargin - 2);
        textPainter.paint(
          canvas,
          Offset(1, yPos - textPainter.height / 2),
        );
      }
    }

    // Draw x-axis labels
    if (series.isNotEmpty && maxDataLength > 0) {
      final sampleXValue = xValueMapper(series[0].data[0]);
      final sampleLabelText = '$sampleXValue';
      final estimatedLabelWidth = sampleLabelText.length * 7.0 + 16;
      final maxLabelsToFit = (adjustedChartWidth / estimatedLabelWidth).floor();
      final effectiveMaxLabels = maxXLabels != null ? maxXLabels!.clamp(1, maxDataLength) : maxLabelsToFit.clamp(1, maxDataLength);
      final stepSize = (maxDataLength / effectiveMaxLabels).ceil().clamp(1, maxDataLength);

      for (int i = 0; i < maxDataLength; i += stepSize) {
        final xPos = leftMargin +
            barsAreaPadding +
            barSpacing +
            (i * (fixedBarWidth * series.length + seriesSpacing * (series.length - 1) + barSpacing)) +
            ((fixedBarWidth * series.length + seriesSpacing * (series.length - 1)) / 2);
        final xValue = xValueMapper(series[0].data[i]);

        TextSpan textSpan;
        if (xAxisLabelStyleFormatter != null) {
          textSpan = xAxisLabelStyleFormatter!(xValue);
        } else {
          textSpan = TextSpan(
            text: '$xValue',
            style: TextStyle(
              color: Color(0xFF909094),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          );
        }

        final xAxisLabelWidth = textSpan.toPlainText().length * 7.0;
        final textPainter = TextPainter(
          text: textSpan,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: adjustedBarWidth * series.length + xAxisLabelWidth + seriesSpacing * (series.length - 1));
        textPainter.paint(
          canvas,
          Offset(
            xPos - textPainter.width / 2,
            topMargin + topBarGap + chartHeight + bottomSpacing + 4,
          ),
        );
      }
    }

    // Draw X-axis line
    final axisPaint = Paint()
      ..color = tooltipStyle.borderColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(leftMargin + barsAreaPadding, sepY),
      Offset(leftMargin + chartWidth - barsAreaPadding, sepY),
      axisPaint,
    );

    // Draw bars for each series with animation
    for (int i = 0; i < maxDataLength; i++) {
      for (int s = 0; s < series.length; s++) {
        if (i >= series[s].data.length) continue;
        final value = yValueMapper(series[s].data[i]);
        final previousValue = previousYValues != null && s < previousYValues!.length && i < previousYValues![s].length
            ? previousYValues![s][i]
            : value;
        final interpolatedValue = previousValue != null && value != null
            ? previousValue + (value - previousValue) * animationValue
            : value;
        final barLeft = leftMargin +
            barsAreaPadding +
            barSpacing +
            (i * (fixedBarWidth * series.length + seriesSpacing * (series.length - 1) + barSpacing)) +
            (s * (fixedBarWidth + seriesSpacing));
        final barRight = barLeft + adjustedBarWidth;
        double barTop, barBottom;
        if (interpolatedValue == null) {
          const nullBarHeight = 6.0;
          barTop = sepY - nullBarHeight / 2;
          barBottom = sepY + nullBarHeight / 2;
        } else if (interpolatedValue >= 0) {
          barTop = sepY - ((interpolatedValue - 0) / yRange) * chartHeight;
          barBottom = sepY;
        } else {
          barTop = sepY;
          barBottom = sepY + ((0 - interpolatedValue) / yRange) * chartHeight;
        }

        barTop = barTop.clamp(topMargin + topBarGap, topMargin + topBarGap + chartHeight);
        barBottom = barBottom.clamp(topMargin + topBarGap, topMargin + topBarGap + chartHeight);
        if (barBottom < barTop) {
          final tmp = barTop;
          barTop = barBottom;
          barBottom = tmp;
        }
        final barRect = Rect.fromLTRB(barLeft, barTop, barRight, barBottom);
        final barPaint = Paint()
          ..color = interpolatedValue == null ? tooltipStyle.borderColor : series[s].barColorMapper(interpolatedValue);
        final r = Radius.circular(6);
        final borderRadius = interpolatedValue == null
            ? BorderRadius.all(Radius.circular(0))
            : interpolatedValue >= 0
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
    }

    // Draw dotted vertical line and tooltip for selected bar
    if (selectedBar != null && selectedSeries != null && selectedBar! < series[selectedSeries!].data.length) {
      final i = selectedBar!;
      final s = selectedSeries!;
      final barLeft = leftMargin +
          barsAreaPadding +
          barSpacing +
          (i * (fixedBarWidth * series.length + seriesSpacing * (series.length - 1) + barSpacing)) +
          (s * (fixedBarWidth + seriesSpacing));
      final barRight = barLeft + adjustedBarWidth;
      final barCenter = barLeft + (barRight - barLeft) / 2;

      final linePaint = Paint()
        ..color = lineStyle.color
        ..strokeWidth = lineStyle.strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final dataItem = series[s].data[i];
      List<TextSpan> tooltipSpans;
      if (tooltipDataFormatter != null) {
        tooltipSpans = tooltipDataFormatter!(dataItem, s);
      } else {
        tooltipSpans = _getDefaultTooltipSpans(dataItem, xValueMapper, yValueMapper, series[s].seriesName, s);
      }

      final combinedTextSpan = TextSpan(children: tooltipSpans);
      final textPainter = TextPainter(
        text: combinedTextSpan,
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 200.0);
      final actualTooltipHeight = textPainter.height + 8;
      final contentWidth = textPainter.width + 16;
      final actualTooltipWidth = contentWidth < 100.0 ? 100.0 : contentWidth.clamp(100.0, 200.0);

      final selectedBarValue = yValueMapper(dataItem);
      final previousSelectedValue = previousYValues != null && s < previousYValues!.length && i < previousYValues![s].length
          ? previousYValues![s][i]
          : selectedBarValue;
      final interpolatedSelectedValue = previousSelectedValue != null && selectedBarValue != null
          ? previousSelectedValue + (selectedBarValue - previousSelectedValue) * animationValue
          : selectedBarValue;
      double lineStartY;
      double lineEndY;
      double tooltipY = topMargin - 4 - 20.0;

      if (interpolatedSelectedValue != null && interpolatedSelectedValue >= 0) {
        lineStartY = tooltipY + actualTooltipHeight + 10;
        lineEndY = sepY;
      } else if (interpolatedSelectedValue != null && interpolatedSelectedValue < 0) {
        lineStartY = tooltipY + actualTooltipHeight + 10;
        double negativeBarBottom = sepY + ((0 - interpolatedSelectedValue) / yRange) * chartHeight;
        negativeBarBottom = negativeBarBottom.clamp(topMargin + topBarGap, topMargin + topBarGap + chartHeight);
        lineEndY = negativeBarBottom;
      } else {
        lineStartY = tooltipY + actualTooltipHeight + 10;
        lineEndY = sepY;
      }

      tooltipY = tooltipY.clamp(8.0, double.infinity);
      final tooltipWidth = actualTooltipWidth;
      final tooltipHeight = actualTooltipHeight;

      double tooltipX = barCenter - tooltipWidth * 0.25;
      tooltipX = tooltipX.clamp(leftMargin, leftMargin + chartWidth - tooltipWidth);

      final actualArrowXOffset = (barCenter - tooltipX).clamp(15.0, tooltipWidth - 15.0);
      final arrowXPosition = barCenter;

      final dashHeight = lineStyle.dashHeight;
      final dashSpace = lineStyle.dashSpace;
      double currentY = lineStartY;

      while (currentY < lineEndY) {
        final remainingHeight = lineEndY - currentY;
        final actualDashHeight = remainingHeight < dashHeight ? remainingHeight : dashHeight;
        canvas.drawLine(
          Offset(arrowXPosition, currentY),
          Offset(arrowXPosition, currentY + actualDashHeight),
          linePaint,
        );
        currentY += dashHeight + dashSpace;
      }

      final tooltipWithArrowPath = Path();
      tooltipWithArrowPath.moveTo(tooltipX + tooltipStyle.borderRadius, tooltipY);
      tooltipWithArrowPath.lineTo(tooltipX + tooltipWidth - tooltipStyle.borderRadius, tooltipY);
      tooltipWithArrowPath.arcToPoint(
        Offset(tooltipX + tooltipWidth, tooltipY + tooltipStyle.borderRadius),
        radius: Radius.circular(tooltipStyle.borderRadius),
        clockwise: true,
      );
      tooltipWithArrowPath.lineTo(tooltipX + tooltipWidth, tooltipY + tooltipHeight - tooltipStyle.borderRadius);
      tooltipWithArrowPath.arcToPoint(
        Offset(tooltipX + tooltipWidth - tooltipStyle.borderRadius, tooltipY + tooltipHeight),
        radius: Radius.circular(tooltipStyle.borderRadius),
        clockwise: true,
      );
      tooltipWithArrowPath.lineTo(tooltipX + actualArrowXOffset + 10, tooltipY + tooltipHeight);
      tooltipWithArrowPath.lineTo(tooltipX + actualArrowXOffset, tooltipY + tooltipHeight + 10);
      tooltipWithArrowPath.lineTo(tooltipX + actualArrowXOffset - 10, tooltipY + tooltipHeight);
      tooltipWithArrowPath.lineTo(tooltipX + tooltipStyle.borderRadius, tooltipY + tooltipHeight);
      tooltipWithArrowPath.arcToPoint(
        Offset(tooltipX, tooltipY + tooltipHeight - tooltipStyle.borderRadius),
        radius: Radius.circular(tooltipStyle.borderRadius),
        clockwise: true,
      );
      tooltipWithArrowPath.lineTo(tooltipX, tooltipY + tooltipStyle.borderRadius);
      tooltipWithArrowPath.arcToPoint(
        Offset(tooltipX + tooltipStyle.borderRadius, tooltipY),
        radius: Radius.circular(tooltipStyle.borderRadius),
        clockwise: true,
      );
      tooltipWithArrowPath.close();

      canvas.drawShadow(
        tooltipWithArrowPath,
        tooltipStyle.shadowColor.withOpacity(tooltipStyle.shadowOpacity),
        tooltipStyle.shadowBlurRadius,
        true,
      );

      final tooltipPaint = Paint()
        ..color = tooltipStyle.backgroundColor
        ..style = PaintingStyle.fill;
      canvas.drawPath(tooltipWithArrowPath, tooltipPaint);

      final tooltipBorderPaint = Paint()
        ..color = tooltipStyle.borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = tooltipStyle.borderWidth;
      canvas.drawPath(tooltipWithArrowPath, tooltipBorderPaint);

      textPainter.paint(
        canvas,
        Offset(tooltipX + 8, tooltipY + 4),
      );

      if (interpolatedSelectedValue != null) {
        final selectedBarLeft = leftMargin +
            barsAreaPadding +
            barSpacing +
            (i * (fixedBarWidth * series.length + seriesSpacing * (series.length - 1) + barSpacing)) +
            (s * (fixedBarWidth + seriesSpacing));
        final selectedBarRight = selectedBarLeft + adjustedBarWidth;
        final selectedBarCenter = selectedBarLeft + (selectedBarRight - selectedBarLeft) / 2;
        double selectedBarTop, selectedBarBottom;
        if (interpolatedSelectedValue >= 0) {
          selectedBarTop = sepY - ((interpolatedSelectedValue - 0) / yRange) * chartHeight;
          selectedBarBottom = sepY;
        } else {
          selectedBarTop = sepY;
          selectedBarBottom = sepY + ((0 - interpolatedSelectedValue) / yRange) * chartHeight;
        }

        selectedBarTop = selectedBarTop.clamp(topMargin + topBarGap, topMargin + topBarGap + chartHeight);
        selectedBarBottom = selectedBarBottom.clamp(topMargin + topBarGap, topMargin + topBarGap + chartHeight);
        if (selectedBarBottom < selectedBarTop) {
          final tmp = selectedBarTop;
          selectedBarTop = selectedBarBottom;
          selectedBarBottom = tmp;
        }

        final dotY = interpolatedSelectedValue >= 0 ? selectedBarTop : selectedBarBottom;
        final dotCenter = Offset(selectedBarCenter, dotY);

        final barColor = series[s].barColorMapper(interpolatedSelectedValue);
        final shadowPaint = Paint()
          ..color = barColor.withOpacity(0.25)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(dotCenter, 6.0, shadowPaint);

        final dotPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(dotCenter, 2.0, dotPaint);

        final borderPaint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.4;
        canvas.drawCircle(dotCenter, 2.0, borderPaint);
      }
    }
  }

  List<TextSpan> _getDefaultTooltipSpans(
    T dataItem,
    dynamic Function(T) xValueMapper,
    num? Function(T) yValueMapper,
    String? seriesName,
    int seriesIndex,
  ) {
    final xValue = xValueMapper(dataItem);
    final yValue = yValueMapper(dataItem);
    final xLabelText = 'Day $xValue';
    final yLabelText = yValue == null ? 'No Data' : '$yValue';
    final seriesLabel = seriesName ?? 'Series ${seriesIndex + 1}';

    return [
      TextSpan(
        text: seriesLabel,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      const TextSpan(text: '\n', style: TextStyle(fontSize: 14)),
      TextSpan(
        text: xLabelText,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      const TextSpan(text: '\n', style: TextStyle(fontSize: 14)),
      TextSpan(
        text: yLabelText,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.normal,
          fontSize: 14,
        ),
      ),
    ];
  }

  @override
  bool shouldRepaint(covariant BarChartPainter<T> oldDelegate) {
    final bool seriesChanged = oldDelegate.series != series;
    final bool selectionChanged = oldDelegate.selectedBar != selectedBar || oldDelegate.selectedSeries != selectedSeries;
    final bool mappersChanged = oldDelegate.xValueMapper != xValueMapper || oldDelegate.yValueMapper != yValueMapper;
    final bool formattersChanged =
        oldDelegate.xAxisLabelStyleFormatter != xAxisLabelStyleFormatter ||
        oldDelegate.yAxisLabelStyleFormatter != yAxisLabelStyleFormatter ||
        oldDelegate.tooltipDataFormatter != tooltipDataFormatter;
    final bool layoutChanged =
        oldDelegate.leftMargin != leftMargin ||
        oldDelegate.barWidth != barWidth ||
        oldDelegate.seriesSpacing != seriesSpacing ||
        oldDelegate.maxXLabels != maxXLabels ||
        oldDelegate.minY != minY ||
        oldDelegate.maxY != maxY;
    final bool stylesChanged = oldDelegate.tooltipStyle != tooltipStyle || oldDelegate.lineStyle != lineStyle;
    final bool animationChanged = oldDelegate.animationValue != animationValue;

    return seriesChanged || selectionChanged || mappersChanged || formattersChanged || layoutChanged || stylesChanged || animationChanged;
  }
}