function main()
% MAIN  疲劳监测系统 主界面 (v2.0)
% =========================================================
% v2 改动:
%   - 把 showLiveScore 参数从 paramStore 传给 run_pvt
%   - paramStore.PVT 新增 showLiveScore 字段
% =========================================================

%% ----- 路径 -----
this_file    = mfilename('fullpath');
project_root = fileparts(this_file);
addpath(genpath(project_root));

%% ----- 配色 -----
COLOR_BG       = [0.96 0.96 0.97];
COLOR_PANEL    = [1 1 1];
COLOR_SECTION  = [0.94 0.94 0.95];
COLOR_TXT_HINT = [0.55 0.55 0.55];
COLOR_TXT_SUB  = [0.40 0.40 0.40];
COLOR_BTN_BG   = [0.99 0.99 0.99];
COLOR_ANALYSIS = [0.85 0.93 1.00];
COLOR_BROWSE   = [0.92 0.92 0.94];
COLOR_PVT      = [1.00 0.93 0.85];

%% ----- 窗口 -----
WIN_W = 1200; WIN_H = 700;
ss = get(0,'ScreenSize');
winX = max(20, round((ss(3)-WIN_W)/2));
winY = max(20, round((ss(4)-WIN_H)/2));
hFig = uifigure('Name','疲劳监测系统','Position',[winX winY WIN_W WIN_H], ...
                'Resize','off','Color',COLOR_BG);

%% ----- 参数库 -----
paramStore = struct();
paramStore.Baseline    = struct('eyesOpenDur',60,'eyesCloseDur',60);
paramStore.PVT         = struct('durationMin',10,'isiMin',2,'isiMax',10, ...
                                 'showLiveScore',false, ...
                                 'adaptiveISI',false, ...
                                 'signalQualityCheck',false);
paramStore.FatigueTest = struct('eyesOpenDur',60,'eyesCloseDur',60);

%% ----- 顶部 -----
uilabel(hFig,'Text','疲劳监测系统','Position',[25 658 400 28], ...
    'FontSize',20,'FontWeight','bold');
uilabel(hFig,'Text','v3.0 · 自适应 ISI + 信号质量监控','Position',[25 635 350 20], ...
    'FontSize',11,'FontColor',COLOR_TXT_HINT);
uilamp(hFig,'Position',[850 660 14 14],'Color',[0.70 0.70 0.70]);
uilabel(hFig,'Text','设备未连接','Position',[872 658 100 18], ...
    'FontSize',11,'FontColor',COLOR_TXT_HINT);
uipanel(hFig,'Position',[25 625 950 1],'BorderType','none', ...
    'BackgroundColor',[0.85 0.85 0.87]);

%% ----- 被试信息 -----
pInfo = uipanel(hFig,'Position',[25 515 950 100],'BorderType','none', ...
    'BackgroundColor',COLOR_SECTION);
uilabel(pInfo,'Text','被试信息','Position',[18 72 100 18], ...
    'FontSize',12,'FontWeight','bold','FontColor',COLOR_TXT_SUB);
fields = {'编号',18,240; '分组',278,240; '年龄',538,130; '性别',688,240};
for i=1:size(fields,1)
    uilabel(pInfo,'Text',fields{i,1},'Position',[fields{i,2},44,60,18], ...
        'FontSize',11,'FontColor',COLOR_TXT_HINT);
end
hSubjectName = uieditfield(pInfo,'text','Value','sub01', ...
    'Position',[fields{1,2},13,fields{1,3},28]);
hSubjectLabel = uidropdown(pInfo,'Items',{'normal (正常)','sleep_deprived (睡眠剥夺)','patient (患者)'}, ...
    'Value','normal (正常)','Position',[fields{2,2},13,fields{2,3},28]);
hSubjectAge = uieditfield(pInfo,'numeric','Value',22,'Limits',[0 120], ...
    'Position',[fields{3,2},13,fields{3,3},28]);
hSubjectGender = uidropdown(pInfo,'Items',{'M','F'},'Value','M', ...
    'Position',[fields{4,2},13,fields{4,3},28]);

%% ----- 任务区标题 -----
uilabel(hFig,'Text','实验任务','Position',[25 485 200 18], ...
    'FontSize',12,'FontWeight','bold','FontColor',COLOR_TXT_SUB);
uilabel(hFig,'Text','推荐流程: 基线 → PVT → 疲劳再测 → 分析对比', ...
    'Position',[400 485 575 18],'FontSize',11,'FontColor',COLOR_TXT_HINT, ...
    'HorizontalAlignment','right');

%% ----- 3 个任务按钮 -----
btnW = 308; btnH = 130; gapX = 13;
startX = 25; startY = 340;
tasks = {
    '①','基线静息','Baseline';
    '②','PVT 持续注意','PVT';
    '③','疲劳再测','FatigueTest';
};
hTaskBtns = gobjects(3,1);
hGearBtns = gobjects(3,1);

for i=1:3
    icon=tasks{i,1}; ttl=tasks{i,2}; tag=tasks{i,3};
    x = startX + (i-1)*(btnW+gapX);
    if strcmp(tag,'PVT'), bgc = COLOR_PVT; else, bgc = COLOR_BTN_BG; end
    sub = describeParams(tag, paramStore);
    btn_text = sprintf('%s\n%s\n%s', icon, ttl, sub);
    hTaskBtns(i) = uibutton(hFig,'Text',btn_text, ...
        'Position',[x startY btnW btnH],'FontSize',14, ...
        'BackgroundColor',bgc,'Tag',tag, ...
        'ButtonPushedFcn',@(s,e) on_task_click(tag));
    if ~strcmp(tag,'FatigueTest')
        hGearBtns(i) = uibutton(hFig,'Text','⚙', ...
            'Position',[x+btnW-32 startY+btnH-28 24 24],'FontSize',12, ...
            'BackgroundColor',bgc,'Tag',['gear_' tag], ...
            'ButtonPushedFcn',@(s,e) on_gear_click(tag));
    end
end

%% ----- 开关行 -----
hUseMock = uicheckbox(hFig,'Text','使用模拟设备 (测试)', ...
    'Position',[25 280 180 22],'FontSize',12,'Value',true);
hSyntheticEEG = uicheckbox(hFig,'Text','+ 伪 EEG (α/θ 节律)', ...
    'Position',[215 280 200 22],'FontSize',12,'Value',true, ...
    'FontColor',[0.30 0.55 0.30]);
hBrowseBtn = uibutton(hFig,'Text','📁 数据浏览', ...
    'Position',[435 277 110 28],'FontSize',11,'BackgroundColor',COLOR_BROWSE, ...
    'ButtonPushedFcn',@(s,e) on_browse_click());
hAnalyzeBtn = uibutton(hFig,'Text','📊 分析数据', ...
    'Position',[555 277 110 28],'FontSize',12,'FontWeight','bold', ...
    'BackgroundColor',COLOR_ANALYSIS,'ButtonPushedFcn',@(s,e) on_analyze_click());
hCountLabel = uilabel(hFig,'Text','今日完成: 0 次', ...
    'Position',[790 280 185 22],'FontSize',12,'FontColor',COLOR_TXT_SUB, ...
    'HorizontalAlignment','right');

%% ----- 状态栏 -----
uilabel(hFig,'Text','状态日志','Position',[25 245 200 18], ...
    'FontSize',12,'FontWeight','bold','FontColor',COLOR_TXT_SUB);
hStatusText = uitextarea(hFig, ...
    'Value',{'就绪';'推荐: 先做基线, 再做 PVT 诱发疲劳, 最后疲劳再测'}, ...
    'Position',[25 25 950 215],'Editable','off','FontSize',11, ...
    'FontName','Consolas','BackgroundColor',COLOR_PANEL);

appState.todayCount = 0;

%% ----- 任务回调 -----
function on_task_click(tag)
    name = strtrim(hSubjectName.Value);
    if isempty(name)
        uialert(hFig,'被试编号不能为空','提示'); return;
    end
    labelParts = split(hSubjectLabel.Value,' ');
    label = labelParts{1};
    age = hSubjectAge.Value;
    gender = hSubjectGender.Value;
    useMock = hUseMock.Value;
    syntheticEEG = hSyntheticEEG.Value;

    switch tag
        case 'Baseline',    paradigmName = 'Baseline';
        case 'PVT',         paradigmName = 'PVT';
        case 'FatigueTest', paradigmName = 'FatigueTest';
    end

    try
        info = info_from_gui(name,label,age,gender,paradigmName);
    catch ME
        uialert(hFig,sprintf('被试信息有误: %s',ME.message),'错误'); return;
    end

    p = paramStore.(tag);
    if useMock
        if syntheticEEG, modeStr='Mock + 伪 EEG'; else, modeStr='Mock 纯噪声'; end
    else
        modeStr='真实设备';
    end

    log_msg(sprintf('[%s] 启动 %s [%s]', datestr(now,'HH:MM:SS'), tag, modeStr));
    log_msg(sprintf('    参数: %s', describeParams(tag, paramStore)));
    log_msg(sprintf('    被试: %s | %s | %d岁 %s', info.name, info.label, info.age, info.gender));

    hFig.Visible = 'off';
    hFig.WindowState = 'minimized';
    drawnow; pause(0.3);

    result=[]; err_msg='';
    try
        switch tag
            case 'Baseline'
                result = run_baseline('useMock',useMock,'info',info, ...
                    'syntheticEEG',syntheticEEG, ...
                    'eyesOpenDur',p.eyesOpenDur,'eyesCloseDur',p.eyesCloseDur, ...
                    'phase','baseline');
            case 'PVT'
                result = run_pvt('useMock',useMock,'info',info, ...
                    'syntheticEEG',syntheticEEG, ...
                    'durationMin',p.durationMin,'isiMin',p.isiMin,'isiMax',p.isiMax, ...
                    'showLiveScore',p.showLiveScore, ...
                    'adaptiveISI',p.adaptiveISI, ...
                    'signalQualityCheck',p.signalQualityCheck);
            case 'FatigueTest'
                result = run_fatigue_test('useMock',useMock,'info',info, ...
                    'syntheticEEG',syntheticEEG, ...
                    'eyesOpenDur',p.eyesOpenDur,'eyesCloseDur',p.eyesCloseDur);
        end
    catch ME
        if isempty(ME.stack)
            err_msg = ME.message;
        else
            err_msg = sprintf('%s\n位置: %s 第 %d 行', ME.message, ME.stack(1).name, ME.stack(1).line);
        end
    end

    if isvalid(hFig)
        hFig.WindowState='normal'; hFig.Visible='on'; figure(hFig);
    end

    if ~isempty(err_msg)
        log_msg(sprintf('  ✗ 出错: %s', err_msg));
        log_msg('---');
        uialert(hFig, err_msg, '实验出错'); return;
    end
    if isempty(result)
        log_msg('  ✗ 未返回数据'); log_msg('---'); return;
    end

    appState.todayCount = appState.todayCount + 1;
    hCountLabel.Text = sprintf('今日完成: %d 次', appState.todayCount);
    log_msg(sprintf('  ✓ 完成: %s', result.save_path));
    log_msg('---');
end

function on_gear_click(tag)
    switch tag
        case 'Baseline', newP = params_baseline(paramStore.Baseline);
        case 'PVT',      newP = params_pvt(paramStore.PVT);
        otherwise,       newP = [];
    end
    if ~isempty(newP)
        paramStore.(tag) = newP;
        if strcmp(tag,'Baseline')
            paramStore.FatigueTest = struct( ...
                'eyesOpenDur', newP.eyesOpenDur, ...
                'eyesCloseDur', newP.eyesCloseDur);
            refreshButtonText('FatigueTest');
        end
        refreshButtonText(tag);
        log_msg(sprintf('[%s] %s 参数已更新: %s', ...
                datestr(now,'HH:MM:SS'), tag, describeParams(tag, paramStore)));
    else
        log_msg(sprintf('[%s] %s 参数未改动', datestr(now,'HH:MM:SS'), tag));
    end
end

function on_browse_click()
    data_dir = fullfile(project_root,'data');
    if ~exist(data_dir,'dir'), mkdir(data_dir); end
    log_msg(sprintf('[%s] 打开数据目录', datestr(now,'HH:MM:SS')));
    try, winopen(data_dir); catch, log_msg('  ⚠ winopen 失败'); end
end

function on_analyze_click()
    log_msg(sprintf('[%s] 启动分析窗口', datestr(now,'HH:MM:SS')));
    try
        analysis_gui();
    catch ME
        log_msg(sprintf('  ✗ 分析窗口启动失败: %s', ME.message));
        uialert(hFig, sprintf('分析窗口启动失败:\n%s', ME.message), '错误');
    end
end

function refreshButtonText(tag)
    for k=1:3
        if strcmp(hTaskBtns(k).Tag, tag)
            switch tag
                case 'Baseline',    icon='①'; ttl='基线静息';
                case 'PVT',         icon='②'; ttl='PVT 持续注意';
                case 'FatigueTest', icon='③'; ttl='疲劳再测';
            end
            sub = describeParams(tag, paramStore);
            hTaskBtns(k).Text = sprintf('%s\n%s\n%s', icon, ttl, sub);
            break;
        end
    end
end

function log_msg(msg)
    current = hStatusText.Value;
    if ischar(current), current = {current}; end
    if ~iscell(current), current = cellstr(current); end
    new_lines = [{char(msg)}; current];
    if length(new_lines) > 100, new_lines = new_lines(1:100); end
    hStatusText.Value = new_lines;
    drawnow;
end

log_msg('---');
log_msg(sprintf('[%s] 疲劳监测系统启动 v3.0', datestr(now,'HH:MM:SS')));
log_msg('★ v3 新增: 自适应 ISI + 实时信号质量监控');
log_msg('推荐流程: ①基线 → ②PVT(诱发疲劳) → ③疲劳再测 → 分析对比');
log_msg('---');

end


% =========================================================
function s = describeParams(tag, store)
    switch tag
        case 'Baseline'
            p = store.Baseline;
            s = sprintf('睁眼 %d 秒 + 闭眼 %d 秒', p.eyesOpenDur, p.eyesCloseDur);
        case 'PVT'
            p = store.PVT;
            extras = {};
            if p.showLiveScore, extras{end+1} = '疲劳分'; end
            if p.adaptiveISI, extras{end+1} = '★自适应'; end
            if p.signalQualityCheck, extras{end+1} = '★质量'; end
            if isempty(extras)
                extra = '';
            else
                extra = [' [' strjoin(extras,'+') ']'];
            end
            s = sprintf('%d 分钟 · ISI %d-%d 秒%s', p.durationMin, p.isiMin, p.isiMax, extra);
        case 'FatigueTest'
            p = store.FatigueTest;
            s = sprintf('睁眼 %d 秒 + 闭眼 %d 秒', p.eyesOpenDur, p.eyesCloseDur);
        otherwise
            s = '';
    end
end
