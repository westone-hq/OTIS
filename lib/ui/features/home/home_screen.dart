import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vibration_checker/adapter/storage/prefs_store.dart';
import 'package:vibration_checker/domain/session/measurement_session.dart';
import 'package:vibration_checker/domain/session/site_info.dart';
import 'package:vibration_checker/ui/core/theme.dart';
import 'package:vibration_checker/ui/core/widgets/app_dialog.dart';
import 'package:vibration_checker/ui/core/widgets/app_layout.dart';
import 'package:vibration_checker/ui/features/home/site_field_messages.dart';
import 'package:vibration_checker/ui/features/home/widgets/direction_selector.dart';
import 'package:vibration_checker/ui/features/home/widgets/floor_fields.dart';
import 'package:vibration_checker/ui/features/home/widgets/labeled_dropdown.dart';
import 'package:vibration_checker/ui/features/home/widgets/load_field.dart';
import 'package:vibration_checker/ui/features/home/widgets/notes_field.dart';
import 'package:vibration_checker/ui/features/home/widgets/site_text_field.dart';
import 'package:vibration_checker/ui/features/update/update_prompt.dart';

/// 작성: 2026-08-17 12:40:41 · 박건준
/// 수정: 2026-10-27 11:00:00 · 박건준
/// 클래스: HomeScreen
/// 목적: 이번 측정의 현장 정보(제번, 현장명, 층수, 운전 방향, 기종, 하중,
///       해석 종류, 추가 참고사항)를 입력받고 측정을 시작하는 홈 화면.
///       주소 · 우편번호는 2026-10-27 사용자 지시로 받지 않는다.
///       - 어르신도 쓰기 쉽도록 필드·버튼 높이 64dp, 터치 영역 최소 56dp,
///         본문 글자 크기 18 이상으로 맞춘다
///       - 입력 오류는 색·아이콘·문구 세 가지를 함께 표시하고, 오류가 난
///         위치로 자동 스크롤한다
///       - 앱이 켜져 처음 뜰 때 한 번 업데이트를 확인한다
///         (`UpdatePrompt.checkAtLaunch()`)
class HomeScreen extends StatefulWidget {
  /// 작성: 2026-10-13 14:27:24 · 박건준
  /// 함수: HomeScreen
  /// 목적: 홈 화면을 만든다.
  /// 인자: updatePrompt — 시작 때 쓸 업데이트 안내 흐름. 안 주면 실제
  ///       서버 · 안드로이드 설치 통로로 만든다
  const HomeScreen({super.key, this.updatePrompt});

  /// 시작 때 쓸 업데이트 안내 흐름. null 이면 기본 흐름
  final UpdatePrompt? updatePrompt;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// 작성: 2026-08-17 12:40:41 · 박건준
/// 수정: 2026-10-27 11:00:00 · 박건준
/// 클래스: _HomeScreenState
/// 목적: 홈 화면의 입력 상태를 관리한다. 입력이 바뀔 때마다 기기에 저장해,
///       다음 측정이나 다음 앱 실행 때 마지막 입력이 그대로 남게 한다.
///       추가 참고사항만은 현장마다 달라 저장하지 않고 빈 칸에서 시작한다
///       (`SiteInfo.toMap()` 참고).
///       - 입력 컨트롤러 6개(제번 · 현장명 · 최하층 · 최상층 · 하중 ·
///         참고사항)와 포커스 노드로 텍스트 필드 값과 포커스
///         이동을 관리한다
///       - 운전 방향 · 기종 · 하중 단위 · 해석 종류는 선택형 값이라 별도
///         컨트롤러 없이 상태 필드로만 둔다
///       - 오류 문구 4개(`_jobNoError` 등)와 스크롤 대상 키 4개로, 검증
///         실패 시 표시·스크롤 위치를 잡는다
///       - 입력 칸 묶음은 `widgets/` 의 위젯이 그리고, 값 · 저장 · 검사 ·
///         시작은 이 상태가 갖는다
class _HomeScreenState extends State<HomeScreen> {
  /// 제번 입력 필드의 텍스트 컨트롤러
  final _jobNoCtl = TextEditingController();

  /// 현장명 입력 필드의 텍스트 컨트롤러
  final _siteNameCtl = TextEditingController();

  /// 최하층 입력 필드의 텍스트 컨트롤러
  final _bottomFloorCtl = TextEditingController();

  /// 최상층 입력 필드의 텍스트 컨트롤러
  final _topFloorCtl = TextEditingController();

  /// 하중 입력 필드의 텍스트 컨트롤러
  final _loadCtl = TextEditingController();

  /// 추가 참고사항 입력 필드의 텍스트 컨트롤러. 기기에 저장하지 않는다
  final _notesCtl = TextEditingController();

  /// 제번 입력 필드의 포커스 노드
  final _jobNoFocus = FocusNode();

  /// 현장명 입력 필드의 포커스 노드
  final _siteNameFocus = FocusNode();

  /// 최하층 입력 필드의 포커스 노드
  final _bottomFloorFocus = FocusNode();

  /// 최상층 입력 필드의 포커스 노드
  final _topFloorFocus = FocusNode();

  /// 하중 입력 필드의 포커스 노드
  final _loadFocus = FocusNode();

  /// 제번 입력 영역으로 스크롤 이동시킬 때 쓰는 위치 키
  final _jobNoKey = GlobalKey();

  /// 현장명 입력 영역으로 스크롤 이동시킬 때 쓰는 위치 키
  final _siteNameKey = GlobalKey();

  /// 최하층 · 최상층 입력 영역으로 스크롤 이동시킬 때 쓰는 위치 키
  final _floorKey = GlobalKey();

  /// 하중 입력 영역으로 스크롤 이동시킬 때 쓰는 위치 키
  final _loadKey = GlobalKey();

  /// 운전 방향. `SiteInfo.directionUp` 또는 `SiteInfo.directionDown`
  String _direction = SiteInfo.directionUp;

  /// 기종. `SiteInfo.modelOptions` 가운데 하나
  String _model = SiteInfo.defaultModel;

  /// 해석 종류. `SiteInfo.analysisTypeOptions` 가운데 하나
  String _analysisType = SiteInfo.defaultAnalysisType;

  /// 제번 입력 오류 문구. null이면 오류 없음
  String? _jobNoError;

  /// 현장명 입력 오류 문구. null이면 오류 없음
  String? _siteNameError;

  /// 층수 입력 오류 문구. null이면 오류 없음
  String? _floorError;

  /// 하중 입력 오류 문구. null이면 오류 없음
  String? _loadError;

  /// 작성: 2026-08-17 12:40:41 · 박건준
  /// 수정: 2026-10-13 14:27:24 · 박건준
  /// 함수: initState
  /// 목적: `initState`(이 화면이 새로 만들어질 때, 화면을 그리기 전에
  ///       Flutter가 딱 한 번만 불러주는 생명주기(lifecycle, "만들어짐
  ///       → 화면에 나타남 → 다시 그려짐 → 사라짐"처럼 정해진 순서로
  ///       불리는 함수들) 메서드다. 마지막으로 저장했던 입력값을 불러온다.
  ///       첫 화면을 그린 뒤 업데이트를 확인한다 — 창을 띄우려면 화면이
  ///       먼저 그려져 있어야 한다. 확인은 앱 실행마다 한 번이다.
  @override
  void initState() {
    super.initState();
    _loadSavedInputs(); // → 로직 이동: _loadSavedInputs()
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final prompt = widget.updatePrompt ?? UpdatePrompt(); // 업데이트 안내 흐름
      // → 로직 이동: UpdatePrompt.checkAtLaunch()
      prompt.checkAtLaunch(context);
    });
  }

  /// 작성: 2026-08-17 12:40:41 · 박건준
  /// 수정: 2026-10-27 11:00:00 · 박건준
  /// 함수: _loadSavedInputs
  /// 목적: `PrefsStore`(기기에 값을 저장·불러오는 저장소 클래스)에 저장된
  ///       마지막 현장 정보를 불러와 입력 필드를 채운다.
  ///       - 값을 다 불러오기 전에 위젯이 화면에서 사라졌으면
  ///         (`!mounted`) 그대로 끝낸다. 이미 사라진 위젯에 `setState`
  ///         (상태가 바뀌었으니 화면을 다시 그리라고 Flutter에 알리는
  ///         함수)를 하면 오류가 난다
  ///       - 저장된 적이 없으면 기본값을 그대로 둔다
  ///       - 선택지에 없는 운전 방향 · 기종 · 하중 단위 · 해석 종류는
  ///         `SiteInfo.fromMap` 이 기본값으로 바꿔 준다
  ///       - 추가 참고사항은 저장돼 있지 않아 빈 칸 그대로다
  Future<void> _loadSavedInputs() async {
    final saved = await PrefsStore.instance.loadLastSite(); // 마지막 저장분
    if (!mounted || saved.isEmpty) return;
    final site = SiteInfo.fromMap(saved); // → 로직 이동: SiteInfo.fromMap()

    setState(() {
      _jobNoCtl.text = site.jobNo;
      _siteNameCtl.text = site.siteName;
      _bottomFloorCtl.text = site.bottomFloor;
      _topFloorCtl.text = site.topFloor;
      _loadCtl.text = site.load;
      _direction = site.direction;
      _model = site.model;
      _analysisType = site.analysisType;
    });
  }

  /// 작성: 2026-10-04 16:44:32 · 박건준
  /// 수정: 2026-10-27 11:00:00 · 박건준
  /// 함수: _currentSite
  /// 목적: 지금 입력창 · 선택지에 있는 값을 앞뒤 공백을 지워 현장 정보로
  ///       묶는다.
  /// 반환: 지금 입력된 현장 정보. 검사는 하지 않는다
  SiteInfo _currentSite() {
    return SiteInfo(
      jobNo: _jobNoCtl.text.trim(),
      siteName: _siteNameCtl.text.trim(),
      bottomFloor: _bottomFloorCtl.text.trim(),
      topFloor: _topFloorCtl.text.trim(),
      direction: _direction,
      model: _model,
      load: _loadCtl.text.trim(),
      analysisType: _analysisType,
      notes: _notesCtl.text.trim(),
    );
  }

  /// 작성: 2026-10-04 16:44:32 · 박건준
  /// 함수: _saveDraft
  /// 목적: 지금 입력을 마지막 현장 정보로 저장한다. 입력이 바뀔 때마다
  ///       부른다 — 측정을 시작하지 않고 앱을 닫아도 다음에 그대로
  ///       남게 하려는 것이다. 검사를 통과하지 않은 값도 저장한다.
  void _saveDraft() {
    // → 로직 이동: PrefsStore.saveLastSite()
    PrefsStore.instance.saveLastSite(_currentSite().toMap());
  }

  /// 작성: 2026-08-17 12:40:41 · 박건준
  /// 수정: 2026-10-27 11:00:00 · 박건준
  /// 함수: dispose
  /// 목적: `dispose`(이 화면이 완전히 사라질 때 Flutter가 마지막으로
  ///       한 번 불러주는 생명주기 메서드. `initState`의 반대 시점)다.
  ///       입력 컨트롤러 6개와 포커스 노드 5개를 정리해, 메모리에 계속
  ///       남아있지 않게 한다.
  @override
  void dispose() {
    _jobNoCtl.dispose();
    _siteNameCtl.dispose();
    _bottomFloorCtl.dispose();
    _topFloorCtl.dispose();
    _loadCtl.dispose();
    _notesCtl.dispose();
    _jobNoFocus.dispose();
    _siteNameFocus.dispose();
    _bottomFloorFocus.dispose();
    _topFloorFocus.dispose();
    _loadFocus.dispose();
    super.dispose();
  }

  /// 작성: 2026-08-17 12:40:41 · 박건준
  /// 수정: 2026-10-27 11:00:00 · 박건준
  /// 함수: _startMeasure
  /// 목적: 입력값을 검증하고, 통과하면 측정을 시작한다.
  ///       - 포커스를 해제하고 입력값을 다듬어 `SiteInfo`(제번 · 현장명 ·
  ///         층수 등 현장 정보를 한데 묶는 자료형)로 묶는다
  ///       - 검사는 `SiteInfo.validate()` 가 한다. 저장할 때도 같은
  ///         검사를 거치므로 기준이 한 곳에 있다
  ///       - 오류가 있으면 오류 문구를 표시하고, 화면 위쪽부터 첫 오류
  ///         필드로 포커스를 옮기며 그 위치까지 화면을 스크롤한 뒤 여기서
  ///         멈춘다
  ///       - 오류가 없으면 현장 정보를 `MeasurementSession`(이번 측정
  ///         정보를 여러 화면이 공유해 쓰도록 앱 전체에 하나만 두는
  ///         객체)에 싣고, 다음에 자동으로 채워 넣을 수 있도록
  ///         `PrefsStore`에도 저장한 뒤 `/start`로 넘어간다
  void _startMeasure() {
    // 1) 포커스 해제 및 입력값 다듬기
    FocusScope.of(context).unfocus();

    final siteInfo = _currentSite(); // → 로직 이동: _currentSite()

    // 2) 검증
    // → 로직 이동: SiteInfo.validate()
    final errors = siteInfo.validate(); // 걸린 항목, 없으면 빈 목록
    // → 로직 이동: jobNoErrorMessage()
    final jobNoError = jobNoErrorMessage(errors); // 제번 오류 문구, 없으면 null
    // → 로직 이동: siteNameErrorMessage()
    final siteNameError = siteNameErrorMessage(errors); // 현장명 오류 문구
    // → 로직 이동: floorErrorMessage()
    final floorError = floorErrorMessage(errors); // 층수 오류 문구, 없으면 null
    // → 로직 이동: loadErrorMessage()
    final loadError = loadErrorMessage(errors); // 하중 오류 문구, 없으면 null

    setState(() {
      _jobNoError = jobNoError;
      _siteNameError = siteNameError;
      _floorError = floorError;
      _loadError = loadError;
    });

    // 3) 오류가 있으면 화면 위쪽부터 첫 오류 필드로 포커스 · 스크롤 이동 후
    //    종료
    if (errors.isNotEmpty) {
      GlobalKey? targetKey; // 스크롤로 보여줄 첫 오류 필드의 위치 키
      if (jobNoError != null) {
        targetKey = _jobNoKey;
        _jobNoFocus.requestFocus();
      } else if (siteNameError != null) {
        targetKey = _siteNameKey;
        _siteNameFocus.requestFocus();
      } else if (floorError != null) {
        targetKey = _floorKey;
        if (siteInfo.bottomFloor.isEmpty) {
          _bottomFloorFocus.requestFocus();
        } else {
          _topFloorFocus.requestFocus();
        }
      } else if (loadError != null) {
        targetKey = _loadKey;
        _loadFocus.requestFocus();
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
    // → 로직 이동: MeasurementSession.instance.currentSite
    MeasurementSession.instance.currentSite = siteInfo;

    // → 로직 이동: PrefsStore.saveLastSite()
    PrefsStore.instance.saveLastSite(siteInfo.toMap());

    context.push('/start'); // → 로직 이동: StartScreen.initState()
  }

  /// 작성: 2026-10-22 23:10:00 · 박건준
  /// 함수: _onEdited
  /// 목적: 입력칸 값이 바뀌었을 때 입력을 저장하고, 그 칸에 오류 표시가
  ///       있으면 지운다. 칸마다 같은 순서라 한 곳에 둔다.
  /// 인자: error — 그 칸의 지금 오류 문구. null 이면 지울 것이 없다
  ///       clear — 그 칸의 오류 문구를 비우는 함수
  void _onEdited(String? error, VoidCallback clear) {
    _saveDraft(); // → 로직 이동: _saveDraft()
    if (error != null) setState(clear);
  }

  /// 작성: 2026-08-17 12:40:41 · 박건준
  /// 수정: 2026-10-04 13:37:23 · 박건준
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
      iconSize: AppDims.iconS,
      textStyle: AppText.caption.copyWith(
        color: AppColors.navy,
        fontWeight: FontWeight.w700,
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppDims.gap2),
    );
  }

  /// 작성: 2026-08-17 12:40:41 · 박건준
  /// 수정: 2026-10-27 11:00:00 · 박건준
  /// 함수: build
  /// 목적: 홈 화면(현장 정보 입력) 레이아웃을 구성한다.
  ///       - `appBar` — 화면 제목과, 설정·저장 결과 화면으로 이동하는
  ///         버튼 2개
  ///       - `body` — 스크롤 가능한 입력 폼. 제번 → 현장명 →
  ///         최하층·최상층 → 운전 방향 → 기종 → 하중 · 단위 → 분석
  ///         내용(해석 종류) → 추가 참고사항 순으로 입력받는다.
  ///         `_startMeasure`가 찾아낸 오류는 각 필드 아래 빨간 오류
  ///         박스로 표시한다
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
      // 입력 필드들을 순서대로 세로로 배치
      body: AppScrollBody(
        children: [
          const SizedBox(height: AppDims.gap),
          Text('현장 정보', style: AppText.subhead),
          const SizedBox(height: AppDims.gap3),

          // → 로직 이동: SiteTextField.build()
          SiteTextField(
            anchorKey: _jobNoKey,
            label: '제번',
            controller: _jobNoCtl,
            focusNode: _jobNoFocus,
            error: _jobNoError,
            onSubmitted: _siteNameFocus.requestFocus,
            onChanged: () => _onEdited(_jobNoError, () => _jobNoError = null),
          ),
          const SizedBox(height: AppDims.gap3),
          // → 로직 이동: SiteTextField.build()
          SiteTextField(
            anchorKey: _siteNameKey,
            label: '현장명',
            controller: _siteNameCtl,
            focusNode: _siteNameFocus,
            error: _siteNameError,
            onSubmitted: _bottomFloorFocus.requestFocus,
            onChanged: () =>
                _onEdited(_siteNameError, () => _siteNameError = null),
          ),
          const SizedBox(height: AppDims.gap3),
          // → 로직 이동: FloorFields.build()
          FloorFields(
            anchorKey: _floorKey,
            bottomController: _bottomFloorCtl,
            bottomFocus: _bottomFloorFocus,
            topController: _topFloorCtl,
            topFocus: _topFloorFocus,
            error: _floorError,
            onTopSubmitted: _startMeasure, // → 로직 이동: _startMeasure()
            onChanged: () => _onEdited(_floorError, () => _floorError = null),
          ),
          const SizedBox(height: AppDims.gap3),
          // → 로직 이동: DirectionSelector.build()
          DirectionSelector(
            direction: _direction,
            onChanged: (val) {
              setState(() => _direction = val);
              _saveDraft(); // → 로직 이동: _saveDraft()
            },
          ),
          const SizedBox(height: AppDims.gap3),
          // → 로직 이동: LabeledDropdown.build()
          LabeledDropdown(
            label: '기종',
            value: _model,
            options: SiteInfo.modelOptions,
            onChanged: (val) {
              setState(() => _model = val);
              _saveDraft(); // → 로직 이동: _saveDraft()
            },
          ),
          const SizedBox(height: AppDims.gap3),
          // → 로직 이동: LoadField.build()
          LoadField(
            anchorKey: _loadKey,
            controller: _loadCtl,
            focusNode: _loadFocus,
            error: _loadError,
            onChanged: () => _onEdited(_loadError, () => _loadError = null),
          ),
          const SizedBox(height: AppDims.gap5),
          // 분석 내용: 고른 해석 종류가 리포트 머리말 측정 칸에 찍힌다.
          // 측정 · 지표 계산은 종류와 상관없이 같다
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('분석 내용', style: AppText.subhead),
              const SizedBox(height: AppDims.gap2),
              // → 로직 이동: LabeledDropdown.build()
              LabeledDropdown(
                label: '해석 종류',
                value: _analysisType,
                options: SiteInfo.analysisTypeOptions,
                onChanged: (val) {
                  setState(() => _analysisType = val);
                  _saveDraft(); // → 로직 이동: _saveDraft()
                },
              ),
            ],
          ),
          const SizedBox(height: AppDims.gap3),
          NotesField(controller: _notesCtl), // → 로직 이동: NotesField.build()
          const SizedBox(height: AppDims.gap6),
        ],
      ),
      bottomNavigationBar: AppBottomBar(
        child: ElevatedButton(
          onPressed: _startMeasure, // → 로직 이동: _startMeasure()
          child: const Text('측정 시작'),
        ),
      ),
    );
  }
}
