import 'dart:async';

import 'package:bruno/src/components/button/brn_big_main_button.dart';
import 'package:bruno/src/components/line/brn_line.dart';
import 'package:bruno/src/components/selection/bean/brn_selection_common_entity.dart';
import 'package:bruno/src/components/selection/brn_selection_util.dart';
import 'package:bruno/src/components/selection/brn_selection_view.dart';
import 'package:bruno/src/components/selection/widget/brn_selection_more_item_widget.dart';
import 'package:bruno/src/components/toast/brn_toast.dart';
import 'package:bruno/src/constants/brn_asset_constants.dart';
import 'package:bruno/src/theme/configs/brn_selection_config.dart';
import 'package:bruno/src/utils/brn_tools.dart';
import 'package:flutter/material.dart';

/// 更多的多选页面
/// 展示的内容：
///         1：以纯标签的形式展示筛选条件 比如：朝向
///         2：以可点击的layout 展示跳转至列表页面 比如：商圈
///         3：以标签和自定义的输入展示筛选条件 比如：面积
///
/// 筛选条件的单选多选判定规则是：父节点的 type 决定子节点的单选多选类型
///                          子节点的 type 决定了自己的展示UI
/// 比如 楼层，楼层节点的type是radio，那么 一层、二层都是 只能选中一个
///                               如果他的某个子节点是range type， 该子节点的展示是自定义输入
///
///
/// 参考[BrnSelectionEntity]和[BrnSelectionView]
class BrnMoreSelectionPage extends StatefulWidget {
  final BrnSelectionEntity entityData;
  final Function(BrnSelectionEntity) confirmCallback;
  final BrnOnCustomFloatingLayerClick onCustomFloatingLayerClick;
  final BrnSelectionConfig themeData;

  BrnMoreSelectionPage(
      {this.entityData, this.confirmCallback, this.onCustomFloatingLayerClick, this.themeData});

  @override
  _BrnMoreSelectionPageState createState() => _BrnMoreSelectionPageState();
}

class _BrnMoreSelectionPageState extends State<BrnMoreSelectionPage>
    with SingleTickerProviderStateMixin {
  List<BrnSelectionEntity> _originalSelectedItemsList;
  AnimationController _controller;
  Animation<Offset> animation;
  StreamController<ClearEvent> clearController;
  bool isValid = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    animation = Tween(end: Offset.zero, begin: Offset(1.0, 0.0)).animate(_controller);
    _controller.forward();

    _originalSelectedItemsList = List();
    _originalSelectedItemsList.clear();
    _originalSelectedItemsList.addAll(widget.entityData?.allSelectedList() ?? List());
    for (BrnSelectionEntity entity in _originalSelectedItemsList) {
      entity.isSelected = true;
      if (entity.customMap != null) {
        //ori 是存数据     customMap是用来展示ui的
        entity.originalCustomMap = Map.from(entity.customMap);
      }
    }

    clearController = StreamController.broadcast();
  }

  /// 页面结构：左侧的透明黑 + 右侧宽为300的内容区域
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0x660c0c0c),
      body: Row(
        children: <Widget>[
          _buildLeftSlide(context),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return SlideTransition(
                position: animation,
                child: child,
              );
            },
            child: _buildRightSlide(context),
          )
        ],
      ),
      //为了解决 键盘抬起按钮的问题 将按钮移动到 此区域
      bottomNavigationBar: Container(
        height: 80,
        child: Row(
          children: <Widget>[
            _buildLeftSlide(context),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return SlideTransition(
                  position: animation,
                  child: child,
                );
              },
              child: Container(
                width: 300,
                color: Colors.white,
                child: Column(
                  children: <Widget>[
                    BrnLine(),
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: _buildBottomButtons(),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _controller?.dispose();
  }

  /// 左侧为透明黑，点击直接退出页面
  Widget _buildLeftSlide(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          BrnSelectionUtil.resetSelectionDatas(widget.entityData);
          //把数据还原
          _originalSelectedItemsList.forEach((data) {
            data.isSelected = true;
            if (data.customMap != null) {
              //ori 是存数据     customMap是用来展示ui的
              data.customMap = Map<String, String>();
              if (data.originalCustomMap != null) {
                data.originalCustomMap.forEach((key, value) {
                  data.customMap[key.toString()] = value.toString() ?? "";
                });
              }
            }
          });
          Navigator.maybePop(context);
        },
        child: Container(
          color: Colors.transparent,
        ),
      ),
    );
  }

  /// 右侧为内容区域：标题+更多+筛选项的列表 + 底部按钮区域
  Widget _buildRightSlide(BuildContext context) {
    return Container(
      width: 300,
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.only(top: 0),
        child: _buildSelectionListView(),
      ),
    );
  }

  /// 标题+筛选条件的 列表
  Widget _buildSelectionListView() {
    return ListView.builder(
      itemBuilder: (context, index) {
        return BrnMoreSelectionWidget(
            clearController: clearController,
            selectionEntity: widget.entityData.children[index],
            onCustomFloatingLayerClick: widget.onCustomFloatingLayerClick,
            themeData: widget.themeData);
      },
      itemCount: widget.entityData.children.length,
    );
  }

  /// 清空筛选项 + 确定按钮
  Widget _buildBottomButtons() {
    return MoreBottomSelectionWidget(
      entity: widget.entityData,
      themeData: widget.themeData,
      clearCallback: () {
        setState(() {
          clearController.add(ClearEvent());
          _clearUIData(widget.entityData);
        });
      },
      conformCallback: (data) {
        checkValue(data);
        if (!isValid) {
          isValid = true;
          return;
        }

        widget.entityData.children.forEach((data) {
          if (data.selectedList().isNotEmpty) {
            data.isSelected = true;
          } else {
            data.isSelected = false;
          }
        });
        if (widget.confirmCallback != null) {
          widget.confirmCallback(data);
        }
        Navigator.of(context).pop();
      },
    );
  }

  //清空UI效果
  void _clearUIData(BrnSelectionEntity entity) {
    entity.isSelected = false;
    entity.customMap = Map<String, String>();
    if (BrnSelectionFilterType.Range == entity.filterType) {
      entity.title = null;
    }
    if (entity.children != null) {
      for (BrnSelectionEntity subEntity in entity.children) {
        _clearUIData(subEntity);
      }
    }
  }

  void checkValue(BrnSelectionEntity entity) {
    clearSelectedEntity();
  }

  void clearSelectedEntity() {
    List<BrnSelectionEntity> tmp = List();
    BrnSelectionEntity node = widget.entityData;
    tmp.add(node);
    while (tmp.isNotEmpty) {
      node = tmp.removeLast();
      if (node.isSelected &&
          (node.filterType == BrnSelectionFilterType.Range ||
              node.filterType == BrnSelectionFilterType.DateRange ||
              node.filterType == BrnSelectionFilterType.DateRangeCalendar)) {
        if (node.customMap != null &&
            ((node.customMap['min'] != null && node.customMap['min'].length > 0) ||
                (node.customMap['max'] != null && node.customMap['max'].length > 0))) {
          if (!node.isValidRange()) {
            isValid = false;
            if (node?.filterType == BrnSelectionFilterType.Range) {
              BrnToast.show('您输入的区间有误', context);
            } else if (node?.filterType == BrnSelectionFilterType.DateRange ||
                node?.filterType == BrnSelectionFilterType.DateRangeCalendar) {
              BrnToast.show('您选择的区间有误', context);
            }
            return;
          }
        } else {
          node.isSelected = false;
        }
      }
      node.children?.forEach((data) {
        tmp.add(data);
      });
    }
  }
}

/// 用于侧边滑动开一个页面
class SlideRightRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SlideRightRoute({this.page})
      : super(
          opaque: false,
          pageBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) =>
              page,
          transitionsBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) =>
              SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
}

/// 底部的重置+确定
// ignore: must_be_immutable
class MoreBottomSelectionWidget extends StatelessWidget {
  final VoidCallback clearCallback;
  final Function(BrnSelectionEntity) conformCallback;
  final BrnSelectionEntity entity;
  BrnSelectionConfig themeData;

  MoreBottomSelectionWidget(
      {this.clearCallback, this.conformCallback, this.entity, this.themeData});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        GestureDetector(
          onTap: () {
            if (clearCallback != null) {
              clearCallback();
            }
          },
          child: Container(
            margin: EdgeInsets.only(left: 20, right: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Container(
                  height: 24,
                  width: 24,
                  child: BrunoTools.getAssetImage(BrnAsset.iconSelectionReset),
                ),
                Text(
                  '重置',
                  style: themeData.resetTextStyle.generateTextStyle(),
                )
              ],
            ),
          ),
        ),
        Expanded(
            child: BrnBigMainButton(
          title: '确定',
          onTap: () {
            if (conformCallback != null) {
              conformCallback(entity);
            }
          },
        )),
      ],
    );
  }
}

//用于处理 重置事件
class ClearEvent {}
