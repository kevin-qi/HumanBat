function [flightPaths] = HumanBat_ClusterFlights(out,AnalogSignals)
    
    % Uses heirarchical clustering to cluster the flights

    VideoFrameRate = 120;
    x_mean = out.trajectories_continuous./1000;  
    t = [1:length(AnalogSignals)]./VideoFrameRate; % NOT SURE ABOUT THIS
    new_t=t;

    % % Flight Room references (provvisory)
    xR = +2.85; xL = -2.85; yF = 2.50;  yB = -2.50;  zT = 2.20;                 %Flight volume coordinates
    F3 = [2.56; 1.43; 0.72];    F4 = [2.56; -1.24; 0.72];                       %Feeders coordinates
    
    %% Re-extract trajectories
    % Filter and interpolate
    x_filt = medfilt1(x_mean,VideoFrameRate/2,[],2,'omitnan','truncate'); %filter after interpolating
    x_intr = HumanBat_interpolate_nans(x_filt);%  fillmissing(x_filt,'next',2,'EndValues','nearest');
    %x_spl = x_intr;
    x_spl_pre = x_intr;
    x_spl_1 = smooth(x_spl_pre(1,:),VideoFrameRate/2);     x_spl_2 = smooth(x_spl_pre(2,:),VideoFrameRate/2);      x_spl_3 = smooth(x_spl_pre(3,:),VideoFrameRate/2); 
    x_spl = [x_spl_1,x_spl_2,x_spl_3]';

    %threshold based on speed
    Vx = gradient(x_spl(1,:), 1/VideoFrameRate);
    Vy = gradient(x_spl(2,:), 1/VideoFrameRate);
    Vz = gradient(x_spl(3,:), 1/VideoFrameRate);
    speed = sqrt(Vx.^2 + Vy.^2 + Vz.^2); %in m/s

    nonflying = find(speed < 1.5);        toofast = find(speed > 20);
    x_flying = x_spl;                     x_flying(:,[nonflying toofast]) = nan;
    batspeed = speed;                     batspeed([nonflying toofast]) = nan;
    bflying=~isnan(batspeed)';           %vector of 1s when the bat is flying
    
    % For each sample, sum up the next 1s of data(flights are longer than 1s),Code from Nick D.
    allsums = [];
    for bf = 1 : size(bflying,1)-VideoFrameRate
        allsums(bf) = sum(bflying(bf:bf+VideoFrameRate));
    end

    % Detect flight starts and stops
    [R,rLT,rUT,rLL,rUL] = risetime(allsums);    
    [F,fLT,fUT,fLL,fUL] = falltime(allsums);           
    if length(R) ~= length(F)
    fLT(length(R)) = length(allsums);
    fUT(length(R)) = length(allsums);
    F(length(R)) = F(length(F));
    end
    flight_starts = round(rLT+VideoFrameRate/2);
    flight_ends = round(fLT+VideoFrameRate/2); %... +Fs is a sistematic correction, useful
    num_flights = size(R,2);
    ref = ones(size(flight_starts));
    avg_flight_time = mean((flight_ends-flight_starts)./VideoFrameRate);

    %%
    % Plot 2D flight trajectories
    plotFlightPathsAll = figure();   set(gcf, 'units','normalized','outerposition',[0 0 1 1]);
    subplot(1,2,1);
    plot(x_mean(1,:),x_mean(2,:),'.');
    hold on;        rectangle('Position',[xL yB xR-xL yF-yB]);
    scatter([F3(1) F4(1)],[F3(2) F4(2)],'filled');  hold off;
    xlim([-3 3]); ylim([-3 3]); zlim([0 2.5]);
    title(['Raw flights']);
    xlabel('m'); ylabel('m');
    hold off
    
    subplot(1,2,2);
    plot(x_spl(1,:),x_spl(2,:)); hold on; plot(x_mean(1,:),x_mean(2,:),'.','MarkerSize',1);
    rectangle('Position',[xL yB xR-xL yF-yB]);  hold off;
    xlim([-3 3]); ylim([-3 3]); zlim([0 2.5]);
    title(['Spline flights: ']);
    xlabel('m'); ylabel('m');
    hold off
    
    % Plot session timeline
    plotFlightTimeline = figure();   set(gcf, 'units','normalized','outerposition',[0 0 1 1]);
    ax1 = subplot(3,1,1);   plot(t,x_mean(1,:),'.');  hold on;
    plot(new_t,x_spl(1,:),'--');   refline(0,F3(1));    hold off;
    legend('cluster/mean','spl');   ylabel('x (m)');
    ax2 = subplot(3,1,2);   plot(new_t,speed,'.');
    hold on;    stem(new_t(flight_starts),ref);    stem(new_t(flight_ends),ref);  hold off;
    ylabel('v (m/s)');
     ax3 = subplot(3,1,3);  % plot(t,rew_signal);
    ylabel('Rewards');
    linkaxes([ax1,ax2,ax3],'x');    xlabel('Samples');
    
    
    % Plot flights in color time order
    plotFlightPathsStartStop = figure();
    if size(R,2) > 0
        CM = jet(size(R,2));
        for nf = 1 : size(R,2)
            hold on
            plot3(x_spl(1,flight_starts(nf):flight_ends(nf)),x_spl(2,flight_starts(nf):flight_ends(nf)),x_spl(3,flight_starts(nf):flight_ends(nf)),'LineWidth',1,'Color',CM(nf,:))
            hold on
            
            fstartxyz(nf,1) = x_spl(1,flight_starts(nf)); %round(nanmean(x_spl(1,flight_starts(nf):flight_starts(nf)+trackData.VideoFrameRate/2)));
            fstartxyz(nf,2) = x_spl(2,flight_starts(nf)); %round(nanmean(x_spl(2,flight_starts(nf):flight_starts(nf)+trackData.VideoFrameRate/2)));
            fstartxyz(nf,3) = x_spl(3,flight_starts(nf)); %round(nanmean(x_spl(3,flight_starts(nf):flight_starts(nf)+trackData.VideoFrameRate/2)));
            
            fendxyz(nf,1) = x_spl(1,flight_ends(nf)); %round(nanmean(x_spl(1,flight_ends(nf):flight_ends(nf)+trackData.VideoFrameRate/2)));
            fendxyz(nf,2) = x_spl(2,flight_ends(nf)); %round(nanmean(x_spl(2,flight_ends(nf):flight_ends(nf)+trackData.VideoFrameRate/2)));
            fendxyz(nf,3) = x_spl(3,flight_ends(nf)); %round(nanmean(x_spl(3,flight_ends(nf):flight_ends(nf)+trackData.VideoFrameRate/2)));
            
            scatter3(fstartxyz(nf,1),fstartxyz(nf,2),fstartxyz(nf,3),50,'r','filled')
            hold on
            scatter3(fendxyz(nf,1),fendxyz(nf,2),fendxyz(nf,3),50,'k','filled')
            %pause
        end
    else
        fstartxyz(1,1) = (0);
        fstartxyz(1,2) = (0);
        fstartxyz(1,3) = (0);
        
        fendxyz(1,1) = (0);
        fendxyz(1,2) = (0);
        fendxyz(1,3) = (0);
    end
    title(['All flights start(r)/stop(b): ']);
    % modify labels for tick marks
    view(0,90)
    xlim([-3 3])
    ylim([-3 3])
    xlabel('m'); ylabel('m');
    
    hold off

    %% Clustering flights

    % Clustering params
    ds_clus = 25;                                                                %number of 3D-points/flight for clustering 
    %madeleine 25 splines, PCA+, 1m linkage
    %angelo 6 splines, PCA-, 0.7m linakge, min 5 
    pca_features = false;                                                       %if using PCA
    k_means = false;                                                            %if using k-means
    dist = 1.5;                                                                 %linkage distance
    reassign = true;                                                            %re-order clusters according to density
    N_min = 3; 
    day_index=1;

    %Cut out flights, downsample to ds_clus positions per flight
    all_flights = NaN(3,max(flight_ends-flight_starts),num_flights);    %3D matrix with all flights
    all_flights_ds = NaN(3,ds_clus,num_flights);                        %3D matrix with all flights(downsampled)
    
    for nf = 1 : size(all_flights,3)
        trajectory = x_spl(:,flight_starts(nf):flight_ends(nf));
        velocity = speed(:,flight_starts(nf):flight_ends(nf));
        all_flights(:,1:(flight_ends(nf)-flight_starts(nf))+1,nf) = trajectory;
        all_flights_vel(1,1:(flight_ends(nf)-flight_starts(nf)+1),nf) = velocity;
        all_flights_ds(:,:,nf) = interp1(linspace(1,3,size(trajectory,2)),trajectory',linspace(1,3,ds_clus),'spline')';
        
        %     %Uncomment if you want to see how the downsampled flights look like
            plot3(all_flights(1,:,nf),all_flights(2,:,nf),all_flights(3,:,nf),'Color','b');
            hold on;
            plot3(all_flights_ds(1,:,nf),all_flights_ds(2,:,nf),all_flights_ds(3,:,nf),'Color','r');
            hold off;
        %     w = waitforbuttonpress;
    end
    
    % Define X matrix of features for clustering (downsampled coordinates, stacked together)
    X = [all_flights_ds(1,:,:), all_flights_ds(2,:,:), all_flights_ds(3,:,:)];
    X = reshape(X,3*size(all_flights_ds,2),size(R,2));
    X = X';     %so then X = #flights x #features
    
    % If dimensionality reduction is needed
    if pca_features
        [coeff,score,latent] = pca(X);     X = score(:,1:5);
    end
    
    % k-means or hierarchical clustering (with euclidean distance and shortest linkage)
    if k_means
        n_clusters = 15;    idx = kmeans(X,n_clusters);
    else
        plotClusterDistance = figure();
        Y = pdist(X,'euclidean');   Z = linkage(Y);
        hLines = dendrogram(Z,0);  hold on;    refline(0,dist);    hold off;
        idx = cluster(Z,'Cutoff',dist,'Criterion','distance');
        title([num2str(length(unique(idx))) ' clusters: ']);
        ylim([0 10]);
    end

    % HDBSCAN (see Humanbat_HDBSCAN_Playground.m)
    %hdbscan_clusterer = HDBSCAN(X)
    
    % Create structure with flight start stop frames, id of the trajectory
    clear flight;
    flight.strt_frame = ceil(flight_starts)';
    flight.stop_frame = ceil(flight_ends)';
    flight.pos = all_flights;
    flight.vel = all_flights_vel;
    flight.id = idx;
    flight.Fs = VideoFrameRate;

    % Sort structure according to cluster id
    clear flight_sorted;
    [flight_sorted.id,I] = sort(flight.id);
    flight_sorted.strt_frame = flight.strt_frame(I);
    flight_sorted.stop_frame = flight.stop_frame(I);
    flight_sorted.pos = flight.pos(:,:,I);
    flight_sorted.vel = flight.vel(:,:,I);
    flight_sorted.Fs = flight.Fs;
    flight_sorted.N = size(flight_sorted.id,1);
    
    % Assign isolated clusters to cluster #flights+1
    [Ns,b] = histc(flight_sorted.id,unique(flight_sorted.id));
    flight_sorted.id(Ns(b)<N_min) = size(all_flights,3)+1;             %flight_sorted.id(Ns(b)==1) = size(all_flights,3)+1;
    id_surv_clusters = unique(flight_sorted.id);
    n_surv_clusters = size(id_surv_clusters,1);
    
    % Create final structure flight.clus after re-assignment
    clear flightPaths;
    flightPaths.id = flight_sorted.id;
    flightPaths.flight_starts_idx = flight_sorted.strt_frame';
    flightPaths.flight_ends_idx = flight_sorted.stop_frame';
    flightPaths.pos = flight_sorted.pos;
    flightPaths.vel = flight_sorted.vel;
    flightPaths.Fs = flight_sorted.Fs;
    flightPaths.N = flight_sorted.N;
    %flightPaths.day = day_index(flightPaths.flight_starts_idx);% this is the day index...
    
    for jj=1:n_surv_clusters;
        flightPaths.id(flight_sorted.id == id_surv_clusters(jj)) = jj;
    end
    id_surv_clusters = unique(flightPaths.id);
    
    %Re-assign id for convenience, if necessary
    if reassign
        new_ord = [];
        [~,new_ord] = sort(histc(flightPaths.id,id_surv_clusters(1:end-1)),'descend');
        new_ord = [new_ord; id_surv_clusters(end)];
        new_ord = circshift(new_ord,1);
        reassign_matrix =(flightPaths.id == new_ord');
        for jj=1:n_surv_clusters;
            flightPaths.id(reassign_matrix(:,jj)) = jj;
        end  
    end 
    
    %Calculate trajectory length, duration in s and interflight (take-off to take-off)
    for ii = 1:flight_sorted.N
        flightPaths.length(ii)= arclength(flightPaths.pos(1,~isnan(flightPaths.pos(1,:,ii)),ii),flightPaths.pos(2,~isnan(flightPaths.pos(2,:,ii)),ii),flightPaths.pos(3,~isnan(flightPaths.pos(3,:,ii)),ii));
        flightPaths.dur(ii) = (flightPaths.flight_ends_idx(ii)-flightPaths.flight_starts_idx(ii))./flightPaths.Fs;
    end
    flightPaths.ifd = diff(flightPaths.flight_starts_idx)';
    
    %group the cluster ids
    for i = 1:max(flightPaths.id)
        flightPaths.clusterIndex{i} = find(flightPaths.id == i);
    end
    
    %add Tobias specific variables for future plots
    flightPaths.trajectoriesContinous = x_intr;
    flightPaths.trajectoriesSpline = x_spl;
    flightPaths.trajectoriesRaw = x_mean;
    flightPaths.batSpeed = speed';
    flightPaths.flight_starts_xyz = flightPaths.pos(:,1,:); %starting position of each flight
    flightPaths.flight_ends_xyz = zeros(length(flightPaths.pos(1,1,:)),3); %make matrix for landing position for each flight 
    for i = 1:length(flightPaths.pos(1,1,:))
        try
            flightPaths.flight_ends_xyz(i,:) = flightPaths.pos(:,find(isnan(flightPaths.pos(1,:,i)),1)-1,i); %find last xyz position
        catch
            flightPaths.flight_ends_xyz(i,:) = flightPaths.pos(:,end,i);
        end
    end
    flightPaths.flightTimeline = plotFlightTimeline;
    flightPaths.flightPathsAll = plotFlightPathsAll;
    flightPaths.flightPathsStartStop = plotFlightPathsStartStop;
    flightPaths.clusterDistance = plotClusterDistance;
    flightPaths.ds_clus = ds_clus;                                                                %number of 3D-points/flight for clustering 
    flightPaths.pca_features = pca_features;                                                       %if using PCA
    flightPaths.linkDist = dist;                                                                 %linkage distance
    flightPaths.N_min = N_min;
    %% Visualize
    
    % Force min cluster: 
    n_surv_clusters = 5;
    
    plotFlightPathsClusterEach = figure();   set(gcf, 'units','normalized','outerposition',[0 0 1 1]);
    col = hsv(n_surv_clusters);
    title(['Flight clusters:']);
    for jj=1:n_surv_clusters;
        id = find(flightPaths.id==jj);
        
        subplot(3,n_surv_clusters,jj);
        avg_take_off = [];
        for ii=1:size(id,1);
            hold on;
            title(['Cluster' num2str(jj) '  (' num2str(size(id,1)) ' flights)'])
            plot3(flightPaths.pos(1,:,id(ii)),flightPaths.pos(2,:,id(ii)),flightPaths.pos(3,:,id(ii)),'-','LineWidth',1,'Color', col(jj,:));
            avg_take_off = [avg_take_off flightPaths.pos(:,1,id(ii))];
            hold on;
        end
        take_off = mean(avg_take_off,2);
        %textscatter3(take_off(1),take_off(2),take_off(3),"Take-off");
        
        plot3(x_spl(1,:),x_spl(2,:),x_spl(3,:),':','Color',[0.7 0.7 0.7],'MarkerSize',0.001);
        xlim([-3 3]); ylim([-3 3]); zlim([0 2.5]);
        xlabel('x');    ylabel('y');    zlabel('z');    view(2);
        hold off;
        
        subplot(3,n_surv_clusters,n_surv_clusters+jj);
        avg_take_off = [];
        for ii=1:size(id,1);
            hold on;
            title(['Cluster' num2str(jj) '  (' num2str(size(id,1)) ' flights)'])
            plot3(flightPaths.pos(1,:,id(ii)),flightPaths.pos(2,:,id(ii)),flightPaths.pos(3,:,id(ii)),'-','LineWidth',1,'Color', col(jj,:));
            avg_take_off = [avg_take_off flightPaths.pos(:,1,id(ii))];
            hold on;
        end
        take_off = mean(avg_take_off,2);
        %textscatter3(take_off(1),take_off(2),take_off(3),"Take-off");
        
        plot3(x_spl(1,:),x_spl(2,:),x_spl(3,:),':','Color',[0.7 0.7 0.7],'MarkerSize',0.001);
        xlim([-3 3]); ylim([-3 3]); zlim([0 2.5]);
        xlabel('x');    ylabel('y');    zlabel('z');    view(0,0);
        hold off;
        
        subplot(3,n_surv_clusters,n_surv_clusters*2+jj);
        histogram(flightPaths.dur(id));
        xlim([0 15]);   xlabel('Duration(s)');  ylabel('Counts');
    end
    
    flightPaths.flightPathsClusterEach = plotFlightPathsClusterEach;




    
end