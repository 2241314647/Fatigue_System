function analysis_gui()
% ANALYSIS_GUI v2  疲劳监测分析窗口
% 4 种分析:
%   1. PVT 行为分析 (含变异性 + 早期预警)
%   2. EEG 疲劳指标 (单次)
%   3. 基线 vs 疲劳 对比 (含个性化归一化)
%   4. ★ 综合疲劳评分 (创新核心)
% =========================================================

%% 路径
this_file    = mfilename('fullpath');
analysis_dir = fileparts(this_file);
project_root = fileparts(analysis_dir);
addpath(genpath(project_root));

%% 配色
COLOR_BG       = [0.96 0.96 0.97];
COLOR_PANEL    = [1 1 1];
COLOR_TXT_HINT = [0.55 0.55 0.55];
COLOR_TXT_SUB  = [0.40 0.40 0.40];
COLOR_BTN_BG   = [0.99 0.99 0.99];
COLOR_HIGHLIGHT= [0.85 0.92 1.00];
COLOR_INNOV    = [1.00 0.95 0.78];   % 创新功能用暖色

%% 窗口
WIN_W = 850; WIN_H = 620;
ss = get(0,'ScreenSize');
winX = max(20, round((ss(3)-WIN_W)/2));
winY = max(20, round((ss(4)-WIN_H)/2));
hFig = uifigure('Name','疲劳数据分析 v2', ...
                'Position',[winX winY WIN_W WIN_H], ...
                'Resize','off','Color',COLOR_BG);

%% 标题
uilabel(hFig,'Text','疲劳数据分析','Position',[25 575 400 28], ...
    'FontSize',18,'FontWeight','bold');
uilabel(hFig,'Text','v2 · 含变异性 + 早期预警 + 综合评分', ...
    'Position',[25 555 500 18],'FontSize',11,'FontColor',COLOR_TXT_HINT);
uipanel(hFig,'Position',[25 545 800 1],'BorderType','none', ...
    'BackgroundColor',[0.85 0.85 0.87]);

%% 第一步: 4 个分析类型 (2x2 布局)
uilabel(hFig,'Text','1. 选择分析类型','Position',[25 508 200 18], ...
    'FontSize',12,'FontWeight','bold','FontColor',COLOR_TXT_SUB);

analysisDefs = {
    'PVT 行为分析',         'pvt',               'normal';
    'EEG 疲劳指标(单次)',    'fatigue_single',    'normal';
    '基线 vs 疲劳 对比',     'fatigue_compare',   'normal';
    '★ 综合疲劳评分',        'fatigue_score',     'innov';
};

btnW = 380; btnH = 48; gapX = 12; gapY = 10;
startX = 25;
hTypeBtns = gobjects(4,1);
selectedType = 'fatigue_score';   % 默认选最有趣的

for i = 1:4
    row = ceil(i/2);
    col = mod(i-1, 2) + 1;
    x = startX + (col-1)*(btnW + gapX);
    y = 455 - (row-1)*(btnH + gapY);

    if strcmp(analysisDefs{i,2}, selectedType)
        bgc = COLOR_HIGHLIGHT;
    elseif strcmp(analysisDefs{i,3}, 'innov')
        bgc = COLOR_INNOV;
    else
        bgc = COLOR_BTN_BG;
    end

    hTypeBtns(i) = uibutton(hFig,'Text',analysisDefs{i,1}, ...
        'Position',[x y btnW btnH],'FontSize',13, ...
        'BackgroundColor',bgc,'Tag',analysisDefs{i,2}, ...
        'ButtonPushedFcn',@(s,e) on_type_select(analysisDefs{i,2}));
end

%% 第二步: 选被试
uilabel(hFig,'Text','2. 选择被试','Position',[25 380 200 18], ...
    'FontSize',12,'FontWeight','bold','FontColor',COLOR_TXT_SUB);

uilabel(hFig,'Text','被试编号:','Position',[25 350 70 22], ...
    'FontSize',11,'FontColor',COLOR_TXT_HINT);
hSubjectDropdown = uidropdown(hFig,'Items',{'sub01'},'Value','sub01', ...
    'Position',[95 350 130 26],'ValueChangedFcn',@(s,e) refresh_file_hint());
uibutton(hFig,'Text','↻','Position',[230 350 26 26],'FontSize',12, ...
    'BackgroundColor',COLOR_BTN_BG,'Tooltip','刷新被试列表', ...
    'ButtonPushedFcn',@(s,e) refresh_subject_list());

hFileHint = uilabel(hFig,'Text','', ...
    'Position',[95 320 700 22],'FontSize',11,'FontColor',COLOR_TXT_HINT);

%% 第三步: 分析按钮
uibutton(hFig,'Text','📊  开始分析','Position',[25 265 200 40], ...
    'FontSize',14,'FontWeight','bold','BackgroundColor',[0.85 0.93 0.85], ...
    'ButtonPushedFcn',@(s,e) on_analyze());

uibutton(hFig,'Text','关闭','Position',[755 575 70 24],'FontSize',11, ...
    'BackgroundColor',COLOR_BTN_BG,'ButtonPushedFcn',@(s,e) close(hFig));

%% 摘要框
uilabel(hFig,'Text','分析摘要','Position',[25 235 200 18], ...
    'FontSize',12,'FontWeight','bold','FontColor',COLOR_TXT_SUB);
hResultText = uitextarea(hFig, ...
    'Value',{'尚未运行分析';'选择类型和被试, 点击 [开始分析]'}, ...
    'Position',[25 25 800 205],'Editable','off','FontSize',11, ...
    'FontName','Consolas','BackgroundColor',COLOR_PANEL);

refresh_subject_list();

% ===========================================================
% 内部函数
% ===========================================================
    function on_type_select(tag)
        selectedType = tag;
        for k=1:4
            if strcmp(hTypeBtns(k).Tag, tag)
                hTypeBtns(k).BackgroundColor = COLOR_HIGHLIGHT;
            elseif strcmp(analysisDefs{k,3}, 'innov')
                hTypeBtns(k).BackgroundColor = COLOR_INNOV;
            else
                hTypeBtns(k).BackgroundColor = COLOR_BTN_BG;
            end
        end
        refresh_file_hint();
    end

    function refresh_subject_list()
        data_dir = fullfile(project_root,'data');
        if ~exist(data_dir,'dir'), mkdir(data_dir); end
        subDirs = dir(data_dir);
        subjects = {};
        for k=1:length(subDirs)
            if subDirs(k).isdir && ~startsWith(subDirs(k).name,'.')
                subjects{end+1} = subDirs(k).name; %#ok<AGROW>
            end
        end
        if isempty(subjects), subjects = {'(无被试)'}; end
        hSubjectDropdown.Items = subjects;
        if ~ismember(hSubjectDropdown.Value, subjects)
            hSubjectDropdown.Value = subjects{1};
        end
        refresh_file_hint();
    end

    function refresh_file_hint()
        subj = hSubjectDropdown.Value;
        switch selectedType
            case 'pvt'
                hFileHint.Text = check_dir(subj, {'PVT'});
            case 'fatigue_single'
                hFileHint.Text = check_dir(subj, {'Baseline'});
            case 'fatigue_compare'
                hFileHint.Text = check_dir(subj, {'Baseline','FatigueTest'});
            case 'fatigue_score'
                hFileHint.Text = check_dir(subj, {'Baseline','PVT','FatigueTest'});
        end
    end

    function s = check_dir(subj, needed)
        missing = {};
        for k = 1:length(needed)
            d = fullfile(project_root,'data',subj,needed{k});
            if ~exist(d,'dir') || isempty(dir(fullfile(d,'*.mat')))
                missing{end+1} = needed{k}; %#ok<AGROW>
            end
        end
        if isempty(missing)
            s = sprintf('  ✓ 找到所需数据: %s', strjoin(needed,', '));
        else
            s = sprintf('  ⚠ 缺少: %s', strjoin(missing,', '));
        end
    end

    function on_analyze()
        subj = hSubjectDropdown.Value;
        if strcmp(subj,'(无被试)')
            uialert(hFig,'没有可分析的被试','提示'); return;
        end
        log_result(sprintf('[%s] 开始分析: %s (被试 %s)', ...
                   datestr(now,'HH:MM:SS'), selectedType, subj));
        log_result('  正在分析, 请稍候...');
        drawnow;

        try
            switch selectedType
                case 'pvt'
                    res = analyze_pvt([], 'subjectName', subj);
                    show_pvt_summary(res);
                case 'fatigue_single'
                    res = analyze_fatigue('subjectName', subj);
                    show_fatigue_single_summary(res);
                case 'fatigue_compare'
                    res = analyze_fatigue('subjectName', subj, 'compare', true);
                    show_fatigue_compare_summary(res);
                case 'fatigue_score'
                    run_fatigue_score(subj);
            end
            log_result('  ✓ 分析完成');
            log_result('---');
        catch ME
            log_result(sprintf('  ✗ 出错: %s', ME.message));
            if ~isempty(ME.stack)
                log_result(sprintf('    位置: %s 第 %d 行', ME.stack(1).name, ME.stack(1).line));
            end
            log_result('---');
        end
    end

    %% ============================================================
    %  ★ 综合疲劳评分核心流程
    %  ============================================================
    function run_fatigue_score(subj)
        log_result('---');
        log_result('  [综合评分] 同时使用 PVT + EEG');
        log_result('  正在加载 3 个数据集...');
        drawnow;

        % 1. PVT 行为分析 (得 RT 时序 + CV 时序)
        pvtRes = analyze_pvt([], 'subjectName', subj, 'showFig', false);

        % 2. EEG 基线 vs 疲劳对比
        eegRes = analyze_fatigue('subjectName', subj, ...
                                  'compare', true, 'showFig', false);
        ta_baseline = eegRes.score_input.theta_alpha_baseline;
        ta_current  = eegRes.score_input.theta_alpha_current;

        % 3. 构造 EEG 时间序列 (因为 EEG 只有基线和疲劳两个点, 
        %    我们做线性插值给综合评分用)
        pvtDurSec = max(pvtRes.respOnsets);
        ta_t = [0, pvtDurSec];
        ta_series = [ta_baseline, ta_current];

        % 4. 调用核心评分函数 (timeseries 模式)
        score = compute_fatigue_score( ...
            'rt_series',           pvtRes.respRTs, ...
            'rt_onsets',           pvtRes.respOnsets, ...
            'rt_baseline',         pvtRes.respRTs(pvtRes.respOnsets <= ...
                                    min(pvtRes.respOnsets)+pvtRes.windowSec), ...
            'theta_alpha_baseline', ta_baseline, ...
            'theta_alpha_series',   ta_series, ...
            'theta_alpha_t',        ta_t, ...
            'window_sec',           pvtRes.windowSec);

        % 5. 摘要
        log_result(sprintf('  被试: %s · 综合疲劳评分', subj));
        log_result('  ─────────────────────');
        log_result(sprintf('  滑窗大小   : %d 秒', pvtRes.windowSec));
        log_result(sprintf('  权重       : RT=%.2f, EEG=%.2f, 趋势=%.2f', ...
                   score.weights(1), score.weights(2), score.weights(3)));
        log_result('  ─────────────────────');
        log_result(sprintf('  起始疲劳分 : %.2f / 1.00', score.value(1)));
        log_result(sprintf('  最终疲劳分 : %.2f / 1.00', score.value(end)));
        log_result(sprintf('  峰值疲劳分 : %.2f / 1.00 (@%.1f 分钟)', ...
                   max(score.value), score.t(find(score.value==max(score.value),1))/60));
        log_result('  ─────────────────────');
        if ~isnan(pvtRes.warnTime)
            log_result(sprintf('  ★ 早期预警 : %.1f 分钟时刻', pvtRes.warnMin));
        else
            log_result('  ★ 早期预警 : 未触发');
        end
        log_result('  ─────────────────────');
        log_result('  分数解读: 0=无疲劳, 0.3=早期, 0.5=中度, 0.7+=严重');

        % 6. 画图
        plot_fatigue_score(score, pvtRes, eegRes);
    end

    function plot_fatigue_score(score, pvtRes, eegRes)
        % 综合评分主图
        figure('Name','★ 综合疲劳评分', 'Position',[150 80 1000 700],'Color','white');

        % 子图 1: 综合评分曲线
        subplot(3,2,[1 2]);
        plot(score.t/60, score.value, 'k-', 'LineWidth', 3); hold on;
        % 颜色带: 不同等级
        ax = gca; yLim = [0 1];
        patch([0 max(score.t/60) max(score.t/60) 0],[0 0 0.3 0.3], ...
              [0.85 1.00 0.85],'EdgeColor','none','FaceAlpha',0.3);
        patch([0 max(score.t/60) max(score.t/60) 0],[0.3 0.3 0.5 0.5], ...
              [1.00 0.95 0.80],'EdgeColor','none','FaceAlpha',0.3);
        patch([0 max(score.t/60) max(score.t/60) 0],[0.5 0.5 0.7 0.7], ...
              [1.00 0.85 0.70],'EdgeColor','none','FaceAlpha',0.3);
        patch([0 max(score.t/60) max(score.t/60) 0],[0.7 0.7 1.0 1.0], ...
              [1.00 0.75 0.75],'EdgeColor','none','FaceAlpha',0.3);
        plot(score.t/60, score.value, 'k-', 'LineWidth', 3);
        if ~isnan(pvtRes.warnTime)
            xline(pvtRes.warnMin, 'r-', 'LineWidth',2, ...
                  'Label','早期预警');
        end
        ylim([0 1]); ylabel('综合疲劳分');
        xlabel('时间 (分钟)');
        title(sprintf('★ 综合疲劳评分曲线 - %s', pvtRes.subject));
        legend({'','无疲劳','早期','中度','严重','疲劳分'}, ...
               'Location','northoutside','Orientation','horizontal');
        grid on; box on; hold off;

        % 子图 2: RT 子分数
        subplot(3,2,3);
        plot(score.t/60, score.s_rt, '-', 'LineWidth', 2, 'Color', [0.3 0.5 0.8]);
        ylabel('S_{RT}'); xlabel('时间 (分钟)');
        title('① 反应时变异性子分数 (创新点 E)');
        grid on; ylim([0 1]);

        % 子图 3: EEG 子分数
        subplot(3,2,4);
        plot(score.t/60, score.s_eeg, '-', 'LineWidth', 2, 'Color', [0.7 0.4 0.5]);
        ylabel('S_{EEG}'); xlabel('时间 (分钟)');
        title('② EEG θ/α 子分数 (创新点 C)');
        grid on; ylim([0 1]);

        % 子图 4: 斜率子分数
        subplot(3,2,5);
        plot(score.t/60, score.s_slope, '-', 'LineWidth', 2, 'Color', [0.4 0.7 0.4]);
        ylabel('S_{slope}'); xlabel('时间 (分钟)');
        title('③ 趋势斜率子分数 (创新点 D)');
        grid on; ylim([0 1]);

        % 子图 5: CV 原始序列(参考)
        subplot(3,2,6);
        plot(score.t/60, score.cv_series, '-', 'LineWidth', 2, 'Color', [0.8 0.4 0.3]);
        hold on; yline(score.cv_baseline, '--', 'Color',[0.5 0.5 0.5], ...
                       'Label',sprintf('基线 %.2f', score.cv_baseline));
        ylabel('CV (std/mean)'); xlabel('时间 (分钟)');
        title('反应时 CV 原始序列');
        grid on; hold off;

        sgtitle(sprintf('综合疲劳评分系统 - %s (w_R_T=%.2f w_E_E_G=%.2f w_t=%.2f)', ...
                pvtRes.subject, score.weights(1), score.weights(2), score.weights(3)));
    end

    function show_pvt_summary(res)
        log_result('---');
        log_result(sprintf('  被试: %s · PVT 行为', res.subject));
        log_result('  ─────────────────────');
        log_result(sprintf('  总 trial    : %d', res.nTrials));
        log_result(sprintf('  漏报        : %d (%.1f%%)', res.nLapse, res.lapseRate));
        log_result(sprintf('  平均反应时  : %.0f ms', res.meanRT));
        log_result(sprintf('  最慢 10%%    : %.0f ms', res.slowest10));
        log_result(sprintf('  反应时斜率  : %+.1f ms/分钟', res.slope));
        log_result(sprintf('  前/后半 RT  : %.0f / %.0f ms', res.rtFirst, res.rtSecond));
        log_result('  ─────────────────────');
        log_result('  [★ 创新指标]');
        log_result(sprintf('  滑窗 CV (基线/最终) : %.3f / %.3f', ...
                   res.cv_baseline, res.cv_series(end)));
        if ~isnan(res.warnTime)
            log_result(sprintf('  早期预警时刻 : %.1f 分钟', res.warnMin));
        else
            log_result('  早期预警 : 未触发');
        end
    end

    function show_fatigue_single_summary(res)
        m = res.metrics;
        log_result('---');
        log_result(sprintf('  被试: %s · EEG 疲劳 (%s)', res.subject, m.segName));
        log_result('  ─────────────────────');
        log_result(sprintf('  θ/α 比值       : %.3f', m.theta_alpha));
        log_result(sprintf('  疲劳指数(θ+α)/β: %.3f', m.fatigueIdx));
        log_result(sprintf('  α/β 比值       : %.3f', m.alpha_beta));
    end

    function show_fatigue_compare_summary(res)
        b = res.baseMetrics; f = res.fatigueMetrics; d = res.delta;
        log_result('---');
        log_result(sprintf('  被试: %s · 基线 vs 疲劳', res.subject));
        log_result('  ─────────────────────');
        log_result('            | 基线  | 疲劳后 | 个性化Δ');
        log_result(sprintf('  θ/α      | %5.2f | %5.2f | %+5.1f%%', ...
                   b.theta_alpha, f.theta_alpha, d.theta_alpha*100));
        log_result(sprintf('  (θ+α)/β  | %5.2f | %5.2f | %+5.1f%%', ...
                   b.fatigueIdx, f.fatigueIdx, d.fatigueIdx*100));
        log_result(sprintf('  α/β      | %5.2f | %5.2f | %+5.1f%%', ...
                   b.alpha_beta, f.alpha_beta, d.alpha_beta*100));
        log_result('  ─────────────────────');
        log_result('  [★ 创新: 个性化归一化]');
        log_result(sprintf('  θ 功率Δ  : %+.1f%%', d.theta*100));
        log_result(sprintf('  α 功率Δ  : %+.1f%%', d.alpha*100));
        log_result(sprintf('  β 功率Δ  : %+.1f%%', d.beta*100));
    end

    function log_result(msg)
        current = hResultText.Value;
        if ischar(current), current = {current}; end
        if ~iscell(current), current = cellstr(current); end
        new_lines = [{char(msg)}; current];
        if length(new_lines) > 200, new_lines = new_lines(1:200); end
        hResultText.Value = new_lines;
        drawnow;
    end
end
