function epoch = mark_and_grab(trig, dataClient, code, varargin)
% MARK_AND_GRAB  打 trigger 并从缓冲区截取一段 epoch 数据
% =========================================================
% 把"打 trigger → 等待 → 抓最后 N 秒"这个高频动作封装成一行。
% 您原代码里这种模式出现了几十次, 现在统一调用此函数。
%
% 用法:
%   epoch = mark_and_grab(trig, dataClient, code);
%   epoch = mark_and_grab(trig, dataClient, code, 'duration', 5);
%   epoch = mark_and_grab(trig, dataClient, code, ...
%                         'duration', 4, 'sampleRate', 500, 'wait', 0.5);
%
% 必需参数:
%   trig       : TriggerBox 对象 (来自 device_init)
%   dataClient : DataClient 对象 (来自 device_init)
%   code       : trigger 编号 (1-255 的整数)
%
% 可选参数(键值对):
%   'duration'   截取多少秒数据(从当前往前数), 默认 2
%   'sampleRate' 采样率(Hz), 默认 500
%   'wait'       打完 trigger 后等多少秒再取数据, 默认 0.5
%                (留时间给信号稳定 + 让 trigger 落进截取窗口)
%
% 返回:
%   epoch : nChan × nSamples 矩阵 (例如 65 × 2500 = 65 通道 × 5 秒)
%
% 时序示意:
%
%        打trigger     wait秒后取数据
%          |             |
%   ━━━━━━━╋━━━━━━━━━━━━╋━━━>  时间
%          ↑             ↑
%          这一刻贴标签   返回的数据是从这一点
%          (code 进入     往回数 duration 秒
%          EEG 数据流)
%
% =========================================================

%% ----- 1. 解析参数 -----
p = inputParser;
addParameter(p, 'duration',   2,   @isnumeric);
addParameter(p, 'sampleRate', 500, @isnumeric);
addParameter(p, 'wait',       0.5, @isnumeric);
parse(p, varargin{:});
opt = p.Results;

%% ----- 2. 打 trigger -----
% 这一行会立刻在 EEG 数据流里贴一个标签,
% 标签的值 = code, 后续离线分析时根据这个值找事件位置
trig.OutputEventData(code);

%% ----- 3. 等待信号稳定 -----
% 为什么要等? 两个原因:
%   1) TriggerBox 通过 USB 发标签到设备, 有几毫秒延迟,
%      等一下确保 trigger 已经进入缓冲区
%   2) 让"trigger 后那段感兴趣的脑电"流入缓冲区
pause(opt.wait);

%% ----- 4. 抓取整个缓冲区 -----
% GetBufferData 返回当前缓冲区中所有可用的数据,
% 形状是 [nChan × nSamples_in_buffer]
% (nChan 通常是 65: 64 EEG + 1 事件通道)
tempdata = dataClient.GetBufferData;

%% ----- 5. 从末尾截取指定时长 -----
nSamples_wanted = round(opt.duration * opt.sampleRate);

if isempty(tempdata)
    % 极端情况: 缓冲区为空(设备掉线/未启动)
    warning('mark_and_grab:EmptyBuffer', ...
            '缓冲区为空,返回空矩阵。请检查设备状态。');
    epoch = [];
    return;
end

if size(tempdata, 2) >= nSamples_wanted
    % 正常情况: 缓冲区数据够多, 取末尾 nSamples_wanted 个采样点
    epoch = tempdata(:, end-nSamples_wanted+1:end);
else
    % 异常情况: 缓冲区数据不够(可能 bufferSize 设太小)
    warning('mark_and_grab:NotEnoughData', ...
            '缓冲区只有 %d 个采样点, 不足 %d 个 (%.1f 秒). 返回全部缓冲区数据.', ...
            size(tempdata, 2), nSamples_wanted, opt.duration);
    epoch = tempdata;
end

end
