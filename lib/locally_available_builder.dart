import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

/// An asset builder that builds according to the locally available state.
final class LocallyAvailableBuilder extends StatefulWidget {
  const LocallyAvailableBuilder({
    super.key,
    required this.asset,
    this.isOriginal = true,
    required this.builder,
    this.progressBuilder,
  });

  final AssetEntity asset;
  final bool isOriginal;
  final Widget Function(BuildContext context, AssetEntity asset) builder;
  final Widget Function(
    BuildContext context,
    PMRequestState? state,
    double? progress,
  )? progressBuilder;

  @override
  State<LocallyAvailableBuilder> createState() =>
      _LocallyAvailableBuilderState();
}

class _LocallyAvailableBuilderState extends State<LocallyAvailableBuilder> {
  AssetEntity get asset => widget.asset;

  bool get isOriginal => widget.isOriginal;

  Widget Function(BuildContext context, AssetEntity asset) get builder =>
      widget.builder;

  Widget Function(
    BuildContext context,
    PMRequestState? state,
    double? progress,
  )? get progressBuilder => widget.progressBuilder;

  bool _hasError = false;
  bool _isLocallyAvailable = false;
  PMProgressHandler? _progressHandler;

  @override
  void initState() {
    super.initState();
    _checkLocallyAvailable();
  }

  @override
  void didUpdateWidget(LocallyAvailableBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (asset != oldWidget.asset || isOriginal != oldWidget.isOriginal) {
      _isLocallyAvailable = false;
      _progressHandler = null;
      _checkLocallyAvailable();
    }
  }

  void _markAndPresentError(Object exception, StackTrace stack) {
    _hasError = true;
    safeSetState(() {});
    FlutterError.presentError(
      FlutterErrorDetails(
        exception: exception,
        stack: stack,
        library: 'LocallyAvailableBuilder(${asset.id})',
      ),
    );
  }

  Future<void> _checkLocallyAvailable() async {
    try {
      _isLocallyAvailable =
          await asset.isLocallyAvailable(isOrigin: isOriginal);
    } catch (e, s) {
      _markAndPresentError(e, s);
      rethrow;
    } finally {
      safeSetState(() {});
    }
    if (!mounted || _isLocallyAvailable) {
      return;
    }
    final handler = PMProgressHandler();
    safeSetState(() {
      _progressHandler = handler;
    });
    asset
        .loadFile(
      isOrigin: isOriginal,
      withSubtype: true,
      progressHandler: handler,
    )
        .then((file) {
      if (file != null) {
        _isLocallyAvailable = true;
      }
    }).catchError((e, s) {
      _markAndPresentError(e, s);
    }).whenComplete(() {
      safeSetState(() {});
    });
    handler.stream.listen((PMProgressState s) {
      assert(() {
        dev.log('Handling progress for asset: $s.', name: asset.id);
        return true;
      }());
      if (s.state == PMRequestState.success) {
        _isLocallyAvailable = true;
        safeSetState(() {});
      }
    });
  }

  Widget _buildErrorIndicator(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.warning_amber_rounded,
        // color: context.iconTheme.color?.withOpacity(.4),
        size: 28,
      ),
    );
  }

  Widget _buildIndicator(BuildContext context) {
    return StreamBuilder<PMProgressState>(
      stream: _progressHandler?.stream,
      initialData: const PMProgressState(0, PMRequestState.prepare),
      builder: (BuildContext c, AsyncSnapshot<PMProgressState> s) {
        final PMRequestState? state = s.data?.state;
        final double? progress = s.data?.progress;
        if (progressBuilder case final builder?) {
          return builder(context, state, progress);
        }
        return Row(
          children: [
            Icon(
              state == PMRequestState.failed
                  ? Icons.cloud_off_rounded
                  : Icons.cloud_download_outlined,
              // color: context.iconTheme.color?.withOpacity(.4),
              size: 28,
            ),
            if (state != PMRequestState.success &&
                state != PMRequestState.failed)
              Text(
                '  iCloud ${((progress ?? 0) * 100).toInt()}%',
                style: const TextStyle(
                    // color: context.textTheme.bodyMedium?.color?.withOpacity(.4),
                    ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocallyAvailable) {
      return builder(context, asset);
    }
    if (_hasError) {
      return _buildErrorIndicator(context);
    }
    if (_progressHandler == null) {
      return const SizedBox.shrink();
    }
    return Center(child: FittedBox(child: _buildIndicator(context)));
  }
}

/// Common extensions for the [State].
extension SafeSetStateExtension on State {
  /// [setState] after the [fn] is done while the [State] is still [mounted]
  /// and [State.context] is safe to mark needs build.
  FutureOr<void> safeSetState(FutureOr<dynamic> Function() fn) async {
    await fn();
    if (mounted &&
        !context.debugDoingBuild &&
        context.owner?.debugBuilding != true) {
      // ignore: invalid_use_of_protected_member
      setState(() {});
    }
  }
}
