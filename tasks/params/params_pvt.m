function newParams = params_pvt(currentParams)
% PARAMS_PVT v3  PVT 参数对话框
% v3 新增:
%   - "★ 启用自适应 ISI" 开关 (方向 1: 自适应难度)
%   - "★ 启用实时信号质量监控" 开关 (方向 3)
%   - "实时显示疲劳分" (v2 已有)
% =========================================================

%% 默认值
defaults.durationMin       = 10;
defaults.isiMin            = 2;
defaults.isiMax            = 10;
defaults.showLiveScore     = false;     % v2
defaults.adaptiveISI       = false;     % v3 ★ 自适应 ISI
defaults.signalQualityCheck = false;    % v3 ★ 实时信号质量

if isempty(currentParams)
    p = defaults;
else
    p = defaults;
    f = fieldnames(defaults);
    for i = 1:length(f)
        if isfield(currentParams, f{i})
            p.(f{i}) = currentParams.(f{i});
        end
    end
end

COLOR_BG       = [0.96 0.96 0.97];
COLOR_TXT_SUB  = [0.40 0.40 0.40];
COLOR_TXT_HINT = [0.55 0.55 0.55];

dlg = uifigure('Name','PVT 参数','Position',[200 200 520 560], ...
               'Resize','off','Color',COLOR_BG,'WindowStyle','modal');

uilabel(dlg,'Text','PVT 持续注意 - 参数设置 (v3)', ...
    'Position',[25 515 430 28],'FontSize',16,'FontWeight','bold');
uilabel(dlg,'Text','★ 创新功能用暖色背景, 默认关闭', ...
    'Position',[25 495 430 18],'FontSize',11,'FontColor',COLOR_TXT_HINT);
uipanel(dlg,'Position',[25 485 430 1],'BorderType','none', ...
    'BackgroundColor',[0.85 0.85 0.87]);

%% 基础参数 -----------
uilabel(dlg,'Text','【基础参数】','Position',[25 458 200 18], ...
    'FontSize',12,'FontColor',COLOR_TXT_SUB,'FontWeight','bold');

uilabel(dlg,'Text','任务总时长 (分钟)', ...
    'Position',[25 432 200 18],'FontSize',12,'FontColor',COLOR_TXT_SUB);
hDur = uispinner(dlg,'Value',p.durationMin,'Limits',[1 30],'Step',1, ...
    'RoundFractionalValues','on','Position',[25 405 430 28],'FontSize',12);

uilabel(dlg,'Text','刺激最短间隔 (秒)', ...
    'Position',[25 378 200 18],'FontSize',12,'FontColor',COLOR_TXT_SUB);
hIsiMin = uispinner(dlg,'Value',p.isiMin,'Limits',[1 8],'Step',1, ...
    'RoundFractionalValues','on','Position',[25 351 200 28],'FontSize',12);

uilabel(dlg,'Text','刺激最长间隔 (秒)', ...
    'Position',[240 378 200 18],'FontSize',12,'FontColor',COLOR_TXT_SUB);
hIsiMax = uispinner(dlg,'Value',p.isiMax,'Limits',[3 15],'Step',1, ...
    'RoundFractionalValues','on','Position',[240 351 215 28],'FontSize',12);

%% v3 ★ 创新功能 1: 自适应 ISI ----------
pAdapt = uipanel(dlg,'Position',[25 245 430 92], ...
    'BorderType','line','BackgroundColor',[1.00 0.95 0.85]);
uilabel(pAdapt,'Text','【★ 自适应 ISI】(功能 1)', ...
    'Position',[10 65 400 18],'FontSize',12,'FontColor',[0.50 0.30 0.10], ...
    'FontWeight','bold');
hAdaptiveISI = uicheckbox(pAdapt,'Text','启用自适应 ISI (根据反应表现动态调难度)', ...
    'Position',[10 36 400 22],'FontSize',12,'Value',p.adaptiveISI);
uilabel(pAdapt,'Text','反应慢 → 缩短 ISI (加大难度)  反应快 → 延长 ISI', ...
    'Position',[10 16 400 18],'FontSize',10,'FontColor',COLOR_TXT_HINT);
uilabel(pAdapt,'Text','基于最近 5 个 trial 的反应时变异系数 CV', ...
    'Position',[10 0 400 18],'FontSize',10,'FontColor',COLOR_TXT_HINT);

%% v3 ★ 创新功能 2: 信号质量监控 ----------
pSQ = uipanel(dlg,'Position',[25 145 430 92], ...
    'BorderType','line','BackgroundColor',[0.85 0.95 1.00]);
uilabel(pSQ,'Text','【★ 实时信号质量监控】(功能 2)', ...
    'Position',[10 65 400 18],'FontSize',12,'FontColor',[0.10 0.30 0.55], ...
    'FontWeight','bold');
hSQCheck = uicheckbox(pSQ,'Text','启用实时 EEG 信号质量监控', ...
    'Position',[10 36 400 22],'FontSize',12,'Value',p.signalQualityCheck);
uilabel(pSQ,'Text','屏幕角落显示质量分 (绿/黄/红)', ...
    'Position',[10 16 400 18],'FontSize',10,'FontColor',COLOR_TXT_HINT);
uilabel(pSQ,'Text','低质量时段自动打标记到数据, 方便事后清洗', ...
    'Position',[10 0 400 18],'FontSize',10,'FontColor',COLOR_TXT_HINT);

%% v2 实时显示疲劳分 ----------
hLiveScore = uicheckbox(dlg,'Text','实时显示疲劳分(屏幕角落, 0-1)', ...
    'Position',[25 110 430 22],'FontSize',12,'Value',p.showLiveScore, ...
    'FontColor',[0.50 0.40 0.20]);

%% 预览
hTotal = uilabel(dlg,'Text',computeTotal(p), ...
    'Position',[25 75 430 22],'FontSize',12,'FontWeight','bold', ...
    'FontColor',[0.20 0.50 0.30],'HorizontalAlignment','center');

hDur.ValueChangedFcn    = @(s,e) updateTotal();
hIsiMin.ValueChangedFcn = @(s,e) updateTotal();
hIsiMax.ValueChangedFcn = @(s,e) updateTotal();

%% 按钮
uibutton(dlg,'Text','保存','Position',[275 20 80 30],'FontSize',12, ...
    'BackgroundColor',[0.85 0.93 0.85],'ButtonPushedFcn',@(s,e) onSave());
uibutton(dlg,'Text','取消','Position',[365 20 80 30],'FontSize',12, ...
    'ButtonPushedFcn',@(s,e) onCancel());
uibutton(dlg,'Text','恢复默认','Position',[25 20 90 30],'FontSize',11, ...
    'ButtonPushedFcn',@(s,e) onReset());

newParams = [];
uiwait(dlg);

    function updateTotal()
        cur.durationMin = round(hDur.Value);
        cur.isiMin = round(hIsiMin.Value);
        cur.isiMax = round(hIsiMax.Value);
        if cur.isiMin >= cur.isiMax
            hTotal.Text = '⚠ 最短间隔必须小于最长间隔';
            hTotal.FontColor = [0.8 0.3 0.3];
        else
            hTotal.Text = computeTotal(cur);
            hTotal.FontColor = [0.20 0.50 0.30];
        end
    end

    function onSave()
        if round(hIsiMin.Value) >= round(hIsiMax.Value)
            uialert(dlg, '最短间隔必须小于最长间隔', '参数错误');
            return;
        end
        newParams = struct( ...
            'durationMin',         round(hDur.Value), ...
            'isiMin',              round(hIsiMin.Value), ...
            'isiMax',              round(hIsiMax.Value), ...
            'showLiveScore',       hLiveScore.Value, ...
            'adaptiveISI',         hAdaptiveISI.Value, ...
            'signalQualityCheck',  hSQCheck.Value);
        uiresume(dlg); delete(dlg);
    end

    function onCancel()
        newParams = [];
        uiresume(dlg); delete(dlg);
    end

    function onReset()
        hDur.Value         = defaults.durationMin;
        hIsiMin.Value      = defaults.isiMin;
        hIsiMax.Value      = defaults.isiMax;
        hLiveScore.Value   = defaults.showLiveScore;
        hAdaptiveISI.Value = defaults.adaptiveISI;
        hSQCheck.Value     = defaults.signalQualityCheck;
        updateTotal();
    end
end

function s = computeTotal(p)
    avgIsi = (p.isiMin + p.isiMax)/2 + 0.8;
    nTrials = round(p.durationMin * 60 / avgIsi);
    s = sprintf('约 %d 分钟 · 预计 %d trial', p.durationMin, nTrials);
end
