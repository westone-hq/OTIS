import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import 'package:vibration_checker/model/measurement_result.dart';
import 'package:vibration_checker/adapter/measurement_repository.dart';
import '../shared/send_email_sheet.dart';
import '../../core/widgets/app_dialog.dart';

/// S5 저장 결과 목록 화면
/// 클래스: HistoryScreen
/// 목적: - 폰에 저장된 과거 측정 결과 목록 표시 및 관리
///       - MeasurementRepository.instance.list() 로 로컬 디스크 조회 및 개별/전체 삭제
///       - 어르신 UX: 88dp 이상의 큰 터치 영역 행, 색+텍스트 3중 상태 표출, 대형 빈 상태 안내
class HistoryScreen extends StatefulWidget {
  /// 작성: 2026-07-03 15:21:58 · 박건준
  /// 함수: HistoryScreen
  /// 목적: 인자 없이 화면을 만든다.
  const HistoryScreen({super.key});

  /// 작성: 2026-07-03 15:21:58 · 박건준
  /// 함수: createState
  /// 목적: 이 화면의 상태 객체(`_HistoryScreenState`)를 만든다.
  /// 반환: 새로 만든 상태 객체
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

/// 클래스: _HistoryScreenState
/// 목적: 저장된 측정 결과 목록의 비동기 로드, 이메일 발송 연결 및 개별
///       삭제 상태를 관리한다.
class _HistoryScreenState extends State<HistoryScreen> {
  /// 화면에 표시 중인 측정 결과 목록. `_loadItems()`가 채운다
  List<MeasurementResult> _items = [];

  /// 목록 조회가 실패했는지 여부. true면 빈 화면에 실패 안내를 덧붙인다
  bool _loadFailed = false;

  /// 작성: 2026-07-03 15:21:58 · 박건준
  /// 함수: initState
  /// 목적: 이 화면이 나타날 때 한 번, 저장된 결과 목록을 불러온다.
  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  /// 함수: _showMockFailure
  /// 목적: 저장·출력 계층 미구현 실패를 사용자가 이해할 수 있는 문구로 화면에 보여준다.
  /// 인자: request — 시도한 동작을 설명하는 한국어 문구
  /// 반환: 없음
  void _showMockFailure(String request) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('저장·출력 기능은 아직 구현되지 않았습니다.\n(요청: $request)'),
        backgroundColor: AppColors.red,
      ),
    );
  }

  /// 작성: 2026-07-04 15:52:54 · 박건준
  /// 함수: _loadItems
  /// 목적: 저장소에서 측정 결과 목록을 불러와 화면 상태에 채운다.
  ///       조회에 실패하면 빈 목록으로 두고 실패 상태를 표시한다.
  Future<void> _loadItems() async {
    try {
      final list = await MeasurementRepository.instance.list();
      if (mounted) {
        setState(() {
          _items = list;
          _loadFailed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _items = [];
          _loadFailed = true;
        });
      }
    }
  }

  /// 작성: 2026-07-03 15:21:58 · 박건준
  /// 함수: _showSendEmailSheet
  /// 목적: 해당 측정 결과를 첨부해 이메일 발송 시트를 띄운다.
  /// 인자: jobId — 첨부할 측정 결과의 식별자
  void _showSendEmailSheet(String jobId) {
    showSendEmailSheet(context, jobId: jobId);
  }

  /// 작성: 2026-07-04 15:52:54 · 박건준
  /// 함수: _confirmDelete
  /// 목적: 삭제 확인 대화상자를 띄우고, "삭제"를 선택하면 저장소에서
  ///       해당 항목을 지운 뒤 화면 목록에서도 제거한다.
  /// 인자: item — 삭제할 측정 결과
  Future<void> _confirmDelete(MeasurementResult item) async {
    final bool? confirmed = await showDialog<bool>( // 사용자 선택. "삭제"면 true
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('측정 결과 삭제'),
        content: Text('${item.jobNo} (${_formatDate(item.dateTime)}) 결과를 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          AppDialogButton(
            label: '취소',
            onPressed: () => Navigator.of(ctx).pop(false),
            primary: false,
            textColor: AppColors.textSub,
          ),
          AppDialogButton(
            label: '삭제',
            onPressed: () => Navigator.of(ctx).pop(true),
            isDestructive: true,
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await MeasurementRepository.instance.delete(item.id);
    } catch (_) {
      _showMockFailure('측정 기록 삭제');
      return;
    }
    if (mounted) {
      setState(() {
        _items.removeWhere((i) => i.id == item.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('측정 결과가 삭제되었습니다.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// 작성: 2026-07-03 15:21:58 · 박건준
  /// 함수: _formatDate
  /// 목적: 날짜를 "YYYY-MM-DD" 형식 문자열로 바꾼다.
  /// 인자: dt — 변환할 날짜/시각
  /// 반환: "YYYY-MM-DD" 형식 문자열
  String _formatDate(DateTime dt) {
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// 작성: 2026-07-03 15:21:58 · 박건준
  /// 함수: _getSummaryText
  /// 목적: 목록 한 줄에 보여줄 요약 문구를 만든다. 기준 초과 항목이
  ///       없으면 "전 지표 정상", 있으면 초과한 항목만 나열한다.
  /// 인자: item — 요약할 측정 결과
  /// 반환: 요약 문구
  String _getSummaryText(MeasurementResult item) {
    final isExceeded = item.xExceeded || item.yExceeded || item.zExceeded || item.noiseExceeded; // 하나라도 초과했는지
    if (!isExceeded) return '전 지표 정상';
    final List<String> reasons = []; // 초과한 항목 문구를 모을 목록
    if (item.xExceeded) reasons.add('X ${item.xPtp.toStringAsFixed(1)}mg');
    if (item.yExceeded) reasons.add('Y ${item.yPtp.toStringAsFixed(1)}mg');
    if (item.zExceeded) reasons.add('Z ${item.zPtp.toStringAsFixed(1)}mg');
    if (item.noiseExceeded) reasons.add('소음 ${item.noiseMax.toStringAsFixed(1)}dBA');
    return '${reasons.join(', ')} 초과';
  }



  /// 작성: 2026-07-03 15:21:58 · 박건준
  /// 함수: _buildEmptyState
  /// 목적: 저장된 결과가 없거나 조회에 실패했을 때 보여줄 빈 상태
  ///       화면을 만든다.
  /// 반환: 빈 상태 안내 위젯
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDims.screenPad),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inbox_outlined,
              size: 64,
              color: AppColors.textSub,
            ),
            const SizedBox(height: AppDims.gap),
            Text(
              _loadFailed ? '저장된 결과를 불러오지 못했습니다' : '저장된 결과가 없습니다',
              style: AppText.body.copyWith(color: AppColors.textSub),
            ),
            if (_loadFailed) ...[
              const SizedBox(height: 4),
              Text(
                '저장·출력 기능은 아직 구현되지 않았습니다.\n(요청: 측정 기록 목록 조회)',
                textAlign: TextAlign.center,
                style: AppText.caption.copyWith(color: AppColors.textSub),
              ),
            ],
            const SizedBox(height: AppDims.gap2),
            SizedBox(
              width: 220,
              height: AppDims.buttonH,
              child: OutlinedButton(
                onPressed: () => context.go('/home'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.navy, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDims.radius),
                  ),
                ),
                child: Text(
                  '측정하러 가기',
                  style: AppText.bodyBold.copyWith(color: AppColors.navy),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 작성: 2026-07-03 15:21:58 · 박건준
  /// 함수: _buildListItem
  /// 목적: 목록 한 행(상태 표시 + 요약 + 이메일/삭제 버튼)을 만든다.
  /// 인자: item — 표시할 측정 결과
  /// 반환: 목록 한 행 위젯
  Widget _buildListItem(MeasurementResult item) {
    final bool isExceeded = item.xExceeded || item.yExceeded || item.zExceeded || item.noiseExceeded; // 하나라도 초과했는지
    final Color statusColor = isExceeded ? AppColors.red : AppColors.green; // 상태 점·글자 색
    final String statusLabel = isExceeded ? '초과' : '정상'; // 상태 문구

    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: () async {
          await context.push('/result/${item.id}');
          _loadItems();
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDims.gap2,
            vertical: AppDims.gap2,
          ),
          child: Row(
            children: [
              // 1. 왼쪽 상태 점 16dp + 텍스트 3중 상태 표시
              SizedBox(
                width: 44,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusLabel,
                      style: AppText.caption.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDims.gap),

              // 2. 중앙 제번+현장명 및 일시+요약
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${item.jobNo} · ${item.siteName}',
                      style: AppText.bodyBold,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatDate(item.dateTime)} · ${_getSummaryText(item)}',
                      style: AppText.caption.copyWith(color: AppColors.textSub),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                  ],
                ),
              ),
              const SizedBox(width: AppDims.gap),

              // 3. 오른쪽 공유 버튼 (56dp) + 삭제 버튼 (56dp) + chevron
              AppDialogIconButton(
                icon: Icons.mail_outline,
                label: '이메일 발송 시트 열기',
                size: 26,
                color: AppColors.navy,
                onPressed: () => _showSendEmailSheet(item.id),
              ),
              AppDialogIconButton(
                icon: Icons.delete_outline,
                label: '측정 결과 삭제',
                size: 26,
                color: AppColors.red,
                onPressed: () => _confirmDelete(item),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textSub,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 작성: 2026-07-03 15:21:58 · 박건준
  /// 함수: build
  /// 목적: 저장된 결과 목록 화면을 그린다. 목록이 비어 있으면 빈
  ///       상태 안내를, 있으면 항목 리스트를 보여준다.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('저장된 결과'),
      ),
      body: SafeArea(
        child: _items.isEmpty
            ? _buildEmptyState()
            : ListView.separated(
                itemCount: _items.length,
                separatorBuilder: (_, _) => const Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.border,
                ),
                itemBuilder: (context, index) => _buildListItem(_items[index]),
              ),
      ),
    );
  }
}
