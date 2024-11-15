%% Example
clear
clc
close all

addpath('permn')

rng(10)
cm_map = 'parula';
%scenario = 'square uniform';
%scenario = 'circle random';
scenario = 'points random';

method = 'gaussian'; % 'area','diff','invsquared','gaussian'
size_kernel = 1;
gra = 1; % granularity. Default is 1

R = 15;
v1 = 1;
v2 = 10;
xshift = 20;
yshift = -40;

switch scenario
    case 'square uniform'
        n = 5e4;
        % Uniform points on square with larger intensity at the border
        nside = round(sqrt(n));
        [xcoord, ycoord] = meshgrid(R*linspace(-1, 1, nside), R*linspace(-1, 1, nside));
        xcoord = xcoord(:)' + xshift;
        ycoord = ycoord(:)' + yshift;
        values = v1*ones(1, length(xcoord));
        % Increase intensity of points at the sides
        values(xcoord - xshift > 0.5*R | ycoord - yshift > 0.5*R) = v2;
    case 'circle random'
        n = 5e4;
        % Random points on circle with larger intensity at the border
        radius = R*sqrt(rand(1, n));
        theta = 2*pi*rand(1, n);
        xcoord = xshift + radius.*cos(theta);
        ycoord = yshift + radius.*sin(theta);
        values = v1*ones(1, n);
        % Increase intensity of points at the center
        values((xcoord-xshift).^2+(ycoord-yshift).^2<(R/2)^2) = v2;
    case 'points random'
        n = 100;
        % 2D scattered points
        xcoord = xshift + R*rand(1, n);
        ycoord = yshift + R*rand(1, n);
        values = [v1*ones(1, floor(n/2)), v2*ones(1, n-floor(n/2))];
end

xycoords = [xcoord; ycoord];
xylimits = [floor(min(xycoords, [], 2)), 1 + ceil(max(xycoords, [], 2))];
ijcoords = [ycoord; xcoord]; % defined with respect to 2D matrix
ijlimits = [xylimits(2,:); xylimits(1,:)]; % defined with respect to 2D matrix


Ntrials = 1e5;

timings_original = nan(1, Ntrials);
timings_optimized = nan(1, Ntrials);
timings_optimized_vect = nan(1, Ntrials);
timings_optimized_mex = nan(1, Ntrials);
timings_optimized_mex_vect = nan(1, Ntrials);

% ORIGINAL VERSION
%%---
for idTrial = 1:Ntrials
    tic
    [bins_hw, counts_hw, edges_hw] = histweight(ijcoords, values, ijlimits, gra, 'method', method, 'window', size_kernel);
    timings_original(idTrial) = toc;
end
%%--

mean_timing_original = mean(timings_original, 'all', "omitnan");
fprintf('\nMean time, original: %4.4g [ms]\n', 1000*mean_timing_original)

methodID = int32(2); % 'area'
bFlagProgress = false;
bVECTORIZED   = false;
bDEBUG_MODE   = false;

addpath("codegen_src/")

% OPTIMIZED VERSION NON-VECT
for idTrial = 1:Ntrials

    tic
    [bins_hw_vect, counts_hw_vect, edges_hw_vect] = histweight_vect(ijcoords, values, ijlimits, gra, methodID, bFlagProgress, false, bDEBUG_MODE);
    timings_optimized(idTrial) = toc;
end

mean_timings_optimized = mean(timings_optimized, 'all', "omitnan");
fprintf('\nMean time, optimized non-vect: %4.4g [ms]\n', 1000*mean_timings_optimized)

% OPTIMIZED VERSION VECT
for idTrial = 1:Ntrials

    tic
    [bins_hw_vect, counts_hw_vect, edges_hw_vect] = histweight_vect(ijcoords, values, ijlimits, gra, methodID, bFlagProgress, true, bDEBUG_MODE);
    timings_optimized_vect(idTrial) = toc;
end

mean_timings_optimized_vect = mean(timings_optimized_vect, 'all', "omitnan");
fprintf('\nMean time, optimized vect: %4.4g [ms]\n', 1000*mean_timings_optimized_vect)

%  OPTIMZIED MEX VERSION NON-VECT
for idTrial = 1:Ntrials

    tic
    [bins_hw_vect_MEX, counts_hw_vect_MEX, edges_hw_vect_MEX] = histweight_vect_MEX(ijcoords, values, ijlimits, gra, int8(methodID), ...
        bFlagProgress, false, bDEBUG_MODE);
    timings_optimized_mex(idTrial) = toc;
end

mean_timings_optimized_mex = mean(timings_optimized_mex, 'all', "omitnan");
fprintf('\nMean time, optimized_mex non-vect: %4.4g [ms]\n', 1000*mean_timings_optimized_mex)

%  OPTIMZIED MEX VERSION VECT
for idTrial = 1:Ntrials

    tic
    [bins_hw_vect_MEX, counts_hw_vect_MEX, edges_hw_vect_MEX] = histweight_vect_MEX(ijcoords, values, ijlimits, gra, int8(methodID), ...
        bFlagProgress, true, bDEBUG_MODE);
    timings_optimized_mex_vect(idTrial) = toc;
end

mean_timings_optimized_mex_vect = mean(timings_optimized_mex_vect, 'all', "omitnan");
fprintf('\nMean time, optimized_mex vect: %4.4g [ms]\n', 1000*mean_timings_optimized_mex_vect)


return
% You can also simply call:
%   [bins_hw, counts_hw, edges_hw] = histweight(ijcoords, values);
% Granularity will be set to 1 as default and limits are automatically
% computed. Area method is used by default

% histcount comparison
bins_hc = histcounts2(ijcoords(1,:)*gra, ijcoords(2,:)*gra, edges_hw{1}, edges_hw{2});

%% PLOT

ibincoords = edges_hw{1};
ibincoords = ibincoords(1:end-1) + 0.5;
jbincoords = edges_hw{2};
jbincoords = jbincoords(1:end-1) + 0.5;
xbincoords = jbincoords;
ybincoords = ibincoords;

figure('Units','normalized','Position',[0.1 0.1 0.8 0.8]), 
colormap(cm_map)

ax1 = subplot(1,3,1);
grid on, hold on, axis equal
xlim(xylimits(1,:) + [-R/2,R/2])
ylim(xylimits(2,:) + [-R/2,R/2])
scatter(xycoords(1,:), xycoords(2,:), [], values,'o','filled')
cb = colorbar;
cb.Label.String = 'intensity';
title('sampled points')
xlabel('x')
ylabel('y')

ax2 = subplot(1,3,2);
grid on, hold on, axis equal
xlim(gra*xlim(ax1))
ylim(gra*ylim(ax1))
h1 = imagesc([xbincoords(1), xbincoords(end)], [ybincoords(1), ybincoords(end)], bins_hw);
set(h1, 'AlphaData', bins_hw~=0)
cb = colorbar;
cb.Label.String = 'intensity';
title('histweight')
xlabel('x')
ylabel('y')

ax3 = subplot(1,3,3);
grid on, hold on, axis equal
xlim(gra*xlim(ax1))
ylim(gra*ylim(ax1))
h2 = imagesc([xbincoords(1), xbincoords(end)], [ybincoords(1), ybincoords(end)], bins_hc);
set(h2, 'AlphaData', bins_hc~=0)
cb = colorbar;
cb.Label.String = 'counts';
title('histcounts')
xlabel('x')
ylabel('y')

%% ERROR
disp(['Sum of values: ',num2str(sum(values))])
disp(['Sum of bins: ',num2str(sum(bins_hw,'all'))])
disp(['Error: ',num2str(sum(bins_hw,'all') - sum(values))])
