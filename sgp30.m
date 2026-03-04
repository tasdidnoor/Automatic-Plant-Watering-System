% Connects to an SGP30 sensor connected to a hardware object that supports I2C (e.g. an arduino).
% ==================================================================================================
% SGP30 eCO2/TVOC sensor class
% By: Eric Prandovszky
% prandov@yorku.ca
% Version 0.8.1
% Nov 05 2024
% Based on: MATLAB's CCS811 eCO2/TVOC sensor class, SGP30-Java by vkaam was also used as a resource
% *Many comments, hopefully it helps
% v0.8.1 Updated to work with r2024+ where device.read() is no longer available and 
% SupportedInterfaces property has been added.
%==================================================================================================

% https://www.mathworks.com/help/matlab/matlab_oop/class-attributes.html
% https://www.mathworks.com/help/matlab/matlab_oop/specifying-methods-and-functions.html

%classdef MyAddon < base class (Inherit your custom add-on class from another class e.g. matlabshared.addon.LibraryBase)
classdef (Sealed) sgp30 < matlabshared.sensors.sensorUnit & matlabshared.sensors.EquivalentCarbondioxide & matlabshared.sensors.TotalVolatileOrganicCompounds
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
% Connecting to the SGP30
%   Create an arduino object with I2C 
%       serialDevices = serialportlist; 
%   Usually the arduino's serial is the last value, otherwise, specify the port
%       a = arduino(serialDevices(end),'Nano3','Libraries',{'I2C'});
%       sgp30obj = sgp30(a);
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
% SGP30 methods:
%   Function:                                 DataType:     Location:
%   getReadings(obj)                          1x2 uint16    sgp30.m\getReadings
%   readEquivalentCarbondioxide(obj)          1x2 uint16    EquivalentCarbondioxide.m\readEquivalentCarbondioxide
%   readTotalVolatileOrganicCompounds(obj)    1x2 uint16    TotalVolatileOrganicCompounds.m\readTotalVolatileOrganicCompounds
%   setHumidity(obj,humidityIn)               1x1 any       sgp30.m\setHumidity
%   selfTest(obj)                             1x1 logical   sgp30.m\selfTest
%   info(obj)                                 1x1 struct    sgp30.m\infoImpl     
%   flush(obj)                                              sensorInterface.p\resetImpl
%
% *Not working yet - These are to do with streaming data
%   *read                                                   sensorUnit.m  read(obj)
%   *stop/release                                           sensorUnit.m  releaseImpl
%   *softResetBus(obj)                                      sgp30.m\softResetBus
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
% Some SGP30 Properties can be read to retreive information
% obj.featureSet        Returns 34
% obj.serialNumber      Returns the stored serial number as an 'uint64'
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
% SGP30 eC02 Sensor commands and timings
% I2CAddress: 0x58
% I2C Commands:
% _____________________________________________________________________________________________
%   Init_air_quality = 0x2003         No Response
%   Measure_air_quality = 0x2008      Read: 6 bytes incl CRC  Delay: Typ.2ms   Max.10ms
%   Get_serial_ID = 0x3682            Read: 9 bytes incl CRC  Delay: Typ.10ms  Max.12ms
%   Get_baseline = 0x2015             Read: 6 bytes incl CRC  Delay: Typ.10ms  Max.10ms
%   Set_baseline = 0x201E             Send: 6 bytes incl CRC  Delay: Typ.10ms  Max.10ms
%   Set_humidity = 0x2061             Send: 3 bytes incl CRC  Delay: Typ.1ms   Max.10ms
%   Measure_test = 0x2032             Read: 3 bytes incl CRC  Delay: Typ.200ms Max.220ms
%                                     On_chip self test returns 0xD400 
%   Get_feature_set_Version = 0x202F  Read: 3 bytes incl CRC  Delay: Typ.1ms   Max.2ms
%   Measure_raw_signals = 0x2050      Read: 6 bytes incl CRC  Delay: Typ.20ms  Max.25ms
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

% Properties---------------------------------------------------------------------------------------
    % https://www.mathworks.com/help/matlab/matlab_oop/property-attributes.html
    % Determining Property Access: 
        % public – unrestricted access
        % protected – access from class or subclasses
        % private – access by class members only (not subclasses)
        % Access List
        % Hidden - Determines if the property can be shown in a property list
        % Constant - Set to true if all instances of the class share the same value
        % Nontunable - When a System object has started processing data, you cannot change nontunable properties.
% Properties---------------------------------------------------------------------------------------
    properties(SetAccess = protected, GetAccess = public, Hidden)
    %"Measure_air_quality" command has to be sent in regular intervals of 1s(One Second) to ensure proper operation of the dynamic baseline compensation algorithm. 
        MinSampleRate = 1;
        MaxSampleRate = 200;
        %verbose = true; %Enables Logging %Moved2Constant
        serialNumber;
        featureSet;
    end
% Properties---------------------------------------------------------------------------------------
    properties(Nontunable, Hidden)
        % Not sure why this is here
        DoF = [1;1];
    end
% Properties---------------------------------------------------------------------------------------
    properties(Access = protected, Constant)
        ODRParameters = [1,7,12.5];                     % OutputDataRate
        EquivalentCarbondioxideDataRegister = 0x2008;	% defined in matlabshared.sensors.EquivalentCarbondioxide
        TVOCDataRegister = 0x2008;                   	% defined in matlabshared.sensors.TotalVolatileOrganicCompounds
    end
% Properties---------------------------------------------------------------------------------------
    properties(Access = protected, Constant)
        SupportedInterfaces = 'I2C';
    end
% Properties---------------------------------------------------------------------------------------
    properties(Access = {?matlabshared.sensors.coder.matlab.sensorInterface, ?matlabshared.sensors.sensorInterface}, Constant)
        I2CAddressList = 0x58; %SGP30 = 0x58
    end
% Properties---------------------------------------------------------------------------------------
    properties(Access = protected,Nontunable) %Based on ccd811.m
        % protected: access from class or subclasses
        DriveMode;
        IsActiveInterrupt = false;
        EnvironmentInput = 'Mask dialog';
        HumidityData = 50;
        TemperatureData = 25;
        DataType = 'double';
    end
% Properties---------------------------------------------------------------------------------------
    properties(Access = private)
        Odr;
    end
% Properties---------------------------------------------------------------------------------------
    properties(Hidden, Constant)
        % # of 16 bit words to read (without CRC)
        WordsReadInit = 0; %No Response
        WordsReadAirQuality = 2;
        WordsReadSerailnumber = 3;
        WordsReadGetBaseline = 2;
        WordsReadSetBaseline = 0; %Send 6 Bytes
        WordsReadSetHumidity = 0; %Send 3 Bytes
        WordsReadMeasureTest = 1;
        WordsReadGetFeatureSet = 1;
        WordsReadMeasureRaw = 2;
        %I2C Delay
        Delay4IAQInit = 10; %ms Not defined in Datasheet SGP30.java uses 10ms
        Delay4ReadAirQuality = 2;   %Typ.2ms  Max.10ms
        Delay4ReadSerialNumber = 10;%Typ.10ms Max.12ms
        Delay4GetBaseline = 10;     %Typ.10ms Max.10ms
        Delay4SetBaseline = 10;     %Typ.10ms Max.10ms
        Delay4SetHumidity = 1;      %Typ.1ms  Max.10ms
        Delay4MeasureTest = 200;    %Typ.200ms Max.220ms
        Delay4GetFeatureSet = 1;    %Typ.1ms  Max.2ms
        Delay4MeasureRawSig = 20;   %Typ.20ms Max.25ms
        %CRC
        crc8Polynomial = 0x31;
        crc8Init = 0xFF;

        HumidityLimit = 82;         %Max Practical Humidity (a 50°C steam room at 100% humidity)
        %HumidityLimit = 255;       %Max possible Humidity (a 177°C Oven at 5% humidity)

        verbose = false;            %Enables Logging
    end
%methods-------------------------------------------------------------------------------------------
    % https://www.mathworks.com/help/matlab/matlab_oop/how-to-use-methods.html
    % https://www.mathworks.com/help/matlab/matlab_oop/method-attributes.html
%--------------------------------------------------------------------------------------------------
% Public methods — Unrestricted access    
% Constructor(Public)------------------------------------------------------------------------------
    methods
        function obj = sgp30(varargin)
            obj@matlabshared.sensors.sensorUnit(varargin{:})
            if ~obj.isSimulink  %is not simulink
                % Code generation does not support try-catch block. So init
                % function call is made separately in both codegen and IO
                % context.
                if ~coder.target('MATLAB')  %'MATLAB'	Running in MATLAB (not generating code)
                    names = {'Bus','I2CAddress'};
                    defaults = {[],0x58};
                    
                    p = matlabshared.sensors.internal.NameValueParserInternal(names, defaults ,false);
                    p.parse(varargin{2:end});

                    obj.init(varargin{:}); %sensorUnit.init
                else % Matlab
                    try
                        names = {'Bus','I2CAddress'};
                        defaults = {[],0x58};
                       
                        p = matlabshared.sensors.internal.NameValueParserInternal(names, defaults ,false);
                        p.parse(varargin{2:end});

                        obj.init(varargin{:}); % *{:} will form a comma-separated list
                    catch ME
                        throwAsCaller(ME);
                    end
                end
                %setting the properties of the object:
                obj.DriveMode = '1';
                obj.EnvironmentInput = 'Mask dialog';
                obj.HumidityData = 50;
                %obj.TemperatureData = 25;
                obj.IsActiveInterrupt = false;
                obj.DataType = 'uint16';    
                %obj.verbose = true; %Enables Logging

            else %Simulink
                %names =    {'Bus','IsActiveHumidity','IsActiveTemperature','OutputDataRate'};
                %defaults = {0,true,true,1};
                names = {'Bus','I2CAddress'};
                defaults = {0,0x58};

                p = matlabshared.sensors.internal.NameValueParserInternal(names, defaults ,false);
                p.parse(varargin{2:end});
                bus =  p.parameterValue('Bus');
                obj.init(varargin{1},'Bus',bus);
               % obj.IsActiveHumidity=p.parameterValue('IsActiveHumidity');
            end
            sgp30.logme(dbstack,'SGP30 Library v0.7'); 
            sgp30.logme(dbstack,'SGP30 Object Created'); 
        end
%Public method-------------------------------------------------------------------------------------
        function pass = selfTest(obj)
            %Returns true: pass, false: fail
            sgp30.logme(dbstack,'Public');
            %Measure_test = 0x2032 Read: 3 bytes incl. CRC  Delay: Typ.200ms Max.220ms
            %On_chip self-test returns 0xD400 
            command = [0x20 0x32]; 
            delay = sgp30.Delay4MeasureTest;
            replysize = sgp30.WordsReadMeasureTest;
            data = obj.commandSendOrReceive(command, delay, replysize);
            if data == 0xD400 %Self-test Passed
                pass = true;
            else %Self-test Failed
                pass = false;
            end
        end
%Public method-------------------------------------------------------------------------------------
        function data = getReadings(obj)
            %Returns eCO2 and tVOC readings in a row Vector
            obj.logme(dbstack,'Public');
           %[data,status,timestamp] = readSensorDataImpl(obj);
            [data,~,~] = readSensorDataImpl(obj); %Removed status, timestamp
        end
%Public method-------------------------------------------------------------------------------------
        function setHumidity(obj,humidityIn)
        %Provides access to the static method "setIaqHumidity"
        %otherwise you must type 'spp30obj' twice: "sgp30obj.setIaqHumidity(sgp30obj,humiditygm3);"
            obj.logme(dbstack,'Public');
            sgp30.setIaqHumidity(obj,humidityIn);
        end
%Public method-------------------------------------------------------------------------------------
        function softResetBus(obj)
            %Perform a soft reset of all devices on the I2C Bus.
            obj.logme(dbstack,'Public');
            %sgp30.resetSGP30(obj);
            %gp30.iaqInit(obj);                          %Send Init Command
            disp('Bus reset not working, try deleting and re-creating your sensor object');
        end
    end%of public methods
%--------------------------------------------------------------------------------------------------  
%Protected methods — Access from methods in class or subclasses
    methods(Access = protected)
%Protected method----------------------------------------------------------------------------------% defined in matlabshared.sensors.sensorUnit	
        function initDeviceImpl(obj)  
           %for initialization which is common to all the sensors on the device (Example: powering up the mag unit in MPU9250)
           sgp30.logme(dbstack,'Protected');
           %get_feature_set, store it as an object property
           obj.featureSet = sgp30.loadFeatureset(obj);
           fprintf('SGP30 Feature Set: 0x%X \n',obj.featureSet);
           %get_serial_number, store it as an object property
           obj.serialNumber = sgp30.loadSerial(obj);
           fprintf('SGP30 Serial#: 0x%X\n',obj.serialNumber);
           %fprintf('SGP30 Serial#: 0d%d\n',obj.serialNumber);
        end
%Protected method----------------------------------------------------------------------------------% defined in matlabshared.sensors.sensorUnit        
        function initSensorImpl(obj)
           %for individual sensor inits
           sgp30.logme(dbstack,'Protected');
           sgp30.iaqInit(obj);                          %Send Init Command
           %initEquivalentCarbondioxideImpl(obj);        %Commented out(for now).
           %initTotalVolatileOrganicCompoundsImpl(obj);  %Does nothing
           java.lang.Thread.sleep(1); %No init delay defined in Datasheet, try 1ms.
        end
%Protected method----------------------------------------------------------------------------------% defined in matlabshared.sensors.sensorUnit
        function [data,status,timeStamp] = readSensorDataImpl(obj)      
        sgp30.logme(dbstack,'Protected'); 
        %Measure_air_quality = 0x2008      Read: 6 bytes incl CRC  Delay: Typ.2ms   Max.10ms
        command = [0x20 0x08]; 
        delay = sgp30.Delay4ReadAirQuality;
        replysize = sgp30.WordsReadAirQuality;

        data = obj.commandSendOrReceive(command, delay, replysize);
        status = 0; %Status can take 3 values namely -1 sensor not used, 0 data available, 1 data not yet available
        timeStamp = datetime('now','TimeZone','local','Format','d-MMM-y HH:mm:ss.SSS');
        end
%Protected method----------------------------------------------------------------------------------
        %Access provided by the handle EquivalentCarbondioxide.m\readEquivalentCarbondioxide
        function [eCO2,status,timestamp]  = readEquivalentCarbondioxideImpl(obj,varargin)

            sgp30.logme(dbstack,'Protected'); 
            [data,status,timestamp] = readSensorDataImpl(obj);
            eCO2 = data(1);
        end
%Protected method----------------------------------------------------------------------------------
        %Access provided by the handle TotalVolatileOrganicCompounds.m\readTotalVolatileOrganicCompounds
        function [TVOC,status,timestamp]  = readTotalVolatileOrganicCompoundsImpl(obj,varargin)  

        sgp30.logme(dbstack,'Protected'); 
        [data,status,timestamp] = readSensorDataImpl(obj);
        TVOC = data(2);
        end
%Protected method----------------------------------------------------------------------------------%defined in matlabshared.sensors.sensorUnit 	
        function data = convertSensorDataImpl(data) 
            %Not used, seems to be required as part of sensorUnit
            %convert i2c response uint8 array to proper datatype eg. 2 bytes to one word
            sgp30.logme(dbstack,'Protected'); 

                data = bitor(uint16(data(:,1)),bitshift(uint16(data(:,2)),8));     %fyi ":" represents an entire row or column
        end
%Protected Method----------------------------------------------------------------------------------% defined in matlabshared.sensors.sensorUnit
        function names = getMeasurementDataNames(obj)
            sgp30.logme(dbstack,'Protected'); 

            names = [obj.EquivalentCarbondioxideDataName,obj.TotalVolatileOrganicCompoundsDataName];
        end
%Protected method----------------------------------------------------------------------------------%defined in matlabshared.sensors.sensorBase             	
        function setODRImpl(obj)
            sgp30.logme(dbstack,'Protected'); 

            gasODR = obj.ODRParameters(obj.ODRParameters<=obj.SampleRate);
            obj.Odr = gasODR(end);
        end
%Protected method----------------------------------------------------------------------------------%defined in matlabshared.sensors.sensorInterface
        function s = infoImpl(obj) %ccs811.m infoImpl

            s = struct('DriveMode',obj.DriveMode);
            %Maybe Add serial Number & sensorVersion here?
        end
%Protected method----------------------------------------------------------------------------------
        %defined in TotalVolatileOrganicCompounds.m Handle Class, so also defined here
        function initEquivalentCarbondioxideImpl(obj)
              obj.logme(dbstack,'Protected'); 
%             changeFromBootToAppMode(obj);
%             if coder.target('Rtw')
%                 obj.Parent.delayFunctionForHardware(100);
%             elseif coder.target('MATLAB')
%                 pause(0.1);
%             end
        end
%Protected Method------initTotalVolatileOrganicCompoundsImpl(obj)
        % Defined in TotalVolatileOrganicCompounds.m Handle Class, so also defined here
        function initTotalVolatileOrganicCompoundsImpl(obj) %does nothing?
        obj.logme(dbstack,'Protected'); 
        end
    end%of protected methods
%--------------------------------------------------------------------------------------------------
% Static Methods — Associated with a class, but not with specific instances of that class
% Invoke static methods using the name of the class followed by dot eg. classname.staticMethodName(args,...)
% You can also invoke static methods using an instance of the class, like any method: 
% obj = MyClass;
% value = obj.pi(.001);
% https://www.mathworks.com/help/matlab/matlab_oop/static-methods.html
%--------------------------------------------------------------------------------------------------
    methods(Static,Hidden)
%Static Method-------------------------------------------------------------------------------------
        % Setup as a static function, type: sgp30.logme('message to log');
        function logme(lineNumStruct,messageToLog) %  Logging function
            %obj.verbose = true;
            %getfield(LineNum(1),'line') % |Use Dynamic Fieldnames instead
            %mFile = lineNumStruct.('file'); 
            if sgp30.verbose
                mLine = lineNumStruct.('line');
                mMethod = lineNumStruct.('name');
                fprintf('log:    Line#%i   Method:%s    %s \n', mLine(1), mMethod , messageToLog);
            end
        end
%Static Method-------------------------------------------------------------------------------------
        function featureset = loadFeatureset(obj) %Obj init Method_3
            sgp30.logme(dbstack,'Static');
            % Get_feature_set_Version = 0x202F  Read: 3 bytes incl CRC  Delay: Typ.1ms   Max.2ms
            command = [0x20 0x2F]; 
            delay = sgp30.Delay4GetFeatureSet;
            replysize = sgp30.WordsReadGetFeatureSet;
            featureset = obj.commandSendOrReceive(command, delay, replysize);
            %feature set should be 0x0020
        end
%Static Method-------------------------------------------------------------------------------------
        function serialNumber = loadSerial(obj) %Obj init Method_2
            sgp30.logme(dbstack,'Static');
            % Get_serial_ID = 0x3682 Read: 9 bytes incl CRC  Delay: Typ.10ms  Max.12ms
            command = [0x36 0x82]; %{} Cell Array,[] Regular array
            delay = sgp30.Delay4ReadSerialNumber;
            replysize = sgp30.WordsReadSerailnumber;
            serialFourWords(2:4) = obj.commandSendOrReceive(command, delay, replysize); %48-bit Serial stored as 3X uint16 with 16 padding bits
            serialNumber = swapbytes(typecast(swapbytes(serialFourWords),'uint64'));    %Must use swapbytes twice or else data is wrong      
        end
%Static Method-------------------------------------------------------------------------------------
        function setIaqHumidity(obj,humidityIn)
            %Set Humidity in gramsPerM^3
            sgp30.logme(dbstack,'Static');
            %Set_humidity = 0x2061             Send: 3 bytes incl CRC  Delay: Typ.1ms   Max.10ms

            %Original Java code wirtes the command and humidity value  together:
            %Java: byte[] command = new byte[]{0x20, 0x61, (byte) arr[0], (byte) arr[1], (byte) generateCrc(arr)};
           
            % Absolute (g/m^3) to Relative (%) Humidity Converter: https://www.cactus2000.de/uk/unit/masshum.shtml
            % Humidity for SGP30 is stored as two Bytes in 8.8 notation: MSB is 0-255g/m^3, LSB is 0/256-255/256 g/m^3
            % AbsoluteHumidity(g/m3) = (6.112 × e^[(17.67 × T)/(T+243.5)] × rh × 18.02) / ((273.15+T) × 100 × 0.08314)
            % T=degrees Celsius, rh= relative humidity in %, e=the base of natural log 2.71828[to the power of the square brackets]:
 
            %SGP30 default humidity Value:  11.57 g/m^3 (50.3%RH @25°C)   [0x0B92]
            %Today in the lab, humidity is  5.373 g/m^3 (26%RH @ 23.1°C)  [0x055F]
            humidityScaled = humidityIn * 256;  
            humidityInt16 = cast(humidityScaled,'uint16');
            humiditybytes = typecast(swapbytes(humidityInt16),'uint8');
            
            command = [0x20 0x61];
            command(3:4) = humiditybytes;
            command(5) = generateCrc(obj,humiditybytes);
            delay = sgp30.Delay4SetHumidity;         %1ms
            replysize = sgp30.WordsReadSetHumidity;  %No Reply
            %Validate humidity. A 50°C steam room with 100% humidity is 82g per M^3, let's use that limit.
            if humidityIn < sgp30.HumidityLimit
            obj.commandSendOrReceive(command, delay, replysize);
            else 
                disp('invalid humidity, SGP30 humidity value not updated');
            end
        end
%Static Method-------------------------------------------------------------------------------------
        function resetSGP30(obj)
            %A soft reset can be triggered using the "General Call" mode according to I2C-bus specification.
            % *All sensors on the bus that support this will be reset using this command.
            % Address byte 0x00, Second byte 0x06. Reset Command using the General Call address 0x0006
            obj.logme(dbstack,'Static');
        %Need to find out how to write to i2c address 0x00
            %obj.write(i2CAddress,Command);
            %command = [0x00 0x06];
            %device.write(command); %General Bus command to all devices on bus
            %device.write(0x00,0x06); %General Bus command to all devices on bus
            java.lang.Thread.sleep(sgp30.Delay4IAQInit);
        end
%Static Method-------------------------------------------------------------------------------------
%Not needed for now. May be implemented later
        function data = getBaseLine(obj)
        %Retreive the baseline values for inspection, or to be stored before device reset
            sgp30.logme(dbstack,'Static');
            %Get_baseline = 0x2015             Read: 6 bytes incl CRC  Delay: Typ.10ms  Max.10ms
            command = [0x20 0x15]; 
            delay = sgp30.Delay4GetBaseline;
            replysize = sgp30.WordsReadGetBaseline;
            data = obj.commandSendOrReceive(command, delay, replysize);
        end
%Static Method-------------------------------------------------------------------------------------
%Not needed for now. May be implemented later
        function setBaseline(obj,eCO2,TVOC)
        %Used to restore Baseline correction values after a power-up or soft reset 
        %Baseline values can be restored by sending "Init_air_quality" followed by "Set_baseline" commands
            sgp30.logme(dbstack,'Static');
            % Set_baseline = 0x201E Send: 6 bytes incl. CRC  Delay: Typ.10ms  Max.10ms
            command = [0x20 0x1E];
            command(3) = eCO2(1);
            command(4) = eCO2(2);
            command(5) = generateCrc(obj,eCO2);
            command(6) = TVOC(1);
            command(7) = TVOC(2);
            command(8) = generateCrc(obj,TVOC);
            write(obj.Device,command);
            java.lang.Thread.sleep(Delay4SetBaseline);
        end
%Static Method-------------------------------------------------------------------------------------
        function iaqInit(obj)
            %The "Init_air_quality" command has to be sent after every power-up or soft reset.
            sgp30.logme(dbstack,'Static');
            %Init_air_quality = 0x2003         No Response
            command = [0x20 0x03]; 
            write(obj.Device,command);
            java.lang.Thread.sleep(sgp30.Delay4IAQInit);
        end
%Notes:--------------------------------------------------------------------------------------------
%Removed getBaseLineECO2 & getBaseLineTVOC, These values are returned together. Use getBaseline instead
%Removed writeEnvironmentValues becaue SGP30 only has humidity, and is updated separately
    end%of Static methods
%--------------------------------------------------------------------------------------------------
%Private Methods — Access by class methods only (not from subclasses)
methods(Access = private)
%Private Method------------------------------------------------------------------------------------
    function resultWords = commandSendOrReceive(obj, command, delay, replySizeWords)
        %This function returns data from the SGP30 in 16-bit words. 
        %Can now also send data if needed
        sgp30.logme(dbstack,'Private');
        if replySizeWords > 0 %If expecting a reply, we will read the response
            readSizeBytes = replySizeWords*3; %Each 16-bit word is followed by an 8-bit CRC checksum
            % MATLAB help-tip said to Pre-Allocate for speed:
            responseBytes = zeros(1,readSizeBytes,"uint8"); % pre-allocate response array
            resultWords = zeros(1,replySizeWords,"uint16"); % pre-allocate response array
            %Send command to device
            write(obj.Device,command); %Write can send multiple bytes. Can also define precision, but I've not tested it
            java.lang.Thread.sleep(delay); %Pause for delay time
            % sensorUnit.m function: readRegisterData(obj, DataRegister, numBytes, precision)
            % I2CDeviceWrapper.m function writeRegister(obj, registerAddress, data, precision)
            % OLD ResponsePlusCRC = read(obj.Device, readSizeBytes,"uint8");
            % NEW I2CsensorDevice.readRegister(obj, registerAddress, numBytes, precision)
            ResponsePlusCRC = readRegister(obj.Device,0x00, readSizeBytes,"uint8");
            for i = 1:readSizeBytes
                responseBytes(i) = bitand(ResponsePlusCRC(i),0xff); %bitmask to convert reply to uint8
            end
            for i = 1:replySizeWords
                dataBytes(1) = responseBytes(3*i-2); %Word Upper Byte
                dataBytes(2) = responseBytes(3*i-1); %word Lower Byte
                crcByte = responseBytes(3*i);        %Word CRC Byte
                crcCheck = obj.generateCrc(dataBytes);
                if crcCheck ~= crcByte
                    sgp30.logme(dbstack,'CRC Error');
                    error("CRC error " + crcByte + " != " + crcCheck + " for crc check " + i);
                end
                resultWords(i) = bitor(bitshift(cast(dataBytes(1),"uint16"),8),cast(dataBytes(2),"uint16")); %combine 2 bytes to 1 word
                % resultWords(i) = swapbytes(typecast(dataBytes,'uint16')) %Also works using typecast and swapbytes
                % https://www.mathworks.com/help/matlab/ref/typecast.html  typecast joines little endian for some reason
                % https://www.mathworks.com/help/matlab/ref/swapbytes.html
            end
        else %when not expecting a reply
            write(obj.Device,command); %Write can send any number of bytes.
            java.lang.Thread.sleep(delay);  %Pause for delay time
        end
    end
%Private Method------------------------------------------------------------------------------------
    function crcOut = generateCrc(obj,data)
        obj.logme(dbstack,' ');
        % https://www.mathworks.com/help/matlab/matlab_prog/perform-cyclic-redundancy-check.html
        % Online calculator: http://www.sunshine2k.de/coding/javascript/crc/crc_js.html 
        crc = sgp30.crc8Init;               %SGP30 crc8Init is 0xFF;
        polynomial = sgp30.crc8Polynomial;   %SGP30 crc8Polynomial is 0x31
        for k= 1:length(data)
            bt = uint8(data(k));
            crc = bitxor(crc,bt);
            for  i = 1:8
                test = bitand(crc,0x80);
                if test ~= 0
                    crc = bitxor(bitshift(crc,1),polynomial); 
                else
                    crc = bitshift(crc,1);
                end
            end
        end
        crcOut = bitand(crc,0xFF); %Converts to uint8
        % SGP30 Datasheet Example CRC: 0xBEEF = 0x92
    end
%Private Method------------------------------------------------------------------------------------
%Not Used for now
    %ccs811.m  changeFromBootToAppMode(obj) called by initEquivalentCarbondioxideImpl(obj) 
    function changeFromBootToAppMode(obj)
        write(obj.Device, obj.APPStartRegister);
    end
end%of private Methods
%--------------------------------------------------------------------------
%Hidden Methods
    methods(Hidden = true)
          %
    end%of Hidden Methods
%--------------------------------------------------------------------------
end%of SGP30 class
%==========================================================================
%% NOTES:
% Arduino I2C Communication Methods
% Path: C:\ProgramData\MATLAB\SupportPackages\R2022b\toolbox\matlab\hardware\shared\sensors\+matlabshared\+sensors\+coder\+matlab\device.m

%% decvice          I2C device connection on Arduino or ESP32 hardware bus
%   deviceObj = device(arduinoObj,'I2CAddress',I2CAddress,Name,Value) 
%       Creates an object that represents the connection between an I2C peripheral connected to the central Arduino or ESP32 hardware. 
%       The Arduino or ESP32 hardware is represented by an arduino object. 
%       You can also customize the connection further using one or more name-value pairs. 
%       The 'I2CAddress' name-value pair is mandatory for creating the I2C device connection.

%% scanI2CBus       Scan I2C bus on Arduino hardware for device address
%   addr = scanI2CBus(a,bus) 
%       Scans the specified bus on the Arduino® hardware in object a and stores it in the variable addr.

%% read	            Read data from I2C bus
%   out = read(dev,numBytes) returns data read from the I2C bus based on the number of bytes.
%   out = read(dev,numBytes,precision) also specifies the data precision.
%% readRegister	    Read data from I2C device register
%   out = readRegister(dev,register) returns data read from the I2C device register.
%   out = readRegister(dev,register,precision) also specifies the data precision.

%% write	        Write data to I2C bus
%   write(dev,dataIn) writes data to the I2C bus.
%   write(dev,dataIn,precision) also specifies the precision.
%       precision: 'uint8' (default) | 'int8' | 'uint16' | 'int16' | 'uint32' | 'int32' | 'uint64' | 'int64'
%   write(obj.Device,);
%% writeRegister    Write data to I2C device register
%   writeRegister(dev,register,dataIn) writes data to the I2C device register
%   writeRegister(dev,register,dataIn,precision) also specifies the data precision.

%% validateRegisterAddress and validateI2CAddress  