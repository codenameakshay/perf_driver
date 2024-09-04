import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

typedef TestCallback = Future<void> Function(IntegrationTestWidgetsFlutterBinding binding, WidgetTester tester);

/// Wrap your integration test with this method, and use the driver to run the test.
/// Currently, this method generates a performance report for the test, which includes UI and raster thread performance metrics.
/// It also includes the device CPU and memory details, but they are highly dependent on the baseline, so they are not very useful as it is.
///
/// Example command - `fvm flutter drive --driver=package:perf_driver/perf_driver.dart --target=test.dart --no-dds --profile`
Future<void> runPerformanceTest(
  String testName, {
  required Widget testWidget,
  required WidgetTester tester,
  required TestCallback callback,

  /// Whether to wrap the test widget with a MaterialApp
  /// Also if performance overlay is true, this value is ignored
  bool wrapWithMaterialApp = true,
  bool showPerformanceOverlay = true,
}) async {
  final binding = IntegrationTestWidgetsFlutterBinding.instance;
  VmService? vmService;
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

    await binding.traceAction(
      () async {
        await tester.pumpWidget(
          showPerformanceOverlay || wrapWithMaterialApp
              ? MaterialApp(
                  showPerformanceOverlay: true,
                  home: testWidget,
                )
              : testWidget,
        );
        // Run the user-provided test callback
        await callback(binding, tester);

        // Measure final CPU and memory usage after the interaction
        final finalCpuUsage = await getCpuUsage(vmService, isolateId);
        final finalMemoryUsage = await getMemoryUsage(vmService, isolateId);

        // Report the benchmark result
        binding.reportData = <String, dynamic>{
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
      },
      retainPriorEvents: true,
      reportKey: 'widget_build',
    );
  } on Exception catch (e) {
    developer.log(e.toString());
  } finally {
    // Clean up
    await vmService?.dispose();
  }
}

Future<Map<String, dynamic>> getCpuUsage(VmService? vmService, String? isolateId) async {
  if (isolateId == null) {
    return <String, dynamic>{};
  }
  final timeline = await vmService?.getCpuSamples(isolateId, 0, DateTime.now().millisecondsSinceEpoch);
  final totalCpuSamples = timeline?.samples?.length ?? 0;
  return {
    'total_cpu_samples': totalCpuSamples,
  };
}

Future<Map<String, dynamic>> getMemoryUsage(VmService? vmService, String? isolateId) async {
  if (isolateId == null) {
    return <String, dynamic>{};
  }
  final memoryUsage = await vmService?.getMemoryUsage(isolateId);
  return {
    'memory_usage': memoryUsage,
  };
}

Future<Map<String, String>> getDeviceDetails(VmService? vmService) async {
  final vm = await vmService?.getVM();
  return {
    'operating_system': vm?.operatingSystem ?? 'Unknown OS',
  };
}
