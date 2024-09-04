import 'package:vm_service/vm_service.dart';

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
