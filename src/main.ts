let disposed = false;
let unmount: (() => void) | undefined;

async function boot(): Promise<void> {
  const root = document.getElementById('app');
  const shell = document.getElementById('boot-shell');
  const detail = document.getElementById('startup-detail');
  try {
    if (!root) throw new Error('The application mount point is missing.');
    if (location.protocol === 'file:') throw new Error('Source HTML cannot run as a file. Run npm install and npm run dev, then open the printed localhost URL.');
    if (getComputedStyle(document.documentElement).getPropertyValue('--exo-css-loaded').trim() !== '1') {
      throw new Error('The stylesheet did not load. Serve the complete project through Vite+, or serve the complete dist directory.');
    }
    const { mount } = await import('./App.tsx');
    if (disposed) return;
    unmount = mount(root);
    if (shell) shell.hidden = true;
  } catch (error) {
    if (detail) detail.textContent = error instanceof Error ? error.message : String(error);
    if (shell) shell.hidden = false;
    console.error('Exo startup failed:', error);
  } finally { clearTimeout(window.__exoBootTimer); }
}
void boot();
if (import.meta.hot) import.meta.hot.dispose(() => { disposed = true; unmount?.(); clearTimeout(window.__exoBootTimer); });
