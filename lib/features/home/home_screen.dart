import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets/app_dialog.dart';
import '../shared/measurement_session.dart';
import '../../domain/prefs_store.dart';

/// S2 홈 / 현장정보 입력
/// - 이번 측정의 현장 정보를 입력하고 측정을 시작하는 홈 화면
/// - 어르신 UX: 필드/버튼 64dp, 터치 영역 최소 56dp, 본문 18+
/// - 오류 표시: 색 + 아이콘 + 텍스트 3중 표시 및 해당 위치로 스크롤
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _jobNoCtl = TextEditingController();
  final _siteNameCtl = TextEditingController();
  final _bottomFloorCtl = TextEditingController();
  final _topFloorCtl = TextEditingController();

  final _jobNoFocus = FocusNode();
  final _siteNameFocus = FocusNode();
  final _bottomFloorFocus = FocusNode();
  final _topFloorFocus = FocusNode();

  final _jobNoKey = GlobalKey();
  final _siteNameKey = GlobalKey();
  final _floorKey = GlobalKey();

  String _direction = '하부 → 상부';
  String _model = 'Gen2';

  String? _jobNoError;
  String? _siteNameError;
  String? _floorError;

  @override
  void initState() {
    super.initState();
    _loadSavedInputs();
  }

  Future<void> _loadSavedInputs() async {
    final saved = await PrefsStore.instance.loadLastSite();
    if (!mounted) return;
    final jobNo = saved['jobNo'];
    final siteName = saved['siteName'];
    final bottomFloor = saved['bottomFloor'];
    final topFloor = saved['topFloor'];
    final direction = saved['direction'];
    final model = saved['model'];

    setState(() {
      if (jobNo != null) _jobNoCtl.text = jobNo;
      if (siteName != null) _siteNameCtl.text = siteName;
      if (bottomFloor != null) _bottomFloorCtl.text = bottomFloor;
      if (topFloor != null) _topFloorCtl.text = topFloor;
      if (direction != null) _direction = direction;
      if (model != null) _model = model;
    });
  }

  @override
  void dispose() {
    _jobNoCtl.dispose();
    _siteNameCtl.dispose();
    _bottomFloorCtl.dispose();
    _topFloorCtl.dispose();
    _jobNoFocus.dispose();
    _siteNameFocus.dispose();
    _bottomFloorFocus.dispose();
    _topFloorFocus.dispose();
    super.dispose();
  }

  void _startMeasure() {
    FocusScope.of(context).unfocus();

    final jobNo = _jobNoCtl.text.trim();
    final siteName = _siteNameCtl.text.trim();
    final bottomFloorStr = _bottomFloorCtl.text.trim();
    final topFloorStr = _topFloorCtl.text.trim();

    String? jobErr;
    String? siteErr;
    String? floorErr;

    if (jobNo.isEmpty) {
      jobErr = '제번을 입력하세요 (예: 2024F 1447R01)';
    }

    if (siteName.isEmpty) {
      siteErr = '현장명을 입력하세요 (예: 럭키종합건설/송정동근생)';
    }

    if (bottomFloorStr.isEmpty || topFloorStr.isEmpty) {
      floorErr = '최하층과 최상층을 모두 입력하세요';
    } else {
      final bottomFloor = int.tryParse(bottomFloorStr);
      final topFloor = int.tryParse(topFloorStr);
      if (bottomFloor == null || topFloor == null) {
        floorErr = '층수는 숫자로 입력하세요';
      } else if (bottomFloor >= topFloor) {
        floorErr = '최상층이 최하층보다 커야 합니다';
      }
    }

    setState(() {
      _jobNoError = jobErr;
      _siteNameError = siteErr;
      _floorError = floorErr;
    });

    if (jobErr != null || siteErr != null || floorErr != null) {
      GlobalKey? targetKey;
      if (jobErr != null) {
        targetKey = _jobNoKey;
        _jobNoFocus.requestFocus();
      } else if (siteErr != null) {
        targetKey = _siteNameKey;
        _siteNameFocus.requestFocus();
      } else if (floorErr != null) {
        targetKey = _floorKey;
        if (bottomFloorStr.isEmpty) {
          _bottomFloorFocus.requestFocus();
        } else {
          _topFloorFocus.requestFocus();
        }
      }

      if (targetKey != null && targetKey.currentContext != null) {
        Scrollable.ensureVisible(
          targetKey.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      return;
    }

    final siteInfo = SiteInfo(
      jobNo: jobNo,
      siteName: siteName,
      bottomFloor: bottomFloorStr,
      topFloor: topFloorStr,
      direction: _direction,
      model: _model,
    );
    MeasurementSession.instance.currentSite = siteInfo;

    PrefsStore.instance.saveLastSite({
      'jobNo': jobNo,
      'siteName': siteName,
      'bottomFloor': bottomFloorStr,
      'topFloor': topFloorStr,
      'direction': _direction,
      'model': _model,
    });

    context.push('/start');
  }

  OutlineInputBorder _errorBorder() {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDims.radius),
      borderSide: const BorderSide(color: AppColors.red, width: 2),
    );
  }

  Widget _buildErrorBox(String message) {
    return Container(
      margin: const EdgeInsets.only(top: AppDims.gap2),
      padding: const EdgeInsets.all(AppDims.gap2),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDims.radius),
        border: Border.all(color: AppColors.red),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.red, size: 28),
          const SizedBox(width: AppDims.gap2),
          Expanded(
            child: Text(
              message,
              style: AppText.body.copyWith(color: AppColors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
  }) {
    return AppDialogButton(
      label: label,
      onPressed: onPressed,
      primary: false,
      icon: icon,
      iconSize: 24,
      textStyle: AppText.caption.copyWith(
        color: AppColors.navy,
        fontWeight: FontWeight.w700,
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppDims.gap2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('진동 측정'),
        actions: [
          _buildActionBtn(
            onPressed: () => context.push('/settings'),
            icon: Icons.settings_outlined,
            label: '설정',
          ),
          _buildActionBtn(
            onPressed: () => context.push('/history'),
            icon: Icons.folder_open_outlined,
            label: '저장 결과',
          ),
          const SizedBox(width: AppDims.gap),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDims.screenPad),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppDims.gap),
                Text('현장 정보', style: AppText.subhead),
                const SizedBox(height: AppDims.gap3),

                // 1) 제번
                Container(
                  key: _jobNoKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('제번', style: AppText.bodyBold),
                      const SizedBox(height: AppDims.gap),
                      SizedBox(
                        height: AppDims.fieldH,
                        child: TextField(
                          controller: _jobNoCtl,
                          focusNode: _jobNoFocus,
                          style: AppText.body,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            hintText: '예: 2024F 1447R01',
                            enabledBorder: _jobNoError != null
                                ? _errorBorder()
                                : null,
                            focusedBorder: _jobNoError != null
                                ? _errorBorder()
                                : null,
                          ),
                          onSubmitted: (_) => _siteNameFocus.requestFocus(),
                          onChanged: (_) {
                            if (_jobNoError != null) {
                              setState(() => _jobNoError = null);
                            }
                          },
                        ),
                      ),
                      if (_jobNoError != null) _buildErrorBox(_jobNoError!),
                    ],
                  ),
                ),
                const SizedBox(height: AppDims.gap3),

                // 2) 현장명
                Container(
                  key: _siteNameKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('현장명', style: AppText.bodyBold),
                      const SizedBox(height: AppDims.gap),
                      SizedBox(
                        height: AppDims.fieldH,
                        child: TextField(
                          controller: _siteNameCtl,
                          focusNode: _siteNameFocus,
                          style: AppText.body,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            hintText: '예: 럭키종합건설/송정동근생',
                            enabledBorder: _siteNameError != null
                                ? _errorBorder()
                                : null,
                            focusedBorder: _siteNameError != null
                                ? _errorBorder()
                                : null,
                          ),
                          onSubmitted: (_) => _bottomFloorFocus.requestFocus(),
                          onChanged: (_) {
                            if (_siteNameError != null) {
                              setState(() => _siteNameError = null);
                            }
                          },
                        ),
                      ),
                      if (_siteNameError != null)
                        _buildErrorBox(_siteNameError!),
                    ],
                  ),
                ),
                const SizedBox(height: AppDims.gap3),

                // 3) 최하층 / 최상층
                Container(
                  key: _floorKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('측정 구간 (최하층 / 최상층)', style: AppText.bodyBold),
                      const SizedBox(height: AppDims.gap),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: AppDims.fieldH,
                              child: TextField(
                                controller: _bottomFloorCtl,
                                focusNode: _bottomFloorFocus,
                                style: AppText.body,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(3),
                                ],
                                decoration: InputDecoration(
                                  hintText: '1',
                                  labelText: '최하층',
                                  enabledBorder: _floorError != null
                                      ? _errorBorder()
                                      : null,
                                  focusedBorder: _floorError != null
                                      ? _errorBorder()
                                      : null,
                                ),
                                onSubmitted: (_) =>
                                    _topFloorFocus.requestFocus(),
                                onChanged: (_) {
                                  if (_floorError != null) {
                                    setState(() => _floorError = null);
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: AppDims.gap2),
                          Expanded(
                            child: SizedBox(
                              height: AppDims.fieldH,
                              child: TextField(
                                controller: _topFloorCtl,
                                focusNode: _topFloorFocus,
                                style: AppText.body,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(3),
                                ],
                                decoration: InputDecoration(
                                  hintText: '8',
                                  labelText: '최상층',
                                  enabledBorder: _floorError != null
                                      ? _errorBorder()
                                      : null,
                                  focusedBorder: _floorError != null
                                      ? _errorBorder()
                                      : null,
                                ),
                                onSubmitted: (_) => _startMeasure(),
                                onChanged: (_) {
                                  if (_floorError != null) {
                                    setState(() => _floorError = null);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_floorError != null) _buildErrorBox(_floorError!),
                    ],
                  ),
                ),
                const SizedBox(height: AppDims.gap3),

                // 4) 운전 방향
                Text('운전 방향', style: AppText.bodyBold),
                const SizedBox(height: AppDims.gap),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(
                      value: '하부 → 상부',
                      label: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('하부 → 상부'),
                      ),
                      icon: Icon(Icons.arrow_upward),
                    ),
                    ButtonSegment<String>(
                      value: '상부 → 하부',
                      label: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('상부 → 하부'),
                      ),
                      icon: Icon(Icons.arrow_downward),
                    ),
                  ],
                  selected: {_direction},
                  onSelectionChanged: (val) {
                    setState(() => _direction = val.first);
                  },
                  style: SegmentedButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    selectedBackgroundColor: AppColors.blue,
                    selectedForegroundColor: Colors.white,
                    foregroundColor: AppColors.navy,
                    textStyle: AppText.bodyBold,
                    minimumSize: const Size(0, AppDims.touchMin),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDims.radius),
                    ),
                  ),
                ),
                const SizedBox(height: AppDims.gap3),

                // 5) 기종
                Text('기종', style: AppText.bodyBold),
                const SizedBox(height: AppDims.gap),
                DropdownButtonFormField<String>(
                  initialValue: _model,
                  items: const [
                    DropdownMenuItem(value: 'Gen2', child: Text('Gen2')),
                    DropdownMenuItem(value: '기타', child: Text('기타')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _model = val);
                  },
                  style: AppText.body,
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    size: 28,
                    color: AppColors.navy,
                  ),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppDims.gap2,
                      vertical: 20,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDims.radius),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDims.radius),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDims.screenPad),
          child: ElevatedButton(
            onPressed: _startMeasure,
            child: const Text('측정 시작'),
          ),
        ),
      ),
    );
  }
}
