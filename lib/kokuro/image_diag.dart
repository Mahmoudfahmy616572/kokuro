import 'package:flutter/material.dart';

// TEMPORARY DIAGNOSTIC — remove after root-cause is found.
// Records poster image load failures and shows them as an on-screen banner so
// the failing host / error can be captured without DevTools.
final List<String> imageDiagLog = [];
final ValueNotifier<int> imageDiagTick = ValueNotifier<int>(0);

void recordImageFailure(String url, Object? error) {
  final host = Uri.tryParse(url)?.host ?? url;
  var reason = error?.toString() ?? 'unknown';
  reason = reason.replaceAll('\n', ' ');
  if (reason.length > 160) reason = reason.substring(0, 160);
  imageDiagLog.add('$host :: $reason');
  while (imageDiagLog.length > 6) {
    imageDiagLog.removeAt(0);
  }
  imageDiagTick.value++;
}

class ImageDiagOverlay extends StatelessWidget {
  const ImageDiagOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: imageDiagTick,
      builder: (_, _, _) {
        if (imageDiagLog.isEmpty) return const SizedBox.shrink();
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Material(
            color: Colors.red.shade900.withValues(alpha: 0.92),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'IMG FAILURES (${imageDiagLog.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ...imageDiagLog.map(
                      (l) => Text(
                        l,
                        style: const TextStyle(color: Colors.white, fontSize: 9),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
