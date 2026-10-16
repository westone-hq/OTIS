import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_layout.dart';
import '../../core/widgets/app_notice.dart';
import 'package:vibration_checker/domain/session/measurement_session.dart';
import 'package:vibration_checker/adapter/prefs_store.dart';
import '../update/update_prompt.dart';

/// 작성: 2026-10-11 17:28:28 · nada
/// 클래스: _HomeLayout
/// 목적: 홈 화면 입력칸 배치에만 쓰는 수치. 다른 화면은 쓰지 않아
///       `theme.dart` 토큰으로 올리지 않는다.
class _HomeLayout {
  /// 추가 참고사항 입력칸이 처음 보이는 줄 수
  static const int notesMinLines = 3;

  /// 추가 참고사항 입력칸이 늘어나는 최대 줄 수. 넘치면 칸 안에서
  /// 스크롤된다
  static const int notesMaxLines = 5;
}

/// 작성: 2026-08-17 12:40:41 · 박건준
/// 수정: 2026-10-13 14:27:24 · nada
/// 클래스: HomeScreen
/// 목적: 이번 측정의 현장 정보(제번, 현장명, 우편번호 · 주소, 층수, 운전
///       방향, 기종, 하중, 해석 종류, 추가 참고사항)를 입력받고 측정을
///       시작하는 홈 화면.
///       - 어르신도 쓰기 쉽도록 필드·버튼 높이 64dp, 터치 영역 최소 56dp,
///         본문 글자 크기 18 이상으로 맞춘다
///       - 입력 오류는 색·아이콘·문구 세 가지를 함께 표시하고, 오류가 난
///         위치로 자동 스크롤한다
///       - 앱이 켜져 처음 뜰 때 한 번 업데이트를 확인한다
///         (`UpdatePrompt.checkAtLaunch()`)
class HomeScreen extends StatefulWidget {
  /// 작성: 2026-10-13 14:27:24 · nada
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
/// 수정: 2026-10-11 17:28:28 · nada
/// 클래스: _HomeScreenState
/// 목적: 홈 화면의 입력 상태를 관리한다. 입력이 바뀔 때마다 기기에 저장해,
///       다음 측정이나 다음 앱 실행 때 마지막 입력이 그대로 남게 한다.
///       추가 참고사항만은 현장마다 달라 저장하지 않고 빈 칸에서 시작한다
///       (`SiteInfo.toMap()` 참고).
///       - 입력 컨트롤러 8개(제번 · 현장명 · 우편번호 · 주소 · 최하층 ·
///         최상층 · 하중 · 참고사항)와 포커스 노드로 텍스트 필드 값과 포커스
///         이동을 관리한다
///       - 운전 방향 · 기종 · 하중 단위 · 해석 종류는 선택형 값이라 별도
///         컨트롤러 없이 상태 필드로만 둔다
///       - 오류 문구 5개(`_jobNoError` 등)와 스크롤 대상 키 5개로, 검증
///         실패 시 표시·스크롤 위치를 잡는다
class _HomeScreenState extends State<HomeScreen> {
  /// 제번 입력 필드의 텍스트 컨트롤러
  final _jobNoCtl = TextEditingController();

  /// 현장명 입력 필드의 텍스트 컨트롤러
  final _siteNameCtl = TextEditingController();

  /// 우편번호 입력 필드의 텍스트 컨트롤러
  final _postalCodeCtl = TextEditingController();

  /// 주소 입력 필드의 텍스트 컨트롤러
  final _addressCtl = TextEditingController();

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

  /// 우편번호 입력 필드의 포커스 노드
  final _postalCodeFocus = FocusNode();

  /// 주소 입력 필드의 포커스 노드
  final _addressFocus = FocusNode();

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

  /// 우편번호 · 주소 입력 영역으로 스크롤 이동시킬 때 쓰는 위치 키
  final _addressKey = GlobalKey();

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

  /// 우편번호 · 주소 입력 오류 문구. 둘 다 걸리면 두 줄이다. null이면
  /// 오류 없음
  String? _addressError;

  /// 층수 입력 오류 문구. null이면 오류 없음
  String? _floorError;

  /// 하중 입력 오류 문구. null이면 오류 없음
  String? _loadError;

  /// 작성: 2026-08-17 12:40:41 · 박건준
  /// 수정: 2026-10-13 14:27:24 · nada
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
  /// 수정: 2026-10-13 13:17:56 · nada
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
      _postalCodeCtl.text = site.postalCode;
      _addressCtl.text = site.address;
      _bottomFloorCtl.text = site.bottomFloor;
      _topFloorCtl.text = site.topFloor;
      _loadCtl.text = site.load;
      _direction = site.direction;
      _model = site.model;
      _analysisType = site.analysisType;
    });
  }

  /// 작성: 2026-10-04 16:44:32 · nada
  /// 수정: 2026-10-13 13:17:56 · nada
  /// 함수: _currentSite
  /// 목적: 지금 입력창 · 선택지에 있는 값을 앞뒤 공백을 지워 현장 정보로
  ///       묶는다.
  /// 반환: 지금 입력된 현장 정보. 검사는 하지 않는다
  SiteInfo _currentSite() {
    return SiteInfo(
      jobNo: _jobNoCtl.text.trim(),
      siteName: _siteNameCtl.text.trim(),
      address: _addressCtl.text.trim(),
      bottomFloor: _bottomFloorCtl.text.trim(),
      topFloor: _topFloorCtl.text.trim(),
      direction: _direction,
      model: _model,
      load: _loadCtl.text.trim(),
      analysisType: _analysisType,
      postalCode: _postalCodeCtl.text.trim(),
      notes: _notesCtl.text.trim(),
    );
  }

  /// 작성: 2026-10-04 16:44:32 · nada
  /// 함수: _saveDraft
  /// 목적: 지금 입력을 마지막 현장 정보로 저장한다. 입력이 바뀔 때마다
  ///       부른다 — 측정을 시작하지 않고 앱을 닫아도 다음에 그대로
  ///       남게 하려는 것이다. 검사를 통과하지 않은 값도 저장한다.
  void _saveDraft() {
    // → 로직 이동: PrefsStore.saveLastSite()
    PrefsStore.instance.saveLastSite(_currentSite().toMap());
  }

  /// 작성: 2026-08-17 12:40:41 · 박건준
  /// 수정: 2026-10-11 17:28:28 · nada
  /// 함수: dispose
  /// 목적: `dispose`(이 화면이 완전히 사라질 때 Flutter가 마지막으로
  ///       한 번 불러주는 생명주기 메서드. `initState`의 반대 시점)다.
  ///       입력 컨트롤러 8개와 포커스 노드 7개를 정리해, 메모리에 계속
  ///       남아있지 않게 한다.
  @override
  void dispose() {
    _jobNoCtl.dispose();
    _siteNameCtl.dispose();
    _postalCodeCtl.dispose();
    _addressCtl.dispose();
    _bottomFloorCtl.dispose();
    _topFloorCtl.dispose();
    _loadCtl.dispose();
    _notesCtl.dispose();
    _jobNoFocus.dispose();
    _siteNameFocus.dispose();
    _postalCodeFocus.dispose();
    _addressFocus.dispose();
    _bottomFloorFocus.dispose();
    _topFloorFocus.dispose();
    _loadFocus.dispose();
    super.dispose();
  }

  /// 작성: 2026-08-17 12:40:41 · 박건준
  /// 수정: 2026-10-11 17:28:28 · nada
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
    final jobNoError = errors.contains(SiteFieldError.jobNoMissing)
        ? '제번을 입력하세요'
        : null; // 제번 오류 문구, 없으면 null
    final siteNameError = errors.contains(SiteFieldError.siteNameMissing)
        ? '현장명을 입력하세요'
        : null; // 현장명 오류 문구, 없으면 null
    // → 로직 이동: _addressErrorMessage()
    final addressError = _addressErrorMessage(errors); // 우편번호 · 주소 오류
    // → 로직 이동: _floorErrorMessage()
    final floorError = _floorErrorMessage(errors); // 층수 오류 문구, 없으면 null
    // → 로직 이동: _loadErrorMessage()
    final loadError = _loadErrorMessage(errors); // 하중 오류 문구, 없으면 null

    setState(() {
      _jobNoError = jobNoError;
      _siteNameError = siteNameError;
      _addressError = addressError;
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
      } else if (addressError != null) {
        targetKey = _addressKey;
        if (errors.contains(SiteFieldError.postalCodeMissing) ||
            errors.contains(SiteFieldError.postalCodeInvalid)) {
          _postalCodeFocus.requestFocus();
        } else {
          _addressFocus.requestFocus();
        }
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

  /// 작성: 2026-10-11 17:28:28 · nada
  /// 함수: _addressErrorMessage
  /// 목적: 우편번호 · 주소 검사에 걸린 항목을 안내 문구로 바꾼다. 두 칸이
  ///       한 줄에 있어 오류 상자도 하나를 쓰고, 둘 다 걸리면 두 줄로
  ///       보인다.
  /// 인자: errors — `SiteInfo.validate()` 가 돌려준 목록
  /// 반환: 우편번호 · 주소 오류 문구. 둘 다 문제가 없으면 null
  String? _addressErrorMessage(List<SiteFieldError> errors) {
    final lines = <String>[
      if (errors.contains(SiteFieldError.postalCodeMissing)) '우편번호를 입력하세요',
      if (errors.contains(SiteFieldError.postalCodeInvalid))
        '우편번호는 숫자 ${SiteInfo.postalCodeLength}자리로 입력하세요',
      if (errors.contains(SiteFieldError.addressMissing)) '주소를 입력하세요',
    ]; // 걸린 항목마다 한 줄
    return lines.isEmpty ? null : lines.join('\n');
  }

  /// 작성: 2026-10-04 13:35:26 · nada
  /// 함수: _floorErrorMessage
  /// 목적: 층수 검사에 걸린 항목을 안내 문구로 바꾼다. 층수 오류는 한 번에
  ///       하나만 나온다.
  /// 인자: errors — `SiteInfo.validate()` 가 돌려준 목록
  /// 반환: 층수 오류 문구. 층수에 문제가 없으면 null
  String? _floorErrorMessage(List<SiteFieldError> errors) {
    if (errors.contains(SiteFieldError.floorMissing)) {
      return '최하층과 최상층을 모두 입력하세요';
    }
    if (errors.contains(SiteFieldError.floorNotNumber)) {
      return '층수는 숫자로 입력하세요';
    }
    if (errors.contains(SiteFieldError.floorNotAscending)) {
      return '최상층이 최하층보다 커야 합니다';
    }
    return null;
  }

  /// 작성: 2026-10-11 17:28:28 · nada
  /// 함수: _loadErrorMessage
  /// 목적: 하중 검사에 걸린 항목을 안내 문구로 바꾼다. 하중 오류는 한 번에
  ///       하나만 나온다.
  /// 인자: errors — `SiteInfo.validate()` 가 돌려준 목록
  /// 반환: 하중 오류 문구. 하중에 문제가 없으면 null
  String? _loadErrorMessage(List<SiteFieldError> errors) {
    if (errors.contains(SiteFieldError.loadMissing)) return '하중을 입력하세요';
    if (errors.contains(SiteFieldError.loadNotNumber)) {
      return '하중은 0 보다 큰 숫자로 입력하세요';
    }
    return null;
  }

  /// 작성: 2026-08-17 12:40:41 · 박건준
  /// 수정: 2026-10-04 13:37:23 · nada
  /// 함수: _errorBorder
  /// 목적: 입력 필드에 오류가 있을 때 보여줄 빨간 테두리를 만든다.
  /// 반환: 빨간 테두리 스타일
  OutlineInputBorder _errorBorder() {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDims.radius),
      borderSide: const BorderSide(
        color: AppColors.red,
        width: AppDims.borderWThick,
      ),
    );
  }

  /// 작성: 2026-08-17 12:40:41 · 박건준
  /// 수정: 2026-10-04 13:37:23 · nada
  /// 함수: _buildErrorBox
  /// 목적: 오류 문구를 아이콘 · 빨간 박스와 함께 보여주는 위젯을 만든다.
  /// 인자: message — 화면에 보여줄 오류 문구
  /// 반환: 오류 안내용 위젯
  Widget _buildErrorBox(String message) {
    return Padding(
      padding: const EdgeInsets.only(top: AppDims.gap2),
      child: AppNotice(
        icon: Icons.error_outline,
        message: message,
        tone: NoticeTone.danger,
      ),
    );
  }

  /// 작성: 2026-08-17 12:40:41 · 박건준
  /// 수정: 2026-10-04 13:37:23 · nada
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
  /// 수정: 2026-10-04 16:44:32 · nada
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
                enabledBorder: _jobNoError != null ? _errorBorder() : null,
                focusedBorder: _jobNoError != null ? _errorBorder() : null,
              ),
              onSubmitted: (_) => _siteNameFocus.requestFocus(),
              onChanged: (_) {
                _saveDraft(); // → 로직 이동: _saveDraft()
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
  /// 수정: 2026-10-11 17:28:28 · nada
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
                enabledBorder: _siteNameError != null ? _errorBorder() : null,
                focusedBorder: _siteNameError != null ? _errorBorder() : null,
              ),
              onSubmitted: (_) => _postalCodeFocus.requestFocus(),
              onChanged: (_) {
                _saveDraft(); // → 로직 이동: _saveDraft()
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

  /// 작성: 2026-10-04 16:44:32 · nada
  /// 수정: 2026-10-11 17:28:28 · nada
  /// 함수: _buildAddressField
  /// 목적: 우편번호와 현장 주소를 받는다. 둘 다 필수이고 리포트 머리말
  ///       주소 칸에 "주소, 우편번호" 로 찍힌다. 우편번호는 주소 위 줄에
  ///       화면 반 폭으로 둔다 — 주소와 한 줄에 두면 360dp 폭 화면에서
  ///       라벨과 다섯 자리가 잘린다(2026-10-11 캡처). 숫자 키패드로
  ///       `SiteInfo.postalCodeLength` 자리까지만 받는다. 값을 고치면 오류
  ///       표시를 지운다.
  /// 반환: 우편번호 · 주소 입력 영역 위젯
  Widget _buildAddressField() {
    return Container(
      key: _addressKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('주소', style: AppText.bodyBold),
          const SizedBox(height: AppDims.gap),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: AppDims.fieldH,
                  child: TextField(
                    controller: _postalCodeCtl,
                    focusNode: _postalCodeFocus,
                    style: AppText.body,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(
                        SiteInfo.postalCodeLength,
                      ),
                    ],
                    decoration: InputDecoration(
                      labelText: '우편번호',
                      enabledBorder: _addressError != null
                          ? _errorBorder()
                          : null,
                      focusedBorder: _addressError != null
                          ? _errorBorder()
                          : null,
                    ),
                    onSubmitted: (_) => _addressFocus.requestFocus(),
                    onChanged: (_) => _onAddressChanged(),
                  ),
                ),
              ),
              const SizedBox(width: AppDims.gap2),
              const Spacer(), // 우편번호 칸을 화면 반 폭으로 둔다
            ],
          ),
          const SizedBox(height: AppDims.gap),
          SizedBox(
            height: AppDims.fieldH,
            child: TextField(
              controller: _addressCtl,
              focusNode: _addressFocus,
              style: AppText.body,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: '도로명 주소',
                enabledBorder: _addressError != null ? _errorBorder() : null,
                focusedBorder: _addressError != null ? _errorBorder() : null,
              ),
              onSubmitted: (_) => _bottomFloorFocus.requestFocus(),
              onChanged: (_) => _onAddressChanged(),
            ),
          ),
          if (_addressError != null) _buildErrorBox(_addressError!),
        ],
      ),
    );
  }

  /// 작성: 2026-10-11 17:28:28 · nada
  /// 함수: _onAddressChanged
  /// 목적: 우편번호나 주소를 고쳤을 때 입력을 저장하고 오류 표시를 지운다.
  ///       두 칸이 오류 상자 하나를 함께 쓴다.
  void _onAddressChanged() {
    _saveDraft(); // → 로직 이동: _saveDraft()
    if (_addressError != null) setState(() => _addressError = null);
  }

  /// 작성: 2026-08-17 12:40:41 · 박건준
  /// 수정: 2026-10-04 16:44:32 · nada
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
                      _saveDraft(); // → 로직 이동: _saveDraft()
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
                      _saveDraft(); // → 로직 이동: _saveDraft()
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

  /// 작성: 2026-10-11 17:28:28 · nada
  /// 수정: 2026-10-13 13:17:56 · nada
  /// 함수: _segmentStyle
  /// 목적: 운전 방향 버튼 묶음의 모양. 터치 영역 56dp 를 지킨다.
  /// 반환: 버튼 묶음 스타일
  ButtonStyle _segmentStyle() {
    return SegmentedButton.styleFrom(
      backgroundColor: AppColors.surface,
      selectedBackgroundColor: AppColors.blue,
      selectedForegroundColor: AppColors.onDark,
      foregroundColor: AppColors.navy,
      textStyle: AppText.bodyBold,
      minimumSize: const Size(0, AppDims.touchMin),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDims.radius),
      ),
    );
  }

  /// 작성: 2026-08-17 12:40:41 · 박건준
  /// 수정: 2026-10-11 17:28:28 · nada
  /// 함수: _buildDirectionSelector
  /// 목적: 운전 방향(상승 / 하강)을 고르는 버튼 2개를 만든다.
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
              value: SiteInfo.directionUp,
              label: Padding(
                padding: EdgeInsets.symmetric(vertical: AppDims.gap2),
                child: Text(SiteInfo.directionUp),
              ),
              icon: Icon(Icons.arrow_upward),
            ),
            ButtonSegment<String>(
              value: SiteInfo.directionDown,
              label: Padding(
                padding: EdgeInsets.symmetric(vertical: AppDims.gap2),
                child: Text(SiteInfo.directionDown),
              ),
              icon: Icon(Icons.arrow_downward),
            ),
          ],
          selected: {_direction},
          onSelectionChanged: (val) {
            setState(() => _direction = val.first);
            _saveDraft(); // → 로직 이동: _saveDraft()
          },
          style: _segmentStyle(), // → 로직 이동: _segmentStyle()
        ),
      ],
    );
  }

  /// 작성: 2026-10-11 17:28:28 · nada
  /// 함수: _buildDropdown
  /// 목적: 선택지 하나를 고르는 드롭다운을 라벨과 함께 만든다. 기종과 해석
  ///       종류가 같은 모양을 쓴다. 긴 선택지("사이클 저크(가속도증가율)
  ///       테스트")도 칸 폭에 맞춰 보이게 칸을 가로로 채운다.
  /// 인자: label — 드롭다운 위 라벨
  ///       value — 지금 고른 값. `options` 가운데 하나
  ///       options — 선택지와 그 차례
  ///       onChanged — 다른 값을 고르면 부를 함수. 고른 값을 받는다
  /// 반환: 라벨 + 드롭다운 위젯
  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: AppText.bodyBold),
        const SizedBox(height: AppDims.gap),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          items: [
            for (final option in options)
              DropdownMenuItem(value: option, child: Text(option)),
          ],
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
          style: AppText.body,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: AppDims.iconM,
            color: AppColors.navy,
          ),
          // 여백 · 테두리는 앱 테마의 입력창 설정을 그대로 따른다
          decoration: const InputDecoration(),
        ),
      ],
    );
  }

  /// 작성: 2026-08-17 12:40:41 · 박건준
  /// 수정: 2026-10-11 17:28:28 · nada
  /// 함수: _buildModelSelector
  /// 목적: 기종을 고르는 드롭다운을 만든다. 선택지는
  ///       `SiteInfo.modelOptions` 차례 그대로다.
  /// 반환: 기종 선택 위젯
  Widget _buildModelSelector() {
    // → 로직 이동: _buildDropdown()
    return _buildDropdown(
      label: '기종',
      value: _model,
      options: SiteInfo.modelOptions,
      onChanged: (val) {
        setState(() => _model = val);
        _saveDraft(); // → 로직 이동: _saveDraft()
      },
    );
  }

  /// 작성: 2026-10-11 17:28:28 · nada
  /// 수정: 2026-10-13 13:17:56 · nada
  /// 함수: _buildLoadField
  /// 목적: 하중 입력칸과 단위 글자(`SiteInfo.loadUnit`, kg)를 한 줄에
  ///       만든다. 단위는 고를 수 없다(2026-10-13 kg 고정). 입력칸 안
  ///       꼬리 글자(suffixText)는 빈 칸일 때 숨으므로 칸 밖 같은 줄에
  ///       둔다. 하중은 소수점이 있는 숫자 키패드로 받고, 숫자인지는 측정
  ///       시작 때 `SiteInfo.validate()` 가 본다. 값을 고치면 오류 표시를
  ///       지운다.
  /// 반환: 하중 입력 영역 위젯
  Widget _buildLoadField() {
    return Container(
      key: _loadKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('하중', style: AppText.bodyBold),
          const SizedBox(height: AppDims.gap),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: AppDims.fieldH,
                  child: TextField(
                    controller: _loadCtl,
                    focusNode: _loadFocus,
                    style: AppText.body,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[0-9.]')),
                    ],
                    decoration: InputDecoration(
                      hintText: '숫자',
                      enabledBorder: _loadError != null ? _errorBorder() : null,
                      focusedBorder: _loadError != null ? _errorBorder() : null,
                    ),
                    onChanged: (_) {
                      _saveDraft(); // → 로직 이동: _saveDraft()
                      if (_loadError != null) {
                        setState(() => _loadError = null);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: AppDims.gap2),
              Text(SiteInfo.loadUnit, style: AppText.bodyBold),
            ],
          ),
          if (_loadError != null) _buildErrorBox(_loadError!),
        ],
      ),
    );
  }

  /// 작성: 2026-10-11 17:28:28 · nada
  /// 함수: _buildAnalysisTypeSelector
  /// 목적: "분석 내용" 소제목 아래에 해석 종류 드롭다운을 만든다. 고른
  ///       문구가 리포트 머리말 측정 칸에 찍힌다. 측정 · 지표 계산은 종류와
  ///       상관없이 같다.
  /// 반환: 분석 내용 영역 위젯
  Widget _buildAnalysisTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('분석 내용', style: AppText.subhead),
        const SizedBox(height: AppDims.gap2),
        // → 로직 이동: _buildDropdown()
        _buildDropdown(
          label: '해석 종류',
          value: _analysisType,
          options: SiteInfo.analysisTypeOptions,
          onChanged: (val) {
            setState(() => _analysisType = val);
            _saveDraft(); // → 로직 이동: _saveDraft()
          },
        ),
      ],
    );
  }

  /// 작성: 2026-10-11 17:28:28 · nada
  /// 함수: _buildNotesField
  /// 목적: 추가 참고사항을 여러 줄로 받는다. 비워 둬도 측정을 시작할 수
  ///       있고, 적은 내용은 메일 본문에만 들어간다. 현장마다 달라 기기에
  ///       저장하지 않는다.
  /// 반환: 추가 참고사항 입력 영역 위젯
  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('추가 참고사항 (선택)', style: AppText.bodyBold),
        const SizedBox(height: AppDims.gap),
        TextField(
          controller: _notesCtl,
          style: AppText.body,
          keyboardType: TextInputType.multiline,
          minLines: _HomeLayout.notesMinLines,
          maxLines: _HomeLayout.notesMaxLines,
        ),
        const SizedBox(height: AppDims.gap),
        Text('메일 본문에 들어갑니다', style: AppText.caption),
      ],
    );
  }

  /// 작성: 2026-08-17 12:40:41 · 박건준
  /// 수정: 2026-10-11 17:28:28 · nada
  /// 함수: build
  /// 목적: 홈 화면(현장 정보 입력) 레이아웃을 구성한다.
  ///       - `appBar` — 화면 제목과, 설정·저장 결과 화면으로 이동하는
  ///         버튼 2개
  ///       - `body` — 스크롤 가능한 입력 폼. 제번 → 현장명 → 우편번호 ·
  ///         주소 → 최하층·최상층 → 운전 방향 → 기종 → 하중 · 단위 → 분석
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

          _buildJobNoField(),
          const SizedBox(height: AppDims.gap3),
          _buildSiteNameField(),
          const SizedBox(height: AppDims.gap3),
          _buildAddressField(),
          const SizedBox(height: AppDims.gap3),
          _buildFloorFields(),
          const SizedBox(height: AppDims.gap3),
          _buildDirectionSelector(),
          const SizedBox(height: AppDims.gap3),
          _buildModelSelector(),
          const SizedBox(height: AppDims.gap3),
          _buildLoadField(),
          const SizedBox(height: AppDims.gap5),
          _buildAnalysisTypeSelector(),
          const SizedBox(height: AppDims.gap3),
          _buildNotesField(),
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
