%% Connecting board and sensors

if (~exist("a"))
    a = arduino;
end

if (~exist("sgp30obj"))
    sgp30obj = sgp30(a); 
end

%% Assigning Thresholds and variables

Air = 3.6;
Hand = 2.9;
Dry_Soil = 2.8;
Wet_Towel = 2.6;
Wet_Soil = 2.3;
Water = 2.0;

% How long does it take to empty 1 litre of water?
17;

Co2Max = 1000;

%% Setting up Live graph

startTime = tic;

figure(3);
h = animatedline('Color', 'g', 'DisplayName', 'Moisture %');
xlabel('Time (seconds)');
ylabel('Percentage (%)');
ylim([0 100]);
title('Real-time Moisture Data (Percentage)');
grid on;

yline(30, '-r', 'Dry Threshold (30%)', 'LineWidth', 2);
yline(70, '-c', 'Wet Threshold (70%)', 'LineWidth', 2);


%% Graphing the thresholds in percentage form

CharMoisture = [0 10 30 50 70 100];
CharVolt = [3.6, 2.9, 2.8, 2.6, 2.3, 2.0];

p = polyfit(CharMoisture, CharVolt, 1);
m = p(1);
c = p(2);

figure(1);
plot(CharMoisture, CharVolt, 'ko', 'MarkerSize', 10, 'MarkerFaceColor', 'w');
hold on;
y_fit = polyval(p, CharMoisture);
plot(CharMoisture, y_fit, 'r-', 'LineWidth', 1.5);
hold off;

xlabel('Moisture (%)');
ylabel('Voltage (V)');
title('Moisture Characterization/Calibration Curve');
grid on;
legend('Calibration Points', sprintf('Fit: V = %.3fM + %.3f', m, c), 'Location', 'best');
hold off

States = {'Dry Soil', 'Hand', 'Wet Soil', 'Water', 'Wet Towel', 'Air'};
y = [Dry_Soil, Hand, Wet_Soil, Water, Wet_Towel, Air];
y2 = volt2mois(y);

figure(2);
x = 1:length(y2);

colors = ['r', 'g', 'm', 'y', 'c', 'b'];
markers = {'*', 'o', '+', 's', 'd', 'h'};

hold on;

plot(x, y2, '-r');

for i = 1:length(y2)
    plot(x(i), y2(i), 'Marker', markers{i},'MarkerFaceColor', colors(i), 'LineStyle', '-', 'DisplayName', States{i});
end

hold off;

legend;
xlabel('Sample Number');
ylabel('Moisture Percentage (%)');
title('Moisture Readings for Different Materials');
grid on;

%% While Loop

figure(3);
shg

% Initialize Data Logging
logFile = 'moisture_log.csv';
if ~exist(logFile, 'file')
    fileID = fopen(logFile, 'w');
    fprintf(fileID, 'Timestamp,Moisture_V,Moisture_Percent,CO2_ppm,Status\n');
    fclose(fileID);
end

while true
    currentTime = toc(startTime);
    timestampStr = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    
    Moisture = readVoltage(a, "A1");
    Co2 = readEquivalentCarbondioxide(sgp30obj);
    
    Moisture_Percent = volt2mois(Moisture);
    
    fprintf('Current Moisture = %0.2fV (%0.1f%%) and current Co2 = %0.0f ppm\n\n', Moisture, Moisture_Percent, Co2);
    
    % Log Data
    fileID = fopen(logFile, 'a');
    status = "Monitoring";
    if Moisture > Dry_Soil
        status = "Watering";
    end
    fprintf(fileID, '%s,%0.2f,%0.1f,%0.0f,%s\n', timestampStr, Moisture, Moisture_Percent, Co2, status);
    fclose(fileID);

    addpoints(h, currentTime, Moisture_Percent);
    drawnow;
    
    if Moisture > Dry_Soil
        if Co2 > Co2Max
            fprintf("Co2 is High! Watering less to avoid fungus!\n\n")
            writeDigitalPin(a, "D2", 1);
            
            % Water for 3 seconds with monitoring
            for i = 1:3
                currentMoisture = readVoltage(a, "A1");
                currentCo2 = readEquivalentCarbondioxide(sgp30obj);
                currentMoisturePercent = volt2mois(currentMoisture);
                currentTime = toc(startTime);
                
                fprintf('  [Watering %d/3s] Moisture = %0.2fV (%0.1f%%), Co2 = %0.0f ppm\n', i, currentMoisture, currentMoisturePercent, currentCo2);
                
                % Update graph during watering
                addpoints(h, currentTime, currentMoisturePercent);
                drawnow;
                
                %Check for Emergency Button
                if readDigitalPin(a, "D6")
                    writeDigitalPin(a, "D2", 0);
                    error("Emergency Stop Activated");
                end
                pause(1);
            end
            writeDigitalPin(a, "D2", 0);
            
        else
            fprintf("It's Dry! Time to Water!\n\n")
            writeDigitalPin(a, "D2", 1);
            
            % Water for 5 seconds with monitoring
            for i = 1:5
                currentMoisture = readVoltage(a, "A1");
                currentCo2 = readEquivalentCarbondioxide(sgp30obj);
                currentMoisturePercent = volt2mois(currentMoisture);
                currentTime = toc(startTime);
                
                fprintf('  [Watering %d/5s] Moisture = %0.2fV (%0.1f%%), Co2 = %0.0f ppm\n', i, currentMoisture, currentMoisturePercent, currentCo2);
                
                % Update graph during watering
                addpoints(h, currentTime, currentMoisturePercent);
                drawnow;

                %Check for Emergency Button
                if readDigitalPin(a, "D6")
                    writeDigitalPin(a, "D2", 0);
                    error("Emergency Stop Activated");
                end
                pause(1);
            end
            writeDigitalPin(a, "D2", 0);
        end
        
    else 
        fprintf("It's Wet! Not Watering!\n\n")
        writeDigitalPin(a, "D2", 0);
        
        % Monitor for 5 seconds without watering
        for i = 1:5
            currentMoisture = readVoltage(a, "A1");
            currentCo2 = readEquivalentCarbondioxide(sgp30obj);
            currentMoisturePercent = volt2mois(currentMoisture);
            currentTime = toc(startTime);
            
            fprintf('  [Monitoring %d/5s] Moisture = %0.2fV (%0.1f%%), Co2 = %0.0f ppm\n', i, currentMoisture, currentMoisturePercent, currentCo2);
            
            % Update graph during monitoring
            addpoints(h, currentTime, currentMoisturePercent);
            drawnow;

            %Check for Emergency Button
            if readDigitalPin(a, "D6")
                writeDigitalPin(a, "D2", 0);
                error("Emergency Stop Activated");
            end
            pause(1);
        end
    end
    
    sprintf("Waiting for 55 seconds...\n")
    
    % Wait for 55 seconds
    for i = 1:55
        currentMoisture = readVoltage(a, "A1");
        currentCo2 = readEquivalentCarbondioxide(sgp30obj);
        currentMoisturePercent = volt2mois(currentMoisture);
        currentTime = toc(startTime);
        fprintf('  [Monitoring %d/55s] Moisture = %0.2fV (%0.1f%%), Co2 = %0.0f ppm\n', i, currentMoisture, currentMoisturePercent, currentCo2);
        
        % Update graph during waiting
        addpoints(h, currentTime, currentMoisturePercent);
        drawnow;
        
        %Check for Emergency Button
        if readDigitalPin(a, "D6")
            writeDigitalPin(a, "D2", 0);
            error("Emergency Stop Activated");
        end
        pause(1);
    end
end