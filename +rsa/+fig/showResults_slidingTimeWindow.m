% Displays results and also plots them by reading in the xls files
% generated by permutation steps in sliding time window analysis.
%
% which_map should be 't' for t-maps and 'r' for r-maps

% Written by IZ 03/13
function showResults_slidingTimeWindow(userOptions, model, which_map)

import rsa.*
import rsa.fig.*
import rsa.fmri.*
import rsa.rdm.*
import rsa.sim.*
import rsa.spm.*
import rsa.stat.*
import rsa.util.*

nMasks = numel(userOptions.maskNames);
modelName = model.name;
if userOptions.partial_correlation
    modelName = [modelName, '_partialCorr'];
end

disp('Second Level Analysis Results: ')

for mask=1:nMasks
    thisMask = userOptions.maskNames{mask};
    
    currentTimeWindow = userOptions.maskTimeWindows{mask};

    %% random effects
    if strcmp(userOptions.groupStats,'RFX')
        
        input_path = fullfile(userOptions.rootPath, 'Results', 'RandomEffects');
        
        try
            all_clusters_pos = csvread(fullfile(input_path,'ClusterStats',[modelName '-' thisMask '-cluster_stats-pos-' which_map '.csv']));
        catch
            error('Cannot read cluster statistics file.');
        end
        
        try
            base_map = csvread(fullfile(input_path, [modelName '-' thisMask '-uncorrected_' which_map '.csv']));
        catch
            error('Cannot read uncorrected map file.');
        end
        
        try
            thresh_map = csvread(fullfile(input_path, [modelName '-' thisMask '-corrected_' which_map '.csv']));
        catch
            error('Cannot read corrected map file.');
        end
        
        disp([thisMask ':']);
        disp(['Total clusters = ' num2str(size(all_clusters_pos,1))]);
        for i=1:size(all_clusters_pos,1)
            disp(['Cluster mass: ' num2str(all_clusters_pos(i,1)) ' Corresponding p value:  ' num2str(all_clusters_pos(i,2))]);
        end
        
        time = userOptions.STCmetaData.tmin*1000;
        for j=1:size(base_map,1)
            xticks{j} = num2str([time time+userOptions.temporalSearchlightTimestep]);
            time = time+ userOptions.temporalSearchlightTimestep;
        end
        
        if length(xticks) > 25
            xtickIncrement = ceil(length(xticks)/15);
        else
            xtickIncrement = userOptions.temporalSearchlightTimestep;
        end
        
        
        % plots
        fprintf('Plotting...')
        subplot(2,1,2)
        hold all
        p1 = plot(thresh_map);
        set(gca, 'Xtick', 1:xtickIncrement:size(xticks,2));
        xticklabel = xticks(1:xtickIncrement:size(xticks,2));
        set(gca, 'XtickLabel', strtok(xticklabel));
        title(['Corrected ' which_map '-map'])
        
        subplot(2,1,1)
        p2 = plot(base_map);
        set(gca, 'Xtick', 1:xtickIncrement:size(xticks,2));
        xticklabel = xticks(1:xtickIncrement:size(xticks,2));
        set(gca, 'XtickLabel', strtok(xticklabel));
        title(['Uncorrected ' which_map '-map'])
        hold all
        
        %% fixed effects
    else
        input_path = fullfile(userOptions.rootPath, 'Results', 'FixedEffects');
        filename = [modelName '-' thisMask '-'];
        try
            r_values = csvread(fullfile(input_path,[filename, 'r.csv'])); 
        catch
            error('Cannot read r values file.');
        end
        
        try
            thresh_r = csvread(fullfile(input_path,[filename, 'thresholded_r.csv']));
        catch
            error('Cannot read thresholded r value file.');
        end
        
        try
            cluster_stats = csvread(fullfile(input_path, 'ClusterStats', [filename, 'clusterstats.csv']));
        catch
            error('Cannot read cluster stats file.');
        end
        
        disp([thisMask ':']);
        
        time = userOptions.STCmetaData.tmin*1000;
        for j=1:size(r_values,2)            
            xticks{j} = num2str([time time+userOptions.temporalSearchlightTimestep]);
            time = time+userOptions.temporalSearchlightTimestep;
        end
        
        if length(xticks) > 25
            xtickIncrement = ceil(length(xticks)/15);
        else
            xtickIncrement = userOptions.temporalSearchlightTimestep;
        end

        %plots
        disp(['Plotting ' thisMask '...']);
        subplot(2,1,1)
        p1 = plot(r_values);
        set(gca, 'Xtick', 1:xtickIncrement:size(xticks,2));
        xticklabel = xticks(1:xtickIncrement:size(xticks,2));
        set(gca, 'XtickLabel', strtok(xticklabel));
        title('r values');
        hold all;
        
        subplot(2,1,2)
        p2 = plot(thresh_r);
        set(gca, 'Xtick', 1:xtickIncrement:size(xticks,2));
        xticklabel = xticks(1:xtickIncrement:size(xticks,2));
        set(gca, 'XtickLabel', strtok(xticklabel));
        title('thresholded r-values (primary threshold)');
        hold all;
        
        for i=1:size(cluster_stats,1)
            disp([' - Cluster ' num2str(i) ' - mass: ' num2str(cluster_stats(i,1)) ' - p value: ' num2str(cluster_stats(i,2))]);
        end
        
    end
    
    
    if mask<nMasks %% assumption: masks are named in pairs in projectOptions
        nextMask = userOptions.maskNames{mask+1};
        if strcmp(strtok(nextMask,'-'),strtok(thisMask,'-'))
            hold all;
            check=true;
        else
            if check
                if mask>1
                    prevMask = userOptions.maskNames{mask-1};
                    hleg = legend(prevMask, thisMask,'Location','Best');
                    set(p1,'Color','red')
                    set(p2,'Color','red')
                end
            end
            figure;
        end
    elseif mask==nMasks
        prevMask = userOptions.maskNames{mask-1};
        hleg = legend(prevMask, thisMask,'Location','Best');
    end
end
disp('Done!');
end