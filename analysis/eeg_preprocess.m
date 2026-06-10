function cleanData = eeg_preprocess(rawData, varargin)
% EEG_PREPROCESS  通用 EEG 预处理函数
% =========================================================
% 功能: 对原始 EEG 数据做标准预处理, 得到可用于分析的清洁数据
%
% 步骤:
%   1. 通道选择 (默认丢弃事件通道, 只保留 EEG)
%   2. 带通滤波 (默认 1-40 Hz)
%   3. 去基线 (每通道减去自身均值)
%   4. (可选) 50/60 Hz 工频陷波
%
% 用法:
%   clean = eeg_preprocess(raw);                       % 全部默认
%   clean = eeg_preprocess(raw, 'lowCut', 0.5);         % 改高通到 0.5Hz
%   clean = eeg_preprocess(raw, 'lowCut', 1, 'highCut', 30);
%   clean = eeg_preprocess(raw, 'sampleRate', 500, 'nEEG', 64);
%   clean = eeg_preprocess(raw, 'notch', 50);           % 加 50Hz 陷波
%
% 参数:
%   rawData      [nChan × nSamples] 原始 EEG, 通常 65×N (64 EEG + 1 事件)
%
% 可选键值参数:
%   'lowCut'     高通截止 (Hz), 默认 1
%                  作用: 去除直流漂移、缓慢出汗导致的电压偏移
%   'highCut'    低通截止 (Hz), 默认 40
%                  作用: 去除肌电(>30Hz)和工频(50Hz)
%   'sampleRate' 采样率 (Hz), 默认 500
%   'nEEG'       保留前几个通道作为 EEG, 默认 64 (丢弃第 65 个事件通道)
%   'notch'      陷波频率 (Hz), 默认 0 (不陷波). 可填 50 或 60
%   'order'      滤波器阶数, 默认 4 (Butterworth)
%
% 返回:
%   cleanData    [nEEG × nSamples] 清洁的 EEG 数据
%
% 设计说明:
%   - 此函数对任意数据形状都适用(只要 N 通道 × M 采样点)
%   - Mock 数据用此函数 → 仍然得到滤波后的数据(噪声变得更"平")
%   - 真数据用此函数 → 标准预处理流程
%   - 切换不需要改任何代码
% =========================================================

%% ----- 1. 参数解析 -----
p = inputParser;
addParameter(p, 'lowCut',     1,   @isnumeric);
addParameter(p, 'highCut',    40,  @isnumeric);
addParameter(p, 'sampleRate', 500, @isnumeric);
addParameter(p, 'nEEG',       64,  @isnumeric);
addParameter(p, 'notch',      0,   @isnumeric);
addParameter(p, 'order',      4,   @isnumeric);
parse(p, varargin{:});
opt = p.Results;

%% ----- 2. 校验输入 -----
if isempty(rawData)
    error('eeg_preprocess:EmptyData', '输入数据为空');
end

[nChan, nSamples] = size(rawData);

if nChan < opt.nEEG
    warning('eeg_preprocess:FewerChannels', ...
            '输入只有 %d 通道, 少于期望的 %d. 使用全部通道.', nChan, opt.nEEG);
    opt.nEEG = nChan;
end

if nSamples < 100
    warning('eeg_preprocess:ShortSegment', ...
            '数据过短 (%d 点), 滤波可能不稳定', nSamples);
end

%% ----- 3. 通道选择: 只保留 EEG -----
% 博瑞康 64 导通常是: 通道 1~64 = EEG, 通道 65 = 事件
% 默认丢弃事件通道
eegData = rawData(1:opt.nEEG, :);

%% ----- 4. 带通滤波 -----
% 用 Butterworth 滤波器: 1~40 Hz 是 EEG 分析的标准频段
%   < 1 Hz: 直流漂移, 不要
%   > 40 Hz: 肌电、工频, 不要
%
% Nyquist 频率 = 采样率的一半
nyq = opt.sampleRate / 2;

% 归一化频率 (Butter 需要 0~1 之间)
lowNorm  = opt.lowCut  / nyq;
highNorm = opt.highCut / nyq;

% 边界检查
if lowNorm >= highNorm
    error('eeg_preprocess:BadFreq', ...
          'lowCut (%.1f) 必须小于 highCut (%.1f)', opt.lowCut, opt.highCut);
end
if highNorm >= 1
    warning('eeg_preprocess:HighCutTooHigh', ...
            'highCut %.1f Hz 超过 Nyquist, 改用 %.1f Hz', ...
            opt.highCut, nyq*0.95);
    highNorm = 0.95;
end

% 设计 Butterworth 带通滤波器
[b, a] = butter(opt.order, [lowNorm, highNorm], 'bandpass');

% filtfilt 是零相位滤波 (双向跑一次), 比 filter 好
% 因为 ERP 分析对时间精度敏感, 不能有相位失真
filteredData = zeros(size(eegData));
for ch = 1:opt.nEEG
    filteredData(ch, :) = filtfilt(b, a, eegData(ch, :));
end

%% ----- 5. (可选) 工频陷波 -----
if opt.notch > 0
    % 设计窄带阻滤波器, 在 notch ± 1 Hz 处衰减
    notchLow  = (opt.notch - 1) / nyq;
    notchHigh = (opt.notch + 1) / nyq;
    [bn, an] = butter(opt.order, [notchLow, notchHigh], 'stop');
    for ch = 1:opt.nEEG
        filteredData(ch, :) = filtfilt(bn, an, filteredData(ch, :));
    end
end

%% ----- 6. 去基线 -----
% 每个通道减去自身均值, 让信号围绕 0 波动
% 这对功率谱分析很重要, 否则直流分量会主导
chMean = mean(filteredData, 2);              % 65 × 1
cleanData = filteredData - chMean;           % 自动广播

end
