import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter_driver/flutter_driver.dart' show Timeline, TimelineSummary;
import 'package:perf_driver/perf_driver.dart';

typedef FlutterDriverExtensionCallback = void Function({
  Future<String> Function(String?)? handler,
});

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
Future<void> perfDriverBase({
  required FlutterDriverExtensionCallback flutterDriverExtension,
  PerformanceBaselines? customBaselines,
}) async {
  final baselines = customBaselines ?? const PerformanceBaselines();

  flutterDriverExtension(handler: (data) async {
    if (data != null) {
      final jsonData = jsonDecode(data) as Map<String, dynamic>;
      final cpuUsageData = jsonData['cpu_usage'] as Map<String, dynamic>;
      final memoryUsageData = jsonData['memory_usage'] as Map<String, dynamic>;
      final widgetBuildData = jsonData['widget_build'] as Map<String, dynamic>;
      final deviceDetails = jsonData['device_details'] as Map<String, dynamic>;

      final timeline = Timeline.fromJson(
        widgetBuildData,
      );
      final summary = TimelineSummary.summarize(timeline);

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
      saveMarkdownFile(
          report, '${DateTime.now().toIso8601String()}.md', 'performance_report/${deviceDetails['operating_system']}');

      // Write the timeline to a file for further analysis if needed
      await summary.writeTimelineToFile(
        'widget_build',
        pretty: true,
        includeSummary: true,
      );
      return 'Performance data saved successfully!';
    } else {
      dev.log('No data received');
      return 'No data received';
    }
  });
}
