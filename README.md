### ▍项目背景
app 需要一个类似微信的相册选择器，不仅需要将相册的内容全部展示出来。

1. 还需要实现根据照片拍摄时间按天倒序进行排序展示。
2. 还要支持全选某一天全部照片。

### ▍找插件

最开始项目使用的 [wechat_assets_picker](https://pub.dev/packages/wechat_assets_picker)

<!--![wechat_assets_picker](https://github.com/fluttercandies/flutter_wechat_assets_picker/raw/main/screenshots/README_2.webp)-->

<img src="https://github.com/fluttercandies/flutter_wechat_assets_picker/raw/main/screenshots/README_2.webp" style="margin:auto; width:50%; display:block;"/>
<br>

可以看到这虽然能够满足仿微信相册选择器，但是还是不能满足我们的另外两个需求

尝试修改 wechat_assets_picker 但是由于过于复杂放弃。

不过由于大致看过了 wechat_assets_picker 的源码，所以准备按照其思路自己实现。

### ▍实现思路与步骤

1. 通过photo_manager获取相册图片
2. 对获取到的图片进行时间倒序排序
3. 在显示的时候以天排序
4. 实现按天全选

核心代码

```dart
/// 异步测试函数，用于演示如何从PhotoManager获取资源列表并进行处理
void test() async {
  // 获取所有普通类型的资源路径列表
  final List<AssetPathEntity> pathList = await PhotoManager.getAssetPathList(type: RequestType.common);
  
  // 选择第一个资源路径
  final AssetPathEntity path = pathList.first;
  
  // 从选中的路径中获取第一页的80个资源
  final List<AssetEntity> list = await path.getAssetListPaged(page: 0, size: 80);
  
  // 按创建时间降序排序资源列表
  list.sort((a, b)=> b.createDateTime.compareTo(a.createDateTime));
  
  // 按年月日对资源进行分组，生成特定格式的数据列表
  final List<MonthlyAssetViewModel> dataList = AssetGroupingHelper.groupByYearMonthDay(list);
}
```

对相册图片进行分组

```dart
// 定义 AssetGroupingHelper 类，用于对资产进行分组
class AssetGroupingHelper {
  // 私有方法 _getYearMonthDay，用于格式化日期，返回年月日字符串
  static String _getYearMonthDay(DateTime? dateTime) {
    // 如果传入的 dateTime 为 null，则返回空字符串
    if (dateTime == null) return '';
    // 使用 'yyyy-MM-dd' 格式化传入的 dateTime
    return DateFormat('yyyy-MM-dd').format(dateTime);
  }

  // 静态方法 groupByYearMonthDay，用于按年月日分组资产实体
  static List<MonthlyAssetViewModel> groupByYearMonthDay(
      List<AssetEntity> assetEntities) {
    // 使用 fold 方法对资产实体列表进行分组，结果存储在 groupedAssets 中
    final Map<String, List<AssetEntity>> groupedAssets = assetEntities.fold(
      <String, List<AssetEntity>>{},
      (Map<String, List<AssetEntity>> map, AssetEntity entity) {
        // 将创建日期从秒转换为毫秒，并格式化为年月日字符串
        final yearMonthCreate = _getYearMonthDay(entity.createDateSecond != null
            ? DateTime.fromMillisecondsSinceEpoch(
                entity.createDateSecond! * 1000)
            : null);
        // 将修改日期从秒转换为毫秒，并格式化为年月日字符串
        final yearMonthModified = _getYearMonthDay(
            entity.modifiedDateSecond != null
                ? DateTime.fromMillisecondsSinceEpoch(
                    entity.modifiedDateSecond! * 1000)
                : null);

        // 使用创建日期优先，如果创建日期为空，则使用修改日期
        final yearMonth =
            yearMonthCreate.isNotEmpty ? yearMonthCreate : yearMonthModified;

        // 如果年月字符串为空，则不进行处理，直接返回当前的 map
        if (yearMonth.isEmpty) return map;

        // 如果当前年月不存在于 map 中，则创建一个新的列表，并将当前实体添加到列表中
        final List<AssetEntity> assets = map.putIfAbsent(yearMonth, () => []);
        assets.add(entity);
        return map;
      },
    );

    // 将分组后的结果转换为 MonthlyAssetViewModel 列表，便于后续处理
    return groupedAssets.entries
        .map((entry) =>
            MonthlyAssetViewModel(month: entry.key, assetList: entry.value))
        .toList();
  }
}
```

viewModel

```dart
/// MonthlyAssetViewModel 类用于管理每月资产的视图模型
/// 
/// 该类包含了月份信息、资产列表以及一个表示是否全选的布尔值
/// 主要用于在UI层和业务逻辑层之间传递数据
class MonthlyAssetViewModel {
  /// 月份信息
  String month;
  
  /// 资产列表
  List<AssetEntity> assetList;
  
  /// 是否全选
  bool selectAll;

  /// MonthlyAssetViewModel 构造函数
  /// 
  /// [month] 表示月份信息，默认为空字符串
  /// [assetList] 表示资产列表，默认为空列表
  /// [selectAll] 表示是否全选，默认为false
  MonthlyAssetViewModel({
    this.month = '',
    this.assetList = const [],
    this.selectAll = false,
  });
}
```

以上就可以实现相册图片按天倒序显示

以下为完整示例

<img src="https://pic1.zhimg.com/80/v2-00e41854d2679fd2558f0f4fc45f7fa6_720w.gif" style="margin:auto; width:50%; display:block;"/>
<br>

```dart
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
```

当然完整的选者器不会这么简单，具体实现见[代码仓库](https://github.com/jungleiOS/custom_photo_selector)

目前该组件已实现功能

1. 分相册集展示所有相册
2. 相册分页加载
3. 相册图片过滤
4. 相册预选择修改
5. 支持默认中
6. 图片预览、视频预览

<img src="https://picx.zhimg.com/80/v2-b73a9ea6f2cbd0a6be7812de9d15a19c_720w.gif" style="margin:auto; width:50%; display:block;"/>
<br>