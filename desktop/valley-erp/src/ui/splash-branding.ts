export const BRAND_ASSETS = {
  splashVideo: 'valley_desktop_opening_final_animated.mp4',
  impactLogo: 'VALLEY-ERP.png',
  compactLogo: 'VALLEY-BOTON',
} as const;

export type BrandingSurface = 'SPLASH' | 'LOGIN' | 'DASHBOARD' | 'MASTER_REPORTS' | 'INTERNAL_FORM' | 'MODAL' | 'SETTINGS';

export function brandingAssetFor(surface: BrandingSurface): string {
  if (surface === 'SPLASH') return BRAND_ASSETS.splashVideo;
  if (surface === 'LOGIN' || surface === 'DASHBOARD' || surface === 'MASTER_REPORTS') return BRAND_ASSETS.impactLogo;
  return BRAND_ASSETS.compactLogo;
}

export const SPLASH_POLICY = {
  mustPlayBeforeLogin: true,
  loop: false,
  targetAspectRatio: '16:9',
  fallbackAfterPlaybackErrorMs: 3500,
};
