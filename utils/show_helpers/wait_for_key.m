function [pressedKey, rt, absTime] = wait_for_key(hFig, validKeys, cueTimer)
% WAIT_FOR_KEY  阻塞等待用户按下指定按键, 返回完整时间信息
% =========================================================
% v2 改动:
%   - 多返回两个值: rt (反应时), absTime (绝对时间戳)
%   - 新增 cueTimer 输入参数(从外部传入"刺激出现时的 tic")
%   - 兼容旧用法: 不传 cueTimer 时, 内部自己 tic
%
% 用法:
%   % 老用法 (兼容)
%   key = wait_for_key(hFig, 'space');
%
%   % 新用法
%   cueTimer = tic;             % 在刺激出现时打时间戳
%   showStim(...);
%   [key, rt, t] = wait_for_key(hFig, {'1','2'}, cueTimer);
%
% 参数:
%   hFig      : figure 句柄
%   validKeys : 字符串(单个键) 或 cell 数组(多个键之一)
%   cueTimer  : (可选) 调用方提供的 tic, 用于计算 rt
%
% 返回:
%   pressedKey : 实际按下的键名(如 'space', '1', 'leftarrow')
%   rt         : 从 cueTimer 到按键的秒数 (反应时, 反映"看到刺激到按键"的时间)
%   absTime    : 按键的绝对时间(用 datenum, 可换算成时分秒)
% =========================================================

% 如果没传 cueTimer, 现场打一个
if nargin < 3 || isempty(cueTimer)
    cueTimer = tic;
end

% 把单字符串包装成 cell, 统一处理
if ischar(validKeys)
    validKeys = {validKeys};
end

pressedKey = '';
rt = NaN;
absTime = NaN;

set(hFig, 'KeyPressFcn', @local_key_handler);

% 阻塞等待
while true
    uiwait(hFig);

    if any(strcmp(pressedKey, validKeys))
        break;
    end
    % 不匹配, 继续等
end

% 用完清掉 KeyPressFcn
set(hFig, 'KeyPressFcn', '');

    function local_key_handler(~, evt)
        pressedKey = evt.Key;
        rt         = toc(cueTimer);      % 立即记反应时
        absTime    = now;                 % 绝对时间(MATLAB datenum)
        uiresume(hFig);
    end
end
