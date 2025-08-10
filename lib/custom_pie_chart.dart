import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

/// Controller for MoCustomPieChart to programmatically control chart interactions
class MoCustomPieChartController {
  _MoCustomPieChartState? _state;

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

  /// Get the currently selected slice index, returns null if no slice is selected
  int? get selectedIndex => _state?._selectedSlice;

  void _attach(_MoCustomPieChartState state) {
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

/// Style configuration for pie chart appearance
class PieStyle {
  final List<Color> sliceColors;
  final double strokeWidth;
  final double sliceGap;

  const PieStyle({
    this.sliceColors = const [
      Color(0xFF13861D),
      Color(0xFFDF130C),
      Color(0xFF1E90FF),
      Color(0xFFFFD700),
      Color(0xFF8A2BE2),
    ],
    this.strokeWidth = 1.0,
    this.sliceGap = 2.0,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PieStyle &&
        other.sliceColors == sliceColors &&
        other.strokeWidth == strokeWidth &&
        other.sliceGap == sliceGap;
  }

  @override
  int get hashCode {
    return sliceColors.hashCode ^ strokeWidth.hashCode ^ sliceGap.hashCode;
  }
}

class MoCustomPieChart<T> extends StatefulWidget {
  final List<T> data;
  final dynamic Function(T chartDataType) labelMapper;
  final num? Function(T chartDataType) valueMapper;
  final Function(int? selectedIndex)? onSelectionChanged;
  final Function(T dataItem)? onSliceTap;
  final List<TextSpan> Function(T dataItem)? tooltipDataFormatter;
  final MoCustomPieChartController? controller;
  final TooltipStyle? tooltipStyle;
  final PieStyle? pieStyle;

  const MoCustomPieChart({
    super.key,
    required this.data,
    required this.labelMapper,
    required this.valueMapper,
    this.onSelectionChanged,
    this.onSliceTap,
    this.tooltipDataFormatter,
    this.controller,
    this.tooltipStyle,
    this.pieStyle,
  });

  @override
  State<MoCustomPieChart<T>> createState() => _MoCustomPieChartState<T>();
}

class _MoCustomPieChartState<T> extends State<MoCustomPieChart<T>> {
  int? _selectedSlice;
  Timer? _autoCloseTimer;
  bool _isInteracting = false;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(MoCustomPieChart<T> oldWidget) {
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
      _selectedSlice = index;
    });

    widget.onSelectionChanged?.call(_selectedSlice);
    return true;
  }

  void _hideTooltip() {
    setState(() {
      _selectedSlice = null;
    });

    widget.onSelectionChanged?.call(_selectedSlice);
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
        painter: PieChartPainter<T>(
          data: widget.data,
          selectedSlice: _selectedSlice,
          labelMapper: widget.labelMapper,
          valueMapper: widget.valueMapper,
          tooltipDataFormatter: widget.tooltipDataFormatter,
          tooltipStyle: widget.tooltipStyle ?? const TooltipStyle(),
          pieStyle: widget.pieStyle ?? const PieStyle(),
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

    final centerX = box.size.width / 2;
    final centerY = box.size.height / 2;
    final radius = math.min(box.size.width, box.size.height) * 0.4;

    final dx = local.dx - centerX;
    final dy = local.dy - centerY;
    final distance = math.sqrt(dx * dx + dy * dy);

    int? tappedIndex;
    if (distance <= radius) {
      final angle = (math.atan2(dy, dx) + 2 * math.pi) % (2 * math.pi);
      final totalValue = widget.data.fold(0.0, (sum, item) => sum + (widget.valueMapper(item) ?? 0).abs());
      double currentAngle = 0.0;

      for (int i = 0; i < widget.data.length; i++) {
        final value = (widget.valueMapper(widget.data[i]) ?? 0).abs();
        final sliceAngle = (value / totalValue) * 2 * math.pi;
        if (angle >= currentAngle && angle < currentAngle + sliceAngle) {
          tappedIndex = i;
          break;
        }
        currentAngle += sliceAngle;
      }
    }

    if (!isTap && _selectedSlice != tappedIndex) {
      setState(() {
        _selectedSlice = tappedIndex;
      });
      widget.onSelectionChanged?.call(tappedIndex);

      _autoCloseTimer?.cancel();
      if (tappedIndex != null) {
        _autoCloseTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _selectedSlice = null;
              widget.onSelectionChanged?.call(null);
            });
          }
        });
      }
    } else if (isTap) {
      setState(() {
        _selectedSlice = tappedIndex;
        widget.onSelectionChanged?.call(tappedIndex);

        if (tappedIndex != null) {
          widget.onSliceTap?.call(widget.data[tappedIndex]);
        }

        if (tappedIndex != null) {
          _autoCloseTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _selectedSlice = null;
                widget.onSelectionChanged?.call(null);
              });
            }
          });
        }

        if (tappedIndex == null && _selectedSlice != null) {
          _selectedSlice = null;
          widget.onSelectionChanged?.call(null);
          _autoCloseTimer?.cancel();
        }
      });
    }
  }
}

class PieChartPainter<T> extends CustomPainter {
  final List<T> data;
  final int? selectedSlice;
  final dynamic Function(T chartDataType) labelMapper;
  final num? Function(T chartDataType) valueMapper;
  final List<TextSpan> Function(T dataItem)? tooltipDataFormatter;
  final TooltipStyle tooltipStyle;
  final PieStyle pieStyle;

  PieChartPainter({
    required this.data,
    required this.selectedSlice,
    required this.labelMapper,
    required this.valueMapper,
    this.tooltipDataFormatter,
    required this.tooltipStyle,
    required this.pieStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = math.min(size.width, size.height) * 0.4;
    final totalValue = data.fold(0.0, (sum, item) => sum + (valueMapper(item) ?? 0).abs());

    double startAngle = -math.pi / 2; // Start at top (12 o'clock)

    final labelPaint = Paint()
      ..color = const Color(0xFF909094)
      ..style = PaintingStyle.fill;

    // Draw pie slices
    for (int i = 0; i < data.length; i++) {
      final value = (valueMapper(data[i]) ?? 0).abs();
      final sweepAngle = (value / totalValue) * 2 * math.pi;
      final isSelected = i == selectedSlice;

      final slicePaint = Paint()
        ..color = pieStyle.sliceColors[i % pieStyle.sliceColors.length]
        ..style = PaintingStyle.fill;

      final sliceBorderPaint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = pieStyle.strokeWidth;

      final sliceRect = Rect.fromCircle(center: Offset(centerX, centerY), radius: radius);
      canvas.drawArc(sliceRect, startAngle, sweepAngle - pieStyle.sliceGap / radius, true, slicePaint);
      canvas.drawArc(sliceRect, startAngle, sweepAngle - pieStyle.sliceGap / radius, true, sliceBorderPaint);

      // Draw label at the edge of the slice
      final labelAngle = startAngle + sweepAngle / 2;
      final labelX = centerX + (radius + 20) * math.cos(labelAngle);
      final labelY = centerY + (radius + 20) * math.sin(labelAngle);
      final labelText = labelMapper(data[i]).toString();
      final textSpan = TextSpan(
        text: labelText,
        style: TextStyle(
          color: Color(0xFF909094),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(labelX - textPainter.width / 2, labelY - textPainter.height / 2),
      );

      startAngle += sweepAngle;
    }

    // Draw tooltip for selected slice
    if (selectedSlice != null && selectedSlice! < data.length) {
      final i = selectedSlice!;
      final value = (valueMapper(data[i]) ?? 0).abs();
      final sweepAngle = (value / totalValue) * 2 * math.pi;
      final tooltipAngle = startAngle - sweepAngle + sweepAngle / 2;
      final tooltipX = centerX + (radius + 30) * math.cos(tooltipAngle);
      final tooltipY = centerY + (radius + 30) * math.sin(tooltipAngle);

      final dataItem = data[i];
      List<TextSpan> tooltipSpans;
      if (tooltipDataFormatter != null) {
        tooltipSpans = tooltipDataFormatter!(dataItem);
      } else {
        tooltipSpans = _getDefaultTooltipSpans(dataItem, labelMapper, valueMapper);
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

      double adjustedTooltipX = tooltipX - actualTooltipWidth / 2;
      double adjustedTooltipY = tooltipY - actualTooltipHeight - 10;
      adjustedTooltipX = adjustedTooltipX.clamp(10, size.width - actualTooltipWidth - 10);
      adjustedTooltipY = adjustedTooltipY.clamp(10, size.height - actualTooltipHeight - 10);

      final actualArrowXOffset = (tooltipX - adjustedTooltipX).clamp(15.0, actualTooltipWidth - 15.0);

      final linePaint = Paint()
        ..color = pieStyle.sliceColors[i % pieStyle.sliceColors.length]
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final dashHeight = 5.0;
      final dashSpace = 5.0;
      double currentY = adjustedTooltipY + actualTooltipHeight + 10;
      final lineEndY = tooltipY;

      while (currentY < lineEndY) {
        final remainingHeight = lineEndY - currentY;
        final actualDashHeight = remainingHeight < dashHeight ? remainingHeight : dashHeight;
        canvas.drawLine(
          Offset(tooltipX, currentY),
          Offset(tooltipX, currentY + actualDashHeight),
          linePaint,
        );
        currentY += dashHeight + dashSpace;
      }

      final tooltipWithArrowPath = Path();
      tooltipWithArrowPath.moveTo(adjustedTooltipX + tooltipStyle.borderRadius, adjustedTooltipY);
      tooltipWithArrowPath.lineTo(adjustedTooltipX + actualTooltipWidth - tooltipStyle.borderRadius, adjustedTooltipY);
      tooltipWithArrowPath.arcToPoint(
        Offset(adjustedTooltipX + actualTooltipWidth, adjustedTooltipY + tooltipStyle.borderRadius),
        radius: Radius.circular(tooltipStyle.borderRadius),
        clockwise: true,
      );
      tooltipWithArrowPath.lineTo(adjustedTooltipX + actualTooltipWidth, adjustedTooltipY + actualTooltipHeight - tooltipStyle.borderRadius);
      tooltipWithArrowPath.arcToPoint(
        Offset(adjustedTooltipX + actualTooltipWidth - tooltipStyle.borderRadius, adjustedTooltipY + actualTooltipHeight),
        radius: Radius.circular(tooltipStyle.borderRadius),
        clockwise: true,
      );
      tooltipWithArrowPath.lineTo(adjustedTooltipX + actualArrowXOffset + 10, adjustedTooltipY + actualTooltipHeight);
      tooltipWithArrowPath.lineTo(adjustedTooltipX + actualArrowXOffset, adjustedTooltipY + actualTooltipHeight + 10);
      tooltipWithArrowPath.lineTo(adjustedTooltipX + actualArrowXOffset - 10, adjustedTooltipY + actualTooltipHeight);
      tooltipWithArrowPath.lineTo(adjustedTooltipX + tooltipStyle.borderRadius, adjustedTooltipY + actualTooltipHeight);
      tooltipWithArrowPath.arcToPoint(
        Offset(adjustedTooltipX, adjustedTooltipY + actualTooltipHeight - tooltipStyle.borderRadius),
        radius: Radius.circular(tooltipStyle.borderRadius),
        clockwise: true,
      );
      tooltipWithArrowPath.lineTo(adjustedTooltipX, adjustedTooltipY + tooltipStyle.borderRadius);
      tooltipWithArrowPath.arcToPoint(
        Offset(adjustedTooltipX + tooltipStyle.borderRadius, adjustedTooltipY),
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
        Offset(adjustedTooltipX + 8, adjustedTooltipY + 4),
      );
    }
  }

  List<TextSpan> _getDefaultTooltipSpans(
    T dataItem,
    dynamic Function(T) labelMapper,
    num? Function(T) valueMapper,
  ) {
    final label = labelMapper(dataItem);
    final value = valueMapper(dataItem);

    final labelText = '$label';
    final valueText = value == null ? 'No Data' : '$value';

    return [
      TextSpan(
        text: labelText,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      const TextSpan(text: '\n', style: TextStyle(fontSize: 14)),
      TextSpan(
        text: valueText,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.normal,
          fontSize: 14,
        ),
      ),
    ];
  }

  @override
  bool shouldRepaint(covariant PieChartPainter<T> oldDelegate) {
    final bool dataChanged = oldDelegate.data != data;
    final bool selectionChanged = oldDelegate.selectedSlice != selectedSlice;
    final bool mappersChanged = oldDelegate.labelMapper != labelMapper || oldDelegate.valueMapper != valueMapper;
    final bool formatterChanged = oldDelegate.tooltipDataFormatter != tooltipDataFormatter;
    final bool stylesChanged = oldDelegate.tooltipStyle != tooltipStyle || oldDelegate.pieStyle != pieStyle;

    return dataChanged || selectionChanged || mappersChanged || formatterChanged || stylesChanged;
  }
}