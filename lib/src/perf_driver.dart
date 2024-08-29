import 'dart:io';
import 'dart:developer' as dev;

import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() {
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
        final frameRateInfo = {
          '30Hz': summary.summaryJson['30hz_frame_percentage'],
          '60Hz': summary.summaryJson['60hz_frame_percentage'],
          '80Hz': summary.summaryJson['80hz_frame_percentage'],
          '90Hz': summary.summaryJson['90hz_frame_percentage'],
          '120Hz': summary.summaryJson['120hz_frame_percentage'],
        };

        final testingData = {
          'device_details': deviceDetails,
          'frame_rate_info': frameRateInfo,
          'performance': performanceData,
          'cpu_usage': cpuUsageData,
          'memory_usage': memoryUsageData,
        };

        final report = convertMapToReadableText(testingData);
        // print(report);
        saveMarkdownFile(report, '${DateTime.now().toIso8601String()}.md',
            'performance_report/${deviceDetails['operating_system']}');

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

String bytesToMB(int? bytes) {
  return ((bytes ?? 0) / (1024 * 1024)).toStringAsFixed(2);
}

void saveMarkdownFile(String content, String fileName, String directory) async {
  final dir = Directory(directory);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  final file = File('$directory/$fileName');
  await file.writeAsString(content);
  dev.log('Markdown file saved as $directory/$fileName');
}

String convertMapToReadableText(Map<String, dynamic> data) {
  final performance = data['performance'];
  final cpuUsage = data['cpu_usage'];
  final memoryUsageInitial = data['memory_usage']['initial']['memory_usage'];
  final memoryUsageFinal = data['memory_usage']['final']['memory_usage'];
  final deviceDetails = data['device_details'];
  final frameRateInfo = data['frame_rate_info'] as Map<String, dynamic>?;

  String frameRateString = frameRateInfo != null
      ? frameRateInfo.entries
          .where((entry) => entry.value > 0)
          .map((entry) => '- ${entry.key}: ${entry.value}%')
          .join('\n')
      : 'No frame rate data';

  String checkOrCross(bool condition) => condition ? '✅' : '❌';

  // Baseline values
  const baseline90thPercentileBuildTime = 6.0; // in milliseconds
  const baseline95thPercentileBuildTime = 8.0; // in milliseconds
  const baseline99thPercentileBuildTime = 12.0; // in milliseconds
  const baselineMissedFrameBuildBudgetCount = 2; // 2 frames
  const baselineMissedFrameBuildBudgetPercentage = 2.5; // 2.5% of total frames
  const baselineMissedFrameRasterizerBudgetCount = 2; // 2 frames
  const baselineMissedFrameRasterizerBudgetPercentage = 2.5; // 2.5% of total frames
  const baselineAverageBuildTime = 6.0; // in milliseconds
  const baselineWorstBuildTime = 30.0; // in milliseconds
  const baselineMemoryUsageMB = 200.0; // in MB
  const baselineCpuUsageIncrease = 500000; // CPU sample increase

  String generateImprovementSuggestions(
      Map<String, dynamic> performance, Map<String, dynamic> cpuUsage, int totalFrames, int totalRasterizerFrames) {
    StringBuffer suggestions = StringBuffer();

    // 90th Percentile Frame Build Time (UI)
    if (performance['90th_percentile_frame_build_time_millis'] > baseline90thPercentileBuildTime) {
      suggestions.writeln(
          "- **UI Build Time:** The 90th percentile frame build time is higher than expected (${performance['90th_percentile_frame_build_time_millis']} ms). Enable the performance overlay and identify heavy operations or widget rebuilds that may be slowing down your UI.");
    }

    // 95th Percentile Frame Build Time (UI)
    if (performance['95th_percentile_frame_build_time_millis'] > baseline95thPercentileBuildTime) {
      suggestions.writeln(
          "- **UI Build Time:** The 95th percentile frame build time is high (${performance['95th_percentile_frame_build_time_millis']} ms). Consider refactoring or optimizing your widgets to reduce the load on the UI thread.");
    }

    // 99th Percentile Frame Build Time (UI)
    if (performance['99th_percentile_frame_build_time_millis'] > baseline99thPercentileBuildTime) {
      suggestions.writeln(
          "- **UI Build Time:** The 99th percentile frame build time is excessively high (${performance['99th_percentile_frame_build_time_millis']} ms). Investigate for any expensive operations that may need to be offloaded to a background thread.");
    }

    // Skipped UI Frames
    int maxSkippedFramesUI = (baselineMissedFrameBuildBudgetPercentage * totalFrames).round();
    if (performance['missed_frame_build_budget_count'] > baselineMissedFrameBuildBudgetCount ||
        performance['missed_frame_build_budget_count'] > maxSkippedFramesUI) {
      suggestions.writeln(
          "- **Skipped UI Frames:** Your app skipped ${performance['missed_frame_build_budget_count']} UI frames. Investigate the performance overlay and ensure that your UI operations are efficient.");
    }

    // 90th Percentile Frame Raster Time
    if (performance['90th_percentile_frame_raster_time_millis'] > baseline90thPercentileBuildTime) {
      suggestions.writeln(
          "- **Raster Time:** The 90th percentile frame raster time is higher than expected (${performance['90th_percentile_frame_raster_time_millis']} ms). Consider simplifying your visuals or reducing the number of layers.");
    }

    // 95th Percentile Frame Raster Time
    if (performance['95th_percentile_frame_raster_time_millis'] > baseline95thPercentileBuildTime) {
      suggestions.writeln(
          "- **Raster Time:** The 95th percentile frame raster time is high (${performance['95th_percentile_frame_raster_time_millis']} ms). Optimize your rendering logic or avoid using complex drawing operations.");
    }

    // 99th Percentile Frame Raster Time
    if (performance['99th_percentile_frame_raster_time_millis'] > baseline99thPercentileBuildTime) {
      suggestions.writeln(
          "- **Raster Time:** The 99th percentile frame raster time is excessively high (${performance['99th_percentile_frame_raster_time_millis']} ms). Check for expensive graphics operations or consider reducing visual complexity.");
    }

    // Skipped Raster Frames
    int maxSkippedFramesRaster = (baselineMissedFrameRasterizerBudgetPercentage * totalFrames).round();
    if (performance['missed_frame_rasterizer_budget_count'] > baselineMissedFrameRasterizerBudgetCount ||
        performance['missed_frame_rasterizer_budget_count'] > maxSkippedFramesRaster) {
      suggestions.writeln(
          "- **Skipped Raster Frames:** Your app skipped ${performance['missed_frame_rasterizer_budget_count']} raster frames. This indicates heavy graphics operations that may need to be optimized.");
    }

    // Average Frame Build Time (UI)
    if (performance['average_frame_build_time_millis'] > baselineAverageBuildTime) {
      suggestions.writeln(
          "- **Average UI Build Time:** The average frame build time is higher than expected (${performance['average_frame_build_time_millis']} ms). Consider optimizing your widget tree and avoiding unnecessary rebuilds.");
    }

    // Slowest Frame Build Time (UI)
    if (performance['worst_frame_build_time_millis'] > baselineWorstBuildTime) {
      suggestions.writeln(
          "- **Slowest UI Frame Build Time:** The slowest frame build time was particularly high (${performance['worst_frame_build_time_millis']} ms). Investigate the cause using the performance overlay and try to identify heavy operations.");
    }

    // Average Frame Raster Time
    if (performance['average_frame_raster_time_millis'] > baselineAverageBuildTime) {
      suggestions.writeln(
          "- **Average Raster Time:** The average frame raster time is higher than expected (${performance['average_frame_raster_time_millis']} ms). Consider simplifying your visual design or reducing the number of layers.");
    }

    // Slowest Frame Raster Time
    if (performance['worst_frame_raster_time_millis'] > baselineWorstBuildTime) {
      suggestions.writeln(
          "- **Slowest Raster Frame Time:** The slowest raster frame time was particularly high (${performance['worst_frame_raster_time_millis']} ms). Optimize your graphics operations or consider offloading heavy work to a background thread.");
    }

    // CPU Usage Increase
    int cpuUsageIncrease = cpuUsage['final']['total_cpu_samples'] - cpuUsage['initial']['total_cpu_samples'];
    if (cpuUsageIncrease > baselineCpuUsageIncrease) {
      suggestions.writeln(
          "- **High CPU Usage:** The CPU usage increased significantly ($cpuUsageIncrease cycles). Consider using the CPU profiler in DevTools to identify potential bottlenecks and optimize your code.");
    }

    if (suggestions.isEmpty) {
      suggestions.writeln("Your app is performing well with no significant issues detected.");
    }

    return suggestions.toString();
  }

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
| 90th Percentile Frame Build Time (ms)       | <= $baseline90thPercentileBuildTime    | ${performance['90th_percentile_frame_build_time_millis']} | ${checkOrCross(performance['90th_percentile_frame_build_time_millis'] <= baseline90thPercentileBuildTime)}  |
| 95th Percentile Frame Build Time (ms)       | <= $baseline95thPercentileBuildTime    | ${performance['95th_percentile_frame_build_time_millis']} | ${checkOrCross(performance['95th_percentile_frame_build_time_millis'] <= baseline95thPercentileBuildTime)}  |
| 99th Percentile Frame Build Time (ms)       | <= $baseline99thPercentileBuildTime    | ${performance['99th_percentile_frame_build_time_millis']} | ${checkOrCross(performance['99th_percentile_frame_build_time_millis'] <= baseline99thPercentileBuildTime)}  |
| Skipped Frames (Count)                      | <= $baselineMissedFrameBuildBudgetCount frames OR <= $baselineMissedFrameBuildBudgetPercentage% of ${performance['total_frames']} = ${(baselineMissedFrameBuildBudgetPercentage * performance['total_frames'] / 100)} | ${performance['missed_frame_build_budget_count']} | ${checkOrCross(performance['missed_frame_build_budget_count'] <= baselineMissedFrameBuildBudgetCount || performance['missed_frame_build_budget_count'] <= (baselineMissedFrameBuildBudgetPercentage * performance['total_frames'] / 100))}  |
| Average Frame Build Time (ms)               | <= $baselineAverageBuildTime           | ${performance['average_frame_build_time_millis']} | ${checkOrCross(performance['average_frame_build_time_millis'] <= baselineAverageBuildTime)}  |
| Slowest Frame Build Time (ms)               | <= $baselineWorstBuildTime             | ${performance['worst_frame_build_time_millis']} | ${checkOrCross(performance['worst_frame_build_time_millis'] <= baselineWorstBuildTime)}  |

### Raster Thread Performance

| Metric                                      | Baseline               | Actual (Raster)       | Status |
|---------------------------------------------|------------------------|-----------------------|--------|
| 90th Percentile Frame Raster Time (ms)      | <= $baseline90thPercentileBuildTime    | ${performance['90th_percentile_frame_raster_time_millis']} | ${checkOrCross(performance['90th_percentile_frame_raster_time_millis'] <= baseline90thPercentileBuildTime)}  |
| 95th Percentile Frame Raster Time (ms)      | <= $baseline95thPercentileBuildTime    | ${performance['95th_percentile_frame_raster_time_millis']} | ${checkOrCross(performance['95th_percentile_frame_raster_time_millis'] <= baseline95thPercentileBuildTime)}  |
| 99th Percentile Frame Raster Time (ms)      | <= $baseline99thPercentileBuildTime    | ${performance['99th_percentile_frame_raster_time_millis']} | ${checkOrCross(performance['99th_percentile_frame_raster_time_millis'] <= baseline99thPercentileBuildTime)}  |
| Skipped Frames (Count)                      | <= $baselineMissedFrameRasterizerBudgetCount frames OR <= $baselineMissedFrameRasterizerBudgetPercentage% of ${performance['total_rasterizer_frames']} = ${(baselineMissedFrameRasterizerBudgetPercentage * performance['total_rasterizer_frames'] / 100)} | ${performance['missed_frame_rasterizer_budget_count']} | ${checkOrCross(performance['missed_frame_rasterizer_budget_count'] <= baselineMissedFrameRasterizerBudgetCount || performance['missed_frame_rasterizer_budget_count'] <= (baselineMissedFrameRasterizerBudgetPercentage * performance['total_rasterizer_frames'] / 100))}  |
| Average Frame Raster Time (ms)              | <= $baselineAverageBuildTime           | ${performance['average_frame_raster_time_millis']} | ${checkOrCross(performance['average_frame_raster_time_millis'] <= baselineAverageBuildTime)}  |
| Slowest Frame Raster Time (ms)              | <= $baselineWorstBuildTime             | ${performance['worst_frame_raster_time_millis']} | ${checkOrCross(performance['worst_frame_raster_time_millis'] <= baselineWorstBuildTime)}  |

### Device Performance

| Metric                                      | Baseline               | Actual                | Status |
|---------------------------------------------|------------------------|-----------------------|--------|
| Initial Memory Usage (MB)                   | <= $baselineMemoryUsageMB              | ${bytesToMB(memoryUsageInitial['heapUsage'])}     | ${checkOrCross(double.parse(bytesToMB(memoryUsageInitial['heapUsage'])) <= baselineMemoryUsageMB)}  |
| Final Memory Usage (MB)                     | <= $baselineMemoryUsageMB              | ${bytesToMB(memoryUsageFinal['heapUsage'])}       | ${checkOrCross(double.parse(bytesToMB(memoryUsageFinal['heapUsage'])) <= baselineMemoryUsageMB)}  |
| CPU Usage Increase (Cycles)                 | <= $baselineCpuUsageIncrease cycles                     | ${cpuUsage['final']['total_cpu_samples'] - cpuUsage['initial']['total_cpu_samples']} | ${checkOrCross((cpuUsage['final']['total_cpu_samples'] - cpuUsage['initial']['total_cpu_samples']) <= baselineCpuUsageIncrease)}  |
''';
}
