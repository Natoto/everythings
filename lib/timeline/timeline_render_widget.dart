import 'dart:math';
import 'dart:ui';
import "dart:ui" as ui;
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:nima/nima/actor_image.dart' as nima;
import 'package:nima/nima/math/aabb.dart' as nima;
import 'package:flare/flare/actor_image.dart' as flare;
import 'package:flare/flare/math/aabb.dart' as flare;
import 'package:timeline/colors.dart';
import 'package:timeline/main_menu/menu_data.dart';
import 'package:timeline/timeline/ticks.dart';
import 'package:timeline/timeline/timeline.dart';
import 'package:timeline/timeline/timeline_entry.dart';
import 'package:timeline/timeline/timeline_utils.dart';

typedef TouchBubbleCallback(TapTarget bubble);
typedef TouchEntryCallback(TimelineEntry entry);

class TimelineRenderWidget extends LeafRenderObjectWidget {
  final MenuItemData focusItem;
  final TouchBubbleCallback touchBubble;
  final TouchEntryCallback touchEntry;
  final double topOverlap;
  final Timeline timeline;
  final List<TimelineEntry> favorites;

  TimelineRenderWidget(
      {Key key,
      this.focusItem,
      this.touchBubble,
      this.touchEntry,
      this.topOverlap,
      this.timeline,
      this.favorites})
      : super(key: key);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return TimelineRenderObject()
      ..timeline = timeline
      ..touchBubble = touchBubble
      ..touchEntry = touchEntry
      ..focusItem = focusItem
      ..favorites = favorites
      ..topOverlap = topOverlap;
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant TimelineRenderObject renderObject) {
    renderObject
      ..timeline = timeline
      ..focusItem = focusItem
      ..touchBubble = touchBubble
      ..touchEntry = touchEntry
      ..favorites = favorites
      ..topOverlap = topOverlap;
  }

  @override
  didUnmountRenderObject(covariant TimelineRenderObject renderObject) {
    renderObject.timeline.isActive = false;
  }
}

class TimelineRenderObject extends RenderBox {
  static const List<Color> LineColors = [
    Color.fromARGB(255, 125, 195, 184),
    Color.fromARGB(255, 190, 224, 146),
    Color.fromARGB(255, 238, 155, 75),
    Color.fromARGB(255, 202, 79, 63),
    Color.fromARGB(255, 128, 28, 15)
  ];

  List<TapTarget> _tapTargets = List<TapTarget>();
  Ticks _ticks = Ticks();
  Timeline _timeline;
  MenuItemData _focusItem;

  double _topOverlap = 0.0;
  double get topOverlap => _topOverlap;
  set topOverlap(double value) {
    if (_topOverlap == value) {
      return;
    }
    _topOverlap = value;
    updateFocusItem();
    markNeedsPaint();
    markNeedsLayout();
  }

  TouchBubbleCallback touchBubble;
  TouchEntryCallback touchEntry;

  Timeline get timeline => _timeline;
  set timeline(Timeline value) {
    if (_timeline == value) {
      return;
    }
    _timeline = value;
    updateFocusItem();
    _timeline.onNeedPaint = markNeedsPaint;
    markNeedsPaint();
    markNeedsLayout();
  }

  List<TimelineEntry> _favorites;
  List<TimelineEntry> get favorites => _favorites;
  set favorites(List<TimelineEntry> value) {
    if (_favorites == value) {
      return;
    }
    _favorites = value;
    markNeedsPaint();
    markNeedsLayout();
  }

  MenuItemData _processedFocusItem;
  void updateFocusItem() {
    if (_processedFocusItem == _focusItem) {
      return;
    }
    if (_focusItem == null || timeline == null || topOverlap == 0.0) {
      return;
    }

    if (_focusItem.pad) {
      timeline.padding = EdgeInsets.only(
          top: topOverlap + _focusItem.padTop + Timeline.Parallax,
          bottom: _focusItem.padBottom);
      timeline.setViewport(
          start: _focusItem.start,
          end: _focusItem.end,
          animate: true,
          pad: true);
    } else {
      timeline.padding = EdgeInsets.zero;
      timeline.setViewport(
          start: _focusItem.start, end: _focusItem.end, animate: true);
    }
    _processedFocusItem = _focusItem;
  }

  MenuItemData get focusItem => _focusItem;
  set focusItem(MenuItemData value) {
    if (_focusItem == value) {
      return;
    }
    _focusItem = value;
    _processedFocusItem = null;
    updateFocusItem();
  }

  @override
  bool get sizedByParent => true;

  @override
  bool hitTestSelf(Offset screenOffset) {
    touchEntry(null);
    for (TapTarget bubble in _tapTargets.reversed) {
      if (bubble.rect.contains(screenOffset)) {
        if (touchBubble != null) {
          touchBubble(bubble);
        }
        return true;
      }
    }
    touchBubble(null);

    return true;
  }

  @override
  void performResize() {
    size = constraints.biggest;
  }

  @override
  void performLayout() {
    if (_timeline != null) {
      _timeline.setViewport(height: size.height, animate: true);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final Canvas canvas = context.canvas;
    if (_timeline == null) {
      return;
    }

    List<TimelineBackgroundColor> backgroundColors = timeline.backgroundColors;
    ui.Paint backgroundPaint;
    if (backgroundColors != null && backgroundColors.length > 0) {
      double rangeStart = backgroundColors.first.start;
      double range = backgroundColors.last.start - backgroundColors.first.start;
      List<ui.Color> colors = <ui.Color>[];
      List<double> stops = <double>[];
      for (TimelineBackgroundColor bg in backgroundColors) {
        colors.add(bg.color);
        stops.add((bg.start - rangeStart) / range);
      }
      double s =
          timeline.computeScale(timeline.renderStart, timeline.renderEnd);
      double y1 = (backgroundColors.first.start - timeline.renderStart) * s;
      double y2 = (backgroundColors.last.start - timeline.renderStart) * s;

      // Fill Background.
      backgroundPaint = ui.Paint()
        ..shader = ui.Gradient.linear(
            ui.Offset(0.0, y1), ui.Offset(0.0, y2), colors, stops)
        ..style = ui.PaintingStyle.fill;

      if (y1 > offset.dy) {
        canvas.drawRect(
            Rect.fromLTWH(
                offset.dx, offset.dy, size.width, y1 - offset.dy + 1.0),
            ui.Paint()..color = backgroundColors.first.color);
      }
      canvas.drawRect(
          Rect.fromLTWH(offset.dx, y1, size.width, y2 - y1), backgroundPaint);

      //print("SIZE ${new Rect.fromLTWH(offset.dx, y1, size.width, y2-y1)}");
    }
    _tapTargets.clear();
    double renderStart = _timeline.renderStart;
    double renderEnd = _timeline.renderEnd;
    double scale = size.height / (renderEnd - renderStart);

    //canvas.drawRect(new Offset(0.0, 0.0) & new Size(100.0, 100.0), new Paint()..color = Colors.red);

    if (timeline.renderAssets != null) {
      canvas.save();
      canvas.clipRect(offset & size);
      for (TimelineAsset asset in timeline.renderAssets) {
        if (asset.opacity > 0) {
          //ctx.globalAlpha = asset.opacity;
          double rs = 0.2 + asset.scale * 0.8;

          double w = asset.width * Timeline.AssetScreenScale;
          double h = asset.height * Timeline.AssetScreenScale;

          if (asset is TimelineImage) {
            canvas.drawImageRect(
                asset.image,
                Rect.fromLTWH(0.0, 0.0, asset.width, asset.height),
                Rect.fromLTWH(
                    offset.dx + size.width - w, asset.y, w * rs, h * rs),
                Paint()
                  ..isAntiAlias = true
                  ..filterQuality = ui.FilterQuality.low
                  ..color = Colors.white.withOpacity(asset.opacity));
          } else if (asset is TimelineNima && asset.actor != null) {
            Alignment alignment = Alignment.center;
            BoxFit fit = BoxFit.cover;

            nima.AABB bounds = asset.setupAABB;

            double contentHeight = bounds[3] - bounds[1];
            double contentWidth = bounds[2] - bounds[0];
            double x = -bounds[0] -
                contentWidth / 2.0 -
                (alignment.x * contentWidth / 2.0) +
                asset.offset;
            double y = -bounds[1] -
                contentHeight / 2.0 +
                (alignment.y * contentHeight / 2.0);

            Offset renderOffset = Offset(offset.dx + size.width - w, asset.y);
            Size renderSize = Size(w * rs, h * rs);

            double scaleX = 1.0, scaleY = 1.0;

            canvas.save();
            //canvas.clipRect(renderOffset & renderSize);

            switch (fit) {
              case BoxFit.fill:
                scaleX = renderSize.width / contentWidth;
                scaleY = renderSize.height / contentHeight;
                break;
              case BoxFit.contain:
                double minScale = min(renderSize.width / contentWidth,
                    renderSize.height / contentHeight);
                scaleX = scaleY = minScale;
                break;
              case BoxFit.cover:
                double maxScale = max(renderSize.width / contentWidth,
                    renderSize.height / contentHeight);
                scaleX = scaleY = maxScale;
                break;
              case BoxFit.fitHeight:
                double minScale = renderSize.height / contentHeight;
                scaleX = scaleY = minScale;
                break;
              case BoxFit.fitWidth:
                double minScale = renderSize.width / contentWidth;
                scaleX = scaleY = minScale;
                break;
              case BoxFit.none:
                scaleX = scaleY = 1.0;
                break;
              case BoxFit.scaleDown:
                double minScale = min(renderSize.width / contentWidth,
                    renderSize.height / contentHeight);
                scaleX = scaleY = minScale < 1.0 ? minScale : 1.0;
                break;
            }

            canvas.translate(
                renderOffset.dx +
                    renderSize.width / 2.0 +
                    (alignment.x * renderSize.width / 2.0),
                renderOffset.dy +
                    renderSize.height / 2.0 +
                    (alignment.y * renderSize.height / 2.0));
            canvas.scale(scaleX, -scaleY);
            canvas.translate(x, y);

            // Comment in to see the AABB
            // canvas.drawRect(new Rect.fromLTRB(bounds[0], bounds[1], bounds[2], bounds[3]), new Paint()..color = (asset.entry.accent != null ? asset.entry.accent : LineColors[depth%LineColors.length]).withOpacity(0.5));

            asset.actor.draw(canvas, asset.opacity);
            canvas.restore();
            _tapTargets.add(TapTarget()
              ..entry = asset.entry
              ..rect = renderOffset & renderSize);
          } else if (asset is TimelineFlare && asset.actor != null) {
            Alignment alignment = Alignment.center;
            BoxFit fit = BoxFit.cover;

            flare.AABB bounds = asset.setupAABB;
            double contentWidth = bounds[2] - bounds[0];
            double contentHeight = bounds[3] - bounds[1];
            double x = -bounds[0] -
                contentWidth / 2.0 -
                (alignment.x * contentWidth / 2.0) +
                asset.offset;
            double y = -bounds[1] -
                contentHeight / 2.0 +
                (alignment.y * contentHeight / 2.0);

            Offset renderOffset = Offset(offset.dx + size.width - w, asset.y);
            Size renderSize = Size(w * rs, h * rs);

            double scaleX = 1.0, scaleY = 1.0;

            canvas.save();
            //canvas.clipRect(renderOffset & renderSize);

            switch (fit) {
              case BoxFit.fill:
                scaleX = renderSize.width / contentWidth;
                scaleY = renderSize.height / contentHeight;
                break;
              case BoxFit.contain:
                double minScale = min(renderSize.width / contentWidth,
                    renderSize.height / contentHeight);
                scaleX = scaleY = minScale;
                break;
              case BoxFit.cover:
                double maxScale = max(renderSize.width / contentWidth,
                    renderSize.height / contentHeight);
                scaleX = scaleY = maxScale;
                break;
              case BoxFit.fitHeight:
                double minScale = renderSize.height / contentHeight;
                scaleX = scaleY = minScale;
                break;
              case BoxFit.fitWidth:
                double minScale = renderSize.width / contentWidth;
                scaleX = scaleY = minScale;
                break;
              case BoxFit.none:
                scaleX = scaleY = 1.0;
                break;
              case BoxFit.scaleDown:
                double minScale = min(renderSize.width / contentWidth,
                    renderSize.height / contentHeight);
                scaleX = scaleY = minScale < 1.0 ? minScale : 1.0;
                break;
            }

            canvas.translate(
                renderOffset.dx +
                    renderSize.width / 2.0 +
                    (alignment.x * renderSize.width / 2.0),
                renderOffset.dy +
                    renderSize.height / 2.0 +
                    (alignment.y * renderSize.height / 2.0));
            canvas.scale(scaleX, scaleY);
            canvas.translate(x, y);

            // Comment in to see the AABB
            // canvas.drawRect(new Rect.fromLTRB(bounds[0], bounds[1], bounds[2], bounds[3]), new Paint()..color = (asset.entry.accent != null ? asset.entry.accent : LineColors[depth%LineColors.length]).withOpacity(0.5));

            asset.actor.draw(canvas, opacity: asset.opacity);
            canvas.restore();
            _tapTargets.add(TapTarget()
              ..entry = asset.entry
              ..rect = renderOffset & renderSize);
          }
        }
      }
      canvas.restore();
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(
        offset.dx, offset.dy + topOverlap, size.width, size.height));
    _ticks.paint(
        context, offset, -renderStart * scale, scale, size.height, timeline);
    canvas.restore();

    if (_timeline.entries != null) {
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(offset.dx + _timeline.gutterWidth,
          offset.dy, size.width - _timeline.gutterWidth, size.height));
      drawItems(
          context,
          offset,
          _timeline.entries,
          _timeline.gutterWidth +
              Timeline.LineSpacing -
              Timeline.DepthOffset * _timeline.renderOffsetDepth,
          scale,
          0);
      canvas.restore();
    }

    if (_timeline.nextEntry != null && _timeline.nextEntryOpacity > 0.0) {
      double x = offset.dx + _timeline.gutterWidth - Timeline.GutterLeft;
      double opacity = _timeline.nextEntryOpacity;
      Color color = Color.fromRGBO(69, 211, 197, opacity);
      double pageSize = (_timeline.renderEnd - _timeline.renderStart);
      double pageReference =
          _timeline.renderEnd; //_timeline.renderStart + pageSize/2.0;

      const double MaxLabelWidth = 1200.0;
      ui.ParagraphBuilder builder = ui.ParagraphBuilder(ui.ParagraphStyle(
          textAlign: TextAlign.start, fontFamily: "Roboto", fontSize: 20.0))
        ..pushStyle(ui.TextStyle(color: color));

      builder.addText(_timeline.nextEntry.label);
      ui.Paragraph labelParagraph = builder.build();
      labelParagraph.layout(ui.ParagraphConstraints(width: MaxLabelWidth));

      double y = offset.dy + size.height - 200.0;
      double labelX =
          x + size.width / 2.0 - labelParagraph.maxIntrinsicWidth / 2.0;
      canvas.drawParagraph(labelParagraph, Offset(labelX, y));
      y += labelParagraph.height;

      Rect nextEntryRect = Rect.fromLTWH(labelX, y,
          labelParagraph.maxIntrinsicWidth, offset.dy + size.height - y);

      const double radius = 25.0;
      labelX = x + size.width / 2.0;
      y += 15 + radius;
      canvas.drawCircle(
          Offset(labelX, y),
          radius,
          Paint()
            ..color = color
            ..style = PaintingStyle.fill);
      nextEntryRect.expandToInclude(Rect.fromLTWH(
          labelX - radius, y - radius, radius * 2.0, radius * 2.0));
      Path path = Path();
      double arrowSize = 6.0;
      double arrowOffset = 1.0;
      path.moveTo(x + size.width / 2.0 - arrowSize,
          y - arrowSize + arrowSize / 2.0 + arrowOffset);
      path.lineTo(x + size.width / 2.0, y + arrowSize / 2.0 + arrowOffset);
      path.lineTo(x + size.width / 2.0 + arrowSize,
          y - arrowSize + arrowSize / 2.0 + arrowOffset);
      canvas.drawPath(
          path,
          Paint()
            ..color = Colors.white.withOpacity(opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0);
      y += 15 + radius;

      builder = ui.ParagraphBuilder(ui.ParagraphStyle(
          textAlign: TextAlign.center,
          fontFamily: "Roboto",
          fontSize: 14.0,
          lineHeight: 1.3))
        ..pushStyle(ui.TextStyle(color: color));

      double timeUntil = _timeline.nextEntry.start - pageReference;
      double pages = timeUntil / pageSize;
      NumberFormat formatter = NumberFormat.compact();
      String pagesFormatted = formatter.format(pages);
      String until = "in " +
          TimelineEntry.formatYears(timeUntil).toLowerCase() +
          "\n($pagesFormatted page scrolls)";
      builder.addText(until);
      labelParagraph = builder.build();
      labelParagraph.layout(ui.ParagraphConstraints(width: size.width));
      canvas.drawParagraph(labelParagraph, Offset(x, y));
      y += labelParagraph.height;

      _tapTargets.add(TapTarget()
        ..entry = _timeline.nextEntry
        ..rect = nextEntryRect
        ..zoom = true);
    }

    if (_timeline.prevEntry != null && _timeline.prevEntryOpacity > 0.0) {
      double x = offset.dx + _timeline.gutterWidth - Timeline.GutterLeft;
      double opacity = _timeline.prevEntryOpacity;
      Color color = Color.fromRGBO(69, 211, 197, opacity);
      double pageSize = (_timeline.renderEnd - _timeline.renderStart);
      double pageReference =
          _timeline.renderEnd; //_timeline.renderStart + pageSize/2.0;

      const double MaxLabelWidth = 1200.0;
      ui.ParagraphBuilder builder = ui.ParagraphBuilder(ui.ParagraphStyle(
          textAlign: TextAlign.start, fontFamily: "Roboto", fontSize: 20.0))
        ..pushStyle(ui.TextStyle(color: color));

      builder.addText(_timeline.prevEntry.label);
      ui.Paragraph labelParagraph = builder.build();
      labelParagraph.layout(ui.ParagraphConstraints(width: MaxLabelWidth));

      double y = offset.dy + topOverlap + 20.0; //+ size.height - 200.0;
      double labelX =
          x + size.width / 2.0 - labelParagraph.maxIntrinsicWidth / 2.0;
      canvas.drawParagraph(labelParagraph, Offset(labelX, y));
      y += labelParagraph.height;

      Rect prevEntryRect = Rect.fromLTWH(labelX, y,
          labelParagraph.maxIntrinsicWidth, offset.dy + size.height - y);

      const double radius = 25.0;
      labelX = x + size.width / 2.0;
      y += 15 + radius;
      canvas.drawCircle(
          Offset(labelX, y),
          radius,
          Paint()
            ..color = color
            ..style = PaintingStyle.fill);
      prevEntryRect.expandToInclude(Rect.fromLTWH(
          labelX - radius, y - radius, radius * 2.0, radius * 2.0));
      Path path = Path();
      double arrowSize = 6.0;
      double arrowOffset = 1.0;
      path.moveTo(
          x + size.width / 2.0 - arrowSize, y + arrowSize / 2.0 + arrowOffset);
      path.lineTo(x + size.width / 2.0, y - arrowSize / 2.0 + arrowOffset);
      path.lineTo(
          x + size.width / 2.0 + arrowSize, y + arrowSize / 2.0 + arrowOffset);
      canvas.drawPath(
          path,
          Paint()
            ..color = Colors.white.withOpacity(opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0);
      y += 15 + radius;

      builder = ui.ParagraphBuilder(ui.ParagraphStyle(
          textAlign: TextAlign.center,
          fontFamily: "Roboto",
          fontSize: 14.0,
          lineHeight: 1.3))
        ..pushStyle(ui.TextStyle(color: color));

      double timeUntil = _timeline.prevEntry.start - pageReference;
      double pages = timeUntil / pageSize;
      NumberFormat formatter = NumberFormat.compact();
      String pagesFormatted = formatter.format(pages.abs());
      String until = TimelineEntry.formatYears(timeUntil).toLowerCase() +
          " ago\n($pagesFormatted page scrolls)";
      builder.addText(until);
      labelParagraph = builder.build();
      labelParagraph.layout(ui.ParagraphConstraints(width: size.width));
      canvas.drawParagraph(labelParagraph, Offset(x, y));
      y += labelParagraph.height;

      _tapTargets.add(TapTarget()
        ..entry = _timeline.prevEntry
        ..rect = prevEntryRect
        ..zoom = true);
    }

    double favoritesGutter = _timeline.gutterWidth - Timeline.GutterLeft;
    if (_favorites != null && _favorites.length > 0 && favoritesGutter > 0.0) {
      Paint accentPaint = Paint()
        ..color = favoritesGutterAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      Paint accentFill = Paint()
        ..color = favoritesGutterAccent
        ..style = PaintingStyle.fill;
      Paint whitePaint = Paint()..color = Colors.white;
      double scale =
          timeline.computeScale(timeline.renderStart, timeline.renderEnd);
      double fullMargin = 50.0;
      double favoritesRadius = 20.0;
      double fullMarginOffset = fullMargin + favoritesRadius + 11.0;
      double x = offset.dx -
          fullMargin +
          favoritesGutter /
              (Timeline.GutterLeftExpanded - Timeline.GutterLeft) *
              fullMarginOffset;

      double padFavorites = 20.0;

      // Order favorites by distance from mid.
      List<TimelineEntry> nearbyFavorites =
          List<TimelineEntry>.from(_favorites);
      double mid = timeline.renderStart +
          (timeline.renderEnd - timeline.renderStart) / 2.0;
      nearbyFavorites.sort((TimelineEntry a, TimelineEntry b) {
        return (a.start - mid).abs().compareTo((b.start - mid).abs());
      });

      // layout favorites.
      for (int i = 0; i < nearbyFavorites.length; i++) {
        TimelineEntry favorite = nearbyFavorites[i];
        double y = ((favorite.start - timeline.renderStart) * scale).clamp(
            offset.dy + topOverlap + favoritesRadius + padFavorites,
            offset.dy + size.height - favoritesRadius - padFavorites);
        favorite.favoriteY = y;
        //print("F ${favorite.label} $y");

        // Check all closer events to see if this one is occluded by a previous closer one.
        // Works because we sorted by distance.
        favorite.isFavoriteOccluded = false;
        for (int j = 0; j < i; j++) {
          TimelineEntry closer = nearbyFavorites[j];
          if ((favorite.favoriteY - closer.favoriteY).abs() <= 1.0) {
            favorite.isFavoriteOccluded = true;
            break;
          }
        }
      }

      for (TimelineEntry favorite in nearbyFavorites.reversed) {
        if (favorite.isFavoriteOccluded) {
          continue;
        }
        double y = favorite
            .favoriteY; //((favorite.start-timeline.renderStart)*scale).clamp(offset.dy + topOverlap + favoritesRadius + padFavorites, offset.dy + size.height - favoritesRadius - padFavorites);

        canvas.drawCircle(
            Offset(x, y),
            favoritesRadius,
            backgroundPaint != null ? backgroundPaint : Paint()
              ..color = Colors.white
              ..style = PaintingStyle.fill);
        canvas.drawCircle(Offset(x, y), favoritesRadius, accentPaint);
        canvas.drawCircle(Offset(x, y), favoritesRadius - 4.0, whitePaint);

        TimelineAsset asset = favorite.asset;
        double assetSize = 40.0 - 8.0;
        Size renderSize = Size(assetSize, assetSize);
        Offset renderOffset = Offset(x - assetSize / 2.0, y - assetSize / 2.0);

        Alignment alignment = Alignment.center;
        BoxFit fit = BoxFit.cover;

        if (asset is TimelineNima && asset.actorStatic != null) {
          nima.AABB bounds = asset.setupAABB;

          double contentHeight = bounds[3] - bounds[1];
          double contentWidth = bounds[2] - bounds[0];
          double x = -bounds[0] -
              contentWidth / 2.0 -
              (alignment.x * contentWidth / 2.0) +
              asset.offset;
          double y = -bounds[1] -
              contentHeight / 2.0 +
              (alignment.y * contentHeight / 2.0);

          double scaleX = 1.0, scaleY = 1.0;

          canvas.save();
          canvas.clipRRect(RRect.fromRectAndRadius(
              renderOffset & renderSize, Radius.circular(favoritesRadius)));

          switch (fit) {
            case BoxFit.fill:
              scaleX = renderSize.width / contentWidth;
              scaleY = renderSize.height / contentHeight;
              break;
            case BoxFit.contain:
              double minScale = min(renderSize.width / contentWidth,
                  renderSize.height / contentHeight);
              scaleX = scaleY = minScale;
              break;
            case BoxFit.cover:
              double maxScale = max(renderSize.width / contentWidth,
                  renderSize.height / contentHeight);
              scaleX = scaleY = maxScale;
              break;
            case BoxFit.fitHeight:
              double minScale = renderSize.height / contentHeight;
              scaleX = scaleY = minScale;
              break;
            case BoxFit.fitWidth:
              double minScale = renderSize.width / contentWidth;
              scaleX = scaleY = minScale;
              break;
            case BoxFit.none:
              scaleX = scaleY = 1.0;
              break;
            case BoxFit.scaleDown:
              double minScale = min(renderSize.width / contentWidth,
                  renderSize.height / contentHeight);
              scaleX = scaleY = minScale < 1.0 ? minScale : 1.0;
              break;
          }

          canvas.translate(
              renderOffset.dx +
                  renderSize.width / 2.0 +
                  (alignment.x * renderSize.width / 2.0),
              renderOffset.dy +
                  renderSize.height / 2.0 +
                  (alignment.y * renderSize.height / 2.0));
          canvas.scale(scaleX, -scaleY);
          canvas.translate(x, y);

          asset.actorStatic.draw(canvas);
          canvas.restore();
          _tapTargets.add(TapTarget()
            ..entry = asset.entry
            ..rect = renderOffset & renderSize
            ..zoom = true);
        } else if (asset is TimelineFlare && asset.actorStatic != null) {
          flare.AABB bounds = asset.setupAABB;
          double contentWidth = bounds[2] - bounds[0];
          double contentHeight = bounds[3] - bounds[1];
          double x = -bounds[0] -
              contentWidth / 2.0 -
              (alignment.x * contentWidth / 2.0) +
              asset.offset;
          double y = -bounds[1] -
              contentHeight / 2.0 +
              (alignment.y * contentHeight / 2.0);

          double scaleX = 1.0, scaleY = 1.0;

          canvas.save();
          canvas.clipRRect(RRect.fromRectAndRadius(
              renderOffset & renderSize, Radius.circular(favoritesRadius)));

          switch (fit) {
            case BoxFit.fill:
              scaleX = renderSize.width / contentWidth;
              scaleY = renderSize.height / contentHeight;
              break;
            case BoxFit.contain:
              double minScale = min(renderSize.width / contentWidth,
                  renderSize.height / contentHeight);
              scaleX = scaleY = minScale;
              break;
            case BoxFit.cover:
              double maxScale = max(renderSize.width / contentWidth,
                  renderSize.height / contentHeight);
              scaleX = scaleY = maxScale;
              break;
            case BoxFit.fitHeight:
              double minScale = renderSize.height / contentHeight;
              scaleX = scaleY = minScale;
              break;
            case BoxFit.fitWidth:
              double minScale = renderSize.width / contentWidth;
              scaleX = scaleY = minScale;
              break;
            case BoxFit.none:
              scaleX = scaleY = 1.0;
              break;
            case BoxFit.scaleDown:
              double minScale = min(renderSize.width / contentWidth,
                  renderSize.height / contentHeight);
              scaleX = scaleY = minScale < 1.0 ? minScale : 1.0;
              break;
          }

          canvas.translate(
              renderOffset.dx +
                  renderSize.width / 2.0 +
                  (alignment.x * renderSize.width / 2.0),
              renderOffset.dy +
                  renderSize.height / 2.0 +
                  (alignment.y * renderSize.height / 2.0));
          canvas.scale(scaleX, scaleY);
          canvas.translate(x, y);

          asset.actorStatic.draw(canvas);
          canvas.restore();
          _tapTargets.add(TapTarget()
            ..entry = asset.entry
            ..rect = renderOffset & renderSize
            ..zoom = true);
        } else {
          _tapTargets.add(TapTarget()
            ..entry = favorite
            ..rect = renderOffset & renderSize
            ..zoom = true);
        }
      }

      // do labels
      TimelineEntry previous;
      for (TimelineEntry favorite in _favorites) {
        if (favorite.isFavoriteOccluded) {
          continue;
        }
        if (previous != null) {
          double distance = (favorite.favoriteY - previous.favoriteY);
          if (distance > favoritesRadius * 2.0) {
            canvas.drawLine(Offset(x, previous.favoriteY + favoritesRadius),
                Offset(x, favorite.favoriteY - favoritesRadius), accentPaint);
            double labelY = previous.favoriteY + distance / 2.0;
            double labelWidth = 37.0;
            double labelHeight = 8.5 * 2.0;
            if (distance - favoritesRadius * 2.0 > labelHeight) {
              ui.ParagraphBuilder builder = ui.ParagraphBuilder(
                  ui.ParagraphStyle(
                      textAlign: TextAlign.center,
                      fontFamily: "RobotoMedium",
                      fontSize: 10.0))
                ..pushStyle(ui.TextStyle(color: Colors.white));

              int value = (favorite.start - previous.start).round().abs();
              String label;
              if (value < 9000) {
                label = value.toStringAsFixed(0);
              } else {
                NumberFormat formatter = NumberFormat.compact();
                label = formatter.format(value);
              }

              builder.addText(label);
              ui.Paragraph distanceParagraph = builder.build();
              distanceParagraph
                  .layout(ui.ParagraphConstraints(width: labelWidth));

              canvas.drawRRect(
                  RRect.fromRectAndRadius(
                      Rect.fromLTWH(x - labelWidth / 2.0,
                          labelY - labelHeight / 2.0, labelWidth, labelHeight),
                      Radius.circular(labelHeight)),
                  accentFill);
              canvas.drawParagraph(
                  distanceParagraph,
                  Offset(x - labelWidth / 2.0,
                      labelY - distanceParagraph.height / 2.0));
            }
          }
        }
        previous = favorite;
      }
    }
  }

  void drawItems(PaintingContext context, Offset offset,
      List<TimelineEntry> entries, double x, double scale, int depth) {
    final Canvas canvas = context.canvas;

    for (TimelineEntry item in entries) {
      if (!item.isVisible ||
          item.y > size.height + Timeline.BubbleHeight ||
          item.endY < -Timeline.BubbleHeight) {
        continue;
      }

      double legOpacity = item.legOpacity * item.opacity;
      Offset entryOffset = Offset(x + Timeline.LineWidth / 2.0, item.y);
      canvas.drawCircle(
          entryOffset,
          Timeline.EdgeRadius,
          Paint()
            ..color = (item.accent != null
                    ? item.accent
                    : LineColors[depth % LineColors.length])
                .withOpacity(item.opacity));
      // Make dots clickable
      // _tapTargets.add(new TapTarget()..entry=item..rect=new Rect.fromCircle(center:entryOffset, radius:Timeline.EdgeRadius*5.0)..zoom=true);
      if (legOpacity > 0.0) {
        Paint legPaint = Paint()
          ..color = (item.accent != null
                  ? item.accent
                  : LineColors[depth % LineColors.length])
              .withOpacity(legOpacity);
        canvas.drawRect(
            Offset(x, item.y) & Size(Timeline.LineWidth, item.length),
            legPaint);
        canvas.drawCircle(
            Offset(x + Timeline.LineWidth / 2.0, item.y + item.length),
            Timeline.EdgeRadius,
            legPaint);
      }

      const double MaxLabelWidth = 1200.0;
      const double BubblePadding = 20.0;
      double bubbleHeight = timeline.bubbleHeight(item);

      ui.ParagraphBuilder builder = ui.ParagraphBuilder(ui.ParagraphStyle(
          textAlign: TextAlign.start, fontFamily: "Roboto", fontSize: 20.0))
        ..pushStyle(
            ui.TextStyle(color: const Color.fromRGBO(255, 255, 255, 1.0)));

      builder.addText(item.label);
      ui.Paragraph labelParagraph = builder.build();
      labelParagraph.layout(ui.ParagraphConstraints(width: MaxLabelWidth));
      //canvas.drawParagraph(labelParagraph, new Offset(offset.dx + Gutter - labelParagraph.minIntrinsicWidth-2, offset.dy + height - o - labelParagraph.height - 5));

      double textWidth =
          labelParagraph.maxIntrinsicWidth * item.opacity * item.labelOpacity;
      // ctx.globalAlpha = labelOpacity*itemOpacity;
      // ctx.save();
      // let bubbleX = labelX-DepthOffset*renderOffsetDepth;
      double bubbleX = _timeline.renderLabelX -
          Timeline.DepthOffset * _timeline.renderOffsetDepth;
      double bubbleY = item.labelY - bubbleHeight / 2.0;

      canvas.save();
      canvas.translate(bubbleX, bubbleY);
      Path bubble =
          makeBubblePath(textWidth + BubblePadding * 2.0, bubbleHeight);
      canvas.drawPath(
          bubble,
          Paint()
            ..color = (item.accent != null
                    ? item.accent
                    : LineColors[depth % LineColors.length])
                .withOpacity(item.opacity * item.labelOpacity));
      canvas
          .clipRect(Rect.fromLTWH(BubblePadding, 0.0, textWidth, bubbleHeight));
      _tapTargets.add(TapTarget()
        ..entry = item
        ..rect = Rect.fromLTWH(
            bubbleX, bubbleY, textWidth + BubblePadding * 2.0, bubbleHeight));

      canvas.drawParagraph(
          labelParagraph,
          Offset(
              BubblePadding, bubbleHeight / 2.0 - labelParagraph.height / 2.0));
      canvas.restore();
      // if(item.asset != null)
      // {
      // 	canvas.drawImageRect(item.asset.image, Rect.fromLTWH(0.0, 0.0, item.asset.width, item.asset.height), Rect.fromLTWH(bubbleX + textWidth + BubblePadding*2.0, bubbleY, item.asset.width, item.asset.height), new Paint()..isAntiAlias=true..filterQuality=ui.FilterQuality.low);
      // }
      if (item.children != null) {
        drawItems(context, offset, item.children, x + Timeline.DepthOffset,
            scale, depth + 1);
      }
    }
  }

  Path makeBubblePath(double width, double height) {
    const double ArrowSize = 19.0;
    const double CornerRadius = 10.0;

    const double circularConstant = 0.55;
    const double icircularConstant = 1.0 - circularConstant;

    Path path = Path();

    path.moveTo(CornerRadius, 0.0);
    path.lineTo(width - CornerRadius, 0.0);
    path.cubicTo(width - CornerRadius + CornerRadius * circularConstant, 0.0,
        width, CornerRadius * icircularConstant, width, CornerRadius);
    path.lineTo(width, height - CornerRadius);
    path.cubicTo(
        width,
        height - CornerRadius + CornerRadius * circularConstant,
        width - CornerRadius * icircularConstant,
        height,
        width - CornerRadius,
        height);
    path.lineTo(CornerRadius, height);
    path.cubicTo(CornerRadius * icircularConstant, height, 0.0,
        height - CornerRadius * icircularConstant, 0.0, height - CornerRadius);

    path.lineTo(0.0, height / 2.0 + ArrowSize / 2.0);
    path.lineTo(-ArrowSize / 2.0, height / 2.0);
    path.lineTo(0.0, height / 2.0 - ArrowSize / 2.0);

    path.lineTo(0.0, CornerRadius);

    path.cubicTo(0.0, CornerRadius * icircularConstant,
        CornerRadius * icircularConstant, 0.0, CornerRadius, 0.0);

    path.close();

    return path;
  }
}
