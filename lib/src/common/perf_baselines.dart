/// Defines performance baseline metrics for an application.
class PerformanceBaselines {
  /// Creates a new [PerformanceBaselines] instance with default values.
  const PerformanceBaselines({
    this.percentile90thBuildTime = 6.0,
    this.percentile95thBuildTime = 8.0,
    this.percentile99thBuildTime = 12.0,
    this.missedFrameBuildBudgetCount = 2,
    this.missedFrameBuildBudgetPercentage = 2.5,
    this.missedFrameRasterizerBudgetCount = 2,
    this.missedFrameRasterizerBudgetPercentage = 2.5,
    this.averageBuildTime = 6.0,
    this.worstBuildTime = 30.0,
    this.memoryUsageMB = 200.0,
    this.cpuUsageIncrease = 500000,
  });

  /// The 90th percentile of frame build times in milliseconds.
  final double percentile90thBuildTime;

  /// The 95th percentile of frame build times in milliseconds.
  final double percentile95thBuildTime;

  /// The 99th percentile of frame build times in milliseconds.
  final double percentile99thBuildTime;

  /// The number of frames that missed the build budget.
  final int missedFrameBuildBudgetCount;

  /// The percentage of frames that missed the build budget.
  final double missedFrameBuildBudgetPercentage;

  /// The number of frames that missed the rasterizer budget.
  final int missedFrameRasterizerBudgetCount;

  /// The percentage of frames that missed the rasterizer budget.
  final double missedFrameRasterizerBudgetPercentage;

  /// The average frame build time in milliseconds.
  final double averageBuildTime;

  /// The worst (longest) frame build time in milliseconds.
  final double worstBuildTime;

  /// The memory usage of the application in megabytes.
  final double memoryUsageMB;

  /// The increase in CPU usage, measured in CPU samples.
  final int cpuUsageIncrease;
}
