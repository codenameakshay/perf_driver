import 'dart:io';
import 'dart:developer' as dev;

import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';
import 'package:perf_driver/src/perf_baselines.dart';

/// Runs performance tests and generates a detailed performance report.
///
/// This method uses the integration_test driver to collect performance data
/// including CPU usage, memory usage, widget build times, and frame rendering
/// metrics. It processes the collected data, generates a markdown report,
/// and saves it to a file. The report includes performance metrics,
/// comparisons against baselines, and improvement suggestions.
///
/// [customBaselines] allows specifying custom performance baselines.
/// If not provided, default baselines will be used.
///
/// Create a sample driver file in your project, and include this method in
/// main method to generate performance reports for your integration tests.
///
/// Example -
/// ```dart
/// void main() {
///   perfDriver();
///   // Or with custom baselines:
///   // perfDriver(customBaselines: PerformanceBaselines(...));
/// }
/// ```
Future<void> perfDriver({PerformanceBaselines? customBaselines}) {
  final baselines = customBaselines ??
      const PerformanceBaselines(
        percentile90thBuildTime: 6.0,
        percentile95thBuildTime: 8.0,
        percentile99thBuildTime: 12.0,
        missedFrameBuildBudgetCount: 2,
        missedFrameBuildBudgetPercentage: 2.5,
        missedFrameRasterizerBudgetCount: 2,
        missedFrameRasterizerBudgetPercentage: 2.5,
        averageBuildTime: 6.0,
        worstBuildTime: 30.0,
        memoryUsageMB: 200.0,
        cpuUsageIncrease: 500000,
      );

  return integrationDriver(
    responseDataCallback: (data) async {
      if (data != null) {
        final cpuUsageData = data['cpu_usage'] as Map<String, dynamic>;
        final memoryUsageData = data['memory_usage'] as Map<String, dynamic>;
        final widgetBuildData = data['widget_build'] as Map<String, dynamic>;
        final deviceDetails = data['device_details'] as Map<String, dynamic>;

        final timeline = driver.Timeline.fromJson(
          widgetBuildData,
        );
        final summary = driver.TimelineSummary.summarize(timeline);

        // Collect performance metrics from the timeline summary
        final performanceData = {
          '90th_percentile_frame_build_time_millis': summary.computePercentileFrameBuildTimeMillis(90),
          '95th_percentile_frame_build_time_millis': summary.computePercentileFrameBuildTimeMillis(95),
          '99th_percentile_frame_build_time_millis': summary.computePercentileFrameBuildTimeMillis(99),
          'missed_frame_build_budget_count': summary.computeMissedFrameBuildBudgetCount(),
          'average_frame_build_time_millis': summary.computeAverageFrameBuildTimeMillis(),
          'worst_frame_build_time_millis': summary.computeWorstFrameBuildTimeMillis(),
          'total_frames': summary.countFrames(),
          '90th_percentile_frame_raster_time_millis': summary.computePercentileFrameRasterizerTimeMillis(90),
          '95th_percentile_frame_raster_time_millis': summary.computePercentileFrameRasterizerTimeMillis(95),
          '99th_percentile_frame_raster_time_millis': summary.computePercentileFrameRasterizerTimeMillis(99),
          'missed_frame_rasterizer_budget_count': summary.computeMissedFrameRasterizerBudgetCount(),
          'average_frame_raster_time_millis': summary.computeAverageFrameRasterizerTimeMillis(),
          'worst_frame_raster_time_millis': summary.computeWorstFrameRasterizerTimeMillis(),
          'total_rasterizer_frames': summary.countRasterizations(),
        };

        // Extract frame rate information from the summary
        final frameRateInfo = {
          '30Hz': summary.summaryJson['30hz_frame_percentage'],
          '60Hz': summary.summaryJson['60hz_frame_percentage'],
          '80Hz': summary.summaryJson['80hz_frame_percentage'],
          '90Hz': summary.summaryJson['90hz_frame_percentage'],
          '120Hz': summary.summaryJson['120hz_frame_percentage'],
        };

        // Compile all testing data
        final testingData = {
          'device_details': deviceDetails,
          'frame_rate_info': frameRateInfo,
          'performance': performanceData,
          'cpu_usage': cpuUsageData,
          'memory_usage': memoryUsageData,
        };

        // Generate and save the performance report
        final report = convertMapToReadableText(testingData, defaultBaselines: baselines);
        saveMarkdownFile(report, '${DateTime.now().toIso8601String()}.md',
            'performance_report/${deviceDetails['operating_system']}');

        // Write the timeline to a file for further analysis if needed
        await summary.writeTimelineToFile(
          'widget_build',
          pretty: true,
          includeSummary: true,
        );
      } else {
        dev.log('No data received');
      }
    },
  );
}

/// Converts bytes to megabytes and returns a string with two decimal places.
String bytesToMB(int? bytes) {
  return ((bytes ?? 0) / (1024 * 1024)).toStringAsFixed(2);
}

/// Saves the given content as a markdown file in the specified directory.
///
/// If the directory doesn't exist, it will be created.
void saveMarkdownFile(String content, String fileName, String directory) async {
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
String convertMapToReadableText(Map<String, dynamic> data, {required PerformanceBaselines defaultBaselines}) {
  final performance = data['performance'];
  final cpuUsage = data['cpu_usage'];
  final memoryUsageInitial = data['memory_usage']['initial']['memory_usage'];
  final memoryUsageFinal = data['memory_usage']['final']['memory_usage'];
  final deviceDetails = data['device_details'];
  final frameRateInfo = data['frame_rate_info'] as Map<String, dynamic>?;

  // Generate frame rate information string
  String frameRateString = frameRateInfo != null
      ? frameRateInfo.entries
          .where((entry) => entry.value > 0)
          .map((entry) => '- ${entry.key}: ${entry.value}%')
          .join('\n')
      : 'No frame rate data';

  // Helper function to return a check or cross mark based on a condition
  String checkOrCross(bool condition) => condition ? '✅' : '❌';

  /// Generates improvement suggestions based on the performance metrics.
  ///
  /// This method analyzes various performance metrics and provides specific
  /// suggestions for improvement when certain thresholds are exceeded.
  String generateImprovementSuggestions(
      Map<String, dynamic> performance, Map<String, dynamic> cpuUsage, int totalFrames, int totalRasterizerFrames) {
    StringBuffer suggestions = StringBuffer();

    // 90th Percentile Frame Build Time (UI)
    if (performance['90th_percentile_frame_build_time_millis'] > defaultBaselines.percentile90thBuildTime) {
      suggestions.writeln(
          "- **UI Build Time:** The 90th percentile frame build time is higher than expected (${performance['90th_percentile_frame_build_time_millis']} ms). Enable the performance overlay and identify heavy operations or widget rebuilds that may be slowing down your UI.");
    }

    // 95th Percentile Frame Build Time (UI)
    if (performance['95th_percentile_frame_build_time_millis'] > defaultBaselines.percentile95thBuildTime) {
      suggestions.writeln(
          "- **UI Build Time:** The 95th percentile frame build time is high (${performance['95th_percentile_frame_build_time_millis']} ms). Consider refactoring or optimizing your widgets to reduce the load on the UI thread.");
    }

    // 99th Percentile Frame Build Time (UI)
    if (performance['99th_percentile_frame_build_time_millis'] > defaultBaselines.percentile99thBuildTime) {
      suggestions.writeln(
          "- **UI Build Time:** The 99th percentile frame build time is excessively high (${performance['99th_percentile_frame_build_time_millis']} ms). Investigate for any expensive operations that may need to be offloaded to a background thread.");
    }

    // Skipped UI Frames
    int maxSkippedFramesUI = (defaultBaselines.missedFrameBuildBudgetPercentage * totalFrames).round();
    if (performance['missed_frame_build_budget_count'] > defaultBaselines.missedFrameBuildBudgetCount ||
        performance['missed_frame_build_budget_count'] > maxSkippedFramesUI) {
      suggestions.writeln(
          "- **Skipped UI Frames:** Your app skipped ${performance['missed_frame_build_budget_count']} UI frames. Investigate the performance overlay and ensure that your UI operations are efficient.");
    }

    // 90th Percentile Frame Raster Time
    if (performance['90th_percentile_frame_raster_time_millis'] > defaultBaselines.percentile90thBuildTime) {
      suggestions.writeln(
          "- **Raster Time:** The 90th percentile frame raster time is higher than expected (${performance['90th_percentile_frame_raster_time_millis']} ms). Consider simplifying your visuals or reducing the number of layers.");
    }

    // 95th Percentile Frame Raster Time
    if (performance['95th_percentile_frame_raster_time_millis'] > defaultBaselines.percentile95thBuildTime) {
      suggestions.writeln(
          "- **Raster Time:** The 95th percentile frame raster time is high (${performance['95th_percentile_frame_raster_time_millis']} ms). Optimize your rendering logic or avoid using complex drawing operations.");
    }

    // 99th Percentile Frame Raster Time
    if (performance['99th_percentile_frame_raster_time_millis'] > defaultBaselines.percentile99thBuildTime) {
      suggestions.writeln(
          "- **Raster Time:** The 99th percentile frame raster time is excessively high (${performance['99th_percentile_frame_raster_time_millis']} ms). Check for expensive graphics operations or consider reducing visual complexity.");
    }

    // Skipped Raster Frames
    int maxSkippedFramesRaster = (defaultBaselines.missedFrameRasterizerBudgetPercentage * totalFrames).round();
    if (performance['missed_frame_rasterizer_budget_count'] > defaultBaselines.missedFrameRasterizerBudgetCount ||
        performance['missed_frame_rasterizer_budget_count'] > maxSkippedFramesRaster) {
      suggestions.writeln(
          "- **Skipped Raster Frames:** Your app skipped ${performance['missed_frame_rasterizer_budget_count']} raster frames. This indicates heavy graphics operations that may need to be optimized.");
    }

    // Average Frame Build Time (UI)
    if (performance['average_frame_build_time_millis'] > defaultBaselines.averageBuildTime) {
      suggestions.writeln(
          "- **Average UI Build Time:** The average frame build time is higher than expected (${performance['average_frame_build_time_millis']} ms). Consider optimizing your widget tree and avoiding unnecessary rebuilds.");
    }

    // Slowest Frame Build Time (UI)
    if (performance['worst_frame_build_time_millis'] > defaultBaselines.worstBuildTime) {
      suggestions.writeln(
          "- **Slowest UI Frame Build Time:** The slowest frame build time was particularly high (${performance['worst_frame_build_time_millis']} ms). Investigate the cause using the performance overlay and try to identify heavy operations.");
    }

    // Average Frame Raster Time
    if (performance['average_frame_raster_time_millis'] > defaultBaselines.averageBuildTime) {
      suggestions.writeln(
          "- **Average Raster Time:** The average frame raster time is higher than expected (${performance['average_frame_raster_time_millis']} ms). Consider simplifying your visual design or reducing the number of layers.");
    }

    // Slowest Frame Raster Time
    if (performance['worst_frame_raster_time_millis'] > defaultBaselines.worstBuildTime) {
      suggestions.writeln(
          "- **Slowest Raster Frame Time:** The slowest raster frame time was particularly high (${performance['worst_frame_raster_time_millis']} ms). Optimize your graphics operations or consider offloading heavy work to a background thread.");
    }

    // CPU Usage Increase
    int cpuUsageIncrease = cpuUsage['final']['total_cpu_samples'] - cpuUsage['initial']['total_cpu_samples'];
    if (cpuUsageIncrease > defaultBaselines.cpuUsageIncrease) {
      suggestions.writeln(
          "- **High CPU Usage:** The CPU usage increased significantly ($cpuUsageIncrease cycles). Consider using the CPU profiler in DevTools to identify potential bottlenecks and optimize your code.");
    }

    if (suggestions.isEmpty) {
      suggestions.writeln("Your app is performing well with no significant issues detected.");
    }

    return suggestions.toString();
  }

  // Generate the final markdown report
  return '''
# Performance Report

## Device Details:
- Operating System: ${deviceDetails['operating_system']}

## Frame Rate Information:
$frameRateString

## Suggestions:
${generateImprovementSuggestions(performance, cpuUsage, performance['total_frames'], performance['total_rasterizer_frames'])}

### UI Thread Performance

| Metric                                      | Baseline               | Actual (UI)           | Status |
|---------------------------------------------|------------------------|-----------------------|--------|
| 90th Percentile Frame Build Time (ms)       | <= ${defaultBaselines.percentile90thBuildTime}    | ${performance['90th_percentile_frame_build_time_millis']} | ${checkOrCross(performance['90th_percentile_frame_build_time_millis'] <= defaultBaselines.percentile90thBuildTime)}  |
| 95th Percentile Frame Build Time (ms)       | <= ${defaultBaselines.percentile95thBuildTime}    | ${performance['95th_percentile_frame_build_time_millis']} | ${checkOrCross(performance['95th_percentile_frame_build_time_millis'] <= defaultBaselines.percentile95thBuildTime)}  |
| 99th Percentile Frame Build Time (ms)       | <= ${defaultBaselines.percentile99thBuildTime}    | ${performance['99th_percentile_frame_build_time_millis']} | ${checkOrCross(performance['99th_percentile_frame_build_time_millis'] <= defaultBaselines.percentile99thBuildTime)}  |
| Skipped Frames (Count)                      | <= ${defaultBaselines.missedFrameBuildBudgetCount} frames OR <= ${defaultBaselines.missedFrameBuildBudgetPercentage}% of ${performance['total_frames']} = ${(defaultBaselines.missedFrameBuildBudgetPercentage * performance['total_frames'] / 100)} | ${performance['missed_frame_build_budget_count']} | ${checkOrCross(performance['missed_frame_build_budget_count'] <= defaultBaselines.missedFrameBuildBudgetCount || performance['missed_frame_build_budget_count'] <= (defaultBaselines.missedFrameBuildBudgetPercentage * performance['total_frames'] / 100))}  |
| Average Frame Build Time (ms)               | <= ${defaultBaselines.averageBuildTime}           | ${performance['average_frame_build_time_millis']} | ${checkOrCross(performance['average_frame_build_time_millis'] <= defaultBaselines.averageBuildTime)}  |
| Slowest Frame Build Time (ms)               | <= ${defaultBaselines.worstBuildTime}             | ${performance['worst_frame_build_time_millis']} | ${checkOrCross(performance['worst_frame_build_time_millis'] <= defaultBaselines.worstBuildTime)}  |

### Raster Thread Performance

| Metric                                      | Baseline               | Actual (Raster)       | Status |
|---------------------------------------------|------------------------|-----------------------|--------|
| 90th Percentile Frame Raster Time (ms)      | <= ${defaultBaselines.percentile90thBuildTime}    | ${performance['90th_percentile_frame_raster_time_millis']} | ${checkOrCross(performance['90th_percentile_frame_raster_time_millis'] <= defaultBaselines.percentile90thBuildTime)}  |
| 95th Percentile Frame Raster Time (ms)      | <= ${defaultBaselines.percentile95thBuildTime}    | ${performance['95th_percentile_frame_raster_time_millis']} | ${checkOrCross(performance['95th_percentile_frame_raster_time_millis'] <= defaultBaselines.percentile95thBuildTime)}  |
| 99th Percentile Frame Raster Time (ms)      | <= ${defaultBaselines.percentile99thBuildTime}    | ${performance['99th_percentile_frame_raster_time_millis']} | ${checkOrCross(performance['99th_percentile_frame_raster_time_millis'] <= defaultBaselines.percentile99thBuildTime)}  |
| Skipped Frames (Count)                      | <= ${defaultBaselines.missedFrameRasterizerBudgetCount} frames OR <= ${defaultBaselines.missedFrameRasterizerBudgetPercentage}% of ${performance['total_rasterizer_frames']} = ${(defaultBaselines.missedFrameRasterizerBudgetPercentage * performance['total_rasterizer_frames'] / 100)} | ${performance['missed_frame_rasterizer_budget_count']} | ${checkOrCross(performance['missed_frame_rasterizer_budget_count'] <= defaultBaselines.missedFrameRasterizerBudgetCount || performance['missed_frame_rasterizer_budget_count'] <= (defaultBaselines.missedFrameRasterizerBudgetPercentage * performance['total_rasterizer_frames'] / 100))}  |
| Average Frame Raster Time (ms)              | <= ${defaultBaselines.averageBuildTime}           | ${performance['average_frame_raster_time_millis']} | ${checkOrCross(performance['average_frame_raster_time_millis'] <= defaultBaselines.averageBuildTime)}  |
| Slowest Frame Raster Time (ms)              | <= ${defaultBaselines.worstBuildTime}             | ${performance['worst_frame_raster_time_millis']} | ${checkOrCross(performance['worst_frame_raster_time_millis'] <= defaultBaselines.worstBuildTime)}  |

### Device Performance

| Metric                                      | Baseline               | Actual                | Status |
|---------------------------------------------|------------------------|-----------------------|--------|
| Initial Memory Usage (MB)                   | <= ${defaultBaselines.memoryUsageMB}              | ${bytesToMB(memoryUsageInitial['heapUsage'])}     | ${checkOrCross(double.parse(bytesToMB(memoryUsageInitial['heapUsage'])) <= defaultBaselines.memoryUsageMB)}  |
| Final Memory Usage (MB)                     | <= ${defaultBaselines.memoryUsageMB}              | ${bytesToMB(memoryUsageFinal['heapUsage'])}       | ${checkOrCross(double.parse(bytesToMB(memoryUsageFinal['heapUsage'])) <= defaultBaselines.memoryUsageMB)}  |
| CPU Usage Increase (Cycles)                 | <= ${defaultBaselines.cpuUsageIncrease} cycles                     | ${cpuUsage['final']['total_cpu_samples'] - cpuUsage['initial']['total_cpu_samples']} | ${checkOrCross((cpuUsage['final']['total_cpu_samples'] - cpuUsage['initial']['total_cpu_samples']) <= defaultBaselines.cpuUsageIncrease)}  |
''';
}
