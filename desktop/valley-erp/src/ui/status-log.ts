export type ExecutionStatusLog = {
  activityName: string;
  description: string;
  currentStep: string;
  difficulty: 1 | 2 | 3 | 4 | 5;
  completedPercentage: number;
  estimatedTime: string;
  completedCount: number;
  pendingCount: number;
};

export const INITIAL_STATUS_LOG: ExecutionStatusLog = {
  activityName: 'Valley ERP Windows Desktop',
  description: 'ERP local do lojista para estoque fisico, vendas, frete e pepitas.',
  currentStep: 'Scaffold desktop e contratos de dominio persistidos no repositorio.',
  difficulty: 4,
  completedPercentage: 65,
  estimatedTime: 'bloqueado apenas por assets oficiais e execucao real em Windows',
  completedCount: 10,
  pendingCount: 4,
};
