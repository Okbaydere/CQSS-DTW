clc;
clear;
close all;

% Add CQT Toolbox path
addpath('CQT_toolbox_2013');

% File directory and extension
file_dir = ''; % file path 

% Text file to write the results
fid = fopen('test.txt', 'w');

% Get the list of files
file_list = dir(fullfile(file_dir, '*.wav'));

tic;

for i = 1:1 % numel(file_list)
    % Read the audio file
    disp(i)
    file_path = fullfile(file_dir, file_list(i).name);
    
    [Data, Fs] = audioread(file_path);
    Data = Data(:, 1);

    % Apply pre-emphasis filter
    premcoef = 0.97;
    Data = filter([1 ,-premcoef], 1, Data);

    % Calculate pitch values
    [Pitch, nf] = yaapt(Data, Fs, 1, [], 0, 2);

    nframejump = (10 * Fs) / 1000; % Value used to convert pitch values to audio samples.
    
    % Mark voiced parts as non-zero
    Pitch_voiced_parts_indices = find(Pitch > 0);
    % Preallocate for voiced segments
    max_segments = numel(Pitch_voiced_parts_indices);
    voiced_segments = zeros(max_segments, 2); 

    segment_start = Pitch_voiced_parts_indices(1);
    segment_count = 1;
    % Determine the voiced segments (word boundaries)
    for j = 2:length(Pitch_voiced_parts_indices)
        if Pitch_voiced_parts_indices(j) - Pitch_voiced_parts_indices(j-1) > 1
            % If index j = 17 and index j-1 = 13, then 17-13 > 1, indicating a new word beginning
            % Mark 13 as the end of the first word and set 17 as the start of the new word
            segment_end = Pitch_voiced_parts_indices(j-1);
            voiced_segments(segment_count, :) = [segment_start, segment_end];
            segment_start = Pitch_voiced_parts_indices(j);
            segment_count = segment_count + 1;
        end
    end
    % End index of the last word
    segment_end = Pitch_voiced_parts_indices(end);
    
    voiced_segments(segment_count, :) = [segment_start, segment_end];
    voiced_segments = voiced_segments(1:segment_count, :);

    voiced_audio_segments = nframejump * voiced_segments; % Voiced segments converted to audio samples

    CQT_mean = [];
    % Size of each word (end - start)
    segment_length = voiced_audio_segments(:,2)-voiced_audio_segments(:,1);

    for j = 1:size(voiced_audio_segments, 1)
        start_index = voiced_audio_segments(j, 1);
        end_index = voiced_audio_segments(j, 2);

        % Process each word separately
        wordData = Data(start_index:end_index);

        % CQSS parameters
        B = 60; % Divide the frequency spectrum in one octave into the specified number of parts. Higher value results in more detailed frequency spectrum analysis.
        fmax = Fs / 2; % default value
        fmin = fmax / 2^3 ; % 
        try
            % Calculate CQSS
            [LogP_absCQT] = cqcc(wordData, Fs, B, fmax, fmin);

            % Calculate the mean
            CQT_mean(end+1, :) = mean(LogP_absCQT,2);
        catch exception
            % Continue processing in case of an error
            fprintf('Error: An error occurred while processing file %s.\n', file_list(i).name);
            fprintf('Error message: %s\n', exception.message);
        end
    end
%----------------------------------------------------------------------------------------------------
%DTW CALCULATION PART
    
    % Get the size of the feature-extracted part
    row_count = size(CQT_mean, 1); 

    % DTW similarity matrix
    dtw_similarities = inf(row_count, row_count);
    minimum = inf;
    min_row1 = 0;
    min_row2 = 0;

    for j = 1:row_count
        for k = 1:row_count
            if j ~= k
                % Calculate DTW similarity
                dtw_similarity = dtw(CQT_mean(j, :), CQT_mean(k, :));
                dtw_similarities(j, k) = dtw_similarity;
                
                % Calculate the ratio by always dividing the larger value by the smaller one
                % to determine the selected lowest similarity values
                if (segment_length(j) > segment_length(k))
                    ratio = segment_length(j) / segment_length(k);
                else
                    ratio = segment_length(k) / segment_length(j);
                end

                if (ratio <= 1.5)
                    % Look for the lowest similarity value and select the words where the lowest values are found
                    if (dtw_similarity < minimum)
                        minimum = dtw_similarity;
                        min_row1 = j;
                        min_row2 = k;
                    end
                end
            end
        end
    end
    % Assuming the file name is s12_3-4. Split after '_' and then after '-', 
    % resulting in [3, 4] as the selected segment
    filename_parts = strsplit(file_list(i).name, '_');
    [~, filename_parts, ~] = fileparts(filename_parts);
    segment_parts = strsplit(filename_parts{2}, '-');
    selected_segment = [str2double(segment_parts{1}), str2double(segment_parts{2})];
    
    % Compare the file name with the selected segments, add 'H' next to it if different
    if (selected_segment(1) == min_row1 && selected_segment(2) == min_row2) || (selected_segment(2) == min_row1 && selected_segment(1) == min_row2)
        result = '';
    else
        result = 'H';
    end
    
    % Write to the text file.
    fprintf(fid, '%s %d-%d %s\n', file_list(i).name, min_row1, min_row2, result);

end

fclose(fid);
