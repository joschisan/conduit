import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Text whose final line break is chosen to even out line widths, replacing
/// the balanced_text package.
///
/// Implemented as a [RenderBox] rather than the package's [LayoutBuilder] so
/// ancestors that probe intrinsic sizes — [IntrinsicHeight], dialogs,
/// [SliverFillRemaining] — keep working; a [LayoutBuilder] throws on any
/// intrinsic query.
class BalancedText extends LeafRenderObjectWidget {
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;

  const BalancedText(this.data, {super.key, this.style, this.textAlign});

  TextStyle _effectiveStyle(BuildContext context) =>
      DefaultTextStyle.of(context).style.merge(style);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderBalancedText(
      text: data,
      style: _effectiveStyle(context),
      textAlign: textAlign ?? TextAlign.start,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderBalancedText renderObject,
  ) {
    renderObject
      ..text = data
      ..style = _effectiveStyle(context)
      ..textAlign = textAlign ?? TextAlign.start
      ..textDirection = Directionality.of(context)
      ..textScaler = MediaQuery.textScalerOf(context);
  }
}

class RenderBalancedText extends RenderBox {
  RenderBalancedText({
    required String text,
    required TextStyle style,
    required TextAlign textAlign,
    required TextDirection textDirection,
    required TextScaler textScaler,
  }) : _text = text,
       _style = style,
       _textAlign = textAlign,
       _textDirection = textDirection,
       _textScaler = textScaler;

  /// Paints the laid-out text; only ever touched in [performLayout] and
  /// [paint] so intrinsic queries can't invalidate what gets painted.
  final TextPainter _painter = TextPainter();

  /// Scratch painter for width probes and intrinsic/dry measurements.
  final TextPainter _measure = TextPainter();

  String _text;
  set text(String value) {
    if (value == _text) return;
    _text = value;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  TextStyle _style;
  set style(TextStyle value) {
    if (value == _style) return;
    _style = value;
    markNeedsLayout();
  }

  TextAlign _textAlign;
  set textAlign(TextAlign value) {
    if (value == _textAlign) return;
    _textAlign = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  TextScaler _textScaler;
  set textScaler(TextScaler value) {
    if (value == _textScaler) return;
    _textScaler = value;
    markNeedsLayout();
  }

  double _lineWidth(String line) {
    _measure
      ..text = TextSpan(text: line, style: _style)
      ..textDirection = _textDirection
      ..textScaler = _textScaler
      ..layout();
    return _measure.width;
  }

  /// Rebalances [_text] onto two visually even lines when it wouldn't fit on
  /// one, mirroring the balanced_text package: walk the break point forward
  /// until the width difference between the lines stops shrinking.
  String _balanced(double maxWidth) {
    if (_text.contains('\n')) return _text;

    final words = _text.split(' ');

    if (words.length < 3 || _lineWidth(_text) < maxWidth) return _text;

    var lastDifference = double.infinity;

    for (var i = 1; i <= words.length; i++) {
      final leadingWidth = _lineWidth(words.sublist(0, i).join(' '));

      if (leadingWidth > maxWidth) return _text;

      final remainingWidth = _lineWidth(words.sublist(i).join(' '));
      final difference = (leadingWidth - remainingWidth).abs();

      if (difference > lastDifference) {
        return '${words.sublist(0, i - 1).join(' ')}\n'
            '${words.sublist(i - 1).join(' ')}';
      }

      lastDifference = difference;
    }

    return _text;
  }

  void _layoutPainter(TextPainter painter, BoxConstraints constraints) {
    painter
      ..text = TextSpan(text: _balanced(constraints.maxWidth), style: _style)
      ..textAlign = _textAlign
      ..textDirection = _textDirection
      ..textScaler = _textScaler
      ..layout(minWidth: constraints.minWidth, maxWidth: constraints.maxWidth);
  }

  @override
  void performLayout() {
    _layoutPainter(_painter, constraints);
    size = constraints.constrain(_painter.size);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _painter.paint(context.canvas, offset);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    _layoutPainter(_measure, constraints);
    return constraints.constrain(_measure.size);
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    _layoutPainter(_measure, const BoxConstraints());
    return _measure.minIntrinsicWidth;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    _layoutPainter(_measure, const BoxConstraints());
    return _measure.maxIntrinsicWidth;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    _layoutPainter(_measure, BoxConstraints(maxWidth: width));
    return _measure.height;
  }

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..label = _text
      ..textDirection = _textDirection;
  }

  @override
  void dispose() {
    _painter.dispose();
    _measure.dispose();
    super.dispose();
  }
}
