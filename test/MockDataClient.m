classdef MockDataClient < handle
% MOCKDATACLIENT v3  模拟博瑞康设备
% v3 改动:
%   - 集成 MockTriggerStore: 在第 65 通道写 trigger code
%   - 在 trigger=31 (错误反馈) 时刻叠加 FRN/Pe 样波形
%   - 这样 Mock 跑 ErrP 范式时, 分析模块也能看到信号
% =========================================================

    properties
        nChan         = 65;
        sampleRate    = 500;
        bufferSize    = 30;
        startTime
        isOpen        = false;
        syntheticEEG  = false;
        rngSeed       = 42;
    end

    methods
        function obj = MockDataClient(varargin)
            if numel(varargin) >= 3, obj.nChan      = varargin{3}; end
            if numel(varargin) >= 4, obj.sampleRate = varargin{4}; end
            if numel(varargin) >= 5, obj.bufferSize = varargin{5}; end
        end

        function Open(obj)
            obj.startTime = tic;
            obj.isOpen    = true;
            if obj.syntheticEEG
                fprintf('[MockDataClient] 启动 (伪 EEG + trigger 通道)\n');
            else
                fprintf('[MockDataClient] 启动 (纯噪声 + trigger 通道)\n');
            end
        end

        function Close(obj)
            obj.isOpen = false;
            fprintf('[MockDataClient] 已关闭\n');
        end

        function data = GetBufferData(obj)
            if ~obj.isOpen
                data = [];
                return;
            end

            elapsed   = toc(obj.startTime);
            available = min(elapsed, obj.bufferSize);
            nSamples  = round(available * obj.sampleRate);
            if nSamples < 1
                data = zeros(obj.nChan, 0);
                return;
            end

            % 生成 EEG (前 nEEG 通道)
            if obj.syntheticEEG
                data = obj.generateSyntheticEEG(nSamples);
            else
                data = obj.generatePureNoise(nSamples);
            end

            % --- 关键新增: 把 trigger 写入第 65 通道 ---
            data = obj.writeTriggers(data, nSamples);

            % --- 关键新增: 在 trigger=31 时刻叠加 ErrP 样波形 ---
            if obj.syntheticEEG
                data = obj.injectErrPSignals(data, nSamples);
            end
        end
    end

    methods (Access = private)

        function data = generatePureNoise(obj, nSamples)
            data = randn(obj.nChan, nSamples) * 10;
            data(1, :) = 1:nSamples;
        end

        function data = generateSyntheticEEG(obj, nSamples)
            fs = obj.sampleRate;
            t  = (0:nSamples-1) / fs;
            nEEG = min(obj.nChan - 1, 64);
            alphaWeights = linspace(0.3, 1.5, nEEG)';

            data = zeros(obj.nChan, nSamples);
            for ch = 1:nEEG
                pinkNoise = pink_noise(nSamples) * 5;
                data(ch, :) = pinkNoise;
            end

            alphaFreq      = 10;
            alphaEnvelope  = 1 + 0.5 * sin(2*pi*0.3*t);
            for ch = 1:nEEG
                phase  = (ch-1) * 0.1;
                ampl   = alphaWeights(ch) * 8;
                data(ch, :) = data(ch, :) + ...
                              ampl * sin(2*pi*alphaFreq*t + phase) .* alphaEnvelope;
            end

            thetaFreq = 6;
            for ch = 1:nEEG
                data(ch, :) = data(ch, :) + ...
                              2 * sin(2*pi*thetaFreq*t + ch*0.05);
            end

            data(1:nEEG, :) = data(1:nEEG, :) + 0.5 * randn(nEEG, nSamples);
            data(1:nEEG, :) = data(1:nEEG, :) * 3;

            if obj.nChan >= 65
                data(65, :) = 0;
            end
        end

        % --- 写 trigger 到第 65 通道 (脉冲式: 1 个采样点写 code, 其余 0) ---
        function data = writeTriggers(obj, data, nSamples)
            store = MockTriggerStore.getInstance();
            events = store.getEvents();
            if isempty(events), return; end
            if obj.nChan < 65, return; end

            fs = obj.sampleRate;
            for k = 1:size(events, 1)
                eventTime = events(k, 1);
                code      = events(k, 2);
                sampleIdx = round(eventTime * fs);

                if sampleIdx >= 1 && sampleIdx <= nSamples
                    % 写 1 个采样点的脉冲(模拟真设备 trigger 通道行为)
                    data(65, sampleIdx) = code;
                end
            end
        end

        function data = injectErrPSignals(obj, data, nSamples)
            % 在 trigger=31 时刻叠加 FRN 样波形(模拟错误相关电位)
            store = MockTriggerStore.getInstance();
            events = store.getEvents();
            if isempty(events), return; end

            fs = obj.sampleRate;
            nEEG = min(obj.nChan - 1, 64);

            % FRN 模板: 300 ms 处一个 -6µV 的负峰, 400 ms 处 +4µV 的正峰
            % 通道权重: 前额(1-20)、中央(21-40) 强, 后部(41-64)弱
            tFRN = (-0.2:1/fs:0.6);    % -200~+600 ms
            % 高斯包络的负波 (FRN, 300ms) + 正波 (Pe, 400ms)
            frnWave = -6 * exp(-((tFRN - 0.30)/0.05).^2) + ...
                       4 * exp(-((tFRN - 0.40)/0.07).^2);

            chWeights = ones(nEEG, 1);
            chWeights(1:20) = 1.2;     % 前额中央增强
            chWeights(21:40) = 1.0;
            chWeights(41:end) = 0.4;   % 后部弱

            for k = 1:size(events, 1)
                eventTime = events(k, 1);
                code      = events(k, 2);

                if code ~= 31, continue; end   % 只在错误反馈注入

                centerSample = round(eventTime * fs);
                startSample  = centerSample - round(0.2 * fs);
                endSample    = centerSample + round(0.6 * fs) - 1;

                % 边界 clip
                addStart = max(1, startSample);
                addEnd   = min(nSamples, endSample);
                if addEnd < addStart, continue; end

                % 对应在 frnWave 里的索引
                waveStart = addStart - startSample + 1;
                waveEnd   = waveStart + (addEnd - addStart);
                if waveEnd > length(frnWave), waveEnd = length(frnWave); addEnd = addStart + (waveEnd-waveStart); end

                wavSlice = frnWave(waveStart:waveEnd);

                % 加到每个 EEG 通道, 带权重
                for ch = 1:nEEG
                    data(ch, addStart:addEnd) = data(ch, addStart:addEnd) + ...
                                                 chWeights(ch) * wavSlice;
                end
            end
        end
    end
end


% =========================================================
function x = pink_noise(n)
    white = randn(1, n);
    X = fft(white);
    nHalf = floor(n/2);
    f = 1:nHalf;
    scale = 1 ./ sqrt(f);
    X(2:nHalf+1) = X(2:nHalf+1) .* scale;
    if mod(n, 2) == 0
        X(end:-1:nHalf+2) = conj(X(2:nHalf));
    else
        X(end:-1:nHalf+2) = conj(X(2:nHalf+1));
    end
    x = real(ifft(X));
    if std(x) > 0
        x = x / std(x);
    end
end
