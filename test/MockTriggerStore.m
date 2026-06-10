classdef MockTriggerStore < handle
% MOCKTRIGGERSTORE  单例: 共享 trigger 事件给 MockDataClient
% =========================================================
% 作为 MockTriggerBox 和 MockDataClient 之间的桥梁。
% MockTriggerBox.OutputEventData(code) → 写入这里
% MockDataClient.GetBufferData         → 读取这里, 把 code 写入第 65 通道
% =========================================================

    properties
        startTime
        eventList    % [Nx2]: [time_sec, code]
    end

    methods (Access = private)
        function obj = MockTriggerStore()
            obj.startTime = tic;
            obj.eventList = zeros(0, 2);
        end
    end

    methods
        function reset(obj)
            obj.startTime = tic;
            obj.eventList = zeros(0, 2);
        end

        function add(obj, t, code)
            obj.eventList(end+1, :) = [t, code];
        end

        function t = elapsedSec(obj)
            t = toc(obj.startTime);
        end

        function evt = getEvents(obj)
            evt = obj.eventList;
        end
    end

    methods (Static)
        function obj = getInstance()
            persistent instance;
            if isempty(instance) || ~isvalid(instance)
                instance = MockTriggerStore();
            end
            obj = instance;
        end
    end
end
