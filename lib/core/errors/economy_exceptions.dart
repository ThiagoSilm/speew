import 'exceptions.dart';

/// Exceções específicas para a camada de Economia Simbólica.

/// Exceção base para erros relacionados a tokens.
class TokenException extends AppException {
  TokenException(String message) : super(message);

  factory TokenException.notFound(String tokenId) =>
      TokenException('Token não encontrado: $tokenId');

  factory TokenException.insufficientSupply(String tokenId) =>
      TokenException('Supply insuficiente para o token: $tokenId');

  factory TokenException.invalidAmount(double amount) =>
      TokenException('Valor inválido: $amount');
}

/// Exceção base para erros relacionados a taxas.
class FeeException extends AppException {
  FeeException(String message) : super(message);

  factory FeeException.feeTooHigh(double fee, double maxFee) =>
      FeeException('Taxa calculada ($fee) excede o máximo permitido ($maxFee).');

  factory FeeException.feeCalculationError(String details) =>
      FeeException('Erro no cálculo da taxa: $details');
}

/// Exceção base para erros relacionados a contratos.
class ContractException extends AppException {
  ContractException(String message) : super(message);

  factory ContractException.notFound(String contractId) =>
      ContractException('Contrato não encontrado: $contractId');

  factory ContractException.invalidState(String currentState, String requiredState) =>
      ContractException('Estado do contrato inválido. Atual: $currentState, Requerido: $requiredState');

  factory ContractException.reputationTooLow(double required, double actual) =>
      ContractException('Reputação insuficiente. Requerido: $required, Atual: $actual');
}

/// Exceção base para erros relacionados a leilões.
class AuctionException extends AppException {
  AuctionException(String message) : super(message);

  factory AuctionException.notFound(String auctionId) =>
      AuctionException('Leilão não encontrado: $auctionId');

  factory AuctionException.inactive() =>
      AuctionException('Leilão inativo ou encerrado.');

  factory AuctionException.bidTooLow(double currentBid, double newBid) =>
      AuctionException('Lance muito baixo. Lance atual: $currentBid, Novo lance: $newBid');
}

/// Exceção base para erros relacionados a staking.
class StakingException extends AppException {
  StakingException(String message) : super(message);

  factory StakingException.lockPeriodNotFinished() =>
      StakingException('Período de bloqueio ainda não terminou.');
}
