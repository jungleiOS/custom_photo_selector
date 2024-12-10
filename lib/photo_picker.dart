import 'package:custom_photo_selector/photo_picker_provider.dart';
import 'package:custom_photo_selector/ui_navigation_bar.dart';
import 'package:custom_photo_selector/ui_photo_previewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:provider/provider.dart';

/// 选择资源后的返回结果。
typedef AssetsResult = (List<AssetEntity> assets, bool isOriginal);

class PhotoPicker extends StatefulWidget {
  const PhotoPicker({
    super.key,
    this.gridCount = 4,
    this.filter,
    this.maxCount = 9,
    this.onSelected,
    this.onOriginChange,
    this.selectPredicate,
    this.selectedAssets = const [],
    this.defaultOriginal,
    this.bottomBarHeaderBuilder,
    this.requestType = RequestType.common,
  });

  final int gridCount;

  /// 资源过滤器，[null] 则不过滤
  final AssetFilter? filter;
  final int maxCount;
  final ValueChanged<List<AssetEntity>>? onSelected;
  final ValueChanged<bool>? onOriginChange;
  final AssetSelectPredicate<AssetEntity>? selectPredicate;
  final List<AssetEntity> selectedAssets;

  /// 默认是否原图，[null] 不显示
  final bool? defaultOriginal;

  /// 底部栏头部
  final WidgetBuilder? bottomBarHeaderBuilder;

  /// Request assets type.
  /// 请求的资源类型
  final RequestType requestType;

  static Future<void> show(
    BuildContext context, {
    int gridCount = 4,

    /// 资源过滤器，[null] 则不过滤
    AssetFilter? filter,
    int maxCount = 9,
    ValueChanged<List<AssetEntity>>? onSelected,
    ValueChanged<bool>? onOriginChange,
    AssetSelectPredicate<AssetEntity>? selectPredicate,
    List<AssetEntity> selectedAssets = const [],

    /// 默认是否原图，[null] 不显示
    bool? defaultOriginal,

    /// 底部栏头部
    WidgetBuilder? bottomBarHeaderBuilder,

    /// Request assets type.
    /// 请求的资源类型
    RequestType requestType = RequestType.common,
  }) {
    return Navigator.of(context, rootNavigator: true).push<List<AssetEntity>?>(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
        ) {
          return PhotoPicker(
            gridCount: gridCount,
            filter: filter,
            maxCount: maxCount,
            onSelected: onSelected,
            onOriginChange: onOriginChange,
            selectPredicate: selectPredicate,
            selectedAssets: selectedAssets,
            defaultOriginal: defaultOriginal,
            bottomBarHeaderBuilder: bottomBarHeaderBuilder,
            requestType: requestType,
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

  @override
  State<PhotoPicker> createState() => _PhotoPickerState();
}

class _PhotoPickerState extends State<PhotoPicker>
    with TickerProviderStateMixin {
  int get gridCount => widget.gridCount;

  AssetFilter? get filter => widget.filter;

  int get maxCount => widget.maxCount;

  ValueChanged<List<AssetEntity>>? get onSelected => widget.onSelected;

  ValueChanged<bool>? get onOriginChange => widget.onOriginChange;

  AssetSelectPredicate<AssetEntity>? get selectPredicate =>
      widget.selectPredicate;

  List<AssetEntity> get selectedAssets => widget.selectedAssets;

  bool? get defaultOriginal => widget.defaultOriginal;

  WidgetBuilder? get bottomBarHeaderBuilder => widget.bottomBarHeaderBuilder;

  RequestType get requestType => widget.requestType;

  late final AnimationController _animationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  late final Animation<Offset> _position = Tween<Offset>(
    begin: const Offset(0, -1),
    end: Offset.zero,
  ).animate(_animationController);
  late final _opacity =
      Tween(begin: 0.0, end: 1.0).animate(_animationController);

  late final _scrollController = ScrollController();
  late final _assetProvider = PhotoPickerProvider(
    maxAssets: maxCount,
    selectPredicate: selectPredicate,
    filter: filter,
    selectedAssets: selectedAssets,
    requestType: requestType,
  );
  final ValueNotifier<bool> _showAlbumSelector = ValueNotifier(false);
  late bool _needOrigin = defaultOriginal ?? false;

  @override
  void initState() {
    super.initState();
    _assetProvider.getPaths();
    PhotoManager.addChangeCallback(_onAssetsUpdated);
    PhotoManager.startChangeNotify();
  }

  @override
  void dispose() {
    _showAlbumSelector.dispose();
    _animationController.dispose();
    _scrollController.dispose();
    PhotoManager.removeChangeCallback(_onAssetsUpdated);
    PhotoManager.stopChangeNotify();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final distanceTop = padding.top + 44;
    final contentHeight = size.height - distanceTop;

    return ChangeNotifierProvider(
      create: (_) => _assetProvider,
      child: PrimaryScrollController(
        controller: _scrollController,
        child: Scaffold(
          appBar: UINavigationBar(
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
            middle: Selector<PhotoPickerProvider, AssetPathEntity?>(
              selector: (_, PhotoPickerProvider p) => p.currentPath,
              builder: (_, path, child) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    final show = !_showAlbumSelector.value;
                    if (show) {
                      _animationController.forward();
                      _showAlbumSelector.value = show;
                    } else {
                      await _animationController.reverse();
                      _showAlbumSelector.value = show;
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(path?.name ?? ''),
                      ),
                      const Icon(
                        Icons.arrow_drop_down_circle_outlined,
                        size: 16,
                      )
                    ],
                  ),
                );
              },
            ),
            right: Selector<PhotoPickerProvider, bool>(
              selector: (_, p) => p.enableFilter,
              builder: (context, needFilter, child) {
                if (filter == null) return const SizedBox();

                final rightImageAsset = needFilter
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    context.read<PhotoPickerProvider>().enableFilter =
                        !needFilter;
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('仅显示未上传'),
                        const SizedBox(width: 4),
                        Icon(
                          rightImageAsset,
                          size: 20.0,
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          body: SizedBox(
            width: size.width,
            height: contentHeight,
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: MediaQuery.removePadding(
                        context: context,
                        removeTop: true,
                        removeBottom: true,
                        child: Selector<PhotoPickerProvider,
                            List<MonthlyAssetViewModel>>(
                          selector: (_, p) => p.monthlyAssets,
                          builder: (_,
                              List<MonthlyAssetViewModel> monthlyAssets,
                              child) {
                            return ListView.builder(
                              controller: _scrollController,
                              itemCount: monthlyAssets.length,
                              itemBuilder: (context, index) {
                                if (monthlyAssets.isEmpty) {
                                  return const SizedBox();
                                }
                                final viewModel = monthlyAssets[index];
                                return MonthlyAssetGroup(
                                  month: viewModel.month,
                                  assetList: viewModel.assetList,
                                  gridCount: gridCount,
                                  onSelected: onSelected,
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    BottomBar(
                      needOrigin: _needOrigin,
                      defaultOriginal: defaultOriginal,
                      bottomBarHeaderBuilder: bottomBarHeaderBuilder,
                      onOrigin: () {
                        _needOrigin = !_needOrigin;
                        setState(() {});
                        onOriginChange?.call(_needOrigin);
                      },
                      onPreview: () {
                        final previewAssets = _assetProvider.selectedAssets;
                        if (previewAssets.isEmpty) return;
                        UIPhotoPreviewer.show(
                          context,
                          previewAssets: previewAssets,
                          provider: _assetProvider,
                          maxCount: maxCount,
                          onSelected: onSelected,
                        );
                      },
                      onConfirm: () {
                        if (_assetProvider.selectedAssets.isEmpty) return;

                        onSelected?.call(_assetProvider.selectedAssets);
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
                ValueListenableBuilder(
                  valueListenable: _showAlbumSelector,
                  builder: (context, show, child) {
                    return Offstage(offstage: !show, child: child);
                  },
                  child: FadeTransition(
                    opacity: _opacity,
                    child: GestureDetector(
                      onTap: _fold,
                      child: Container(
                        alignment: Alignment.topCenter,
                        color: Colors.black.withOpacity(0.3),
                        child: SlideTransition(
                          position: _position,
                          child: Selector<PhotoPickerProvider,
                              List<AssetPathEntity>>(
                            selector: (_, p) => p.pathList,
                            builder: (context, List<AssetPathEntity> pathList,
                                child) {
                              return AlbumPathSelector(
                                pathList: pathList,
                                onCancel: _fold,
                                onSelected: (index) async {
                                  await context
                                      .read<PhotoPickerProvider>()
                                      .switchPath(pathList[index]);
                                  _scrollController.jumpTo(0.0);
                                  _fold();
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _fold() async {
    await _animationController.reverse();
    _showAlbumSelector.value = false;
  }

  void _onAssetsUpdated(MethodCall call) {
    _assetProvider.updateAssets();
  }
}

class MonthlyAssetGroup extends StatelessWidget {
  const MonthlyAssetGroup({
    super.key,
    this.month = '',
    this.assetList = const [],
    this.gridCount = 4,
    this.onSelected,
  });

  final String month;
  final List<AssetEntity> assetList;
  final int gridCount;
  final ValueChanged<List<AssetEntity>>? onSelected;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 8),
              Text(month),
              const Spacer(),
              Selector<PhotoPickerProvider, List<AssetEntity>>(
                builder: (context, selectedAssets, child) {
                  bool selectedAll = true;
                  for (final asset in assetList) {
                    if (!selectedAssets.contains(asset)) {
                      selectedAll = false;
                    }
                  }
                  final iconImage = selectedAll
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (selectedAll) {
                        context
                            .read<PhotoPickerProvider>()
                            .batchUnSelectAssets(assetList);
                      } else {
                        context
                            .read<PhotoPickerProvider>()
                            .batchSelectAssets(assetList);
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
                selector: (_, p) => p.selectedAssets,
              ),
            ],
          ),
          Builder(
            builder: (context) {
              final totalRows = (assetList.length + gridCount - 1) ~/ gridCount;
              const singleSpace = 2;
              final totalSpace = (gridCount - 1) * singleSpace;
              final itemWidth = (size.width - totalSpace) / gridCount;
              final height =
                  itemWidth * totalRows + (totalRows - 1) * singleSpace;
              // debugPrint('--------> $month');
              return SizedBox(
                height: height,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: assetList.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: gridCount,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                  ),
                  itemBuilder: (context, gridIndex) {
                    // debugPrint('---------> ${assetList[gridIndex].createDateTime.toString()}');
                    return _renderGridItem(gridIndex);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _renderGridItem(int gridIndex) {
    final asset = assetList[gridIndex];
    return Selector<PhotoPickerProvider, List<AssetEntity>>(
      selector: (_, p) => p.selectedAssets,
      builder: (context, List<AssetEntity> selectedAssets, child) {
        final index = selectedAssets.indexOf(asset);
        final isSelected = index != -1;
        final iconImage =
            isSelected ? Icons.radio_button_checked : Icons.radio_button_off;
        final indexStr = isSelected ? '${index + 1}' : '';
        if (asset.id ==
                context.read<PhotoPickerProvider>().currentAssets.last.id &&
            context.read<PhotoPickerProvider>().hasMoreToLoad) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.read<PhotoPickerProvider>().loadMore();
            }
          });
        }
        final maxCount = context.read<PhotoPickerProvider>().maxAssets;
        final disabled = selectedAssets.length == maxCount && !isSelected;
        return GestureDetector(
          onTap: () {
            final List<AssetEntity> allAssetList = [];
            for (final item
                in context.read<PhotoPickerProvider>().monthlyAssets) {
              allAssetList.addAll(item.assetList);
            }
            final index = allAssetList.indexOf(asset);
            UIPhotoPreviewer.show(
              context,
              previewAssets: allAssetList,
              provider: context.read<PhotoPickerProvider>(),
              initialIndex: index,
              maxCount: maxCount,
              onSelected: onSelected,
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              AssetEntityImage(
                asset,
                isOriginal: false,
                thumbnailSize: const ThumbnailSize.square(300),
                fit: BoxFit.cover,
              ),
              Positioned(
                bottom: 1,
                left: 4,
                child: Offstage(
                  offstage: asset.type != AssetType.video,
                  child: Row(
                    children: [
                      const Icon(Icons.videocam, size: 22, color: Colors.white),
                      const SizedBox(width: 4.0),
                      Text(
                        durationIndicatorBuilder(
                            Duration(seconds: asset.duration)),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      )
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 6,
                left: 8,
                child: Text(
                  indexStr,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              Positioned(
                right: 0.0,
                top: 0.0,
                child: Offstage(
                  offstage: disabled,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (isSelected) {
                        context
                            .read<PhotoPickerProvider>()
                            .unSelectAsset(asset);
                      } else {
                        context.read<PhotoPickerProvider>().selectAsset(asset);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        iconImage,
                        size: 20,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String durationIndicatorBuilder(Duration duration) {
    const String separator = ':';
    final String minute = duration.inMinutes.toString().padLeft(2, '0');
    final String second = (duration - Duration(minutes: duration.inMinutes))
        .inSeconds
        .toString()
        .padLeft(2, '0');
    return '$minute$separator$second';
  }
}

class AlbumPathSelector extends StatefulWidget {
  const AlbumPathSelector({
    super.key,
    this.pathList = const [],
    this.selectedIndex = 0,
    this.onSelected,
    this.onCancel,
  });

  final List<AssetPathEntity> pathList;
  final int selectedIndex;
  final ValueChanged<int>? onSelected;
  final VoidCallback? onCancel;

  @override
  State<AlbumPathSelector> createState() => _AlbumPathSelectorState();
}

class _AlbumPathSelectorState extends State<AlbumPathSelector> {
  List<AssetPathEntity> get pathList => widget.pathList;

  int get selectedIndex => widget.selectedIndex;

  ValueChanged<int>? get onSelected => widget.onSelected;

  VoidCallback? get onCancel => widget.onCancel;

  late final ValueNotifier<int> _currentIndexNotifier =
      ValueNotifier(selectedIndex);

  late final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration:
          BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor),
      child: SizedBox(
        height: 300.0,
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          removeBottom: true,
          child: ListView.builder(
            controller: _controller,
            itemCount: pathList.length,
            itemBuilder: (context, index) {
              final assetPath = pathList[index];
              return GestureDetector(
                onTap: () {
                  _currentIndexNotifier.value = index;
                  onSelected?.call(index);
                },
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    FutureBuilder(
                      future: assetPath.getAssetListPaged(page: 0, size: 1),
                      builder: (context, snapshot) {
                        switch (snapshot.connectionState) {
                          case ConnectionState.done:
                            if (snapshot.hasError) {
                              return Text('error: ${snapshot.error}');
                            } else {
                              if (snapshot.data == null ||
                                  snapshot.data!.isEmpty) {
                                return const SizedBox();
                              }
                              return AssetEntityImage(
                                snapshot.data!.first,
                                isOriginal: false,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              );
                            }
                          default:
                            return const CircularProgressIndicator();
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    FutureBuilder(
                      future: assetPath.assetCountAsync,
                      builder: (context, snapshot) {
                        switch (snapshot.connectionState) {
                          case ConnectionState.done:
                            if (snapshot.hasError) {
                              return Text('error: ${snapshot.error}');
                            } else {
                              return Text(assetPath.name);
                              // return Text(
                              //   '${UIPhotoPicker.getAssetPathName(assetPath)}(${snapshot.data})',
                              // );
                            }
                          default:
                            return const CircularProgressIndicator();
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    ValueListenableBuilder(
                      valueListenable: _currentIndexNotifier,
                      builder: (context, currentIndex, child) {
                        return Offstage(
                          offstage: currentIndex != index,
                          child: child!,
                        );
                      },
                      child: const Icon(Icons.check_box, size: 16.0),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _currentIndexNotifier.dispose();
    _controller.dispose();
    super.dispose();
  }
}

class BottomBar extends StatelessWidget {
  const BottomBar({
    super.key,
    this.onConfirm,
    this.onPreview,
    this.onOrigin,
    this.needOrigin = false,
    this.defaultOriginal,
    this.bottomBarHeaderBuilder,
  });

  final VoidCallback? onConfirm;
  final VoidCallback? onPreview;
  final VoidCallback? onOrigin;
  final bool needOrigin;
  final bool? defaultOriginal;
  final WidgetBuilder? bottomBarHeaderBuilder;

  @override
  Widget build(BuildContext context) {
    final iconImage =
        needOrigin ? Icons.radio_button_checked : Icons.radio_button_off;
    return Selector<PhotoPickerProvider, List<AssetEntity>>(
      selector: (_, p) => p.selectedAssets,
      builder: (_, List<AssetEntity> selectedAssets, child) {
        final maxCount = context.read<PhotoPickerProvider>().maxAssets;
        final text =
            selectedAssets.isEmpty ? '预览' : '预览(${selectedAssets.length})';
        final confirmText = selectedAssets.isEmpty
            ? '确认'
            : '确认 ${selectedAssets.length}/$maxCount';
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom,
          ),
          constraints: BoxConstraints(
            minHeight: 45 + MediaQuery.paddingOf(context).bottom,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 1.0,
                offset: const Offset(0.0, -1.0),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (bottomBarHeaderBuilder != null)
                bottomBarHeaderBuilder!(context),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onPreview,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 15.0, vertical: 10.0),
                          child: Text(text),
                        ),
                      ),
                    ),
                  ),
                  if (defaultOriginal != null)
                    Expanded(
                      child: Center(
                        child: GestureDetector(
                          onTap: onOrigin,
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('原图'),
                              const SizedBox(width: 4.0),
                              Icon(
                                iconImage,
                                size: 20.0,
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onConfirm,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 15.0),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: selectedAssets.isEmpty
                                  ? Colors.black
                                  : Colors.green,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5.0),
                              child: Text(
                                confirmText,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
