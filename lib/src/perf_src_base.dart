import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_driver/flutter_driver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perf_driver/perf_src.dart';
import 'package:vm_service/vm_service.dart' as vm;
import 'package:vm_service/vm_service_io.dart';

typedef TestBaseCallback = Future<void> Function(FlutterDriver driver, WidgetTester tester);

/// This method wraps your performance test with Flutter Driver.
/// It generates a performance report, including UI and raster thread performance metrics,
/// as well as device CPU and memory details.
///
/// Example command - `fvm flutter drive --driver=test_driver/perf_driver.dart --target=test.dart --no-dds --profile`
Future<void> runPerformanceTestBase(
  String testName, {
  required Widget testWidget,
  required FlutterDriver driver,
  required WidgetTester tester,
  required TestBaseCallback callback,

  /// Whether to wrap the test widget with a MaterialApp
  /// Also if performance overlay is true, this value is ignored
  bool wrapWithMaterialApp = true,
  bool showPerformanceOverlay = true,
  String reportKey = 'widget_build',
}) async {
  vm.VmService? vmService;
  String? isolateId;

  try {
    // Connect to the VM service
    final serviceProtocolUri = await developer.Service.getInfo().then((info) => info.serverUri);
    vmService = await vmServiceConnectUri('${serviceProtocolUri?.replace(scheme: 'ws')}ws');

    // Get the isolate ID
    final vm = await vmService.getVM();
    isolateId = vm.isolates?.first.id;

    // Measure initial CPU and memory usage before any interaction
    final initialCpuUsage = await getCpuUsage(vmService, isolateId);
    final initialMemoryUsage = await getMemoryUsage(vmService, isolateId);
    final deviceDetails = await getDeviceDetails(vmService);

    // Start tracing performance
    await driver.startTracing();

    await tester.pumpWidget(
      showPerformanceOverlay || wrapWithMaterialApp
          ? MaterialApp(
              showPerformanceOverlay: true,
              home: testWidget,
            )
          : testWidget,
    );
    // Run the user-provided test callback
    await callback(driver, tester);

    // Stop tracing performance
    final timeline = await driver.stopTracingAndDownloadTimeline();

    // Measure final CPU and memory usage after the interaction
    final finalCpuUsage = await getCpuUsage(vmService, isolateId);
    final finalMemoryUsage = await getMemoryUsage(vmService, isolateId);

    // Report the benchmark result
    final timelineSummary = TimelineSummary.summarize(timeline);
    await timelineSummary.writeTimelineToFile(reportKey, pretty: true);

    final reportData = <String, dynamic>{
      'widget_build': timeline.json,
      'device_details': deviceDetails,
      'cpu_usage': {
        'initial': initialCpuUsage,
        'final': finalCpuUsage,
      },
      'memory_usage': {
        'initial': initialMemoryUsage,
        'final': finalMemoryUsage,
      },
    };

    driver.requestData(jsonEncode(reportData));
  } on Exception catch (e) {
    developer.log(e.toString());
  } finally {
    // Clean up
    await vmService?.dispose();
    await driver.close();
  }
}
