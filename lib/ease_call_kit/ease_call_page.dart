import 'package:ease_call_kit_demo/ease_call_kit/Views/ease_call_time_text.dart';
import 'package:ease_call_kit_demo/ease_call_kit/ease_call_manager.dart';
import 'package:ease_call_kit_demo/ease_call_kit/models/ease_enums.dart';
import 'package:agora_rtc_engine/rtc_remote_view.dart';
import 'package:sprintf/sprintf.dart';
import 'package:flutter/material.dart';

class EaseCallPage extends StatefulWidget {
  final Widget child;
  final String appId;

  late final MinWindowFrame voiceMinFrame;
  late final MinWindowFrame videoMinFrame;
  late final EdgeInsets minWindowZone;

  EaseCallPage({
    required this.child,
    required this.appId,
    MinWindowFrame? voiceMinFrame,
    MinWindowFrame? videoMinFrame,
    EdgeInsets? minWindowZone,
    Key? key,
  }) : super(key: key) {
    this.voiceMinFrame =
        voiceMinFrame ?? MinWindowFrame(height: 120, width: 90);
    this.videoMinFrame =
        videoMinFrame ?? MinWindowFrame(height: 150, width: 120);
    this.minWindowZone =
        minWindowZone ?? const EdgeInsets.fromLTRB(15, 15, 15, 30);
  }

  @override
  _EaseCallPageState createState() => _EaseCallPageState();
}

class _EaseCallPageState extends State<EaseCallPage>
    with TickerProviderStateMixin {
  OverlayEntry? _overlayEntry;
  Size? _windowSize;

  AnimationController? _animController;
  Animation<Offset>? _animation;
  bool _isTouchDown = false;
  String get timeStr {
    if (EaseCallManager.instance.model.state == EaseCallState.answering) {
      int time = EaseCallManager.instance.viewModel!.time ?? 0;
      String timeStr = time < 3600
          ? sprintf("%02i:%02i", [
              int.parse(((time % 3600) / 60).truncate().toStringAsFixed(0)),
              (time % 60),
            ])
          : sprintf("%02i:%02i:%02i", [
              int.parse((time / 3600).truncate().toStringAsFixed(0)),
              int.parse(((time % 3600) / 60).truncate().toStringAsFixed(0)),
              (time % 60)
            ]);
      return timeStr;
    } else {
      return "接通中";
    }
  }

  @override
  void initState() {
    EaseCallManager.instance.setAppId(widget.appId);
    EaseCallManager.instance.addListener(() {
      _updateOverlayEntry();
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    _windowSize ??= MediaQuery.of(context).size;
    return widget.child;
  }

  void _updateOverlayEntry() {
    _overlayEntry?.remove();
    _overlayEntry = null;

    /// 不存在viewMode，则表示不需要显示。
    if (EaseCallManager.instance.viewModel == null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        late Widget callWidget;
        bool isMin = EaseCallManager.instance.viewModel!.isMin;
        switch (EaseCallManager.instance.viewModel!.callType) {
          case EaseCallType.audio:
            callWidget = isMin ? _voiceMinView() : _voiceNormalView();
            break;
          case EaseCallType.video:
            callWidget = isMin ? _videoMinView() : _videoNormalView();
            break;
          case EaseCallType.multi:
            callWidget = isMin ? _multiNormalView() : _multiMinView();
            break;
        }
        return SafeArea(
          child: Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                callWidget,
              ],
            ),
          ),
        );
      },
    );
    Overlay.of(context, rootOverlay: true)!.insert(_overlayEntry!);
  }

  Widget _videoNormalView() {
    return SurfaceView(uid: EaseCallManager.instance.model.curCall!.uid!);
  }

  Widget _voiceNormalView() {
    GlobalKey<EaseCallTimeTextState> textKey = GlobalKey();
    EaseCallManager.instance.viewModel?.addListener(() {
      textKey.currentState?.strUpdate(timeStr);
    });
    EaseCallTimeText timeText = EaseCallTimeText(
      timeStr,
      const TextStyle(
        fontSize: 24,
        height: 1.1,
      ),
      key: textKey,
    );
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      right: 0,
      child: Container(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: [
                IconButton(
                    padding: const EdgeInsets.all(20),
                    iconSize: 36,
                    onPressed: () => {
                          EaseCallManager.instance.setWindowToMin(true),
                        },
                    icon: const Icon(
                      Icons.class__outlined,
                    ))
              ],
            ),
            const SizedBox(height: 40),
            const Icon(
              Icons.ac_unit_rounded,
              size: 160,
            ),
            const SizedBox(
              height: 20,
            ),
            timeText,
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: () {
                  List<Widget> widgets = [];
                  if (EaseCallManager.instance.viewModel!.isCallIn == false ||
                      EaseCallManager.instance.viewModel?.state ==
                          EaseCallState.answering) {
                    widgets.add(
                      _getCallBtn(
                        EaseCallManager.instance.viewModel!.isMute
                            ? Icons.mic_off
                            : Icons.mic,
                        Colors.black38,
                        Colors.white,
                        clickAction: () {
                          EaseCallManager.instance.setMute(
                            !EaseCallManager.instance.viewModel!.isMute,
                          );
                        },
                      ),
                    );
                    widgets.add(
                      _getCallBtn(
                        Icons.call_end,
                        Colors.red,
                        Colors.white,
                        clickAction: () {
                          EaseCallManager.instance.hangupAction();
                        },
                      ),
                    );
                    widgets.add(
                      _getCallBtn(
                        EaseCallManager.instance.viewModel!.isSpeaker
                            ? Icons.hearing
                            : Icons.volume_up,
                        Colors.black38,
                        Colors.white,
                        clickAction: () {
                          EaseCallManager.instance.setSpeakerOut(
                            !EaseCallManager.instance.viewModel!.isSpeaker,
                          );
                        },
                      ),
                    );
                  } else {
                    widgets.add(
                      _getCallBtn(
                        Icons.call_end,
                        Colors.red,
                        Colors.white,
                        clickAction: () => {
                          EaseCallManager.instance.hangupAction(),
                        },
                      ),
                    );

                    widgets.add(
                      _getCallBtn(
                        Icons.call,
                        Colors.green,
                        Colors.white,
                        clickAction: () =>
                            EaseCallManager.instance.acceptAction(),
                      ),
                    );
                  }

                  return widgets;
                }(),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _multiNormalView() {
    return Container();
  }

  Widget _videoMinView() {
    return Container();
  }

  Widget _voiceMinView() {
    double top = _isTouchDown
        ? widget.voiceMinFrame.top
        : _animation?.value.dy ?? widget.voiceMinFrame.top;

    double right = _isTouchDown
        ? widget.voiceMinFrame.right
        : _animation?.value.dx ?? widget.voiceMinFrame.right;

    GlobalKey<EaseCallTimeTextState> textKey = GlobalKey();
    EaseCallManager.instance.viewModel?.addListener(() {
      textKey.currentState?.strUpdate(timeStr);
    });

    EaseCallTimeText timeText = EaseCallTimeText(
      timeStr,
      const TextStyle(
        color: Colors.white,
        fontSize: 18,
        height: 1.1,
      ),
      key: textKey,
    );
    return Positioned(
      top: top,
      right: right,
      child: SizedBox(
        width: widget.voiceMinFrame.width,
        height: widget.voiceMinFrame.height,
        child: GestureDetector(
          onPanUpdate: (details) => {
            widget.voiceMinFrame.right -= details.delta.dx,
            widget.voiceMinFrame.top += details.delta.dy,
            _overlayEntry?.markNeedsBuild(),
          },
          onTapDown: (details) => {
            _isTouchDown = true,
          },
          onTapUp: (details) => {
            _isTouchDown = false,
          },
          onPanEnd: (details) async {
            _isTouchDown = false;
            double y = widget.voiceMinFrame.top;
            double x = widget.voiceMinFrame.right;
            if (y < widget.minWindowZone.top) {
              y = widget.minWindowZone.top;
            }
            if (y >
                _windowSize!.height -
                    widget.minWindowZone.bottom -
                    widget.voiceMinFrame.height) {
              y = _windowSize!.height -
                  widget.minWindowZone.bottom -
                  widget.voiceMinFrame.height;
            }
            if ((_windowSize!.width - x - widget.voiceMinFrame.width / 2) >
                _windowSize!.width / 2) {
              x = widget.minWindowZone.right;
            } else {
              x = _windowSize!.width -
                  widget.minWindowZone.left -
                  widget.voiceMinFrame.width;
            }
            _animController = AnimationController(
              duration: const Duration(milliseconds: 100),
              vsync: this,
            );
            _animation = Tween(
              begin:
                  Offset(widget.voiceMinFrame.right, widget.voiceMinFrame.top),
              end: Offset(x, y),
            ).animate(_animController!)
              ..addListener(() {
                _overlayEntry?.markNeedsBuild();
              })
              ..addStatusListener((status) {
                if (status == AnimationStatus.completed) {
                  widget.voiceMinFrame.right = x;
                  widget.voiceMinFrame.top = y;
                }
              });
            await _animController!.forward();
            _animController!.dispose();
          },
          child: TextButton(
            style: ButtonStyle(
              padding: MaterialStateProperty.all(const EdgeInsets.all(6)),
              shape: MaterialStateProperty.all(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              backgroundColor: MaterialStateProperty.all(Colors.green),
            ),
            child: Column(
              children: [
                const SizedBox(
                  height: 16,
                ),
                const Icon(
                  Icons.call,
                  size: 40,
                  color: Colors.white,
                ),
                const SizedBox(
                  height: 10,
                ),
                timeText,
              ],
            ),
            onPressed: () => {EaseCallManager.instance.setWindowToMin(false)},
          ),
        ),
      ),
    );
  }

  Widget _getCallBtn(
    IconData btnIcon,
    Color bgColor,
    Color forceColor, {
    double size = 50,
    VoidCallback? clickAction,
  }) {
    return TextButton(
      style: ButtonStyle(
        padding: MaterialStateProperty.all(const EdgeInsets.all(16)),
        shape: MaterialStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(60),
          ),
        ),
        backgroundColor: MaterialStateProperty.all(bgColor),
      ),
      onPressed: clickAction,
      child: Icon(
        btnIcon,
        size: size,
        color: forceColor,
      ),
    );
  }

  Widget _multiMinView() {
    return Container();
  }

  @override
  void dispose() {
    _animController?.dispose();
    super.dispose();
  }
}

class MinWindowFrame {
  double top, right, height, width;

  double get bottom => top + height;
  double get left => right - width;
  MinWindowFrame({
    this.top = 15.0,
    this.right = 15.0,
    this.height = 120.0,
    this.width = 90.0,
  });
}
