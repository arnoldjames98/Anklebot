%% Brand New 2019 MATLAB Analysis Code
% Created on January 1, 2019

clear; clc; close all

%% Part 1: Parameters
% These are the parameters that change based on the study type

% Data set variables (specific to the format of the .dat file)
columnData = {
    'i', 'no units' % 1
    'time_since_start' , 'ms' % 2
    'pos.ie' , 'rad' % 3
    'pos.dp' , 'rad' % 4
    'vel.ie' , 'rad/s' % 5
    'vel.dp' , 'rad/s' % 6
    'torque.ie', 'Nm' % 7
    'torque.dp', 'Nm' % 8
    'moment_cmd.ie', 'Nm' % 9
    'moment_cmd.dp', 'Nm' % 10
    'knee.raw', 'rad' % 11
    'right.devtrq', 'Nm' % 12
    'left.devtrq', 'Nm' % 13
    'right.volts', 'V' % 14
    'left.volts', 'V' % 15
    'emg.triggering_signal', 'V' % 16
    'ankle.perturb_DP', 'no units' % 17
    'emg.tib_ant', 'V' % 18
    'emg.per_loin', 'V' % 19
    'emg.sol', 'V' % 20
    'emg.meg_gas', 'V' % 21
    'load_cell.left', 'V' % 22
    'load_cell.right', 'V' % 23
    'accel.ie', 'rad/s^2' % 24
    'accel.dp', 'rad/s^2' % 25
    'fvel.ie', 'rad/s' % 26
    'fvel.dp', 'rad/s' % 27
    'varDamp_K', 'no unit' % 28
    'damp_IE', 'Nms/rad' % 29
    'damp_DP', 'Nms/rad' % 30
    'faccel', 'rad/s^2' % 31
    'vel_ times_accel', 'unit'}; % 32

columnCount = length(columnData); % number of columns in .dat files
headerCount = 13; % number of header lines in .dat files

% Study variables
trialPerBlockCount = 10; % number of trials per blocks (trials per .dat file)
blocksCount = 19; % total number of blocks (number of .dat files)
targetDistance = 7.5; % distance to targets (in deg)
trialTime = 2000; % length of each trial (in ms)

% Graph colors (using RGB color codes)
green = [120/255 190/255 32/255]; % used for positive trials
orange = [255/255 127/255 50/255]; % used for negative trials
blue = [0/255 163/255 224/255]; % used for variable trials
purple = [154/255 83/255 239/255]; % used for damping/user intent
black = [0 0 0]; % used for all other trials

%% Part 2: Loading in the Data
% Generates a string used for reading the .dat file
singleF = '%f';
multipleF = singleF;

% Loop that creates a string of repeated '%f' (ie. '%f%f%f' if 3 columns)
for i = 1:(columnCount-1)
    multipleF = strcat(multipleF, singleF);
end

% Removes header and loads data
[filename, directory_name] = uigetfile('*.dat', 'MultiSelect','on');
allFiles_fullname = fullfile(directory_name, filename);

% Initialize the cell array that stores all of the data
eachBlock = cell(blocksCount,2);

% Loop for creating separate variables for each of the files
for j = 1:length(allFiles_fullname)
    fileIdentifier = fopen(char(allFiles_fullname(j)));
    disp(char(allFiles_fullname(j)))
    % Creates a cell array
    cellArray = textscan(fileIdentifier, multipleF, 'HeaderLines', ...
        headerCount,'Delimiter','\n','CollectOutput',1);
    fclose(fileIdentifier);
    % Put the data into the cell array
    eachBlock{j,1} = cell2mat(cellArray); % Each matrix of data
    eachBlock{j,2} = char(filename(j)); % Each filename
end

% Correcting data units
for i = 1:blocksCount
    % Converting position from radians to degrees
    eachBlock{i,1}(:,3) = eachBlock{i,1}(:,3)*180/pi;
    columnData{3,2} = 'deg';
    eachBlock{i,1}(:,4) = eachBlock{i,1}(:,4)*180/pi;
    columnData{4,2} = 'deg';
    eachBlock{i,1}(:,5) = eachBlock{i,1}(:,5)*180/pi;
    columnData{5,2} = 'deg/s';
    eachBlock{i,1}(:,6) = eachBlock{i,1}(:,6)*180/pi;
    columnData{6,2} = 'deg/s';
    
    % Converting time_to_start into seconds
    eachBlock{i,1}(:,2) = (eachBlock{i,1}(:,2)-eachBlock{i,1}(1,2))/(10^9);
    columnData{2,2} = 's';
end

disp('Units corrected.')


%% Individual Graphing of the Raw Data
figure
% Specify what data you want to graph
graphBlock = 6; % the block of 10 trials whose data is graphed
graphColumn = 3; % the column of data being graphed
time = eachBlock{graphBlock,1}(:,2);

% Format the graph the labels for readability
titleBlock = extractBefore(eachBlock{graphBlock,2},'_');
titleType = extractBetween(eachBlock{graphBlock,2},'_','.');
titleFull = strcat(titleBlock,' (',titleType, ')');

xLabelName = strrep(columnData{2, 1},'_',' ');
xLabelUnits = columnData{2, 2};
xLabelFull = strcat(xLabelName,' (',xLabelUnits, ')');

yLabelName = strrep(columnData{graphColumn, 1},'_',' ');
yLabelUnits = columnData{graphColumn, 2};
yLabelFull = strcat(yLabelName,' (',yLabelUnits, ')');

% Selecting the appropriate color for the graph
if titleType == 'positive'
    plotColor = green;
elseif titleType == 'negative'
        plotColor = orange;
elseif titleType == 'variable'
    plotColor = blue;
else
    plotColor = black;
end

% Plot the desired graph
plot(time, eachBlock{graphBlock,1}(:,graphColumn), 'linewidth',1.5,...
    'color', plotColor)
title(titleFull);
xlabel(xLabelFull);
ylabel(yLabelFull);
grid on

% Graph signal that specifies the start of the trials
hold on
plot(time,eachBlock{graphBlock,1}(:,17),'color',black)

%% Subplot Graphing of the Raw Data
figure
% Specify what data you want to graph
graphColumn = 3;

for i = 1:blocksCount % Creates a graph within a subplot for each block
    time = eachBlock{i,1}(:,2);
    
    % Format the graph the labels for readability
    titleBlock = extractBefore(eachBlock{i,2},'_');
    titleType = extractBetween(eachBlock{i,2},'_','.');
    titleFull = strcat(titleBlock,' (',titleType, ')');

    xLabelName = strrep(columnData{2, 1},'_',' ');
    xLabelUnits = columnData{2, 2};
    xLabelFull = strcat(xLabelName,' (',xLabelUnits, ')');

    yLabelName = strrep(columnData{graphColumn, 1},'_',' ');
    yLabelUnits = columnData{graphColumn, 2};
    yLabelFull = strcat(yLabelName,' (',yLabelUnits, ')');

    % Selecting the appropriate color for the graph
    if titleType == 'positive'
        plotColor = green;
    elseif titleType == 'negative'
        plotColor = orange;
    elseif titleType == 'variable'
        plotColor = blue;
    else
        plotColor = black;
    end

    % Plot the desired subplot arrangement
    %subplot(blocksCount, 1, i) % Plot all in a line
    subplot(5, 4, i) % Plot as a grid

    % Plot the desired graph 
    plot(time,eachBlock{i,1}(:,graphColumn),'linewidth',1.5,'color',plotColor)
    drawnow
    grid on

    hold on
    plot(time,eachBlock{i,1}(:,17),'color',black)

    title(titleFull);
    xlabel(xLabelFull);
    ylabel(yLabelFull);
    
    % Allow for the subplots to be expanded by clicking on them
    set(gca, 'ButtonDownFcn', [...
    'set(copyobj(gca, uipanel(''Position'', [0 0 1 1])), ' ...
    '    ''Units'', ''normal'', ''OuterPosition'', [0 0 1 1], ' ...
    '    ''ButtonDownFcn'', ''delete(get(gca, ''''Parent''''))''); ']);
    
end
%% Breaking the blocks into trials
totalTrials = 0;
eachTrial = cell(blocksCount*trialPerBlockCount,3);

for i = 1:blocksCount
    trialInBlock = 0;

    time = eachBlock{i,1}(:,2);
    inputSignal = eachBlock{i,1}(:,17);
    %figure
    %plot(time,eachBlock{i,1}(:,graphColumn),'linewidth',1.5,'color',plotColor)
                %hold on
    
    % Find the each of the trials within the block
    step = 1;
    while step < length(time)
        if 9.5 < inputSignal(step) && inputSignal(step) < 10.5 ...
                && trialInBlock < trialPerBlockCount
            %plot(time(step),10,'b*')
            totalTrials = totalTrials + 1;
            trialInBlock = trialInBlock + 1;
            
            % Extract data about each trial
            titleType = extractBetween(eachBlock{i,2},'_','.');
            
            % Eversion (+) or inversion (-)
            if mod(totalTrials,2) == 1
                trialDirection = 'eversion';
            else
                trialDirection = 'inversion';
            end
            
            % Put the data into the cell array
            %trialTime = 1999;
            
            eachTrial{totalTrials,1} = eachBlock{i,1}(step:step+trialTime-1,:); % Each matrix of data
            eachTrial{totalTrials,2} = char(titleType); % Trial type
            eachTrial{totalTrials,3} = trialDirection; % Direction
            
            % Since the input signal stays for more than 1 time step
            step = step + 100;
        else
        % If no input signal found, check the next time step
        step = step + 1;
        end
    end
end

disp('Number of identified trials:')
disp(totalTrials)

%% Plots every trial
figure
% Specify what data you want to graph
graphColumn = 3;

% Plots every trial
for i = 1:190
    plot(eachTrial{i,1}(:,graphColumn))
    grid on
    drawnow
    hold on
end

title('All Trials')

yLabelName = strrep(columnData{graphColumn, 1},'_',' ');
yLabelUnits = columnData{graphColumn, 2};
yLabelFull = strcat(yLabelName,' (',yLabelUnits, ')');
    
ylabel(yLabelFull)


%% Plots every trial of a certain direciton
figure
% Specify what data you want to graph
graphColumn = 3;
direction = 'eversion';

intersectionSet = find(strcmp(eachTrial(:,3), direction));
for i = intersectionSet'
    plot(eachTrial{i,1}(:,graphColumn))
    grid on
    drawnow
    hold on
end

title(direction)

yLabelName = strrep(columnData{graphColumn, 1},'_',' ');
yLabelUnits = columnData{graphColumn, 2};
yLabelFull = strcat(yLabelName,' (',yLabelUnits, ')');
    
ylabel(yLabelName)

%% Plots every trial, sorted by directions and types
% Section parameters
graphColumn = 3; % Specify what data you want to graph (columnData)

subplotRows = 3; % Number of rows of plots
subplotColumns = 2; % Number of columns of plots

dampingEnviornments = ['positive', 'negative', 'variable'];
movementDirections = ['eversion', 'inversion'];

% Create a new figure
figure

plotIndex = 0; % For placing the subplots

% Nested for loop that creates each subplot
for type = dampingEnviornments
    for direction = movementDirections
        plotIndex = plotIndex + 1;
        
        % Select the rows from eachTrial corresponding to desired direction
        % and type
        directionSet = find(strcmp(eachTrial(:,3), direction));
        typeSet = find(strcmp(eachTrial(:,2), type));

        % Find the entries in eachTrial that meet the criteria
        intersectionSet = intersect(directionSet, typeSet);
        
        for i = intersectionSet' % Plots each line
            % Locate the correct subplot
            subplot(subplotRows,subplotColumns,plotIndex)
            
            % Find and graph each trials data as colored lines
            plot(eachTrial{i,1}(:,graphColumn))
            title(strcat(type, ' ', direction));
            
            % Generate and label the y axis of the plot
            yLabelName = strrep(columnData{graphColumn, 1},'_',' ');
            yLabelUnits = columnData{graphColumn, 2};
            yLabelFull = strcat(yLabelName,' (',yLabelUnits, ')');
            ylabel(yLabelFull)
            
            grid on
            drawnow % Animate the graph as it is drawn
            hold on
       
        end
        
        % Allow for the subplots to be expanded by clicking on them
        set(gca, 'ButtonDownFcn', [...
        'set(copyobj(gca, uipanel(''Position'', [0 0 1 1])), ' ...
        '    ''Units'', ''normal'', ''OuterPosition'', [0 0 1 1], ' ...
        '    ''ButtonDownFcn'', ''delete(get(gca, ''''Parent''''))''); ']);
        
    end
end

%% Plots of average and standard deviations of all the trials, sorted
% Section parameters
graphColumn = 3; % Specify what data you want to graph (columnData)
subplotRows = 3; % Number of rows of plots
subplotColumns = 2; % Number of columns of plots
dampingEnviornments = ['positive', 'negative', 'variable'];
movementDirections = ['eversion', 'inversion'];
opacity = 0.8; % Visibility of each trial line (set to 1 to hide)

% Create a new figure
figure

plotIndex = 0; % For placing the subplots

% Nested for loop that creates each subplot
for type = dampingEnviornments
    % Selecting the appropriate color for the graph
    if type == 'positive'
        plotColor = green;
    elseif type == 'negative'
        plotColor = orange;
    elseif type == 'variable'
        plotColor = blue;
    else
        plotColor = black;
    end
    
    for direction = movementDirections
        plotIndex = plotIndex + 1;
        
        % Select the rows from eachTrial corresponding to desired direction
        % and type
        directionSet = find(strcmp(eachTrial(:,3), direction));
        typeSet = find(strcmp(eachTrial(:,2), type));

        % Find the entries in eachTrial that meet the criteria
        intersectionSet = intersect(directionSet, typeSet);
        
        % Initialize a matrix used to calculate the mean/std dev lines
        meanMatrix = zeros(trialTime,length(intersectionSet));
        
        meanMatrixIndex = 1; % Index for columns in meanMatrix
        
        for i = intersectionSet' % Plots each line
            % Locate the correct subplot
            subplot(subplotRows,subplotColumns,plotIndex)
            
            % Find and graph each trials data as light grey lines
            y = eachTrial{i,1}(:,graphColumn);
            plot(y, 'color',black+opacity) % color+opacity 
            
            % When graphing position, fix the axis for easy comparison
            if graphColumn == 3
                if direction == 'inversion'
                    ylim([-20 5]);
                else 
                    ylim([-5 20]);
                end
            end
            
            % Generate a matrix for calculating mean and standard deviation
            meanMatrix(:,meanMatrixIndex) = y;
            meanMatrixIndex = meanMatrixIndex + 1; 
            
            % Generate the title
            title(strcat(type, ' ', direction));
            
            % Generate and label the y axis of the plot
            yLabelName = strrep(columnData{graphColumn, 1},'_',' ');
            yLabelUnits = columnData{graphColumn, 2};
            yLabelFull = strcat(yLabelName,' (',yLabelUnits, ')');
            ylabel(yLabelFull)
            
            grid on
            drawnow % Animate the graph as it is drawn
            hold on
       
        end
        
        % Plot the mean and standard deviation lines
        plot(mean(meanMatrix,2), 'LineWidth', 2, 'color', plotColor)
        plot(mean(meanMatrix,2)+std(meanMatrix,[],2),'--','LineWidth', 1, 'color', black)
        plot(mean(meanMatrix,2)-std(meanMatrix,[],2),'--','LineWidth', 1, 'color', black)
        
        % Allow for the subplots to be expanded by clicking on them
        set(gca, 'ButtonDownFcn', [...
        'set(copyobj(gca, uipanel(''Position'', [0 0 1 1])), ' ...
        '    ''Units'', ''normal'', ''OuterPosition'', [0 0 1 1], ' ...
        '    ''ButtonDownFcn'', ''delete(get(gca, ''''Parent''''))''); ']);
        
    end
end

%% Plots of the user intent and robotic damping
% Section parameters
subplotRows = 3; % Number of rows of plots
subplotColumns = 2; % Number of columns of plots
dampingEnviornments = ['variable', 'intent', 'damping'];
movementDirections = ['eversion', 'inversion'];
opacity = 0.8; % Visibility of each trial line (set to 1 to hide)

% Variable damping parameters
dampingLimitUpper = 1;
dampingLimitLower = -0.5;

% Create a new figure
figure

plotIndex = 0; % For placing the subplots

% Nested for loop that creates each subplot
for type = dampingEnviornments
    % Selecting the appropriate color for the graph
    if type == 'variable'
        plotColor = blue;
    elseif type == 'intent'
        plotColor = purple;
    elseif type == 'damping'
        plotColor = purple;
    else
        plotColor = black;
    end
    
    for direction = movementDirections
        plotIndex = plotIndex + 1;
        
        % Select the rows from eachTrial corresponding to desired direction
        % and type
        directionSet = find(strcmp(eachTrial(:,3), direction));
        
        % Always sets the type to variable
        typeSet = find(strcmp(eachTrial(:,2), 'variable'));

        % Find the entries in eachTrial that meet the criteria
        intersectionSet = intersect(directionSet, typeSet);
        
        % Initialize a matrix used to calculate the mean/std dev lines
        meanMatrix = zeros(trialTime,length(intersectionSet));
        
        meanMatrixIndex = 1; % Index for columns in meanMatrix
        
        for i = intersectionSet' % Plots each line
            % Locate the correct subplot
            subplot(subplotRows,subplotColumns,plotIndex)
            
            % Find and graph each trials data as light grey lines
            if type == 'variable'
                graphColumn = 3;
                y = eachTrial{i,1}(:,graphColumn); % varaible position
            elseif type == 'intent'
                filteredVelocity = (eachTrial{i,1}(:,26));
                filteredAcceleration = (eachTrial{i,1}(:,31));
                y = filteredVelocity.*filteredAcceleration;
            elseif type == 'damping'
                graphColumn = 29;
                y = (eachTrial{i,1}(:,graphColumn));
                k = eachTrial{i,1}(1,28);
                disp(k)
            end
            
            plot(y, 'color',black+opacity) % color+opacity 
            
            % Generate a matrix for calculating mean and standard deviation
            meanMatrix(:,meanMatrixIndex) = y;
            meanMatrixIndex = meanMatrixIndex + 1; 
            
            % Generate the title (unique for damping)
            if type == 'damping'
                title(strcat(type, ' ', direction, ' (k = ', num2str(k), ')'));
            else
                title(strcat(type, ' ', direction));
            end
            
            % Generate and label the y axis of the plot
            % Intent is calculated, not found in columnData
            if type == 'intent'
                ylabel('intent (rad^2/s^3)') % user intent units
            else 
                yLabelName = strrep(columnData{graphColumn, 1},'_',' ');
                yLabelUnits = columnData{graphColumn, 2};
                yLabelFull = strcat(yLabelName,' (',yLabelUnits, ')');
                ylabel(yLabelFull)
            end
            
            grid on
            drawnow % Animate the graph as it is drawn
            hold on
       
        end
        
        % Plot the mean and standard deviation lines
        plot(mean(meanMatrix,2), 'LineWidth', 2, 'color', plotColor)
        plot(mean(meanMatrix,2)+std(meanMatrix,[],2),'--','LineWidth', 1, 'color', black)
        plot(mean(meanMatrix,2)-std(meanMatrix,[],2),'--','LineWidth', 1, 'color', black)
        
        % Allow for the subplots to be expanded by clicking on them
        set(gca, 'ButtonDownFcn', [...
        'set(copyobj(gca, uipanel(''Position'', [0 0 1 1])), ' ...
        '    ''Units'', ''normal'', ''OuterPosition'', [0 0 1 1], ' ...
        '    ''ButtonDownFcn'', ''delete(get(gca, ''''Parent''''))''); ']);
        
    end
end