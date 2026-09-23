import { Component, render } from 'preact';
import type { ComponentChildren } from 'preact';
import { StudioApp } from './studio/StudioApp.tsx';

class ErrorBoundary extends Component<{ children: ComponentChildren }, { error: string }> {
  state = { error: '' };
  static getDerivedStateFromError(error: unknown) { return { error: error instanceof Error ? error.message : String(error) }; }
  render() {
    return this.state.error ? <main class="startup-card" role="alert"><h1>The editor could not start.</h1><p>{this.state.error}</p><p>Run the complete project with its Vite+ server, or serve the production dist folder. Do not open the source HTML directly.</p><button class="outline-button" onClick={() => location.reload()}>Reload</button></main> : this.props.children;
  }
}
export function mount(root: HTMLElement): () => void {
  render(<ErrorBoundary><StudioApp /></ErrorBoundary>, root);
  return () => render(null, root);
}
