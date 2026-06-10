function score = compute_fatigue_score(varargin)
% COMPUTE_FATIGUE_SCORE  综合疲劳评分 (核心创新算法)
% =========================================================
% 融合三个指标得到 0-1 的综合疲劳分:
%   1. ΔRT_CV     反应时变异系数变化 (创新点 E)
%   2. ΔθαRatio   EEG θ/α 比值变化 (创新点 C, 个性化归一化)
%   3. SlopeNorm  滑动窗口趋势斜率 (创新点 D)
%
% 公式: FatigueScore = w1*S1 + w2*S2 + w3*S3
%   默认 w1=w2=w3=1/3 (未先验选择)
%
% 用法:
%   % 模式1: 单时间点 (用基线+当前快照)
%   score = compute_fatigue_score('rt_baseline', rt_b, 'rt_current', rt_c, ...
%                                  'theta_alpha_baseline', tb, 'theta_alpha_current', tc);
%
%   % 模式2: 时序模式 (返回随时间变化的分数序列)
%   score = compute_fatigue_score('rt_series', rts, 'rt_onsets', onsets, ...
%                                  'theta_alpha_baseline', tb, ...
%                                  'theta_alpha_series', tas, ...
%                                  'theta_alpha_t', tas_t, ...
%                                  'rt_baseline', rt_b);
%
% 可选参数:
%   'w_rt',  默认 1/3
%   'w_eeg', 默认 1/3
%   'w_slope', 默认 1/3
%   'window_sec',  滑动窗口长度, 默认 60
%   'slope_window_K', 趋势窗口点数, 默认 5
%   'slope_norm_factor', 斜率归一化系数, 默认 0.05
%
% 返回:
%   score.value       0-1 综合疲劳分 (模式1) 或 时间序列 (模式2)
%   score.t           对应时间点 (模式2)
%   score.s_rt        三个子分数
%   score.s_eeg
%   score.s_slope
%   score.weights     使用的权重
%   score.mode        'snapshot' or 'timeseries'
% =========================================================

%% ----- 参数解析 -----
p = inputParser;
addParameter(p, 'rt_baseline',         [],   @(x) isnumeric(x));
addParameter(p, 'rt_current',          [],   @(x) isnumeric(x));
addParameter(p, 'rt_series',           [],   @(x) isnumeric(x));
addParameter(p, 'rt_onsets',           [],   @(x) isnumeric(x));
addParameter(p, 'theta_alpha_baseline',[],   @(x) isnumeric(x));
addParameter(p, 'theta_alpha_current', [],   @(x) isnumeric(x));
addParameter(p, 'theta_alpha_series',  [],   @(x) isnumeric(x));
addParameter(p, 'theta_alpha_t',       [],   @(x) isnumeric(x));
addParameter(p, 'w_rt',                1/3,  @isnumeric);
addParameter(p, 'w_eeg',               1/3,  @isnumeric);
addParameter(p, 'w_slope',             1/3,  @isnumeric);
addParameter(p, 'window_sec',          60,   @isnumeric);
addParameter(p, 'slope_window_K',      5,    @isnumeric);
addParameter(p, 'slope_norm_factor',   0.05, @isnumeric);
parse(p, varargin{:});
opt = p.Results;

% 决定模式
if ~isempty(opt.rt_series) && ~isempty(opt.rt_onsets)
    mode = 'timeseries';
else
    mode = 'snapshot';
end

score.mode    = mode;
score.weights = [opt.w_rt, opt.w_eeg, opt.w_slope];

%% =========================================================
%  模式 1: snapshot (单时间点综合分)
%  =========================================================
if strcmp(mode, 'snapshot')
    if isempty(opt.rt_baseline) || isempty(opt.rt_current)
        error('compute_fatigue_score:Missing', 'snapshot 模式需要 rt_baseline 和 rt_current');
    end

    % --- 子分数 1: 反应时变异性变化 ---
    cv_base = std(opt.rt_baseline) / mean(opt.rt_baseline);
    cv_cur  = std(opt.rt_current)  / mean(opt.rt_current);
    if cv_base > eps
        delta_cv = (cv_cur - cv_base) / cv_base;
    else
        delta_cv = 0;
    end
    s_rt = clip01(delta_cv);

    % --- 子分数 2: θ/α 比值变化 ---
    if ~isempty(opt.theta_alpha_baseline) && ~isempty(opt.theta_alpha_current)
        if opt.theta_alpha_baseline > eps
            delta_eeg = (opt.theta_alpha_current - opt.theta_alpha_baseline) / opt.theta_alpha_baseline;
        else
            delta_eeg = 0;
        end
        s_eeg = clip01(delta_eeg);
    else
        s_eeg = 0;
    end

    % --- 子分数 3: 斜率 (snapshot 模式没有时间序列, 给 0) ---
    s_slope = 0;

    % --- 综合 ---
    score.value   = opt.w_rt * s_rt + opt.w_eeg * s_eeg + opt.w_slope * s_slope;
    score.s_rt    = s_rt;
    score.s_eeg   = s_eeg;
    score.s_slope = s_slope;
    score.cv_baseline = cv_base;
    score.cv_current  = cv_cur;
    return;
end

%% =========================================================
%  模式 2: timeseries (返回随时间的疲劳分曲线)
%  =========================================================

rts = opt.rt_series(:)';
onsets = opt.rt_onsets(:)';

% 移除 NaN (漏报)
valid = ~isnan(rts);
rts_v = rts(valid);
onsets_v = onsets(valid);

if isempty(rts_v) || length(rts_v) < 3
    error('compute_fatigue_score:NotEnoughRT', '有效反应时点太少');
end

% ---- 1. 滑动窗口 CV (基于反应时) ----
W = opt.window_sec;
step = 5;   % 每 5 秒输出一点
tStart = min(onsets_v);
tEnd   = max(onsets_v);
t_grid = tStart : step : tEnd;

cv_series = nan(size(t_grid));
mean_rt_series = nan(size(t_grid));
n_in_win = nan(size(t_grid));

for k = 1:length(t_grid)
    t_center = t_grid(k);
    inWin = (onsets_v >= t_center - W/2) & (onsets_v <= t_center + W/2);
    if sum(inWin) >= 3
        rt_w = rts_v(inWin);
        m_rt = mean(rt_w);
        s_rt = std(rt_w);
        cv_series(k) = s_rt / m_rt;
        mean_rt_series(k) = m_rt;
        n_in_win(k) = sum(inWin);
    end
end

% ---- 2. 基线 CV (前 W 秒的窗口) ----
cv_baseline = nan;
if ~isempty(opt.rt_baseline) && length(opt.rt_baseline) >= 3
    cv_baseline = std(opt.rt_baseline) / mean(opt.rt_baseline);
else
    % 用 PVT 自身前 W 秒做基线
    firstWin = onsets_v <= (tStart + W);
    if sum(firstWin) >= 3
        cv_baseline = std(rts_v(firstWin)) / mean(rts_v(firstWin));
    end
end

% ---- 3. CV 变化(归一化) ----
if ~isnan(cv_baseline) && cv_baseline > eps
    delta_cv = (cv_series - cv_baseline) / cv_baseline;
else
    delta_cv = zeros(size(cv_series));
end
s_rt_series = arrayfun(@clip01, delta_cv);

% ---- 4. EEG 子分数 (如果提供了时间序列) ----
s_eeg_series = zeros(size(t_grid));
if ~isempty(opt.theta_alpha_series) && ~isempty(opt.theta_alpha_t) && ~isempty(opt.theta_alpha_baseline)
    ta_base = opt.theta_alpha_baseline;
    if ta_base > eps
        % 把 EEG 时间序列插值到 t_grid
        ta_interp = interp1(opt.theta_alpha_t, opt.theta_alpha_series, t_grid, 'linear', 'extrap');
        delta_ta = (ta_interp - ta_base) / ta_base;
        s_eeg_series = arrayfun(@clip01, delta_ta);
    end
end

% ---- 5. 趋势斜率子分数 ----
K = opt.slope_window_K;
normF = opt.slope_norm_factor;
slope_series = nan(size(t_grid));
s_slope_series = zeros(size(t_grid));

for k = K:length(t_grid)
    win_idx = (k-K+1):k;
    if any(isnan(cv_series(win_idx)))
        continue;
    end
    pCoef = polyfit(t_grid(win_idx), cv_series(win_idx), 1);
    sl = pCoef(1);
    slope_series(k) = sl;
    s_slope_series(k) = clip01(sl / normF);
end

% ---- 6. 综合 ----
score_series = opt.w_rt * s_rt_series + ...
               opt.w_eeg * s_eeg_series + ...
               opt.w_slope * s_slope_series;

% 装包返回
score.t            = t_grid;
score.value        = score_series;
score.s_rt         = s_rt_series;
score.s_eeg        = s_eeg_series;
score.s_slope      = s_slope_series;
score.cv_series    = cv_series;
score.cv_baseline  = cv_baseline;
score.mean_rt_series = mean_rt_series;
score.slope_series = slope_series;
score.n_in_win     = n_in_win;

end


% =========================================================
% 辅助: 将变化量归一到 [0, 1]
% 思想: 0% 变化 → 0;  100% 变化 → 1;  >100% 上升 → 也是 1
% 下降(<0) 当 0 处理 (疲劳指标只看上升)
% =========================================================
function y = clip01(x)
    if isnan(x), y = 0; return; end
    if x < 0,    y = 0; return; end
    if x > 1,    y = 1; return; end
    y = x;
end
