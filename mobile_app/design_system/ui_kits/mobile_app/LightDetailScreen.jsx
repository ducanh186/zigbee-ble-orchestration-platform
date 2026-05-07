// LightDetailScreen.jsx — large ON/OFF + command lifecycle panel.

const LightDetailScreen = ({ deviceId, onBack }) => {
  const device = MOCK_DEVICES.find(d => d.id === deviceId) || MOCK_DEVICES[0];
  const [power, setPower] = React.useState(device.power);
  const [confirmedPower, setConfirmedPower] = React.useState(device.power);
  const [phase, setPhase] = React.useState('idle'); // idle | sending | polling | success | failed | timeout
  const [cmdId, setCmdId] = React.useState('cmd-01');
  const [lastTarget, setLastTarget] = React.useState(null);
  const [reason, setReason] = React.useState(null);

  const isUnreachable = confirmedPower === 'unreachable';

  const send = (target) => {
    if (isUnreachable) return;
    const newId = 'cmd-' + Math.floor(Math.random() * 90 + 10);
    setCmdId(newId);
    setLastTarget(target);
    setReason(null);
    setPhase('sending');
    setTimeout(() => setPhase('polling'), 600);
    setTimeout(() => {
      setPhase('success');
      setPower(target);
      setConfirmedPower(target);
      setTimeout(() => setPhase('idle'), 1400);
    }, 1900);
  };

  const retry = () => lastTarget && send(lastTarget);

  const phaseTone = { idle: 'neutral', sending: 'primary', polling: 'primary',
                      success: 'success', failed: 'error', timeout: 'warning' };
  const phaseLabel = { idle: 'IDLE', sending: 'ACCEPTED', polling: 'POLLING',
                       success: 'EXECUTED', failed: 'FAILED', timeout: 'TIMEOUT' };

  const sending = phase === 'sending' || phase === 'polling';
  const lightLogs = MOCK_LOGS.filter(l => l.deviceId === device.id).slice(0, 3);

  return (
    <>
      <AppBar
        title="Light detail"
        leading={<IconBtn icon="arrow-left" onClick={onBack} />}
        trailing={<IconBtn icon="refresh-cw" />}
      />
      <Body>
        {/* hero card */}
        <Card padding={20} style={{
          display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 14,
        }}>
          <div style={{
            width: 96, height: 96, borderRadius: 28,
            background: power === 'on' ? 'var(--warning-tint)'
              : isUnreachable ? 'var(--warning-tint)' : 'rgb(107 114 128 / 0.12)',
            color: power === 'on' ? 'var(--warning)'
              : isUnreachable ? 'var(--warning)' : 'var(--text-secondary)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            transition: 'all 200ms var(--ease-standard)',
          }}>
            <i data-lucide="lightbulb" style={{ width: 48, height: 48 }}></i>
          </div>
          <div style={{ textAlign: 'center' }}>
            <div style={{ fontSize: 22, fontWeight: 700, letterSpacing: '-0.01em' }}>{device.name}</div>
            <div style={{
              fontSize: 12, color: 'var(--text-secondary)', marginTop: 2,
              fontFamily: "'JetBrains Mono', monospace",
            }}>{device.id} · {device.roomName}</div>
          </div>
          <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
            <Badge tone={POWER_TONE[power]} dot>{POWER_LABEL[power]}</Badge>
            <span style={{ fontSize: 12, color: 'var(--text-secondary)' }}>· {device.reportedAt}</span>
          </div>

          {/* on/off pills */}
          <div style={{ display: 'flex', gap: 10, width: '100%', marginTop: 4 }}>
            <button
              disabled={sending || isUnreachable}
              onClick={() => send('on')}
              style={{
                flex: 1, height: 56, borderRadius: 999, border: 'none',
                background: power === 'on' ? 'var(--primary)' : 'var(--primary-tint)',
                color: power === 'on' ? 'var(--primary-on)' : 'var(--primary)',
                fontFamily: 'inherit', fontSize: 16, fontWeight: 700, letterSpacing: '0.04em',
                cursor: sending || isUnreachable ? 'not-allowed' : 'pointer',
                opacity: isUnreachable ? 0.4 : sending ? 0.6 : 1,
                display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
              }}>
              {sending && phase !== 'success' && (
                <span style={{
                  width: 14, height: 14, borderRadius: 999,
                  border: '2px solid currentColor', borderRightColor: 'transparent',
                  animation: 'spin 0.8s linear infinite',
                }}></span>
              )}
              ON
            </button>
            <button
              disabled={sending || isUnreachable}
              onClick={() => send('off')}
              style={{
                flex: 1, height: 56, borderRadius: 999,
                border: '1px solid var(--border)',
                background: power === 'off' ? 'var(--surface-elevated)' : 'transparent',
                color: 'var(--text-primary)',
                fontFamily: 'inherit', fontSize: 16, fontWeight: 700, letterSpacing: '0.04em',
                cursor: sending || isUnreachable ? 'not-allowed' : 'pointer',
                opacity: isUnreachable ? 0.4 : sending ? 0.6 : 1,
              }}>
              OFF
            </button>
          </div>
        </Card>

        {/* command status */}
        <Card padding={14}>
          <SectionTitle>Last command</SectionTitle>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <div style={{ minWidth: 0 }}>
              <div style={{ fontSize: 13, fontFamily: "'JetBrains Mono', monospace" }}>{cmdId}</div>
              <div style={{ fontSize: 11, color: 'var(--text-secondary)', marginTop: 2 }}>
                {phase === 'polling' ? 'Waiting for gateway…' :
                 phase === 'sending' ? 'Sent to cloud' :
                 phase === 'success' ? 'Acknowledged' :
                 phase === 'failed'  ? (reason || 'Cluster busy') :
                 phase === 'timeout' ? 'No reply within 5s — last confirmed state preserved' :
                 'No active command'}
              </div>
            </div>
            <Badge tone={phaseTone[phase]} dot={phase !== 'idle'}>{phaseLabel[phase]}</Badge>
          </div>
          {(phase === 'failed' || phase === 'timeout') && (
            <button onClick={retry} style={{
              marginTop: 12, width: '100%', height: 40, borderRadius: 12,
              border: '1px solid var(--border)', background: 'var(--surface-elevated)',
              color: 'var(--primary)', fontFamily: 'inherit', fontWeight: 600,
              fontSize: 13, cursor: 'pointer',
              display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
            }}>
              <i data-lucide="refresh-cw" style={{ width: 14, height: 14 }}></i>
              Retry {lastTarget?.toUpperCase()}
            </button>
          )}
        </Card>

        {/* recent logs */}
        <SectionTitle action={
          <span style={{ fontSize: 12, color: 'var(--primary)', fontWeight: 600 }}>View all</span>
        }>Recent events</SectionTitle>
        <Card padding={4}>
          {lightLogs.map((l, i) => (
            <div key={l.id} style={{
              display: 'flex', gap: 10, padding: '10px 12px',
              borderTop: i === 0 ? 'none' : '1px solid var(--border)',
            }}>
              <span style={{
                fontFamily: "'JetBrains Mono', monospace", fontSize: 11,
                color: 'var(--text-secondary)', width: 56, flexShrink: 0, paddingTop: 2,
              }}>{l.t}</span>
              <i data-lucide={l.icon} style={{
                width: 14, height: 14, flexShrink: 0, marginTop: 3,
                color: `var(--${l.sev === 'info' ? 'primary' : l.sev})`,
              }}></i>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 13, fontWeight: 500 }}>{l.msg}</div>
                <div style={{
                  fontSize: 11, color: 'var(--text-secondary)',
                  fontFamily: "'JetBrains Mono', monospace", marginTop: 1,
                }}>{l.meta}</div>
              </div>
            </div>
          ))}
        </Card>
      </Body>
    </>
  );
};

window.LightDetailScreen = LightDetailScreen;
