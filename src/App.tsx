import { Component, render } from 'preact';
import type { ComponentChildren } from 'preact';
import { useCallback, useEffect, useMemo, useLayoutEffect, useRef, useState } from 'preact/hooks';
import { DEFAULT, PRESETS, STORAGE_KEY, parseDocument } from './model.ts';
import { Editor, messageOf } from './editor.ts';
import { readPngProject } from './binary.ts';
import { download } from './export.ts';
import { studyImages } from './assets.ts';
import { Inspector } from './components/Inspector.tsx';
import { Viewport } from './components/Viewport.tsx';
import { ExportDialog, AboutDialog } from './components/Dialogs.tsx';
import { Icon } from './components/Icon.tsx';

function App() {
  const [notification, setNotification] = useState(''), [exportOpen, setExportOpen] = useState(false), [aboutOpen, setAboutOpen] = useState(false);
  const [panel, setPanel] = useState<'presets' | 'inspector' | ''>('');
  const [savingPng, setSavingPng] = useState(false);
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
      if (event.key === 'Escape') setPanel('');
    };
    document.addEventListener('keydown', keydown);
    return () => document.removeEventListener('keydown', keydown);
  }, [editor]);
  return <div class="editor" data-panel={panel}>
    <header class="topbar">
      <a class="brand" href="./">Hyalos</a>
      <div class="header-actions">
        <button id="open-project" class="text-button" disabled={editor.busy} onClick={() => fileInput.current?.click()}>Open recipe</button>
        <button id="open-export" class="text-button" disabled={editor.busy} aria-label="Export options: format, resolution, sequence or project" title="Choose format, resolution, a PNG sequence or a project recipe" onClick={() => setExportOpen(true)}>Export options <Icon name="arrow" /></button>
        <button id="save-png" class="primary" disabled={editor.status !== 'ready' || editor.busy || savingPng} aria-busy={savingPng} aria-label={savingPng ? 'Saving PNG' : 'Save PNG: 1920 × 1080 with embedded recipe'} title="Download a 1920 × 1080 PNG with its recipe, without opening options" onClick={async () => {
          const filename = `hyalos-${editor.selected}-s${editor.settings.seed}-1920x1080.png`;
          setPanel(''); setSavingPng(true);
          try { download(await editor.exportPNG(1920, 1080), filename); notify('PNG saved with its recipe.'); }
          catch (error) { notify(messageOf(error)); }
          finally { setSavingPng(false); }
        }}>{savingPng ? 'Saving…' : 'Save PNG'}<Icon name="download" /></button>
        {savingPng && <button id="cancel-save-png" class="text-button" onClick={() => editor.cancelExport()}>Cancel save</button>}
      </div>
    </header>
    <div class="mobile-toolbar"><button data-panel="presets" aria-controls="study-library" aria-expanded={panel === 'presets'} onClick={() => setPanel(panel === 'presets' ? '' : 'presets')}>Studies</button><button data-panel="inspector" aria-controls="inspector" aria-expanded={panel === 'inspector'} onClick={() => setPanel(panel === 'inspector' ? '' : 'inspector')}>Edit</button></div>
    {panel && <button class="panel-scrim" aria-label="Close panel" onClick={() => setPanel('')} />}
    <main class="workspace" id="workspace" inert={editor.busy}>
      <aside class="library" id="study-library" aria-label="Study library"><div class="panel-header"><span>Studies</span></div>
        <div id="presets" class="preset-list">{PRESETS.map(p => <button key={p.id} class="preset-card" data-preset={p.id} aria-pressed={editor.selected === p.id} disabled={editor.busy} onClick={() => { editor.select(p.id); setPanel(''); }}><img src={studyImages[p.id]} alt="" /><span class="preset-name">{p.name}</span></button>)}</div>
        <div class="library-bottom">
          <button class="outline-button" id="save-recipe" disabled={editor.busy} onClick={() => editor.saveRecipe()}>Save recipe <Icon name="download" /></button>
          <button id="copy-link" class="text-button" onClick={async () => {
            try { const url = new URL(location.href); url.hash = `scene=${encodeURIComponent(JSON.stringify(editor.getScene()))}`; await navigator.clipboard.writeText(url.toString()); notify('Scene link copied.'); }
            catch { notify('Clipboard unavailable. Save the recipe instead.'); }
          }}>Copy scene link <Icon name="arrow" /></button>
        </div>
      </aside>
      <Viewport editor={editor} notify={notify} />
      <Inspector editor={editor} notify={notify} onAbout={() => setAboutOpen(true)} />
    </main>
    <input id="project-file" ref={fileInput} type="file" accept=".json,.png,application/json,image/png" hidden onChange={async e => {
      const input = e.currentTarget, file = input.files?.[0];
      if (!file) return;
      try {
        if (file.size > 64 * 1024 * 1024) throw new Error('File exceeds the 64 MiB import budget.');
        const text = file.name.toLowerCase().endsWith('.png') ? readPngProject(new Uint8Array(await file.arrayBuffer())) : await file.text();
        const recipe = parseDocument(text);
        editor.setScene(recipe);
        notify(editor.hash && recipe.shaderHash !== editor.hash ? 'Recipe restored. Its shader revision differs from this build.' : 'Recipe restored. Choose Render to update the preview.');
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
