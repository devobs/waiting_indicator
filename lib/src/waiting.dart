import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

typedef WaitingIndicatorBuilder = Widget Function(
    BuildContext context, Color? color);

typedef LayerWaitingBuilder = Widget Function(
    BuildContext context,
    Animation<double> animation,
    Widget waitingIndicator,
    bool displayChildWhileWaiting);

typedef WaitingCallHandler<T> = Future<T> Function(
    BuildContext context, FutureOr<T> Function() callback);

/// Widget mutualisé d'indication d'attente.
class WaitingIndicator extends StatelessWidget {
  final Color? color;
  const WaitingIndicator({Key? key, this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget indicator;
    try {
      final nested = Provider.of<_NestedWaitingIndicatorState>(context);
      indicator = nested._indicatorBuilder!(context, color);
    } on ProviderNotFoundException {
      indicator =
          NestedWaitingIndicator.defaultIndicatorBuilder(context, color);
    }

    return indicator;
  }

  static Future<T> wait<T>(
          BuildContext context, FutureOr<T> Function() callback) =>
      Provider.of<_NestedWaitingIndicatorState>(context, listen: false)
          .wait<T>(context, callback);
}

/// Widget permettant d'afficher un indicateur local au Widget.
/// Ainsi un widget fils de [child] peut appeler lors d'un traitement
/// [_AnimatedWaitingIndicator.wait] pour afficher le temps du traitement
/// l'indicateur.
class NestedWaitingIndicator extends StatefulWidget {
  /// L'élément fils qui sera recouvert par le spinner d'attente
  final Widget child;

  /// La couleur de fond de l'attente
  final LayerWaitingBuilder? layerWaitingBuilder;

  /// Si [waiting] est à vrai alors l'indicateur est affiché et [child] n'est
  /// plus cliquable.
  final bool waiting;

  /// Si [displayChildWhileWaiting] est à vrai, [child] est affiché quand
  /// [waiting] est à true.
  /// Si aucune valeur n'est passée ou n'a été définie dans un
  /// [NestedWaitingIndicator] parent, alors la valeur est `true`.
  final bool? displayChildWhileWaiting;

  /// Permet de redéfinir l'indicateur. Le paramètre [color] permet de
  /// personnaliser la couleur de l'indicateur passé dans
  /// [WaitingIndicator.color]
  final WaitingIndicatorBuilder? indicatorBuilder;

  /// Gère l'appel des fonctions pour uniformiser l'affichage des erreurs
  /// durant l'appel par exemple.
  final WaitingCallHandler? waitingCallHandler;

  /// La durée de la transition en bascule true/false sur [waiting]
  final Duration? duration;

  /// Si à [true] Indique que les [WaitingIndicator] et [NestedWaitingIndicator]
  /// héritent des propriétés de cet objet pour l'affichage.
  final bool? inherit;

  const NestedWaitingIndicator(
      {Key? key,
      required this.child,
      this.waiting = false,
      this.displayChildWhileWaiting,
      this.layerWaitingBuilder,
      this.indicatorBuilder,
      this.waitingCallHandler,
      this.duration,
      this.inherit})
      : super(key: key);

  /// Cette méthode permet de redéfinir le comportement par défaut de l'animation
  /// d'attente. L'appel de cette méthode désactive donc l'indicateur d'attente
  /// par défaut
  static Widget listen<T>(
      {Key? key,
      required Widget Function(BuildContext context, AsyncSnapshot<T> snapshot)
          builder}) {
    return Builder(
        key: key,
        builder: (context) => ValueListenableBuilder<Future<T>?>(
            valueListenable: Provider.of<_NestedWaitingIndicatorState>(context,
                    listen: false)
                ._resultListenerForAnimation as ValueNotifier<Future<T>?>,
            builder: (context, value, child) {
              return FutureBuilder<T>(
                  future: value,
                  builder: (context, snapshot) => builder(context, snapshot));
            }));
  }

  static Widget defaultIndicatorBuilder(BuildContext context, Color? color) =>
      !kIsWeb && Platform.isMacOS
          ? const CupertinoActivityIndicator()
          : CircularProgressIndicator(
              valueColor: color == null ? null : AlwaysStoppedAnimation(color));

  static Widget defaultLayerWaitingBuilder(
          BuildContext context,
          Animation<double> animation,
          Widget waitingIndicator,
          bool displayChildWhileWaiting,
          {Color backgroundColor = Colors.black45}) =>
      FadeTransition(
        opacity: animation,
        child: Container(
            padding: MediaQuery.of(context).viewInsets,
            alignment: Alignment.center,
            color: displayChildWhileWaiting
                ? backgroundColor
                : Theme.of(context).scaffoldBackgroundColor,
            child: waitingIndicator),
      );

  @override
  State<NestedWaitingIndicator> createState() => _NestedWaitingIndicatorState();
}

class _NestedWaitingIndicatorState extends State<NestedWaitingIndicator> {
  var _displayWaiting = false;
  WaitingIndicatorBuilder? _indicatorBuilder;
  bool? _displayChildWhileWaiting;
  LayerWaitingBuilder? _layerWaitingBuilder;
  WaitingCallHandler? _waitingCallHandler;
  Duration? _duration;

  bool _resultListenerForAnimationNeeded = false;

  final _callBackResultNotifier = ValueNotifier<Future?>(null);

  final _childKey = GlobalKey();

  bool get _inherit => widget.inherit ?? widget.indicatorBuilder == null;

  ValueNotifier<Future?> get _resultListenerForAnimation {
    _resultListenerForAnimationNeeded = true;
    return _callBackResultNotifier;
  }

  @override
  void initState() {
    super.initState();

    _duration = widget.duration;
    _indicatorBuilder = widget.indicatorBuilder;
    _displayChildWhileWaiting = widget.displayChildWhileWaiting;
    _layerWaitingBuilder = widget.layerWaitingBuilder;
    _waitingCallHandler = widget.waitingCallHandler;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _udpateIndicator();
  }

  @override
  void didUpdateWidget(covariant NestedWaitingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    var mustUpdateIndicator = false;

    if (oldWidget.indicatorBuilder != widget.indicatorBuilder) {
      _indicatorBuilder = widget.indicatorBuilder;
      mustUpdateIndicator = true;
    }
    if (oldWidget.layerWaitingBuilder != widget.layerWaitingBuilder) {
      _layerWaitingBuilder = widget.layerWaitingBuilder;
      mustUpdateIndicator = true;
    }

    if (oldWidget.displayChildWhileWaiting != widget.displayChildWhileWaiting) {
      _displayChildWhileWaiting = widget.displayChildWhileWaiting;
      mustUpdateIndicator = true;
    }

    if (oldWidget.waitingCallHandler != widget.waitingCallHandler) {
      _waitingCallHandler = widget.waitingCallHandler;
      mustUpdateIndicator = true;
    }

    if (oldWidget.duration != widget.duration) {
      _duration = widget.duration;
      mustUpdateIndicator = true;
    }

    if (mustUpdateIndicator) _udpateIndicator();
  }

  static Future _defaultErrorHandlers(
          BuildContext context, FutureOr Function() callback) async =>
      await callback();

  void _udpateIndicator() {
    try {
      _NestedWaitingIndicatorState? nestedCache;
      // To limit usage of provider
      _NestedWaitingIndicatorState getNested() =>
          nestedCache ??= Provider.of<_NestedWaitingIndicatorState>(context);

      _indicatorBuilder ??= getNested()._indicatorBuilder;
      _layerWaitingBuilder ??= getNested()._layerWaitingBuilder;
      _displayChildWhileWaiting ??= getNested()._displayChildWhileWaiting;
      _waitingCallHandler ??= getNested()._waitingCallHandler;
      _duration ??= getNested()._duration;
    } on ProviderNotFoundException {
      _indicatorBuilder ??= NestedWaitingIndicator.defaultIndicatorBuilder;
      _displayChildWhileWaiting ??= true;
      _waitingCallHandler ??= _defaultErrorHandlers;
      _layerWaitingBuilder ??=
          NestedWaitingIndicator.defaultLayerWaitingBuilder;
      _duration ??= const Duration(milliseconds: 300);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget result = KeyedSubtree(key: _childKey, child: widget.child);
    if (_inherit) {
      result = Provider<_NestedWaitingIndicatorState>.value(
          value: this, child: result);
    }
    return _AnimatedWaitingIndicator(
        duration: _duration ?? const Duration(milliseconds: 300),
        waiting: _displayWaiting || widget.waiting,
        displayChildWhileWaiting:
            widget.displayChildWhileWaiting ?? _displayWaiting,
        indicatorBuilder: (context) => _indicatorBuilder!(context, null),
        layerWaitingBuilder: _layerWaitingBuilder!,
        child: result);
  }

  Future<T> wait<T>(
      BuildContext context, FutureOr<T> Function() callback) async {
    try {
      if (!_resultListenerForAnimationNeeded) {
        setState(() {
          _displayWaiting = true;
        });
      }
      _callBackResultNotifier.value = _waitingCallHandler!(context, callback);
      return await _callBackResultNotifier.value;
    } finally {
      if (mounted && !_resultListenerForAnimationNeeded) {
        setState(() {
          _displayWaiting = false;
        });
      }
    }
  }
}

class _AnimatedWaitingIndicator extends ImplicitlyAnimatedWidget {
  final Widget child;
  final bool waiting;
  final bool displayChildWhileWaiting;
  final LayerWaitingBuilder layerWaitingBuilder;
  final WidgetBuilder indicatorBuilder;

  const _AnimatedWaitingIndicator(
      {Key? key,
      required this.child,
      required this.waiting,
      required this.displayChildWhileWaiting,
      required this.indicatorBuilder,
      required this.layerWaitingBuilder,
      required Duration duration})
      : super(key: key, duration: duration);

  @override
  _AnimatedWaitingIndicatorState createState() =>
      _AnimatedWaitingIndicatorState();
}

class _AnimatedWaitingIndicatorState
    extends ImplicitlyAnimatedWidgetState<_AnimatedWaitingIndicator> {
  Tween<double>? _opacityTween;

  final _childKey = GlobalKey();
  var _withStack = false;

  bool _updateWithStack() {
    final oldWithStack = _withStack;
    _withStack = controller.isAnimating || widget.waiting;

    return oldWithStack != _withStack;
  }

  void _animationListener(status) {
    if (mounted && _updateWithStack()) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();

    _updateWithStack();

    controller.addStatusListener(_animationListener);
  }

  @override
  void dispose() {
    controller.removeStatusListener(_animationListener);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyedChild = KeyedSubtree(key: _childKey, child: widget.child);

    if (!_withStack) return keyedChild;

    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        if (widget.displayChildWhileWaiting || controller.isAnimating)
          keyedChild,
        Positioned.fill(
          child: widget.layerWaitingBuilder(
            context,
            _opacityTween!.animate(controller),
            widget.indicatorBuilder(context),
            widget.displayChildWhileWaiting,
          ),
        )
      ],
    );
  }

  @override
  void forEachTween(visitor) {
    _opacityTween = visitor(_opacityTween, widget.waiting ? 1.0 : 0.0,
        (value) => Tween<double>(begin: value)) as Tween<double>?;
  }
}
