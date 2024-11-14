import 'dart:developer' as dev;
import 'dart:io';

import 'perf_baselines.dart';

/// Converts bytes to megabytes and returns a string with two decimal places.
String bytesToMB(int? bytes) {
  return ((bytes ?? 0) / (1024 * 1024)).toStringAsFixed(2);
}

/// Saves the given content as a markdown file in the specified directory.
///
/// If the directory doesn't exist, it will be created.
Future<void> saveMarkdownFile(
    String content, String fileName, String directory) async {
  final dir = Directory(directory);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  final file = File('$directory/$fileName');
  await file.writeAsString(content);
  dev.log('Markdown file saved as $directory/$fileName');
}

/// Converts the performance data map into a readable markdown text.
///
/// This method processes the collected performance data and generates a detailed
/// markdown report. It includes sections for device details, frame rate information,
/// improvement suggestions, and detailed performance metrics for both UI and Raster threads.
String convertMapToReadableText(
  Map<String, dynamic> data, {
  required PerformanceBaselines defaultBaselines,
  bool isBase = false,
}) {
  final performance = data['performance'] as Map<String, dynamic>? ?? {};
  var cpuUsage = <String, dynamic>{};
  var memoryUsageInitial = <String, dynamic>{};
  var memoryUsageFinal = <String, dynamic>{};
  var deviceDetails = <String, dynamic>{};

  if (isBase) {
    cpuUsage = data['cpu_usage'] as Map<String, dynamic>? ?? {};

    final memoryUse = data['memory_usage'] as Map<String, dynamic>? ?? {};
    final initialMemoryUse =
        memoryUse['initial'] as Map<String, dynamic>? ?? {};
    final finalMemoryUse = memoryUse['final'] as Map<String, dynamic>? ?? {};

    memoryUsageInitial =
        initialMemoryUse['memory_usage'] as Map<String, dynamic>? ?? {};
    memoryUsageFinal =
        finalMemoryUse['memory_usage'] as Map<String, dynamic>? ?? {};

    deviceDetails = data['device_details'] as Map<String, dynamic>? ?? {};
  }
  final frameRateInfo = data['frame_rate_info'] as Map<String, dynamic>? ?? {};

  // Generate frame rate information string
  final String frameRateString = frameRateInfo.isNotEmpty
      ? frameRateInfo.entries
          .where((entry) => entry.value as num > 0)
          .map((entry) => '- ${entry.key}: ${entry.value}%')
          .join('\n')
      : 'No frame rate data';

  // Helper function to return a check or cross mark based on a condition
  String checkOrCross({
    required bool condition,
  }) {
    return condition ? '✅' : '❌';
  }

  /// Generates improvement suggestions based on the performance metrics.
  ///
  /// This method analyzes various performance metrics and provides specific
  /// suggestions for improvement when certain thresholds are exceeded.
  String generateImprovementSuggestions(
    Map<String, dynamic> performance,
    int totalFrames,
    int totalRasterizerFrames, {
    Map<String, dynamic> cpuUsage = const {},
  }) {
    final StringBuffer suggestions = StringBuffer();
    final cpuFinalUse =
        cpuUsage.isNotEmpty ? cpuUsage['final'] as Map<String, dynamic>? : null;
    final cpuInitialUse = cpuUsage.isNotEmpty
        ? cpuUsage['initial'] as Map<String, dynamic>?
        : null;

    // 90th Percentile Frame Build Time (UI)
    if (performance['90th_percentile_frame_build_time_millis'] as num >
        defaultBaselines.percentile90thBuildTime) {
      suggestions.writeln(
        "- **UI Build Time:** The 90th percentile frame build time is higher than expected (${performance['90th_percentile_frame_build_time_millis']} ms). Enable the performance overlay and identify heavy operations or widget rebuilds that may be slowing down your UI.",
      );
    }

    // 95th Percentile Frame Build Time (UI)
    if (performance['95th_percentile_frame_build_time_millis'] as num >
        defaultBaselines.percentile95thBuildTime) {
      suggestions.writeln(
        "- **UI Build Time:** The 95th percentile frame build time is high (${performance['95th_percentile_frame_build_time_millis']} ms). Consider refactoring or optimizing your widgets to reduce the load on the UI thread.",
      );
    }

    // 99th Percentile Frame Build Time (UI)
    if (performance['99th_percentile_frame_build_time_millis'] as num >
        defaultBaselines.percentile99thBuildTime) {
      suggestions.writeln(
        "- **UI Build Time:** The 99th percentile frame build time is excessively high (${performance['99th_percentile_frame_build_time_millis']} ms). Investigate for any expensive operations that may need to be offloaded to a background thread.",
      );
    }

    // Skipped UI Frames
    final int maxSkippedFramesUI =
        (defaultBaselines.missedFrameBuildBudgetPercentage * totalFrames)
            .round();
    if (performance['missed_frame_build_budget_count'] as num >
            defaultBaselines.missedFrameBuildBudgetCount ||
        performance['missed_frame_build_budget_count'] as num >
            maxSkippedFramesUI) {
      suggestions.writeln(
        "- **Skipped UI Frames:** Your app skipped ${performance['missed_frame_build_budget_count']} UI frames. Investigate the performance overlay and ensure that your UI operations are efficient.",
      );
    }

    // 90th Percentile Frame Raster Time
    if (performance['90th_percentile_frame_raster_time_millis'] as num >
        defaultBaselines.percentile90thBuildTime) {
      suggestions.writeln(
        "- **Raster Time:** The 90th percentile frame raster time is higher than expected (${performance['90th_percentile_frame_raster_time_millis']} ms). Consider simplifying your visuals or reducing the number of layers.",
      );
    }

    // 95th Percentile Frame Raster Time
    if (performance['95th_percentile_frame_raster_time_millis'] as num >
        defaultBaselines.percentile95thBuildTime) {
      suggestions.writeln(
        "- **Raster Time:** The 95th percentile frame raster time is high (${performance['95th_percentile_frame_raster_time_millis']} ms). Optimize your rendering logic or avoid using complex drawing operations.",
      );
    }

    // 99th Percentile Frame Raster Time
    if (performance['99th_percentile_frame_raster_time_millis'] as num >
        defaultBaselines.percentile99thBuildTime) {
      suggestions.writeln(
        "- **Raster Time:** The 99th percentile frame raster time is excessively high (${performance['99th_percentile_frame_raster_time_millis']} ms). Check for expensive graphics operations or consider reducing visual complexity.",
      );
    }

    // Skipped Raster Frames
    final int maxSkippedFramesRaster =
        (defaultBaselines.missedFrameRasterizerBudgetPercentage * totalFrames)
            .round();
    if (performance['missed_frame_rasterizer_budget_count'] as num >
            defaultBaselines.missedFrameRasterizerBudgetCount ||
        performance['missed_frame_rasterizer_budget_count'] as num >
            maxSkippedFramesRaster) {
      suggestions.writeln(
        "- **Skipped Raster Frames:** Your app skipped ${performance['missed_frame_rasterizer_budget_count']} raster frames. This indicates heavy graphics operations that may need to be optimized.",
      );
    }

    // Average Frame Build Time (UI)
    if (performance['average_frame_build_time_millis'] as num >
        defaultBaselines.averageBuildTime) {
      suggestions.writeln(
        "- **Average UI Build Time:** The average frame build time is higher than expected (${performance['average_frame_build_time_millis']} ms). Consider optimizing your widget tree and avoiding unnecessary rebuilds.",
      );
    }

    // Slowest Frame Build Time (UI)
    if (performance['worst_frame_build_time_millis'] as num >
        defaultBaselines.worstBuildTime) {
      suggestions.writeln(
        "- **Slowest UI Frame Build Time:** The slowest frame build time was particularly high (${performance['worst_frame_build_time_millis']} ms). Investigate the cause using the performance overlay and try to identify heavy operations.",
      );
    }

    // Average Frame Raster Time
    if (performance['average_frame_raster_time_millis'] as num >
        defaultBaselines.averageBuildTime) {
      suggestions.writeln(
        "- **Average Raster Time:** The average frame raster time is higher than expected (${performance['average_frame_raster_time_millis']} ms). Consider simplifying your visual design or reducing the number of layers.",
      );
    }

    // Slowest Frame Raster Time
    if (performance['worst_frame_raster_time_millis'] as num >
        defaultBaselines.worstBuildTime) {
      suggestions.writeln(
        "- **Slowest Raster Frame Time:** The slowest raster frame time was particularly high (${performance['worst_frame_raster_time_millis']} ms). Optimize your graphics operations or consider offloading heavy work to a background thread.",
      );
    }

    // CPU Usage Increase
    if (cpuUsage.isNotEmpty) {
      final int cpuUsageIncrease =
          (cpuFinalUse?['total_cpu_samples'] as int? ?? 0) -
              (cpuInitialUse?['total_cpu_samples'] as int? ?? 0);
      if (cpuUsageIncrease > defaultBaselines.cpuUsageIncrease) {
        suggestions.writeln(
          '- **High CPU Usage:** The CPU usage increased significantly ($cpuUsageIncrease cycles). Consider using the CPU profiler in DevTools to identify potential bottlenecks and optimize your code.',
        );
      }
    }

    if (suggestions.isEmpty) {
      suggestions.writeln(
          'Your app is performing well with no significant issues detected.');
    }

    return suggestions.toString();
  }

  final cpuFinalUse =
      cpuUsage.isNotEmpty ? cpuUsage['final'] as Map<String, dynamic>? : null;
  final cpuInitialUse =
      cpuUsage.isNotEmpty ? cpuUsage['initial'] as Map<String, dynamic>? : null;

  // Generate the final markdown report
  var report = '''
# Performance Report

## Device Details:
- Operating System: ${deviceDetails['operating_system']}

## Frame Rate Information:
$frameRateString

## Suggestions:
${generateImprovementSuggestions(
    performance,
    performance['total_frames'] as int? ?? 0,
    performance['total_rasterizer_frames'] as int? ?? 0,
    cpuUsage: cpuUsage,
  )}

### UI Thread Performance

| Metric                                      | Baseline               | Actual (UI)           | Status |
|---------------------------------------------|------------------------|-----------------------|--------|
| 90th Percentile Frame Build Time (ms)       | <= ${defaultBaselines.percentile90thBuildTime}    | ${performance['90th_percentile_frame_build_time_millis']} | ${checkOrCross(condition: performance['90th_percentile_frame_build_time_millis'] as num <= defaultBaselines.percentile90thBuildTime)}  |
| 95th Percentile Frame Build Time (ms)       | <= ${defaultBaselines.percentile95thBuildTime}    | ${performance['95th_percentile_frame_build_time_millis']} | ${checkOrCross(condition: performance['95th_percentile_frame_build_time_millis'] as num <= defaultBaselines.percentile95thBuildTime)}  |
| 99th Percentile Frame Build Time (ms)       | <= ${defaultBaselines.percentile99thBuildTime}    | ${performance['99th_percentile_frame_build_time_millis']} | ${checkOrCross(condition: performance['99th_percentile_frame_build_time_millis'] as num <= defaultBaselines.percentile99thBuildTime)}  |
| Skipped Frames (Count)                      | <= ${defaultBaselines.missedFrameBuildBudgetCount} frames OR <= ${defaultBaselines.missedFrameBuildBudgetPercentage}% of ${performance['total_frames']} = ${defaultBaselines.missedFrameBuildBudgetPercentage * (performance['total_frames'] as num) / 100} | ${performance['missed_frame_build_budget_count']} | ${checkOrCross(condition: performance['missed_frame_build_budget_count'] as num <= defaultBaselines.missedFrameBuildBudgetCount || performance['missed_frame_build_budget_count'] as num <= (defaultBaselines.missedFrameBuildBudgetPercentage * (performance['total_frames'] as num) / 100))}  |
| Average Frame Build Time (ms)               | <= ${defaultBaselines.averageBuildTime}           | ${performance['average_frame_build_time_millis']} | ${checkOrCross(condition: performance['average_frame_build_time_millis'] as num <= defaultBaselines.averageBuildTime)}  |
| Slowest Frame Build Time (ms)               | <= ${defaultBaselines.worstBuildTime}             | ${performance['worst_frame_build_time_millis']} | ${checkOrCross(condition: performance['worst_frame_build_time_millis'] as num <= defaultBaselines.worstBuildTime)}  |

### Raster Thread Performance

| Metric                                      | Baseline               | Actual (Raster)       | Status |
|---------------------------------------------|------------------------|-----------------------|--------|
| 90th Percentile Frame Raster Time (ms)      | <= ${defaultBaselines.percentile90thBuildTime}    | ${performance['90th_percentile_frame_raster_time_millis']} | ${checkOrCross(condition: performance['90th_percentile_frame_raster_time_millis'] as num <= defaultBaselines.percentile90thBuildTime)}  |
| 95th Percentile Frame Raster Time (ms)      | <= ${defaultBaselines.percentile95thBuildTime}    | ${performance['95th_percentile_frame_raster_time_millis']} | ${checkOrCross(condition: performance['95th_percentile_frame_raster_time_millis'] as num <= defaultBaselines.percentile95thBuildTime)}  |
| 99th Percentile Frame Raster Time (ms)      | <= ${defaultBaselines.percentile99thBuildTime}    | ${performance['99th_percentile_frame_raster_time_millis']} | ${checkOrCross(condition: performance['99th_percentile_frame_raster_time_millis'] as num <= defaultBaselines.percentile99thBuildTime)}  |
| Skipped Frames (Count)                      | <= ${defaultBaselines.missedFrameRasterizerBudgetCount} frames OR <= ${defaultBaselines.missedFrameRasterizerBudgetPercentage}% of ${performance['total_rasterizer_frames']} = ${defaultBaselines.missedFrameRasterizerBudgetPercentage * (performance['total_rasterizer_frames'] as num) / 100} | ${performance['missed_frame_rasterizer_budget_count']} | ${checkOrCross(condition: performance['missed_frame_rasterizer_budget_count'] as num <= defaultBaselines.missedFrameRasterizerBudgetCount || performance['missed_frame_rasterizer_budget_count'] as num <= (defaultBaselines.missedFrameRasterizerBudgetPercentage * (performance['total_rasterizer_frames'] as num) / 100))}  |
| Average Frame Raster Time (ms)              | <= ${defaultBaselines.averageBuildTime}           | ${performance['average_frame_raster_time_millis']} | ${checkOrCross(condition: performance['average_frame_raster_time_millis'] as num <= defaultBaselines.averageBuildTime)}  |
| Slowest Frame Raster Time (ms)              | <= ${defaultBaselines.worstBuildTime}             | ${performance['worst_frame_raster_time_millis']} | ${checkOrCross(condition: performance['worst_frame_raster_time_millis'] as num <= defaultBaselines.worstBuildTime)}  |
''';

  if (cpuUsage.isNotEmpty) {
    report += '''
### Device Performance

| Metric                                      | Baseline               | Actual                | Status |
|---------------------------------------------|------------------------|-----------------------|--------|
| Initial Memory Usage (MB)                   | <= ${defaultBaselines.memoryUsageMB}              | ${bytesToMB(memoryUsageInitial['heapUsage'] as int?)}     | ${checkOrCross(condition: double.parse(bytesToMB(memoryUsageInitial['heapUsage'] as int?)) <= defaultBaselines.memoryUsageMB)}  |
| Final Memory Usage (MB)                     | <= ${defaultBaselines.memoryUsageMB}              | ${bytesToMB(memoryUsageFinal['heapUsage'] as int?)}       | ${checkOrCross(condition: double.parse(bytesToMB(memoryUsageFinal['heapUsage'] as int?)) <= defaultBaselines.memoryUsageMB)}  |
| CPU Usage Increase (Cycles)                 | <= ${defaultBaselines.cpuUsageIncrease} cycles                     | ${(cpuFinalUse?['total_cpu_samples'] as int) - (cpuInitialUse?['total_cpu_samples'] as int)} | ${checkOrCross(condition: ((cpuFinalUse?['total_cpu_samples'] as int) - (cpuInitialUse?['total_cpu_samples'] as int)) <= defaultBaselines.cpuUsageIncrease)}  |
''';
  }

  return report;
}
