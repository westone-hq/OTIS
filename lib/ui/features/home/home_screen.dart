import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets/app_dialog.dart';
import '../shared/measurement_session.dart';
import 'package:vibration_checker/adapter/prefs_store.dart';

/// 작성: 2026-08-17 12:40:41 · 박건준
/// 클래스: HomeScreen
/// 목적: 이번 측정의 현장 정보(제번, 현장명, 층수, 운전 방향, 기종)를
///       입력받고 측정을 시작하는 홈 화면.
///       - 어르신도 쓰기 쉽도록 필드·버튼 높이 64dp, 터치 영역 최소 56dp,
///         본문 글자 크기 18 이상으로 맞춘다
///       - 입력 오류는 색·아이콘·문구 세 가지를 함께 표시하고, 오류가 난
///         위치로 자동 스크롤한다
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// 작성: 2026-08-17 12:40:41 · 박건준
/// 클래스: _HomeScreenState
/// 목적: 홈 화면의 입력 상태를 관리한다.
///       - 입력 컨트롤러 4개(제번·현장명·최하층·최상층)와 포커스 노드로
///         텍스트 필드 값과 포커스 이동을 관리한다
///       - `_direction`(운전 방향)·`_model`(기종)은 선택형 값이라 별도
///         컨트롤러 없이 상태 필드로만 둔다
///       - 오류 문구 3개(`_jobNoError` 등)와 스크롤 대상 키 3개로, 검증
///         실패 시 표시·스크롤 위치를 잡는다
class _HomeScreenState extends State<HomeScreen> {
  /// 제번 입력 필드의 텍스트 컨트롤러
  final _jobNoCtl = TextEditingController();

  /// 현장명 입력 필드의 텍스트 컨트롤러
  final _siteNameCtl = TextEditingController();

  /// 최하층 입력 필드의 텍스트 컨트롤러
  final _bottomFloorCtl = TextEditingController();

  /// 최상층 입력 필드의 텍스트 컨트롤러
  final _topFloorCtl = TextEditingController();

  /// 제번 입력 필드의 포커스 노드
  final _jobNoFocus = FocusNode();

  /// 현장명 입력 필드의 포커스 노드
  final _siteNameFocus = FocusNode();

  /// 최하층 입력 필드의 포커스 노드
  final _bottomFloorFocus = FocusNode();

  /// 최상층 입력 필드의 포커스 노드
  final _topFloorFocus = FocusNode();

  /// 제번 입력 영역으로 스크롤 이동시킬 때 쓰는 위치 키
  final _jobNoKey = GlobalKey();

  /// 현장명 입력 영역으로 스크롤 이동시킬 때 쓰는 위치 키
  final _siteNameKey = GlobalKey();

  /// 최하층 · 최상층 입력 영역으로 스크롤 이동시킬 때 쓰는 위치 키
  final _floorKey = GlobalKey();

  /// 운전 방향. '하부 → 상부' 또는 '상부 → 하부' 중 하나
  String _direction = '하부 → 상부';

  /// 기종. 'Gen2' 또는 '기타' 중 하나
  String _model = 'Gen2';

  /// 제번 입력 오류 문구. null이면 오류 없음
  String? _jobNoError;

  /// 현장명 입력 오류 문구. null이면 오류 없음
  String? _siteNameError;

  /// 층수 입력 오류 문구. null이면 오류 없음
  String? _floorError;

  /// 작성: 2026-08-17 12:40:41 · 박건준
  /// 함수: initState
  /// 목적: `initState`(이 화면이 새로 만들어질 때, 화면을 그리기 전에
  ///       Flutter가 딱 한 번만 불러주는 생명주기(lifecycle, "만들어짐
  ///       → 화면에 나타남 → 다시 그려짐 → 사라짐"처럼 정해진 순서로
  ///       불리는 함수들) 메서드다. 마지막으로 저장했던 입력값을 불러온다.
  @override
  void initState() {
    super.initState();
    _loadSavedInputs(); // → 로직 이동: _loadSavedInputs()
  }

  /// 작성: 2026-08-17 12:40:41 · 박건준
  /// 함수: _loadSavedInputs
  /// 목적: `PrefsStore`(기기에 값을 저장·불러오는 저장소 클래스)에 저장된
  ///       마지막 현장 정보를 불러와 입력 필드를 채운다.
  ///       - 값을 다 불러오기 전에 위젯이 화면에서 사라졌으면
  ///         (`!mounted`) 그대로 끝낸다. 이미 사라진 위젯에 `setState`
  ///         (상태가 바뀌었으니 화면을 다시 그리라고 Flutter에 알리는
  ///         함수)를 하면 오류가 난다
  ///       - 각 값은 저장된 적이 있을 때(null이 아닐 때)만 반영한다.
  ///         저장된 적 없는 값은 기존 기본값을 그대로 둔다
  Future<void> _loadSavedInputs() async {
    final saved = await PrefsStore.instance.loadLastSite(); // 마지막 저장분
    if (!mounted) return;
    final jobNo = saved['jobNo']; // 저장된 제번, 없으면 null
    final siteName = saved['siteName']; // 저장된 현장명, 없으면 null
    final bottomFloorStr = saved['bottomFloor']; // 저장된 최하층, 없으면 null
    final topFloorStr = saved['topFloor']; // 저장된 최상층, 없으면 null
    final direction = saved['direction']; // 저장된 운전 방향, 없으면 null
    final model = saved['model']; // 저장된 기종, 없으면 null

    setState(() {
      if (jobNo != null) _jobNoCtl.text = jobNo;
      if (siteName != null) _siteNameCtl.text = siteName;
      if (bottomFloorStr != null) _bottomFloorCtl.text = bottomFloorStr;
      if (topFloorStr != null) _topFloorCtl.text = topFloorStr;
      if (direction != null) _direction = direction;
      if (model != null) _model = model;
    });
  }

  /// 작성: 2026-08-17 12:40:41 · 박건준
  /// 함수: dispose
  /// 목적: `dispose`(이 화면이 완전히 사라질 때 Flutter가 마지막으로
  ///       한 번 불러주는 생명주기 메서드. `initState`의 반대 시점)다.
  ///       입력 컨트롤러 4개와 포커스 노드 4개를 정리해, 메모리에 계속
  ///       남아있지 않게 한다.
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

  /// 작성: 2026-08-17 12:40:41 · 박건준
  /// 함수: _startMeasure
  /// 목적: 입력값을 검증하고, 통과하면 측정을 시작한다.
  ///       - 포커스를 해제하고 제번 · 현장명 · 최하층 · 최상층 값을 다듬는다
  ///       - 필수값 누락, 층수가 숫자가 아님, 최상층이 최하층보다 작거나
  ///         같음을 검사한다
  ///       - 오류가 있으면 오류 문구를 표시하고, 첫 오류 필드로 포커스를
  ///         옮기며 그 위치까지 화면을 스크롤한 뒤 여기서 멈춘다
  ///       - 오류가 없으면 입력값을 `SiteInfo`(제번 · 현장명 · 층수 등
  ///         현장 정보를 한데 묶는 자료형)로 묶어 `MeasurementSession`
  ///         (이번 측정 정보를 여러 화면이 공유해 쓰도록 앱 전체에 하나만
  ///         두는 객체)에 저장하고, 다음에 자동으로 채워 넣을 수 있도록
  ///         `PrefsStore`에도 저장한 뒤 `/start`로 넘어간다
  void _startMeasure() {
    // 1) 포커스 해제 및 입력값 다듬기
    FocusScope.of(context).unfocus();

    final jobNo = _jobNoCtl.text.trim(); // 앞뒤 공백을 지운 제번
    final siteName = _siteNameCtl.text.trim(); // 앞뒤 공백을 지운 현장명
    final bottomFloorStr = _bottomFloorCtl.text.trim(); // 최하층 원문
    final topFloorStr = _topFloorCtl.text.trim(); // 최상층 원문

    // 2) 검증
    String? jobNoError; // 제번 오류 문구, 없으면 null
    String? siteNameError; // 현장명 오류 문구, 없으면 null
    String? floorError; // 층수 오류 문구, 없으면 null

    if (jobNo.isEmpty) {
      jobNoError = '제번을 입력하세요 (예: 2024F 1447R01)';
    }

    if (siteName.isEmpty) {
      siteNameError = '현장명을 입력하세요 (예: 럭키종합건설/송정동근생)';
    }

    if (bottomFloorStr.isEmpty || topFloorStr.isEmpty) {
      floorError = '최하층과 최상층을 모두 입력하세요';
    } else {
      final bottomFloor = int.tryParse(bottomFloorStr); // 최하층 숫자, 변환 실패 시 null
      final topFloor = int.tryParse(topFloorStr); // 최상층 숫자, 변환 실패 시 null
      if (bottomFloor == null || topFloor == null) {
        floorError = '층수는 숫자로 입력하세요';
      } else if (bottomFloor >= topFloor) {
        floorError = '최상층이 최하층보다 커야 합니다';
      }
    }

    setState(() {
      _jobNoError = jobNoError;
      _siteNameError = siteNameError;
      _floorError = floorError;
    });

    // 3) 오류가 있으면 첫 오류 필드로 포커스 · 스크롤 이동 후 종료
    if (jobNoError != null || siteNameError != null || floorError != null) {
      GlobalKey? targetKey; // 스크롤로 보여줄 첫 오류 필드의 위치 키
      if (jobNoError != null) {
        targetKey = _jobNoKey;
        _jobNoFocus.requestFocus();
      } else if (siteNameError != null) {
        targetKey = _siteNameKey;
        _siteNameFocus.requestFocus();
      } else if (floorError != null) {
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

    // 4) 오류 없음 — 세션에 반영하고 다음 자동 입력을 위해 저장
    final siteInfo = SiteInfo(
      // 검증을 마친 입력값을 묶은 현장 정보
      jobNo: jobNo,
      siteName: siteName,
      bottomFloor: bottomFloorStr,
      topFloor: topFloorStr,
      direction: _direction,
      model: _model,
    );
    // → 로직 이동: MeasurementSession.instance.currentSite
    MeasurementSession.instance.currentSite = siteInfo;

    PrefsStore.instance.saveLastSite({
      'jobNo': jobNo,
      'siteName': siteName,
      'bottomFloor': bottomFloorStr,
      'topFloor': topFloorStr,
      'direction': _direction,
      'model': _model,
    });

    context.push('/start'); // → 로직 이동: StartScreen.initState()
  }

  /// 작성: 2026-08-17 12:40:41 · 박건준
  /// 함수: _errorBorder
  /// 목적: 입력 필드에 오류가 있을 때 보여줄 빨간 테두리를 만든다.
  OutlineInputBorder _errorBorder() {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDims.radius),
      borderSide: const BorderSide(color: AppColors.red, width: 2),
    );
  }

  /// 작성: 2026-08-17 12:40:41 · 박건준
  /// 함수: _buildErrorBox
  /// 목적: 오류 문구를 아이콘 · 빨간 박스와 함께 보여주는 위젯을 만든다.
  /// 인자: message — 화면에 보여줄 오류 문구
  /// 반환: 오류 안내용 위젯
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

  /// 작성: 2026-08-17 12:40:41 · 박건준
  /// 함수: _buildActionBtn
  /// 목적: 앱바 오른쪽에 쓰는 아이콘 + 문구 버튼을 만든다.
  /// 인자: onPressed — 버튼을 눌렀을 때 실행할 동작
  ///       icon — 버튼에 쓸 아이콘
  ///       label — 버튼에 표시할 문구
  /// 반환: 스타일이 적용된 액션 버튼 위젯
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

  /// 작성: 2026-08-17 12:40:41 · 박건준
  /// 함수: _buildJobNoField
  /// 목적: 제번 입력 필드를 만든다. 값을 고치면 오류 표시를 지운다.
  /// 반환: 제번 입력 영역 위젯
  Widget _buildJobNoField() {
    return Container(
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
                enabledBorder: _jobNoError != null ? _errorBorder() : null,
                focusedBorder: _jobNoError != null ? _errorBorder() : null,
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
    );
  }

  /// 작성: 2026-08-17 12:40:41 · 박건준
  /// 함수: _buildSiteNameField
  /// 목적: 현장명 입력 필드를 만든다. 값을 고치면 오류 표시를 지운다.
  /// 반환: 현장명 입력 영역 위젯
  Widget _buildSiteNameField() {
    return Container(
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
                enabledBorder: _siteNameError != null ? _errorBorder() : null,
                focusedBorder: _siteNameError != null ? _errorBorder() : null,
              ),
              onSubmitted: (_) => _bottomFloorFocus.requestFocus(),
              onChanged: (_) {
                if (_siteNameError != null) {
                  setState(() => _siteNameError = null);
                }
              },
            ),
          ),
          if (_siteNameError != null) _buildErrorBox(_siteNameError!),
        ],
      ),
    );
  }

  /// 작성: 2026-08-17 12:40:41 · 박건준
  /// 함수: _buildFloorFields
  /// 목적: 최하층 · 최상층 입력 필드 2개를 나란히 만든다. 숫자만 입력받고,
  ///       값을 고치면 오류 표시를 지운다.
  /// 반환: 최하층 · 최상층 입력 영역 위젯
  Widget _buildFloorFields() {
    return Container(
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
                    onSubmitted: (_) => _topFloorFocus.requestFocus(),
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
    );
  }

  /// 작성: 2026-08-17 12:40:41 · 박건준
  /// 함수: _buildDirectionSelector
  /// 목적: 운전 방향(하부 → 상부 / 상부 → 하부)을 고르는 버튼 2개를 만든다.
  /// 반환: 운전 방향 선택 위젯
  Widget _buildDirectionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
      ],
    );
  }

  /// 작성: 2026-08-17 12:40:41 · 박건준
  /// 함수: _buildModelSelector
  /// 목적: 기종(Gen2 / 기타)을 고르는 드롭다운을 만든다.
  /// 반환: 기종 선택 위젯
  Widget _buildModelSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
      ],
    );
  }

  /// 작성: 2026-08-17 12:40:41 · 박건준
  /// 함수: build
  /// 목적: 홈 화면(현장 정보 입력) 레이아웃을 구성한다.
  ///       - `appBar` — 화면 제목과, 설정·저장 결과 화면으로 이동하는
  ///         버튼 2개
  ///       - `body` — 스크롤 가능한 입력 폼. 제번 → 현장명 → 최하층·최상층
  ///         → 운전 방향 → 기종 순으로 입력받는다. `_startMeasure`가 찾아낸
  ///         오류는 각 필드 아래 빨간 오류 박스로 표시한다
  ///       - `bottomNavigationBar` — 입력을 마치고 `_startMeasure`를 호출해
  ///         `/start`로 넘어가는 "측정 시작" 버튼
  /// 인자: context — 이 화면이 어디에 놓이는지 알려주는 값. `appBar`의
  ///       설정·저장 결과 버튼이 다른 화면으로 넘어갈 때 쓴다
  /// 반환: 홈 화면 전체를 담는 `Scaffold` 위젯
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 화면 전체 틀
      appBar: AppBar(
        // 상단 앱바: 제목 + 설정 · 저장 결과 버튼
        title: const Text('진동 측정'),
        actions: [
          _buildActionBtn(
            // → 로직 이동: SettingsScreen.build()
            onPressed: () => context.push('/settings'),
            icon: Icons.settings_outlined,
            label: '설정',
          ),
          _buildActionBtn(
            // → 로직 이동: HistoryScreen.build()
            onPressed: () => context.push('/history'),
            icon: Icons.folder_open_outlined,
            label: '저장 결과',
          ),
          const SizedBox(width: AppDims.gap),
        ],
      ),
      body: SafeArea(
        // 시스템 UI(노치 등)를 피해서 배치
        child: SingleChildScrollView(
          // 입력 폼 전체를 세로로 스크롤
          padding: const EdgeInsets.all(AppDims.screenPad),
          child: ConstrainedBox(
            // 넓은 화면에서 폭이 과하게 늘어나지 않게 제한
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              // 입력 필드들을 순서대로 세로로 배치
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppDims.gap),
                Text('현장 정보', style: AppText.subhead),
                const SizedBox(height: AppDims.gap3),

                _buildJobNoField(),
                const SizedBox(height: AppDims.gap3),
                _buildSiteNameField(),
                const SizedBox(height: AppDims.gap3),
                _buildFloorFields(),
                const SizedBox(height: AppDims.gap3),
                _buildDirectionSelector(),
                const SizedBox(height: AppDims.gap3),
                _buildModelSelector(),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        // 하단 고정 영역, 시스템 UI를 피해서 배치
        child: Padding(
          padding: const EdgeInsets.all(AppDims.screenPad),
          child: ElevatedButton(
            onPressed: _startMeasure, // → 로직 이동: _startMeasure()
            child: const Text('측정 시작'),
          ),
        ),
      ),
    );
  }
}
