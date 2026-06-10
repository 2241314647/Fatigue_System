function result = analyze_pvt(matFile, varargin)
% ANALYZE_PVT  PVT 行为分析 v2 (反应时趋势 + 变异性 + 早期预警)
% =========================================================
% v2 新增:
%   - 滑动窗口反应时变异系数 CV (创新点 E)
%   - 滑动窗口趋势斜率 (创新点 D, 早期预警)
%   - 变异性预警时刻识别 (CV 上升超阈值的最早时刻)
%
% 沿用 v1 全部分析:
%   - 平均/中位/最快10%/最慢10% RT
%   - 漏报次数/率
%   - 反应时趋势(全局线性回归)
%   - 前后半段对比
%
% 用法:
%   res = analyze_pvt();             % 自动选最新
%   res = analyze_pvt('xxx.mat');    % 指定文件
%   res = analyze_pvt('xxx.mat', 'windowSec', 60, 'slopeWindow', 5);
% =========================================================

%% ----- 1. 参数 -----
p = inputParser;
addParameter(p, 'showFig',     true,    @islogical);
addParameter(p, 'subjectName', 'sub01', @ischar);
addParameter(p, 'windowSec',   60,      @isnumeric);     % 创新参数: 滑窗大小
addParameter(p, 'slopeWindow', 5,       @isnumeric);     % 趋势窗点数
addParameter(p, 'warnThresh',  0.30,    @isnumeric);     % CV 变化预警阈值 (30%)
parse(p, varargin{:});
opt = p.Results;

%% ----- 2. 定位文件 -----
if nargin < 1 || isempty(matFile)
    this_file    = mfilename('fullpath');
    analysis_dir = fileparts(this_file);
    project_root = fileparts(analysis_dir);
    search_pat   = fullfile(project_root, 'data', opt.subjectName, 'PVT', '*.mat');
    files = dir(search_pat);
    if isempty(files)
        error('analyze_pvt:NoFile', '找不到 PVT 数据: %s', search_pat);
    end
    [~, idx] = max([files.datenum]);
    matFile = fullfile(files(idx).folder, files(idx).name);
    fprintf('[分析] 自动选择: %s\n', files(idx).name);
end
if ~exist(matFile, 'file')
    error('analyze_pvt:FileNotFound', '文件不存在: %s', matFile);
end

%% ----- 3. 加载 -----
data = load(matFile);
trials = data.trials;
nTrials = length(trials);
lapseThresh = data.options.lapseThresh;
fprintf('  trial 数: %d, lapse 阈值: %.0f ms, 滑窗 %d 秒\n', ...
        nTrials, lapseThresh*1000, opt.windowSec);

%% ----- 4. 提取数据 -----
onsets    = [trials.onset];
rts       = [trials.rt];
responded = logical([trials.responded]);
isLapse   = logical([trials.isLapse]);
validRT   = rts(responded);
onsetMin  = onsets / 60;

nResp   = sum(responded);
nLapse  = sum(isLapse);

meanRT   = mean(validRT) * 1000;
medianRT = median(validRT) * 1000;
lapseRate = nLapse / nTrials * 100;

sortedRT = sort(validRT, 'descend');
n10 = max(1, round(length(sortedRT) * 0.1));
slowest10 = mean(sortedRT(1:n10)) * 1000;
fastest10 = mean(sortedRT(end-n10+1:end)) * 1000;

% 全局线性回归
respOnsetMin = onsetMin(responded);
respRT_ms = validRT * 1000;
if length(respRT_ms) >= 2
    pCoef = polyfit(respOnsetMin, respRT_ms, 1);
    slope = pCoef(1);
    trendLine = polyval(pCoef, respOnsetMin);
else
    slope = NaN; trendLine = [];
end

% 前后半段
midTime = max(onsets) / 2;
firstHalf = responded & (onsets <= midTime);
secondHalf = responded & (onsets > midTime);
rtFirst  = mean(rts(firstHalf)) * 1000;
rtSecond = mean(rts(secondHalf)) * 1000;
rtChange = rtSecond - rtFirst;
lapseFirst  = sum(isLapse & (onsets <= midTime));
lapseSecond = sum(isLapse & (onsets > midTime));

%% =========================================================
%  ★ 创新分析 (v2)
%  =========================================================
fprintf('\n[创新分析] 滑动窗口 CV + 趋势斜率...\n');

% --- 创新 E: 滑动窗口 CV 序列 ---
respOnsets = onsets(responded);   % 用秒为单位
respRTs    = validRT;             % 用秒为单位

W = opt.windowSec;
step = 5;       % 每 5 秒输出一点
tStart = min(respOnsets);
tEnd   = max(respOnsets);
t_grid = tStart : step : tEnd;

cv_series      = nan(size(t_grid));
mean_rt_series = nan(size(t_grid));
n_in_win       = nan(size(t_grid));

for k = 1:length(t_grid)
    t_center = t_grid(k);
    inWin = (respOnsets >= t_center - W/2) & (respOnsets <= t_center + W/2);
    if sum(inWin) >= 3
        rtw = respRTs(inWin);
        cv_series(k)      = std(rtw) / mean(rtw);
        mean_rt_series(k) = mean(rtw) * 1000;   % 转 ms
        n_in_win(k)       = sum(inWin);
    end
end

% 基线 CV = 前 W 秒的窗口
firstWinIdx = respOnsets <= (tStart + W);
if sum(firstWinIdx) >= 3
    cv_baseline = std(respRTs(firstWinIdx)) / mean(respRTs(firstWinIdx));
else
    cv_baseline = NaN;
end

% CV 相对变化
if ~isnan(cv_baseline) && cv_baseline > eps
    delta_cv = (cv_series - cv_baseline) / cv_baseline;   % 比例变化
else
    delta_cv = zeros(size(cv_series));
end

% --- 创新 D: 趋势斜率序列 ---
K = opt.slopeWindow;
slope_series = nan(size(t_grid));
for k = K:length(t_grid)
    win_idx = (k-K+1):k;
    if any(isnan(cv_series(win_idx)))
        continue;
    end
    pCoef2 = polyfit(t_grid(win_idx), cv_series(win_idx), 1);
    slope_series(k) = pCoef2(1);
end

% --- 早期预警时刻 (CV 变化首次超阈值) ---
warnIdx = find(delta_cv > opt.warnThresh, 1);
if ~isempty(warnIdx)
    warnTime = t_grid(warnIdx);
    warnMin  = warnTime / 60;
else
    warnTime = NaN;
    warnMin  = NaN;
end

%% ----- 5. 打印 -----
fprintf('\n=====================================\n');
fprintf('   PVT 行为分析 v2 (含创新指标)\n');
fprintf('=====================================\n');
fprintf(' 被试: %s\n', data.info.name);
fprintf(' 任务时长: %.1f 分钟\n', data.options.durationMin);
fprintf('-------------------------------------\n');
fprintf(' [总体表现]\n');
fprintf('  总 trial    : %d\n', nTrials);
fprintf('  有效反应    : %d\n', nResp);
fprintf('  漏报(lapse) : %d (%.1f%%)\n', nLapse, lapseRate);
fprintf('  平均反应时  : %.0f ms\n', meanRT);
fprintf('  中位反应时  : %.0f ms\n', medianRT);
fprintf('  最快 10%%    : %.0f ms\n', fastest10);
fprintf('  最慢 10%%    : %.0f ms\n', slowest10);
fprintf('-------------------------------------\n');
fprintf(' [常规疲劳趋势]\n');
if ~isnan(slope)
    fprintf('  反应时斜率  : %+.1f ms/分钟\n', slope);
end
fprintf('  前/后半段RT : %.0f / %.0f ms (变化 %+.0f)\n', rtFirst, rtSecond, rtChange);
fprintf('  漏报 前/后  : %d / %d\n', lapseFirst, lapseSecond);
fprintf('-------------------------------------\n');
fprintf(' [★ 创新指标 (变异性 + 早期预警)]\n');
fprintf('  基线 CV     : %.3f (前 %d 秒)\n', cv_baseline, W);
fprintf('  最终 CV     : %.3f\n', cv_series(end));
if ~isnan(cv_baseline)
    fprintf('  CV 变化     : %+.1f%% (越高=越疲劳)\n', delta_cv(end)*100);
end
if ~isnan(warnTime)
    fprintf('  早期预警    : %.1f 分钟时刻 (CV 超 %.0f%% 阈值)\n', warnMin, opt.warnThresh*100);
    if ~isnan(slope) && slope > 0
        % 平均RT 显著上升的时刻 ≈ 后半段
        late_warn = max(onsets)/2 / 60;
        fprintf('  传统检测约   : %.1f 分钟 (平均 RT 上升明显)\n', late_warn);
        fprintf('  ✓ 早期预警领先约 %.1f 分钟\n', late_warn - warnMin);
    end
else
    fprintf('  早期预警    : 未触发 (CV 上升 < %.0f%%)\n', opt.warnThresh*100);
end
fprintf('=====================================\n');

% v3 创新功能数据 (如果存在)
if isfield(data,'adaptiveISIHistory') && ~isempty(data.adaptiveISIHistory)
    fprintf(' [★ 自适应 ISI 触发记录]\n');
    fprintf('  共 %d 次自适应触发\n', length(data.adaptiveISIHistory));
    % 统计各类触发原因
    reasons = {data.adaptiveISIHistory.reason};
    nHard = sum(contains(reasons, '加难'));
    nEasy = sum(contains(reasons, '减压'));
    nKeep = sum(contains(reasons, '正常'));
    fprintf('  加难 %d 次, 减压 %d 次, 维持 %d 次\n', nHard, nEasy, nKeep);
    fprintf('-------------------------------------\n');
end
if isfield(data,'qualityHistory') && ~isempty(data.qualityHistory)
    qScores = [data.qualityHistory.score];
    qLevels = {data.qualityHistory.level};
    fprintf(' [★ 信号质量监控]\n');
    fprintf('  采样次数  : %d\n', length(qScores));
    fprintf('  平均质量分: %.2f / 1.00\n', mean(qScores,'omitnan'));
    fprintf('  好/可疑/差: %d / %d / %d\n', ...
            sum(strcmp(qLevels,'good')), ...
            sum(strcmp(qLevels,'caution')), ...
            sum(strcmp(qLevels,'bad')));
    fprintf('=====================================\n');
end
fprintf('\n');

%% ----- 6. 画图 -----
result.figures = [];
if opt.showFig
    % === 图 1: 反应时 + 趋势线 (原图) ===
    fig1 = figure('Name','PVT 反应时', 'Position',[200 100 900 500],'Color','white');
    subplot(2,1,1);
    plot(respOnsetMin, respRT_ms, 'o', 'MarkerSize',5, ...
         'MarkerFaceColor',[0.3 0.5 0.8],'MarkerEdgeColor','none'); hold on;
    if ~isempty(trendLine)
        plot(respOnsetMin, trendLine, 'r-', 'LineWidth',2.5);
    end
    yline(lapseThresh*1000, '--','Color',[0.8 0.3 0.3],'Label','Lapse 阈值');
    xlabel('时间 (分钟)'); ylabel('反应时 (ms)');
    title(sprintf('反应时 - %s (全局斜率 %+.1f ms/min)', data.info.name, slope));
    grid on; box on; hold off;

    subplot(2,1,2);
    histogram(validRT*1000, 20, 'FaceColor', [0.4 0.6 0.8]); hold on;
    xline(meanRT, 'r-','LineWidth',2,'Label',sprintf('均值 %.0f', meanRT));
    xline(lapseThresh*1000,'--','Color',[0.8 0.3 0.3],'Label','Lapse');
    xlabel('反应时 (ms)'); ylabel('次数');
    title('反应时分布');
    grid on; box on; hold off;
    result.figures(end+1) = fig1;

    % === 图 2: ★ 创新: 滑动窗口 CV + 趋势 + 预警 ===
    fig2 = figure('Name','★ 反应时变异性 (创新)', ...
                  'Position',[200 150 950 600],'Color','white');

    subplot(3,1,1);
    plot(t_grid/60, mean_rt_series, '-', 'LineWidth',2, ...
         'Color',[0.3 0.5 0.8]); hold on;
    xlabel('时间 (分钟)'); ylabel('窗口均 RT (ms)');
    title(sprintf('滑动窗口均反应时 (窗 %d 秒)', W));
    grid on; box on; hold off;

    subplot(3,1,2);
    plot(t_grid/60, cv_series, '-', 'LineWidth', 2.5, ...
         'Color',[0.8 0.4 0.3]); hold on;
    yline(cv_baseline, '--','Color',[0.5 0.5 0.5], ...
          'Label',sprintf('基线 CV=%.2f', cv_baseline));
    if ~isnan(warnTime)
        xline(warnMin, 'r-', 'LineWidth', 2, ...
              'Label',sprintf('预警 %.1f 分钟', warnMin));
    end
    xlabel('时间 (分钟)'); ylabel('CV (std/mean)');
    title('★ 反应时变异系数 CV (创新指标 - 疲劳早期就上升)');
    grid on; box on; hold off;

    subplot(3,1,3);
    plot(t_grid/60, slope_series, '-', 'LineWidth', 2, ...
         'Color',[0.4 0.7 0.4]); hold on;
    yline(0, 'k-');
    xlabel('时间 (分钟)'); ylabel('CV 斜率');
    title(sprintf('★ 趋势斜率 (窗口 %d 点, 持续上升=疲劳累积)', K));
    grid on; box on; hold off;

    sgtitle(sprintf('★ 早期疲劳预警分析 - %s', data.info.name));
    result.figures(end+1) = fig2;

    % === 图 3: 前后对比 ===
    fig3 = figure('Name','前后对比', 'Position',[300 200 700 400],'Color','white');
    subplot(1,2,1);
    b1 = bar([rtFirst, rtSecond], 'FaceColor','flat');
    b1.CData = [0.4 0.7 0.4; 0.8 0.4 0.3];
    set(gca,'XTickLabel',{'前半段','后半段'});
    ylabel('平均反应时 (ms)');
    title('反应时');
    grid on;

    subplot(1,2,2);
    b2 = bar([lapseFirst, lapseSecond], 'FaceColor','flat');
    b2.CData = [0.4 0.7 0.4; 0.8 0.4 0.3];
    set(gca,'XTickLabel',{'前半段','后半段'});
    ylabel('漏报次数');
    title('漏报');
    grid on;

    sgtitle(sprintf('%s - 疲劳累积对比', data.info.name));
    result.figures(end+1) = fig3;
end

%% ----- 7. 返回 -----
result.subject    = data.info.name;
result.matFile    = matFile;
result.nTrials    = nTrials;
result.nResp      = nResp;
result.nLapse     = nLapse;
result.lapseRate  = lapseRate;
result.meanRT     = meanRT;
result.medianRT   = medianRT;
result.slowest10  = slowest10;
result.fastest10  = fastest10;
result.slope      = slope;
result.rtFirst    = rtFirst;
result.rtSecond   = rtSecond;
result.rtChange   = rtChange;
result.lapseFirst = lapseFirst;
result.lapseSecond= lapseSecond;

% v2 新增
result.windowSec       = W;
result.cv_baseline     = cv_baseline;
result.cv_series       = cv_series;
result.cv_t            = t_grid;
result.cv_delta        = delta_cv;
result.slope_series    = slope_series;
result.mean_rt_series  = mean_rt_series;
result.warnThresh      = opt.warnThresh;
result.warnTime        = warnTime;
result.warnMin         = warnMin;

% 为 compute_fatigue_score 准备数据
result.respOnsets = respOnsets;
result.respRTs    = respRTs;

% v3: 透传创新功能数据
if isfield(data,'adaptiveISIHistory')
    result.adaptiveISIHistory = data.adaptiveISIHistory;
end
if isfield(data,'qualityHistory')
    result.qualityHistory = data.qualityHistory;
end

end
