function [normalizedSignal] = piecewiseNormalize(signal,nsamples)

% This function performs piecewise normalization on the input signal.
% The input signal is first reshaped into a matrix with a specified number
% of samples per row. Signal is filled with NaNs to ensure
% the matrix has complete rows. Each row of the matrix is then normalized
% independently. Finally, the normalized matrix is reshaped back into a
% single vector, and any added NaNs are removed.
%
% Parameters:
%   signal (vector): The input signal to be normalized.
%   nsamples (scalar): The number of samples per row for the piecewise normalization.
%
% Returns:
%   normalizedSignal (vector): The piecewise normalized signal.


signal = signal(:);
n = length(signal);
nrows = ceil(n/nsamples);
nnans = nrows*nsamples - n;

% Reshape signal into a matrix with nsamples per row
sigMatrix = reshape([signal; nan(nnans,1)], nsamples, nrows);

% Normalize each row of the matrix
sigMatrixNorm = normalize(sigMatrix,1);

% Reshape normalized matrix back into a single vector
normalizedSignal = reshape(sigMatrixNorm, [], 1);

% Remove any added NaNs
normalizedSignal(end-nnans+1:end) = [];

end