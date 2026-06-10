# FatigueMon: EEG Fatigue Assessment System

基于 MATLAB 的脑电疲劳评估系统，支持基线静息采集、PVT 持续注意任务、疲劳后再测、PVT 行为分析、EEG 频段分析和综合疲劳评分。系统同时提供真实脑电设备接入和 Mock 模拟设备模式，便于在无硬件环境下完成演示、教学和流程验证。

## 功能概览

- 图形化主界面：统一管理被试信息、实验任务、参数配置和数据分析入口。
- 三阶段实验流程：清醒基线、PVT 疲劳诱发、疲劳后静息再测。
- PVT 任务：支持可配置时长、刺激间隔、实时疲劳分显示、自适应 ISI 和信号质量提示。
- EEG 采集：支持博瑞康 64 导脑电设备，也支持内置 Mock 数据客户端。
- 数据分析：包含反应时统计、漏报率、滑动窗口 CV、EEG θ/α 指标、基线归一化和综合疲劳评分。
- 自动保存：每次实验按被试和任务类型保存为 `.mat` 文件。

## 目录结构

```text
Fatigue_System/
  main.m                         # 系统主界面入口
  check_env.m                    # 环境自检脚本
  tasks/                         # 实验任务与参数配置
  analysis/                      # 数据分析与疲劳评分
  utils/                         # 设备、被试信息、显示与采集工具
  test/                          # Mock 设备与触发器
  docs/                          # 项目说明文档
  data/                          # 本地实验数据目录，.mat 数据默认不入库
  stimuli/                       # 刺激素材说明
```

## 运行环境

- Windows 10/11
- MATLAB R2022b 或更高版本，推荐 R2024a
- Signal Processing Toolbox
- 可选硬件：博瑞康 64 导脑电设备及对应 SDK

无真实设备时，可在主界面勾选“使用模拟设备”和“伪 EEG”，完成主要流程测试。

## 快速开始

在 MATLAB 中执行：

```matlab
cd D:\Fatigue_System
check_env
main
```

推荐流程：

1. 打开 `main` 主界面。
2. 填写被试编号、分组、年龄和性别。
3. 勾选 Mock 模式进行首次测试。
4. 依次运行“基线静息”、“PVT 持续注意”、“疲劳再测”。
5. 点击“分析数据”，选择被试和分析类型。

## 数据保存

实验数据默认保存到：

```text
data/<subject>/<task>/<subject>_<task>_<timestamp>.mat
```

其中 `<task>` 包括：

- `Baseline`
- `PVT`
- `FatigueTest`

出于隐私和仓库体积考虑，`.gitignore` 默认排除 `data/**/*.mat`。如需共享示例数据，建议先脱敏并单独放入 `docs/examples/` 或发布包。

## 主要模块

| 模块 | 文件 | 说明 |
| --- | --- | --- |
| 主界面 | `main.m` | 任务入口、参数管理、状态日志和分析入口 |
| 环境检查 | `check_env.m` | 检查 MATLAB 版本、工具箱、目录结构和 Mock 设备 |
| 基线任务 | `tasks/run_baseline.m` | 睁眼/闭眼静息采集 |
| PVT 任务 | `tasks/run_pvt.m` | 持续注意任务、自适应 ISI、信号质量记录 |
| 疲劳再测 | `tasks/run_fatigue_test.m` | 疲劳后静息采集 |
| EEG 预处理 | `analysis/eeg_preprocess.m` | 通道选择、带通滤波、去基线和可选陷波 |
| PVT 分析 | `analysis/analyze_pvt.m` | 反应时、漏报率、CV、趋势斜率 |
| 疲劳分析 | `analysis/analyze_fatigue.m` | 频段功率、θ/α 和基线对比 |
| 综合评分 | `analysis/compute_fatigue_score.m` | 行为和 EEG 指标融合评分 |
| 设备初始化 | `utils/device_init.m` | 真实设备和 Mock 设备统一入口 |

## 注意事项

- 本系统用于科研、教学和实验辅助，不应单独作为医学诊断依据。
- 使用真实脑电设备前，请确认设备 SDK 路径和采集软件状态。
- 采集真实被试数据前，请按所在机构要求完成伦理审批、知情同意和数据脱敏。

## 版本

当前整理版本：V1.0 / 2026-06
