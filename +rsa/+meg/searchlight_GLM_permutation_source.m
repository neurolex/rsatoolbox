% [p_paths, p_median_paths] = searchlight_GLM_permutation_source(RDMPaths, glm_paths, models, slSTCMetadatas, lagSTCMetadatas, nPermutations, threshold, userOptions)
%
% Cai Wingfield 2015-04
function [p_paths, p_median_paths] = searchlight_GLM_permutation_source(RDMPaths, glm_paths, models, slSTCMetadatas, lagSTCMetadatas, nPermutations, threshold, userOptions)

    import rsa.*
    import rsa.meg.*
    import rsa.rdm.*
    import rsa.stat.*
    import rsa.util.*
    
    
    %% Things to be returned whether or not work is done
    
    for chi = 'LR'
        
        glmMeshDir = fullfile(userOptions.rootPath, 'Meshes');
        
        p_file_name = sprintf('p_mesh-%sh', lower(chi));
        p_paths.(chi) = fullfile(glmMeshDir, p_file_name);
        
        p_median_file_name = sprintf('p_mesh_median-%sh', lower(chi));
        p_median_paths.(chi) = fullfile(glmMeshDir, p_median_file_name);
        
    end%for
    
    
    %% Precompute permutations for speed
    
    prints('Precomputing RDM index permutations...');
    
    % Indices for lower-triangular-form of RDM.
    lt_indices = 1:numel(vectorizeRDM(models(1).RDM));
    
    % Indices for squareform of RDM.
    sf_indices = squareform(lt_indices);
    
    % Preallocate
    lt_index_permutations = nan(numel(lt_indices), nPermutations);
    
    % Generate some permutations
    for p = 1:nPermutations
        lt_index_permutations(:, p) = squareform(randomizeSimMat(sf_indices));
    end
    
    
    %% Both hemispheres separately.
    
    for chi = 'LR'
        
        %% Load data RDMs
        
        prints('Loading %sh data RDMs from "%s"...', lower(chi), RDMPaths.(chi));
        
        slRDMs = directLoad(RDMPaths.(chi));
        
        [nVertices, nTimepoints_data] = size(slRDMs);
        lag_in_timepoints = (lagSTCMetadatas.(chi).tmin - slSTCMetadatas.(chi).tmin) / lagSTCMetadatas.(chi).tstep;

        [modelStack, nTimepoints_overlap] = stack_and_offset_models(models, lag_in_timepoints, nTimepoints_data);

        nModels = size(modelStack{1}, 1);
        % + 1 for that all-1s predictor
        nBetas = nModels + 1;

        
        %% Calculate distributions of betas at each vertex

        % Preallocate
        h0_betas = zeros(nVertices, nTimepoints_overlap, nBetas, nPermutations);

        prints('Computing beta null distributions at %d vertices...', nVertices);
            
        parfor t = 1:nTimepoints_overlap
        
            % Temporarily disable this warning
            %warning_id = 'stats:glmfit:IllConditioned';
            w = warning('off', 'all');
            
            prints('Timepoint %d of %d...', t, nTimepoints_overlap);
            
            t_relative_to_data = t + lag_in_timepoints;
            
            for v = 1:nVertices
                
                unscrambled_data_rdm = slRDMs(v, t_relative_to_data).RDM;

                for p = 1:nPermutations
		
                    scrambled_data_rdm = unscrambled_data_rdm(lt_index_permutations(:, p));

                    h0_betas(v, t, :, p) = glmfit( ...
                        modelStack{t}', ...
                        scrambled_data_rdm', ...
                        'normal');
                end%for
                
                % Occasional feedback
                if feedback_throttle(10, v, nVertices)
                    prints('%2.0f%% of vertices covered for timepoint %d.', percent(v, nVertices), t);
                end
            end%for
        
            % Re-enable warning
            %warning('on', warning_id);
            warning(w);
        end%for
        
        
        %% Pool and save H0-distributions
        
        % Save null-distributions pre pooling
        gotoDir(userOptions.rootPath, 'Stats');
        save(sprintf('unpooled-h0-%sh', lower(chi)), 'h0_betas', '-v7.3');
        
        % We'll pool the distrubution across timepoints and permutations.
        % This is based on the assumption that the distributions of
        % beta values should be independent of time.
        % We may (or may not) want to make the same assumption about
        % space, but we won't do that for now.
        
        % But first we need to slice out the betas for the all-1s
        % predictor.
        h0_betas = h0_betas(:, :, 2:end, :);
        
        % We want the distribution of maximum-over-models betas at each
        % vertex.
        % (nVertices, nTimepoints_overlap, nPermutations)
        h0_betas = max(h0_betas, 3);
        % (nVertices, nTimepoints_overlap * nPermutations)
        h0_betas = reshape(h0_betas, ...
            nVertices, nTimepoints_overlap * nPermutations);
        
        % Save null-distributions post pooling
        save(sprintf('pooled-h0-%sh', lower(chi)), 'h0_betas', '-v7.3');
        
        
        %% Calculate beta threshold
        beta_thresholds = zeros(nVertices, 1);
        for v = 1:nVertices
           beta_thresholds(v) = quantile(h0_betas(v, :), 1 - threshold);
        end
        
        prints('Selecting top %2.1f centile of the null distribution at each vertex.', 100 * (1 - threshold));
        prints('This gives a median GLM coefficient threshold of %f over vertices.', median(beta_thresholds));

        
        %% Threshold beta maps
        
        prints('Loading actual %sh beta values...', lower(chi));
        
        glm_mesh_betas = directLoad([glm_paths.betas.(chi) '.mat'], 'glm_mesh_betas');
        
        
    
    end%for:chi

end%function
