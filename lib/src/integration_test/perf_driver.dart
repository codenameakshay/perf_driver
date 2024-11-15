import 'dart:developer' as dev;

import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';
import 'package:perf_driver/src/common/perf_baselines.dart';
import 'package:perf_driver/src/common/utils.dart';

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
///   perfDriverIntegrationTest();
///   // Or with custom baselines:
///   // perfDriverIntegrationTest(customBaselines: PerformanceBaselines(...));
/// }
/// ```
Future<void> perfDriverIntegrationTest(
    {PerformanceBaselines? customBaselines}) {
  final baselines = customBaselines ?? const PerformanceBaselines();

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
          '90th_percentile_frame_build_time_millis':
              summary.computePercentileFrameBuildTimeMillis(90),
          '95th_percentile_frame_build_time_millis':
              summary.computePercentileFrameBuildTimeMillis(95),
          '99th_percentile_frame_build_time_millis':
              summary.computePercentileFrameBuildTimeMillis(99),
          'missed_frame_build_budget_count':
              summary.computeMissedFrameBuildBudgetCount(),
          'average_frame_build_time_millis':
              summary.computeAverageFrameBuildTimeMillis(),
          'worst_frame_build_time_millis':
              summary.computeWorstFrameBuildTimeMillis(),
          'total_frames': summary.countFrames(),
          '90th_percentile_frame_raster_time_millis':
              summary.computePercentileFrameRasterizerTimeMillis(90),
          '95th_percentile_frame_raster_time_millis':
              summary.computePercentileFrameRasterizerTimeMillis(95),
          '99th_percentile_frame_raster_time_millis':
              summary.computePercentileFrameRasterizerTimeMillis(99),
          'missed_frame_rasterizer_budget_count':
              summary.computeMissedFrameRasterizerBudgetCount(),
          'average_frame_raster_time_millis':
              summary.computeAverageFrameRasterizerTimeMillis(),
          'worst_frame_raster_time_millis':
              summary.computeWorstFrameRasterizerTimeMillis(),
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
        final report =
            convertMapToReadableText(testingData, defaultBaselines: baselines);
        await saveMarkdownFile(
          report,
          '${DateTime.now().toIso8601String()}.md',
          'performance_report/${deviceDetails['operating_system']}',
        );

        // Write the timeline to a file for further analysis if needed
        await summary.writeTimelineToFile(
          'widget_build',
          pretty: true,
        );
      } else {
        dev.log('No data received');
      }
    },
  );
}
