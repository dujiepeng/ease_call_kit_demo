import 'package:ease_call_kit_demo/ease_call_kit/models/ease_enums.dart';
import 'package:flutter/material.dart';

class EaseCallViewModel with ChangeNotifier {
  /// 是否最小化
  final bool isMin;

  /// 是否开启扬声器
  final bool isSpeaker;

  /// 呼叫种类
  final EaseCallType callType;

  /// 是否是静音
  final bool isMute;

  /// 是否是呼入
  final bool isCallIn;

  /// 呼叫状态
  final EaseCallState state;

  /// 通话时长
  int? _time;

  int? get time => _time;

  set time(value) {
    _time = value;
    notifyListeners();
  }

  EaseCallViewModel(
    this.callType,
    this.state,
    this.isCallIn, {
    this.isMin = false,
    this.isSpeaker = false,
    this.isMute = false,
  });

  EaseCallViewModel copyWith({
    EaseCallType? callType,
    EaseCallState? state,
    bool? isMin,
    bool? isSpeaker,
    bool? isMute,
  }) {
    return EaseCallViewModel(
      callType ?? this.callType,
      state ?? state ?? this.state,
      isCallIn,
      isMin: isMin ?? this.isMin,
      isSpeaker: isSpeaker ?? this.isSpeaker,
      isMute: isMute ?? this.isMute,
    ).._time = _time;
  }
}
