function [dataClient, trig, cfg] = device_init(varargin)
% DEVICE_INIT  启动设备 (真博瑞康 或 Mock 模拟器)
% =========================================================
% v2 改动:
%   - 新增 'syntheticEEG' 参数, 只在 Mock 模式下生效
%   - 真模式下此参数被忽略(因为真设备的数据就是真的)
%
% 完整用法见函数体注释。
% =========================================================

%% ----- 1. 解析参数 -----
p = inputParser;
addParameter(p, 'ipAddress',  '127.0.0.1',              @ischar);
addParameter(p, 'serverPort', 8712,                     @isnumeric);
addParameter(p, 'nChan',      65,                       @isnumeric);
addParameter(p, 'sampleRate', 500,                      @isnumeric);
addParameter(p, 'bufferSize', 50,                       @isnumeric);
addParameter(p, 'sdkPath',    'D:\experient\neracle64\', @ischar);
addParameter(p, 'maxRetry',   3,                        @isnumeric);
% --- v2 新增 ---
addParameter(p, 'useMock',      false, @islogical);
addParameter(p, 'syntheticEEG', false, @islogical);
parse(p, varargin{:});
cfg = p.Results;

%% ----- 2. Mock 模式 -----
if cfg.useMock
    dataClient = MockDataClient(cfg.ipAddress, cfg.serverPort, ...
                                cfg.nChan, cfg.sampleRate, cfg.bufferSize);
    dataClient.syntheticEEG = cfg.syntheticEEG;
    dataClient.Open;

    trig = MockTriggerBox();

    if cfg.syntheticEEG
        fprintf('[设备] Mock 模式 (伪 EEG) | 采样率 %d Hz | %d 通道\n', ...
                cfg.sampleRate, cfg.nChan);
    else
        fprintf('[设备] Mock 模式 (纯噪声) | 采样率 %d Hz | %d 通道\n', ...
                cfg.sampleRate, cfg.nChan);
    end
    return;
end

%% ----- 3. 真实模式 (原有逻辑) -----
if exist(cfg.sdkPath, 'dir')
    addpath(cfg.sdkPath);
else
    warning('device_init:SDKPathMissing', ...
            'SDK 路径不存在: %s', cfg.sdkPath);
end

dataClient = [];
for attempt = 1:cfg.maxRetry
    try
        fprintf('[设备] 第 %d/%d 次连接 ... ', attempt, cfg.maxRetry);
        dataClient = DataClient(cfg.ipAddress, cfg.serverPort, ...
                                cfg.nChan, cfg.sampleRate, cfg.bufferSize);
        dataClient.Open;
        pause(1);
        tempdata = dataClient.GetBufferData;
        if numel(tempdata) > 0
            fprintf('成功 ✓\n');
            break;
        else
            fprintf('缓冲区为空\n');
            try, dataClient.Close; catch, end
            dataClient = [];
        end
    catch ME
        fprintf('失败: %s\n', ME.message);
        try, dataClient.Close; catch, end
        dataClient = [];
        if attempt < cfg.maxRetry, pause(2); end
    end
end

if isempty(dataClient)
    error('device_init:ConnectFailed', ...
        ['无法连接到脑电设备。请检查:\n', ...
         '  1. NeurOne64 主机开机\n', ...
         '  2. NeurOne 软件已 Start 传输\n', ...
         '  3. IP/端口 (%s:%d) 正确'], ...
         cfg.ipAddress, cfg.serverPort);
end

try
    trig = TriggerBox();
    fprintf('[标签] TriggerBox 启动 ✓\n');
catch ME
    try, dataClient.Close; catch, end
    error('device_init:TriggerBoxFailed', ...
          'TriggerBox 启动失败: %s', ME.message);
end

fprintf('[设备] 采样率 %d Hz | 通道 %d | 缓冲 %d 秒\n', ...
        cfg.sampleRate, cfg.nChan, cfg.bufferSize);

end
