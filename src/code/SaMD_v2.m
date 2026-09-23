clear; clc; close all;
rng(1);

%% CLEANING

% % 1. VISUALIZING NUMBER OF NaNs

data = readtable('TBI_Full_Dataset for analysis 4-9-26.xlsx');

chunks = {1:25, 26:50, 51:width(data)};
titles = {'Features 1-25', 'Features 26-50', 'Features 51-end'};
missing_count = sum(ismissing(data));       % Count the number of missing values for each variable
vars = data.Properties.VariableNames;

for i = 1:length(chunks)
    idx = chunks{i};

    figure;                                     % Open a new figure
    b = bar(missing_count(idx));        % Generate a bar plot to visualize amount of missing data
    xtips = b.XEndPoints;                 % X coordinates of the endpoints of the bars in the first bar plot
    ytips = b.YEndPoints;                 % Y coordinates of the endpoints of the bars in the first bar plot
    labels = string(ytips); 
    text(xtips, ytips, labels, 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'bottom');         % Label the top of each bar with the amount of missing data
    set(gca, 'XTick', 1:length(idx)); 
    set(gca, 'XTickLabel', vars(idx));
    xticklabels(vars(chunks{i})); % Bar plot X-axis label with variable names, 40 degree angle
    xtickangle(60);
    title('Missing Data: ', titles{i});% Bar plot title
    ylabel('Total NaNs');                       % Bar plot Y-axis label

end

% % 2. CORRELATION HEATMAP

% Isolate the biomarker features only
biomarker_indices = [42:53, 57:width(data)];
biomarker_data = data(:, biomarker_indices);

% Get numeric data and its variable names
numeric_data = biomarker_data{:, varfun(@isnumeric, biomarker_data, 'OutputFormat','uniform')};
var_names = biomarker_data.Properties.VariableNames(varfun(@isnumeric, biomarker_data, 'OutputFormat','uniform'));

% Generate and plot the correlation matrix
corr_mat = corr(numeric_data, 'Rows', 'pairwise');
figure;
h = heatmap(var_names, var_names, corr_mat);
h.Title = 'Feature Correlation Heatmap';
h.Colormap = parula;

% Find redundant pairs to decide which to keep
[row, col] = find(abs(corr_mat) > 0.85 & abs(corr_mat) < 1);
redundant_pairs = [var_names(row)', var_names(col)'];

if ~isempty(redundant_pairs)
    sorted_pairs = sort(string(redundant_pairs), 2);
    unique_pairs = unique(sorted_pairs, 'rows');
    
    fprintf('High Correlation (> 0.85) Pairs found:\n');
    disp(unique_pairs);
else
    fprintf('No high correlation pairs found above 0.85.\n');
end


%% PREPROCESSING

% % 1. CREATE COMBINED COLUMN FOR 'FIRST 24H' FROM 0H AND 24H

% Rename a variable
data = renamevars(data, {'Tau0h', 'Tau24h'}, {'Tau0H', 'Tau24H'});

% List all biomarkers
biomarkers = {'ASC', 'Caspase_1', 'IL_18', 'IL_1b', 'Tau', 'GFAP', 'UCHL1', 'NFL', 'pTaut'};

for i = 1:length(biomarkers)
    col0    = [biomarkers{i}, '0H'];
    col24   = [biomarkers{i}, '24H'];
    new_col = [biomarkers{i}, '_First 24h'];

    has0  = ismember(col0,  data.Properties.VariableNames);
    has24 = ismember(col24, data.Properties.VariableNames);

    % If both 0h and 24h values are present, use the mean
    if has0 && has24
        v0  = data.(col0);
        v24 = data.(col24);

        combined = nan(height(data), 1);
        both_present = ~isnan(v0) & ~isnan(v24);
        only0_present = ~isnan(v0) &  isnan(v24);
        only24_present = isnan(v0) & ~isnan(v24);

        combined(both_present) = (v0(both_present) + v24(both_present)) / 2;
        combined(only0_present) = v0(only0_present);
        combined(only24_present) = v24(only24_present);

        data.(new_col) = combined;

    % If only one is present, use that value
    elseif has0 && ~has24
        data.(new_col) = data.(col0);
    elseif ~has0 && has24
        data.(new_col) = data.(col24);
    end
end

% If none is present, impute using KNN

 
% % 2. LOG SCALE TO HANDLE OUTLIERS

% Log scale for high variance, crucial before running UMAP or PAM
% Only transform non-NaN values; NaN rows are for KNN
for i = 1:length(biomarkers)
    target     = [biomarkers{i}, '_First 24h'];
    col_data   = data.(target);
    is_valid   = ~isnan(col_data);
    col_data(is_valid) = log10(col_data(is_valid) + 1);
    data.(target) = col_data;
end


% % 3a. COMBINE AGE IN MONTHS TO AGE IN YEARS

if ismember('AgeInMonths', data.Properties.VariableNames) && ismember('Age_inYears', data.Properties.VariableNames);
    conversion = ~isnan(data.AgeInMonths) & isnan(data.Age_inYears);
    data.Age_inYears(conversion) = data.AgeInMonths(conversion) / 12;
else 
    disp('Age columns not found.')
end


% % 3b. FEATURE SELECTION 

% Quantitative Clinical Labels
numeric_clinical = {'Age_inYears', 'Weight', 'Height', 'BMI', 'BSA', ...
                    'GCS', 'HospitalStay_LOS', 'ICU_LOS', ...
                    'PRISMScore', 'ISSScore', 'MarshallScoreAdmission'};

% Biomarkers (Strictly 24h)
biomarker_24h_vars = strcat(biomarkers, '_First 24h');

% Binary/Qualitative to keep
binary_vars = {'AbusiveHeadInjuty', 'PolytraumaY_N', 'ICPMonitoringY_N', ...
               'CSFDiversionY_N', 'MannitolOr3_SalineY_N', 'SeizuresY_N', ...
               'HypoxicEvent', 'HyperventilationY_N', 'CardiacArrestY_N', ...
               'IMVY_N', 'CraniectomyY_N', 'HypothermiaY_N', ...
               'HistoryOfPriorTBIY_N', 'FeverY_N', 'AnalgesicsY_N', ...
               'Anti_inflammatoryY_N', 'SedativesY_N', 'CTAbnormality'};

qualitative_to_encode = {'Mortality', 'Severity', 'Gender', 'Ethnicity', 'Race'};

% % 3c. ONE-HOT ENCODING & BINARY CONVERSION
% Initialize data_encoded with the quantitative variables
data_encoded = data(:, [numeric_clinical, biomarker_24h_vars]); 

% Convert Y/N to 1/0
for i = 1:length(binary_vars)
    var = binary_vars{i};
    if ismember(var, data.Properties.VariableNames)
        % 1. Convert to string and trim any hidden spaces
        clean_data = strtrim(string(data.(var))); 
        
        % 2. Check for 'Y', 'Yes', or '1' to be safe
        is_yes = strcmpi(clean_data, 'Yes') | (clean_data == "1");
        
        data_encoded.(var) = double(is_yes);
    end
end

% One-Hot Encode (Qualitative to numerical)
for i = 1:length(qualitative_to_encode)
    var = qualitative_to_encode{i};
    if ismember(var, data.Properties.VariableNames)
        cats       = categorical(data.(var));
        temp_dummy = dummyvar(cats);                    % k columns
        temp_dummy = temp_dummy(:, 1:end-1);            % drop last (reference category)

        cat_labels = categories(cats);
        new_names  = strcat(var, '_', string(cat_labels(1:end-1)'));

        dummy_table  = array2table(temp_dummy, 'VariableNames', new_names);
        data_encoded = [data_encoded, dummy_table]; 
    else
        fprintf('Warning: qualitative variable "%s" not found — skipped.\n', var);
    end
end

target_vars = data_encoded.Properties.VariableNames;
fprintf('Feature matrix ready: %d patients × %d features\n', height(data_encoded), length(target_vars));


% % 4. IMPUTE MISSING DATA

% Impute first, then normalize 
X_raw = table2array(data_encoded);

% Temporarily range-normalize just for KNN distance computation 
[X_norm_for_knn, C_knn, S_knn] = normalize(X_raw, 'range');
imputed_norm = fillmissing(X_norm_for_knn, 'knn', 5);

% Rescale back to original units 
X_imputed_raw = (imputed_norm .* S_knn) + C_knn;
data_imputed = array2table(X_imputed_raw, 'VariableNames', target_vars);
fprintf('KNN imputation complete. Missing values remaining: %d\n', sum(sum(ismissing(data_imputed))));


% % 5. Z-SCORE NORMALIZATION
% We normalize the imputed table with all the encoded variables)
% instead of the original 'data' table.

X_final    = table2array(data_imputed);
X_zscored  = normalize(X_final);   % column-wise z-score
data_normalized = array2table(X_zscored, 'VariableNames', target_vars);
fprintf('Z-score normalization complete: %d features.\n', width(data_normalized));

% NOTES: 
% use 'data' for side notes section in the GUI
% use 'data_normalized' for algorithm


%% FEATURE REDUCTION: PCA

set(groot, 'defaultTextInterpreter', 'none');
set(groot, 'defaultAxesTickLabelInterpreter', 'none');
set(groot, 'defaultLegendInterpreter', 'none');

% Feature list
biomarkers = {'ASC_First 24h','Caspase_1_First 24h','IL_1b_First 24h',...
              'Tau_First 24h','GFAP_First 24h','UCHL1_First 24h',...
              'NFL_First 24h','pTaut_First 24h'};
clinical_req = {'GCS','Weight','Age_inYears'};
target_vars_final = [biomarkers, clinical_req];

% Extract and run PCA
X_input = table2array(data_normalized(:, target_vars_final));
[coeff, score, ~, ~, explained] = pca(X_input);

% PCA Explain Plot 
figure('Color','w','Name','PCA Variance Explained');
pareto(explained);  % Pareto shows individual and cumulative variance
xlabel('Principal Component');
ylabel('Variance Explained (%)');
title('PCA Feature Contribution (Explain Plot)');
grid on;

% Select PCs for clustering 
pca_rank = find(cumsum(explained) > 80, 1); % (cumulative sum > 80%)
X_cluster = score(:, 1:pca_rank);
fprintf('Retaining %d PCs for HDBSCAN clustering.\n', pca_rank);


%% CLUSTERING 1: HDBScan 

rng(1); 

X_cluster_small = X_cluster(:, 1:2); 
X_cluster_norm = zscore(X_cluster_small);

clusterer = HDBSCAN(X_cluster_norm);
clusterer.run_hdbscan(2, 2, 1, 0.3);

% Extract labels for later
% HDBSCAN typically uses 0 for noise
final_labels = clusterer.labels; 

% Phenotype discovery summary
u_labels     = unique(final_labels);
num_clusters = sum(u_labels > 0);
noise_count  = sum(final_labels <= 0);

% Formatting for later
opt_k = num_clusters;

fprintf('HDBSCAN Object: %d Phenotypes found | %d Outliers\n', ...
    num_clusters, noise_count);

% Visualization 
figure('Color','w', 'Name', 'HDBSCAN Results');
subplot(1,2,1);
clusterer.plot_clusters(); % 2D Scatter of PCs
title('Density-Based Phenotypes');

subplot(1,2,2);
clusterer.plot_tree(); % Condensed tree
title('Condensed Cluster Hierarchy');


%% CLUSTERING 2: PAM
k_range = 3:6; 
results = struct(); 
best_sil = -1;
k_optimal = []; % Default

for k = k_range
    rng(1); 
    [labels, ~] = kmedoids(X_cluster, k, 'Algorithm', 'pam', 'Distance', 'euclidean');
    
    results(k).labels = labels;
    results(k).sil = mean(silhouette(X_cluster, labels));
    
    % Track the mathematical "Winner"
    if results(k).sil > best_sil
        best_sil = results(k).sil;
        k_optimal = k;
    end
    fprintf('  Testing k=%d: Avg Silhouette = %.3f\n', k, results(k).sil);
end

% Set up your two versions
k_clinical = 3; 
final_versions = [k_optimal, k_clinical];
version_names = {['Optimal Math Cluster (k=' num2str(k_optimal) ')'], 'Clinical Benchmark (k=3)'};

fprintf('\nSelected k_math=%d (Sil=%.3f) and k_clinical=3 for comparison.\n', k_optimal, best_sil);

% Visualization & comparison
figure('Color','w', 'Name', 'PAM Medoid Structure Comparison');
t_pam = tiledlayout(1, 2, 'TileSpacing', 'compact');

for v = 1:length(final_versions)
    current_k = final_versions(v);
    
    % Re-run kmedoids to get labels AND the actual medoid values (C)
    rng(1); 
    [current_labels, C] = kmedoids(X_cluster, current_k, 'Algorithm', 'pam', 'Distance', 'euclidean');
    
    nexttile;
    % Plot patients
    gscatter(X_cluster(:,1), X_cluster(:,2), current_labels, lines(current_k), '.', 15);
    hold on;
    
    % Plot Medoids directly using the output 'C'
    plot(C(:, 1), C(:, 2), 'ko', 'MarkerSize', 10, 'LineWidth', 2, 'DisplayName', 'Medoids');
    
    title(version_names{v});
    xlabel('PC1'); ylabel('PC2');
    grid on; 
    if v == 2, legend('Location', 'northeastoutside'); else, legend('off'); end
end


%% DIMENSIONALITY REDUCTION: UMAP & t-SNE

% 1. UMAP
% Optimize UMAP
neighbors_list = [10, 15, 20];
dist_list      = [0.01, 0.1];
best_n = 15; best_d = 0.1; % Defaults

% Run UMAP
rng(1);
[embedding_umap, ~, ~] = run_umap(X_cluster, ...
    'n_neighbors', best_n, 'min_dist', best_d, ...
    'verbose','none', 'confirm_delete',false, 'ask_prior',false, 'random_state', 1);

% 2. t-SNE 
rng(1);
embedding_tsne = tsne(X_cluster, 'Algorithm','exact', 'Distance','euclidean', 'Perplexity',10);

% 3. Visualization 
embeddings_to_plot = {embedding_tsne, embedding_umap};
method_names       = {'t-SNE', 'UMAP'};

current_k = k_clinical;

for m = 1:length(embeddings_to_plot)
    X_vis = embeddings_to_plot{m};
    name  = method_names{m};
    final_labels = results(k_clinical).labels;
    
    figure('Color','w', 'Name',[name ' Visualization']);
    gscatter(X_vis(:,1), X_vis(:,2), final_labels);
    hold on;
    
    % Annotate cluster sizes 
    u_clusters = unique(final_labels);
    for c = 1:length(u_clusters)
        cl = u_clusters(c);
        mask = final_labels == cl;
        text(mean(X_vis(mask,1)), mean(X_vis(mask,2)), sprintf('n=%d', sum(mask)), ...
            'HorizontalAlignment','center', 'FontWeight','bold', 'FontSize',9);
    end
    hold off;
    
    title(sprintf('%s: PAM Phenotypes (k=%d, Sil=%.2f)', name, current_k, results(current_k).sil));    
    xlabel([name ' 1']); 
    ylabel([name ' 2']);
    grid on; legend('Location','bestoutside');
end

% 4. PC1 loadings plot for interpretability 
[~, load_sort] = sort(abs(coeff(:,1)), 'descend');    % 'coeff' from the PCA section 
figure('Color','w');
barh(flip(coeff(load_sort, 1)), 'FaceColor',[0.6 0.3 0.6]);
set(gca, 'YTick', 1:length(target_vars_final), ...
    'YTickLabel', flip(target_vars_final(load_sort)), 'FontSize', 9);
xlabel('Loading Score');
title('Feature Contributions to PC1 (Clustering Axis)');
xline(0, '-k'); grid on;


%% OUTCOME VALIDATION
% Validate discovered phenotypes against long-term GOSE outcomes
outcome_vars = {'GOSEAVG2_6Wk', 'GOSEAVG3_6mo', 'GOSEAVG9_12mo'}; 

for v = 1:length(final_versions)
    current_k = final_versions(v);
    current_labels = results(current_k).labels;
    
    for i = 1:length(outcome_vars)
        ov = outcome_vars{i};
        valid_mask = ~isnan(data.(ov));
        
        figure('Color','w', 'Name', [version_names{v} ' - ' ov]);
        
        % Use lines(current_k) to avoid "Index Exceeds Bounds" errors
        current_colors = lines(current_k);
        
        boxplot(data.(ov)(valid_mask), current_labels(valid_mask), 'Colors', current_colors);
        
        ylabel('GOSE Score (12-mo)'); 
        xlabel('Phenotype Cluster');
        title(sprintf('%s\n%s Performance', version_names{v}, ov));
        grid on;
        
        % Kruskal-Wallis significance check
        [p, ~, ~] = kruskalwallis(data.(ov)(valid_mask), current_labels(valid_mask), 'off');
        fprintf('%s vs %s: p = %.4f\n', version_names{v}, ov, p);
    end
end


%% SUPERVISED VALIDATION: 5-FOLD CROSS-VALIDATION & RANDOM FOREST
% Proves that the phenotypes are predictable and not bcs of random noise

% Remove outcomes (LOS, GOSE) so the model explains phenotypes using only baseline features
outcomes_to_drop = {'HospitalStay_LOS', 'ICU_LOS', 'GOSEAVG2_6Wk', ...
                    'GOSEAVG3_6mo', 'GOSEAVG9_12mo', 'Mortality'};
cols_to_keep = ~ismember(data_normalized.Properties.VariableNames, outcomes_to_drop);
X_explain = table2array(data_normalized(:, cols_to_keep));
explain_vars = data_normalized.Properties.VariableNames(cols_to_keep);

% Only train on patients PAM successfully clustered 
labels_explain = results(k_clinical).labels;
is_valid_cluster = true(size(labels_explain)); 

X_pure = X_explain(is_valid_cluster, :);
Y_pure = labels_explain(is_valid_cluster);

if ~isempty(Y_pure)
    % Permutation Feature Importance:
    % Measure how much accuracy drops when a feature is shuffled, determining the importance of a feature
    num_trees = 300;
    rng(1); 
    rf_model = TreeBagger(num_trees, X_pure, Y_pure, ...
        'Method', 'classification', 'OOBPredictorImportance', 'on', 'MinLeafSize', 2);

    oob_error = oobError(rf_model);
    fprintf('Random Forest OOB error: %.3f (accuracy: %.1f%%)\n', ...
        oob_error(end), (1 - oob_error(end)) * 100);

    imp_scores = rf_model.OOBPermutedPredictorDeltaError;
    [sorted_imp, s_idx] = sort(imp_scores, 'descend');
    
    % Plot top 15 features
    top_n = min(15, length(explain_vars));
    figure('Color','w', 'Name', 'Global Importance');
    barh(flip(sorted_imp(s_idx(1:top_n))), 'FaceColor', [0.25 0.45 0.75]);
    set(gca, 'YTick', 1:top_n, 'YTickLabel', flip(explain_vars(s_idx(1:top_n))));
    title('Global Drivers of Phenotype Separation'); xlabel('Delta Error (Importance)');
    grid on;

    % Visualization of importance
    u_clusters = unique(Y_pure);
    cluster_means = zeros(length(u_clusters), length(explain_vars));
    for i = 1:length(u_clusters)
        cluster_means(i, :) = mean(X_pure(Y_pure == u_clusters(i), :), 1);
    end

    figure('Color','w', 'Name', 'Phenotype Signatures');
    h_heat = heatmap(explain_vars(s_idx(1:top_n)), strcat('Cluster ', string(u_clusters')), ...
        cluster_means(:, s_idx(1:top_n)));
    h_heat.Title = 'PAM Phenotype Biomarker Fingerprints (Z-Scores)';
    h_heat.Colormap = redblue_colormap(); % Red = High concentration, Blue = Low
    h_heat.ColorLimits = [-1.5, 1.5];

    % One-vs-Rest (OvR) Analysis: 
    % Find what makes one specific cluster unique compared to all others
    figure('Color','w', 'Name', 'Per-Cluster Drivers');
    t = tiledlayout(ceil(length(u_clusters)/2), 2, 'TileSpacing', 'compact');
    
    for i = 1:length(u_clusters)
        binary_y = double(Y_pure == u_clusters(i));
        rng(1);
        rf_ovr = TreeBagger(150, X_pure, binary_y, 'Method', 'classification', ...
            'OOBPredictorImportance', 'on');
        
        [ovr_imp, ovr_idx] = sort(rf_ovr.OOBPermutedPredictorDeltaError, 'descend');
        nexttile;
        barh(flip(ovr_imp(1:7)), 'FaceColor', [0.25 0.60 0.45]);
        set(gca, 'YTick', 1:7, 'YTickLabel', flip(explain_vars(ovr_idx(1:7))));
        title(sprintf('What defines Phenotype %d?', u_clusters(i)));
    end
end