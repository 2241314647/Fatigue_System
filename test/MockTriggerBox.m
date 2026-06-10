classdef MockTriggerBox < handle
% MOCKTRIGGERBOX v2  支持把 trigger 信息共享给 MockDataClient
% =========================================================
% v2 改动:
%   - 通过 MockTriggerStore (全局单例) 记录 trigger 事件
%   - MockDataClient 在生成数据时, 在对应时刻把 code 写入第 65 通道
%   - 这样 Mock 数据也能用 trigger 通道做事件锁定分析
% =========================================================

    methods
        function obj = MockTriggerBox()
            % 启动时清空 trigger 历史
            store = MockTriggerStore.getInstance();
            store.reset();
            fprintf('[MockTriggerBox] 模拟 TriggerBox 已启动 (含数据通道写入)\n');
        end

        function OutputEventData(~, code)
            % 写入: (当前时间, code)
            store = MockTriggerStore.getInstance();
            t = store.elapsedSec();   % 距离 reset 的秒数
            store.add(t, code);
            fprintf('[Trigger] code=%d @ t=%.3fs\n', code, t);
        end
    end
end
