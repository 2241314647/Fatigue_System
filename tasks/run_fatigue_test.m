function result = run_fatigue_test(varargin)
% RUN_FATIGUE_TEST  疲劳后再测 (疲劳监测系统)
% =========================================================
% 在 PVT 疲劳诱发任务"之后"运行, 流程和 run_baseline 完全一样
% (睁眼静息 + 闭眼静息), 但保存为 'FatigueTest' 范式名,
% 用于和基线对比, 看 θ/α 等指标是否因疲劳而变化。
%
% 本函数是 run_baseline 的薄封装: 转发参数, 并强制 phase='fatigue'。
%
% 用法:
%   result = run_fatigue_test();
%   result = run_fatigue_test('useMock', true);
%   result = run_fatigue_test('info', infoStruct, ...);
%
% 参数同 run_baseline (eyesOpenDur / eyesCloseDur / useMock / syntheticEEG / info)
% =========================================================

% 过滤掉调用方可能传入的 'phase' 参数, 避免重复
args = varargin;
keep = true(1, numel(args));
k = 1;
while k <= numel(args)-1
    if ischar(args{k}) && strcmpi(args{k}, 'phase')
        keep(k)   = false;
        keep(k+1) = false;
        k = k + 2;
    else
        k = k + 1;
    end
end
args = args(keep);

% 调用 run_baseline, 强制 phase='fatigue'
result = run_baseline(args{:}, 'phase', 'fatigue');

end
