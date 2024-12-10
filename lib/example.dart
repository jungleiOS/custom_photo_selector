import 'package:custom_photo_selector/photo_picker_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

class Example extends StatefulWidget {
  const Example({super.key});

  @override
  State<Example> createState() => _ExampleState();
}

class _ExampleState extends State<Example> {
  AssetPathEntity? _currentPath;
  int _pageIndex = 0;
  bool _hasMore = true;
  List<MonthlyAssetViewModel> _dataList = [];
  final List<AssetEntity> _assetList = [];
  final List<AssetEntity> _selectedList = [];

  @override
  void initState() {
    super.initState();
    initData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('example'),
      ),
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          itemCount: _dataList.length,
          itemBuilder: (context, index) {
            final model = _dataList[index];
            if (model.assetList.last.id == _assetList.last.id && _hasMore) {
              _pageIndex++;
              getAssets();
            }
            bool selectedAll = true;
            for (final asset in model.assetList) {
              final index = _selectedList.indexOf(asset);
              if (index == -1) {
                selectedAll = false;
                break;
              }
            }
            return AssetGroup(
              model: model,
              selectedAll: selectedAll,
              onTapSelectedAll: (selected) {
                if (selected) {
                  unSelectAll(model.assetList);
                } else {
                  selectAll(model.assetList);
                }
              },
              itemBuilder: (context, groupIndex) {
                final asset = model.assetList[groupIndex];
                final index = _selectedList.indexOf(asset);
                final selected = index != -1;
                final icon =
                    selected ? Icons.check_circle : Icons.circle_outlined;
                return Stack(
                  children: [
                    Positioned.fill(
                      child: AssetEntityImage(
                        asset,
                        isOriginal: false,
                        thumbnailSize: const ThumbnailSize.square(300),
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned.fill(
                      child: Offstage(
                        offstage: !selected,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 4.0,
                      top: 4.0,
                      child: Offstage(
                        offstage: !selected,
                        child: Text(
                          (index + 1).toString(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0.0,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          tapAsset(asset);
                        },
                        child: Padding(
                          padding:
                              const EdgeInsets.fromLTRB(12.0, 4.0, 4.0, 12.0),
                          child: Icon(
                            icon,
                            size: 20.0,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  void initData() async {
    final tempList =
        await PhotoManager.getAssetPathList(type: RequestType.common);
    if (tempList.isEmpty) {
      EasyLoading.showToast('相册为空');
      return;
    }
    _currentPath = tempList.first;
    _pageIndex = 0;
    _assetList.clear();
    getAssets();
  }

  void getAssets() async {
    if (_currentPath != null && _hasMore) {
      final list =
          await _currentPath!.getAssetListPaged(page: _pageIndex, size: 80);
      _assetList.addAll(list);
      _assetList.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
      _dataList = AssetGroupingHelper.groupByYearMonthDay(_assetList);
      _hasMore = list.isNotEmpty;
      if (mounted) {
        setState(() {});
      }
    }
  }

  void tapAsset(AssetEntity asset) {
    final index = _selectedList.indexOf(asset);
    if (index != -1) {
      _selectedList.removeAt(index);
    } else {
      _selectedList.add(asset);
    }
    if (mounted) {
      setState(() {});
    }
  }

  void selectAll(List<AssetEntity> list) {
    for (final asset in list) {
      if (!_selectedList.contains(asset)) {
        _selectedList.add(asset);
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  void unSelectAll(List<AssetEntity> list) {
    for (final asset in list) {
      _selectedList.remove(asset);
    }
    if (mounted) {
      setState(() {});
    }
  }
}

class AssetGroup extends StatelessWidget {
  const AssetGroup({
    super.key,
    required this.model,
    required this.itemBuilder,
    this.selectedAll = false,
    this.onTapSelectedAll,
  });

  final MonthlyAssetViewModel model;
  final IndexedWidgetBuilder itemBuilder;
  final bool selectedAll;
  final ValueChanged<bool>? onTapSelectedAll;

  @override
  Widget build(BuildContext context) {
    final icon = selectedAll ? Icons.check_circle : Icons.circle_outlined;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 3 * 2) / 4;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(model.month),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    onTapSelectedAll?.call(selectedAll);
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12.0, 4.0, 4.0, 4.0),
                    child: Icon(
                      icon,
                      size: 20.0,
                      color: Colors.green,
                    ),
                  ),
                )
              ],
            ),
            Wrap(
              spacing: 2,
              runSpacing: 2,
              children: model.assetList.map(
                (asset) {
                  final index = model.assetList.indexOf(asset);
                  return SizedBox(
                    width: width,
                    height: width,
                    child: itemBuilder(context, index),
                  );
                },
              ).toList(),
            ),
          ],
        );
      },
    );
  }
}
