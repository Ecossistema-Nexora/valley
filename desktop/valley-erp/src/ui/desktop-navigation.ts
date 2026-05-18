export type DesktopRouteId =
  | 'dashboard'
  | 'products'
  | 'stock'
  | 'sales'
  | 'freight'
  | 'pepitas'
  | 'reports'
  | 'settings';

export type DesktopRoute = {
  id: DesktopRouteId;
  label: string;
  shortcut: string;
  density: 'high' | 'medium';
  icon: string;
};

export const DESKTOP_ROUTES: DesktopRoute[] = [
  { id: 'dashboard', label: 'Dashboard', shortcut: 'Ctrl+1', density: 'high', icon: 'grid' },
  { id: 'products', label: 'Produtos', shortcut: 'Ctrl+2', density: 'high', icon: 'box' },
  { id: 'stock', label: 'Estoque Fisico', shortcut: 'Ctrl+3', density: 'high', icon: 'warehouse' },
  { id: 'sales', label: 'Ordens de Venda', shortcut: 'Ctrl+4', density: 'high', icon: 'receipt' },
  { id: 'freight', label: 'Frete Fisico', shortcut: 'Ctrl+5', density: 'high', icon: 'truck' },
  { id: 'pepitas', label: 'Pepitas', shortcut: 'Ctrl+6', density: 'medium', icon: 'gem' },
  { id: 'reports', label: 'Relatorios Master', shortcut: 'Ctrl+7', density: 'high', icon: 'chart' },
  { id: 'settings', label: 'Configuracoes', shortcut: 'Ctrl+,', density: 'medium', icon: 'settings' },
];

export const GLOBAL_SHORTCUTS = [
  { shortcut: 'Ctrl+N', action: 'Novo registro' },
  { shortcut: 'Ctrl+S', action: 'Salvar formulario ativo' },
  { shortcut: 'Ctrl+F', action: 'Focar busca e filtros' },
  { shortcut: 'F5', action: 'Atualizar grade' },
  { shortcut: 'Esc', action: 'Fechar modal ou painel lateral' },
];
