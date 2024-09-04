import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_driver/flutter_driver.dart';
import 'package:perf_driver/src/vm_utils.dart';
import 'package:vm_service/vm_service.dart' as vm;
import 'package:vm_service/vm_service_io.dart' show vmServiceConnectUri;

typedef TestBaseCallback = Future<void> Function(FlutterDriver driver);

/// This method wraps your performance test with Flutter Driver.
/// It generates a performance report, including UI and raster thread performance metrics,
/// as well as device CPU and memory details.
///
/// Example command - `fvm flutter drive --driver=test_driver/perf_driver.dart --target=test.dart --no-dds --profile`
Future<void> runPerformanceTestBase(
  String testName, {
  required FlutterDriver driver,
  required TestBaseCallback callback,
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

    final timeline = await driver.traceAction(
      () async {
        // Run the user-provided test callback
        await callback(driver);
      },
      retainPriorEvents: true,
    );

    // Measure final CPU and memory usage after the interaction
    final finalCpuUsage = await getCpuUsage(vmService, isolateId);
    final finalMemoryUsage = await getMemoryUsage(vmService, isolateId);

    // Report the benchmark result
    final timelineSummary = TimelineSummary.summarize(timeline);
    await timelineSummary.writeTimelineToFile('widget_build', pretty: true);

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
