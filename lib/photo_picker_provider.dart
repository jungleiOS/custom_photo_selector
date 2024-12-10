import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';

/// 判断资源可否被选择。
typedef AssetSelectPredicate<Asset> = FutureOr<bool> Function(
  Asset asset,
  bool isSelected,
);

/// 资源过滤器，用于过滤掉不符合要求的资源。返回false，则该资源将会被过滤掉。
typedef AssetFilter = FutureOr<bool> Function(AssetEntity asset);

class PhotoPickerProvider extends ChangeNotifier {
  PhotoPickerProvider({
    this.maxAssets = 9,
    this.selectPredicate,
    this.filter,
    this.pageSize = 80,
    List<AssetEntity>? selectedAssets,
    this.requestType = RequestType.common,
  }) : _selectedAssets =
            selectedAssets?.toList() ?? List<AssetEntity>.empty(growable: true);

  final AssetSelectPredicate<AssetEntity>? selectPredicate;
  final AssetFilter? filter;
  final int maxAssets;
  final int pageSize;
  final RequestType requestType;

  List<AssetPathEntity> get pathList => _pathList;

  List<AssetPathEntity> _pathList = [];

  AssetPathEntity? _currentPath;

  AssetPathEntity? get currentPath => _currentPath;

  void setCurrentPath(AssetPathEntity? value) {
    if (value == _currentPath) {
      return;
    }
    _currentPath = value;
    notifyListeners();
  }

  late bool _enableFilter = filter != null;

  set enableFilter(bool value) {
    if (value == _enableFilter) {
      return;
    }
    _enableFilter = value;
    _currentPage = 0;
    _currentAssets.clear();
    _monthlyAssets.clear();
    _getAssetsFromPath(currentPage);
    notifyListeners();
  }

  bool get enableFilter => _enableFilter;

  int _currentPage = 0;

  int get currentPage => _currentPage;

  List<MonthlyAssetViewModel> _monthlyAssets = [];

  List<MonthlyAssetViewModel> get monthlyAssets => _monthlyAssets;

  void setMonthlyAssets(List<MonthlyAssetViewModel> value) {
    if (value == _monthlyAssets) {
      return;
    }
    _monthlyAssets = value;
    notifyListeners();
  }

  /// 已选中的资源
  List<AssetEntity> get selectedAssets => _selectedAssets;
  late List<AssetEntity> _selectedAssets;

  void _setSelectedAssets(List<AssetEntity> value) {
    if (value == _selectedAssets) {
      return;
    }
    _selectedAssets = value.toList();
    notifyListeners();
  }

  /// Select asset.
  /// 选中资源
  void selectAsset(AssetEntity item) async {
    if (selectedAssets.length == maxAssets || selectedAssets.contains(item)) {
      return;
    }
    final bool? selectPredicateResult = await selectPredicate?.call(item, true);
    if (selectPredicateResult == false) {
      return;
    }
    final List<AssetEntity> set = selectedAssets.toList();
    set.add(item);
    _setSelectedAssets(set);
  }

  /// Un-select asset.
  /// 取消选中资源
  void unSelectAsset(AssetEntity item) async {
    final bool? selectPredicateResult =
        await selectPredicate?.call(item, false);
    if (selectPredicateResult == false) {
      return;
    }
    final List<AssetEntity> set = selectedAssets.toList();
    set.remove(item);
    _setSelectedAssets(set);
  }

  void batchSelectAssets(List<AssetEntity> assets) {
    if (selectedAssets.length + assets.length > maxAssets) {
      return;
    }
    for (var element in assets) {
      if (!selectedAssets.contains(element)) {
        selectAsset(element);
      }
    }
  }

  void batchUnSelectAssets(List<AssetEntity> assets) {
    for (var element in assets) {
      if (selectedAssets.contains(element)) {
        unSelectAsset(element);
      }
    }
  }

  Future<void> getPaths() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.hasAccess) {
      EasyLoading.showToast('权限检查未通过，请开启相册访问权限');
      return;
    }
    final tempList = await PhotoManager.getAssetPathList(type: requestType);
    if (tempList.isNotEmpty) {
      final List<AssetPathEntity> list = [];
      for (var element in tempList) {
        final count = await element.assetCountAsync;
        if (count > 0) {
          list.add(element);
        }
      }
      _pathList = list;
      if (_pathList.isNotEmpty) {
        _currentPath = _pathList.first;
        // final pathAllAssetCount = await _currentPath!.assetCountAsync;
        _getAssetsFromPath(currentPage);
      }
    }
  }

  /// Assets under current path entity.
  /// 正在查看的资源路径下的所有资源
  List<AssetEntity> get currentAssets => _currentAssets;
  final List<AssetEntity> _currentAssets = <AssetEntity>[];

  /// Whether there are any assets can be displayed.
  /// 是否有资源可供显示
  bool get hasAssetsToDisplay => _hasAssetsToDisplay;
  bool _hasAssetsToDisplay = false;

  set hasAssetsToDisplay(bool value) {
    if (value == _hasAssetsToDisplay) {
      return;
    }
    _hasAssetsToDisplay = value;
    notifyListeners();
  }

  bool _hasMoreToLoad = true;

  /// Whether more assets are waiting for a load.
  /// 是否还有更多资源可以加载
  bool get hasMoreToLoad => _hasMoreToLoad;

  void updateAssets() async {
    // _monthlyAssets = await _assetSort(path: _currentPath!);
    notifyListeners();
  }

  Future<void> switchPath(AssetPathEntity path) async {
    _currentPage = 0;
    _currentAssets.clear();
    _monthlyAssets.clear();
    setCurrentPath(path);
    _getAssetsFromPath(currentPage);
  }

  void _getAssetsFromPath(int pageIndex) async {
    final List<AssetEntity> list =
        await currentPath!.getAssetListPaged(page: pageIndex, size: pageSize);
    _hasMoreToLoad = list.isNotEmpty;
    if (_enableFilter && filter != null) {
      for (var element in list) {
        final bool? filterResult = await filter?.call(element);
        if (filterResult == true) {
          _currentAssets.add(element);
        }
      }
    } else {
      _currentAssets.addAll(list);
    }
    // _currentAssets 按时间排序
    _currentAssets.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
    final viewModelList =
        AssetGroupingHelper.groupByYearMonthDay(_currentAssets);
    setMonthlyAssets(viewModelList);
  }

  void loadMore() async {
    if (hasMoreToLoad) {
      _currentPage++;
      _getAssetsFromPath(currentPage);
    }
  }
}

class MonthlyAssetViewModel {
  String month;
  List<AssetEntity> assetList;
  bool selectAll;

  MonthlyAssetViewModel({
    this.month = '',
    this.assetList = const [],
    this.selectAll = false,
  });
}

// 定义 AssetGroupingHelper 类
class AssetGroupingHelper {
  // 提取年月信息的方法
  static String _getYearMonthDay(DateTime? dateTime) {
    if (dateTime == null) return '';
    return DateFormat('yyyy-MM-dd').format(dateTime);
  }

  // 静态方法，用于按年月日分组
  static List<MonthlyAssetViewModel> groupByYearMonthDay(
      List<AssetEntity> assetEntities) {
    final Map<String, List<AssetEntity>> groupedAssets = assetEntities.fold(
      <String, List<AssetEntity>>{},
      (Map<String, List<AssetEntity>> map, AssetEntity entity) {
        final yearMonthCreate = _getYearMonthDay(entity.createDateSecond != null
            ? DateTime.fromMillisecondsSinceEpoch(
                entity.createDateSecond! * 1000)
            : null);
        final yearMonthModified = _getYearMonthDay(
            entity.modifiedDateSecond != null
                ? DateTime.fromMillisecondsSinceEpoch(
                    entity.modifiedDateSecond! * 1000)
                : null);

        // 使用创建日期优先，如果创建日期为空，则使用修改日期
        final yearMonth =
            yearMonthCreate.isNotEmpty ? yearMonthCreate : yearMonthModified;

        if (yearMonth.isEmpty) return map;

        final List<AssetEntity> assets = map.putIfAbsent(yearMonth, () => []);
        assets.add(entity);
        return map;
      },
    );

    return groupedAssets.entries
        .map((entry) =>
            MonthlyAssetViewModel(month: entry.key, assetList: entry.value))
        .toList();
  }
}
