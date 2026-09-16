load('MATA00-1004961-20250116-154000.mat')
GEN = sqrt(GYR(:,1).^2+GYR(:,2).^2+GYR(:,3).^2);
figure
plot(timeStamp,GEN)
hold on
load('MATA00-2000822-20250116-153939.mat')
GEN = sqrt(GYR(:,1).^2+GYR(:,2).^2+GYR(:,3).^2);
plot(timeStamp-seconds(0.3),GEN)