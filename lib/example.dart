import 'package:custom_photo_selector/photo_picker_provider.dart';
import 'package:custom_photo_selector/ui_navigation_bar.dart';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    initData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const UINavigationBar(title: 'Example'),
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: ListView.builder(
          itemCount: _dataList.length,
          itemBuilder: (context, index) {
            final model = _dataList[index];
            if (model.assetList.last.id == _assetList.last.id && _hasMore) {
              _pageIndex++;
              getAssets();
            }
            return AssetGroup(model: model);
          },
        ),
      ),
    );
  }

  void initData() async {
    final tempList = await PhotoManager.getAssetPathList(type: RequestType.common);
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
}

class AssetGroup extends StatelessWidget {
  const AssetGroup({
    super.key,
    required this.model,
  });

  final MonthlyAssetViewModel model;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 3) / 4;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(model.month),
            Wrap(
              spacing: 1,
              runSpacing: 1,
              children: model.assetList
                  .map(
                    (asset) => AssetEntityImage(
                      asset,
                      isOriginal: false,
                      thumbnailSize: const ThumbnailSize.square(300),
                      fit: BoxFit.cover,
                      width: width,
                      height: width,
                    ),
                  )
                  .toList(),
            ),
          ],
        );
      },
    );
  }
}
