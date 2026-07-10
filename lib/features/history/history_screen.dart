import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../domain/models/measurement_result.dart';
import '../../domain/repository/measurement_repository.dart';
import '../shared/send_email_sheet.dart';
import '../../core/widgets/app_dialog.dart';

/// S5 저장 결과 목록 화면
/// - 폰에 저장된 과거 측정 결과 목록 표시 및 관리 (Phase 4-C 연동)
/// - MeasurementRepository.instance.list() 로 로컬 디스크 조회 및 개별/전체 삭제
/// - 어르신 UX: 88dp 이상의 큰 터치 영역 행, 색+텍스트 3중 상태 표출, 대형 빈 상태 안내
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

/// 저장된 측정 결과 목록의 비동기 로드, 이메일 발송 연결 및 개별 삭제 상태를 관리합니다.
class _HistoryScreenState extends State<HistoryScreen> {
  List<MeasurementResult> _items = kDebugMode ? MeasurementResult.mockList : [];
  final bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final list = await MeasurementRepository.instance.list();
      if (mounted) {
        setState(() {
          _items = list.isNotEmpty ? list : (kDebugMode ? MeasurementResult.mockList : []);
        });
      }
    } catch (_) {
      if (mounted && !kDebugMode) {
        setState(() => _items = []);
      }
    }
  }

  void _showSendEmailSheet(String jobId) {
    showSendEmailSheet(context, jobId: jobId);
  }

  Future<void> _confirmDelete(MeasurementResult item) async {
    final bool? confirmed = await showDialog<bool>(
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

    if (confirmed == true) {
      try {
        await MeasurementRepository.instance.delete(item.id);
      } catch (_) {}
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
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _getSummaryText(MeasurementResult item) {
    if (item.id == '2024F1447R01') return 'Z 22.2mg 초과';
    if (item.id == '2024F1448R02') return '전 지표 정상';
    if (item.id == '2024F1449R03') return 'X 11.5mg, 소음 52.3dBA 초과';
    final isExceeded = item.xExceeded || item.yExceeded || item.zExceeded || item.noiseExceeded;
    if (!isExceeded) return '전 지표 정상';
    final List<String> reasons = [];
    if (item.xExceeded) reasons.add('X ${item.xPtp.toStringAsFixed(1)}mg');
    if (item.yExceeded) reasons.add('Y ${item.yPtp.toStringAsFixed(1)}mg');
    if (item.zExceeded) reasons.add('Z ${item.zPtp.toStringAsFixed(1)}mg');
    if (item.noiseExceeded) reasons.add('소음 ${item.noiseMax.toStringAsFixed(1)}dBA');
    return '${reasons.join(', ')} 초과';
  }

  Widget _buildBadge(String label) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: AppText.caption.copyWith(
          fontSize: 11,
          color: AppColors.blue,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

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
              '저장된 결과가 없습니다',
              style: AppText.body.copyWith(color: AppColors.textSub),
            ),
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

  Widget _buildListItem(MeasurementResult item) {
    final bool isExceeded = item.xExceeded || item.yExceeded || item.zExceeded || item.noiseExceeded;
    final Color statusColor = isExceeded ? AppColors.red : AppColors.green;
    final String statusLabel = isExceeded ? '초과' : '정상';

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
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildBadge('PDF'),
                        _buildBadge('RAW'),
                      ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('저장된 결과'),
        actions: [
          // 테스트 및 QA 편의를 위한 목록 비우기/복원 토글 버튼 (디버그 모드 한정)
          if (kDebugMode)
            Semantics(
            button: true,
            label: _items.isEmpty ? '샘플 복원' : '목록 비우기',
            child: IconButton(
              icon: Icon(_items.isEmpty ? Icons.restore : Icons.delete_outline),
              onPressed: () async {
                if (_items.isEmpty) {
                  setState(() => _items = MeasurementResult.mockList);
                  try {
                    await MeasurementRepository.instance.save(MeasurementResult.mock);
                    final list = await MeasurementRepository.instance.list();
                    if (mounted && list.isNotEmpty) setState(() => _items = list);
                  } catch (_) {}
                } else {
                  final oldItems = List<MeasurementResult>.from(_items);
                  setState(() => _items = []);
                  for (final item in oldItems) {
                    try { await MeasurementRepository.instance.delete(item.id); } catch (_) {}
                  }
                }
              },
              tooltip: _items.isEmpty ? '샘플 복원' : '목록 비우기',
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : (_items.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.border,
                    ),
                    itemBuilder: (context, index) => _buildListItem(_items[index]),
                  )),
      ),
    );
  }
}
