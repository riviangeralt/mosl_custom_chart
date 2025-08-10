import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

/// Controller for MoCustomAreaChart to programmatically control chart interactions
class MoCustomAreaChartController {
  _MoCustomAreaChartState? _state;

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

  /// Get the currently selected point index, returns null if no point is selected
  int? get selectedIndex => _state?._selectedPoint;

  void _attach(_MoCustomAreaChartState state) {
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

/// Style configuration for area and line appearance
class AreaStyle {
  final Color fillColor;
  final Color lineColor;
  final double strokeWidth;
  final double dashHeight;
  final double dashSpace;
  final double pointRadius;

  const AreaStyle({
    this.fillColor = const Color(0x8013861D), // Semi-transparent green
    this.lineColor = const Color(0xFF13861D),
    this.strokeWidth = 2.0,
    this.dashHeight = 5.0,
    this.dashSpace = 5.0,
    this.pointRadius = 3.0,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AreaStyle &&
        other.fillColor == fillColor &&
        other.lineColor == lineColor &&
        other.strokeWidth == strokeWidth &&
        other.dashHeight == dashHeight &&
        other.dashSpace == dashSpace &&
        other.pointRadius == pointRadius;
  }

  @override
  int get hashCode {
    return fillColor.hashCode ^
        lineColor.hashCode ^
        strokeWidth.hashCode ^
        dashHeight.hashCode ^
        dashSpace.hashCode ^
        pointRadius.hashCode;
  }
}

class MoCustomAreaChart<T> extends StatefulWidget {
  final List<T> data;
  final dynamic Function(T chartDataType) xValueMapper;
  final num? Function(T chartDataType) yValueMapper;
  final Function(int? selectedIndex)? onSelectionChanged;
  final Function(T dataItem)? onPointTap;
  final TextSpan Function(dynamic xValue)? xAxisLabelStyleFormatter;
  final TextSpan Function(dynamic yValue)? yAxisLabelStyleFormatter;
  final List<TextSpan> Function(T dataItem)? tooltipDataFormatter;
  final double? pointSpacing;
  final int? maxXLabels;
  final MoCustomAreaChartController? controller;
  final num? minY;
  final num? maxY;
  final TooltipStyle? tooltipStyle;
  final AreaStyle? areaStyle;

  const MoCustomAreaChart({
    super.key,
    required this.data,
    required this.xValueMapper,
    required this.yValueMapper,
    this.onSelectionChanged,
    this.onPointTap,
    this.xAxisLabelStyleFormatter,
    this.yAxisLabelStyleFormatter,
    this.tooltipDataFormatter,
    this.pointSpacing,
    this.maxXLabels,
    this.controller,
    this.minY,
    this.maxY,
    this.tooltipStyle,
    this.areaStyle,
  });

  @override
  State<MoCustomAreaChart<T>> createState() => _MoCustomAreaChartState<T>();
}

class _MoCustomAreaChartState<T> extends State<MoCustomAreaChart<T>> {
  int? _selectedPoint;
  Timer? _autoCloseTimer;
  bool _isInteracting = false;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(MoCustomAreaChart<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach();
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  bool _showTooltipAtIndex(int index) {
    if (index < 0 || index >= widget.data.length) {
      return false;
    }

    setState(() {
      _selectedPoint = index;
    });

    widget.onSelectionChanged?.call(_selectedPoint);
    return true;
  }

  void _hideTooltip() {
    setState(() {
      _selectedPoint = null;
    });

    widget.onSelectionChanged?.call(_selectedPoint);
  }

  double _calculateLeftMargin() {
    if (widget.data.isEmpty) return 40.0;

    final dataMaxY = widget.data
        .map((entry) => widget.yValueMapper(entry) ?? 0)
        .reduce((a, b) => a > b ? a : b);
    final dataMinY = widget.data
        .map((entry) => widget.yValueMapper(entry) ?? 0)
        .reduce((a, b) => a < b ? a : b);

    final maxY = widget.maxY ?? dataMaxY;
    final minY = widget.minY ?? dataMinY;

    List<num> yLabels = [];
    final includeZero = minY <= 0 && maxY >= 0;

    if (minY >= 0) {
      final step = (maxY - minY) / 4;
      for (int i = 0; i < 5; i++) {
        yLabels.add(minY + (step * i));
      }
    } else if (maxY <= 0) {
      final step = (maxY - minY) / 4;
      for (int i = 0; i < 5; i++) {
        yLabels.add(minY + (step * i));
      }
    } else {
      final positiveRange = maxY;
      final negativeRange = minY.abs();
      final totalRange = positiveRange + negativeRange;
      final positiveLabels = ((positiveRange / totalRange) * 4).round().clamp(1, 3);
      final negativeLabels = 4 - positiveLabels;

      yLabels = [];

      if (negativeLabels > 0) {
        final negativeStep = minY / negativeLabels;
        for (int i = negativeLabels; i >= 1; i--) {
          yLabels.add(negativeStep * i);
        }
      }

      if (includeZero) {
        yLabels.add(0);
      }

      if (positiveLabels > 0) {
        final positiveStep = maxY / positiveLabels;
        for (int i = 1; i <= positiveLabels; i++) {
          yLabels.add(positiveStep * i);
        }
      }
    }

    final double yRange = ((maxY - minY).abs() == 0 ? 1 : (maxY - minY).abs()).toDouble();

    if (minY < 0 && maxY > 0) {
      final positiveLabels = yLabels.where((label) => label > 0).toList()..sort();
      final negativeLabels = yLabels.where((label) => label < 0).toList()..sort((a, b) => b.compareTo(a));

      if (negativeLabels.isNotEmpty && positiveLabels.isNotEmpty) {
        final negativeAbsMax = minY.abs();
        final firstPositiveLabel = positiveLabels.first;

        if (negativeAbsMax < firstPositiveLabel) {
          yLabels = [];
          final step = maxY / 4;
          for (int i = 0; i < 5; i++) {
            yLabels.add(i * step);
          }
        }
      }

      if (positiveLabels.isNotEmpty && negativeLabels.isNotEmpty) {
        final positiveAbsMax = maxY.abs();
        final firstNegativeLabelAbs = negativeLabels.first.abs();

        if (positiveAbsMax < firstNegativeLabelAbs) {
          yLabels = [];
          final step = minY / 4;
          for (int i = 0; i < 5; i++) {
            yLabels.add(i * step);
          }
        }
      }
    }

    final double boundaryThreshold = yRange * 0.05;

    yLabels = yLabels.where((label) {
      if (label == minY || label == maxY) return true;
      if (label == 0 && includeZero) return true;
      if ((label - minY).abs() < boundaryThreshold && label != minY) return false;
      if ((label - maxY).abs() < boundaryThreshold && label != maxY) return false;
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
      child: CustomPaint(
        size: Size.infinite,
        painter: AreaChartPainter<T>(
          data: widget.data,
          selectedPoint: _selectedPoint,
          xValueMapper: widget.xValueMapper,
          yValueMapper: widget.yValueMapper,
          xAxisLabelStyleFormatter: widget.xAxisLabelStyleFormatter,
          yAxisLabelStyleFormatter: widget.yAxisLabelStyleFormatter,
          tooltipDataFormatter: widget.tooltipDataFormatter,
          leftMargin: _calculateLeftMargin(),
          pointSpacing: widget.pointSpacing,
          maxXLabels: widget.maxXLabels,
          minY: widget.minY,
          maxY: widget.maxY,
          tooltipStyle: widget.tooltipStyle ?? const TooltipStyle(),
          areaStyle: widget.areaStyle ?? const AreaStyle(),
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
    if (isTap) {
      _autoCloseTimer?.cancel();
    }

    RenderBox box = context.findRenderObject() as RenderBox;
    final local = box.globalToLocal(globalPosition);

    final double leftMargin = _calculateLeftMargin();
    const double rightMargin = 10;
    const double topMargin = 30;
    const double bottomMargin = 10;
    final double topPointGap = box.size.height * 0.15;
    final double bottomPointGap = box.size.height * 0.03;
    const double xAxisLabelHeight = 15;
    const double bottomSpacing = 2;
    final double chartWidth = box.size.width - leftMargin - rightMargin;
    final double chartHeight = box.size.height - topMargin - bottomMargin - topPointGap - bottomPointGap - xAxisLabelHeight - bottomSpacing;

    final double fixedPointSpacing = widget.pointSpacing ?? (chartWidth / (widget.data.length > 1 ? widget.data.length - 1 : 1));
    const double pointsAreaPadding = 10.0;
    final double adjustedChartWidth = chartWidth - (pointsAreaPadding * 2);

    final maxY = widget.data
        .map((e) => widget.yValueMapper(e) ?? 0)
        .reduce((a, b) => a > b ? a : b);
    final minY = widget.data
        .map((e) => widget.yValueMapper(e) ?? 0)
        .reduce((a, b) => a < b ? a : b);
    final yRange = (maxY - minY).abs() == 0 ? 1 : (maxY - minY).abs();
    final double sepY = topMargin + topPointGap + (chartHeight * (maxY - 0) / yRange);

    int? tappedIndex;
    for (int i = 0; i < widget.data.length; i++) {
      const double pointsAreaPadding = 10.0;
      final pointX = leftMargin + pointsAreaPadding + (i * fixedPointSpacing);
      final value = widget.yValueMapper(widget.data[i]);
      double pointY;
      if (value == null) {
        pointY = sepY;
      } else {
        pointY = sepY - ((value - 0) / yRange) * chartHeight;
      }

      pointY = pointY.clamp(topMargin + topPointGap, topMargin + topPointGap + chartHeight);
      const tapBuffer = 20.0;
      bool isHit;

      if (isTap) {
        isHit = (local.dx - pointX).abs() <= tapBuffer && (local.dy - pointY).abs() <= tapBuffer;
      } else {
        isHit = (local.dx - pointX).abs() <= tapBuffer &&
            local.dy >= topMargin + topPointGap &&
            local.dy <= topMargin + topPointGap + chartHeight;
      }

      if (isHit) {
        tappedIndex = i;
        break;
      }
    }

    if (!isTap && _selectedPoint != tappedIndex) {
      setState(() {
        _selectedPoint = tappedIndex;
      });
      widget.onSelectionChanged?.call(tappedIndex);

      _autoCloseTimer?.cancel();
      if (tappedIndex != null) {
        _autoCloseTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _selectedPoint = null;
              widget.onSelectionChanged?.call(null);
            });
          }
        });
      }
    } else if (isTap) {
      setState(() {
        _selectedPoint = tappedIndex;
        widget.onSelectionChanged?.call(tappedIndex);

        if (tappedIndex != null) {
          widget.onPointTap?.call(widget.data[tappedIndex]);
        }

        if (tappedIndex != null) {
          _autoCloseTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _selectedPoint = null;
                widget.onSelectionChanged?.call(null);
              });
            }
          });
        }

        if (tappedIndex == null && _selectedPoint != null) {
          _selectedPoint = null;
          widget.onSelectionChanged?.call(null);
          _autoCloseTimer?.cancel();
        }
      });
    }
  }
}

class AreaChartPainter<T> extends CustomPainter {
  final List<T> data;
  final int? selectedPoint;
  final dynamic Function(T chartDataType) xValueMapper;
  final num? Function(T chartDataType) yValueMapper;
  final TextSpan Function(dynamic xValue)? xAxisLabelStyleFormatter;
  final TextSpan Function(dynamic yValue)? yAxisLabelStyleFormatter;
  final List<TextSpan> Function(T dataItem)? tooltipDataFormatter;
  final double leftMargin;
  final double? pointSpacing;
  final int? maxXLabels;
  final num? minY;
  final num? maxY;
  final TooltipStyle tooltipStyle;
  final AreaStyle areaStyle;

  AreaChartPainter({
    required this.data,
    this.selectedPoint,
    required this.xValueMapper,
    required this.yValueMapper,
    this.xAxisLabelStyleFormatter,
    this.yAxisLabelStyleFormatter,
    this.tooltipDataFormatter,
    required this.leftMargin,
    this.pointSpacing,
    this.maxXLabels,
    this.minY,
    this.maxY,
    required this.tooltipStyle,
    required this.areaStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double rightMargin = 10;
    const double topMargin = 30;
    const double bottomMargin = 10;
    final double topPointGap = size.height * 0.15;
    final double bottomPointGap = size.height * 0.03;
    const double xAxisLabelHeight = 15;
    const double bottomSpacing = 2;
    final double chartHeight = size.height - topMargin - bottomMargin - topPointGap - bottomPointGap - xAxisLabelHeight - bottomSpacing;
    final double chartWidth = size.width - leftMargin - rightMargin;

    final double fixedPointSpacing = pointSpacing ?? (chartWidth / (data.length > 1 ? data.length - 1 : 1));
    const double pointsAreaPadding = 10.0;
    final double adjustedChartWidth = chartWidth - (pointsAreaPadding * 2);

    final dataMaxY = data.isEmpty ? 0 : data
        .map((entry) => yValueMapper(entry) ?? 0)
        .reduce((a, b) => a > b ? a : b);
    final dataMinY = data.isEmpty ? 0 : data
        .map((entry) => yValueMapper(entry) ?? 0)
        .reduce((a, b) => a < b ? a : b);

    final chartMaxY = maxY ?? dataMaxY;
    final chartMinY = minY ?? dataMinY;
    final yRange = (chartMaxY - chartMinY).abs() == 0 ? 1 : (chartMaxY - chartMinY).abs();

    final textStyle = TextStyle(
      color: Color(0xFF909094),
      fontSize: 10,
      fontWeight: FontWeight.bold,
    );

    List<num> yLabels = [];
    final includeZero = chartMinY <= 0 && chartMaxY >= 0;

    if (chartMinY >= 0) {
      final step = (chartMaxY - chartMinY) / 4;
      for (int i = 0; i < 5; i++) {
        yLabels.add(chartMinY + (step * i));
      }
    } else if (chartMaxY <= 0) {
      final step = (chartMaxY - chartMinY) / 4;
      for (int i = 0; i < 5; i++) {
        yLabels.add(chartMinY + (step * i));
      }
    } else {
      final positiveRange = chartMaxY;
      final negativeRange = chartMinY.abs();
      final totalRange = positiveRange + negativeRange;
      final positiveLabels = ((positiveRange / totalRange) * 4).round().clamp(1, 3);
      final negativeLabels = 4 - positiveLabels;

      yLabels = [];

      if (negativeLabels > 0) {
        final negativeStep = chartMinY / negativeLabels;
        for (int i = negativeLabels; i >= 1; i--) {
          yLabels.add(negativeStep * i);
        }
      }

      if (includeZero) {
        yLabels.add(0);
      }

      if (positiveLabels > 0) {
        final positiveStep = chartMaxY / positiveLabels;
        for (int i = 1; i <= positiveLabels; i++) {
          yLabels.add(positiveStep * i);
        }
      }
    }

    final double boundaryThreshold = yRange * 0.05;

    if (chartMinY < 0 && chartMaxY > 0) {
      final positiveLabels = yLabels.where((label) => label > 0).toList()..sort();
      final negativeLabels = yLabels.where((label) => label < 0).toList()..sort((a, b) => b.compareTo(a));

      if (negativeLabels.isNotEmpty && positiveLabels.isNotEmpty) {
        final negativeAbsMax = chartMinY.abs();
        final firstPositiveLabel = positiveLabels.first;

        if (negativeAbsMax < firstPositiveLabel) {
          yLabels = [];
          final step = chartMaxY / 4;
          for (int i = 0; i < 5; i++) {
            yLabels.add(i * step);
          }
        }
      }

      if (positiveLabels.isNotEmpty && negativeLabels.isNotEmpty) {
        final positiveAbsMax = chartMaxY.abs();
        final firstNegativeLabelAbs = negativeLabels.first.abs();

        if (positiveAbsMax < firstNegativeLabelAbs) {
          yLabels = [];
          final step = chartMinY / 4;
          for (int i = 0; i < 5; i++) {
            yLabels.add(i * step);
          }
        }
      }
    }

    yLabels = yLabels.where((label) {
      if (label == chartMinY || label == chartMaxY) return true;
      if (label == 0 && includeZero) return true;
      if ((label - chartMinY).abs() < boundaryThreshold && label != chartMinY) return false;
      if ((label - chartMaxY).abs() < boundaryThreshold && label != chartMaxY) return false;
      return true;
    }).toList();

    final double sepY = topMargin + topPointGap + (chartHeight * (chartMaxY - 0) / yRange);

    for (final yValue in yLabels) {
      final yPos = topMargin + topPointGap + (chartHeight * (chartMaxY - yValue) / yRange);

      if (yPos >= topMargin + topPointGap && yPos <= topMargin + topPointGap + chartHeight) {
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

    if (data.isNotEmpty) {
      final sampleXValue = xValueMapper(data[0]);
      final sampleLabelText = '$sampleXValue';
      final estimatedLabelWidth = sampleLabelText.length * 7.0 + 16;
      final maxLabelsToFit = (adjustedChartWidth / estimatedLabelWidth).floor();
      final totalDataPoints = data.length;
      final effectiveMaxLabels = maxXLabels != null ? maxXLabels!.clamp(1, totalDataPoints) : maxLabelsToFit.clamp(1, totalDataPoints);
      final stepSize = (totalDataPoints / effectiveMaxLabels).ceil().clamp(1, totalDataPoints);

      for (int i = 0; i < data.length; i += stepSize) {
        final xPos = leftMargin + pointsAreaPadding + (i * fixedPointSpacing);
        final xValue = xValueMapper(data[i]);

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
        )..layout(maxWidth: xAxisLabelWidth);
        textPainter.paint(
          canvas,
          Offset(xPos - textPainter.width / 2, topMargin + topPointGap + chartHeight + bottomSpacing + 4),
        );
      }
    }

    final axisPaint = Paint()
      ..color = tooltipStyle.borderColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(leftMargin + pointsAreaPadding, sepY),
      Offset(leftMargin + chartWidth - pointsAreaPadding, sepY),
      axisPaint,
    );

    final areaPath = Path();
    final linePath = Path();
    bool firstPoint = true;

    for (int i = 0; i < data.length; i++) {
      final value = yValueMapper(data[i]);
      final x = leftMargin + pointsAreaPadding + (i * fixedPointSpacing);
      final y = value == null ? sepY : sepY - ((value - 0) / yRange) * chartHeight;

      final clampedY = y.clamp(topMargin + topPointGap, topMargin + topPointGap + chartHeight);

      if (firstPoint) {
        areaPath.moveTo(x, sepY); // Start at zero line
        areaPath.lineTo(x, clampedY); // Move to first point
        linePath.moveTo(x, clampedY);
        firstPoint = false;
      } else {
        areaPath.lineTo(x, clampedY);
        linePath.lineTo(x, clampedY);
      }

      if (value != null) {
        final pointPaint = Paint()
          ..color = value >= 0 ? areaStyle.lineColor : const Color(0xFFDF130C)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(x, clampedY),
          areaStyle.pointRadius,
          pointPaint,
        );
      }
    }

    // Close the area path by going back to the zero line
    if (data.isNotEmpty) {
      final lastX = leftMargin + pointsAreaPadding + ((data.length - 1) * fixedPointSpacing);
      areaPath.lineTo(lastX, sepY);
      areaPath.close();
    }

    final areaPaint = Paint()
      ..color = areaStyle.fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(areaPath, areaPaint);

    final linePaint = Paint()
      ..color = areaStyle.lineColor
      ..strokeWidth = areaStyle.strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawPath(linePath, linePaint);

    if (selectedPoint != null) {
      final i = selectedPoint!;
      const double pointsAreaPadding = 10.0;
      final pointX = leftMargin + pointsAreaPadding + (i * fixedPointSpacing);
      final value = yValueMapper(data[i]);
      final pointY = value == null ? sepY : sepY - ((value - 0) / yRange) * chartHeight;

      final linePaint = Paint()
        ..color = areaStyle.lineColor
        ..strokeWidth = areaStyle.strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final dataItem = data[i];
      List<TextSpan> tooltipSpans;
      if (tooltipDataFormatter != null) {
        tooltipSpans = tooltipDataFormatter!(dataItem);
      } else {
        tooltipSpans = _getDefaultTooltipSpans(dataItem, xValueMapper, yValueMapper);
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

      final extraSpaceForTooltip = 20.0;
      double tooltipY = topMargin - 4 - extraSpaceForTooltip;
      double lineStartY = tooltipY + actualTooltipHeight + 10;
      double lineEndY;

      if (value != null && value >= 0) {
        lineEndY = pointY.clamp(topMargin + topPointGap, topMargin + topPointGap + chartHeight);
      } else if (value != null && value < 0) {
        lineEndY = pointY.clamp(topMargin + topPointGap, topMargin + topPointGap + chartHeight);
      } else {
        lineEndY = sepY;
      }

      const minTopPadding = 8.0;
      tooltipY = tooltipY.clamp(minTopPadding, double.infinity);

      final tooltipWidth = actualTooltipWidth;
      final tooltipHeight = actualTooltipHeight;
      double tooltipX = pointX - tooltipWidth * 0.25;

      tooltipX = tooltipX.clamp(leftMargin, leftMargin + chartWidth - tooltipWidth);
      final arrowXPosition = pointX;

      final actualArrowXOffset = (pointX - tooltipX).clamp(
        15.0,
        tooltipWidth - 15.0,
      );

      final dashHeight = areaStyle.dashHeight;
      final dashSpace = areaStyle.dashSpace;
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

      if (value != null) {
        final pointCenter = Offset(pointX, pointY.clamp(topMargin + topPointGap, topMargin + topPointGap + chartHeight));
        final pointColor = value >= 0 ? areaStyle.lineColor : const Color(0xFFDF130C);
        final shadowPaint = Paint()
          ..color = pointColor.withOpacity(0.25)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pointCenter, areaStyle.pointRadius + 2, shadowPaint);
        final dotPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pointCenter, areaStyle.pointRadius, dotPaint);
        final borderPaint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.4;
        canvas.drawCircle(pointCenter, areaStyle.pointRadius, borderPaint);
      }
    }
  }

  List<TextSpan> _getDefaultTooltipSpans(
    T dataItem,
    dynamic Function(T) xValueMapper,
    num? Function(T) yValueMapper,
  ) {
    final xValue = xValueMapper(dataItem);
    final yValue = yValueMapper(dataItem);

    final xLabelText = 'Day $xValue';
    final yLabelText = yValue == null ? 'No Data' : '$yValue';

    return [
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
  bool shouldRepaint(covariant AreaChartPainter<T> oldDelegate) {
    final bool dataChanged = oldDelegate.data != data;
    final bool selectionChanged = oldDelegate.selectedPoint != selectedPoint;
    final bool mappersChanged = oldDelegate.xValueMapper != xValueMapper || oldDelegate.yValueMapper != yValueMapper;
    final bool formattersChanged =
        oldDelegate.xAxisLabelStyleFormatter != xAxisLabelStyleFormatter ||
        oldDelegate.yAxisLabelStyleFormatter != yAxisLabelStyleFormatter ||
        oldDelegate.tooltipDataFormatter != tooltipDataFormatter;
    final bool layoutChanged =
        oldDelegate.leftMargin != leftMargin ||
        oldDelegate.pointSpacing != pointSpacing ||
        oldDelegate.maxXLabels != maxXLabels ||
        oldDelegate.minY != minY ||
        oldDelegate.maxY != maxY;
    final bool stylesChanged = oldDelegate.tooltipStyle != tooltipStyle || oldDelegate.areaStyle != areaStyle;

    return dataChanged || selectionChanged || mappersChanged || formattersChanged || layoutChanged || stylesChanged;
  }
}