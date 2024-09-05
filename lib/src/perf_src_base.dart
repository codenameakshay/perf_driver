import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_driver/flutter_driver.dart';

typedef TestBaseCallback = Future<void> Function(FlutterDriver driver);

Timeline? timeline;

/// This method starts the performance test with Flutter Driver.
/// Make sure to create a new folder called `test_driver` in the root of your project.
/// Create a new file called `main.dart` in the `main_test.dart` folder.
/// Add the following code to the `main.dart` file:
/// ```dart
/// import 'package:flutter_driver/driver_extension.dart' show enableFlutterDriverExtension;
/// import 'package:perf_driver/perf_base.dart';
/// import 'package:your_app/main.dart' as app;
///
/// Future<void> main() async {
///   return await perfDriverBase(
///     flutterDriverExtension: enableFlutterDriverExtension,
///     runAppMain: app.main,
///   );
/// }
/// ```
///
/// Example command for running test - `fvm flutter drive --target=test_driver/test.dart --no-dds --profile`
Future<void> startPerformanceTest({
  required FlutterDriver driver,
}) async {
  try {
    await driver.startTracing();
  } on Exception catch (e, s) {
    developer.log(e.toString(), error: e, stackTrace: s);
  }
}

/// This method stops the performance test and generates a report.
/// It stops the tracing, downloads the timeline, and generates a markdown report
/// based on the performance metrics collected. The report includes detailed
/// information about the performance of the app, including frame build and raster
/// times, and frame rate information. The method returns the performance report
/// as a string.
///
/// Make sure to run this after `startPerformanceTest` method, and after your actual test.
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
