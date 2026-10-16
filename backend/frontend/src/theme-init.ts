import { applyTheme, readTheme } from "./theme";

// Runs before CSS and React so a saved dark theme never flashes white.
applyTheme(readTheme());
