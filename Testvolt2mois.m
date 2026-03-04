classdef Testvolt2mois < matlab.unittest.TestCase
    
    methods (Test)
        function testCalibrationPoints(testCase)

            voltage1 = 2.8;
            expected1 = 30;
            actual1 = volt2mois(voltage1);
            
            voltage2 = 2.3;
            expected2 = 70;
            actual2 = volt2mois(voltage2);
            
            testCase.verifyEqual(actual1, expected1);
            testCase.verifyEqual(actual2, expected2);
           
        end
        
        function testLinearBehavior(testCase)

            midVoltage = (2.8 + 2.3) / 2;
            expectedMid = (30 + 70) / 2;
            actualMid = volt2mois(midVoltage);
   
            voltage25 = 2.8 + 0.25 * (2.3 - 2.8); 
            expected25 = 30 + 0.25 * (70 - 30);
            actual25 = volt2mois(voltage25);
            
            voltage75 = 2.8 + 0.75 * (2.3 - 2.8);
            expected75 = 30 + 0.75 * (70 - 30);
            actual75 = volt2mois(voltage75);
            
            actualMid_rounded = round(actualMid, 2);
            actual25_rounded = round(actual25, 2);
            actual75_rounded = round(actual75, 2);

            testCase.verifyEqual(actualMid_rounded, expectedMid);
            testCase.verifyEqual(actual25_rounded, expected25);
            testCase.verifyEqual(actual75_rounded, expected75);
            
        end
    end
end