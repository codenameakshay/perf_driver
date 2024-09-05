# Performance Driver

A Flutter package for running performance tests and generating detailed performance reports. This package helps developers analyze their app's performance metrics, including CPU usage, memory usage, widget build times, and frame rendering metrics.

## Features

- Collects performance data using Flutter's integration test framework.
- Generates detailed markdown reports with performance metrics.
- Provides suggestions for performance improvements based on collected data.
- Supports custom performance baselines for tailored analysis.

## Versions

The Performance Driver package offers two versions for running performance tests:

1. **flutter_driver**:

   - Uses the legacy `flutter_driver` package.
   - Suitable for apps that are not yet migrated to the new integration testing framework.
   - Provides a more traditional approach to UI testing.

2. **integration_test**:
   - Utilizes the newer `integration_test` package.
   - Recommended for new projects as it offers better performance and more features.
   - Supports more advanced testing scenarios and improved reporting.

### Differences

| Feature               | flutter_driver                    | integration_test                |
| --------------------- | --------------------------------- | ------------------------------- |
| Testing Framework     | Legacy `flutter_driver`           | New `integration_test`          |
| Performance Reporting | Basic reporting capabilities      | Detailed markdown reports       |
| Test Execution        | Slower due to legacy architecture | Faster and more efficient       |
| API Support           | Limited to older APIs             | Full support for new APIs       |
| Community Support     | Less active                       | Actively maintained and updated |

## Getting Started

To use the Performance Driver package, follow these steps:

1. **Add the dependency** to your `pubspec.yaml` file:

   ```yaml
   dependencies:
     perf_driver: ^0.0.1
   ```

2. **Import the package** in your Dart file:

   ```dart
   import 'package:perf_driver/perf_driver.dart';
   ```

3. **Run performance tests** by creating a sample driver file in your project.

## Usage

To run performance tests, you can use the `perfDriver` function. Here’s an example of how to set it up:

```dart
import 'package:flutter/material.dart';
import 'package:perf_driver/perf_driver.dart';

void main() {
  perfDriver();
  // Or with custom baselines:
  // perfDriver(customBaselines: PerformanceBaselines(...));
}
```

### Example of Running a Performance Test

You can wrap your integration test with the `runPerformanceTest` method to generate a performance report:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:perf_driver/src/perf_src.dart';

Future<void> main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('MyApp Tests', (tester) async {
      await runPerformanceTest(
    'My Performance Test',
    testWidget: MyApp(),
    tester: tester,
    callback: (binding, tester) async {
      // Interact with your app here
      await tester.pumpAndSettle();
    },
  );
});
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Performance Test')),
        body: Center(child: Text('Hello, World!')),
      ),
    );
  }
}
```

## Additional Information

For more information on how to contribute to the package, file issues, or find more resources, please refer to the [Dart documentation](https://dart.dev/guides) and the [Flutter documentation](https://flutter.dev/docs).

## License

This package is licensed under the MIT License. See the LICENSE file for more details.
