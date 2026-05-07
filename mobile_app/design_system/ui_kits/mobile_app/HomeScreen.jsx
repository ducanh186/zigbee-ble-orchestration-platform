// HomeScreen.jsx — Dashboard: gateway status, counts, quick light tiles.

const HomeScreen = ({ onOpenLight }) => {
  const lights = MOCK_DEVICES.filter(d => d.deviceType === 'light');
  const onCount = lights.filter(l => l.power === 'on').length;
  const unreachableCount = lights.filter(l => l.power === 'unreachable').length;

  return (
    <>
      <AppBar
        title="Home"
        trailing={<IconBtn icon="refresh-cw" />}
      />
      <Body>
        {/* gateway status */}
        <Card style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
          <div style={{
            width: 44, height: 44, borderRadius: 12,
            background: 'var(--success-tint)', color: 'var(--success)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <i data-lucide="router" style={{ width: 22, height: 22 }}></i>
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 15, fontWeight: 600 }}>Gateway online</div>
            <div style={{
              fontSize: 12, color: 'var(--text-secondary)',
              fontFamily: "'JetBrains Mono', monospace", marginTop: 2,
            }}>z3gw-01 · last seen 1s ago</div>
          </div>
          <Badge tone="success" dot>OK</Badge>
        </Card>

        {/* metrics row */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8 }}>
          <Card padding={12}>
            <div style={{ fontSize: 11, color: 'var(--text-secondary)', fontWeight: 600, letterSpacing: '0.04em', textTransform: 'uppercase' }}>Devices</div>
            <div style={{ fontSize: 24, fontWeight: 700, marginTop: 4 }}>{MOCK_DEVICES.length}</div>
          </Card>
          <Card padding={12}>
            <div style={{ fontSize: 11, color: 'var(--success)', fontWeight: 600, letterSpacing: '0.04em', textTransform: 'uppercase' }}>On</div>
            <div style={{ fontSize: 24, fontWeight: 700, marginTop: 4 }}>{onCount}</div>
          </Card>
          <Card padding={12}>
            <div style={{ fontSize: 11, color: 'var(--warning)', fontWeight: 600, letterSpacing: '0.04em', textTransform: 'uppercase' }}>Unreach</div>
            <div style={{ fontSize: 24, fontWeight: 700, marginTop: 4 }}>{unreachableCount}</div>
          </Card>
        </div>

        {/* quick lights */}
        <SectionTitle action={
          <span style={{ fontSize: 12, color: 'var(--primary)', fontWeight: 600 }}>See all</span>
        }>Quick lights</SectionTitle>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
          {lights.slice(0, 4).map(l => (
            <Card key={l.id} padding={14} onClick={() => onOpenLight(l.id)} style={{
              opacity: l.power === 'unreachable' ? 0.7 : 1,
            }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div style={{
                  width: 36, height: 36, borderRadius: 10,
                  background: l.power === 'on' ? 'var(--warning-tint)' : 'rgb(107 114 128 / 0.14)',
                  color: l.power === 'on' ? 'var(--warning)' : 'var(--text-secondary)',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                }}>
                  <i data-lucide="lightbulb" style={{ width: 20, height: 20 }}></i>
                </div>
                <Badge tone={POWER_TONE[l.power]} dot>{POWER_LABEL[l.power]}</Badge>
              </div>
              <div style={{ fontSize: 14, fontWeight: 600, marginTop: 12, lineHeight: 1.25 }}>{l.name}</div>
              <div style={{ fontSize: 11, color: 'var(--text-secondary)', fontFamily: "'JetBrains Mono', monospace", marginTop: 2 }}>{l.id}</div>
            </Card>
          ))}
        </div>

        <div style={{ height: 4 }} />
      </Body>
    </>
  );
};

window.HomeScreen = HomeScreen;
