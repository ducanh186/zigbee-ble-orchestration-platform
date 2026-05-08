// LogsScreen.jsx — timeline + filters.

const LogsScreen = () => {
  const [type, setType] = React.useState('all');
  const [sev, setSev] = React.useState('all');
  const [expandedId, setExpandedId] = React.useState(null);

  const TYPES = [
    { id: 'all', label: 'All' },
    { id: 'LIGHT', label: 'Light', icon: 'lightbulb' },
    { id: 'MOTION', label: 'Motion', icon: 'radar' },
    { id: 'GATEWAY', label: 'Gateway', icon: 'router' },
  ];
  const SEVS = [
    { id: 'all', label: 'All' },
    { id: 'info', label: 'Info' },
    { id: 'warning', label: 'Warning' },
    { id: 'error', label: 'Error' },
  ];

  const filtered = MOCK_LOGS.filter(l => {
    if (type !== 'all' && l.type !== type) return false;
    if (sev !== 'all' && l.sev !== sev) return false;
    return true;
  });

  return (
    <>
      <AppBar title="Logs" trailing={<IconBtn icon="refresh-cw" />} />

      <div style={{ padding: '0 16px 12px', display: 'flex', flexDirection: 'column', gap: 8 }}>
        <div style={{ display: 'flex', gap: 8, overflowX: 'auto', paddingBottom: 2 }}>
          {TYPES.map(t => (
            <Chip key={t.id} active={type === t.id} onClick={() => setType(t.id)} icon={t.icon}>
              {t.label}
            </Chip>
          ))}
        </div>
        <div style={{ display: 'flex', gap: 8, overflowX: 'auto', paddingBottom: 2 }}>
          {SEVS.map(s => (
            <Chip key={s.id} active={sev === s.id} onClick={() => setSev(s.id)}>
              {s.id !== 'all' && (
                <span style={{
                  width: 6, height: 6, borderRadius: 999,
                  background: `var(--${s.id === 'info' ? 'primary' : s.id})`,
                  marginRight: 2,
                }}></span>
              )}
              {s.label}
            </Chip>
          ))}
        </div>
      </div>

      <Body padded={false}>
        <div>
          {filtered.map(l => {
            const open = expandedId === l.id;
            return (
              <div key={l.id} onClick={() => setExpandedId(open ? null : l.id)} style={{
                padding: '12px 16px',
                borderTop: '1px solid var(--border)',
                background: open ? 'var(--surface)' : 'transparent',
                cursor: 'pointer',
              }}>
                <div style={{ display: 'flex', gap: 10, alignItems: 'flex-start' }}>
                  <span style={{
                    fontFamily: "'JetBrains Mono', monospace", fontSize: 12,
                    color: 'var(--text-secondary)', width: 60, flexShrink: 0, paddingTop: 1,
                  }}>{l.t}</span>
                  <i data-lucide={l.icon} style={{
                    width: 16, height: 16, flexShrink: 0, marginTop: 2,
                    color: `var(--${l.sev === 'info' ? 'primary' : l.sev})`,
                  }}></i>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontSize: 13, fontFamily: "'JetBrains Mono', monospace" }}>
                      <span style={{ color: 'var(--text-secondary)' }}>{l.type}</span> {l.deviceId}
                    </div>
                    <div style={{ fontSize: 14, marginTop: 2 }}>{l.msg}</div>
                    <div style={{
                      fontSize: 11, color: 'var(--text-secondary)',
                      fontFamily: "'JetBrains Mono', monospace", marginTop: 2,
                    }}>{l.meta}</div>
                    {open && (
                      <pre style={{
                        marginTop: 8, padding: 10, borderRadius: 8,
                        background: 'var(--bg)', border: '1px solid var(--border)',
                        fontFamily: "'JetBrains Mono', monospace", fontSize: 11,
                        color: 'var(--text-primary)', overflow: 'auto', margin: '8px 0 0',
                      }}>{JSON.stringify({
                        device_id: l.deviceId, type: l.type.toLowerCase(),
                        severity: l.sev, message: l.msg,
                        occurred_at: '2026-03-19T' + l.t + 'Z',
                      }, null, 2)}</pre>
                    )}
                  </div>
                  <i data-lucide={open ? 'chevron-up' : 'chevron-down'} style={{
                    width: 14, height: 14, color: 'var(--text-secondary)', marginTop: 4,
                  }}></i>
                </div>
              </div>
            );
          })}
          {filtered.length === 0 && (
            <div style={{ padding: 32, textAlign: 'center', color: 'var(--text-secondary)' }}>
              No events match.
            </div>
          )}
        </div>
      </Body>
    </>
  );
};

window.LogsScreen = LogsScreen;
