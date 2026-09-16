

MATA1 = load();
MATA2 = load();
SHIMMER = load();

sigs = [MATA1.ACC sqrt(sum(MATA1.ACC.^2,2)) MATA2.ACC sqrt(sum(MATA2.ACC.^2,2)) SHIMMER.ACC sqrt(sum(SHIMMER.ACC.^2,2)) ];



% terminar
t4Hz = (0:1:length(resp_filtered)-1)./fr;

SetupPN.Tm = 10;
SetupPN.Ts = 5;
SetupPN.Omega_r = [0 200]./60;
SetupPN.a = 0.7;
SetupPN.b = 0.7;
SetupPN.d = 1;
SetupPN.plotflag = true;
acc_results = peakednessCost (resp_filtered,t4Hz,fr,SetupPN);



