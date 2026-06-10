function quality = compute_signal_quality(eegSegment, varargin)
% COMPUTE_SIGNAL_QUALITY  实时 EEG 信号质量评估
% =========================================================
% 根据短时 EEG 片段, 计算一个 0-1 的"信号质量分":
%   1.0 = 完美 (无伪迹)
%   0.6-1.0 = 良好
%   0.3-0.6 = 可疑 (建议被试放松)
%   0.0-0.3 = 差 (大量伪迹, 数据不可用)
%
% 评估算法 (无需 CNN, 用简单稳健的统计):
%   ① 振幅超阈值率: 振幅 > ampThresh µV 的采样点比例
%   ② 高频噪声占比: >30Hz 频段的能量占总能量的比例
%   ③ 标准差异常: 通道间标准差差异过大 (说明某通道伪迹)
%
% 三个子分数加权得到总分。
%
% 用法:
%   q = compute_signal_quality(eegSeg);
%   q = compute_signal_quality(eegSeg, 'fs', 500, 'ampThresh', 100);
%
% 参数:
%   eegSegment : nChan × nSamples 的 EEG 片段 (前 64 通道是 EEG)
%   'fs'         采样率, 默认 500
%   'ampThresh'  振幅阈值(µV), 默认 100 (超过这个值视为伪迹)
%   'nEEG'       EEG 通道数(去掉 trigger 通道), 默认 64
%
% 返回 (struct):
%   quality.score      总质量分 0-1
%   quality.color      建议颜色 [R G B] (用于 GUI 提示)
%   quality.level      文字等级: 'good' / 'caution' / 'bad'
%   quality.detail     子分数: ampScore / hfScore / chanScore
% =========================================================

%% 参数
p = inputParser;
addParameter(p, 'fs',        500, @isnumeric);
addParameter(p, 'ampThresh', 100, @isnumeric);
addParameter(p, 'nEEG',      64,  @isnumeric);
parse(p, varargin{:});
opt = p.Results;

% 取 EEG 通道
nCh = min(opt.nEEG, size(eegSegment,1));
eeg = double(eegSegment(1:nCh, :));

% 防呆: 空数据
if isempty(eeg) || size(eeg,2) < 10
    quality.score = 0;
    quality.color = [0.6 0.6 0.6];
    quality.level = 'unknown';
    quality.detail = struct('ampScore',0,'hfScore',0,'chanScore',0);
    return;
end

%% ----- ① 振幅超阈值率 -----
% 振幅特别大的采样点比例 -> 伪迹强
absEEG = abs(eeg);
overThresh = sum(absEEG(:) > opt.ampThresh);
total = numel(eeg);
overRate = overThresh / total;
% 转成"质量分": 超阈值越少越好
% overRate=0 → 1, overRate=0.5+ → 0
ampScore = max(0, 1 - 2 * overRate);

%% ----- ② 高频噪声占比 -----
% 高频(>30Hz)能量占比, 高了说明肌电/工频干扰
hfScore = 1;   % 默认满分(短数据算不出 FFT 时)
if size(eeg,2) >= opt.fs       % 至少 1 秒
    % 只看跨通道平均信号的 FFT (省时)
    sig = mean(eeg, 1);
    N = length(sig);
    Y = abs(fft(sig));
    f = (0:N-1) * opt.fs / N;
    halfMask = f >= 0 & f <= opt.fs/2;
    f = f(halfMask);
    P = Y(halfMask).^2;
    totalP = sum(P) + eps;
    hfP = sum(P(f > 30));
    hfRatio = hfP / totalP;
    % hfRatio=0 → 1, hfRatio=0.5+ → 0
    hfScore = max(0, 1 - 2 * hfRatio);
end

%% ----- ③ 通道标准差异常 -----
% 各通道 std, 算"四分位距", 异常通道占比
chStd = std(eeg, 0, 2);
medStd = median(chStd);
% 偏离中位数超过 5 倍的通道认为异常
abnormal = sum(chStd > 5 * medStd | chStd < 0.2 * medStd);
abnormalRate = abnormal / nCh;
% abnormalRate=0 → 1, abnormalRate=0.5+ → 0
chanScore = max(0, 1 - 2 * abnormalRate);

%% ----- 总分 (加权) -----
% 振幅权重最大(最直接), 其他作参考
totalScore = 0.5 * ampScore + 0.3 * hfScore + 0.2 * chanScore;
totalScore = max(0, min(1, totalScore));

%% ----- 等级 + 颜色 -----
if totalScore >= 0.7
    color = [0.4 0.9 0.4];  % 绿
    level = 'good';
elseif totalScore >= 0.4
    color = [1.0 0.85 0.3]; % 黄
    level = 'caution';
else
    color = [1.0 0.4 0.4];  % 红
    level = 'bad';
end

quality.score = totalScore;
quality.color = color;
quality.level = level;
quality.detail.ampScore  = ampScore;
quality.detail.hfScore   = hfScore;
quality.detail.chanScore = chanScore;
quality.detail.overRate  = overRate;

end
