function result = run_pvt(varargin)
% RUN_PVT v3  PVT 持续注意 (含创新功能)
% =========================================================
% v3 改动:
%   ★ 自适应 ISI: 根据最近 5 个 trial 的 RT 变异性自动调整 ISI 范围
%     - 反应稳定 → ISI 区间不变
%     - 反应变异大 → 缩短 ISI (加大难度, 加速诱发疲劳)
%     - 反应过快 (注意力过高) → 延长 ISI (放松要求)
%   ★ 实时信号质量监控: 屏幕角落显示 EEG 质量分 (绿/黄/红)
%     - 自动标记低质量时段
% 保留 v2: 实时疲劳分显示
% =========================================================

%% ----- 参数 -----
p = inputParser;
addParameter(p, 'durationMin',        10,    @isnumeric);
addParameter(p, 'isiMin',             2,     @isnumeric);
addParameter(p, 'isiMax',             10,    @isnumeric);
addParameter(p, 'maxRespTime',        1.0,   @isnumeric);
addParameter(p, 'lapseThresh',        0.5,   @isnumeric);
addParameter(p, 'showLiveScore',      false, @islogical);
addParameter(p, 'adaptiveISI',        false, @islogical);   % v3
addParameter(p, 'signalQualityCheck', false, @islogical);   % v3
addParameter(p, 'useMock',            false, @islogical);
addParameter(p, 'syntheticEEG',       false, @islogical);
addParameter(p, 'info',               [],    @(x) isstruct(x) || isempty(x));
parse(p, varargin{:});
opt = p.Results;

%% ----- 被试信息 -----
if isempty(opt.info)
    info = subject_info('PVT');
else
    info = opt.info;
    info.paradigm = 'PVT';
    this_file    = mfilename('fullpath');
    tasks_dir    = fileparts(this_file);
    project_root = fileparts(tasks_dir);
    base_dir = fullfile(project_root, 'data', info.name, 'PVT');
    if ~exist(base_dir, 'dir'), mkdir(base_dir); end
    info.save_dir = base_dir;
    info.save_prefix = sprintf('%s_PVT_%s', info.name, info.timestamp);
end

totalSec = opt.durationMin * 60;

% 打印启动 banner (含创新功能开关状态)
fprintf('\n[PVT v3] 启动\n');
fprintf('  时长: %.1f 分钟, ISI: %.0f-%.0f 秒\n', ...
        opt.durationMin, opt.isiMin, opt.isiMax);
fprintf('  ★ 自适应 ISI: %s\n', onoff(opt.adaptiveISI));
fprintf('  ★ 信号质量监控: %s\n', onoff(opt.signalQualityCheck));
fprintf('  实时疲劳分: %s\n\n', onoff(opt.showLiveScore));

%% ----- 启动设备 -----
buf_size = max(60, ceil(totalSec * 1.3));
[dataClient, trig, cfg] = device_init('useMock', opt.useMock, ...
    'bufferSize', buf_size, 'syntheticEEG', opt.syntheticEEG);
fs = cfg.sampleRate;

%% ----- Trigger -----
TRIG_STIM     = 10;
TRIG_RESPONSE = 20;
TRIG_LAPSE    = 30;
TRIG_BAD_QUAL = 40;   % v3: 低质量时段标记
TRIG_START    = 100;
TRIG_END      = 101;

%% ----- 状态 -----
keyEvents    = {};
expStart     = [];
cueTimer     = [];
currentTrial = 0;
waitingResp  = false;

% v3: 自适应 ISI 历史
isiHistory       = [];   % 记录每个 trial 实际用的 ISI
isiAdaptHistory  = struct('trial',{},'origRange',{},'adaptRange',{},'reason',{});
recentRTs        = [];   % 最近 5 个反应时

% v3: 信号质量历史
qualityHistory   = struct('time',{},'score',{},'level',{});

% v2: 疲劳分历史
rtHistory     = [];
onsetHistory  = [];
liveWindowSec = 60;

%% ----- 主流程 -----
hFig = [];
trials = struct('onset',{},'rt',{},'responded',{},'isLapse',{}, ...
                'usedIsi',{},'sqAtStim',{});

try
    hFig = uifigure('Name','PVT v3','Color','black', ...
                    'WindowState','fullscreen', ...
                    'HandleVisibility','off');
    set(hFig,'KeyPressFcn',@on_key_press);

    % 指导语
    show_text(hFig,'持续注意任务 (PVT)','FontSize',60,'Color','white','Y',0.7);
    show_text(hFig,'看到红色数字立刻按 空格键', ...
        'FontSize',40,'Color','yellow','Y',0.55,'Mode','overlay');
    extraY = 0.42;
    if opt.adaptiveISI
        show_text(hFig,'★ 系统会根据您的反应自动调整难度', ...
            'FontSize',26,'Color',[0.95 0.75 0.4],'Y',extraY,'Mode','overlay');
        extraY = extraY - 0.06;
    end
    if opt.signalQualityCheck
        show_text(hFig,'★ 屏幕右上角显示信号质量(绿/黄/红)', ...
            'FontSize',26,'Color',[0.6 0.8 1.0],'Y',extraY,'Mode','overlay');
        extraY = extraY - 0.06;
    end
    if opt.showLiveScore
        show_text(hFig,'★ 屏幕左下角显示当前疲劳分', ...
            'FontSize',26,'Color',[0.9 0.7 0.3],'Y',extraY,'Mode','overlay');
    end
    show_text(hFig,'按 空格 开始','FontSize',36,'Color','cyan','Y',0.08,'Mode','overlay');
    wait_for_key(hFig,'space');
    set(hFig,'KeyPressFcn',@on_key_press);

    % 开始
    trig.OutputEventData(TRIG_START);
    expStart = tic;
    trialNum = 0;

    % 当前 ISI 范围 (自适应会改这两个)
    curIsiMin = opt.isiMin;
    curIsiMax = opt.isiMax;

    while toc(expStart) < totalSec
        trialNum = trialNum + 1;
        currentTrial = trialNum;

        % ====== v3: 自适应 ISI ======
        if opt.adaptiveISI && length(recentRTs) >= 5
            [curIsiMin, curIsiMax, reason] = adapt_isi( ...
                recentRTs(end-4:end), opt.isiMin, opt.isiMax);
            isiAdaptHistory(end+1).trial      = trialNum;
            isiAdaptHistory(end).origRange   = [opt.isiMin, opt.isiMax];
            isiAdaptHistory(end).adaptRange  = [curIsiMin, curIsiMax];
            isiAdaptHistory(end).reason       = reason;
        end

        % 注视点
        show_fixation(hFig);

        % ====== v3: 信号质量检查 (每个 trial 一次) ======
        if opt.signalQualityCheck && opt.useMock
            % Mock 模式: 假数据, 质量分基本随机但偏高
            sqResult = mock_quality_for_test();
        elseif opt.signalQualityCheck
            % 真实设备: 从 dataClient 拿最近 2 秒数据评估
            % 注意: dataClient.GetBufferData 会清空缓存, 不能在主流程外频繁调用
            % 这里只是"尝试性"读取, 真实部署可能需要更精细的接口
            try
                snapEEG = dataClient.GetBufferData;
                if ~isempty(snapEEG) && size(snapEEG,2) > fs
                    % 用最后 2 秒
                    nSamp = min(size(snapEEG,2), 2*fs);
                    sqResult = compute_signal_quality(snapEEG(:,end-nSamp+1:end), ...
                        'fs', fs);
                else
                    sqResult = struct('score',1,'color',[0.5 0.5 0.5], ...
                                      'level','unknown');
                end
            catch
                sqResult = struct('score',1,'color',[0.5 0.5 0.5],'level','unknown');
            end
        else
            sqResult = struct('score',NaN,'color',[],'level','disabled');
        end

        % 记录质量历史
        if opt.signalQualityCheck
            qualityHistory(end+1).time  = toc(expStart);
            qualityHistory(end).score   = sqResult.score;
            qualityHistory(end).level   = sqResult.level;
            % 标记低质量时段
            if strcmp(sqResult.level, 'bad')
                trig.OutputEventData(TRIG_BAD_QUAL);
            end
        end

        % 用当前自适应后的 ISI 范围
        isi = curIsiMin + rand * (curIsiMax - curIsiMin);
        if toc(expStart) + isi + opt.maxRespTime > totalSec, break; end
        pause(isi);

        % 刺激出现
        waitingResp = true;
        cueTimer = tic;
        onsetTime = toc(expStart);
        trig.OutputEventData(TRIG_STIM);

        rt = NaN; responded = false;
        nKeyBefore = length(keyEvents);

        % 红色计时器
        clf(hFig);
        axTimer = axes('Parent',hFig,'Position',[0 0 1 1], ...
            'Visible','off','XLim',[0 1],'YLim',[0 1]);
        hTimerTxt = text(0.5,0.5,'0','Parent',axTimer, ...
            'FontSize',120,'Color','red', ...
            'HorizontalAlignment','center', ...
            'VerticalAlignment','middle','FontWeight','bold');

        % 角落: 信号质量(右上)
        if opt.signalQualityCheck && ~isnan(sqResult.score)
            text(0.95,0.95, sprintf('信号:%.0f%%', sqResult.score*100), ...
                'Parent',axTimer,'FontSize',20,'Color',sqResult.color, ...
                'HorizontalAlignment','right','VerticalAlignment','top', ...
                'FontWeight','bold');
        end
        % 角落: 疲劳分(左下)
        if opt.showLiveScore
            sNow = compute_live_fatigue(rtHistory, onsetHistory, ...
                liveWindowSec, onsetTime);
            text(0.05,0.05, sprintf('疲劳:%.2f',sNow), 'Parent',axTimer, ...
                'FontSize',20,'Color',fatigue_color(sNow), ...
                'HorizontalAlignment','left','VerticalAlignment','bottom', ...
                'FontWeight','bold');
        end
        % 角落: 当前 ISI(右下, 调试用)
        if opt.adaptiveISI
            text(0.95,0.05, sprintf('ISI:%.1f-%.1fs', curIsiMin, curIsiMax), ...
                'Parent',axTimer,'FontSize',16,'Color',[0.95 0.75 0.4], ...
                'HorizontalAlignment','right','VerticalAlignment','bottom');
        end

        while toc(cueTimer) < opt.maxRespTime
            elapsedMs = toc(cueTimer) * 1000;
            if isvalid(hTimerTxt)
                hTimerTxt.String = sprintf('%d', round(elapsedMs));
            end
            drawnow;
            if length(keyEvents) > nKeyBefore
                lastEvt = keyEvents{end};
                if strcmp(lastEvt.key,'space')
                    rt = lastEvt.rt;
                    responded = true;
                    break;
                end
            end
            pause(0.005);
        end

        waitingResp = false;

        % 反馈
        if responded
            trig.OutputEventData(TRIG_RESPONSE);
            isLapse = rt > opt.lapseThresh;
            if isLapse, fbColor = [1 0.6 0]; else, fbColor = [0 1 0]; end
            show_text(hFig, sprintf('%d ms', round(rt*1000)), ...
                'FontSize',90,'Color',fbColor);
            % 更新自适应历史
            recentRTs(end+1) = rt;
            rtHistory(end+1) = rt;
            onsetHistory(end+1) = onsetTime;
            pause(0.6);
        else
            trig.OutputEventData(TRIG_LAPSE);
            isLapse = true;
            show_text(hFig,'请集中注意!','FontSize',70,'Color',[1 0.3 0.3]);
            % 漏报也算"反应慢", 用 maxRespTime 作为占位
            recentRTs(end+1) = opt.maxRespTime;
            pause(0.8);
        end

        % 保留最近 5 个
        if length(recentRTs) > 5
            recentRTs = recentRTs(end-4:end);
        end

        % 保存 trial
        trials(trialNum).onset     = onsetTime;
        trials(trialNum).rt        = rt;
        trials(trialNum).responded = responded;
        trials(trialNum).isLapse   = isLapse;
        trials(trialNum).usedIsi   = isi;
        trials(trialNum).sqAtStim  = sqResult.score;

        if mod(trialNum, 10) == 0
            fprintf('  trial %d, t=%.1f/%.0fs, ISI=[%.1f,%.1f]\n', ...
                trialNum, toc(expStart), totalSec, curIsiMin, curIsiMax);
        end

        clf(hFig);
    end

    trig.OutputEventData(TRIG_END);
    allEEG = dataClient.GetBufferData;
    fprintf('[PVT] 抓到 EEG: %d ch × %d 点 (%.1fs)\n', ...
        size(allEEG,1), size(allEEG,2), size(allEEG,2)/fs);

    show_text(hFig,'任务完成, 谢谢!','FontSize',64,'Color','white');
    pause(2.5);

catch ME
    if ~isempty(hFig) && isvalid(hFig), close(hFig); end
    try, dataClient.Close; catch, end
    rethrow(ME);
end

if isvalid(hFig), close(hFig); end
dataClient.Close;

%% ----- 保存 -----
result.info       = info;
result.options    = opt;
result.trials     = trials;
result.keyEvents  = keyEvents;
result.eeg        = allEEG;
result.sampleRate = fs;
result.nChan      = size(allEEG,1);

% v3: 创新功能产出
result.adaptiveISIHistory = isiAdaptHistory;
result.qualityHistory     = qualityHistory;

result.trigger.STIM     = TRIG_STIM;
result.trigger.RESPONSE = TRIG_RESPONSE;
result.trigger.LAPSE    = TRIG_LAPSE;
result.trigger.BAD_QUAL = TRIG_BAD_QUAL;
result.trigger.START    = TRIG_START;
result.trigger.END      = TRIG_END;

save_path = fullfile(info.save_dir, [info.save_prefix '.mat']);
save(save_path,'-struct','result');
result.save_path = save_path;

nResp = sum([trials.responded]);
fprintf('\n[PVT] ✓ 数据已保存: %s\n', save_path);
fprintf('  %d trial, %d 反应, %d 漏报\n', length(trials), nResp, length(trials)-nResp);
if opt.adaptiveISI
    fprintf('  ★ 自适应 ISI 触发次数: %d\n', length(isiAdaptHistory));
end
if opt.signalQualityCheck
    badN = sum(strcmp({qualityHistory.level},'bad'));
    fprintf('  ★ 信号质量记录 %d 次, 其中差的 %d 次\n', length(qualityHistory), badN);
end
fprintf('\n');

% ===========================================================
% 嵌套函数
% ===========================================================
    function on_key_press(~, evt)
        if isempty(expStart), return; end
        if isempty(cueTimer), rt_k = NaN;
        else, rt_k = toc(cueTimer);
        end
        evtStruct = record_key_event(evt.Key, rt_k, toc(expStart), ...
            'trial', currentTrial, ...
            'duringStim', waitingResp);
        keyEvents{end+1} = evtStruct;
    end
end


% =========================================================
% 自适应 ISI 算法 (核心创新)
% 输入: 最近 5 个 RT, 原 ISI 范围
% 输出: 新 ISI 范围, 触发原因
%
% 规则:
%   计算最近 5 个 RT 的变异系数 CV = std/mean
%   CV > 0.30 → 反应不稳定(疲劳) → 缩短 ISI 30%, 加大难度
%   CV < 0.10 → 反应稳定快 → 延长 ISI 20%, 减压
%   否则保持
% =========================================================
function [newMin, newMax, reason] = adapt_isi(recentRTs, baseMin, baseMax)
    cv = std(recentRTs) / mean(recentRTs);
    rangeWidth = baseMax - baseMin;
    midPoint = (baseMin + baseMax) / 2;

    if cv > 0.30
        % 反应不稳定 → 缩短 (难度上调)
        newRange = rangeWidth * 0.7;
        newMin = max(1, midPoint - newRange/2);
        newMax = midPoint + newRange/2;
        reason = sprintf('CV=%.2f >0.30, 加难', cv);
    elseif cv < 0.10
        % 反应过稳 → 延长 (减压)
        newRange = rangeWidth * 1.2;
        newMin = max(1, midPoint - newRange/2);
        newMax = midPoint + newRange/2;
        reason = sprintf('CV=%.2f <0.10, 减压', cv);
    else
        newMin = baseMin;
        newMax = baseMax;
        reason = sprintf('CV=%.2f 正常', cv);
    end
end


% =========================================================
% Mock 模式下的"伪信号质量分" (随机, 偏好)
% =========================================================
function q = mock_quality_for_test()
    s = 0.7 + 0.3 * rand;   % 0.7-1.0 之间
    if s > 0.7
        c = [0.4 0.9 0.4]; l = 'good';
    elseif s > 0.4
        c = [1.0 0.85 0.3]; l = 'caution';
    else
        c = [1.0 0.4 0.4]; l = 'bad';
    end
    q.score = s; q.color = c; q.level = l;
end


% =========================================================
% 实时疲劳分 (v2 逻辑保留)
% =========================================================
function score = compute_live_fatigue(rtHist, onsetHist, windowSec, nowSec)
    if length(rtHist) < 3, score = 0; return; end
    inWin = onsetHist >= (nowSec - windowSec);
    if sum(inWin) < 3, inWin = true(size(onsetHist)); end
    rtw = rtHist(inWin);
    cv_now = std(rtw) / mean(rtw);

    firstWin = onsetHist <= (onsetHist(1) + windowSec);
    if sum(firstWin) < 3
        cv_base = cv_now;
    else
        rtb = rtHist(firstWin);
        cv_base = std(rtb) / mean(rtb);
    end
    if cv_base < eps, score = 0; return; end
    delta = (cv_now - cv_base) / cv_base;
    if delta < 0, score = 0;
    elseif delta > 1, score = 1;
    else, score = delta;
    end
end


function color = fatigue_color(score)
    if score < 0.3, color = [0.4 0.9 0.4];
    elseif score < 0.5, color = [1.0 1.0 0.4];
    elseif score < 0.7, color = [1.0 0.6 0.2];
    else, color = [1.0 0.3 0.3];
    end
end


function s = onoff(b)
    if b, s = '开启'; else, s = '关闭'; end
end
