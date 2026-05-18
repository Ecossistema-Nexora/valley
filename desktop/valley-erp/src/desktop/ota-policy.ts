export type OtaChannel = 'stable' | 'beta';

export type OtaPolicy = {
  channel: OtaChannel;
  checkOnStartup: boolean;
  downloadInBackground: boolean;
  installOnNextRestart: boolean;
  allowSilentPatch: boolean;
  keepCurrentVersionOnFailure: boolean;
  writeLocalLog: boolean;
};

export const WINDOWS_DESKTOP_OTA_POLICY: OtaPolicy = {
  channel: 'stable',
  checkOnStartup: true,
  downloadInBackground: true,
  installOnNextRestart: true,
  allowSilentPatch: true,
  keepCurrentVersionOnFailure: true,
  writeLocalLog: true,
};

export const BETA_OTA_POLICY: OtaPolicy = {
  ...WINDOWS_DESKTOP_OTA_POLICY,
  channel: 'beta',
};
