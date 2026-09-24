%% ==========================================================
% Batch Processing Piezo Fiber Gesture Data
%
% 功能：
% 1. 批量读取120组csv
% 2. 50Hz Notch
% 3. 20Hz Lowpass
% 4. 保存处理后的CSV
% 5. 保存Lowpass20Hz结果图
%
%% ==========================================================


clear;
clc;
close all;


%% ================= 参数 =================

fs = 2000;


% 输入文件夹
input_folder = 'FBG+PIO';


% CSV结果保存
output_csv_folder = 'Results_CSV1';


% 图片保存
output_fig_folder = 'Results_Figure1';



% 创建文件夹
if ~exist(output_csv_folder,'dir')
    mkdir(output_csv_folder);
end


if ~exist(output_fig_folder,'dir')
    mkdir(output_fig_folder);
end



%% ================= 获取全部CSV =================


files = dir(fullfile(input_folder,'*.csv'));


num_files = length(files);


disp(['Total files = ',num2str(num_files)])



%% ================= 批量循环 =================


for i = 1:num_files


    %% 当前文件

    filename = files(i).name;

    filepath = fullfile(input_folder,filename);


    disp(['Processing: ',filename])



    %% ================= 读取 =================

    tbl = readtable(filepath);


    signal = tbl{:,2};


    signal = signal - mean(signal);


    N = length(signal);


    t = (0:N-1)'/fs;



    %% ================= 50Hz Notch =================


    wo = 50/(fs/2);

    bw = wo/35;


    [b_notch,a_notch] = iirnotch(wo,bw);


    signal_notch = filtfilt(...
        b_notch,...
        a_notch,...
        signal);



    %% ================= 20Hz Lowpass =================


    fc = 20;


    [b_lp,a_lp] = butter(4,...
        fc/(fs/2),...
        'low');


    signal_lp = filtfilt(...
        b_lp,...
        a_lp,...
        signal_notch);



    %% ================= Hilbert =================


    analytic_signal = hilbert(signal_lp);


    env_hilbert = abs(analytic_signal);


    env_hilbert = env_hilbert ./ max(env_hilbert);



    %% ================= RMS =================


    win_ms = 200;


    win = round(win_ms/1000*fs);


    env_rms = sqrt(...
        movmean(signal_lp.^2,win));


    env_rms = env_rms ./ max(env_rms);



    %% ================= 保存CSV =================


    result = table(...
        t,...
        signal,...
        signal_notch,...
        signal_lp,...
        env_hilbert,...
        env_rms,...
        ...
        'VariableNames',...
        {'Time',...
        'Raw',...
        'Notch50Hz',...
        'Lowpass20Hz',...
        'Hilbert',...
        'RMS'});


    

    % 文件名

    [~,name,~]=fileparts(filename);


    save_name = fullfile(...
        output_csv_folder,...
        [name,'_Processed.csv']);


    writetable(result,save_name);



    %% ================= 保存Lowpass图 =================


    fig = figure(...
        'Visible','off',...
        'Position',[200 200 900 400]);


    plot(t,signal_lp,...
        'LineWidth',1.2);


    xlabel('Time (s)')


    ylabel('Voltage(V)')


    title([name,...
        '  Lowpass 20Hz'])


    grid on



    fig_name = fullfile(...
        output_fig_folder,...
        [name,'_Lowpass20Hz.png']);



    saveas(fig,fig_name);


    close(fig);



end



disp('================================')
disp('All processing finished!')
disp(['CSV saved in: ',output_csv_folder])
disp(['Figures saved in: ',output_fig_folder])
disp('================================')