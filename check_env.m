function check_env()
% CHECK_ENV  疲劳监测系统 环境自检脚本
% =========================================================
% 在新电脑或新装环境上运行, 检查 8 个方面。
% 用法:
%   >> cd D:\Fatigue_System
%   >> check_env
% =========================================================

fprintf('\n');
fprintf('========================================\n');
fprintf('  疲劳监测系统 环境自检 (v1.0)\n');
fprintf('  %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
fprintf('========================================\n\n');

issues  = {};
warns   = {};

%% 1. MATLAB 版本
fprintf('[1/8] MATLAB 版本 ... ');
v = ver('MATLAB'); fprintf('%s\n', v.Version);
verNum = str2double(v.Version);
if verNum < 9.13
    issues{end+1} = sprintf('MATLAB %s 太旧, 建议 R2024a+', v.Version);
elseif verNum < 24.1
    warns{end+1} = sprintf('MATLAB %s 比开发版本 R2024a 旧, 可能有兼容问题', v.Version);
end

%% 2. 工具箱
fprintf('[2/8] 必需工具箱 ... ');
allTbx = ver; tbxNames = {allTbx.Name};
if any(strcmp(tbxNames,'Signal Processing Toolbox'))
    fprintf('✓ Signal Processing Toolbox 已装\n');
else
    fprintf('✗\n');
    issues{end+1} = '缺少 Signal Processing Toolbox (pwelch 需要)';
end

%% 3. 屏幕
fprintf('[3/8] 屏幕与 DPI ... ');
sc = get(0,'ScreenSize'); fprintf('%d × %d\n', sc(3), sc(4));
if sc(3) < 1024
    issues{end+1} = sprintf('屏幕宽 %d 太小, 需要至少 1000', sc(3));
end

%% 4. 目录
fprintf('[4/8] 项目目录 ... ');
this_file    = mfilename('fullpath');
project_root = fileparts(this_file);
fprintf('%s\n', project_root);
expectedDirs = {'tasks','analysis','utils','test','data'};
for k=1:length(expectedDirs)
    d = expectedDirs{k};
    if ~exist(fullfile(project_root,d),'dir')
        if strcmp(d,'data')
            warns{end+1} = 'data/ 不存在, 首次采集会自动创建';
        else
            issues{end+1} = sprintf('缺失目录: %s/', d);
        end
    end
end

%% 5. 核心文件
fprintf('[5/8] 核心文件 ...\n');
coreFiles = {
    'main.m'
    'tasks/run_baseline.m'
    'tasks/run_pvt.m'
    'tasks/run_fatigue_test.m'
    'tasks/params/params_baseline.m'
    'tasks/params/params_pvt.m'
    'utils/device_init.m'
    'utils/mark_and_grab.m'
    'utils/subject_info.m'
    'utils/info_from_gui.m'
    'utils/record_key_event.m'
    'utils/show_helpers/show_text.m'
    'utils/show_helpers/show_fixation.m'
    'utils/show_helpers/wait_for_key.m'
    'analysis/eeg_preprocess.m'
    'analysis/analyze_pvt.m'
    'analysis/analyze_fatigue.m'
    'analysis/analysis_gui.m'
    'test/MockDataClient.m'
    'test/MockTriggerBox.m'
    'test/MockTriggerStore.m'
};
missing = {};
for k=1:length(coreFiles)
    if ~exist(fullfile(project_root,coreFiles{k}),'file')
        missing{end+1} = coreFiles{k}; %#ok<AGROW>
    end
end
if isempty(missing)
    fprintf('         ✓ 全部 %d 个核心文件存在\n', length(coreFiles));
else
    fprintf('         ✗ 缺失 %d 个:\n', length(missing));
    for k=1:length(missing)
        fprintf('            - %s\n', missing{k});
        issues{end+1} = sprintf('缺失文件: %s', missing{k}); %#ok<AGROW>
    end
end

%% 6. 中文/Unicode
fprintf('[6/8] 中文与 Unicode ... ');
try
    f = figure('Visible','off');
    text(0.5,0.5,'测试 ① ② ③ ⚙ 📁 📊 θ α β');
    close(f);
    fprintf('✓ 应能正常显示\n');
catch
    fprintf('⚠\n');
    warns{end+1} = '中文/Unicode 渲染可能有问题';
end

%% 7. 博瑞康 SDK
fprintf('[7/8] 博瑞康 SDK ... ');
sdkPath = 'D:\experient\neracle64\';
if exist(sdkPath,'dir')
    fprintf('✓ 找到 %s\n', sdkPath);
    addpath(sdkPath);
    if ~isempty(which('DataClient'))
        fprintf('         ✓ DataClient 类可识别\n');
    else
        warns{end+1} = 'SDK 路径存在但找不到 DataClient.m';
    end
else
    fprintf('⚠ 默认路径不存在\n');
    warns{end+1} = sprintf(['博瑞康 SDK 路径 %s 不存在。\n', ...
        '          → 只影响"连真实设备", Mock 模式不受影响。\n', ...
        '          → 连真实设备需改 utils/device_init.m 的 sdkPath'], sdkPath);
end

%% 8. Mock 设备自检
fprintf('[8/8] Mock 设备 ... ');
try
    addpath(genpath(project_root));
    mc = MockDataClient('127.0.0.1', 8712, 65, 500, 10);
    mc.Open;
    pause(0.5);
    d = mc.GetBufferData;
    mc.Close;
    if ~isempty(d)
        fprintf('✓ Mock 设备工作正常 (%d 通道)\n', size(d,1));
    else
        warns{end+1} = 'Mock 设备返回空数据';
    end
catch ME
    fprintf('✗\n');
    issues{end+1} = sprintf('Mock 设备测试失败: %s', ME.message);
end

%% 总结
fprintf('\n========================================\n');
fprintf('  自检结果汇总\n');
fprintf('========================================\n');
if isempty(issues) && isempty(warns)
    fprintf('\n🎉 完美! 没有发现任何问题, 可直接运行 main\n\n');
    return;
end
if ~isempty(issues)
    fprintf('\n❌ 严重问题 (%d 个, 必须解决):\n', length(issues));
    for k=1:length(issues), fprintf('   %d. %s\n', k, issues{k}); end
end
if ~isempty(warns)
    fprintf('\n⚠ 警告 (%d 个, 建议关注):\n', length(warns));
    for k=1:length(warns), fprintf('   %d. %s\n', k, warns{k}); end
end
fprintf('\n========================================\n');
if isempty(issues)
    fprintf(' 总评: 可运行 main, 但请关注警告\n');
else
    fprintf(' 总评: 请先解决严重问题\n');
end
fprintf('========================================\n\n');
end
