function info = subject_info(paradigm_name)
% SUBJECT_INFO  弹对话框收集被试信息,并自动创建数据保存目录
% =========================================================
% 解决"每次换被试要改 5 个文件"的痛点。
% 实验员填一次,所有范式共享。
%
% 用法:
%   info = subject_info('Resting');
%   info = subject_info('Oddball');
%
% 返回结构体 info 含以下字段:
%   info.name        被试编号 (如 'sub01')
%   info.label       分组标签 (如 'hc' / 'mci' / 'ad')
%   info.age         年龄 (数字)
%   info.gender      性别 ('M' / 'F')
%   info.paradigm    范式名 (传入的 paradigm_name)
%   info.timestamp   时间戳 (yyyymmdd_HHMMSS)
%   info.save_dir    本次实验保存目录(已自动创建)
%   info.save_prefix 文件名前缀(被试_范式_时间戳)
%
% 目录结构:
%   <项目根目录>/data/<被试编号>/<范式名>/
%   例如: D:\EEG_System\data\sub01\Resting\
% =========================================================

if nargin < 1
    paradigm_name = 'Unknown';
end

%% ----- 1. 弹对话框 -----
prompt   = { ...
    '被试编号 (如 sub01, qym04):', ...
    '分组标签 (hc=健康 / mci=轻度认知障碍 / ad=阿尔茨海默):', ...
    '年龄:', ...
    '性别 (M=男 / F=女):'};

dlgtitle = ['被试信息 - ' paradigm_name];
dims     = [1 50];                       % 每个输入框: 1 行高, 50 字符宽
defaults = {'sub01', 'hc', '65', 'M'};   % 默认值, 节省实验员打字

answer = inputdlg(prompt, dlgtitle, dims, defaults);

% 用户按了"取消"或关掉窗口
if isempty(answer)
    error('subject_info:Cancelled', '已取消: 未输入被试信息');
end

%% ----- 2. 填入结构体 -----
info.name     = strtrim(answer{1});   % strtrim 去掉首尾空格
info.label    = strtrim(answer{2});
info.age      = str2double(answer{3});
info.gender   = strtrim(answer{4});
info.paradigm = paradigm_name;

%% ----- 3. 基础合法性检查 -----
if isempty(info.name)
    error('subject_info:EmptyName', '被试编号不能为空');
end

if isnan(info.age)
    error('subject_info:BadAge', '年龄必须是数字, 您输入的是: %s', answer{3});
end

%% ----- 4. 生成时间戳 -----
% datestr 把当前时间格式化, 用作文件名一部分
% 这样同一个被试做多次实验, 文件名不会冲突
info.timestamp = datestr(now, 'yyyymmdd_HHMMSS');

%% ----- 5. 自动创建保存目录 -----
% 关键设计:数据存到"项目根目录 / data / 被试 / 范式 /"
% 项目根目录 = subject_info.m 所在目录的父目录
%   subject_info.m 在 D:\EEG_System\utils\
%   它的父目录就是 D:\EEG_System\
this_file = mfilename('fullpath');                  % 这个 .m 文件的完整路径
utils_dir = fileparts(this_file);                   % D:\EEG_System\utils
project_root = fileparts(utils_dir);                % D:\EEG_System

base_dir = fullfile(project_root, 'data', info.name, info.paradigm);
if ~exist(base_dir, 'dir')
    mkdir(base_dir);                                % 不存在就创建(支持多层)
end
info.save_dir = base_dir;

%% ----- 6. 统一文件名前缀 -----
% 例如: sub01_Resting_20260516_154322
info.save_prefix = sprintf('%s_%s_%s', ...
                           info.name, info.paradigm, info.timestamp);

%% ----- 7. 打印确认信息 -----
fprintf('\n');
fprintf('========== 被试信息确认 ==========\n');
fprintf('  被试编号 : %s\n', info.name);
fprintf('  分组     : %s\n', info.label);
fprintf('  年龄/性别: %d / %s\n', info.age, info.gender);
fprintf('  范式     : %s\n', info.paradigm);
fprintf('  保存目录 : %s\n', info.save_dir);
fprintf('  文件前缀 : %s\n', info.save_prefix);
fprintf('===================================\n\n');

end
