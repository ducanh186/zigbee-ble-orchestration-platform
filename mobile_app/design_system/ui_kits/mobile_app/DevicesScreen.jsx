// DevicesScreen.jsx — list, filterable by node type.

const DevicesScreen = ({ onOpenLight }) => {
  const [filter, setFilter] = React.useState('light');
  const [search, setSearch] = React.useState('');

  const filtered = MOCK_DEVICES.filter(d => {
    if (filter !== 'all' && d.deviceType !== filter) return false;
    if (search && !`${d.name} ${d.id} ${d.roomName}`.toLowerCase().includes(search.toLowerCase())) return false;
    return true;
  });

  const TYPES = [
    { id: 'all', label: 'All' },
    { id: 'light', label: 'Light', icon: 'lightbulb' },
    { id: 'motion', label: 'Motion', icon: 'radar' },
    { id: 'switch', label: 'Switch', icon: 'toggle-left' },
    { id: 'lock', label: 'Lock', icon: 'lock' },
  ];

  return (
    <>
      <AppBar title="Devices" trailing={<IconBtn icon="refresh-cw" />} />
      <div style={{
        padding: '0 16px 12px', display: 'flex', flexDirection: 'column', gap: 10,
        background: 'var(--bg)',
      }}>
        {/* search */}
        <div style={{
          display: 'flex', alignItems: 'center', gap: 8,
          background: 'var(--surface)', border: '1px solid var(--border)',
          borderRadius: 12, padding: '9px 12px',
        }}>
          <i data-lucide="search" style={{ width: 16, height: 16, color: 'var(--text-secondary)' }}></i>
          <input
            value={search} onChange={e => setSearch(e.target.value)}
            placeholder="Search devices"
            style={{
              flex: 1, border: 'none', outline: 'none', background: 'transparent',
              fontFamily: 'inherit', fontSize: 14, color: 'var(--text-primary)',
            }}
          />
        </div>
        {/* filter chips */}
        <div style={{ display: 'flex', gap: 8, overflowX: 'auto', paddingBottom: 4 }}>
          {TYPES.map(t => (
            <Chip key={t.id} active={filter === t.id} onClick={() => setFilter(t.id)} icon={t.icon}>
              {t.label}
            </Chip>
          ))}
        </div>
      </div>

      <Body padded={false}>
        <div style={{ padding: '0 16px 16px', display: 'flex', flexDirection: 'column', gap: 10 }}>
          {filtered.length === 0 && (
            <Card padding={32} style={{ textAlign: 'center' }}>
              <i data-lucide="inbox" style={{ width: 32, height: 32, color: 'var(--text-secondary)' }}></i>
              <div style={{ marginTop: 8, fontSize: 14, color: 'var(--text-secondary)' }}>No devices match.</div>
            </Card>
          )}
          {filtered.map(d => {
            const isLight = d.deviceType === 'light';
            const onClick = isLight ? () => onOpenLight(d.id) : undefined;
            const tone = POWER_TONE[d.power] || (d.isOnline ? 'success' : 'neutral');
            const label = POWER_LABEL[d.power] || (d.isOnline ? 'ONLINE' : 'OFFLINE');
            return (
              <Card key={d.id} onClick={onClick} padding={14} style={{
                display: 'flex', alignItems: 'center', gap: 12,
                opacity: d.power === 'unreachable' ? 0.75 : 1,
              }}>
                <div style={{
                  width: 40, height: 40, borderRadius: 12,
                  background: 'var(--primary-tint)', color: 'var(--primary)',
                  display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
                }}>
                  <i data-lucide={TYPE_ICON[d.deviceType]} style={{ width: 20, height: 20 }}></i>
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 14, fontWeight: 600 }}>{d.name}</div>
                  <div style={{
                    fontSize: 12, color: 'var(--text-secondary)',
                    fontFamily: "'JetBrains Mono', monospace", marginTop: 2,
                  }}>{d.id} · {d.roomName}</div>
                </div>
                <Badge tone={tone} dot>{label}</Badge>
                {isLight && <i data-lucide="chevron-right" style={{ width: 16, height: 16, color: 'var(--text-secondary)' }}></i>}
              </Card>
            );
          })}
        </div>
      </Body>
    </>
  );
};

window.DevicesScreen = DevicesScreen;
