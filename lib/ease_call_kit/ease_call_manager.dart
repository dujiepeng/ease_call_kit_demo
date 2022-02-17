import 'dart:async';

import 'package:ease_call_kit_demo/ease_call_kit/ease_call_keys.dart';
import 'package:ease_call_kit_demo/ease_call_kit/models/ease_call_ec_call.dart';
import 'package:ease_call_kit_demo/ease_call_kit/models/ease_call_error.dart';
import 'package:ease_call_kit_demo/ease_call_kit/models/ease_call_model.dart';
import 'package:ease_call_kit_demo/ease_call_kit/models/ease_call_view_model.dart';
import 'package:ease_call_kit_demo/ease_call_kit/models/ease_enums.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/rtc_engine.dart';

import 'package:flutter/widgets.dart';

import 'package:im_flutter_sdk/im_flutter_sdk.dart';

String currentTime = DateTime.now().millisecondsSinceEpoch.toString();

class EaseCallManager with ChangeNotifier implements EMChatManagerListener {
  static EaseCallManager? _instance;
  static EaseCallManager get instance => _instance ??= EaseCallManager();

  final Map<String, Timer> _callTimerMap = {};
  final Map<String, Timer> _alertTimerMap = {};
  Timer? _confirmTimer;
  Timer? _callRingTimer;
  Timer? _callTimer;
  String? appId;
  bool _needSwitchToVoice = false;
  late RtcEngine _engine;
  bool get isBusy {
    return model.curCall != null && model.state != EaseCallState.idle
        ? true
        : false;
  }

  late EaseCallModel model;

  EaseCallViewModel? viewModel;

  EaseCallEventHandle? callEventHandle;

  EaseCallManager() {
    model = EaseCallModel(stateChangeHandle: _callStateWillChange);
    EMClient.getInstance.chatManager.addListener(this);
  }

  void setHandle(EaseCallEventHandle callEventHandle) {
    this.callEventHandle = callEventHandle;
  }

  void setAppId(String appId) async {
    this.appId = appId;
    await initAgoraSDK();
  }

  Future<void> initAgoraSDK() async {
    await [Permission.microphone, Permission.camera].request();
    _engine = await RtcEngine.create(appId!);
    _engine.setEventHandler(RtcEngineEventHandler(
      error: (err) => {
        if (err == ErrorCode.TokenExpired || err == ErrorCode.InvalidToken)
          {
            model.state = EaseCallState.idle,
            _callbackError(
              EaseCallErrorType.rtc,
              int.parse(err.toString()),
              "RTC Error",
            ),
          }
        else
          {
            if (err != ErrorCode.NoError &&
                err != ErrorCode.JoinChannelRejected)
              {
                _callbackError(
                  EaseCallErrorType.rtc,
                  int.parse(err.toString()),
                  "RTC Error",
                ),
              }
          },
      },
      remoteAudioStateChanged: (uid, state, reason, elapsed) => {},
      joinChannelSuccess: (channel, uid, elapsed) {
        callEventHandle?.didJoinChannel?.call(channel, uid);
        model.hasJoinedChannel = true;
        model.curCall!.users[uid] = EMClient.getInstance.currentUsername!;
        if (model.curCall!.callType == EaseCallType.multi) {
          enableVoice(false);
        }
      },
      localUserRegistered: (uid, userAccount) => {},
      tokenPrivilegeWillExpire: (token) => {},
      userOffline: (uid, reason) => {
        if (model.curCall?.callType == EaseCallType.multi)
          {
            // TODO: update multi view, remove offline user.
          }
        else
          {
            _callbackCallEnd(EaseCallEndReason.hangup),
            model.state = EaseCallState.idle,
          },
      },
      userJoined: (uid, elapsed) {
        if (model.curCall?.callType == EaseCallType.multi) {
          // TODO: update multi view, add joind user.
        } else {
          _stopCallTimer(model.curCall!.remoteEid!);
          model.curCall!.users[uid] = model.curCall!.remoteEid!;
        }
        String? username = model.curCall!.users[uid];
        callEventHandle?.remoteUserDidJoinChannel?.call(
          model.curCall!.channelName!,
          uid,
          username!,
        );
      },
      userMuteVideo: (uid, muted) => {},
      userMuteAudio: (uid, muted) => {},
      remoteVideoStateChanged: (uid, state, reason, elapsed) => {
        if (reason == VideoRemoteStateReason.RemoteMuted &&
            model.curCall!.callType == EaseCallType.video)
          {
            // switchVideoToVoice(),
          }
      },
      audioVolumeIndication: (speakers, totalVolume) => {},
    ));
  }

  @override
  void dispose() {
    _clearInfo();
    _instance = null;
    super.dispose();
  }

  void _clearInfo() {
    for (var item in _alertTimerMap.values.toList()) {
      item.cancel();
    }
    for (var item in _callTimerMap.values.toList()) {
      item.cancel();
    }
    viewModel = null;
    _stopCallTimeRunner();
    _alertTimerMap.clear();
    _callTimerMap.clear();
    _confirmTimer?.cancel();
    model.recvCalls.clear();
    model.curCall = null;
    _needSwitchToVoice = false;
  }

  /// 发送呼叫邀请
  Future<void> _sendInviteMsgToCallee(
    String eid,
    EaseCallType callType,
    String callId,
    String channelName,
    String? ext,
  ) async {
    EMMessage msg = EMMessage.createTxtSendMessage(eid, "flutter 邀请通话");
    msg.attributes = {
      EaseCallKeys.msgType: EaseCallKeys.msgTypeValue,
      EaseCallKeys.action: EaseCallKeys.inviteAction,
      EaseCallKeys.callId: callId,
      EaseCallKeys.callType: callType == EaseCallType.audio ? 0 : 1,
      EaseCallKeys.callerDevId: model.curDevId,
      EaseCallKeys.channelName: channelName,
      EaseCallKeys.timestamp: currentTime,
    };

    try {
      await CallMessage(msg).send();
    } on EaseCallError {
      rethrow;
    }
  }

  /// 发送alert 信息
  void _sendAlertMsgToCaller(
    String callerEid,
    String callId,
    String calleeDevId,
  ) async {
    EMMessage msg = EMMessage.createCmdSendMessage(
      username: callerEid,
      action: "rtcCall",
    );
    EMCmdMessageBody body = msg.body as EMCmdMessageBody;
    body.deliverOnlineOnly = true;
    msg.attributes = {
      EaseCallKeys.msgType: EaseCallKeys.msgTypeValue,
      EaseCallKeys.action: EaseCallKeys.alertAction,
      EaseCallKeys.callId: callId,
      EaseCallKeys.calleeDevId: model.curDevId,
      EaseCallKeys.callerDevId: calleeDevId,
      EaseCallKeys.timestamp: currentTime,
    };

    try {
      await CallMessage(msg).send();
    } on EaseCallError catch (e) {
      callEventHandle?.callDidOccurError?.call(e);
    }
  }

  void _sendConfirmRingMsgToCallee(
    String eid,
    String callId,
    bool isValid,
    String calleeDevId,
  ) async {
    EMMessage msg = EMMessage.createCmdSendMessage(
      username: eid,
      action: "rtcCall",
    );
    EMCmdMessageBody body = msg.body as EMCmdMessageBody;
    body.deliverOnlineOnly = true;
    msg.attributes = {
      EaseCallKeys.msgType: EaseCallKeys.msgTypeValue,
      EaseCallKeys.action: EaseCallKeys.confirmRingAction,
      EaseCallKeys.callId: callId,
      EaseCallKeys.callerDevId: model.curDevId,
      EaseCallKeys.calleeDevId: calleeDevId,
      EaseCallKeys.timestamp: currentTime,
      EaseCallKeys.callStatus: isValid,
    };

    try {
      await CallMessage(msg).send();
    } on EaseCallError catch (e) {
      callEventHandle?.callDidOccurError?.call(e);
    }
  }

  void _sendCancelCallMsgToCallee(String calleeId, String callId) async {
    EMMessage msg = EMMessage.createCmdSendMessage(
      username: calleeId,
      action: "rtcCall",
    );
    EMCmdMessageBody body = msg.body as EMCmdMessageBody;
    body.deliverOnlineOnly = true;

    msg.attributes = {
      EaseCallKeys.msgType: EaseCallKeys.msgTypeValue,
      EaseCallKeys.action: EaseCallKeys.cancelCallAction,
      EaseCallKeys.callId: callId,
      EaseCallKeys.callerDevId: model.curDevId,
      EaseCallKeys.timestamp: currentTime,
    };

    try {
      await CallMessage(msg).send();
    } on EaseCallError catch (e) {
      callEventHandle?.callDidOccurError?.call(e);
    }
  }

  void _sendAnswerMsg(
    String callerEid,
    String callId,
    String result,
    String devId,
  ) async {
    EMMessage msg = EMMessage.createCmdSendMessage(
      username: callerEid,
      action: "rtcCall",
    );
    EMCmdMessageBody body = msg.body as EMCmdMessageBody;
    body.deliverOnlineOnly = true;

    Map<String, dynamic> map = {
      EaseCallKeys.msgType: EaseCallKeys.msgTypeValue,
      EaseCallKeys.action: EaseCallKeys.answerCallAction,
      EaseCallKeys.callId: callId,
      EaseCallKeys.callerDevId: devId,
      EaseCallKeys.calleeDevId: model.curDevId,
      EaseCallKeys.result: result,
      EaseCallKeys.timestamp: currentTime,
    };

    if (model.curCall!.callType == EaseCallType.audio && _needSwitchToVoice) {
      map[EaseCallKeys.videoToVoice] = true;
    }
    msg.attributes = map;

    try {
      await CallMessage(msg).send();
      _startConfirmTimer(callId);
    } on EaseCallError catch (e) {
      callEventHandle?.callDidOccurError?.call(e);
    }
  }

  void _sendConfirmAnswerMsgToCallee(
    String eid,
    String callId,
    String result,
    String devId,
  ) async {
    EMMessage msg = EMMessage.createCmdSendMessage(
      username: eid,
      action: "rtcCall",
    );
    EMCmdMessageBody body = msg.body as EMCmdMessageBody;
    body.deliverOnlineOnly = true;

    msg.attributes = {
      EaseCallKeys.msgType: EaseCallKeys.msgTypeValue,
      EaseCallKeys.action: EaseCallKeys.confirmCalleeAction,
      EaseCallKeys.callId: callId,
      EaseCallKeys.callerDevId: model.curDevId,
      EaseCallKeys.calleeDevId: devId,
      EaseCallKeys.result: result,
      EaseCallKeys.timestamp: currentTime,
    };

    if (result == EaseCallKeys.accept) {
      model.state = EaseCallState.answering;
    }
    try {
      await CallMessage(msg).send();
    } on EaseCallError catch (e) {
      model.state = EaseCallState.idle;
      callEventHandle?.callDidOccurError?.call(e);
    }
  }

  void _sendVideoToVoiceMsg(String eid, String callId) async {
    EMMessage msg = EMMessage.createCmdSendMessage(
      username: eid,
      action: "rtcCall",
    );
    EMCmdMessageBody body = msg.body as EMCmdMessageBody;
    body.deliverOnlineOnly = true;

    msg.attributes = {
      EaseCallKeys.msgType: EaseCallKeys.msgTypeValue,
      EaseCallKeys.action: EaseCallKeys.videoToVoice,
      EaseCallKeys.callId: callId,
      EaseCallKeys.timestamp: currentTime,
    };

    try {
      await CallMessage(msg).send();
    } on EaseCallError catch (e) {
      callEventHandle?.callDidOccurError?.call(e);
    }
  }

  void _parseMsg(EMMessage msg) async {
    if (msg.to != EMClient.getInstance.currentUsername) {
      return;
    }
    if (!msg.attributes.containsKey(EaseCallKeys.msgType)) {
      return;
    }

    String? msgType = msg.attributes[EaseCallKeys.msgType];
    if (msgType == null) return;
    String from = msg.from!;
    String? callId = msg.attributes[EaseCallKeys.callId];
    String? result = msg.attributes[EaseCallKeys.result];
    String? callerDevId = msg.attributes[EaseCallKeys.callerDevId];
    String? calleeDevId = msg.attributes[EaseCallKeys.calleeDevId];
    String? channelName = msg.attributes[EaseCallKeys.channelName];
    bool? isValid = msg.attributes[EaseCallKeys.callStatus];

    EaseCallType callType = msg.attributes[EaseCallKeys.callType] == 0
        ? EaseCallType.audio
        : EaseCallType.video;
    bool? isVideoToVoice = msg.attributes[EaseCallKeys.videoToVoice];
    String? ext = msg.attributes[EaseCallKeys.ext];

    _parseInviteMsg() {
      if (callId != null && model.curCall?.callId == callId) {
        return;
      }
      if (_alertTimerMap.containsKey(callId)) return;
      if (isBusy) {
        _sendAnswerMsg(
          from,
          callId!,
          EaseCallKeys.busyResult,
          callerDevId!,
        );
      } else {
        ECCall call = ECCall(
          callId: callId,
          isCaller: false,
          callType: callType,
          remoteDevId: callerDevId,
          channelName: channelName,
          remoteEid: from,
          ext: ext,
        );
        model.recvCalls[callId!] = call;
        _sendAlertMsgToCaller(call.remoteEid!, callId, call.remoteDevId!);
        _startAlertTimer(callId);
      }
    }

    _parseAlertMsg() {
      if (model.curDevId == callerDevId &&
          callerDevId != null &&
          callId != null &&
          calleeDevId != null) {
        if (model.curCall?.callId == callId &&
            _callTimerMap.containsKey(from)) {
          _sendConfirmRingMsgToCallee(from, callId, true, calleeDevId);
        } else {
          _sendConfirmRingMsgToCallee(from, callId, false, calleeDevId);
        }
      }
    }

    _parseCancelCallMsg() {
      if (callId != null &&
          model.curCall?.callId == callId &&
          !model.hasJoinedChannel) {
        _stopConfirmTimer(callId);
        _stopAlertTimer(callId);
        _callbackCallEnd(EaseCallEndReason.remoteCancel);
        model.state = EaseCallState.idle;
      } else {
        model.recvCalls.remove(callId);
        _stopAlertTimer(callId!);
      }
    }

    _parseAnswerMsg() {
      if (callId != null &&
          callerDevId != null &&
          model.curCall?.callId == callId &&
          model.curDevId == callerDevId) {
        if (model.curCall?.callType == EaseCallType.multi) {
          if (result != EaseCallKeys.accept) {
            // TODO: update multi ui;
          }

          Timer? timer = _callTimerMap[from];
          if (timer != null) {
            _sendConfirmAnswerMsgToCallee(from, callId, result!, calleeDevId!);
            timer.cancel();
            _callTimerMap.remove(from);
          }
        } else {
          if (model.state == EaseCallState.outgoing) {
            if (result == EaseCallKeys.accept) {
              if (isVideoToVoice ?? false) {
                switchVideoToVoice();
              }
              model.state = EaseCallState.answering;
            } else {
              if (result == EaseCallKeys.refuseResult) {
                _callbackCallEnd(EaseCallEndReason.refuse);
              }
              if (result == EaseCallKeys.busyResult) {
                _callbackCallEnd(EaseCallEndReason.busy);
              }
              model.state = EaseCallState.idle;
            }
            _sendConfirmAnswerMsgToCallee(from, callId, result!, calleeDevId!);
          }
        }
      }
    }

    _parseConfirmRingMsg() {
      if (callId != null &&
          calleeDevId != null &&
          _alertTimerMap.containsKey(callId) &&
          calleeDevId == model.curDevId) {
        _stopAlertTimer(callId);
        if (isBusy) {
          _sendAnswerMsg(from, callId, EaseCallKeys.busyResult, callerDevId!);
          return;
        }
        ECCall? call = model.recvCalls[callId];
        if (call != null) {
          if (isValid ?? false) {
            model.curCall = call;
            model.recvCalls.clear();
            _stopAllAlertTimer();
            model.state = EaseCallState.alerting;
          }
          model.recvCalls.remove(callId);
        }
      }
    }

    _parseConfirmCalleeMsg() {
      if (callId == null) return;
      if (model.state == EaseCallState.alerting &&
          model.curCall?.callId == callId) {
        _stopConfirmTimer(callId);
        if (model.curDevId == calleeDevId) {
          if (result == EaseCallKeys.accept) {
            model.state = EaseCallState.answering;
            if (model.curCall!.callType != EaseCallType.audio) {
              // TODO: setupLocalVideo
            }
            _needFetchToken();
          }
        } else {
          _callbackCallEnd(EaseCallEndReason.handleOnOtherDevice);
          model.state = EaseCallState.idle;
        }
      } else {
        if (model.recvCalls.containsKey(callId)) {
          model.recvCalls.remove(callId);
          _stopAlertTimer(callId);
        }
      }
    }

    _parseVideoToVoiceMsg() {
      if (model.curCall?.callId == callId) {
        switchVideoToVoice();
      }
    }

    if (msgType == EaseCallKeys.msgTypeValue) {
      String action = msg.attributes[EaseCallKeys.action];
      switch (action) {
        case EaseCallKeys.inviteAction:
          _parseInviteMsg();
          break;
        case EaseCallKeys.alertAction:
          _parseAlertMsg();
          break;
        case EaseCallKeys.confirmRingAction:
          _parseConfirmRingMsg();
          break;
        case EaseCallKeys.cancelCallAction:
          _parseCancelCallMsg();
          break;
        case EaseCallKeys.confirmCalleeAction:
          _parseConfirmCalleeMsg();
          break;
        case EaseCallKeys.answerCallAction:
          _parseAnswerMsg();
          break;
        case EaseCallKeys.videoToVoice:
          _parseVideoToVoiceMsg();
          break;
      }
    }
  }

  void _callStateWillChange(EaseCallState newState, EaseCallState perState) {
    switch (newState) {
      case EaseCallState.idle:
        debugPrint("------切换为挂断状态");
        _refreshIdle();
        break;
      case EaseCallState.outgoing:
        debugPrint("------切换为呼叫状态");
        _refreshOutgoing();
        break;
      case EaseCallState.alerting:
        debugPrint("------切换为协商状态");
        _refreshAlerting();

        break;
      case EaseCallState.answering:
        debugPrint("------切换为接听状态");
        _refreshAnswering();
        break;
      default:
    }
  }

  void _needFetchToken() {
    callEventHandle?.callDidRequestTokenForAppId?.call(
      appId!,
      model.curCall!.channelName!,
      EMClient.getInstance.currentUsername!,
      model.curCall!.uid,
    );
  }

  /// pragma mark - Timer manager

  void _joinAgoraChannel() async {
    if (model.hasJoinedChannel) {
      await _engine.leaveChannel();
    }

    await _engine.joinChannel(
      model.agoraRtcToken,
      model.curCall!.channelName!,
      null,
      model.agoraUid!,
    );

    setSpeakerOut(true);
  }

  void _startCallTimer(String remoteUser) {
    if (_callTimerMap.containsKey(remoteUser)) {
      return;
    }
    Timer timer = Timer(const Duration(seconds: 30), () {
      _timeoutCall(remoteUser);
    });
    _callTimerMap[remoteUser] = timer;
  }

  void _stopCallTimer(String remoteUser) {
    Timer? timer = _callTimerMap[remoteUser];
    timer?.cancel();
    _callTimerMap.remove(remoteUser);
  }

  void _timeoutCall(String remoteUser) {
    _callTimerMap.remove(remoteUser);
    _sendCancelCallMsgToCallee(remoteUser, model.curCall!.callId!);
    if (model.curCall!.callType != EaseCallType.multi) {
      _callbackCallEnd(EaseCallEndReason.remoteNoResponse);
      model.state = EaseCallState.idle;
    } else {
      // TODO: 多人时需要从ui上移除
    }
  }

  void _startAlertTimer(String callId) {
    Timer timer = Timer(const Duration(seconds: 5), () {
      _timeoutAlert(callId);
    });
    _alertTimerMap[callId] = timer;
  }

  void _stopAlertTimer(String callId) {
    Timer? timer = _alertTimerMap[callId];
    timer?.cancel();
    _alertTimerMap.remove(callId);
  }

  void _stopAllAlertTimer() {
    for (var timer in _alertTimerMap.values.toList()) {
      timer.cancel();
    }
    _alertTimerMap.clear();
  }

  void _timeoutAlert(String callId) {
    _alertTimerMap.remove(callId);
  }

  void _startConfirmTimer(String callId) {
    if (_confirmTimer != null) {
      _confirmTimer!.cancel();
    }
    _confirmTimer = Timer(const Duration(seconds: 5), () {
      _timeoutConfirm(callId);
    });
  }

  void _stopConfirmTimer(String callId) {
    if (_confirmTimer != null) {
      _confirmTimer!.cancel();
    }
    _confirmTimer = null;
  }

  void _timeoutConfirm(String callId) {
    if (model.curCall?.callId == callId) {
      _callbackCallEnd(EaseCallEndReason.remoteNoResponse);
      model.state = EaseCallState.idle;
    }
  }

  void _startRingTimer(String callId) {
    if (_callRingTimer != null) {
      _callRingTimer!.cancel();
    }

    _callRingTimer = Timer(const Duration(seconds: 30), () {
      _timeoutRing(callId);
    });
  }

  void _stopRingTimer(String callId) {
    if (_callRingTimer != null) {
      _callRingTimer!.cancel();
    }
    _callRingTimer = null;
  }

  void _timeoutRing(String callId) {
    if (model.curCall?.callId == callId) {
      _callbackCallEnd(EaseCallEndReason.noResponse);
    }
  }

  void _callbackCallEnd(EaseCallEndReason reason) {
    callEventHandle?.callDidEnd?.call(
      model.curCall?.channelName,
      reason,
      0,
      model.curCall?.callType,
    );
  }

  void _callbackError(EaseCallErrorType type, int code, String desc) {
    callEventHandle?.callDidOccurError?.call(EaseCallError(code, type, desc));
  }

  /// 开始计时
  void _startCallTimeRunner() {
    _stopCallTimeRunner();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      viewModel?.time += 1;
    });
  }

  void _stopCallTimeRunner() {
    _callTimer?.cancel();
    viewModel?.time = 0;
  }

  /// pragma mark - update ui.
  void _refreshOutgoing() {
    if (model.curCall != null) {
      if (model.curCall!.callType == EaseCallType.video) {
        // TODO: update local video view;
      }
      viewModel = EaseCallViewModel(
        model.curCall!.callType!,
        EaseCallState.outgoing,
        false,
      );

      _updateUI();
      _needFetchToken();
    } else {
      // TODO: clear info;
    }
  }

  void _refreshAlerting() {
    if (model.curCall != null) {
      callEventHandle?.callDidReceive?.call(
        model.curCall!.callType!,
        model.curCall!.remoteEid!,
        model.curCall!.ext,
      );
      if (model.curCall!.callType == EaseCallType.multi) {
        // TODO: set ui type;
      } else {}
      _startRingTimer(model.curCall!.callId!);
      viewModel =
          EaseCallViewModel(model.curCall!.callType!, model.state, true);
      _updateUI();
    }
  }

  void _refreshAnswering() {
    if (model.curCall != null) {
      if (model.curCall!.callType == EaseCallType.multi &&
          model.curCall!.isCaller) {
        // TODO: update local video view;
        _needFetchToken();
      }
      _startCallTimeRunner();
      viewModel = viewModel?.copyWith(state: model.state);
      _updateUI();
    }
  }

  void _refreshIdle() async {
    if (model.curCall != null) {
      if (model.curCall!.callType != EaseCallType.audio) {
        await _engine.stopPreview();
        await _engine.disableVideo();
      }
      if (model.hasJoinedChannel) {
        model.hasJoinedChannel = false;
        await _engine.leaveChannel();
      }
    }

    _clearInfo();
    _updateUI();
  }

  /// pragma mark - Action

  void _updateUI() {
    notifyListeners();
  }

  /// pragma mark - delegate

  @override
  void onCmdMessagesReceived(List<EMMessage> messages) {
    for (var msg in messages) {
      _parseMsg(msg);
    }
  }

  @override
  void onConversationRead(String? from, String? to) {}

  @override
  void onConversationsUpdate() {}

  @override
  void onGroupMessageRead(List<EMGroupMessageAck> groupMessageAcks) {}

  @override
  void onMessagesDelivered(List<EMMessage> messages) {}

  @override
  void onMessagesRead(List<EMMessage> messages) {}

  @override
  void onMessagesRecalled(List<EMMessage> messages) {}

  @override
  void onMessagesReceived(List<EMMessage> messages) {
    debugPrint("收到消息");
    for (var msg in messages) {
      _parseMsg(msg);
    }
  }
}

class EaseCallEventHandle {
  /// 通话结束
  /// [channel] 通话channel
  /// [reason] 结束原因
  /// [time] 通话持续时间
  /// [type] 通话类型
  final void Function(
    String? channel,
    EaseCallEndReason reason,
    int time,
    EaseCallType? type,
  )? callDidEnd;

  /// 多人通话时点击邀请
  /// [users] 当前已在通话中获已被邀请的成员
  final void Function(
    List<String?> users,
  )? multiCAllDidInviting;

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
    EaseCallError error,
  )? callDidOccurError;

  /// 加入通话前会触发该回调，需要获取声网token并通过EaseCallManager#setAgoraToken设置给EaseCallKit
  /// [appId] 当前的AppId
  /// [channelName] 当前的channelName
  /// [eid] 当前使用的环信id
  /// [agoraUid] 当前的声网id，如果没有，需要由AppServer分配
  final void Function(
    String appId,
    String channelName,
    String eid,
    int? agoraUId,
  )? callDidRequestTokenForAppId;

  /// 有用户加入会议
  /// [channelName] channelName
  /// [agoraUId] 加入人的声网id
  /// [eid] 加入人的环信id
  final void Function(
    String channelName,
    int agoraUId,
    String eid,
  )? remoteUserDidJoinChannel;

  /// 自己加入会议后回调
  /// [channelName] channel name;
  /// [agoraUid] 声网id

  final void Function(
    String channelName,
    int agoraUid,
  )? didJoinChannel;

  EaseCallEventHandle({
    this.callDidEnd,
    this.multiCAllDidInviting,
    this.callDidReceive,
    this.callDidOccurError,
    this.callDidRequestTokenForAppId,
    this.remoteUserDidJoinChannel,
    this.didJoinChannel,
  });
}

extension EaseCallManagerMethod on EaseCallManager {
  /// 发起单人呼叫
  /// [eid] 接收方环信id
  /// [callType] 呼叫类型
  /// [ext] 附件信息
  Future<void> startSingleCall(
    String eid, {
    EaseCallType callType = EaseCallType.audio,
    String? ext,
  }) async {
    if (eid.isEmpty) {
      throw (EaseCallError(
        EaseCallProcessErrorCode.invalidParams,
        EaseCallErrorType.process,
        "Require remote eid",
      ));
    }

    if (isBusy) {
      throw (EaseCallError(
        EaseCallProcessErrorCode.curBusy,
        EaseCallErrorType.process,
        "current is busy.",
      ));
    }

    model.curCall = ECCall(
      channelName: randomString(),
      remoteEid: eid,
      callType: callType,
      callId: randomString(),
      isCaller: true,
      ext: ext,
    );
    model.state = EaseCallState.outgoing;
    try {
      await _sendInviteMsgToCallee(
        eid,
        callType,
        model.curCall!.callId!,
        model.curCall!.channelName!,
        ext,
      );
      _startCallTimer(eid);
    } on EaseCallError {
      viewModel = null;
      _updateUI();
      model.state = EaseCallState.idle;
      rethrow;
    }
  }

  /// 挂断通话
  Future<void> hangupAction() async {
    if (model.state == EaseCallState.answering) {
      // 正常挂断
      if (model.curCall?.callType == EaseCallType.multi) {
        if (_callTimerMap.isNotEmpty) {
          List<Timer> timers = _callTimerMap.values.toList();
          for (var timer in timers) {
            // TODO: multi
          }
        }
      }
      _callbackCallEnd(EaseCallEndReason.hangup);
      model.state = EaseCallState.idle;
    } else {
      if (model.state == EaseCallState.outgoing) {
        // 取消呼叫
        _stopAlertTimer(model.curCall!.remoteEid!);
        _sendCancelCallMsgToCallee(
          model.curCall!.remoteEid!,
          model.curCall!.callId!,
        );
        _callbackCallEnd(EaseCallEndReason.cancel);
        model.state = EaseCallState.idle;
      } else {
        // 拒接
        _sendAnswerMsg(
          model.curCall!.remoteEid!,
          model.curCall!.callId!,
          EaseCallKeys.refuseResult,
          model.curCall!.remoteDevId!,
        );
        model.state = EaseCallState.idle;
      }
    }
  }

  /// 设置声网token, 设置后会尝试加入channel中
  /// [token] 声网token
  /// [channelName] 声网的ChannelName
  /// [uid] 声网id
  void setRtcToken(
    String? token,
    String channelName,
    int agoraUid,
  ) {
    if (model.curCall?.channelName == channelName) {
      model.agoraRtcToken = token;
      model.agoraUid = agoraUid;
      _joinAgoraChannel();
    }
  }

  /// 切换小窗口
  /// [isMin] 是否使用小窗口
  void setWindowToMin(bool isMin) async {
    viewModel = viewModel?.copyWith(isMin: isMin);
    _updateUI();
  }

  /// 设置麦克风静音
  /// [isMute] 是否静音
  void setMute(bool isMute) async {
    if (isMute) {
      await _engine.disableAudio();
    } else {
      await _engine.enableAudio();
    }

    viewModel = viewModel?.copyWith(isMute: isMute);

    _updateUI();
  }

  /// 使用扬声器
  /// [isSpeaker] 是否使用扬声器
  void setSpeakerOut(bool isSpeaker) async {
    await _engine.setEnableSpeakerphone(isSpeaker);
    viewModel = viewModel?.copyWith(isSpeaker: isSpeaker);
    _updateUI();
  }

  /// 由视频切换为语音，切换后本次通话不可再切换回来
  void switchVideoToVoice() async {
    if (model.curCall != null &&
        model.curCall!.callType == EaseCallType.video) {
      _needSwitchToVoice = true;
      model = model.copyWith(
        curCall: model.curCall!.copyWith(
          callType: EaseCallType.audio,
        ),
      );

      viewModel = viewModel?.copyWith(
        callType: EaseCallType.audio,
      );

      // TODO: 更新ui, 设置声网
    }
    if (model.curCall?.isCaller == true ||
        model.state == EaseCallState.answering) {
      // TODO: 更新ui, 设置声网
    }
  }

  void enableVideo(bool isEnable) async {
    if (isEnable) {
      await _engine.enableVideo();
    } else {
      await _engine.disableVideo();
    }
  }

  void enableVoice(bool isEnable) async {
    if (isEnable) {
      await _engine.enableAudio();
    } else {
      await _engine.disableAudio();
    }
  }

  void acceptAction() {
    _sendAnswerMsg(
      model.curCall!.remoteEid!,
      model.curCall!.callId!,
      EaseCallKeys.accept,
      model.curCall!.remoteDevId!,
    );
  }
}
