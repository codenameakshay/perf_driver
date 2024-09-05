import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_driver/flutter_driver.dart';

typedef TestBaseCallback = Future<void> Function(FlutterDriver driver);

Timeline? timeline;

/// This method wraps your performance test with Flutter Driver.
/// It generates a performance report, including UI and raster thread performance metrics,
/// as well as device CPU and memory details.
///
/// Example command - `fvm flutter drive --driver=test_driver/perf_driver.dart --target=test.dart --no-dds --profile`
Future<void> startPerformanceTest({
  required FlutterDriver driver,
}) async {
  try {
    await driver.startTracing();
  } on Exception catch (e, s) {
    developer.log(e.toString(), error: e, stackTrace: s);
  }
}

Future<String?> stopPerformanceTest({
  required FlutterDriver driver,
}) async {
  try {
    timeline = await driver.stopTracingAndDownloadTimeline();
    assert(timeline != null, 'Timeline is null');

    if (timeline == null) {
      throw Exception('Timeline is null');
    } else {
      // Report the benchmark result
      final timelineSummary = TimelineSummary.summarize(timeline!);
      await timelineSummary.writeTimelineToFile('widget_build', pretty: true);

      final reportData = <String, dynamic>{
        'widget_build': timeline?.json,
      };

      final perfDataResult = await driver.requestData(jsonEncode(reportData));
      developer.log(perfDataResult);
      return perfDataResult;
    }
  } on Exception catch (e, s) {
    developer.log(e.toString(), error: e, stackTrace: s);
    return null;
  }
}
