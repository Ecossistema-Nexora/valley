use serde::Serialize;

#[derive(Serialize)]
struct RootAclProvider {
    provider: &'static str,
    secret_env: &'static str,
    acl: &'static str,
}

#[tauri::command]
fn root_acl_providers() -> Vec<RootAclProvider> {
    vec![
        RootAclProvider { provider: "AMAZON", secret_env: "SECRET_AMAZON_CONNECTOR", acl: "ROOT_ONLY" },
        RootAclProvider { provider: "ALIEXPRESS", secret_env: "SECRET_ALIEXPRESS_CONNECTOR", acl: "ROOT_ONLY" },
        RootAclProvider { provider: "CJ_DROPSHIPPING", secret_env: "SECRET_CJ_CONNECTOR", acl: "ROOT_ONLY" },
        RootAclProvider { provider: "PRIVATE_STOCK", secret_env: "SECRET_PRIVATE_STOCK_CONNECTOR", acl: "ROOT_ONLY" },
    ]
}

#[tauri::command]
fn security_boot_policy() -> String {
    "SPLASH_LOCKED_UNTIL_VIDEO_ENDED;NO_VENDOR_SECRET_ON_CLIENT;OTA_SILENT_CHANNEL_ENABLED".into()
}

pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_updater::Builder::new().build())
        .plugin(tauri_plugin_process::init())
        .invoke_handler(tauri::generate_handler![root_acl_providers, security_boot_policy])
        .run(tauri::generate_context!())
        .expect("erro ao iniciar Valley Admin Windows");
}

fn main() {
    run();
}
