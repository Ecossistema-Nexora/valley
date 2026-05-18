import { useEffect, useMemo, useRef, useState } from 'react';
import { Activity, AlertTriangle, Boxes, Coins, Gauge, KeyRound, Lock, RefreshCw, Search, Settings2, ShieldCheck, Truck, Users } from 'lucide-react';
import { connectors, logs, tenants, tokenomics } from './domain/mockData';
import { globalSearch } from './services/globalSearch';
import { bindAdminShortcuts } from './services/keyboard';

const currency = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' });
const number = new Intl.NumberFormat('pt-BR');

function MetricCard({ title, value, detail, icon: Icon }: { title: string; value: string; detail: string; icon: any }) {
  return <section className="metric-card"><div className="metric-icon"><Icon size={19} /></div><span>{title}</span><strong>{value}</strong><small>{detail}</small></section>;
}

function SplashGate({ onDone }: { onDone: () => void }) {
  const [fallbackProgress, setFallbackProgress] = useState(0);
  useEffect(() => {
    const timer = window.setInterval(() => setFallbackProgress((progress) => Math.min(100, progress + 2)), 80);
    return () => window.clearInterval(timer);
  }, []);
  useEffect(() => { if (fallbackProgress >= 100) onDone(); }, [fallbackProgress, onDone]);
  return <main className="splash-shell"><video className="splash-video" src="/assets/valley_desktop_opening_final_animated.mp4" autoPlay playsInline onEnded={onDone} /><div className="splash-overlay"><img src="/assets/VALLEY-ADMIN.png" alt="Valley Admin" /><h1>Central Master Valley</h1><p>Inicialização bloqueada até a abertura institucional ser concluída.</p><div className="progress"><i style={{ width: `${fallbackProgress}%` }} /></div></div></main>;
}

export function App() {
  const [ready, setReady] = useState(false);
  const [query, setQuery] = useState('');
  const [refreshPulse, setRefreshPulse] = useState(0);
  const searchRef = useRef<HTMLInputElement>(null);
  const data = useMemo(() => globalSearch(query), [query, refreshPulse]);
  useEffect(() => bindAdminShortcuts(() => setRefreshPulse(Date.now()), () => searchRef.current?.focus()), []);
  if (!ready) return <SplashGate onDone={() => setReady(true)} />;

  const activeTenants = tenants.length;
  const incidents = tenants.reduce((sum, tenant) => sum + tenant.incidentCount, 0);
  const health = Math.round(tenants.reduce((sum, tenant) => sum + tenant.health, 0) / tenants.length);
  const profit = tenants.reduce((sum, tenant) => sum + tenant.grossProfitBRL, 0);

  return <div className="admin-shell"><aside className="sidebar"><div className="brand-mini"><img src="/assets/VALLEY-BOTON.png" alt="Valley" /><b>ADMIN</b></div><nav><a className="active"><Gauge size={16}/> Infraestrutura</a><a><Boxes size={16}/> APIs Exclusivas</a><a><Coins size={16}/> Tokenomics</a><a><Truck size={16}/> Valley Rider</a><a><Users size={16}/> Omniverse</a><a><KeyRound size={16}/> Cofre de Chaves</a><a><Settings2 size={16}/> Flags Globais</a></nav><div className="root-seal"><ShieldCheck size={17}/> ACL ROOT_ONLY</div></aside><main className="workspace"><header className="topbar"><div><img src="/assets/VALLEY-ADMIN.png" alt="Valley Admin" className="header-logo" /><h1>Painel de Controle Global</h1><p>Modo Deus para ERP, Rider, Omniverse, Stock, Tokenomics e OTA Windows.</p></div><label className="global-search"><Search size={18}/><input ref={searchRef} value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Ctrl+P: localizar transação, tenant, API, usuário..." /></label><button className="refresh" onClick={() => setRefreshPulse(Date.now())}><RefreshCw size={16}/> F5 Atualizar</button></header><section className="metrics-grid"><MetricCard title="Saúde Global" value={`${health}%`} detail="Média ponderada multi-tenant" icon={Activity} /><MetricCard title="Lucro Real Stock" value={currency.format(profit)} detail="Base dos tiers 10/20/50%" icon={Boxes} /><MetricCard title="Tenants Ativos" value={String(activeTenants)} detail="ERP + Rider + Omniverse" icon={Users} /><MetricCard title="Incidentes" value={String(incidents)} detail="Abertos no SOC administrativo" icon={AlertTriangle} /></section><section className="dashboard-grid"><section className="panel wide"><div className="panel-title"><h2>BI Operacional em Tempo Real</h2><span>Grafana-like density</span></div><div className="chart-row"><div className="line-chart">{[38,58,44,72,68,91,83,96,88,98,94,99].map((height, index) => <i key={index} style={{ height: `${height}%` }} />)}</div><div className="pie"><b>{health}%</b><small>health</small></div><div className="bar-chart">{tenants.map((tenant) => <span key={tenant.id} title={tenant.name} style={{ height: `${Math.max(12, tenant.health)}%` }} />)}</div></div></section><section className="panel"><div className="panel-title"><h2>Tokenomics Dual</h2><span>V-Coin / Pepitas</span></div><div className="token-box"><strong>{number.format(tokenomics.vcoinCirculation)}</strong><span>V-Coin em circulação</span></div><div className="token-box"><strong>{number.format(tokenomics.pepitasCirculation)}</strong><span>Pepitas em circulação</span></div><div className="discounts"><b>Descontos sobre lucro real</b><em>10%</em><em>20%</em><em>50%</em></div></section><section className="panel wide"><div className="panel-title"><h2>Monitoramento Multi-Tenant</h2><span>{data.tenants.length} registros filtrados</span></div><table><thead><tr><th>Tenant</th><th>Tipo</th><th>ID</th><th>Health</th><th>Latência</th><th>Lucro</th><th>Usuários</th><th>Inc.</th></tr></thead><tbody>{data.tenants.map((tenant) => <tr key={tenant.id}><td><b>{tenant.name}</b><small>{tenant.lastSeen}</small></td><td>{tenant.kind}</td><td>{tenant.cnpjOrDocument}</td><td>{tenant.health}%</td><td>{tenant.latencyMs}ms</td><td>{currency.format(tenant.grossProfitBRL)}</td><td>{number.format(tenant.activeUsers)}</td><td>{tenant.incidentCount}</td></tr>)}</tbody></table></section><section className="panel"><div className="panel-title"><h2>APIs Exclusivas</h2><span>ACL negada ao lojista</span></div>{data.connectors.map((connector) => <div className="connector" key={connector.provider}><b>{connector.provider}</b><span className={connector.enabled ? 'ok' : 'off'}>{connector.enabled ? 'ON' : 'OFF'}</span><small>{connector.secretEnv}</small><small>{number.format(connector.importedSkus)} SKUs · lag {connector.syncLagSeconds}s · {connector.stockMode}</small></div>)}</section><section className="panel"><div className="panel-title"><h2>Flags Globais</h2><span>Emergency control</span></div>{['Stock infinito', 'Cashback V-Coin', 'Rider dispatch', 'Omniverse login', 'OTA silencioso', 'Modo manutenção'].map((flag, index) => <label className="switch-row" key={flag}><span>{flag}</span><input type="checkbox" defaultChecked={index !== 5}/></label>)}</section><section className="panel wide"><div className="panel-title"><h2>Console de Auditoria</h2><span>logs do sistema</span></div><div className="logs">{data.logs.map((log, index) => <p key={index} className={log.level.toLowerCase()}><b>[{log.level}]</b><span>{log.timestamp}</span><code>{log.source}</code>{log.message}</p>)}</div></section><section className="panel"><div className="panel-title"><h2>Segurança Master</h2><span>desktop Windows</span></div><div className="security-note"><Lock size={18}/><p>Segredos reais ficam em cofre/variáveis de ambiente no backend. O cliente desktop não persiste credenciais de fornecedor.</p></div></section></section></main></div>;
}
