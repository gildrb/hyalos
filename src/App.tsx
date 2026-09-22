import { Component, render } from 'preact';
import type { ComponentChildren } from 'preact';
import { useCallback, useEffect, useMemo, useLayoutEffect, useRef, useState } from 'preact/hooks';
import { DEFAULT, PRESETS, FINISHES, STORAGE_KEY, parseDocument } from './model.ts';
import { Editor, messageOf } from './editor.ts';
import { readPngProject } from './binary.ts';
import { studyImages } from './assets.ts';
import { Inspector } from './components/Inspector.tsx';
import { Viewport } from './components/Viewport.tsx';
import { ExportDialog, AboutDialog } from './components/Dialogs.tsx';
import { Icon } from './components/Icon.tsx';

function App() {
  const [notification, setNotification] = useState(''), [exportOpen, setExportOpen] = useState(false), [aboutOpen, setAboutOpen] = useState(false);
  const [panel, setPanel] = useState<'presets' | 'inspector' | ''>('');
  const notificationTimer = useRef<ReturnType<typeof setTimeout> | undefined>();
  const fileInput = useRef<HTMLInputElement>(null);
  const notify = useCallback((text: string): void => {
    setNotification(text); clearTimeout(notificationTimer.current);
    notificationTimer.current = setTimeout(() => setNotification(''), 5000);
  }, []);
  const startup = useMemo(() => {
    try {
      const saved = location.hash.startsWith('#scene=') ? decodeURIComponent(location.hash.slice(7)) : localStorage.getItem(STORAGE_KEY);
      return { settings: saved ? parseDocument(saved).settings : DEFAULT, warning: '' };
    } catch (error) { return { settings: DEFAULT, warning: `Saved scene was not loaded: ${messageOf(error)}` }; }
  }, []);
  const editor = useMemo(() => new Editor(startup.settings, {
    save: recipe => { try { localStorage.setItem(STORAGE_KEY, JSON.stringify(recipe)); } catch { notify('Local storage unavailable. Save a recipe to keep this scene.'); } },
  }), []);
  const [, setRevision] = useState(0);
  useLayoutEffect(() => {
    const refresh = () => setRevision(n => n + 1);
    const unsubscribe = editor.subscribe(refresh);
    refresh();
    return unsubscribe;
  }, [editor]);
  useEffect(() => {
    if (startup.warning) notify(startup.warning);
    return () => { clearTimeout(notificationTimer.current); };
  }, []);
  useEffect(() => {
    const api = Object.freeze({
      get ready() { return editor.ready; },
      getScene: () => editor.getScene(),
      setScene: (recipe: unknown) => editor.setScene(recipe),
      setParameters: (patch: Parameters<Editor['setParameters']>[0]) => editor.setParameters(patch),
      exportPNG: (width?: number, height?: number) => editor.exportPNG(width, height),
      capabilities: () => editor.capabilities(),
    });
    window.hyalos = api;
    return () => { if (window.hyalos === api) delete window.hyalos; };
  }, [editor]);
  useEffect(() => {
    const keydown = (event: KeyboardEvent): void => {
      if (editor.busy || document.querySelector('dialog[open]') || (event.target instanceof HTMLElement && /INPUT|TEXTAREA|SELECT/.test(event.target.tagName))) return;
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'z') { event.preventDefault(); if (event.shiftKey) editor.redo(); else editor.undo(); }
      if (event.code === 'Space') { event.preventDefault(); editor.togglePlay(); }
      if (event.key === 'Escape') setPanel('');
    };
    document.addEventListener('keydown', keydown);
    return () => document.removeEventListener('keydown', keydown);
  }, [editor]);
  return <div class="editor" data-panel={panel}>
    <header class="topbar">
      <a class="brand" href="./" aria-label="Hyalos visual laboratory"><svg viewBox="0 0 32 32" aria-hidden="true"><path d="M7 24 25 6M7 6l18 18M6 16h20" /></svg><strong>hyalos</strong><span class="brand-divider" /><span>visual laboratory</span></a>
      <div class="header-centre"><span class="small-dot" />PROMETHEAN STUDIES<span class="muted">/ 001</span></div>
      <div class="header-actions"><span class="privacy">ON DEVICE</span><button id="open-project" class="text-button" disabled={editor.busy} onClick={() => fileInput.current?.click()}>Open recipe</button><button id="open-export" class="primary" disabled={editor.busy} onClick={() => { editor.stop(); setExportOpen(true); }}>Export <Icon name="arrow" /></button></div>
    </header>
    <div class="mobile-toolbar"><button data-panel="presets" aria-expanded={panel === 'presets'} onClick={() => setPanel(panel === 'presets' ? '' : 'presets')}>Studies</button><button data-panel="inspector" aria-expanded={panel === 'inspector'} onClick={() => setPanel(panel === 'inspector' ? '' : 'inspector')}>Parameters</button></div>
    <main class="workspace" id="workspace" inert={editor.busy}>
      <aside class="library" aria-label="Study library"><div class="panel-header"><span>Studies</span><span class="counter">06</span></div><p class="library-intro">An intelligence of our own.</p>
        <div id="presets" class="preset-list">{PRESETS.map((p, index) => <button key={p.id} class="preset-card" data-preset={p.id} aria-pressed={editor.selected === p.id} disabled={editor.busy} onClick={() => { editor.select(p.id); setPanel(''); }}><img src={studyImages[p.id]} alt="" /><span><span class="preset-name">{p.name}</span><small>{String(index + 1).padStart(2, '0')} / {FINISHES[p.settings.finish ?? 0].toUpperCase()}</small></span></button>)}</div>
        <div class="library-bottom"><button class="outline-button" id="save-recipe" disabled={editor.busy} onClick={() => editor.saveRecipe()}>Save this variation <Icon name="download" /></button><p>Seeded. Adjustable. Yours.<br />No uploads. No runtime cloud.</p></div>
      </aside>
      <Viewport editor={editor} notify={notify} />
      <Inspector editor={editor} notify={notify} onAbout={() => setAboutOpen(true)} />
    </main>
    <footer class="footer"><span>A FIRE HELD IN COMMON.</span><span id="shader-version">HYALOS VISUAL SYSTEM / {editor.hash?.slice(0, 8) ?? 'NOT COMPILED'}</span><button id="copy-link" class="text-button" onClick={async () => {
      try { const url = new URL(location.href); url.hash = `scene=${encodeURIComponent(JSON.stringify(editor.getScene()))}`; await navigator.clipboard.writeText(url.toString()); notify('Scene link copied. Nothing was uploaded.'); }
      catch { notify('Clipboard unavailable. Save the recipe instead.'); }
    }}>Copy scene link <Icon name="arrow" /></button></footer>
    <input id="project-file" ref={fileInput} type="file" accept=".json,.png,application/json,image/png" hidden onChange={async e => {
      const input = e.currentTarget, file = input.files?.[0];
      if (!file) return;
      try {
        if (file.size > 64 * 1024 * 1024) throw new Error('File exceeds the 64 MiB import budget.');
        const text = file.name.toLowerCase().endsWith('.png') ? readPngProject(new Uint8Array(await file.arrayBuffer())) : await file.text();
        const recipe = parseDocument(text);
        editor.setScene(recipe);
        notify(editor.hash && recipe.shaderHash !== editor.hash ? 'Recipe restored. Its shader revision differs from this build.' : 'Recipe restored. Playback is paused.');
      } catch (error) { notify(messageOf(error)); }
      finally { input.value = ''; }
    }} />
    <div id="toast" class="toast" role="status" hidden={!notification}>{notification}</div>
    <ExportDialog editor={editor} open={exportOpen} onClose={() => setExportOpen(false)} notify={notify} />
    <AboutDialog editor={editor} open={aboutOpen} onClose={() => setAboutOpen(false)} />
  </div>;
}
class ErrorBoundary extends Component<{ children: ComponentChildren }, { error: string }> {
  state = { error: '' };
  static getDerivedStateFromError(error: unknown) { return { error: messageOf(error) }; }
  render() {
    return this.state.error ? <main class="startup-card" role="alert"><h1>The editor could not start.</h1><p>{this.state.error}</p><p>Run the complete project with its Vite+ server, or serve the production dist folder. Do not open the source HTML directly.</p><button class="outline-button" onClick={() => location.reload()}>Reload</button></main> : this.props.children;
  }
}
export function mount(root: HTMLElement): () => void {
  render(<ErrorBoundary><App /></ErrorBoundary>, root);
  return () => render(null, root);
}
