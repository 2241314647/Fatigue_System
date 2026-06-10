function result = analyze_fatigue(varargin)
% ANALYZE_FATIGUE  EEG 疲劳指标分析 v2
% =========================================================
% v2 改动:
%   - 输出"个性化归一化"指标 (创新点 C):
%       (X_fatigue - X_baseline) / X_baseline
%     用相对变化, 不依赖绝对值, 跨被试可比
%   - compare 模式额外返回 score_input 子结构, 直接喂给
%     compute_fatigue_score (snapshot 模式)
%
% 用法:
%   res = analyze_fatigue('matFile', 'xxx.mat');               % 单文件
%   res = analyze_fatigue('subjectName', 'sub01','compare',true); % 对比
%
% 可选参数:
%   'matFile'      指定单个文件
%   'subjectName'  被试名 (compare 时自动找 Baseline / FatigueTest)
%   'compare'      true=对比基线和疲劳, 默认 false
%   'segment'      'eyes_closed'(默认) 或 'eyes_open'
%   'showFig'      默认 true
% =========================================================

%% ----- 1. 参数 -----
p = inputParser;
addParameter(p, 'matFile',     '',      @ischar);
addParameter(p, 'subjectName', 'sub01', @ischar);
addParameter(p, 'compare',     false,   @islogical);
addParameter(p, 'segment',     'eyes_closed', @ischar);
addParameter(p, 'showFig',     true,    @islogical);
parse(p, varargin{:});
opt = p.Results;

this_file    = mfilename('fullpath');
analysis_dir = fileparts(this_file);
project_root = fileparts(analysis_dir);

bandDef = struct('delta',[1 4],'theta',[4 8],'alpha',[8 13],'beta',[13 30]);

%% ----- 2. 对比 vs 单 -----
if opt.compare
    baseFile    = find_latest(project_root, opt.subjectName, 'Baseline');
    fatigueFile = find_latest(project_root, opt.subjectName, 'FatigueTest');
    if isempty(baseFile),    error('analyze_fatigue:NoBaseline', '找不到基线数据'); end
    if isempty(fatigueFile), error('analyze_fatigue:NoFatigue', '找不到疲劳数据'); end

    fprintf('[对比模式]\n  基线: %s\n  疲劳: %s\n', baseFile, fatigueFile);

    baseMetrics    = compute_metrics(baseFile, opt.segment, bandDef);
    fatigueMetrics = compute_metrics(fatigueFile, opt.segment, bandDef);

    % v2: 计算个性化归一化指标 (创新点 C)
    delta = compute_normalized_change(baseMetrics, fatigueMetrics);

    print_comparison(baseMetrics, fatigueMetrics, delta, opt.subjectName);

    result.subject        = opt.subjectName;
    result.baseMetrics    = baseMetrics;
    result.fatigueMetrics = fatigueMetrics;
    result.delta          = delta;

    % v2: 为 compute_fatigue_score (snapshot 模式) 准备输入
    result.score_input.theta_alpha_baseline = baseMetrics.theta_alpha;
    result.score_input.theta_alpha_current  = fatigueMetrics.theta_alpha;

    result.figures = [];
    if opt.showFig
        result.figures = plot_comparison(baseMetrics, fatigueMetrics, delta, opt.subjectName);
    end
else
    if isempty(opt.matFile)
        opt.matFile = find_latest(project_root, opt.subjectName, 'Baseline');
        if isempty(opt.matFile)
            error('analyze_fatigue:NoFile','未指定 matFile 且找不到 Baseline 数据');
        end
    end
    metrics = compute_metrics(opt.matFile, opt.segment, bandDef);
    print_single(metrics);
    result.subject = metrics.subject;
    result.metrics = metrics;
    result.figures = [];
    if opt.showFig
        result.figures = plot_single(metrics);
    end
end
end


% =========================================================
function f = find_latest(root, subj, paradigm)
    pat = fullfile(root, 'data', subj, paradigm, '*.mat');
    files = dir(pat);
    if isempty(files), f = ''; else
        [~, idx] = max([files.datenum]);
        f = fullfile(files(idx).folder, files(idx).name);
    end
end


% =========================================================
function m = compute_metrics(matFile, segName, bandDef)
    data = load(matFile);
    fs = data.sampleRate;
    nEEG = min(64, data.nChan);

    segIdx = find(strcmp(data.segType, segName), 1);
    if isempty(segIdx), segIdx = length(data.eeg); end
    segData = data.eeg{segIdx};

    segClean = eeg_preprocess(segData, 'sampleRate', fs, 'nEEG', nEEG);

    winLen  = round(2 * fs);
    overlap = round(0.5 * winLen);
    nfft    = winLen;

    [pxx1, fAxis] = pwelch(segClean(1,:), winLen, overlap, nfft, fs);
    psdAll = zeros(length(pxx1), nEEG);
    for ch = 1:nEEG
        psdAll(:,ch) = pwelch(segClean(ch,:), winLen, overlap, nfft, fs);
    end
    psdMean = mean(psdAll, 2);

    bn = fieldnames(bandDef);
    bandPow = struct();
    for b = 1:length(bn)
        rng_b = bandDef.(bn{b});
        mask = (fAxis >= rng_b(1)) & (fAxis < rng_b(2));
        bandPow.(bn{b}) = sum(psdMean(mask)) * (fAxis(2)-fAxis(1));
    end

    m.subject     = data.info.name;
    m.segName     = segName;
    m.fAxis       = fAxis;
    m.psdMean     = psdMean;
    m.bandPow     = bandPow;
    m.theta_alpha = bandPow.theta / bandPow.alpha;
    m.fatigueIdx  = (bandPow.theta + bandPow.alpha) / bandPow.beta;
    m.alpha_beta  = bandPow.alpha / bandPow.beta;
end


% =========================================================
% v2: 个性化归一化变化量 (创新点 C)
%   delta = (fatigue - baseline) / baseline
% =========================================================
function d = compute_normalized_change(b, f)
    d.theta_alpha = safe_rel(f.theta_alpha, b.theta_alpha);
    d.fatigueIdx  = safe_rel(f.fatigueIdx,  b.fatigueIdx);
    d.alpha_beta  = safe_rel(f.alpha_beta,  b.alpha_beta);
    d.theta       = safe_rel(f.bandPow.theta, b.bandPow.theta);
    d.alpha       = safe_rel(f.bandPow.alpha, b.bandPow.alpha);
    d.beta        = safe_rel(f.bandPow.beta,  b.bandPow.beta);
end

function v = safe_rel(curr, base)
    if abs(base) < eps, v = NaN; else, v = (curr - base) / base; end
end


% =========================================================
function print_single(m)
    fprintf('\n=====================================\n');
    fprintf('   EEG 疲劳指标 (单次)\n');
    fprintf('=====================================\n');
    fprintf(' 被试: %s | 段: %s\n', m.subject, m.segName);
    fprintf('-------------------------------------\n');
    bn = fieldnames(m.bandPow);
    for b = 1:length(bn)
        fprintf('  %-6s 功率: %.2f\n', bn{b}, m.bandPow.(bn{b}));
    end
    fprintf('-------------------------------------\n');
    fprintf('  θ/α 比值       : %.3f\n', m.theta_alpha);
    fprintf('  疲劳指数(θ+α)/β: %.3f\n', m.fatigueIdx);
    fprintf('  α/β 比值       : %.3f\n', m.alpha_beta);
    fprintf('=====================================\n\n');
end


function print_comparison(b, f, d, subj)
    fprintf('\n=====================================\n');
    fprintf('   EEG 疲劳对比 (个性化归一化, v2)\n');
    fprintf('=====================================\n');
    fprintf(' 被试: %s | 段: %s\n', subj, b.segName);
    fprintf('-------------------------------------\n');
    fprintf('                |  基线   |  疲劳后 | 个性化Δ\n');
    fprintf('  --------------+---------+---------+---------\n');
    fprintf('  θ/α 比值      | %6.3f | %6.3f | %+6.1f%%\n', ...
            b.theta_alpha, f.theta_alpha, d.theta_alpha*100);
    fprintf('  (θ+α)/β       | %6.3f | %6.3f | %+6.1f%%\n', ...
            b.fatigueIdx, f.fatigueIdx, d.fatigueIdx*100);
    fprintf('  α/β           | %6.3f | %6.3f | %+6.1f%%\n', ...
            b.alpha_beta, f.alpha_beta, d.alpha_beta*100);
    fprintf('-------------------------------------\n');
    fprintf(' [个性化归一化变化 Δ = (疲劳-基线)/基线]\n');
    fprintf('  ★ 跨被试可比, 不受绝对值影响\n');
    fprintf('  θ 功率        : %+6.1f%%\n', d.theta*100);
    fprintf('  α 功率        : %+6.1f%%\n', d.alpha*100);
    fprintf('  β 功率        : %+6.1f%%\n', d.beta*100);
    fprintf('-------------------------------------\n');
    if d.fatigueIdx > 0
        fprintf('  ✓ 疲劳指数上升, 符合疲劳累积预期\n');
    else
        fprintf('  疲劳指数未上升\n');
    end
    fprintf('=====================================\n\n');
end


% =========================================================
function figs = plot_single(m)
    figs = [];
    fig = figure('Name','EEG 疲劳指标', 'Position',[200 100 900 450],'Color','white');
    subplot(1,2,1);
    fMask = m.fAxis <= 40;
    plot(m.fAxis(fMask), 10*log10(m.psdMean(fMask)), 'LineWidth', 1.8);
    xlabel('频率 (Hz)'); ylabel('功率 (dB)');
    title(sprintf('功率谱 - %s (%s)', m.subject, m.segName));
    grid on; box on;
    subplot(1,2,2);
    vals = [m.theta_alpha, m.fatigueIdx, m.alpha_beta];
    labs = {'θ/α','(θ+α)/β','α/β'};
    bh = bar(vals, 'FaceColor','flat');
    bh.CData = [0.5 0.4 0.7; 0.8 0.5 0.3; 0.4 0.6 0.5];
    set(gca,'XTickLabel',labs); ylabel('比值'); title('疲劳指标');
    grid on;
    for k=1:3
        text(k, vals(k), sprintf('%.2f',vals(k)), ...
             'HorizontalAlignment','center','VerticalAlignment','bottom');
    end
    figs(end+1) = fig;
end


function figs = plot_comparison(b, f, d, subj)
    figs = [];

    % 图 1: 功率谱对比
    fig1 = figure('Name','疲劳对比: 功率谱', 'Position',[200 100 900 450],'Color','white');
    fMask = b.fAxis <= 40;
    plot(b.fAxis(fMask), 10*log10(b.psdMean(fMask)), 'b-', 'LineWidth', 2); hold on;
    plot(f.fAxis(fMask), 10*log10(f.psdMean(fMask)), 'r-', 'LineWidth', 2);
    legend({'基线','疲劳后'}, 'Location','best');
    xlabel('频率 (Hz)'); ylabel('功率 (dB)');
    title(sprintf('功率谱对比 - %s', subj));
    grid on; box on; hold off;
    figs(end+1) = fig1;

    % 图 2: 绝对值指标
    fig2 = figure('Name','疲劳对比: 指标', 'Position',[300 150 800 450],'Color','white');
    metricVals = [b.theta_alpha, f.theta_alpha;
                  b.fatigueIdx,  f.fatigueIdx;
                  b.alpha_beta,  f.alpha_beta];
    bh = bar(metricVals, 'grouped');
    bh(1).FaceColor = [0.3 0.5 0.8];
    bh(2).FaceColor = [0.8 0.4 0.3];
    set(gca,'XTickLabel',{'θ/α','(θ+α)/β','α/β'});
    ylabel('比值');
    legend({'基线','疲劳后'}, 'Location','best');
    title(sprintf('疲劳指标对比 - %s', subj));
    grid on;
    figs(end+1) = fig2;

    % v2 图 3: ★ 个性化归一化变化 (新增创新图)
    fig3 = figure('Name','★ 个性化归一化变化', 'Position',[350 200 800 450],'Color','white');
    dVals = [d.theta_alpha, d.fatigueIdx, d.alpha_beta, d.theta, d.alpha, d.beta] * 100;
    dLabs = {'θ/α','(θ+α)/β','α/β','θ','α','β'};
    colors = repmat([0.5 0.5 0.5], 6, 1);
    colors(dVals > 0, :) = repmat([0.8 0.4 0.3], sum(dVals>0), 1);
    colors(dVals < 0, :) = repmat([0.3 0.5 0.8], sum(dVals<0), 1);
    bh3 = bar(dVals, 'FaceColor','flat');
    bh3.CData = colors;
    set(gca,'XTickLabel',dLabs);
    ylabel('相对变化 (%)');
    yline(0,'k-');
    title(sprintf('★ 个性化归一化变化 Δ - %s (红=上升, 蓝=下降)', subj));
    grid on;
    for k=1:length(dVals)
        text(k, dVals(k)+sign(dVals(k))*max(abs(dVals))*0.05, ...
             sprintf('%+.1f%%', dVals(k)), ...
             'HorizontalAlignment','center');
    end
    figs(end+1) = fig3;
end
