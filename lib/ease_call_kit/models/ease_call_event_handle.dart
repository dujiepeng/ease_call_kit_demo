import 'ease_call_error.dart';
import 'ease_enums.dart';

class EaseCallEventHandle {
  /// 通话结束
  /// [channel] 通话channel
  /// [reason] 结束原因
  /// [keepTime] 通话持续时间
  /// [type] 通话类型
  /// [remoteEid] 对方环信id
  final void Function(
    String? channel,
    EaseCallEndReason reason,
    int? keepTime,
    EaseCallType? type,
    String? remoteEid,
  )? callDidEnd;

  /// 多人通话时点击邀请
  /// [users] 当前已在通话中获已被邀请的成员
  final void Function(
    List<String?> users,
  )? multiCallDidInviting;

  /// 收到通话邀请
  /// [type] 通话类型
  /// [inviter] 邀请人环信id
  /// [ext] 邀请时附带信息
  final void Function(
    EaseCallType type,
    String inviter,
    String? ext,
  )? callDidReceive;

  /// 通话过程中发送异常回调
  /// [error] 错误信息
  final void Function(
    String? remoteEid,
    EaseCallError error,
  )? callDidOccurError;

  /// 加入通话前会触发该回调，需要获取声网token并通过EaseCallManager#setAgoraToken设置给EaseCallKit
  /// [appId] 当前的AppId
  /// [channelName] 当前的channelName
  /// [eid] 当前使用的环信id
  /// [agoraUid] 当前的声网id，如果没有，需要由AppServer分配
  final void Function(
    String appId,
    String channel,
    String eid,
    int? agoraUId,
  )? callDidRequestTokenForAppId;

  /// 有用户加入会议
  /// [channelName] channelName
  /// [agoraUId] 加入人的声网id
  /// [eid] 加入人的环信id
  final void Function(
    String channel,
    int agoraUId,
    String eid,
  )? remoteUserDidJoinChannel;

  /// 开始通话
  /// [channel] 通话channelName
  /// [remoteEid] 对方环信id，如果是群聊，为null
  final void Function(
    String? channel,
    String? remoteEid,
  )? startTalking;

  /// 自己加入会议后回调
  /// [channelName] channel name;
  /// [agoraUid] 声网id
  final void Function(
    String channel,
    int agoraUid,
  )? didJoinChannel;

  EaseCallEventHandle({
    this.callDidEnd,
    this.multiCallDidInviting,
    this.callDidReceive,
    this.callDidOccurError,
    this.callDidRequestTokenForAppId,
    this.remoteUserDidJoinChannel,
    this.didJoinChannel,
    this.startTalking,
  });
}
