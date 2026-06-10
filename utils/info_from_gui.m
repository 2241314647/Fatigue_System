function info = info_from_gui(name, label, age, gender, paradigm)
% INFO_FROM_GUI  从 GUI 收集到的简单信息构造完整 info 结构体
% =========================================================
% subject_info() 弹对话框版本返回的 info 含 8 个字段,
% GUI 只能收集 4 个(name/label/age/gender), 本函数补齐其余 4 个:
%   .paradigm   范式名(必须传入)
%   .timestamp  当前时间戳
%   .save_dir   保存目录(自动创建)
%   .save_prefix 文件名前缀
%
% 用法:
%   info = info_from_gui('sub01', 'hc', 65, 'M', 'Resting');
%
% 这样保证 GUI 调用 run_xxx('info', info) 时, info 格式和 subject_info() 一致,
% run_xxx 内部代码无需任何改动。
% =========================================================

% 基础校验
name = strtrim(name);
if isempty(name)
    error('info_from_gui:EmptyName', '被试编号不能为空');
end
if isnan(age)
    error('info_from_gui:BadAge', '年龄必须是数字');
end

% 填基础字段
info.name     = name;
info.label    = strtrim(label);
info.age      = age;
info.gender   = strtrim(gender);
info.paradigm = paradigm;

% 时间戳
info.timestamp = datestr(now, 'yyyymmdd_HHMMSS');

% 自动创建保存目录(和 subject_info.m 逻辑一致)
% 关键: 找到项目根目录
% 本文件在 utils/, 它的父目录就是项目根
this_file    = mfilename('fullpath');
utils_dir    = fileparts(this_file);
project_root = fileparts(utils_dir);

base_dir = fullfile(project_root, 'data', info.name, info.paradigm);
if ~exist(base_dir, 'dir')
    mkdir(base_dir);
end
info.save_dir = base_dir;

% 文件名前缀
info.save_prefix = sprintf('%s_%s_%s', ...
                           info.name, info.paradigm, info.timestamp);

% 控制台打印(和 subject_info 风格一致)
fprintf('\n========== 被试信息(来自 GUI)==========\n');
fprintf('  被试编号 : %s\n', info.name);
fprintf('  分组     : %s\n', info.label);
fprintf('  年龄/性别: %d / %s\n', info.age, info.gender);
fprintf('  范式     : %s\n', info.paradigm);
fprintf('  保存目录 : %s\n', info.save_dir);
fprintf('  文件前缀 : %s\n', info.save_prefix);
fprintf('=========================================\n\n');

end
