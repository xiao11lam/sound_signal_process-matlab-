%实验要求二：基于线性预测系数和基音参数的语音合成实验
clear all; clc; close all;
[xx, fs] = audioread('C7_2_y.wav');           % 读入数据文件
xx=xx-mean(xx);                           % 去除直流分量
x=xx/max(abs(xx));                        % 归一化
N=length(x);                              % 数据长度
time=(0:N-1)/fs;                          % 时间刻度
wlen=240;                                 % 帧长
inc=80;                                   % 帧移
overlap=wlen-inc;                         % 重叠长度
tempr1=(0:overlap-1)'/overlap;            % 斜三角窗函数w1
tempr2=(overlap-1:-1:0)'/overlap;         % 斜三角窗函数w2
n2=1:wlen/2+1;                            % 正频率的下标值
wind=hanning(wlen);                       % 窗函数
X=enframe(x,wind,inc)';                   % 分帧
fn=size(X,2);                             % 帧数
T1=0.1; r2=0.5;                           % 端点检测参数
miniL=10;                                 % 有话段最短帧数
mnlong=5;                                 % 元音主体最短帧数
ThrC=[10 15];                             % 阈值
p=12;                                     % LPC阶次
frameTime=FrameTimeC(fn,wlen,inc,fs);     % 计算每帧的时间刻度
for i=1 : fn                              % 计算每帧的线性预测系数和增益
    u=X(:,i);
    [ar,g]=lpc(u,p);
    AR_coeff(:,i)=ar;
    Gain(i)=g;
end
% 基音检测
[voiceseg,vosl,SF,Ef,period]=pitch_Ceps(x,wlen,inc,T1,fs); %基于倒谱法的基音周期检测
Dpitch=pitfilterm1(period,voiceseg,vosl);       % 对T0进行平滑处理求出基音周期T0

tal=0;                                    % 初始化前导零点
zint=zeros(p,1);
for i=1:fn; 
    ai=AR_coeff(:,i);                     % 获取第i帧的预测系数
    sigma_square=Gain(i);                 % 获取第i帧的增益系数
    sigma=sqrt(sigma_square);
    
    if SF(i)==0                           % 无话帧
        excitation=randn(wlen,1);         % 产生白噪声
        [synt_frame,zint]=filter(sigma,ai,excitation,zint); % 用白噪声合成语音
    else                                  % 有话帧
        PT=round(Dpitch(i));              % 取周期值
        exc_syn1 =zeros(wlen+tal,1);      % 初始化脉冲发生区
        exc_syn1(mod(1:tal+wlen,PT)==0) = 1;  % 在基音周期的位置产生脉冲，幅值为1
        exc_syn2=exc_syn1(tal+1:tal+inc); % 计算帧移inc区间内脉冲个数
        index=find(exc_syn2==1);
        excitation=exc_syn1(tal+1:tal+wlen);% 这一帧的激励脉冲源
        
        if isempty(index)                 % 帧移inc区间内没有脉冲
            tal=tal+inc;                  % 计算下一帧的前导零点
        else                              % 帧移inc区间内有脉冲
            eal=length(index);            % 计算有几个脉冲
            tal=inc-index(eal);           % 计算下一帧的前导零点
        end
        gain=sigma/sqrt(1/PT);            % 增益
        [synt_frame,zint]=filter(gain, ai,excitation,zint); % 用脉冲合成语音
    end
        if i==1                           % 若为第1帧
            output=synt_frame;            % 不需要重叠相加,保留合成数据
        else
            M=length(output);             % 按线性比例重叠相加处理合成数据
            output=[output(1:M-overlap); output(M-overlap+1:M).*tempr2+synt_frame(1:overlap).*tempr1; synt_frame(overlap+1:wlen)];
        end
end
ol=length(output);                        % 把输出output延长至与输入信号xx等长
if ol<N
    output1=[output; zeros(N-ol,1)];
else
    output1=output(1:N);
end
bn=[0.964775   -3.858862   5.788174   -3.858862   0.964775]; % 滤波器系数
an=[1.000000   -3.928040   5.786934   -3.789685   0.930791];
output=filter(bn,an,output1);             % 高通滤波
output=output/max(abs(output));           % 幅值归一

subplot 211; plot(time,x,'k'); title('(a)原始语音波形');
axis([0 max(time) -1 1.1]); xlabel('时间/s'); ylabel('幅值')
subplot 212; plot(time,output,'k');  title('(b)合成语音波形');
axis([0 max(time) -1 1.1]); xlabel('时间/s'); ylabel('幅值')
