% 压电纤维信号分析平台 (Piezoelectric Fiber Signal Analysis Platform)
% 基于“首次边缘触发”的批量对齐算法 (整体一次性运行)
% 适配最新列名格式: Time, Raw, Notch50Hz, Lowpass20Hz, Hilbert, RMS
clc; clear; close all;

% --- 1. 文件夹与参数设置 ---
input_dir = 'Results_CSV1';            % 原始CSV文件存放的文件夹路径
output_data_dir = 'aligned_data1';  % 对齐后数据的保存文件夹
output_plot_dir = 'aligned_plots1'; % 对齐后图片的保存文件夹

if ~exist(output_data_dir, 'dir')
    mkdir(output_data_dir);
end
if ~exist(output_plot_dir, 'dir')
    mkdir(output_plot_dir);
end

files = dir(fullfile(input_dir, '*.csv'));
num_files = length(files);
if num_files == 0
    error('未找到CSV文件，请检查 input_dir 路径设置是否正确。');
end

fs = 2000;                    % 采样率 2000Hz
move_time = 1;                % 目标截取长度 1s
points_move = move_time * fs; % 对应 2000 个采样点

fprintf('分析平台启动，采用“首次边缘触发”算法，共 %d 个文件...\n', num_files);

% --- 2. 批量处理核心循环 ---
for i = 1:num_files
    file_name = files(i).name;
    [~, name_no_ext, ~] = fileparts(file_name);
    file_path = fullfile(input_dir, file_name);
    
    try
        data = readtable(file_path);
    catch
        fprintf('读取失败，跳过: %s\n', file_name);
        continue;
    end
    
    % 提取低通滤波后的原始信号作为触发判定依据
    try
        signal = data.Lowpass20Hz; 
    catch
        fprintf('未找到 Lowpass20Hz 列，跳过: %s\n', file_name);
        continue;
    end
    
    % --- 首次边缘触发算法 (First Edge Trigger) ---
    % 1. 划定基线区间：0.2s 到 0.25s (点401到500)，避开启动毛刺，且在真实运动前
    baseline_start = round(0.2 * fs) + 1;
    baseline_end = round(0.25 * fs);
    baseline_data = signal(baseline_start:baseline_end);
    
    baseline_mean = mean(baseline_data);
    baseline_std = std(baseline_data);
    
    % 2. 设定自适应阈值。加入 0.5e-4 的兜底值，防止基线绝对平滑导致阈值过低
    threshold_offset = max(6 * baseline_std, 0.5e-4); 
    
    % 3. 设定受限搜索区域：0.25s 到 2.0s (点501到4000)
    % 彻底无视 2.0s 之后的机械震荡和残余应力波动
    search_start = baseline_end + 1;
    search_end = min(round(2.0 * fs), length(signal)); 
    
    start_idx = 0;
    consecutive_points = 10; % 连续10个点(5ms)偏离基线即认为运动开始
    count = 0;
    
    for j = search_start:search_end
        % 判断依据：当前点的绝对幅值是否显著偏离基线
        if abs(signal(j) - baseline_mean) > threshold_offset
            count = count + 1;
            if count >= consecutive_points
                % 找到触发点，向前回溯，保留完整的起始边缘
                trigger_point = j - consecutive_points + 1;
                % 往前多截取 0.05s (100个点)，保证捕捉到信号刚开始变化的瞬间
                start_idx = max(1, trigger_point - round(0.05 * fs)); 
                break;
            end
        else
            count = 0;
        end
    end
    
    % --- 3. 截取与对齐 ---
    % 如果在 2s 内没找到触发点（例如 180度 不动的情况），给一个默认截取位置
    if start_idx == 0 || (start_idx + points_move - 1 > height(data))
        start_idx = round(0.3 * fs); % 默认从 0.3s 处开始截取 1s
        if start_idx + points_move - 1 > height(data)
            start_idx = height(data) - points_move + 1;
        end
    end
    
    % 截取 1s 数据窗
    aligned_data = data(start_idx : start_idx + points_move - 1, :);
    % 时间轴重新归零
    aligned_data.Time = (0 : points_move - 1)' / fs;
    
    % --- 4. 保存CSV ---
    writetable(aligned_data, fullfile(output_data_dir, ['Aligned_', file_name]));
    
    % --- 5. 保存结果图 ---
    fig = figure('Visible', 'off', 'Position', [100, 100, 800, 400]); 
    plot(aligned_data.Time, aligned_data.Lowpass20Hz, 'LineWidth', 1.5, 'Color', '#D95319');
    
    title(sprintf('Aligned Signal (Edge Trigger): %s', name_no_ext), 'Interpreter', 'none', 'FontSize', 14);
    xlabel('Time (s)', 'FontSize', 12);
    ylabel('Amplitude (Lowpass20Hz)', 'FontSize', 12);
    grid on;
    
    % 强制显示纵坐标刻度，确保 Y 轴数值展示清晰
    ax = gca;
    ax.YAxis.Visible = 'on'; 
    ax.YTickMode = 'auto'; 
    set(gca, 'FontSize', 12);
    
    exportgraphics(fig, fullfile(output_plot_dir, ['Plot_', name_no_ext, '.png']), 'Resolution', 300); 
    close(fig);
    
    fprintf('处理完成 [%d/%d]: %s (对齐起点: %.3f s)\n', i, num_files, file_name, start_idx/fs);
end

fprintf('\n批处理完成！利用首次边缘触发逻辑有效剔除了后段机械震荡干扰。\n');