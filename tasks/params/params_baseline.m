function newParams = params_baseline(currentParams)
% PARAMS_BASELINE  基线静息参数对话框
% =========================================================

%% 默认值
defaults.eyesOpenDur  = 60;
defaults.eyesCloseDur = 60;

if isempty(currentParams)
    p = defaults;
else
    p = defaults;
    f = fieldnames(defaults);
    for i = 1:length(f)
        if isfield(currentParams, f{i})
            p.(f{i}) = currentParams.(f{i});
        end
    end
end

COLOR_BG       = [0.96 0.96 0.97];
COLOR_TXT_SUB  = [0.40 0.40 0.40];
COLOR_TXT_HINT = [0.55 0.55 0.55];
COLOR_BTN_BG   = [0.99 0.99 0.99];

dlg = uifigure('Name','基线参数','Position',[200 200 480 430], ...
               'Resize','off','Color',COLOR_BG,'WindowStyle','modal');

uilabel(dlg,'Text','基线静息 - 参数设置', ...
    'Position',[25 275 370 28],'FontSize',16,'FontWeight','bold');
uilabel(dlg,'Text','睁眼和闭眼各记录一段, 提取清醒基线', ...
    'Position',[25 255 370 18],'FontSize',11,'FontColor',COLOR_TXT_HINT);
uipanel(dlg,'Position',[25 245 370 1],'BorderType','none', ...
    'BackgroundColor',[0.85 0.85 0.87]);

%% 睁眼时长
uilabel(dlg,'Text','睁眼静息时长 (秒)', ...
    'Position',[25 208 270 18],'FontSize',12,'FontColor',COLOR_TXT_SUB);
uilabel(dlg,'Text','推荐 60', ...
    'Position',[320 208 75 18],'FontSize',11,'FontColor',COLOR_TXT_HINT, ...
    'HorizontalAlignment','right');
hOpen = uispinner(dlg,'Value',p.eyesOpenDur,'Limits',[10 300],'Step',10, ...
    'RoundFractionalValues','on','Position',[25 180 370 28],'FontSize',12);

%% 闭眼时长
uilabel(dlg,'Text','闭眼静息时长 (秒)', ...
    'Position',[25 148 270 18],'FontSize',12,'FontColor',COLOR_TXT_SUB);
uilabel(dlg,'Text','推荐 60', ...
    'Position',[320 148 75 18],'FontSize',11,'FontColor',COLOR_TXT_HINT, ...
    'HorizontalAlignment','right');
hClose = uispinner(dlg,'Value',p.eyesCloseDur,'Limits',[10 300],'Step',10, ...
    'RoundFractionalValues','on','Position',[25 120 370 28],'FontSize',12);

%% 预览
hTotal = uilabel(dlg,'Text',computeTotal(p), ...
    'Position',[25 80 370 22],'FontSize',12,'FontWeight','bold', ...
    'FontColor',[0.20 0.50 0.30],'HorizontalAlignment','center');

hOpen.ValueChangedFcn  = @(s,e) updateTotal();
hClose.ValueChangedFcn = @(s,e) updateTotal();

%% 按钮
uibutton(dlg,'Text','保存','Position',[220 20 80 30],'FontSize',12, ...
    'BackgroundColor',[0.85 0.93 0.85],'ButtonPushedFcn',@(s,e) onSave());
uibutton(dlg,'Text','取消','Position',[310 20 80 30],'FontSize',12, ...
    'ButtonPushedFcn',@(s,e) onCancel());
uibutton(dlg,'Text','恢复默认','Position',[25 20 90 30],'FontSize',11, ...
    'ButtonPushedFcn',@(s,e) onReset());

newParams = [];
uiwait(dlg);

    function updateTotal()
        cur.eyesOpenDur  = round(hOpen.Value);
        cur.eyesCloseDur = round(hClose.Value);
        hTotal.Text = computeTotal(cur);
    end

    function onSave()
        newParams = struct( ...
            'eyesOpenDur',  round(hOpen.Value), ...
            'eyesCloseDur', round(hClose.Value));
        uiresume(dlg); delete(dlg);
    end

    function onCancel()
        newParams = [];
        uiresume(dlg); delete(dlg);
    end

    function onReset()
        hOpen.Value  = defaults.eyesOpenDur;
        hClose.Value = defaults.eyesCloseDur;
        updateTotal();
    end
end

function s = computeTotal(p)
    total = p.eyesOpenDur + p.eyesCloseDur;
    s = sprintf('总计 %d 秒 (约 %.1f 分钟)', total, total/60);
end
