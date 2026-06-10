# 代码结构说明

本文档用于说明 FatigueMon 的主要代码结构、模块职责和软著代码材料整理范围。

## 一、系统分层

系统按“界面入口、实验任务、数据分析、公共工具、Mock 测试”五层组织。

| 层级 | 目录或文件 | 职责 |
| --- | --- | --- |
| 界面入口 | `main.m` | 创建主界面，管理被试信息、任务按钮、参数状态和分析入口 |
| 环境检查 | `check_env.m` | 检查 MATLAB 环境、工具箱、核心文件、Mock 设备和 SDK 路径 |
| 实验任务 | `tasks/` | 实现基线静息、PVT 持续注意、疲劳后再测和任务参数对话框 |
| 数据分析 | `analysis/` | 实现 EEG 预处理、PVT 分析、疲劳指标分析和综合评分 |
| 公共工具 | `utils/` | 设备初始化、触发标记、被试信息、按键记录和界面显示工具 |
| Mock 测试 | `test/` | 提供无硬件环境下可运行的模拟数据客户端和触发器 |

## 二、核心流程

1. `main.m` 启动 GUI，并将项目根目录加入 MATLAB 路径。
2. 用户录入被试信息，选择真实设备或 Mock 模式。
3. 基线任务调用 `tasks/run_baseline.m`，保存睁眼/闭眼 EEG。
4. PVT 任务调用 `tasks/run_pvt.m`，保存刺激、按键、反应时、信号质量和可选疲劳分。
5. 疲劳再测调用 `tasks/run_fatigue_test.m`，复用基线采集流程并以 `FatigueTest` 范式保存。
6. 数据分析入口调用 `analysis/analysis_gui.m`，进一步选择 PVT、单次 EEG、基线对比或综合疲劳评分。

## 三、主要算法与实现点

- EEG 预处理：`analysis/eeg_preprocess.m`
  - 选择 EEG 通道，默认去除事件通道。
  - 使用 Butterworth 带通滤波。
  - 按通道去基线。
  - 可选 50/60 Hz 工频陷波。

- PVT 行为分析：`analysis/analyze_pvt.m`
  - 统计反应时、漏报率、快速反应比例。
  - 按滑动窗口计算反应时变异系数。
  - 估计趋势斜率，用于观察疲劳变化。

- EEG 疲劳指标：`analysis/analyze_fatigue.m`
  - 计算频段功率。
  - 输出 θ/α 等疲劳相关指标。
  - 支持基线与疲劳后数据对比。

- 综合疲劳评分：`analysis/compute_fatigue_score.m`
  - 融合反应时变异、EEG θ/α 变化和趋势斜率。
  - 输出 0 到 1 范围内的疲劳评分。

- Mock 设备：`test/MockDataClient.m`
  - 在无真实硬件时生成模拟脑电和触发通道数据。
  - 便于课堂演示、调试和流程验证。

## 四、软著代码材料建议范围

正式整理源代码文档时，建议优先包含以下文件：

```text
main.m
check_env.m
tasks/run_baseline.m
tasks/run_pvt.m
tasks/run_fatigue_test.m
tasks/params/params_baseline.m
tasks/params/params_pvt.m
analysis/eeg_preprocess.m
analysis/analyze_pvt.m
analysis/analyze_fatigue.m
analysis/compute_fatigue_score.m
analysis/analysis_gui.m
utils/device_init.m
utils/mark_and_grab.m
utils/compute_signal_quality.m
utils/subject_info.m
utils/info_from_gui.m
utils/record_key_event.m
utils/show_helpers/show_text.m
utils/show_helpers/show_fixation.m
utils/show_helpers/wait_for_key.m
test/MockDataClient.m
test/MockTriggerBox.m
test/MockTriggerStore.m
```

`.mat` 实验数据、临时截图、个人信息和设备厂商 SDK 不应作为源代码提交。

