function Percentage = volt2mois(voltage)
    x1 = 2.8;
    y1 = 30;
    
    x2 = 2.3;
    y2 = 70;
    
    m = (y2 - y1) / (x2 - x1);
    b = y1 - m * x1;
    
    Percentage = m * voltage + b;
end