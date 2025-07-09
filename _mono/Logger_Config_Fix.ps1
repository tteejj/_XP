# In Start.ps1, after creating the Logger service, add this configuration:
# Configure logger to reduce verbosity
$logger.MinimumLevel = "Info"  # Only log Info, Warning, Error, Fatal
$logger.EnableConsoleLogging = $false  # Disable console logging by default
