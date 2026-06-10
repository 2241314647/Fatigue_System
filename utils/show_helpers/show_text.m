function show_text(hFig, str, varargin)
% SHOW_TEXT  在 figure 上显示一行居中文字
% =========================================================
% 把"clf + axes + text"这一连串操作封装成一行调用。
%
% 用法:
%   show_text(hFig, '欢迎参加实验');
%   show_text(hFig, '+', 'FontSize', 200);
%   show_text(hFig, '按空格开始', 'FontSize', 50, 'Color', 'yellow', 'Y', 0.2);
%   show_text(hFig, '提示', 'Mode', 'overlay');  % 不清空,叠加在已有内容上
%
% 必需参数:
%   hFig : figure 句柄(从 figure(...) 返回的对象)
%   str  : 要显示的文字
%
% 可选参数(键值对):
%   'FontSize'  字号, 默认 60
%   'Color'     颜色, 默认 'white'  (可以是 'red'/'cyan' 或 [1 0 0] 这种)
%   'Y'         垂直位置 0-1, 默认 0.5 (0.5=居中, 0=底部, 1=顶部)
%   'X'         水平位置 0-1, 默认 0.5
%   'Mode'      'clear' (先清空 figure, 默认) 或 'overlay' (叠加在已有内容上)
%   'FontWeight' 字重, 默认 'bold'
% =========================================================

%% ----- 1. 解析参数 -----
p = inputParser;
addParameter(p, 'FontSize',   60,       @isnumeric);
addParameter(p, 'Color',      'white');  % 字符串或 RGB 向量都行
addParameter(p, 'Y',          0.5,      @isnumeric);
addParameter(p, 'X',          0.5,      @isnumeric);
addParameter(p, 'Mode',       'clear',  @ischar);
addParameter(p, 'FontWeight', 'bold',   @ischar);
parse(p, varargin{:});
opt = p.Results;

%% ----- 2. 准备绘图坐标轴 -----
if strcmp(opt.Mode, 'clear')
    % 清空 figure, 建立新坐标轴 (0~1 归一化坐标系, 方便居中)
    clf(hFig);
    ax = axes('Parent', hFig, ...
              'Position', [0 0 1 1], ...   % 坐标轴铺满整个窗口
              'Visible', 'off', ...
              'XLim', [0 1], 'YLim', [0 1]);
else
    % overlay 模式: 找到已有的坐标轴, 没有就建一个
    ax = findobj(hFig, 'Type', 'axes');
    if isempty(ax)
        ax = axes('Parent', hFig, ...
                  'Position', [0 0 1 1], ...
                  'Visible', 'off', ...
                  'XLim', [0 1], 'YLim', [0 1]);
    else
        ax = ax(1);   % 取第一个
    end
end

%% ----- 3. 画文字 -----
text(opt.X, opt.Y, str, ...
     'Parent',              ax, ...
     'FontSize',            opt.FontSize, ...
     'Color',               opt.Color, ...
     'HorizontalAlignment', 'center', ...
     'VerticalAlignment',   'middle', ...
     'FontWeight',          opt.FontWeight, ...
     'Interpreter',         'none');   % 不解析 LaTeX, 避免下划线变下标等问题

%% ----- 4. 立刻刷新到屏幕 -----
drawnow;

end
