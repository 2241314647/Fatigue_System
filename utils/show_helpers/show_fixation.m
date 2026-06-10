function show_fixation(hFig, varargin)
% SHOW_FIXATION  显示标准 EEG 实验的注视点 '+'
% =========================================================
% EEG 实验里被试要盯着屏幕中央, 通常用一个白色 '+' 当注视点。
% 此函数 = show_text 的快捷版本, 专门画 '+'.
%
% 用法:
%   show_fixation(hFig);                    % 默认
%   show_fixation(hFig, 'FontSize', 250);    % 自定义大小
% =========================================================

p = inputParser;
addParameter(p, 'FontSize', 200,     @isnumeric);
addParameter(p, 'Color',    'white');
parse(p, varargin{:});
opt = p.Results;

show_text(hFig, '+', 'FontSize', opt.FontSize, 'Color', opt.Color);

end
