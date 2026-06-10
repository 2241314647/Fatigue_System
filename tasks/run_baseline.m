function result = run_baseline(varargin)
% RUN_BASELINE  基线静息任务 (疲劳监测系统)
% =========================================================
% 在 PVT 疲劳诱发任务"之前"运行, 记录被试清醒状态的 EEG 基线。
% 流程:
%   睁眼静息 (注视 +) → 闭眼静息 (文字提示闭眼)
% 提取清醒状态的 α/θ 功率, 作为后续疲劳对比的"参照点"。
%
% 用法:
%   result = run_baseline();                          % 默认参数
%   result = run_baseline('useMock', true);           % 测试
%   result = run_baseline('info', infoStruct, ...);   % 从 GUI 接被试信息
%
% 可选键值参数:
%   'eyesOpenDur'   睁眼时长(秒), 默认 60
%   'eyesCloseDur'  闭眼时长(秒), 默认 60
%   'useMock'       true=模拟设备, 默认 false
%   'syntheticEEG'  true=Mock 模式生成伪 EEG, 默认 false
%   'info'          从 GUI 收的被试信息结构体
%   'phase'         'baseline'(基线) 或 'fatigue'(疲劳再测), 默认 'baseline'
%                   仅影响保存的范式名, 数据格式完全一致
%
% 返回:
%   result.info         被试信息
%   result.options      参数
%   result.eeg          cell{1}=睁眼段, cell{2}=闭眼段
%   result.segType      {'eyes_open','eyes_closed'}
%   result.sampleRate
%   result.nChan
%   result.trigger      trigger 编码
%   result.save_path
%
% Trigger 编码:
%   1   睁眼静息开始
%   2   闭眼静息开始
%   100 任务结束
% =========================================================

%% ----- 1. 参数解析 -----
p = inputParser;
addParameter(p, 'eyesOpenDur',  60,    @isnumeric);
addParameter(p, 'eyesCloseDur', 60,    @isnumeric);
addParameter(p, 'useMock',      false, @islogical);
addParameter(p, 'syntheticEEG', false, @islogical);
addParameter(p, 'info',         [],    @(x) isstruct(x) || isempty(x));
addParameter(p, 'phase',        'baseline', @ischar);
parse(p, varargin{:});
opt = p.Results;

%% ----- 2. 被试信息 -----
% phase 决定保存的"范式名": baseline → Baseline, fatigue → FatigueTest
if strcmp(opt.phase, 'fatigue')
    paradigmName = 'FatigueTest';
else
    paradigmName = 'Baseline';
end

if isempty(opt.info)
    info = subject_info(paradigmName);
else
    info = opt.info;
    info.paradigm = paradigmName;   % 确保范式名正确
    % 重新生成保存目录(因为 phase 可能改变范式名)
    this_file    = mfilename('fullpath');
    tasks_dir    = fileparts(this_file);
    project_root = fileparts(tasks_dir);
    base_dir = fullfile(project_root, 'data', info.name, paradigmName);
    if ~exist(base_dir, 'dir'), mkdir(base_dir); end
    info.save_dir = base_dir;
    info.save_prefix = sprintf('%s_%s_%s', info.name, paradigmName, info.timestamp);
end

fprintf('\n[%s] 睁眼 %d 秒 + 闭眼 %d 秒\n', ...
        paradigmName, opt.eyesOpenDur, opt.eyesCloseDur);

%% ----- 3. 启动设备 -----
buf_size = max(50, ceil((opt.eyesOpenDur + opt.eyesCloseDur) * 1.3));
[dataClient, trig, cfg] = device_init('useMock',      opt.useMock, ...
                                       'bufferSize',   buf_size, ...
                                       'syntheticEEG', opt.syntheticEEG);
fs = cfg.sampleRate;

%% ----- 4. Trigger 编码 -----
TRIG_EYES_OPEN  = 1;
TRIG_EYES_CLOSE = 2;
TRIG_END        = 100;

%% ----- 5. 主流程 -----
hFig = [];
eeg_data = cell(2, 1);
segType  = {'eyes_open', 'eyes_closed'};

try
    % --- 建全屏窗口 ---
    hFig = uifigure('Name', paradigmName, ...
                    'Color', 'black', ...
                    'WindowState', 'fullscreen', ...
                    'HandleVisibility', 'off');

    % --- 指导语 ---
    if strcmp(opt.phase, 'fatigue')
        titleStr = '疲劳后基线测量';
    else
        titleStr = '清醒基线测量';
    end
    show_text(hFig, titleStr, 'FontSize', 64, 'Color', 'white', 'Y', 0.62);
    show_text(hFig, '接下来先睁眼注视屏幕中央十字', ...
              'FontSize', 38, 'Color', 'white', 'Y', 0.46, 'Mode', 'overlay');
    show_text(hFig, '请放松, 减少眨眼和身体移动', ...
              'FontSize', 34, 'Color', [0.7 0.7 0.7], 'Y', 0.36, 'Mode', 'overlay');
    show_text(hFig, '按 空格 开始', ...
              'FontSize', 36, 'Color', 'cyan', 'Y', 0.18, 'Mode', 'overlay');
    wait_for_key(hFig, 'space');

    % --- 睁眼静息 ---
    show_fixation(hFig);
    trig.OutputEventData(TRIG_EYES_OPEN);
    eeg_data{1} = mark_and_grab(trig, dataClient, TRIG_EYES_OPEN, ...
                                 'duration', opt.eyesOpenDur, ...
                                 'sampleRate', fs);

    % --- 闭眼提示 ---
    show_text(hFig, '请闭上眼睛', 'FontSize', 60, 'Color', 'white', 'Y', 0.58);
    show_text(hFig, '保持闭眼, 放松, 直到听到提示或屏幕变化', ...
              'FontSize', 34, 'Color', [0.7 0.7 0.7], 'Y', 0.42, 'Mode', 'overlay');
    pause(3);   % 给被试时间闭眼

    % --- 闭眼静息 ---
    trig.OutputEventData(TRIG_EYES_CLOSE);
    eeg_data{2} = mark_and_grab(trig, dataClient, TRIG_EYES_CLOSE, ...
                                 'duration', opt.eyesCloseDur, ...
                                 'sampleRate', fs);

    % --- 提示睁眼 + 结束 ---
    trig.OutputEventData(TRIG_END);
    show_text(hFig, '请睁开眼睛', 'FontSize', 60, 'Color', 'white', 'Y', 0.55);
    show_text(hFig, '本阶段结束, 谢谢', ...
              'FontSize', 40, 'Color', 'white', 'Y', 0.4, 'Mode', 'overlay');
    pause(2.5);

catch ME
    if ~isempty(hFig) && isvalid(hFig), close(hFig); end
    try, dataClient.Close; catch, end
    rethrow(ME);
end

%% ----- 6. 清理 -----
if isvalid(hFig), close(hFig); end
dataClient.Close;

%% ----- 7. 保存 -----
result.info       = info;
result.options    = opt;
result.eeg        = eeg_data;
result.segType    = segType;
result.sampleRate = fs;
result.nChan      = size(eeg_data{1}, 1);
result.trigger.EYES_OPEN  = TRIG_EYES_OPEN;
result.trigger.EYES_CLOSE = TRIG_EYES_CLOSE;
result.trigger.END        = TRIG_END;

save_path = fullfile(info.save_dir, [info.save_prefix '.mat']);
save(save_path, '-struct', 'result');
result.save_path = save_path;

fprintf('\n[%s] ✓ 数据已保存\n  路径: %s\n\n', paradigmName, save_path);

end
