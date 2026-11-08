import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/order_status.dart';

class OrderProgress extends StatelessWidget {
  const OrderProgress({super.key, required this.status});

  final String status;

  static const _labels = [
    'Оформлен',
    'Оплачен',
    'Подтверждён',
    'В пути',
    'Доставлен',
  ];

  @override
  Widget build(BuildContext context) {
    if (status == 'cancelled') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: AppRadii.cardBorder,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cancel_outlined, size: 18, color: AppColors.navyMuted),
            SizedBox(width: 8),
            Text(
              'Заказ отменён',
              style: TextStyle(
                color: AppColors.navyMuted,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final current = OrderStatus.step(status);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardBorder,
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (_, constraints) {
          final cellW = constraints.maxWidth / _labels.length;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 28,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Connector lines behind the dots
                    for (int i = 0; i < _labels.length - 1; i++)
                      Positioned(
                        left: cellW * i + cellW / 2,
                        right: constraints.maxWidth -
                            (cellW * (i + 1) + cellW / 2),
                        top: 13,
                        height: 2,
                        child: Container(
                          color: current > i + 1
                              ? AppColors.purple
                              : AppColors.border,
                        ),
                      ),
                    // Step dots
                    Row(
                      children: List.generate(_labels.length, (i) {
                        final step = i + 1;
                        return SizedBox(
                          width: cellW,
                          height: 28,
                          child: Center(
                            child: _StepDot(
                              done: current >= step,
                              active: current == step,
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: List.generate(_labels.length, (i) {
                  final done = current >= i + 1;
                  return SizedBox(
                    width: cellW,
                    child: Text(
                      _labels[i],
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            done ? FontWeight.w600 : FontWeight.w400,
                        color: done ? AppColors.navy : AppColors.navyMuted,
                        height: 1.2,
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.done, required this.active});

  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? AppColors.purple : AppColors.surface,
        border: Border.all(
          color: (done || active) ? AppColors.purple : AppColors.border,
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: done
          ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
          : active
              ? Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.purple,
                  ),
                )
              : null,
    );
  }
}
