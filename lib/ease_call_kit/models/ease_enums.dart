enum EaseCallErrorType { process, rtc, im }

enum EaseCallEndReason {
  hangup,
  cancel,
  remoteCancel,
  refuse,
  busy,
  noResponse,
  remoteNoResponse,
  handleOnOtherDevice
}

enum EaseCallType { audio, video, multi }
enum EaseCallState { idle, outgoing, alerting, answering }
