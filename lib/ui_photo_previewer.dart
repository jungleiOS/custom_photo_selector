import 'dart:async';
import 'dart:io';

import 'package:custom_photo_selector/locally_available_builder.dart';
import 'package:custom_photo_selector/photo_picker_provider.dart';
import 'package:custom_photo_selector/ui_navigation_bar.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

class UIPhotoPreviewer extends StatefulWidget {
  const UIPhotoPreviewer({
    super.key,
    required this.previewAssets,
    required this.provider,
    this.initialIndex = 0,
    this.showConfirm = true,
    this.returnEmptyList = false,
    this.maxCount,
    this.onSelected,
  });

  final List<AssetEntity> previewAssets;
  final PhotoPickerProvider provider;
  final int initialIndex;
  final bool showConfirm;

  ///   是否返回空列表
  final bool returnEmptyList;
  final int? maxCount;
  final ValueChanged<List<AssetEntity>>? onSelected;

  @override
  State<StatefulWidget> createState() => _UIPhotoPreviewerState();

  static Future<List<AssetEntity>?> show(
    BuildContext context, {
    required List<AssetEntity> previewAssets,
    PhotoPickerProvider? provider,
    int initialIndex = 0,
    bool showConfirm = true,
    bool returnEmptyList = false,
    int? maxCount,
    ValueChanged<List<AssetEntity>>? onSelected,
  }) {
    provider ??= PhotoPickerProvider(
      maxAssets: previewAssets.length,
      selectedAssets: previewAssets,
    );
    return Navigator.of(context, rootNavigator: true).push<List<AssetEntity>?>(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
        ) {
          return UIPhotoPreviewer(
            previewAssets: previewAssets,
            provider: provider!,
            initialIndex: initialIndex,
            showConfirm: showConfirm,
            returnEmptyList: returnEmptyList,
            maxCount: maxCount,
            onSelected: onSelected,
          );
        },
        transitionsBuilder: (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) {
          final tween = Tween(begin: const Offset(0, 1), end: Offset.zero)
              .chain(CurveTween(curve: Curves.ease));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }
}

class _UIPhotoPreviewerState extends State<UIPhotoPreviewer> {
  List<AssetEntity> get previewAssets => widget.previewAssets;

  int get initialIndex => widget.initialIndex;

  PhotoPickerProvider get provider => widget.provider;

  bool get showConfirm => widget.showConfirm;

  bool get returnEmptyList => widget.returnEmptyList;

  int? get maxCount => widget.maxCount;

  ValueChanged<List<AssetEntity>>? get onSelected => widget.onSelected;

  late final ExtendedPageController _controller =
      ExtendedPageController(initialPage: initialIndex);

  final ValueNotifier<bool> _needDisplayDetail = ValueNotifier(false);

  final ValueNotifier<int> _currentIndex = ValueNotifier(1);

  GlobalKey<ExtendedImageSlidePageState> slidePageKey =
      GlobalKey<ExtendedImageSlidePageState>();

  @override
  void initState() {
    super.initState();
    _currentIndex.value = initialIndex + 1;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    return ChangeNotifierProvider.value(
      value: provider,
      child: Scaffold(
        body: SizedBox(
          width: size.width,
          height: size.height,
          child: Stack(
            children: [
              GestureDetector(
                onTap: () {
                  _needDisplayDetail.value = !_needDisplayDetail.value;
                },
                child: ExtendedImageSlidePage(
                  key: slidePageKey,
                  slideAxis: SlideAxis.both,
                  slideType: SlideType.wholePage,
                  child: ExtendedImageGesturePageView.builder(
                    controller: _controller,
                    itemCount: previewAssets.length,
                    onPageChanged: (index) {
                      _currentIndex.value = index + 1;
                    },
                    itemBuilder: (context, index) {
                      final asset = previewAssets[index];
                      switch (asset.type) {
                        case AssetType.image:
                          return ImagePageBuilder(asset: asset);
                        case AssetType.video:
                          return VideoPageBuilder(asset: asset);
                        case AssetType.audio:
                          return AudioPageBuilder(asset: asset);
                        case AssetType.other:
                          return const SizedBox();
                      }
                    },
                  ),
                ),
              ),
              ValueListenableBuilder(
                valueListenable: _needDisplayDetail,
                builder: (context, needDisplay, child) {
                  final top = needDisplay
                      ? -(padding.top + UINavigationBar.toolbarHeight)
                      : 0.0;
                  return AnimatedPositionedDirectional(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    start: 0.0,
                    end: 0.0,
                    top: top,
                    child: child!,
                  );
                },
                child: UINavigationBar(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  left: GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.close,
                        size: 24.0,
                      ),
                    ),
                  ),
                  middle: ValueListenableBuilder(
                    valueListenable: _currentIndex,
                    builder: (context, value, child) {
                      return Text('$value / ${previewAssets.length}');
                    },
                  ),
                  right: ValueListenableBuilder(
                    valueListenable: _currentIndex,
                    builder: (context, currentIndex, child) {
                      if (!showConfirm) return const SizedBox();

                      final asset = previewAssets[currentIndex - 1];
                      return Selector<PhotoPickerProvider, List<AssetEntity>>(
                        builder: (context, selectedAssets, child) {
                          final index = context
                              .read<PhotoPickerProvider>()
                              .selectedAssets
                              .indexOf(asset);
                          final isSelected = index != -1;
                          final iconImage = isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off;
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (isSelected) {
                                context
                                    .read<PhotoPickerProvider>()
                                    .unSelectAsset(asset);
                              } else {
                                context
                                    .read<PhotoPickerProvider>()
                                    .selectAsset(asset);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Icon(
                                iconImage,
                                size: 20.0,
                                color: Colors.green,
                              ),
                            ),
                          );
                        },
                        selector: (_, provider) => provider.selectedAssets,
                      );
                    },
                  ),
                ),
              ),
              if (showConfirm)
                ValueListenableBuilder(
                  valueListenable: _needDisplayDetail,
                  builder: (context, needDisplay, child) {
                    final height = padding.bottom + 48.0 + 35.0 + 24.0;
                    final bottom = needDisplay ? -height : 0.0;
                    return AnimatedPositionedDirectional(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      start: 0.0,
                      end: 0.0,
                      bottom: bottom,
                      child: Container(
                        color: Theme.of(context)
                            .scaffoldBackgroundColor
                            .withOpacity(0.5),
                        height: height,
                        child: child!,
                      ),
                    );
                  },
                  child: ValueListenableBuilder(
                    valueListenable: _currentIndex,
                    builder: (context, currentIndex, child) {
                      final currentAsset = previewAssets[currentIndex - 1];
                      return Selector<PhotoPickerProvider, List<AssetEntity>>(
                        builder: (context, selectedAssets, child) {
                          final maxCount =
                              context.read<PhotoPickerProvider>().maxAssets;
                          final confirmText = selectedAssets.isEmpty
                              ? '确认'
                              : '确认 ${selectedAssets.length}/$maxCount';
                          final disabled = selectedAssets.isEmpty &&
                              !returnEmptyList &&
                              widget.maxCount != 1;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8.0),
                                child: SizedBox(
                                  height: 48.0,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: selectedAssets.length,
                                    itemBuilder: (context, index) {
                                      final asset = selectedAssets[index];
                                      final isViewing = asset == currentAsset;
                                      final border = isViewing
                                          ? Border.all(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .secondary,
                                              width: 3,
                                            )
                                          : null;
                                      return GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () {
                                          final pageIndex =
                                              previewAssets.indexOf(asset);
                                          _controller.jumpToPage(pageIndex);
                                          _currentIndex.value = pageIndex + 1;
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8.0),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 300),
                                            width: 48.0,
                                            height: 48.0,
                                            decoration:
                                                BoxDecoration(border: border),
                                            child: AssetEntityImage(
                                              asset,
                                              isOriginal: false,
                                              thumbnailSize:
                                                  const ThumbnailSize.square(
                                                      300),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  if (disabled) return;

                                  if (widget.maxCount == 1) {
                                    onSelected?.call([currentAsset]);
                                    Navigator.pop(context);
                                    Navigator.pop(context);
                                  } else {
                                    Navigator.of(context).pop(selectedAssets);
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 15.0),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: disabled
                                          ? Colors.black
                                          : Colors.green,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 5.0),
                                      child: Text(
                                        confirmText,
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            ],
                          );
                        },
                        selector: (_, provider) => provider.selectedAssets,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _needDisplayDetail.dispose();
    _currentIndex.dispose();
    super.dispose();
  }
}

class ImagePageBuilder extends StatefulWidget {
  const ImagePageBuilder({
    super.key,
    required this.asset,
    this.previewThumbnailSize,
    this.shouldAutoplayPreview = false,
  });

  final AssetEntity asset;
  final ThumbnailSize? previewThumbnailSize;
  final bool shouldAutoplayPreview;
  @override
  State<StatefulWidget> createState() => _ImagePageBuilderState();
}

class _ImagePageBuilderState extends State<ImagePageBuilder>
    with SingleTickerProviderStateMixin {
  AssetEntity get asset => widget.asset;

  ThumbnailSize? get previewThumbnailSize => widget.previewThumbnailSize;

  bool get shouldAutoplayPreview => widget.shouldAutoplayPreview;

  bool get _isOriginal => widget.previewThumbnailSize == null;

  bool get _isLivePhoto => widget.asset.isLivePhoto;
  bool _isLocallyAvailable = false;
  VideoPlayerController? _controller;

  AnimationController? _animationController;
  Animation<double>? _curveAnimation;
  late VoidCallback doubleTapListener;
  Animation<double>? doubleTapAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _curveAnimation = CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeInOut,
    );
  }

  @override
  void didUpdateWidget(ImagePageBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.asset != oldWidget.asset ||
        widget.previewThumbnailSize != oldWidget.previewThumbnailSize) {
      _isLocallyAvailable = false;
      _controller
        ?..pause()
        ..dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _animationController?.dispose();
    super.dispose();
  }

  Widget _imageBuilder(BuildContext context, AssetEntity asset) {
    return ExtendedImage(
      image: AssetEntityImageProvider(
        asset,
        isOriginal: _isOriginal,
        thumbnailSize: widget.previewThumbnailSize,
      ),
      fit: BoxFit.contain,
      mode: ExtendedImageMode.gesture,
      enableSlideOutPage: true,
      onDoubleTap: (state) {
        final double begin = state.gestureDetails!.totalScale!;
        final double end = state.gestureDetails!.totalScale! == 1.0 ? 3.0 : 1.0;
        final Offset pointerDownPosition = state.pointerDownPosition!;

        doubleTapAnimation?.removeListener(doubleTapListener);
        _animationController!
          ..stop()
          ..reset();
        doubleTapListener = () {
          state.handleDoubleTap(
            scale: doubleTapAnimation!.value,
            doubleTapPosition: pointerDownPosition,
          );
        };
        doubleTapAnimation = Tween<double>(
          begin: begin,
          end: end,
        ).animate(_curveAnimation!)
          ..addListener(doubleTapListener);
        _animationController!.forward();
      },
      initGestureConfigHandler: (ExtendedImageState state) => GestureConfig(
        minScale: 1.0,
        maxScale: 3.0,
        animationMinScale: 0.6,
        animationMaxScale: 4.0,
        inPageView: true,
      ),
      loadStateChanged: (ExtendedImageState state) {
        final hasLoaded = state.extendedImageLoadState == LoadState.completed;
        return switch (state.extendedImageLoadState) {
          LoadState.completed => hasLoaded
              ? state.completedWidget
              : TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 150),
                  builder: (_, double value, Widget? w) => Opacity(
                    opacity: value,
                    child: w,
                  ),
                  child: state.completedWidget,
                ),
          LoadState.failed => const Text('加载失败'),
          LoadState.loading => const SizedBox.shrink(),
        };
      },
    );
  }

  Widget _buildLivePhotosWrapper(BuildContext context, AssetEntity asset) {
    return Stack(
      children: <Widget>[
        if (_controller?.value.isInitialized ?? false)
          Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: _controller!,
                builder: (_, VideoPlayerValue value, Widget? child) {
                  return Opacity(
                    opacity: value.isPlaying ? 1 : 0,
                    child: child,
                  );
                },
                child: VideoPlayer(_controller!),
              ),
            ),
          ),
        if (_controller == null)
          Positioned.fill(child: _imageBuilder(context, asset))
        else
          Positioned.fill(
            child: ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: _controller!,
              builder: (_, VideoPlayerValue value, Widget? child) {
                return Opacity(
                  opacity: value.isPlaying ? 0 : 1,
                  child: child,
                );
              },
              child: _imageBuilder(context, asset),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LocallyAvailableBuilder(
      key: ValueKey<String>(widget.asset.id),
      asset: widget.asset,
      isOriginal: _isOriginal,
      builder: (BuildContext context, AssetEntity asset) {
        // Initialize the video controller when the asset is a Live photo
        // and available for further use.
        if (!_isLocallyAvailable && _isLivePhoto) {
          _initializeLivePhoto();
        }
        _isLocallyAvailable = true;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          // onTap: widget.delegate.switchDisplayingDetail,
          onLongPress: _isLivePhoto ? _play : null,
          onLongPressEnd: _isLivePhoto
              ? (_) {
                  _stop();
                }
              : null,
          child: Builder(
            builder: (BuildContext context) {
              if (!_isLivePhoto) {
                return _imageBuilder(context, asset);
              }
              return _buildLivePhotosWrapper(context, asset);
            },
          ),
        );
      },
    );
  }

  Future<void> _initializeLivePhoto() async {
    final File? file;
    if (_isOriginal) {
      file = await widget.asset.originFileWithSubtype;
    } else {
      file = await widget.asset.fileWithSubtype;
    }
    if (!mounted || file == null) {
      return;
    }
    final VideoPlayerController c = VideoPlayerController.file(
      file,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    setState(() {
      _controller = c;
    });
    c
      ..initialize().then((_) {
        if (widget.shouldAutoplayPreview) {
          _play();
        }
      })
      ..setVolume(0)
      ..addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
  }

  void _play() {
    if (_controller?.value.isInitialized ?? false) {
      // Only impact when initialized.
      HapticFeedback.lightImpact();
      _controller?.play();
    }
  }

  Future<void> _stop() async {
    await _controller?.pause();
    await _controller?.seekTo(Duration.zero);
  }
}

class VideoPageBuilder extends StatefulWidget {
  const VideoPageBuilder({
    super.key,
    required this.asset,
    this.shouldAutoplayPreview = false,
  });

  final AssetEntity asset;
  final bool shouldAutoplayPreview;

  @override
  State<VideoPageBuilder> createState() => _VideoPageBuilderState();
}

class _VideoPageBuilderState extends State<VideoPageBuilder> {
  AssetEntity get asset => widget.asset;

  bool get shouldAutoplayPreview => widget.shouldAutoplayPreview;

  /// Controller for the video player.
  /// 视频播放的控制器
  VideoPlayerController get controller => _controller!;
  VideoPlayerController? _controller;

  /// Whether the controller has initialized.
  /// 控制器是否已初始化
  bool hasLoaded = false;

  /// Whether there's any error when initialize the video controller.
  /// 初始化视频控制器时是否发生错误
  bool hasErrorWhenInitializing = false;

  /// Whether the player is playing.
  /// 播放器是否在播放
  final ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);

  /// Whether the controller is playing.
  /// 播放控制器是否在播放
  bool get isControllerPlaying => _controller?.value.isPlaying ?? false;

  bool _isInitializing = false;
  bool _isLocallyAvailable = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(VideoPageBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.asset != oldWidget.asset) {
      _controller
        ?..removeListener(videoPlayerListener)
        ..pause()
        ..dispose();
      _controller = null;
      hasLoaded = false;
      hasErrorWhenInitializing = false;
      isPlaying.value = false;
      _isInitializing = false;
      _isLocallyAvailable = false;
    }
  }

  @override
  void dispose() {
    /// Remove listener from the controller and dispose it when widget dispose.
    /// 部件销毁时移除控制器的监听并销毁控制器。
    _controller
      ?..removeListener(videoPlayerListener)
      ..pause()
      ..dispose();
    super.dispose();
  }

  /// Get media url from the asset, then initialize the controller and add with a listener.
  /// 从资源获取媒体url后初始化，并添加监听。
  Future<void> initializeVideoPlayerController() async {
    _isInitializing = true;
    _isLocallyAvailable = true;
    final String? url = await widget.asset.getMediaUrl();
    if (url == null) {
      hasErrorWhenInitializing = true;
      if (mounted) {
        setState(() {});
      }
      return;
    }
    final Uri uri = Uri.parse(url);
    if (Platform.isAndroid) {
      _controller = VideoPlayerController.contentUri(uri);
    } else {
      _controller = VideoPlayerController.networkUrl(uri);
    }
    try {
      await controller.initialize();
      hasLoaded = true;
      controller
        ..addListener(videoPlayerListener)
        ..setLooping(false);
      if (shouldAutoplayPreview) {
        controller.play();
      }
    } catch (e, s) {
      FlutterError.presentError(
        FlutterErrorDetails(
          exception: e,
          stack: s,
          library: 'local',
          silent: true,
        ),
      );
      hasErrorWhenInitializing = true;
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  /// Listener for the video player.
  /// 播放器的监听方法
  void videoPlayerListener() {
    if (isControllerPlaying != isPlaying.value) {
      isPlaying.value = isControllerPlaying;
    }
  }

  /// Callback for the play button.
  /// 播放按钮的回调
  ///
  /// Normally it only switches play state for the player. If the video reaches the end,
  /// then click the button will make the video replay.
  /// 一般来说按钮只切换播放暂停。当视频播放结束时，点击按钮将从头开始播放。
  Future<void> playButtonCallback(BuildContext context) async {
    if (isPlaying.value) {
      controller.pause();
      return;
    }
    if (controller.value.duration == controller.value.position) {
      controller
        ..seekTo(Duration.zero)
        ..play();
      return;
    }
    controller.play();
  }

  Widget _contentBuilder(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned.fill(
          child: Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: isPlaying,
          builder: (_, bool value, __) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: value || MediaQuery.accessibleNavigationOf(context)
                ? () {
                    playButtonCallback(context);
                  }
                : null,
            child: Center(
              child: AnimatedOpacity(
                duration: kThemeAnimationDuration,
                opacity: value ? 0.0 : 1.0,
                child: GestureDetector(
                  onTap: () {
                    playButtonCallback(context);
                  },
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      boxShadow: <BoxShadow>[
                        BoxShadow(color: Colors.black12),
                      ],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      value
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_filled,
                      size: 70.0,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LocallyAvailableBuilder(
      key: ValueKey(asset.id),
      asset: asset,
      builder: (context, asset) {
        if (hasErrorWhenInitializing) {
          return const Center(
            child: Text('加载失败'),
          );
        }
        if (!_isLocallyAvailable && !_isInitializing) {
          initializeVideoPlayerController();
        }
        if (!hasLoaded) {
          return const SizedBox.shrink();
        }
        return _contentBuilder(context);
      },
    );
  }
}

class AudioPageBuilder extends StatefulWidget {
  const AudioPageBuilder({
    super.key,
    required this.asset,
    this.shouldAutoplayPreview = false,
  });

  /// Asset currently displayed.
  /// 展示的资源
  final AssetEntity asset;

  /// Whether the preview should auto play.
  /// 预览是否自动播放
  final bool shouldAutoplayPreview;

  @override
  State<StatefulWidget> createState() => _AudioPageBuilderState();
}

class _AudioPageBuilderState extends State<AudioPageBuilder> {
  /// A [StreamController] for current position of the [_controller].
  /// 控制器当前的播放进度
  final StreamController<Duration> durationStreamController =
      StreamController<Duration>.broadcast();

  /// Create a [VideoPlayerController] instance for the page builder state.
  /// 创建一个 [VideoPlayerController] 的实例
  VideoPlayerController get controller => _controller!;
  VideoPlayerController? _controller;

  /// Whether the audio loaded.
  /// 音频是否已经加载完成
  bool isLoaded = false;

  /// Whether the player is playing.
  /// 播放器是否在播放
  bool isPlaying = false;

  /// Whether the controller is playing.
  /// 播放控制器是否在播放
  bool get isControllerPlaying => _controller?.value.isPlaying == true;

  /// Duration of the audio.
  /// 音频的时长
  Duration assetDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    openAudioFile();
  }

  @override
  void didUpdateWidget(AudioPageBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.asset != oldWidget.asset) {
      _controller
        ?..removeListener(audioPlayerListener)
        ..pause()
        ..dispose();
      isLoaded = false;
      isPlaying = false;
      assetDuration = Duration.zero;
      openAudioFile();
    }
  }

  @override
  void dispose() {
    /// Stop and dispose player instance to stop playing
    /// when dispose (e.g. page switched).
    /// 状态销毁时停止并销毁实例（例如页面切换时）
    _controller
      ?..removeListener(audioPlayerListener)
      ..pause()
      ..dispose();
    super.dispose();
  }

  /// Load content url from the asset.
  /// 通过content地址加载资源
  Future<void> openAudioFile() async {
    try {
      final String? url = await widget.asset.getMediaUrl();
      assetDuration = Duration(seconds: widget.asset.duration);
      _controller = VideoPlayerController.networkUrl(Uri.parse(url!));
      await controller.initialize();
      controller.addListener(audioPlayerListener);
      if (widget.shouldAutoplayPreview) {
        controller.play();
      }
    } catch (e, s) {
      FlutterError.presentError(
        FlutterErrorDetails(
          exception: e,
          stack: s,
          library: 'local',
          silent: true,
        ),
      );
    } finally {
      isLoaded = true;
      if (mounted) {
        setState(() {});
      }
    }
  }

  /// Listener for the player.
  /// 播放器的监听方法
  void audioPlayerListener() {
    if (isControllerPlaying != isPlaying) {
      isPlaying = isControllerPlaying;
      if (mounted) {
        setState(() {});
      }
    }

    /// Add the current position into the stream.
    durationStreamController.add(controller.value.position);
  }

  void playButtonCallback() {
    if (isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
  }

  /// Title widget.
  /// 标题组件
  Widget get titleWidget {
    return Text(
      widget.asset.title ?? '',
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.normal),
    );
  }

  /// Button to control audio play/pause.
  /// 控制音频播放或暂停的按钮
  Widget get audioControlButton {
    return GestureDetector(
      onTap: playButtonCallback,
      child: Container(
        margin: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          boxShadow: <BoxShadow>[BoxShadow(color: Colors.black12)],
          shape: BoxShape.circle,
        ),
        child: Icon(
          isPlaying ? Icons.pause_circle_outline : Icons.play_circle_filled,
          size: 70,
        ),
      ),
    );
  }

  /// Duration indicator for the audio.
  /// 音频的时长指示器
  Widget get durationIndicator {
    final String Function(Duration) durationBuilder = durationIndicatorBuilder;
    return StreamBuilder<Duration>(
      initialData: Duration.zero,
      stream: durationStreamController.stream,
      builder: (BuildContext _, AsyncSnapshot<Duration> data) {
        return Text(
          '${durationBuilder(data.data!)} / ${durationBuilder(assetDuration)}',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.normal,
          ),
        );
      },
    );
  }

  /// This is used in video asset item in the picker, in order
  /// to display the duration of the video or audio type of asset.
  /// 该字段用在选择器视频或音频部件上，用于显示视频或音频资源的时长。
  String durationIndicatorBuilder(Duration duration) {
    const String separator = ':';
    final String minute = duration.inMinutes.toString().padLeft(2, '0');
    final String second = (duration - Duration(minutes: duration.inMinutes))
        .inSeconds
        .toString()
        .padLeft(2, '0');
    return '$minute$separator$second';
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: isLoaded
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                titleWidget,
                audioControlButton,
                durationIndicator,
              ],
            )
          : const SizedBox.shrink(),
    );
  }
}
