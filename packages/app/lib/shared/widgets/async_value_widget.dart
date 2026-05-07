import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:design_system/design_system.dart';
import '../utils/error_utils.dart';

class AsyncValueWidget<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T) data;
  final Widget Function()? loading;
  final VoidCallback onRetry;
  final bool showLoading;

  const AsyncValueWidget({
    super.key,
    required this.value,
    required this.data,
    this.loading,
    required this.onRetry,
    this.showLoading = true,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () => showLoading 
          ? (loading?.call() ?? const Center(child: CircularProgressIndicator()))
          : const SizedBox.shrink(),
      error: (e, _) {
        final message = getFriendlyErrorMessage(e);
        final isNetwork = message.contains('internet connection');
        return EmptyState(
          icon: isNetwork ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
          title: isNetwork ? 'No Internet Connection' : 'Something went wrong',
          subtitle: message,
          buttonLabel: 'Retry',
          onButtonPressed: onRetry,
        );
      },
    );
  }
}
