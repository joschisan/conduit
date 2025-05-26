pub mod account;
pub mod admin;
pub mod daemon;
pub mod user;

use anyhow::{Context, Result, ensure};
use serde::de::DeserializeOwned;
use std::process::Command;

trait RunConduitCli {
    fn run_conduit_cli<T: DeserializeOwned>(&mut self) -> Result<T>;
}

impl RunConduitCli for Command {
    fn run_conduit_cli<T: DeserializeOwned>(&mut self) -> Result<T> {
        let output = self.output().context("Failed to run conduit-cli")?;

        ensure!(
            output.status.success(),
            "Conduit CLI returned non-zero exit code: {} : {}",
            String::from_utf8_lossy(&output.stderr),
            String::from_utf8_lossy(&output.stdout),
        );

        let output = String::from_utf8(output.stdout).context("Failed to convert stdout")?;

        serde_json::from_str(&output).context(format!("Failed to parse output: {}", output))
    }
}
