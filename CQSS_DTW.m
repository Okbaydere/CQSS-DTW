clc;
clear;
close all;

% CQT Toolbox yolunu ekle
addpath('CQT_toolbox_2013');

% Dosya dizini ve uzantısı
file_dir = 'C:\Users\Oguz Kaaan\Desktop\CQSS-DTW\CQSS\pitch-based\medianfiltered';

% Sonuçları yazdırılacak metin dosyası
fid = fopen('test.txt', 'w');


% Dosya listesini al
file_list = dir(fullfile(file_dir, '*.wav'));



tic;

for i = 1:1 % numel(file_list)
    % Ses dosyasını oku
    disp(i)
    file_path = fullfile(file_dir, file_list(i).name);
    
    [Data, Fs] = audioread("C:\Users\Oguz Kaaan\Desktop\CQSS-DTW\CQSS\pitch-based\medianfiltered\sa1_1-2.wav");
    Data = Data(:, 1);

    % Ön vurgulama filtresi uygula
    premcoef = 0.97;
    Data = filter([1 ,-premcoef], 1, Data);

    % Pitch değerlerini hesapla
    [Pitch, nf] = yaapt(Data, Fs, 1, [], 0, 2);

    nframejump = (10 * Fs) / 1000; % Pitch değerlerini ses değerlerine dönüştürmek için kullanılan değer.
    
    %Sıfırdan büyük kısımları sesli olarak işaretle
    Pitch_voiced_parts_indices = find(Pitch > 0);
    % Voiced_segment için Preallocate yapılıyor
    max_segments = numel(Pitch_voiced_parts_indices);
    voiced_segments = zeros(max_segments, 2); 

    segment_start = Pitch_voiced_parts_indices(1);
    segment_count = 1;
  %sesli kısımlar belirleniliyor , kelime olarak ayrılıyor
    for j = 2:length(Pitch_voiced_parts_indices)
        if Pitch_voiced_parts_indices(j) - Pitch_voiced_parts_indices(j-1) > 1
            %örneğin indis j = 17, indis j-1 = 13 olsun 17-13>1 olur. 17 -> Yeni kelime başlangıcı
            % 13 ilk kelimenin bitişi yapılır ve yeni kelime belirlenmiş olur
            segment_end = Pitch_voiced_parts_indices(j-1);
            voiced_segments(segment_count, :) = [segment_start, segment_end];
            segment_start = Pitch_voiced_parts_indices(j);
            segment_count = segment_count + 1;
        end
    end
% son kelimenin end'i
    segment_end = Pitch_voiced_parts_indices(end);
    
    voiced_segments(segment_count, :) = [segment_start, segment_end];
    voiced_segments = voiced_segments(1:segment_count, :);

    voiced_audio_segments = nframejump * voiced_segments; % nframejump ile sinyale dönüştürülmüş sesli kısımlar

    CQT_mean = [];
    % her bir kelimenin boyutu (sesli kısmın bitişi - başlangıcı)
    segment_length = voiced_audio_segments(:,2)-voiced_audio_segments(:,1);

    for j = 1:size(voiced_audio_segments, 1)
        start_index = voiced_audio_segments(j, 1);
        end_index = voiced_audio_segments(j, 2);

        % Her bir kelime için işlemleri gerçekleştir
        wordData = Data(start_index:end_index);

        % CQSS parametreleri
        B = 60; % Bir oktavdaki frekans spektrumunu belirtilen sayıda parçaya böler. Sayı arttıkça frekans spektrumu daha detaylı analiz edilir.
        fmax = Fs / 2; %default değer
        fmin = fmax / 2^3 ; % 
        try
            % CQSS hesapla
            [LogP_absCQT] = cqcc(wordData, Fs, B, fmax, fmin);

            % Ortalama hesapla
            CQT_mean(end+1, :) = mean(LogP_absCQT,2);
        catch exception
            % Hata durumunda işleme devam et
            fprintf('Hata: Dosya %s işlenirken bir hata oluştu.\n', file_list(i).name);
            fprintf('Hata mesajı: %s\n', exception.message);
        end
    end
%----------------------------------------------------------------------------------------------------
%DTW HESAPLAMA KISMI
    
    %Özellik çıkarması yapılan kısımın boyutunu alıyor.
    row_count = size(CQT_mean, 1); 

    % DTW benzerlik matrisi
    dtw_similarities = inf(row_count, row_count);
    minimum = inf;
    min_row1 = 0;
    min_row2 = 0;

for j = 1:row_count
    for k = 1:row_count
        if j ~= k
            % DTW benzerlik hesaplaması
            dtw_similarity = dtw(CQT_mean(j, :), CQT_mean(k, :));
            dtw_similarities(j, k) = dtw_similarity;
            
            %Oranın her zaman büyük olanın küçük olanla bölünmesini
            %sağlayarak buluyor.
            if (segment_length(j) > segment_length(k))
                oran = segment_length(j) / segment_length(k);
            else
                oran = segment_length(k) / segment_length(j);
            end

            if (oran <= 1.5)
                % En düşük benzerlik değerine bakılıyor. Daha sonra seçilen
                % en düşük benzerlik değerlerinin bulunduğu kelimeleri
                % seçiyor
                if (dtw_similarity < minimum)
                    minimum = dtw_similarity;
                    min_row1 = j;
                    min_row2 = k;
                end
            end
        end
    end
end
    %örneğin dosya adı s12_3-4 olsun. _'den sonrasını ayırıp 3 ve 4 olacak
    %şekilde bakılıyor.
   filename_parts = strsplit(file_list(i).name, '_');
   [~, filename_parts, ~] = fileparts(filename_parts);
   segment_parts = strsplit(filename_parts{2}, '-');
    selected_segment = [str2double(segment_parts{1}), str2double(segment_parts{2})];
    
    % Dosyanın adıyla karşılaştırma yap eğer farklılarsa yanına H işareti
    % koy.
    if (selected_segment(1) == min_row1 && selected_segment(2) == min_row2) || (selected_segment(2) == min_row1 && selected_segment(1) == min_row2)
        sonuc = '';
    else
        sonuc = 'H';
    end
    
    % Text dosyasına yaz.
  
    fprintf(fid, '%s %d-%d %s\n', file_list(i).name, min_row1, min_row2, sonuc);

end


fclose(fid);


