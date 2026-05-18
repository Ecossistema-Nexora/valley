export function bindAdminShortcuts(onRefresh: () => void, onSearch: () => void) {
  const handler = (event: KeyboardEvent) => {
    if (event.key === 'F5') {
      event.preventDefault();
      onRefresh();
    }
    if (event.ctrlKey && event.key.toLowerCase() === 'p') {
      event.preventDefault();
      onSearch();
    }
  };

  window.addEventListener('keydown', handler);
  return () => window.removeEventListener('keydown', handler);
}
