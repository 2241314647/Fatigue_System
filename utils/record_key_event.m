function event = record_key_event(key, rt, absTime, varargin)
% RECORD_KEY_EVENT  统一构造按键事件结构体
% =========================================================
% 在按键回调里调用此函数, 生成"标准格式"的事件记录。
% 所有范式用同一种格式, 方便分析模块统一读取。
%
% 用法:
%   evt = record_key_event(key, rt, absTime);
%   evt = record_key_event(key, rt, absTime, 'trial', tr, 'condition', 'target');
%
% 参数:
%   key      : 按下的键名 (如 'space', '1', '2')
%   rt       : 反应时(秒, 从刺激出现到按键)
%   absTime  : 绝对时间(datenum 格式, 实验中的精确时刻)
%   附加字段 : 任意键值对, 自动并入结构体(如 'trial', 5)
%
% 返回:
%   event : struct, 含 key/rt/time_abs + 任意附加字段
% =========================================================

event = struct(...
    'key',      key, ...
    'rt',       rt, ...
    'time_abs', absTime);

% 把额外参数(键值对)合并进去
for k = 1:2:length(varargin)
    fname = varargin{k};
    fval  = varargin{k+1};
    event.(fname) = fval;
end

end
